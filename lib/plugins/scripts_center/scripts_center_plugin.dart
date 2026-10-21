// ignore_for_file: deprecated_member_use_from_same_package

library;

import 'dart:io';
import 'dart:convert';

import 'package:aboutme/core/services/startup_trace.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/event_args.dart' as event_args;
import 'package:aboutme/core/event/item_event_args.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/core/widgets/lazy_indexed_stack.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/core/services/plugin_data_selector/plugin_data_selector_service.dart';
import 'package:aboutme/core/services/plugin_data_selector/models/selector_definition.dart';
import 'package:aboutme/core/services/plugin_data_selector/models/selector_step.dart';
import 'package:aboutme/core/services/plugin_data_selector/models/selectable_item.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/utils/file_picker_helper.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'services/script_loader.dart';
import 'services/script_manager.dart';
import 'services/script_executor.dart';
import 'services/script_store_manager.dart';
import 'services/script_download_manager.dart';
import 'models/script_folder.dart';
import 'models/script_input.dart';
import 'screens/scripts_list_screen.dart';
import 'screens/script_edit_screen.dart';
import 'screens/script_store_screen.dart';
import 'screens/script_execution_log_screen.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

part 'scripts_center_data_selectors.dart';

/// 深度序列化对象为 JSON 兼容的 Map/List/基本类型（异步版本）
Future<dynamic> _deepSerializeAsync(dynamic value) async {
  // null 值
  if (value == null) {
    return null;
  }

  // 基本类型：String, num, bool
  if (value is String || value is num || value is bool) {
    return value;
  }

  // DateTime 转为 ISO 8601 字符串
  if (value is DateTime) {
    return value.toIso8601String();
  }

  // List 类型：递归序列化每个元素
  if (value is List) {
    final results = <dynamic>[];
    for (final item in value) {
      results.add(await _deepSerializeAsync(item));
    }
    return results;
  }

  // Map 类型：递归序列化每个值
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      result[entry.key.toString()] = await _deepSerializeAsync(entry.value);
    }
    return result;
  }

  // 尝试调用 toJson 方法（如果存在）
  try {
    final dynamic obj = value;
    final jsonResult = obj.toJson();

    // 如果 toJson 返回 Future，等待它
    if (jsonResult is Future) {
      final awaited = await jsonResult;
      return await _deepSerializeAsync(awaited);
    }

    // 递归序列化 toJson 的结果
    return await _deepSerializeAsync(jsonResult);
  } catch (e) {
    // 对象没有 toJson 方法或调用失败，继续尝试其他方法
  }

  // 尝试转换为字符串（最后的兜底方案）
  try {
    return value.toString();
  } catch (e) {
    return '<无法序列化: ${value.runtimeType}>';
  }
}

/// 将 EventArgs 对象序列化为 Map，以便传递给 JavaScript（异步版本）
Future<Map<String, dynamic>> _serializeEventArgsAsync(EventArgs args) async {
  final Map<String, dynamic> result = {
    'eventName': args.eventName,
    'whenOccurred': args.whenOccurred.toIso8601String(),
  };

  // 处理不同类型的 EventArgs 子类
  if (args is ItemEventArgs) {
    result['itemId'] = args.itemId;
    result['title'] = args.title;
    result['action'] = args.action;
  } else if (args is event_args.Value) {
    result['value'] = await _deepSerializeAsync(args.value);
  } else if (args is event_args.Values) {
    result['value1'] = await _deepSerializeAsync(args.value1);
    result['value2'] = await _deepSerializeAsync(args.value2);
  } else if (args is event_args.UpdateEvent) {
    result['version'] = args.version;
    result['forceUpdate'] = args.forceUpdate;
    if (args.changelog != null) {
      result['changelog'] = args.changelog;
    }
  }

  // 深度序列化整个 result，确保所有嵌套对象都被转换
  return await _deepSerializeAsync(result) as Map<String, dynamic>;
}

/// 脚本中心插件
///
/// 提供JS脚本管理、执行和事件触发功能
class ScriptsCenterPlugin extends BasePlugin {
  // 单例模式
  static ScriptsCenterPlugin? _instance;

  static ScriptsCenterPlugin get instance {
    if (_instance == null) {
      _instance =
          PluginManager.instance.getPlugin('scripts_center')
              as ScriptsCenterPlugin?;
      if (_instance == null) {
        throw StateError('ScriptsCenterPlugin has not been initialized');
      }
    }
    return _instance!;
  }

  // 服务实例
  late ScriptLoader _scriptLoader;
  late ScriptManager _scriptManager;
  late ScriptExecutor _scriptExecutor;
  late ScriptStoreManager _scriptStoreManager;
  late ScriptDownloadManager _scriptDownloadManager;

  // 事件订阅ID列表
  final List<String> _subscriptionIds = [];

  @override
  String get id => 'scripts_center';

  @override
  Color get color => Colors.deepPurple;

  @override
  IconData get icon => Icons.code;

  @override
  String? getPluginName(context) {
    return 'scripts_center_scriptCenter'.tr;
  }

  // 获取服务实例的访问器
  ScriptManager get scriptManager => _scriptManager;
  ScriptExecutor get scriptExecutor => _scriptExecutor;
  ScriptStoreManager get scriptStoreManager => _scriptStoreManager;
  ScriptDownloadManager get scriptDownloadManager => _scriptDownloadManager;

  @override
  Future<void> initialize() async {
    try {
      // 初始化服务层
      _scriptLoader = ScriptLoader(storage);
      _scriptManager = ScriptManager(_scriptLoader);
      _scriptStoreManager = ScriptStoreManager(
        storage: storage,
        scriptLoader: _scriptLoader,
      );
      _scriptDownloadManager = ScriptDownloadManager(
        scriptLoader: _scriptLoader,
        scriptStoreManager: _scriptStoreManager,
        scriptManager: _scriptManager,
      );
      _scriptExecutor = ScriptExecutor(
        scriptManager: _scriptManager,
        storage: storage,
        eventManager: EventManager.instance,
      );

      // 初始化JS引擎
      await StartupTrace.measure('scripts.engine', _scriptExecutor.initialize);

      // 初始化默认文件夹
      await StartupTrace.measure('scripts.folders', _initializeDefaultFolders);

      // 恢复缺失的内置脚本（assets 打包分发）
      await StartupTrace.measure(
        'scripts.builtin_sync',
        _scriptLoader.syncBuiltInScripts,
      );

      // 加载当前文件夹的脚本
      await StartupTrace.measure('scripts.load', _scriptManager.loadScripts);

      // 初始化脚本商场
      await StartupTrace.measure(
        'scripts.store_config',
        _scriptStoreManager.initialize,
      );

      // 注册数据选择器
      registerDataSelectors();
    } catch (e) {
      print('❌ ScriptsCenterPlugin初始化失败: $e');
      rethrow;
    }
  }

  /// 初始化默认文件夹
  Future<void> _initializeDefaultFolders() async {
    try {
      final folders = <ScriptFolder>[];

      // 1. 默认脚本文件夹（应用文档目录下的 scripts）
      final defaultScriptsPath = await _scriptLoader.getScriptsDirectory();
      folders.add(
        ScriptFolder(
          id: 'default',
          name: '我的脚本',
          path: defaultScriptsPath,
          isBuiltIn: true,
          enabled: true,
          icon: 'folder',
          description: '默认脚本存储位置',
        ),
      );

      // 初始化文件夹
      await _scriptManager.initializeFolders(folders);
    } catch (e) {
      print('❌ 初始化默认文件夹失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {
    // 插件已在 initialize() 中完成初始化
    // 这里可以添加额外的应用级注册逻辑

    // 延迟设置触发器和执行自动运行脚本，确保其他插件已初始化
    Future.delayed(const Duration(milliseconds: 500), () {
      _setupTriggers();
      _runAutoRunScripts();
    });
  }

  /// 执行自动运行脚本
  void _runAutoRunScripts() async {
    try {
      // 加载所有文件夹的脚本
      final allScripts = await _scriptManager.loadAllScripts();

      // 筛选已启用且开启了自动运行的脚本
      final autoRunScripts =
          allScripts
              .where((script) => script.enabled && script.autoRun)
              .toList();

      if (autoRunScripts.isEmpty) {
        return;
      }

      for (var script in autoRunScripts) {
        try {
          final result = await _scriptExecutor.execute(
            script.id,
            args: const {'trigger': 'auto'},
            instanceId: 'auto_run',
          );

          if (!result.success) {
            print('   ⚠️ 脚本执行失败: ${script.name}');
            print('      错误: ${result.error}');
          }
        } catch (e) {
          print('   ❌ 脚本执行异常: ${script.name}, 错误: $e');
        }
      }
    } catch (e) {
      print('❌ 执行自动运行脚本失败: $e');
    }
  }

  /// 设置事件触发器
  void _setupTriggers() async {
    try {
      // 加载所有文件夹的脚本
      final allScripts = await _scriptManager.loadAllScripts();
      final enabledScripts = allScripts.where((s) => s.enabled).toList();
      final scriptsWithTriggers =
          enabledScripts.where((script) => script.hasTriggers).toList();

      if (scriptsWithTriggers.isEmpty) {
        return;
      }

      for (var script in scriptsWithTriggers) {
        for (var trigger in script.triggers) {
          // 订阅事件
          final subscriptionId = EventManager.instance.subscribe(
            trigger.event,
            (args) async {
              print('🎯 触发事件: ${trigger.event} -> 执行脚本: ${script.name}');

              // 延迟执行
              if (trigger.delay != null && trigger.delay! > 0) {
                await Future.delayed(Duration(milliseconds: trigger.delay!));
              }

              // 执行脚本
              try {
                // 序列化事件数据（异步）
                final eventData = await _serializeEventArgsAsync(args);

                final result = await _scriptExecutor.execute(
                  script.id,
                  args: {'event': trigger.event, 'eventData': eventData},
                  // 事件风暴下单实例：同一事件重复触发时，
                  // 脚本未跑完的重复执行会被拒绝
                  instanceId: 'event:${trigger.event}',
                );

                if (!result.success) {
                  print('⚠️ 脚本执行失败: ${script.name}');
                  print('   错误: ${result.error}');
                } else {
                  print('✅ 脚本执行成功: ${script.name}');
                  print('   耗时: ${result.duration.inMilliseconds}ms');
                }
              } catch (e) {
                print('❌ 脚本执行异常: ${script.name}, 错误: $e');
              }
            },
          );

          _subscriptionIds.add(subscriptionId);
        }
      }
    } catch (e) {
      print('❌ 设置触发器失败: $e');
    }
  }

  /// 重新加载脚本并重新设置触发器
  Future<void> reloadScripts() async {
    try {
      // 取消所有现有订阅
      _clearTriggers();

      // 重新加载脚本
      await _scriptManager.loadScripts();

      // 重新设置触发器
      _setupTriggers();

      print('✅ 脚本重新加载成功');
    } catch (e) {
      print('❌ 脚本重新加载失败: $e');
      rethrow;
    }
  }

  /// 清除所有触发器订阅
  void _clearTriggers() {
    for (var subscriptionId in _subscriptionIds) {
      EventManager.instance.unsubscribeById(subscriptionId);
    }
    _subscriptionIds.clear();
    print('🗑️ 已清除所有触发器订阅');
  }

  @override
  Widget buildMainView(BuildContext context) {
    return const ScriptsCenterMainView();
  }

  @override
  Widget? buildCardView(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          PluginManager.instance.openPlugin(context, this);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'scripts_center_scriptCenter'.tr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    '总数',
                    _scriptManager.scriptCount.toString(),
                  ),
                  _buildStatItem(
                    context,
                    '已启用',
                    _scriptManager.enabledScriptCount.toString(),
                  ),
                  _buildStatItem(
                    context,
                    '触发器',
                    _subscriptionIds.length.toString(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  void dispose() {
    _clearTriggers();
    _scriptExecutor.dispose();
    _scriptManager.dispose();
    _scriptStoreManager.dispose();
    _scriptDownloadManager.dispose();
  }
}

/// 脚本中心主视图
class ScriptsCenterMainView extends StatefulWidget {
  const ScriptsCenterMainView({super.key});

  @override
  State<ScriptsCenterMainView> createState() => _ScriptsCenterMainViewState();
}

class _ScriptsCenterMainViewState extends State<ScriptsCenterMainView> {
  late ScriptsCenterPlugin _plugin;
  /// 脚本列表页搜索词（外层导航栏搜索框驱动）
  String _searchQuery = '';

  /// 脚本商场页搜索词（外层导航栏搜索框驱动）
  String _storeSearchQuery = '';

  /// 底部导航当前页签：0 脚本 / 1 执行记录 / 2 脚本商场
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _plugin =
        PluginManager.instance.getPlugin('scripts_center')
            as ScriptsCenterPlugin;
    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRouteContext(_currentIndex);
    });
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前页签状态
  /// （页签首次访问后保活，再次切换不触发子页 initState）
  void _updateRouteContext(int index) {
    if (!mounted) return;
    const pageIds = [
      '/scripts_center',
      '/scripts_center/logs',
      '/scripts_center/store',
    ];
    const titles = ['脚本', '执行记录', '插件商场'];
    RouteHistoryManager.updateCurrentContext(
      pageId: pageIds[index.clamp(0, pageIds.length - 1)],
      title: titles[index.clamp(0, titles.length - 1)],
      params: {'tabIndex': index},
    );
  }

  void _setSearchQuery(String query) {
    setState(() {
      // 搜索词按页签分发：脚本列表 / 脚本商场各自持有
      if (_currentIndex == 2) {
        _storeSearchQuery = query;
      } else {
        _searchQuery = query;
      }
    });
  }

  /// 底部导航子栏右侧圆钮：新建/导入脚本菜单
  void _showCreateMenu() {
    SmoothBottomSheet.show(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: Text('scripts_center_newScript'.tr),
            onTap: () {
              Navigator.pop(context);
              _showCreateScriptDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text('scripts_center_importJsFile'.tr),
            onTap: () {
              Navigator.pop(context);
              _showImportScriptDialog(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabTitles = [
      'scripts_center_scriptCenter'.tr,
      '执行记录',
      'scripts_center_scriptStore'.tr,
    ];
    return SuperCupertinoNavigationWrapper(
      title: Text(tabTitles[_currentIndex]),
      largeTitle: tabTitles[_currentIndex],
      enableLargeTitle: true,
      // 搜索栏作用于脚本列表页签与脚本商场页签
      enableSearchBar: _currentIndex == 0 || _currentIndex == 2,
      searchPlaceholder: 'scripts_center_search'.tr,
      onSearchChanged: _setSearchQuery,
      onSearchSubmitted: _setSearchQuery,

      // 三个页签共用外层 header，首次访问后保留各页签状态。
      // 弧形底部导航经内层 Scaffold 停靠屏幕底部（wrapper 的
      // bottomBarChild 参数实际不生效），extendBody 让内容延伸到栏下
      body: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: LazyIndexedStack(
          index: _currentIndex,
          builders: [
            (_) => ScriptsListScreen(
              scriptManager: _plugin.scriptManager,
              scriptExecutor: _plugin.scriptExecutor,
              searchQuery: _searchQuery,
            ),
            (_) => ScriptExecutionLogScreen(
              logger: _plugin.scriptExecutor.executionLogger,
              executor: _plugin.scriptExecutor,
              embedded: true,
            ),
            (_) => MultiProvider(
              providers: [
                ChangeNotifierProvider.value(
                  value: _plugin.scriptStoreManager,
                ),
                ChangeNotifierProvider.value(
                  value: _plugin.scriptDownloadManager,
                ),
                ChangeNotifierProvider.value(value: _plugin.scriptManager),
              ],
              child: ScriptStoreScreen(
                embedded: true,
                searchQuery: _storeSearchQuery,
              ),
            ),
          ],
        ),

        // 底部弧形导航：脚本 / 执行记录 / 脚本商场
        bottomNavigationBar: DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.all(theme.spacing.lg),
                  child: DSBottomNavigation(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                      _updateRouteContext(index);
                    },
                    // 子栏右侧圆钮：新建/导入脚本菜单（无子栏胶囊，
                    // 恒传 never 保持仅 dock 的紧凑占位）
                    trailingAction: DsIcon(
                      DsIconKind.plus,
                      size: 16,
                      color: theme.primary,
                    ),
                    onTrailingTap: _showCreateMenu,
                    subBarBehavior: RadialSubBarBehavior.never,
                    items: const [
                      DSNavItem(icon: DsIconKind.code, label: '脚本'),
                      DSNavItem(icon: DsIconKind.clock, label: '执行记录'),
                      DSNavItem(icon: DsIconKind.store, label: '插件商场'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateScriptDialog(BuildContext context) async {
    final result = await NavigationHelper.push<Map<String, dynamic>>(
      context,
      ScriptEditScreen(script: null, scriptManager: _plugin.scriptManager),
    );

    if (result == null) return;

    try {
      // 使用统一的保存方法
      await _plugin.scriptManager.saveScriptFromEditResult(result);

      // 重新设置触发器
      await _plugin.reloadScripts();
      Toast.success('脚本创建成功！');
    } catch (e) {
      Toast.error('操作失败: $e');
    }
  }

  /// 显示导入脚本对话框
  Future<void> _showImportScriptDialog(BuildContext context) async {
    // 选择JS文件
    final files = await FilePickerHelper.pickFiles(multiple: false);
    if (files.isEmpty) return;

    final file = files.first;

    try {
      // 读取JS文件内容
      final jsContent = await file.readAsString();

      // 检查同目录下是否有metadata.json
      Map<String, dynamic>? metadata;
      String? localScriptPath = file.path;

      final metadataFile = File('${file.parent.path}/metadata.json');
      if (await metadataFile.exists()) {
        try {
          final metadataContent = await metadataFile.readAsString();
          metadata = jsonDecode(metadataContent) as Map<String, dynamic>;
        } catch (e) {
          print('读取metadata.json失败: $e');
        }
      }

      // 解析metadata中的数据
      Map<String, dynamic>? initialData;
      if (metadata != null) {
        initialData = {
          'id': metadata['id'], // 添加id字段
          'name': metadata['name'],
          'description': metadata['description'],
          'author': metadata['author'],
          'version': metadata['version'],
          'icon': metadata['icon'],
          'code': jsContent,
          'configFormFields': metadata['configFormFields'],
          'localScriptPath': localScriptPath,
          // 解析inputs
          if (metadata['inputs'] != null)
            'inputs':
                (metadata['inputs'] as List<dynamic>)
                    .map((e) => ScriptInput.fromJson(e as Map<String, dynamic>))
                    .toList(),
          // 解析triggers
          if (metadata['triggers'] != null) 'triggers': metadata['triggers'],
          // 解析config
          if (metadata['config'] != null) 'config': metadata['config'],
        };
      } else {
        initialData = {'code': jsContent, 'localScriptPath': localScriptPath};
      }

      // 跳转到编辑页面，传入初始数据
      final result = await NavigationHelper.push<Map<String, dynamic>>(
        context,
        ScriptEditScreen(
          script: null,
          scriptManager: _plugin.scriptManager,
          initialData: initialData,
        ),
      );

      if (result == null) return;

      // 使用统一的保存方法
      await _plugin.scriptManager.saveScriptFromEditResult(result);

      // 重新设置触发器
      await _plugin.reloadScripts();
      Toast.success('脚本导入成功！');
    } catch (e) {
      Toast.error('导入失败: $e');
    }
  }
}
