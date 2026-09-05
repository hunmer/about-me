import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/plugins/scripts_center/models/script_execution_result.dart';
import 'script_manager.dart';

/// 脚本执行器服务
///
/// 使用 JSBridgeManager 提供的统一 JS 执行环境
/// 脚本可以直接调用 Aboutme 的插件 API（如 Aboutme.chat.sendMessage() 等）
class ScriptExecutor {
  final ScriptManager scriptManager;
  final StorageManager storage;
  final EventManager eventManager;

  /// JS Bridge Manager 实例
  final JSBridgeManager _jsBridge = JSBridgeManager.instance;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 正在执行的脚本栈（用于检测循环调用）
  final Set<String> _executingScripts = {};

  /// 日志回调函数
  final Function(String message, String level)? onLog;

  ScriptExecutor({
    required this.scriptManager,
    required this.storage,
    required this.eventManager,
    this.onLog,
  });

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
  Future<Map<String, dynamic>> _handleGetConfig(
    Map<String, dynamic> params,
  ) async {
    try {
      // 支持两种调用方式：
      // 1. getConfig({scriptId: 'xxx'}) - 对象参数
      // 2. getConfig('xxx') - 位置参数（会被包装成 {_value: 'xxx'}）
      final scriptId =
          (params['scriptId'] as String?) ?? (params['_value'] as String?);

      if (scriptId == null || scriptId.isEmpty) {
        return {'error': 'scriptId 参数缺失'};
      }

      final configPath = 'configs/scripts_center/${scriptId}_config.json';
      final data = await storage.read(configPath);

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

      // 合并存储的配置和默认配置（确保所有字段都存在）
      final storedConfig = data as Map<String, dynamic>;
      return {
        ...defaultConfig,
        ...storedConfig,
        'scriptId': scriptId, // 确保 scriptId 正确
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// 处理保存脚本配置
  ///
  /// 支持两种调用方式：
  /// 1. setConfig({scriptId: 'xxx', config: {...}}) - 对象参数
  /// 2. setConfig('xxx', {...}) - 两个位置参数
  Future<Map<String, dynamic>> _handleSetConfig(
    Map<String, dynamic> params,
  ) async {
    try {
      final scriptId =
          (params['scriptId'] as String?) ?? (params['_pos0'] as String?);
      final config =
          (params['config'] as Map<String, dynamic>?) ??
          (params['_pos1'] as Map<String, dynamic>?);

      if (scriptId == null || scriptId.isEmpty) {
        return {'error': 'scriptId 参数缺失'};
      }
      if (config == null) {
        return {'error': 'config 参数缺失'};
      }

      final configPath = 'configs/scripts_center/${scriptId}_config.json';

      // 确保目录存在
      await storage.createDirectory('configs/scripts_center');

      // 保存配置
      await storage.write(configPath, config);

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

    if (scriptId == null || scriptId.isEmpty) {
      return {'success': false, 'error': 'scriptId 参数缺失'};
    }

    // 检测循环调用
    if (_executingScripts.contains(scriptId)) {
      print('❌ 检测到循环调用: $scriptId');
      return {
        'success': false,
        'error': '检测到循环调用: $scriptId',
      };
    }

    try {
      print('📞 脚本互调: $scriptId');

      // 准备参数
      final Map<String, dynamic> args = {
        'params': runParams ?? [],
        'calledFrom': 'runScript',
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
  Future<ScriptExecutionResult> execute(
    String scriptId, {
    Map<String, dynamic>? args,
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

      // 检测循环调用
      if (_executingScripts.contains(scriptId)) {
        throw Exception('检测到循环调用: $scriptId');
      }

      // 标记为正在执行
      _executingScripts.add(scriptId);

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

        return ScriptExecutionResult.success(
          result: result,
          duration: duration,
          scriptId: scriptId,
        );
      } finally {
        // 移除执行标记
        _executingScripts.remove(scriptId);
      }
    } catch (e) {
      final duration = DateTime.now().difference(startTime);

      // 记录错误日志
      onLog?.call(
        '脚本执行失败: $e',
        'error',
      );

      return ScriptExecutionResult.failure(
        error: e.toString(),
        duration: duration,
        scriptId: scriptId,
      );
    }
  }

  /// 执行脚本代码（JS 层已自带超时机制）
  Future<dynamic> _executeWithTimeout(String code) async {
    // 使用 JSBridgeManager 执行代码
    final jsResult = await _jsBridge.evaluate(code);

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
