import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dart_date/dart_date.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/storage/storage_manager.dart' show StorageManager;
import 'package:aboutme/core/utils/network.dart'
    show createClientWithSystemProxy;
import 'package:aboutme/screens/json_dynamic_screen/json_dynamic_screen.dart';
import 'platform/js_engine_interface.dart';
import 'platform/js_engine_factory.dart';
// 条件导入：默认 Web 平台存根，有 IO 库时（移动/桌面）使用真实实现
import 'platform/mobile_js_engine_stub.dart'
    if (dart.library.io) 'platform/mobile_js_engine.dart';
import 'js_ui_handlers.dart';
import 'plugin_tool_registry.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/data_filter/field_filter_service.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';

/// 延迟注册的插件信息
class PendingPluginRegistration {
  final PluginBase plugin;
  final Map<String, Function> apis;

  PendingPluginRegistration({required this.plugin, required this.apis});
}

/// 延迟执行的脚本信息
class _PendingScript {
  final String code;
  final String? description;
  final Completer<JSResult> completer;

  _PendingScript({
    required this.code,
    this.description,
    required this.completer,
  });
}

/// 全局 JS 桥接管理器
class JSBridgeManager {
  static JSBridgeManager? _instance;
  static JSBridgeManager get instance {
    _instance ??= JSBridgeManager._();
    return _instance!;
  }

  JSBridgeManager._();

  JSEngine? _engine;
  bool _initialized = false;
  final Map<String, PluginBase> _registeredPlugins = {};

  // 工具调用上下文管理
  final Map<String, Map<String, dynamic>> _toolCallContexts = {};
  String? _currentToolCallId;
  int _currentStepIndex = -1;

  // 事件队列管理 - 存储待传递给 JavaScript 的事件
  final Map<String, List<Map<String, dynamic>>> _eventQueue = {};

  // 延迟注册队列 - 存储等待 JS Bridge 初始化完成后注册的插件
  final List<PendingPluginRegistration> _pendingRegistrations = [];

  // 延迟执行队列 - 存储等待 JS Bridge 初始化完成后执行的脚本
  final List<_PendingScript> _pendingScripts = [];

  /// 初始化 JS 引擎
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _engine = JSEngineFactory.create();
      await _engine!.initialize();

      // 注册全局 API
      await _registerGlobalAPI();

      _initialized = true;

      // 使用 Get.context 全局注册 UI 处理器
      _registerUIHandlersGlobal();

      // 处理延迟注册的插件
      await _processPendingRegistrations();

      // 处理延迟执行的脚本
      await _processPendingScripts();
    } catch (e) {
      print('JS Bridge 初始化失败: $e');
      _initialized = false;
    }
  }

  /// 使用 Get.context 全局注册 UI 处理器
  void _registerUIHandlersGlobal() {
    if (!_initialized || _engine == null) {
      print('警告: JS Bridge 未初始化，无法注册 UI 处理器');
      return;
    }

    // 只有 MobileJSEngine 需要注册 UI 处理器
    if (_engine is! MobileJSEngine) {
      print('跳过 UI 处理器注册 (Web 平台)');
      return;
    }

    // 尝试获取全局 context
    final context = Get.context;
    if (context == null) {
      print('警告: Get.context 不可用，UI 处理器将在首次调用时延迟注册');
      return;
    }

    final handlers = JSUIHandlers(context);
    handlers.register(_engine as MobileJSEngine);
    // Native Agent 工具与 JS API 共用 Dialog 实现。
    pluginTools.register('ui', {
      'dialog': (Map<String, dynamic> args) {
        final rawOptions = args['options'];
        final options = rawOptions is Map
            ? Map<String, dynamic>.from(rawOptions)
            : <String, dynamic>{};
        final actions = (options['actions'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        return handlers.handleDialog(
          options['title']?.toString(),
          options['content']?.toString(),
          actions,
        );
      },
    });
    print('✓ UI 处理器已全局注册 (Toast/Alert/Dialog)');
  }

  /// 检查是否支持
  bool get isSupported => _initialized && _engine != null;

  /// 注册 UI 处理器（Toast/Alert/Dialog）
  ///
  /// 必须在有 BuildContext 的情况下调用，通常在 UI 组件初始化时调用
  void registerUIHandlers(BuildContext context) {
    if (!_initialized || _engine == null) {
      print('警告: JS Bridge 未初始化，无法注册 UI 处理器');
      return;
    }

    // 只有 MobileJSEngine 需要注册 UI 处理器
    if (_engine is MobileJSEngine) {
      final handlers = JSUIHandlers(context);
      handlers.register(_engine as MobileJSEngine);
      pluginTools.register('ui', {
        'dialog': (Map<String, dynamic> args) {
          final rawOptions = args['options'];
          final options = rawOptions is Map
              ? Map<String, dynamic>.from(rawOptions)
              : <String, dynamic>{};
          final actions = (options['actions'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          return handlers.handleDialog(
            options['title']?.toString(),
            options['content']?.toString(),
            actions,
          );
        },
      });
      print('✓ UI 处理器已注册 (Toast/Alert/Dialog)');
    } else {
      print('跳过 UI 处理器注册 (Web 平台)');
    }
  }

  /// 注册插件分析处理器（由 OpenAI 插件调用）
  ///
  /// 用于在 JS 中调用 callPluginAnalysis() 时执行插件的数据分析方法
  void registerPluginAnalysisHandler(
    Future<String> Function(String methodName, Map<String, dynamic> params)
    handler,
  ) {
    if (!_initialized || _engine == null) {
      print('警告: JS Bridge 未初始化，无法注册插件分析处理器');
      return;
    }

    // 只有 MobileJSEngine 支持插件分析
    if (_engine is MobileJSEngine) {
      (_engine as MobileJSEngine).setPluginAnalysisHandler(handler);
      print('✓ 插件分析处理器已注册');
    } else {
      print('跳过插件分析处理器注册 (Web 平台)');
    }
  }

  /// 处理延迟注册的插件
  Future<void> _processPendingRegistrations() async {
    if (_pendingRegistrations.isEmpty) return;

    print('正在处理 ${_pendingRegistrations.length} 个延迟注册的插件...');

    final registrations = List<PendingPluginRegistration>.from(
      _pendingRegistrations,
    );
    _pendingRegistrations.clear();

    for (final registration in registrations) {
      try {
        await _doRegisterPlugin(registration.plugin, registration.apis);
        print('✓ 延迟注册成功: ${registration.plugin.id}');
      } catch (e) {
        print('✗ 延迟注册失败: ${registration.plugin.id} - $e');
      }
    }

    print('所有延迟注册已完成');
  }

  /// 处理延迟执行的脚本
  Future<void> _processPendingScripts() async {
    if (_pendingScripts.isEmpty) return;

    print('正在处理 ${_pendingScripts.length} 个延迟执行的脚本...');

    final scripts = List<_PendingScript>.from(_pendingScripts);
    _pendingScripts.clear();

    for (final script in scripts) {
      try {
        final result = await _engine!.evaluate(script.code);
        script.completer.complete(result);
        print('✓ 延迟脚本执行成功: ${script.description ?? '(未命名)'}');
      } catch (e) {
        script.completer.complete(JSResult.error(e.toString()));
        print('✗ 延迟脚本执行失败: ${script.description ?? '(未命名)'} - $e');
      }
    }

    print('所有延迟脚本已处理');
  }

  /// 执行实际的插件注册（拆分出来以便复用）
  Future<void> _doRegisterPlugin(
    PluginBase plugin,
    Map<String, Function> apis,
  ) async {
    _registeredPlugins[plugin.id] = plugin;
    // 记录 API 名注册表（供工具调用解析真实命名空间；热重载后可能为 null）
    _pluginApiNames ??= {};
    _pluginApiNames!.putIfAbsent(plugin.id, () => {}).addAll(apis.keys);

    // 为每个插件创建命名空间
    // 使用 globalThis 确保跨平台兼容性（Web/QuickJS）
    await _engine!.evaluateDirect('''
      (function() {
        // 确保全局命名空间存在
        if (typeof globalThis.Aboutme === 'undefined') {
          globalThis.Aboutme = {
            version: '1.0.0',
            plugins: {}
          };
        }

        // 创建插件命名空间
        globalThis.Aboutme.plugins.${plugin.id} = {};

        // 兼容浏览器环境
        if (typeof window !== 'undefined') {
          window.Aboutme = globalThis.Aboutme;
        }
      })();
    ''');

    // 注册 API
    for (var entry in apis.entries) {
      final apiName = entry.key;
      final dartFunction = entry.value;

      // 包装函数：直接返回原始结果或 Future
      // 集成字段过滤器，支持 mode/fields/excludeFields 参数
      dynamic wrappedFunction([
        dynamic a,
        dynamic b,
        dynamic c,
        dynamic d,
        dynamic e,
      ]) {
        try {
          final args = [a, b, c, d, e].where((arg) => arg != null).toList();

          // 参数转换规则：
          // 1. 如果没有参数，传递空 Map
          // 2. 如果有一个参数且是 Map，直接传递
          // 3. 如果有一个参数但不是 Map（如字符串），包装成 {_value: arg}
          // 4. 如果有多个参数，包装成 {_pos0: arg0, _pos1: arg1, ...}
          final Map<String, dynamic> paramsMap;
          if (args.isEmpty) {
            paramsMap = {};
          } else if (args.length == 1 && args[0] is Map<String, dynamic>) {
            paramsMap = args[0] as Map<String, dynamic>;
          } else if (args.length == 1) {
            // 单个非 Map 参数，包装成 {_value: arg}
            paramsMap = {'_value': args[0]};
          } else {
            // 多个参数，使用位置名称
            paramsMap = {};
            for (int i = 0; i < args.length; i++) {
              paramsMap['_pos$i'] = args[i];
            }
          }

          // 提取过滤参数（避免传递给底层方法）
          final originalParams = Map<String, dynamic>.from(paramsMap);
          final cleanedParams = FieldFilterService.cleanParams(paramsMap);

          // 直接调用 Dart 函数并返回（可能是同步值或 Future）
          final result = Function.apply(dartFunction, [cleanedParams]);

          // 如果是 Future，包装为返回序列化结果的 Future
          if (result is Future) {
            return result
                .then((awaitedResult) {
                  // 应用字段过滤器
                  final filtered = FieldFilterService.filterFromParams(
                    awaitedResult,
                    originalParams,
                  );
                  return _serializeResult(filtered);
                })
                .catchError((e) {
                  print('JS API Error [${plugin.id}.$apiName]: $e');
                  return jsonEncode({'error': e.toString()});
                });
          }

          // 同步结果：应用过滤器后序列化
          final filtered = FieldFilterService.filterFromParams(
            result,
            originalParams,
          );
          return _serializeResult(filtered);
        } catch (e) {
          print('JS API Error [${plugin.id}.$apiName]: $e');
          return jsonEncode({'error': e.toString()});
        }
      }

      // 注册包装后的函数
      await _engine!.registerFunction(
        'Aboutme_${plugin.id}_$apiName',
        wrappedFunction,
      );

      // 在插件命名空间下创建代理
      // 直接返回内层 Promise，不使用 await（避免事件循环阻塞）
      // 自动将 JSON 字符串解析为对象
      await _engine!.evaluateDirect('''
        (function() {
          var namespace = globalThis.Aboutme;

          // 返回 Promise 并自动解析 JSON 返回值
          namespace.plugins.${plugin.id}.$apiName = function() {
            var args = Array.prototype.slice.call(arguments);
            // 调用底层函数并自动解析 JSON 字符串
            return Aboutme_${plugin.id}_$apiName.apply(null, args).then(function(result) {
              // 如果返回值是字符串，尝试解析为 JSON
              if (typeof result === 'string') {
                try {
                  return JSON.parse(result);
                } catch (e) {
                  // 解析失败，返回原始字符串
                  return result;
                }
              }
              return result;
            });
          };
        })();
      ''');
    }
  }

  /// 注册插件的 JS API
  Future<void> registerPlugin(
    PluginBase plugin,
    Map<String, Function> apis,
  ) async {
    pluginTools.register(plugin.id, apis);
    // 如果尚未初始化，先加入延迟注册队列
    if (!_initialized || _engine == null) {
      _pendingRegistrations.add(
        PendingPluginRegistration(plugin: plugin, apis: apis),
      );
      return;
    }

    // 如果已初始化，直接注册
    await _doRegisterPlugin(plugin, apis);
  }

  /// 执行 JS 代码
  Future<JSResult> evaluate(String code, {Duration? timeout}) async {
    if (!_initialized || _engine == null) {
      return JSResult.error('JS Bridge not initialized');
    }
    return await _engine!.evaluate(code, timeout: timeout);
  }

  /// 终止当前正在执行的脚本（协作式终止）
  void requestAbort() {
    _engine?.requestAbortAll();
  }

  /// 执行 JS 代码（如果未初始化则加入延迟队列）
  ///
  /// 与 [evaluate] 不同，此方法在 JS Bridge 未初始化时不会立即返回错误，
  /// 而是将脚本加入延迟执行队列，等待初始化完成后自动执行。
  Future<JSResult> evaluateWhenReady(String code, {String? description}) async {
    // 如果已初始化，直接执行
    if (_initialized && _engine != null) {
      return await _engine!.evaluate(code);
    }

    // 否则加入延迟执行队列
    print('[JSBridge] JS Bridge 未初始化，脚本加入延迟队列: ${description ?? '(未命名)'}');
    final completer = Completer<JSResult>();
    _pendingScripts.add(
      _PendingScript(
        code: code,
        description: description,
        completer: completer,
      ),
    );
    return completer.future;
  }

  /// 注册全局 API
  Future<void> _registerGlobalAPI() async {
    if (_engine == null) return;

    // 注册全局命名空间（使用 globalThis 确保跨平台）
    await _engine!.evaluateDirect('''
      (function() {
        // 确保全局命名空间存在
        if (typeof globalThis.Aboutme === 'undefined') {
          globalThis.Aboutme = {
            version: '1.0.0',
            plugins: {},
            system: {}
          };
        }

        // 兼容浏览器环境
        if (typeof window !== 'undefined') {
          window.Aboutme = globalThis.Aboutme;
        }
      })();
    ''');

    // 注册系统级 API
    await _registerSystemAPIs();

    // 注册 HTTP 请求 API
    await _registerHttpAPI();

    // 注册事件系统 API
    await _registerEventAPIs();

    // 注册工具调用 API
    await _registerToolCallAPIs();
  }

  /// 注册系统级 API（时间、设备信息等）
  Future<void> _registerSystemAPIs() async {
    if (_engine == null) return;

    // 1. 获取当前时间
    await _engine!.registerFunction('Aboutme_system_getCurrentTime', ([
      dynamic a,
    ]) async {
      try {
        final now = DateTime.now();
        final weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

        final timeInfo = {
          'timestamp': now.millisecondsSinceEpoch,
          'datetime': now.toIso8601String(),
          'year': now.year,
          'month': now.month,
          'day': now.day,
          'hour': now.hour,
          'minute': now.minute,
          'second': now.second,
          'weekday': now.weekday,
          'weekdayName': weekdayNames[now.weekday - 1],
        };

        return jsonEncode(timeInfo);
      } catch (e) {
        return jsonEncode({'error': e.toString()});
      }
    });

    // 2. 获取设备信息
    await _engine!.registerFunction('Aboutme_system_getDeviceInfo', ([
      dynamic a,
    ]) async {
      try {
        // 导入 device_info_plus 包以获取详细设备信息
        // 这里先返回基础信息，后续可以扩展
        final deviceInfo = {
          'platform': _getPlatformName(),
          'platformVersion': 'Unknown',
          'deviceModel': 'Unknown',
          'isPhysicalDevice': true,
        };

        return jsonEncode(deviceInfo);
      } catch (e) {
        return jsonEncode({'error': e.toString()});
      }
    });

    // 3. 获取应用信息
    await _engine!.registerFunction('Aboutme_system_getAppInfo', ([
      dynamic a,
    ]) async {
      try {
        // 导入 package_info_plus 包以获取详细应用信息
        // 这里先返回基础信息
        final appInfo = {
          'appName': 'Aboutme',
          'version': '1.0.0',
          'buildNumber': '1',
          'packageName': 'github.hunmer.aboutme',
        };

        return jsonEncode(appInfo);
      } catch (e) {
        return jsonEncode({'error': e.toString()});
      }
    });

    // 4. 格式化日期时间
    await _engine!.registerFunction('Aboutme_system_formatDate', ([
      dynamic a,
      dynamic b,
    ]) async {
      try {
        final dateInput = a;
        final format = b ?? 'yyyy-MM-dd HH:mm:ss';

        DateTime dateTime;
        if (dateInput is num) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(dateInput.toInt());
        } else if (dateInput is String) {
          dateTime = DateTime.parse(dateInput);
        } else {
          throw Exception('Invalid date input type');
        }

        final formatted = _formatDateTime(dateTime, format.toString());
        return formatted;
      } catch (e) {
        return jsonEncode({'error': e.toString()});
      }
    });

    // 5. 获取当前时间戳
    await _engine!.registerFunction('Aboutme_system_getTimestamp', ([
      dynamic a,
    ]) async {
      try {
        return DateTime.now().millisecondsSinceEpoch;
      } catch (e) {
        return jsonEncode({'error': e.toString()});
      }
    });

    // 6. 获取自定义日期（解决时区问题的核心 API）
    await _engine!.registerFunction('Aboutme_system_getCustomDate', ([
      dynamic options,
    ]) async {
      try {
        // 解析参数
        Map<String, dynamic> opts = {};
        if (options is String) {
          opts = jsonDecode(options);
        } else if (options is Map) {
          opts = Map<String, dynamic>.from(options);
        }

        // 默认从当前时间开始
        DateTime date = DateTime.now();

        // 处理基准日期
        if (opts['baseDate'] != null) {
          final baseDate = opts['baseDate'];
          if (baseDate is num) {
            date = DateTime.fromMillisecondsSinceEpoch(baseDate.toInt());
          } else if (baseDate is String) {
            date = DateTime.parse(baseDate);
          }
        }

        // 处理时区
        String timezone = opts['timezone']?.toString() ?? 'local';
        if (timezone == 'UTC') {
          date = date.toUtc();
        } else {
          date = date.toLocal();
        }

        // 处理增加时间
        if (opts['add'] != null) {
          final add = Map<String, dynamic>.from(opts['add'] as Map);
          date = date.add(
            Duration(
              days: (add['days'] as num?)?.toInt() ?? 0,
              hours: (add['hours'] as num?)?.toInt() ?? 0,
              minutes: (add['minutes'] as num?)?.toInt() ?? 0,
              seconds: (add['seconds'] as num?)?.toInt() ?? 0,
              milliseconds: (add['milliseconds'] as num?)?.toInt() ?? 0,
            ),
          );
        }

        // 处理减少时间
        if (opts['subtract'] != null) {
          final sub = Map<String, dynamic>.from(opts['subtract'] as Map);
          date = date.subtract(
            Duration(
              days: (sub['days'] as num?)?.toInt() ?? 0,
              hours: (sub['hours'] as num?)?.toInt() ?? 0,
              minutes: (sub['minutes'] as num?)?.toInt() ?? 0,
              seconds: (sub['seconds'] as num?)?.toInt() ?? 0,
              milliseconds: (sub['milliseconds'] as num?)?.toInt() ?? 0,
            ),
          );
        }

        // 处理相对位置（使用 dart_date 扩展方法）
        String? position = opts['relativePosition']?.toString();
        if (position != null) {
          switch (position) {
            case 'startOfDay':
              date = date.startOfDay;
              break;
            case 'endOfDay':
              date = date.endOfDay;
              break;
            case 'startOfHour':
              date = date.startOfHour;
              break;
            case 'endOfHour':
              date = date.endOfHour;
              break;
            case 'startOfMinute':
              date = date.startOfMinute;
              break;
            case 'endOfMinute':
              date = date.endOfMinute;
              break;
            case 'startOfMonth':
              date = date.startOfMonth;
              break;
            case 'endOfMonth':
              date = date.endOfMonth;
              break;
            case 'startOfWeek':
              date = date.startOfWeek;
              break;
            case 'endOfWeek':
              date = date.endOfWeek;
              break;
            case 'startOfYear':
              date = date.startOfYear;
              break;
            case 'endOfYear':
              date = date.endOfYear;
              break;
          }
        }

        // 处理返回格式
        String format = opts['format']?.toString() ?? 'object';
        final weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

        if (format == 'timestamp') {
          return date.millisecondsSinceEpoch;
        } else if (format == 'iso') {
          return date.toIso8601String();
        } else if (format == 'text') {
          // 使用 dart_date 的 timeago 功能
          return date.timeago();
        } else if (format == 'object') {
          // 返回完整对象（默认）
          return jsonEncode({
            'timestamp': date.millisecondsSinceEpoch,
            'datetime': date.toIso8601String(),
            'year': date.year,
            'month': date.month,
            'day': date.day,
            'hour': date.hour,
            'minute': date.minute,
            'second': date.second,
            'millisecond': date.millisecond,
            'weekday': date.weekday,
            'weekdayName': weekdayNames[date.weekday - 1],
          });
        } else {
          // 自定义格式字符串
          return date.format(format);
        }
      } catch (e) {
        return jsonEncode({'error': e.toString()});
      }
    });

    // 6. sleep - 异步等待（QuickJS 无可靠 setTimeout，供脚本轮询间隔使用）
    await _engine!.registerFunction('Aboutme_system_sleep', ([
      dynamic a,
    ]) async {
      final ms = a is num ? a.toInt() : int.tryParse(a?.toString() ?? '') ?? 0;
      if (ms > 0) {
        await Future.delayed(Duration(milliseconds: ms));
      }
      return {'success': true, 'sleptMs': ms};
    });

    // 7. saveFile - 保存文件（相对 app_data 目录）
    //    支持 base64 内联或 url 下载直写（大文件走 url，base64 不过桥防 UI 卡顿）
    await _engine!.registerFunction('Aboutme_system_saveFile', ([
      dynamic a,
    ]) async {
      try {
        final params = a is Map<String, dynamic> ? a : <String, dynamic>{};
        final relativePath = params['path']?.toString() ?? '';
        if (relativePath.isEmpty) {
          throw Exception('缺少 path 参数');
        }
        final base64Data = params['base64']?.toString() ?? '';
        final downloadUrl = params['url']?.toString() ?? '';
        if (base64Data.isEmpty && downloadUrl.isEmpty) {
          throw Exception('缺少 base64 或 url 参数');
        }

        var byteCount = 0;
        if (downloadUrl.isNotEmpty) {
          final client = await createClientWithSystemProxy(
            proxyUrl: (params['proxy']?.toString())?.isEmpty == true
                ? null
                : params['proxy']?.toString(),
          );
          try {
            final resp = await client
                .get(Uri.parse(downloadUrl))
                .timeout(
                  Duration(
                    seconds: params['timeout'] is num
                        ? (params['timeout'] as num).toInt()
                        : 120,
                  ),
                );
            if (resp.statusCode != 200) {
              throw Exception('下载失败: HTTP ${resp.statusCode}');
            }
            byteCount = resp.bodyBytes.length;
            await globalStorage.writeBytes(relativePath, resp.bodyBytes);
          } finally {
            client.close();
          }
        } else {
          final bytes = Uint8List.fromList(base64Decode(base64Data));
          byteCount = bytes.length;
          await globalStorage.writeBytes(relativePath, bytes);
        }

        // 附加绝对路径便于定位（Web 平台没有文件系统，仅返回相对路径）
        String? absolutePath;
        try {
          final rootDir = await StorageManager.appDataDirectory();
          absolutePath = '${rootDir.path}/$relativePath';
        } catch (e) {
          absolutePath = null;
        }

        return {
          'success': true,
          'path': relativePath,
          if (absolutePath != null) 'absolutePath': absolutePath,
          'size': byteCount,
        };
      } catch (e) {
        return {'error': e.toString()};
      }
    });

    // 8. readFile - 读取文件为 base64（与 saveFile 对应，用于图生图上传参考图等）
    //    path 支持相对 app_data 的路径与绝对路径（远端存储模式下绝对路径不可用）
    await _engine!.registerFunction('Aboutme_system_readFile', ([
      dynamic a,
    ]) async {
      try {
        final params = a is Map<String, dynamic> ? a : <String, dynamic>{};
        final filePath = params['path']?.toString() ?? '';
        if (filePath.isEmpty) {
          throw Exception('缺少 path 参数');
        }

        final bytes = await globalStorage.readBytes(filePath);
        if (bytes == null) {
          throw Exception('文件不存在: $filePath');
        }

        return {
          'success': true,
          'base64': base64Encode(bytes),
          'size': bytes.length,
        };
      } catch (e) {
        return {'error': e.toString()};
      }
    });

    // 在 JS 中创建系统 API 代理
    await _engine!.evaluateDirect('''
      (function() {
        var namespace = globalThis.Aboutme;

        // 辅助函数：自动解析 JSON 字符串结果
        function parseResult(result) {
          if (typeof result === 'string') {
            try {
              return JSON.parse(result);
            } catch (e) {
              return result;
            }
          }
          return result;
        }

        namespace.system.getCurrentTime = function() {
          return Aboutme_system_getCurrentTime().then(parseResult);
        };

        namespace.system.getDeviceInfo = function() {
          return Aboutme_system_getDeviceInfo().then(parseResult);
        };

        namespace.system.getAppInfo = function() {
          return Aboutme_system_getAppInfo().then(parseResult);
        };

        namespace.system.formatDate = function(dateInput, format) {
          return Aboutme_system_formatDate(dateInput, format).then(parseResult);
        };

        namespace.system.getTimestamp = function() {
          return Aboutme_system_getTimestamp();
        };

        // sleep - 等待指定毫秒（用于脚本轮询）
        namespace.system.sleep = function(ms) {
          return Aboutme_system_sleep(ms).then(parseResult);
        };

        // saveFile - 将 base64 数据保存为文件（相对 app_data 目录）
        namespace.system.saveFile = function(opts) {
          return Aboutme_system_saveFile(opts).then(parseResult);
        };

        // readFile - 读取文件为 base64（相对 app_data 或绝对路径）
        namespace.system.readFile = function(opts) {
          return Aboutme_system_readFile(opts).then(parseResult);
        };

        // 获取自定义日期（推荐使用，解决时区问题）
        namespace.system.getCustomDate = function(options) {
          return Aboutme_system_getCustomDate(options ? JSON.stringify(options) : '{}').then(parseResult);
        };

        // 获取位置信息
        namespace.system.getLocation = function(mode) {
          // 使用 flutter.getLocation 获取位置
          return flutter.getLocation(mode);
        };

        // 创建 UI 插件命名空间，将 flutter.* 方法代理到 Aboutme.plugins.ui.*
        namespace.plugins.ui = {
          toast: function(message, options) {
            return flutter.toast(message, options);
          },
          alert: function(message, options) {
            return flutter.alert(message, options);
          },
          dialog: function(options) {
            return flutter.dialog(options);
          },
          // 用 json_dynamic_widget 渲染 JSON 并全屏展示
          showJsonScreen: function(json, options) {
            var jsonStr = typeof json === 'string' ? json : JSON.stringify(json);
            var title = (options && options.title) || 'JSON UI';
            return Aboutme_ui_showJsonScreen(jsonStr, title).then(parseResult);
          }
        };
      })();
    ''');
  }

  /// 注册 HTTP 请求 API（Aboutme.http.request）
  ///
  /// QuickJS 环境没有 fetch，脚本通过此 API 发起网络请求。
  /// 参数：{ url, method?, headers?, body?, timeout?, responseType?, proxy?, multipart? }，
  /// timeout 单位秒默认 60；responseType 为 'base64' 时返回 bodyBase64（用于二进制下载）；
  /// proxy 可显式指定代理（host:port），缺省时自动探测系统代理（被墙站点必须走代理）；
  /// multipart 为 [{name, value?}] 文本字段或 [{name, filename?, base64}] 文件字段
  /// （QuickJS 无 FormData，multipart 请求体由 Dart 端拼装，用于图生图上传参考图等）。
  /// 返回：{ statusCode, headers, body } 或 { statusCode, headers, bodyBase64 }。
  Future<void> _registerHttpAPI() async {
    if (_engine == null) return;

    await _engine!.registerFunction('Aboutme_http_request', ([
      dynamic a,
    ]) async {
      try {
        final params = a is Map<String, dynamic> ? a : <String, dynamic>{};
        final url = params['url']?.toString() ?? '';
        if (url.isEmpty) {
          throw Exception('缺少 url 参数');
        }

        final method = (params['method']?.toString() ?? 'GET').toUpperCase();
        final timeoutSec = params['timeout'] is num
            ? (params['timeout'] as num).toInt()
            : 60;
        final wantBase64 = params['responseType']?.toString() == 'base64';
        final proxy = params['proxy']?.toString();
        final multipartParts = params['multipart'] is List
            ? params['multipart'] as List
            : null;

        final rawHeaders = params['headers'];
        final headers = <String, String>{};
        if (rawHeaders is Map) {
          rawHeaders.forEach((k, v) => headers[k.toString()] = v.toString());
        }

        final body = params['body'];
        String? bodyStr;
        if (body is Map || body is List) {
          bodyStr = jsonEncode(body);
        } else if (body != null) {
          bodyStr = body.toString();
        }

        final uri = Uri.parse(url);
        http.BaseRequest request;
        if (multipartParts != null) {
          final mreq = http.MultipartRequest(method, uri);
          // boundary 由 MultipartRequest 自动生成，不能携带外部 Content-Type
          headers.remove('Content-Type');
          for (final part in multipartParts) {
            if (part is! Map) continue;
            final name = part['name']?.toString();
            if (name == null || name.isEmpty) continue;
            final filename = part['filename']?.toString() ?? 'file';
            // 大文件路径引用（本地 path / 远端 url）：由 Dart 侧直接读取，
            // 避免 MB 级 base64 过 QuickJS 桥导致主线程解析阻塞（UI 卡顿）
            final filePath = part['path']?.toString();
            final fileUrl = part['url']?.toString();
            if (fileUrl != null && fileUrl.isNotEmpty) {
              final tmp = await _downloadToTemp(fileUrl, proxy: proxy);
              if (tmp != null) {
                mreq.files.add(
                  await http.MultipartFile.fromPath(
                    name,
                    tmp.path,
                    filename: filename,
                  ),
                );
              }
              continue;
            }
            if (filePath != null &&
                filePath.isNotEmpty &&
                File(filePath).existsSync()) {
              mreq.files.add(
                await http.MultipartFile.fromPath(
                  name,
                  filePath,
                  filename: filename,
                ),
              );
              continue;
            }
            final base64Data = part['base64']?.toString();
            if (base64Data != null && base64Data.isNotEmpty) {
              mreq.files.add(
                http.MultipartFile.fromBytes(
                  name,
                  base64Decode(base64Data),
                  filename: filename,
                ),
              );
            } else {
              mreq.fields[name] = part['value']?.toString() ?? '';
            }
          }
          request = mreq;
        } else {
          final req = http.Request(method, uri);
          if (bodyStr != null) {
            req.body = bodyStr;
          }
          request = req;
        }
        request.headers.addAll(headers);

        // 走系统代理（或显式 proxy 参数），否则被墙站点会 Connection reset
        final client = await createClientWithSystemProxy(
          proxyUrl: (proxy == null || proxy.isEmpty) ? null : proxy,
        );
        try {
          final response = await client
              .send(request)
              .timeout(Duration(seconds: timeoutSec));
          final bytes = await response.stream.toBytes();

          if (wantBase64) {
            return {
              'statusCode': response.statusCode,
              'headers': response.headers,
              'bodyBase64': base64Encode(bytes),
            };
          }
          return {
            'statusCode': response.statusCode,
            'headers': response.headers,
            'body': utf8.decode(bytes, allowMalformed: true),
          };
        } finally {
          client.close();
        }
      } catch (e) {
        return {'error': e.toString()};
      }
    });

    // 注册 JSON 动态 UI 展示函数（供 Aboutme.plugins.ui.showJsonScreen 调用）
    //
    // 后台触发（无 UI 上下文）时返回 success:false 而非 error，
    // 让脚本可以降级处理（如只 toast / 返回结果）而不是捕获异常
    await _engine!.registerFunction('Aboutme_ui_showJsonScreen', ([
      dynamic a,
      dynamic b,
    ]) async {
      try {
        final jsonStr = a?.toString() ?? '';
        if (jsonStr.isEmpty) {
          throw Exception('缺少 JSON 参数');
        }
        final title = b?.toString();
        final decoded = jsonDecode(jsonStr);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('JSON 必须是组件对象（含 type 字段）');
        }

        final context = Get.context;
        if (context == null) {
          return {'success': false, 'reason': 'no_context'};
        }

        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => JsonDynamicScreen(
              title: (title == null || title.isEmpty) ? 'JSON UI' : title,
              widgetJson: decoded,
            ),
          ),
        );
        return {'success': true};
      } catch (e) {
        return {'error': e.toString()};
      }
    });

    // 在 JS 中创建 http 命名空间
    await _engine!.evaluateDirect('''
      (function() {
        var namespace = globalThis.Aboutme;

        namespace.http = {
          request: function(opts) {
            if (!opts || typeof opts !== 'object') {
              return Promise.reject(new Error('request 需要参数对象 {url, method, headers, body, timeout}'));
            }
            return Aboutme_http_request(opts);
          }
        };
      })();
    ''');
  }

  /// 注册事件系统 API
  Future<void> _registerEventAPIs() async {
    if (_engine == null) return;

    // 1. events.on - 订阅事件
    await _engine!.registerFunction('Aboutme_events_on', ([
      dynamic a,
      dynamic b,
    ]) async {
      try {
        final eventName = a as String?;
        // b 是 JavaScript 函数,无法直接传递到 Dart
        // 这里需要使用回调机制

        if (eventName == null || eventName.isEmpty) {
          throw Exception('on() 需要提供事件名称参数');
        }

        // 先声明订阅 ID 变量
        late String subscriptionId;

        // 生成唯一的订阅 ID
        subscriptionId = EventManager.instance.subscribe(eventName, (args) {
          // 将事件参数序列化并传递给 JavaScript
          final eventData = {
            'eventName': args.eventName,
            'whenOccurred': args.whenOccurred.toIso8601String(),
            'data': args is ItemEventArgs
                ? {
                    'itemId': args.itemId,
                    'title': args.title,
                    'action': args.action,
                  }
                : {},
          };

          // 调用 JavaScript 回调
          // 注意: 这里需要通过事件队列机制来触发 JS 回调
          // 当前实现仅返回订阅 ID,实际回调需要在 JS 端轮询事件队列
          _eventQueue.putIfAbsent(subscriptionId, () => []).add(eventData);
        });

        return subscriptionId;
      } catch (e) {
        print('[Events API] on 失败: $e');
        return jsonEncode({'error': e.toString()});
      }
    });

    // 2. events.off - 取消订阅
    await _engine!.registerFunction('Aboutme_events_off', ([dynamic a]) async {
      try {
        final subscriptionId = a as String?;

        if (subscriptionId == null || subscriptionId.isEmpty) {
          throw Exception('off() 需要提供订阅 ID 参数');
        }

        // 使用 EventManager 的 unsubscribeById 方法
        final success = EventManager.instance.unsubscribeById(subscriptionId);

        // 清理事件队列
        _eventQueue.remove(subscriptionId);

        return jsonEncode({'success': success});
      } catch (e) {
        print('[Events API] off 失败: $e');
        return jsonEncode({'error': e.toString()});
      }
    });

    // 3. events.getEvents - 获取队列中的事件
    await _engine!.registerFunction('Aboutme_events_getEvents', ([
      dynamic a,
    ]) async {
      try {
        final subscriptionId = a as String?;

        if (subscriptionId == null || subscriptionId.isEmpty) {
          throw Exception('getEvents() 需要提供订阅 ID 参数');
        }

        final events = _eventQueue[subscriptionId] ?? [];
        _eventQueue[subscriptionId] = []; // 清空队列

        return jsonEncode(events);
      } catch (e) {
        print('[Events API] getEvents 失败: $e');
        return jsonEncode({'error': e.toString()});
      }
    });

    // 在 JS 中创建事件 API 代理
    await _engine!.evaluateDirect('''
      (function() {
        var namespace = globalThis.Aboutme;

        // 创建 events 命名空间
        namespace.events = {
          _subscriptions: {},
          _pollingIntervals: {}
        };

        // on - 订阅事件
        namespace.events.on = function(eventName, handler) {
          if (!eventName || typeof handler !== 'function') {
            throw new Error('on(eventName, handler) 需要事件名称和处理函数');
          }

          // 调用 Dart 端注册订阅
          return Aboutme_events_on(eventName).then(function(subscriptionId) {
            if (typeof subscriptionId === 'string' && subscriptionId.startsWith('sub_')) {
              // 保存订阅信息
              namespace.events._subscriptions[subscriptionId] = {
                eventName: eventName,
                handler: handler
              };

              // 启动轮询(每500ms检查一次新事件)
              namespace.events._pollingIntervals[subscriptionId] = setInterval(function() {
                Aboutme_events_getEvents(subscriptionId).then(function(result) {
                  var events = typeof result === 'string' ? JSON.parse(result) : result;
                  if (Array.isArray(events)) {
                    events.forEach(function(event) {
                      try {
                        handler(event);
                      } catch (e) {
                        console.error('事件处理函数错误:', e);
                      }
                    });
                  }
                });
              }, 500);

              return subscriptionId;
            } else {
              throw new Error('订阅失败: ' + subscriptionId);
            }
          });
        };

        // off - 取消订阅
        namespace.events.off = function(subscriptionId) {
          if (!subscriptionId) {
            throw new Error('off(subscriptionId) 需要订阅 ID');
          }

          // 停止轮询
          if (namespace.events._pollingIntervals[subscriptionId]) {
            clearInterval(namespace.events._pollingIntervals[subscriptionId]);
            delete namespace.events._pollingIntervals[subscriptionId];
          }

          // 移除订阅信息
          delete namespace.events._subscriptions[subscriptionId];

          // 调用 Dart 端取消订阅
          return Aboutme_events_off(subscriptionId).then(function(result) {
            if (typeof result === 'string') {
              try {
                return JSON.parse(result);
              } catch (e) {
                return result;
              }
            }
            return result;
          });
        };
      })();
    ''');
  }

  /// 注册工具调用 API（步骤间结果传递）
  Future<void> _registerToolCallAPIs() async {
    if (_engine == null) return;

    // 1. setResult - 设置结果
    await _engine!.registerFunction('Aboutme_toolCall_setResult', ([
      dynamic a,
    ]) async {
      try {
        final params = a as Map<String, dynamic>?;
        if (params == null) {
          throw Exception('setResult 需要参数对象 {id?, value}');
        }

        final id = params['id'] as String?;
        final value = params['value'];

        if (value == null) {
          throw Exception('setResult 需要提供 value 参数');
        }

        setToolCallResult(id, value);
        return jsonEncode({'success': true});
      } catch (e) {
        print('[ToolCall API] setResult 失败: $e');
        return jsonEncode({'error': e.toString()});
      }
    });

    // 2. getResult - 获取结果
    await _engine!.registerFunction('Aboutme_toolCall_getResult', ([
      dynamic a,
    ]) async {
      try {
        final params = a as Map<String, dynamic>?;
        if (params == null) {
          throw Exception('getResult 需要参数对象 {id?, step?, default?}');
        }

        final id = params['id'] as String?;
        final step = params['step'] as int?;
        final defaultValue = params['default'];

        final result = getToolCallResult(id, step, defaultValue);

        // 序列化结果
        return _serializeResult(result);
      } catch (e) {
        print('[ToolCall API] getResult 失败: $e');
        return jsonEncode({'error': e.toString()});
      }
    });

    // 在 JS 中创建 toolCall API 代理
    await _engine!.evaluateDirect('''
      (function() {
        var namespace = globalThis.Aboutme;

        // 创建 toolCall 命名空间
        namespace.toolCall = {};

        // setResult API
        namespace.toolCall.setResult = function(params) {
          if (!params || typeof params !== 'object') {
            throw new Error('setResult 需要参数对象 {id?, value}');
          }
          return Aboutme_toolCall_setResult(params).then(function(result) {
            if (typeof result === 'string') {
              try {
                return JSON.parse(result);
              } catch (e) {
                return result;
              }
            }
            return result;
          });
        };

        // getResult API
        namespace.toolCall.getResult = function(params) {
          if (!params || typeof params !== 'object') {
            throw new Error('getResult 需要参数对象 {id?, step?, default?}');
          }
          return Aboutme_toolCall_getResult(params).then(function(result) {
            if (typeof result === 'string') {
              try {
                return JSON.parse(result);
              } catch (e) {
                return result;
              }
            }
            return result;
          });
        };

        // getCurrentStep - 获取当前步骤索引（只读）
        namespace.toolCall.getCurrentStep = function() {
          // 这个值由 Dart 端在执行时设置，这里只是占位
          return -1;
        };
      })();
    ''');
  }

  /// 获取平台名称
  String _getPlatformName() {
    if (kIsWeb) return 'web';

    // 使用 Platform 类判断平台
    try {
      // 需要导入 dart:io 并使用条件导入
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime, String format) {
    final weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

    String result = format;

    // 替换占位符
    result = result.replaceAll(
      'yyyy',
      dateTime.year.toString().padLeft(4, '0'),
    );
    result = result.replaceAll('MM', dateTime.month.toString().padLeft(2, '0'));
    result = result.replaceAll('dd', dateTime.day.toString().padLeft(2, '0'));
    result = result.replaceAll('HH', dateTime.hour.toString().padLeft(2, '0'));
    result = result.replaceAll(
      'hh',
      (dateTime.hour % 12).toString().padLeft(2, '0'),
    );
    result = result.replaceAll(
      'mm',
      dateTime.minute.toString().padLeft(2, '0'),
    );
    result = result.replaceAll(
      'ss',
      dateTime.second.toString().padLeft(2, '0'),
    );
    result = result.replaceAll('E', weekdayNames[dateTime.weekday - 1]);

    return result;
  }

  /// 序列化结果
  String _serializeResult(dynamic result) {
    if (result == null) {
      return 'null';
    } else if (result is String) {
      // 如果已经是 JSON 字符串，直接返回
      try {
        jsonDecode(result);
        return result;
      } catch (e) {
        // 不是 JSON，包装成字符串
        return jsonEncode(result);
      }
    } else if (result is bool || result is num) {
      return result.toString();
    } else {
      // 对象或列表，序列化为 JSON
      try {
        return jsonEncode(result);
      } catch (e) {
        return jsonEncode({'error': 'Failed to serialize result: $e'});
      }
    }
  }

  /// 获取已注册的插件
  PluginBase? getPlugin(String id) => _registeredPlugins[id];

  final PluginToolRegistry pluginTools = PluginToolRegistry();

  /// 获取所有已注册的插件 ID
  List<String> get registeredPluginIds => _registeredPlugins.keys.toList();

  /// 各插件注册的 JS API 名注册表
  ///
  /// 声明为 nullable 以防御热重载：新增字段的初始化器不会作用于
  /// 已存在的单例实例（热重载后为 null），使用处需判空回退注册
  Map<String, Set<String>>? _pluginApiNames;

  /// 下载远端文件到临时文件（走系统代理），失败返回 null
  static Future<File?> _downloadToTemp(
    String url, {
    String? proxy,
    int timeoutSec = 120,
  }) async {
    try {
      final client = await createClientWithSystemProxy(
        proxyUrl: (proxy == null || proxy.isEmpty) ? null : proxy,
      );
      try {
        final resp = await client
            .get(Uri.parse(url))
            .timeout(Duration(seconds: timeoutSec));
        if (resp.statusCode != 200) return null;
        final name = url.replaceFirst(RegExp(r'[?#].*$'), '').split('/').last;
        final tmp = File(
          '${Directory.systemTemp.path}/aboutme_dl_${DateTime.now().millisecondsSinceEpoch}_${name.isEmpty ? 'file' : name}',
        );
        await tmp.writeAsBytes(resp.bodyBytes);
        return tmp;
      } finally {
        client.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// 解析 (pluginId, methodName) 到 JS API 实际注册的插件命名空间。
  ///
  /// 工具描述文件的 pluginId 可能与 JS API 实际注册插件不一致
  /// （如 moments.json / memory.json 描述的方法都挂在 openai 插件下）：
  /// 先精确匹配原插件，miss 则按注册顺序全局搜方法名。
  /// 注册表为空（热重载后未重新注册）返回 null，由调用方回退原插件。
  (String, String)? resolvePluginApi(String pluginId, String methodName) {
    final names = _pluginApiNames;
    if (names == null || names.isEmpty) return null;
    if (names[pluginId]?.contains(methodName) == true) {
      return (pluginId, methodName);
    }
    for (final entry in names.entries) {
      if (entry.value.contains(methodName)) {
        return (entry.key, methodName);
      }
    }
    return null;
  }

  // ==================== 工具调用上下文管理 ====================

  /// 初始化工具调用上下文
  void initToolCallContext(String toolCallId) {
    _toolCallContexts[toolCallId] = {};
    print('[JSBridge] 初始化工具调用上下文: $toolCallId');
  }

  /// 清除工具调用上下文
  void clearToolCallContext(String toolCallId) {
    _toolCallContexts.remove(toolCallId);
    if (_currentToolCallId == toolCallId) {
      _currentToolCallId = null;
      _currentStepIndex = -1;
    }
    print('[JSBridge] 清除工具调用上下文: $toolCallId');
  }

  /// 设置当前执行上下文（工具调用ID和步骤索引）
  void setCurrentExecution(String toolCallId, int stepIndex) {
    _currentToolCallId = toolCallId;
    _currentStepIndex = stepIndex;
  }

  /// 在工具调用上下文中设置结果
  ///
  /// 从 JavaScript 中调用: await Aboutme.toolCall.setResult({id: 'myKey', value: {...}})
  /// 从 Dart 中调用: jsBridge.setToolCallResult('myKey', value)
  void setToolCallResult(String? id, dynamic value) {
    if (_currentToolCallId == null) {
      throw Exception('没有活动的工具调用上下文');
    }

    final context = _toolCallContexts[_currentToolCallId];
    if (context == null) {
      throw Exception('工具调用上下文不存在: $_currentToolCallId');
    }

    // 使用自定义 ID 或当前步骤索引作为键
    final key = id ?? 'step_$_currentStepIndex';
    context[key] = value;
    print('[JSBridge] 设置结果: $key = $value');
  }

  /// 从工具调用上下文中获取结果
  ///
  /// 从 JavaScript 中调用:
  /// - await Aboutme.toolCall.getResult({id: 'myKey'})
  /// - await Aboutme.toolCall.getResult({step: 0})
  /// - await Aboutme.toolCall.getResult({id: 'myKey', default: {}})
  /// 从 Dart 中调用: jsBridge.getToolCallResult('myKey', null, defaultValue)
  dynamic getToolCallResult(String? id, int? step, dynamic defaultValue) {
    if (_currentToolCallId == null) {
      if (defaultValue != null) {
        return defaultValue;
      }
      throw Exception('没有活动的工具调用上下文');
    }

    final context = _toolCallContexts[_currentToolCallId];
    if (context == null) {
      if (defaultValue != null) {
        return defaultValue;
      }
      throw Exception('工具调用上下文不存在: $_currentToolCallId');
    }

    // 优先使用 ID，其次使用步骤索引
    String key;
    if (id != null) {
      key = id;
    } else if (step != null) {
      key = 'step_$step';
    } else {
      throw Exception('必须提供 id 或 step 参数');
    }

    // 获取结果，如果不存在则返回默认值
    final result = context[key];
    if (result == null && defaultValue != null) {
      return defaultValue;
    }

    print('[JSBridge] 获取结果: $key = $result');
    return result;
  }

  /// 释放资源
  Future<void> dispose() async {
    pluginTools.clear();
    if (_initialized && _engine != null) {
      await _engine!.dispose();
      _registeredPlugins.clear();
      _pluginApiNames?.clear();
      _initialized = false;
      _engine = null;
    }
  }
}
