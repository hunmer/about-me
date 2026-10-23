import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/plugins/scripts_center/models/script_execution_result.dart';
import 'package:aboutme/plugins/scripts_center/models/script_profile.dart';
import 'script_execution_logger.dart';
import 'script_manager.dart';

const _uuid = Uuid();

/// 脚本执行器服务
///
/// 使用 JSBridgeManager 提供的统一 JS 执行环境
/// 脚本可以直接调用 Aboutme 的插件 API（如 Aboutme.chat.sendMessage() 等）
class ScriptExecutor {
  final ScriptManager scriptManager;
  final StorageManager storage;
  final EventManager eventManager;

  /// 执行记录器（所有触发路径的执行都统一记录）
  final ScriptExecutionLogger executionLogger;

  /// JS Bridge Manager 实例
  final JSBridgeManager _jsBridge = JSBridgeManager.instance;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 正在执行的脚本实例表（scriptId -> 运行中的实例 id 集合）
  ///
  /// 实例 id 由调用方指定（单实例语义，通常是来源名称，如 'auto_run'、
  /// 'event:xxx'）；不传则每次生成随机 id，即允许并发运行。
  /// 脚本互调（runScript）的嵌套链仍按 scriptId 检测循环调用
  final Map<String, Set<String>> _executingScripts = {};

  /// 正在执行脚本所使用的配置文件 id（scriptId -> profileId）
  ///
  /// execute 的 args 里带 profileId 时记录，脚本内 getConfig(scriptId)
  /// 未显式指定 profileId 时自动读取该配置文件
  final Map<String, String> _activeProfileIds = {};

  /// 日志回调函数
  final Function(String message, String level)? onLog;

  ScriptExecutor({
    required this.scriptManager,
    required this.storage,
    required this.eventManager,
    ScriptExecutionLogger? executionLogger,
    this.onLog,
  }) : executionLogger = executionLogger ?? ScriptExecutionLogger(storage);

  /// 初始化JS引擎
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ ScriptExecutor已经初始化过了');
      return;
    }

    try {
      // 如果 JSBridgeManager 尚未初始化，等待它完成
      if (!_jsBridge.isSupported) {
        print('⏳ 等待 JS Bridge 初始化...');
        await _waitForJSBridge();
      }

      // 注入脚本中心特有的全局API（runScript 等）
      await _injectScriptCenterAPI();

      _isInitialized = true;
    } catch (e) {
      print('❌ ScriptExecutor初始化失败: $e');
      rethrow;
    }
  }

  /// 等待 JS Bridge 初始化完成
  Future<void> _waitForJSBridge() async {
    const maxWaitTime = Duration(seconds: 30); // 最多等待30秒
    const checkInterval = Duration(milliseconds: 100); // 每100ms检查一次

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < maxWaitTime) {
      if (_jsBridge.isSupported) {
        return;
      }

      await Future.delayed(checkInterval);
    }

    throw Exception('等待 JS Bridge 初始化超时（${maxWaitTime.inSeconds}秒）');
  }

  /// 注入脚本中心特有的 API 到 JS 环境
  ///
  /// 注意：Aboutme 的插件 API（如 Aboutme.chat.* 等）已由 JSBridgeManager 自动注册
  /// 这里只需要注入脚本中心特有的功能
  Future<void> _injectScriptCenterAPI() async {
    // 创建一个临时的"插件"来注册脚本中心特有的 API
    // 这样可以利用 JSBridgeManager 的标准 API 注册机制
    final _ScriptExecutorPlugin tempPlugin = _ScriptExecutorPlugin(this);

    final apis = {
      'runScript': _handleRunScript,
      'getConfig': _handleGetConfig,
      'setConfig': _handleSetConfig,
      'log': _handleLog,
      'emit': _handleEmit,
    };

    // 使用 JSBridgeManager 的标准 API 注册机制
    await _jsBridge.registerPlugin(tempPlugin, apis);

    // 额外暴露到 Aboutme.script_executor（便于脚本使用）
    await _jsBridge.evaluate('''
      (function() {
        if (typeof globalThis.Aboutme !== 'undefined' &&
            typeof globalThis.Aboutme.plugins !== 'undefined' &&
            typeof globalThis.Aboutme.plugins.script_executor !== 'undefined') {
          // 将 API 直接暴露到 Aboutme.script_executor
          globalThis.Aboutme.script_executor = globalThis.Aboutme.plugins.script_executor;

          // 同时暴露全局函数（便于脚本使用）
          globalThis.runScript = globalThis.Aboutme.plugins.script_executor.runScript;
          globalThis.log = globalThis.Aboutme.plugins.script_executor.log;
          globalThis.emit = globalThis.Aboutme.plugins.script_executor.emit;

          // 兼容浏览器环境
          if (typeof window !== 'undefined') {
            window.Aboutme = globalThis.Aboutme;
            window.runScript = globalThis.runScript;
            window.log = globalThis.log;
            window.emit = globalThis.emit;
          }
        }
      })();
    ''');
  }

  /// 处理获取脚本配置
  ///
  /// 支持的调用方式：
  /// 1. getConfig({scriptId: 'xxx'}) - 取默认配置文件
  /// 2. getConfig({scriptId: 'xxx', profileId: 'yyy'}) - 取指定配置文件
  /// 3. getConfig('xxx') - 位置参数（取默认配置文件）
  /// 4. getConfig('xxx', 'yyy') - 两个位置参数（scriptId, profileId）
  ///
  /// 未显式指定 profileId 时：若脚本正以某个配置文件执行（args.profileId），
  /// 则返回该配置文件；否则返回默认配置文件
  Future<Map<String, dynamic>> _handleGetConfig(
    Map<String, dynamic> params,
  ) async {
    try {
      final scriptId = (params['scriptId'] as String?) ??
          (params['_value'] as String?) ??
          (params['_pos0'] as String?);
      final profileId = (params['profileId'] as String?) ??
          (params['_pos1'] as String?);

      if (scriptId == null || scriptId.isEmpty) {
        return {'error': 'scriptId 参数缺失'};
      }

      final result = await AboutmeDataService.instance.call(
        'scripts_center',
        'getConfig',
        {'scriptId': scriptId},
      );
      final data = result['success'] == true ? result['data'] : null;

      // 默认配置
      final defaultConfig = {
        'scriptId': scriptId,
        'enabled': false,
        'agentId': null,
        'enabledEvents': <String>[],
        'eventTemplates': <String, dynamic>{},
        'promptTemplate': '根据以下事件，用一句话鼓励用户：{eventDescription}',
      };

      if (data == null) {
        // 返回默认配置
        return defaultConfig;
      }

      // 解析配置文件（兼容旧扁平格式）
      final profiles = ScriptProfiles.fromStorage(data);

      // 目标配置文件优先级：显式传入 > 当前执行上下文 > 默认
      final targetId = (profileId != null && profileId.isNotEmpty)
          ? profileId
          : (_activeProfileIds[scriptId] ?? profiles.defaultProfileId);
      final profile = profiles.getById(targetId);
      if (profile == null) {
        return {'error': '配置文件不存在: $targetId'};
      }

      // 合并默认配置和配置文件值（确保所有字段都存在）
      return {
        ...defaultConfig,
        ...profile.values,
        'scriptId': scriptId, // 确保 scriptId 正确
        'profileId': profile.id,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// 处理保存脚本配置
  ///
  /// 支持的调用方式：
  /// 1. setConfig({scriptId: 'xxx', config: {...}}) - 整体覆盖（旧行为）
  /// 2. setConfig({scriptId: 'xxx', profileId: 'yyy', config: {...}}) - 只更新指定配置文件
  /// 3. setConfig('xxx', {...}) - 位置参数（整体覆盖）
  Future<Map<String, dynamic>> _handleSetConfig(
    Map<String, dynamic> params,
  ) async {
    try {
      final scriptId =
          (params['scriptId'] as String?) ?? (params['_pos0'] as String?);
      final config =
          (params['config'] as Map<String, dynamic>?) ??
          (params['_pos1'] as Map<String, dynamic>?);
      final profileId = params['profileId'] as String?;

      if (scriptId == null || scriptId.isEmpty) {
        return {'error': 'scriptId 参数缺失'};
      }
      if (config == null) {
        return {'error': 'config 参数缺失'};
      }

      Future<dynamic> exec(String action, Map<String, dynamic> params) async {
        final r = await AboutmeDataService.instance.call(
          'scripts_center',
          action,
          params,
        );
        if (r['success'] != true) throw Exception(r['error']);
        return r['data'];
      }

      Future<dynamic> readConfig() async {
        final r = await AboutmeDataService.instance.call(
          'scripts_center',
          'getConfig',
          {'scriptId': scriptId},
        );
        return r['success'] == true ? r['data'] : null;
      }

      if (profileId != null && profileId.isNotEmpty) {
        // 只更新指定配置文件的值，保留其他配置文件
        final existing = ScriptProfiles.fromStorage(await readConfig());
        final index = existing.profiles.indexWhere((p) => p.id == profileId);
        final updated = ScriptProfile(
          id: profileId,
          name: index >= 0 ? existing.profiles[index].name : profileId,
          values: config,
        );
        if (index >= 0) {
          existing.profiles[index] = updated;
        } else {
          existing.profiles.add(updated);
        }
        await exec('setConfig', {
          'scriptId': scriptId,
          'config': existing.toStorage(),
        });
      } else {
        // 未指定配置文件：整体覆盖（兼容旧脚本行为）
        await exec('setConfig', {'scriptId': scriptId, 'config': config});
      }

      return {'success': true};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// 处理日志输出
  ///
  /// 支持两种调用方式：
  /// 1. log({message: 'xxx', level: 'info'}) - 对象参数
  /// 2. log('xxx') - 单个位置参数（默认 info 级别）
  /// 3. log('xxx', 'error') - 两个位置参数
  void _handleLog(Map<String, dynamic> params) {
    final message =
        (params['message'] as String?) ??
        (params['_value'] as String?) ??
        (params['_pos0'] as String?);
    final level =
        (params['level'] as String?) ?? (params['_pos1'] as String?) ?? 'info';

    if (message == null || message.isEmpty) {
      return;
    }

    final emoji =
        {'info': 'ℹ️', 'warn': '⚠️', 'error': '❌', 'debug': '🐛'}[level] ??
        'ℹ️';
    print('$emoji [Script] $message');
    onLog?.call(message, level);
  }

  /// 处理事件触发
  ///
  /// 支持两种调用方式：
  /// 1. emit({eventName: 'xxx', data: {...}}) - 对象参数
  /// 2. emit('xxx') - 单个位置参数（只有事件名）
  /// 3. emit('xxx', {...}) - 两个位置参数
  void _handleEmit(Map<String, dynamic> params) {
    final eventName =
        (params['eventName'] as String?) ??
        (params['_value'] as String?) ??
        (params['_pos0'] as String?);
    final data = params['data'] ?? params['_pos1'];

    if (eventName == null || eventName.isEmpty) {
      return;
    }

    eventManager.broadcast(eventName, data);
  }

  /// 处理脚本互调
  ///
  /// 此方法由 JS 环境中的 runScript() 函数调用
  /// 支持真正的异步执行和脚本间调用
  ///
  /// 支持两种调用方式：
  /// 1. runScript({scriptId: 'xxx', params: {...}}) - 对象参数
  /// 2. runScript('xxx') - 单个位置参数
  /// 3. runScript('xxx', {...}) - 两个位置参数
  Future<dynamic> _handleRunScript(Map<String, dynamic> params) async {
    // 支持位置参数：runScript('scriptId', 'params')
    final scriptId =
        (params['scriptId'] as String?) ??
        (params['_value'] as String?) ??
        (params['_pos0'] as String?);
    final runParams = params['params'] ?? params['_pos1'];
    final profileId = params['profileId'] as String?;

    if (scriptId == null || scriptId.isEmpty) {
      return {'success': false, 'error': 'scriptId 参数缺失'};
    }

    // 循环调用检测统一在 execute() 内按嵌套调用链判定，这里不做扁平检查，
    // 避免并发运行同一脚本时误报

    try {
      print('📞 脚本互调: $scriptId');

      // 准备参数
      final Map<String, dynamic> args = {
        'params': runParams ?? [],
        'calledFrom': 'runScript',
        if (profileId != null && profileId.isNotEmpty) 'profileId': profileId,
      };

      // 执行目标脚本
      final result = await execute(scriptId, args: args);

      // 返回结果
      if (result.success) {
        print('✅ 脚本互调成功: $scriptId');
        return result.result;
      } else {
        print('⚠️ 脚本互调失败: $scriptId - ${result.error}');
        return {
          'success': false,
          'error': result.error,
        };
      }
    } catch (e) {
      print('❌ 脚本互调异常: $scriptId - $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 执行脚本
  ///
  /// [instanceId] 执行实例 id：单实例语义的调用方传固定值（通常是来源名称，
  /// 如 'auto_run'、'event:xxx'），同实例仍在运行时会拒绝重复触发；
  /// 不传则生成随机 id，每次执行都是独立实例，允许并发
  Future<ScriptExecutionResult> execute(
    String scriptId, {
    Map<String, dynamic>? args,
    String? instanceId,
  }) async {
    if (!_isInitialized) {
      return ScriptExecutionResult.failure(
        error: 'ScriptExecutor未初始化',
        duration: Duration.zero,
        scriptId: scriptId,
      );
    }

    final startTime = DateTime.now();

    try {
      // 检查脚本是否存在
      final script = scriptManager.getScriptById(scriptId);
      if (script == null) {
        throw Exception('脚本不存在: $scriptId');
      }

      // 检查脚本是否启用
      if (!script.enabled) {
        throw Exception('脚本未启用: $scriptId');
      }

      // 获取脚本代码
      final code = await scriptManager.getScriptCode(scriptId);
      if (code == null || code.isEmpty) {
        throw Exception('脚本代码为空: $scriptId');
      }

      // 运行判重：
      // - 脚本互调（calledFrom == 'runScript'）的嵌套链：检测循环调用
      // - 固定 instanceId 的调用方（单实例语义）：同来源实例仍在运行则拒绝
      // - 未传 instanceId（如手动运行）：随机 id，每次独立放行
      final effectiveInstanceId = instanceId ?? _uuid.v4();
      if (args?['calledFrom'] == 'runScript') {
        if (_executingScripts.containsKey(scriptId)) {
          throw Exception('检测到循环调用: $scriptId');
        }
      } else if (instanceId != null &&
          _executingScripts[scriptId]?.contains(instanceId) == true) {
        throw Exception('脚本正在运行（来源: $instanceId），已忽略重复触发: $scriptId');
      }

      // 标记为正在执行
      _executingScripts
          .putIfAbsent(scriptId, () => <String>{})
          .add(effectiveInstanceId);

      // 记录本次执行使用的配置文件（脚本内 getConfig 未显式指定时使用）
      final profileId = args?['profileId'] as String?;
      if (profileId != null && profileId.isNotEmpty) {
        _activeProfileIds[scriptId] = profileId;
      }

      // 上报运行中状态（执行记录页实时可见）
      final trigger = _resolveTrigger(args);
      executionLogger.startRun(
        scriptId: scriptId,
        scriptName: script.name,
        trigger: trigger,
      );

      try {
        // 准备参数
        final argsJson = jsonEncode(args ?? {});

        // 先定义 args 和 scriptInfo 变量，然后执行脚本代码
        // 避免包装成函数导致返回值问题
        final wrappedCode = '''
          const args = $argsJson;
          const scriptInfo = {
            id: '${script.id}',
            name: '${script.name}',
            version: '${script.version}'
          };

          $code
        ''';

        // 使用 JSBridgeManager 执行脚本
        final result = await _executeWithTimeout(wrappedCode);

        final duration = DateTime.now().difference(startTime);

        // 记录执行日志
        onLog?.call(
          '脚本 ${script.name} 执行成功，耗时 ${duration.inMilliseconds}ms',
          'info',
        );

        executionLogger.record(
          scriptId: scriptId,
          scriptName: script.name,
          success: true,
          trigger: trigger,
          durationMs: duration.inMilliseconds,
          result: result,
          images: _extractImagePaths(result),
        );

        // 成就系统计数（A68 Hello World）
        EventManager.instance.broadcast(
          'script_executed',
          EventArgs('script_executed'),
        );

        return ScriptExecutionResult.success(
          result: result,
          duration: duration,
          scriptId: scriptId,
        );
      } finally {
        // 移除执行标记（该脚本无运行中实例时移除整个条目）
        final instances = _executingScripts[scriptId];
        instances?.remove(effectiveInstanceId);
        if (instances != null && instances.isEmpty) {
          _executingScripts.remove(scriptId);
        }
        _activeProfileIds.remove(scriptId);
        executionLogger.endRun(scriptId);
      }
    } catch (e) {
      final duration = DateTime.now().difference(startTime);

      // 记录错误日志
      onLog?.call(
        '脚本执行失败: $e',
        'error',
      );

      executionLogger.record(
        scriptId: scriptId,
        scriptName: scriptManager.getScriptById(scriptId)?.name ?? scriptId,
        success: false,
        trigger: _resolveTrigger(args),
        durationMs: duration.inMilliseconds,
        error: e,
      );

      // 成就系统计数（A68 Hello World，运行即计数，含失败）
      EventManager.instance.broadcast(
        'script_executed',
        EventArgs('script_executed'),
      );

      return ScriptExecutionResult.failure(
        error: e.toString(),
        duration: duration,
        scriptId: scriptId,
      );
    }
  }

  /// 从脚本返回值提取图片本地路径（约定 result.data.localPaths）
  ///
  /// 内置 ai_image 等脚本把生成的图片路径放在该字段，
  /// 执行记录详情据此展示图片
  List<String> _extractImagePaths(dynamic result) {
    try {
      if (result is! Map) return const [];
      final data = result['data'];
      if (data is! Map) return const [];
      final paths = data['localPaths'];
      if (paths is! List) return const [];
      return paths
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 终止正在执行的脚本
  ///
  /// 协作式终止：reject JS 挂起的 Promise（脚本的 await 处抛错）+
  /// evaluate 轮询退出，执行落入失败路径并记录"脚本已被用户终止"。
  /// 注意：JS 引擎全局共享，会终止所有正在执行的脚本；
  /// 正在同步执行的密集计算段无法立即打断（QuickJS 限制）
  void terminateRunning() {
    final running = [
      for (final e in _executingScripts.entries)
        if (e.value.isNotEmpty) '${e.key} ×${e.value.length}',
    ];
    print('⛔ 请求终止脚本执行（当前运行中: $running）');
    _jsBridge.requestAbort();
  }

  /// 根据执行参数推断触发方式
  String _resolveTrigger(Map<String, dynamic>? args) {
    if (args == null) return '手动';
    if (args['calledFrom'] == 'runScript') return '脚本互调';
    if (args['calledFrom'] == 'agent_tool') return 'Agent 工具';
    if (args['event'] != null) return '事件触发';
    if (args['trigger'] == 'auto') return '自动运行';
    return '手动';
  }

  /// 执行脚本代码
  ///
  /// 脚本可能包含网络请求/轮询等长耗时操作，使用 5 分钟超时
  Future<dynamic> _executeWithTimeout(String code) async {
    // 使用 JSBridgeManager 执行代码
    final jsResult = await _jsBridge.evaluate(
      code,
      timeout: const Duration(minutes: 5),
    );

    // 处理返回值
    if (!jsResult.success) {
      throw Exception(jsResult.error ?? '未知错误');
    }

    return jsResult.result;
  }

  /// 评估表达式（用于调试）
  Future<String?> evaluateExpression(String expression) async {
    if (!_isInitialized) return null;

    try {
      final result = await _jsBridge.evaluate(expression);
      if (result.success) {
        return result.result?.toString();
      } else {
        return 'Error: ${result.error}';
      }
    } catch (e) {
      print('❌ 表达式评估失败: $e');
      return 'Exception: $e';
    }
  }

  /// 清理资源
  void dispose() {
    _executingScripts.clear();
    _activeProfileIds.clear();
    _isInitialized = false;
    print('✅ ScriptExecutor已清理');
  }
}

/// 临时插件类，用于向 JSBridgeManager 注册 ScriptExecutor 的 API
///
/// 这是一个轻量级的适配器，使 ScriptExecutor 能够利用 JSBridgeManager 的
/// 标准 API 注册机制来暴露 runScript 等函数
class _ScriptExecutorPlugin extends PluginBase {
  final ScriptExecutor executor;

  _ScriptExecutorPlugin(this.executor);

  @override
  String get id => 'script_executor';

  @override
  IconData? get icon => null;

  @override
  Color? get color => null;

  @override
  Future<void> initialize() async {
    // 无需初始化，ScriptExecutor 已经初始化
  }

  @override
  Widget buildMainView(BuildContext context) {
    // 这个插件不需要 UI
    return Container();
  }
}
