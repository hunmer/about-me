import 'dart:convert';
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/screens/onboarding/plugin_onboarding_screen.dart';
import 'package:aboutme/screens/onboarding/sample_data_selection_step.dart';
import 'package:flutter/material.dart';
import 'plugin_base.dart';
import 'storage/storage_manager.dart';

/// 插件管理器，负责管理所有已注册的插件
class PluginManager {
  StorageManager? _storageManager;
  static const String _configStorageKey = 'configs/plugin_manager.json';
  Map<String, int> _pluginAccessTimes = {};
  // 插件固定时间（毫秒时间戳），被固定的插件在列表中置顶，
  // 按最后固定时间降序排列
  Map<String, int> _pluginPinnedTimes = {};
  // 已展示过首次引导的插件ID
  Set<String> _onboardingShownPlugins = {};
  Map<String, dynamic> _settings = {'autoOpenLastPlugin': true};
  String? _lastOpenedPluginId; // 最后打开的插件ID
  PluginBase? _currentPlugin; // 当前打开的插件
  // 单例实例
  static final PluginManager _instance = PluginManager._internal();

  // 私有构造函数
  PluginManager._internal();

  // 工厂构造函数
  factory PluginManager() => _instance;

  // 获取单例实例
  static PluginManager get instance => _instance;

  // 设置存储管理器并初始化数据
  Future<void> setStorageManager(StorageManager manager) async {
    _storageManager = manager;
    // 加载合并后的配置文件
    await _loadConfig();
  }

  // 获取存储管理器
  StorageManager? get storageManager => _storageManager;

  final List<PluginBase> _plugins = [];

  /// 注册插件
  Future<void> registerPlugin(PluginBase plugin) async {
    if (!_plugins.any((p) => p.id == plugin.id)) {
      if (_storageManager != null) {
        plugin.setStorageManager(_storageManager!);
      }
      _plugins.add(plugin);
      // 初始化插件（加载数据、设置监听器等）
      await plugin.initialize();
      // 注册到应用程序（设置监听器等）
      await plugin.registerToApp(this, ConfigManager(_storageManager!));

      // 广播插件加载完成事件
      eventManager.broadcast('plugin_loaded', Value(plugin.id));
    }
  }

  /// 获取所有已注册的插件
  /// [sortByRecentlyOpened] 是否按最近打开时间排序
  /// 已固定的插件始终排在最前（按最后固定时间降序）
  List<PluginBase> getAllPlugins({bool sortByRecentlyOpened = false}) {
    if (!sortByRecentlyOpened) {
      return List.unmodifiable(_plugins);
    }

    // 创建插件列表的副本并按访问时间排序
    final sortedPlugins = List<PluginBase>.from(_plugins);
    sortedPlugins.sort((a, b) {
      // 固定的插件置顶，按最后固定时间降序（最近固定的在最前）
      final pinnedA = _pluginPinnedTimes[a.id];
      final pinnedB = _pluginPinnedTimes[b.id];
      if (pinnedA != null && pinnedB == null) return -1;
      if (pinnedA == null && pinnedB != null) return 1;
      if (pinnedA != null && pinnedB != null) {
        return pinnedB.compareTo(pinnedA);
      }
      final timeA = _pluginAccessTimes[a.id] ?? 0;
      final timeB = _pluginAccessTimes[b.id] ?? 0;
      return timeB.compareTo(timeA); // 降序排列，最近的在前
    });
    return List.unmodifiable(sortedPlugins);
  }

  /// 插件是否已固定
  bool isPluginPinned(String id) => _pluginPinnedTimes.containsKey(id);

  /// 切换插件固定状态：固定时记录时间戳并置顶，取消固定则移除
  void togglePluginPin(String id) {
    if (_pluginPinnedTimes.containsKey(id)) {
      _pluginPinnedTimes.remove(id);
    } else {
      _pluginPinnedTimes[id] = DateTime.now().millisecondsSinceEpoch;
    }
    _saveConfig();
  }

  /// 获取所有已注册的插件（向后兼容的getter）
  List<PluginBase> get allPlugins => getAllPlugins();

  /// 获取最近打开的插件
  /// [excludePluginId] 需要排除的插件ID，用于避免返回当前正在使用的插件
  PluginBase? getLastOpenedPlugin({String? excludePluginId}) {
    // 优先使用持久化存储的最后打开的插件ID
    if (_lastOpenedPluginId != null && _lastOpenedPluginId != excludePluginId) {
      final plugin = getPlugin(_lastOpenedPluginId!);
      if (plugin != null) {
        return plugin;
      }
    }

    // 如果没有最后打开的插件记录或该插件不存在，则回退到访问时间排序
    if (_pluginAccessTimes.isEmpty || _plugins.isEmpty) {
      return null;
    }

    // 按访问时间降序排序，并排除指定的插件ID
    var sortedEntries = _pluginAccessTimes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 找到第一个不是被排除ID的插件
    for (var entry in sortedEntries) {
      if (entry.key != excludePluginId) {
        var plugin = getPlugin(entry.key);
        if (plugin != null) {
          return plugin;
        }
      }
    }

    return null;
  }

  /// 根据ID获取插件
  PluginBase? getPlugin(String id) {
    try {
      return _plugins.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 移除插件
  Future<void> removePlugin(String id) async {
    _plugins.removeWhere((p) => p.id == id);
  }

  /// 加载合并后的配置文件
  Future<void> _loadConfig() async {
    if (_storageManager == null) return;

    try {
      final configStr = await _storageManager!.readFile(
        _configStorageKey,
        '{}',
      );
      final config = jsonDecode(configStr) as Map<String, dynamic>;

      // 加载访问时间
      final accessTimes = config['accessTimes'] as Map<String, dynamic>?;
      if (accessTimes != null) {
        _pluginAccessTimes = Map<String, int>.from(
          accessTimes.map((key, value) => MapEntry(key, value as int)),
        );
      }

      // 加载固定时间
      final pinnedTimes = config['pinnedTimes'] as Map<String, dynamic>?;
      if (pinnedTimes != null) {
        _pluginPinnedTimes = Map<String, int>.from(
          pinnedTimes.map((key, value) => MapEntry(key, value as int)),
        );
      }

      // 加载已展示引导的插件
      final onboardingShown = config['onboardingShown'] as List<dynamic>?;
      if (onboardingShown != null) {
        _onboardingShownPlugins = onboardingShown.whereType<String>().toSet();
      }

      // 加载设置
      final settings = config['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        _settings = settings;
      }

      // 加载最后打开的插件ID
      final lastPlugin = config['lastOpenedPlugin'] as String?;
      _lastOpenedPluginId = (lastPlugin?.isNotEmpty ?? false)
          ? lastPlugin
          : null;
    } catch (e) {
      debugPrint('Warning: Failed to load plugin manager config: $e');
    }
  }

  /// 保存合并后的配置文件
  Future<void> _saveConfig() async {
    if (_storageManager == null) return;

    try {
      final config = {
        'accessTimes': _pluginAccessTimes,
        'pinnedTimes': _pluginPinnedTimes,
        'onboardingShown': _onboardingShownPlugins.toList(),
        'settings': _settings,
        'lastOpenedPlugin': _lastOpenedPluginId,
      };
      await _storageManager!.writeFile(_configStorageKey, jsonEncode(config));
    } catch (e) {
      debugPrint('Warning: Failed to save plugin manager config: $e');
    }
  }

  /// 获取当前打开的插件
  PluginBase? getCurrentPlugin() => _currentPlugin;

  /// 获取当前打开的插件ID
  String? getCurrentPluginId() => _currentPlugin?.id;

  /// 从全局路由记录取当前页面所属的插件ID（当前路由为 `/plugin/<id>` 时），
  /// 比 [_currentPlugin] 可靠：后者只在 toHomeScreen 清空，普通返回手势
  /// 后仍保留旧值，用它做排除会把真正最近使用的插件误排除掉。
  /// 栈顶是插件子页面（不带 `/plugin/` 前缀）时，回退取栈内的插件主界面，
  /// 避免把当前插件当作"上次插件"重复打开
  String? getCurrentRoutePluginId() {
    final routeName = RouteHistoryManager.getCurrentContext()?.pageId;
    if (routeName != null && routeName.startsWith('/plugin/')) {
      final rest = routeName.substring('/plugin/'.length);
      final slash = rest.indexOf('/');
      return slash == -1 ? rest : rest.substring(0, slash);
    }
    return RouteHistoryManager.getStackPluginId();
  }

  /// 获取是否自动打开最后使用的插件
  bool get autoOpenLastPlugin =>
      _settings['autoOpenLastPlugin'] as bool? ?? true;

  /// 设置是否自动打开最后使用的插件
  set autoOpenLastPlugin(bool value) {
    _settings['autoOpenLastPlugin'] = value;
    _saveConfig();
  }

  /// 获取最后打开的插件ID
  String? get getLastOpenedPluginId => _lastOpenedPluginId;

  /// 记录插件打开（仅记录，不导航）
  ///
  /// 用于 OpenContainer 等自定义导航场景，需要记录打开历史但不通过 Navigator 导航
  void recordPluginOpen(PluginBase plugin) {
    _currentPlugin = plugin;
    _lastOpenedPluginId = plugin.id;
    _pluginAccessTimes[plugin.id] = DateTime.now().millisecondsSinceEpoch;
    // OpenContainer 等自定义导航的插件页路由名不带 /plugin/ 前缀，
    // 预登记给下一个入栈路由，供路由栈的插件识别（防重复打开）
    RouteHistoryManager.markNextRouteAsPlugin(plugin.id);
    _saveConfig();
  }

  /// 打开插件界面
  void openPlugin(
    BuildContext context,
    PluginBase plugin, {
    bool replaceCurrent = false,
  }) {
    // 检查当前路由是否已经是该插件主界面（openPlugin 推入的路由名），
    // 防止悬浮球等入口把同一插件叠加多层。
    // context 可能来自悬浮球根上下文（ModalRoute.of 为 null），统一
    // 回退到 RouteHistoryManager 的全局路由记录判断
    final currentRouteName =
        ModalRoute.of(context)?.settings.name ??
        RouteHistoryManager.getCurrentContext()?.pageId;
    if (currentRouteName == '/plugin/${plugin.id}') {
      return;
    }
    // 当前停在该插件的子页面时（栈顶路由不带 /plugin/ 前缀），同样不重复入栈
    if (getCurrentRoutePluginId() == plugin.id) {
      return;
    }
    // 记录打开历史
    recordPluginOpen(plugin);
    // 返回行为由 NavigationHelper.smartBack 的返回路由表统一决策
    // （/plugin/<id> → 固定回首页），不要在此包 PopScope——canPop:false
    // 会拦截一切 pop()/popUntil()，与返回逻辑叠加曾导致无限递归崩溃
    // 使用 NavigationHelper.push 以支持 iOS 左滑返回
    final page = plugin.buildMainView(context);
    if (replaceCurrent) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          settings: RouteSettings(name: '/plugin/${plugin.id}'),
          builder: (_) => page,
        ),
      );
    } else {
      NavigationHelper.push(context, page, routeName: '/plugin/${plugin.id}');
    }
    _maybeShowOnboarding(context, plugin);
  }

  /// 首次打开插件时弹出引导页
  ///
  /// 弹出即记录（含跳过场景），后续不再重复弹出；
  /// 引导完成时由引导页自行调用 plugin.onOnboardingComplete，
  /// 声明了示例数据分组的插件会在引导步骤末尾附加「示例数据选择」
  void _maybeShowOnboarding(BuildContext context, PluginBase plugin) {
    if (_onboardingShownPlugins.contains(plugin.id)) return;
    final steps = plugin.getOnboardingSteps(context);
    final sampleGroups = plugin.getSampleDataGroups();
    if (steps.isEmpty && sampleGroups.isEmpty) return;
    _onboardingShownPlugins.add(plugin.id);
    _saveConfig();
    showPluginOnboarding(
      context,
      plugin: plugin,
      steps: [
        ...steps,
        if (sampleGroups.isNotEmpty)
          buildSampleDataSelectionStep(sampleGroups),
      ],
    );
  }

  static toHomeScreen(BuildContext context) {
    PluginManager.instance._currentPlugin = null; // 清除当前插件记录
    // 清除所有历史路由，回到根路由（默认主页：果冻小屋）
    NavigationHelper.returnToHome(context);
  }
}
