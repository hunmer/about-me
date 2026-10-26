import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'page_visit_record.dart';

/// 路由历史管理器
///
/// 负责记录和管理页面访问历史，支持持久化存储
/// 可作为 NavigatorObserver 自动记录路由变化
// RouteAware 只接收遮住底层页面的路由通知；部分弹层也继承 PageRoute。
class RouteHistoryManager extends RouteObserver<PageRoute<dynamic>> {
  static final RouteHistoryManager _instance = RouteHistoryManager._internal();
  factory RouteHistoryManager() => _instance;
  RouteHistoryManager._internal();

  static RouteHistoryManager get instance => _instance;

  /// 存储管理器
  StorageManager? _storage;

  /// 存储键（system 域 config 命令统一通道，configs/ 前缀原位落盘）
  static const String _storageKey = 'route_history.json';

  /// 历史记录列表（按时间倒序）
  final List<PageVisitRecord> _history = [];

  /// 最大历史记录数
  static const int _maxHistorySize = 100;

  /// 并发锁
  bool _isSaving = false;

  /// 是否已初始化
  bool _initialized = false;

  /// 当前路由上下文（内存中，不持久化）
  /// 用于"询问当前上下文"功能获取当前页面信息
  PageVisitRecord? _currentRouteContext;

  /// 当前栈顶的页面路由（有路由名的才算页面，弹层/对话框不算）
  /// 用于把页面手动设置的上下文绑定到路由
  Route<dynamic>? _currentTopPageRoute;

  /// 各页面路由手动设置过的上下文（弱引用，路由销毁后条目可回收）
  /// pop 返回页面时优先按它恢复，避免只按路由名恢复而丢失 channelId 等参数
  final Expando<PageVisitRecord> _manualRouteContexts = Expando();

  /// 路由栈中插件主界面路由的层数
  int _pluginRouteCount = 0;

  /// 栈内最上层插件主界面所属的插件ID
  String? _stackTopPluginId;

  /// 待认领的插件ID：recordPluginOpen 在 push 插件页面之前设置，
  /// 下一个入栈的非 `/plugin/` 前缀路由认领它（OpenContainer 等自定义导航
  /// 的插件页路由名不带 `/plugin/` 前缀，无法从路由名识别所属插件）
  String? _pendingPluginId;

  /// 已认领的非 `/plugin/` 前缀路由名 → 插件ID
  final Map<String, String> _routePluginOwners = {};

  /// 初始化管理器（从存储加载历史记录）
  Future<void> initialize({StorageManager? storage}) async {
    if (_initialized) return;

    // 设置存储管理器
    if (storage != null) {
      _storage = storage;
    }

    if (_storage == null) {
      debugPrint('RouteHistoryManager: 存储管理器未设置，跳过初始化');
      return;
    }

    try {
      final data = await AboutmeDataService.instance.getConfig(_storageKey);
      if (data != null) {
        // 使用 Map.from() 进行安全的类型转换
        final json = Map<String, dynamic>.from(data as Map);
        final historyList = json['history'] as List<dynamic>?;

        if (historyList != null) {
          _history.clear();
          for (final item in historyList) {
            try {
              // 使用 Map.from() 进行安全的类型转换
              final record = PageVisitRecord.fromJson(Map<String, dynamic>.from(item as Map));
              _history.add(record);
            } catch (e) {
              debugPrint('解析历史记录失败: $e');
            }
          }

          // 按时间倒序排序
          _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }
      }
    } catch (e) {
      debugPrint('加载路由历史失败: $e');
    }

    _initialized = true;
  }

  /// 记录页面访问
  ///
  /// [pageId] 页面唯一标识符
  /// [title] 页面标题
  /// [icon] 页面图标（可选）
  /// [params] 附加参数（可选）
  static Future<void> recordPageVisit({
    required String pageId,
    required String title,
    IconData? icon,
    Map<String, dynamic>? params,
  }) async {
    final manager = instance;

    // 确保已初始化
    if (!manager._initialized) {
      await manager.initialize();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final iconCodePoint = icon?.codePoint;

    // 查找是否已存在该页面的记录
    final existingIndex = manager._history.indexWhere((record) => record.pageId == pageId);

    if (existingIndex != -1) {
      // 更新现有记录
      final existing = manager._history[existingIndex];
      manager._history[existingIndex] = existing.copyWith(
        timestamp: now,
        visitCount: existing.visitCount + 1,
        title: title, // 更新标题（可能有变化）
        iconCodePoint: iconCodePoint,
        params: params,
      );
    } else {
      // 创建新记录
      final record = PageVisitRecord(
        pageId: pageId,
        title: title,
        iconCodePoint: iconCodePoint,
        timestamp: now,
        visitCount: 1,
        params: params,
      );
      manager._history.insert(0, record);
    }

    // 按时间重新排序
    manager._history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // 限制历史记录数量
    if (manager._history.length > _maxHistorySize) {
      manager._history.removeRange(_maxHistorySize, manager._history.length);
    }

    // 异步保存
    manager._saveHistory();

    debugPrint('记录页面访问: $pageId ($title), 总访问次数: ${manager._history[manager._history.indexWhere((r) => r.pageId == pageId)].visitCount}');
  }

  /// 获取上次访问的页面（排除指定页面）
  ///
  /// [excludePageId] 要排除的页面ID（通常是当前页面）
  static PageVisitRecord? getLastVisitedPage({String? excludePageId}) {
    final manager = instance;

    if (manager._history.isEmpty) return null;

    if (excludePageId == null) {
      return manager._history.first;
    }

    // 查找第一个不是排除页面的记录
    for (final record in manager._history) {
      if (record.pageId != excludePageId) {
        return record;
      }
    }

    return null;
  }

  /// 获取历史记录列表
  ///
  /// [limit] 限制返回数量（默认不限制）
  /// [excludePageId] 排除指定页面（可选）
  static List<PageVisitRecord> getHistory({int? limit, String? excludePageId}) {
    final manager = instance;

    var history = manager._history;

    // 排除指定页面
    if (excludePageId != null) {
      history = history.where((record) => record.pageId != excludePageId).toList();
    }

    // 限制数量
    if (limit != null && limit < history.length) {
      return history.sublist(0, limit);
    }

    return List.unmodifiable(history);
  }

  /// 清空历史记录
  static Future<void> clearHistory() async {
    final manager = instance;
    manager._history.clear();
    await manager._saveHistory();
    debugPrint('路由历史已清空');
  }

  /// 删除指定页面的历史记录
  ///
  /// [pageId] 要删除的页面ID
  static Future<void> removePageHistory(String pageId) async {
    final manager = instance;
    manager._history.removeWhere((record) => record.pageId == pageId);
    await manager._saveHistory();
    debugPrint('已删除页面历史: $pageId');
  }

  /// 获取指定页面的访问次数
  ///
  /// [pageId] 页面ID
  static int getVisitCount(String pageId) {
    final manager = instance;
    final record = manager._history.firstWhere(
      (r) => r.pageId == pageId,
      orElse: () => PageVisitRecord(
        pageId: '',
        title: '',
        timestamp: 0,
        visitCount: 0,
      ),
    );
    return record.visitCount;
  }

  /// 保存历史记录到存储
  Future<void> _saveHistory() async {
    if (_isSaving) return; // 防止并发保存
    if (_storage == null) return; // 存储未初始化

    _isSaving = true;
    try {
      // system 域 config 命令为事务写，无文件层 412 版本冲突
      await AboutmeDataService.instance.setConfig(_storageKey, {
        'history': _history.map((record) => record.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('保存路由历史失败: $e');
    } finally {
      _isSaving = false;
    }
  }

  /// 获取历史记录统计信息
  static Map<String, dynamic> getStatistics() {
    final manager = instance;

    if (manager._history.isEmpty) {
      return {
        'totalPages': 0,
        'totalVisits': 0,
        'mostVisitedPage': null,
      };
    }

    final totalVisits = manager._history.fold<int>(
      0,
      (sum, record) => sum + record.visitCount,
    );

    final mostVisited = manager._history.reduce(
      (current, next) => current.visitCount > next.visitCount ? current : next,
    );

    return {
      'totalPages': manager._history.length,
      'totalVisits': totalVisits,
      'mostVisitedPage': mostVisited,
    };
  }

  // ==================== NavigatorObserver 实现 ====================

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic> && route.opaque) {
      super.didPush(route, previousRoute);
    } else {
      debugPrint('RouteHistoryManager: 跳过弹层 didPushNext type=${route.runtimeType}');
    }
    debugPrint(
      'RouteHistoryManager: didPush name=${route.settings.name} '
      'type=${route.runtimeType}');
    _claimPendingPluginRoute(route);
    _trackPluginRoute(route, 1);
    if (_hasRouteName(route)) {
      _currentTopPageRoute = route;
    }
    _recordRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic> && route.opaque) {
      super.didPop(route, previousRoute);
    } else {
      debugPrint('RouteHistoryManager: 跳过弹层 didPopNext type=${route.runtimeType}');
    }
    _trackPluginRoute(route, -1, previousRoute);
    // pop 操作不记录新路由，但可以更新当前上下文到前一个路由。
    // 弹出的若是弹层/对话框（无路由名），上下文一直描述其下方页面，无需恢复
    if (previousRoute != null && _hasRouteName(route)) {
      _restoreContextForRoute(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) {
      _trackPluginRoute(oldRoute, -1);
    }
    if (newRoute != null) {
      _claimPendingPluginRoute(newRoute);
      _trackPluginRoute(newRoute, 1);
      if (_hasRouteName(newRoute)) {
        _currentTopPageRoute = newRoute;
      }
      _recordRoute(newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _trackPluginRoute(route, -1, previousRoute);
  }

  /// 让刚入栈的路由认领 [markNextRouteAsPlugin] 登记的插件
  void _claimPendingPluginRoute(Route<dynamic> route) {
    final pending = _pendingPluginId;
    if (pending == null) return;
    _pendingPluginId = null;
    final name = route.settings.name;
    // 无名路由（对话框等）与自带插件信息的前缀路由不需要认领
    if (name == null || name.startsWith('/plugin/')) return;
    _routePluginOwners[name] = pending;
  }

  /// 解析路由所属的插件ID；非插件路由返回 null
  String? _pluginIdOfRoute(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null) return null;
    if (name.startsWith('/plugin/')) {
      final rest = name.substring('/plugin/'.length);
      final slash = rest.indexOf('/');
      final id = slash == -1 ? rest : rest.substring(0, slash);
      return id.isEmpty ? null : id;
    }
    return _routePluginOwners[name];
  }

  /// 维护栈内插件主界面路由的计数与栈顶插件
  ///
  /// [delta] 入栈为 1、出栈为 -1；[revealedRoute] 出栈后露出的下层路由，
  /// 若它也是插件主界面则回写为栈内最新插件
  void _trackPluginRoute(Route<dynamic> route, int delta,
      [Route<dynamic>? revealedRoute]) {
    final pluginId = _pluginIdOfRoute(route);
    if (pluginId != null) {
      _pluginRouteCount += delta;
      if (_pluginRouteCount <= 0) {
        _pluginRouteCount = 0;
        _stackTopPluginId = null;
      } else if (delta > 0) {
        _stackTopPluginId = pluginId;
      }
      if (delta < 0) {
        // 登记制路由出栈后释放映射，避免路由名复用时串到旧插件
        final name = route.settings.name;
        if (name != null && !name.startsWith('/plugin/')) {
          _routePluginOwners.remove(name);
        }
      }
    } else if (delta > 0) {
      // 无关页面（设置页、无名对话框等）入栈后栈顶不再是插件页面：
      // 清掉栈顶插件标记，pop 回插件主界面时由下方 revealedRoute 逻辑
      // 恢复。否则压在插件上的页面会被 openPlugin 误判为该插件的
      // 子页面而拒绝跳转
      _stackTopPluginId = null;
    }
    if (revealedRoute != null) {
      final revealedId = _pluginIdOfRoute(revealedRoute);
      if (revealedId != null) {
        _stackTopPluginId = revealedId;
      }
    }
  }

  /// 登记下一个入栈路由所属的插件（OpenContainer 等自定义导航场景，
  /// 由 PluginManager.recordPluginOpen 在 push 插件页之前调用）
  static void markNextRouteAsPlugin(String pluginId) {
    instance._pendingPluginId = pluginId;
  }

  /// 获取当前路由栈中插件主界面所属的插件ID
  ///
  /// 栈顶是插件子页面（路由名不带 `/plugin/` 前缀）时，栈内下方
  /// 仍有插件主界面，返回该插件ID；栈内没有插件路由时返回 null
  static String? getStackPluginId() => instance._stackTopPluginId;


  /// 从 Route 对象记录路由访问
  void _recordRoute(Route<dynamic> route) {
    final routeName = route.settings.name;

    // 只有设置了路由名称的才能记录到历史（用于复原跳转）
    if (routeName == null || routeName.isEmpty) {
      // 弹层/对话框（无路由名）不是页面导航，
      // 不覆盖当前上下文（否则会丢掉页面手动设置的 channelId 等参数）
      return;
    }

    // 从 RouteSettings.arguments 提取参数
    final args = route.settings.arguments;

    // 更新当前路由上下文（用于"询问当前上下文"功能）
    _currentRouteContext = PageVisitRecord(
      pageId: routeName,
      title: routeName,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      visitCount: 1,
      params: _extractParams(args),
    );
    debugPrint('RouteHistoryManager: 更新当前路由上下文 "$routeName"（observer），参数: ${_currentRouteContext!.params}');

    // 异步记录到历史（不阻塞 UI）
    _recordToHistory(routeName, args);
  }

  /// 从 Route 对象更新当前上下文
  void _updateCurrentContextFromRoute(Route<dynamic> route) {
    final routeName = route.settings.name;
    final args = route.settings.arguments;
    final now = DateTime.now().millisecondsSinceEpoch;

    _currentRouteContext = PageVisitRecord(
      pageId: routeName ?? 'unknown',
      title: routeName ?? 'Unknown Route',
      timestamp: now,
      visitCount: 1,
      params: _extractParams(args),
    );
  }

  /// 路由是否带有效名字（页面路由）；无名字的视为弹层/对话框
  bool _hasRouteName(Route<dynamic> route) {
    final name = route.settings.name;
    return name != null && name.isNotEmpty;
  }

  /// pop 返回某页面时恢复上下文
  ///
  /// 优先恢复该页面手动设置过的上下文（含 channelId 等参数），
  /// 没有手动设置过才按路由名生成
  void _restoreContextForRoute(Route<dynamic> route) {
    if (_hasRouteName(route)) {
      _currentTopPageRoute = route;
    }
    final manual = _manualRouteContexts[route];
    if (manual != null) {
      _currentRouteContext = manual;
      return;
    }
    _updateCurrentContextFromRoute(route);
  }

  /// 从参数对象提取参数 Map
  Map<String, dynamic>? _extractParams(dynamic args) {
    if (args == null) return null;
    if (args is Map<String, dynamic>) return args;
    if (args is Map) return Map<String, dynamic>.from(args);
    // 其他类型封装为参数
    return {'value': args};
  }

  /// 异步记录到历史存储
  Future<void> _recordToHistory(String routeName, dynamic args) async {
    // 确保已初始化
    if (!_initialized) {
      await initialize();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final params = _extractParams(args);

    // 查找是否已存在该路由的记录
    final existingIndex = _history.indexWhere(
      (record) => record.pageId == routeName,
    );

    if (existingIndex != -1) {
      // 更新现有记录
      final existing = _history[existingIndex];
      _history[existingIndex] = existing.copyWith(
        timestamp: now,
        visitCount: existing.visitCount + 1,
        params: params,
      );
    } else {
      // 创建新记录
      final record = PageVisitRecord(
        pageId: routeName,
        title: routeName,
        timestamp: now,
        visitCount: 1,
        params: params,
      );
      _history.insert(0, record);
    }

    // 按时间重新排序
    _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // 限制历史记录数量
    if (_history.length > _maxHistorySize) {
      _history.removeRange(_maxHistorySize, _history.length);
    }

    // 异步保存
    _saveHistory();
  }

  // ==================== 当前路由上下文管理 ====================

  /// 更新当前路由上下文（不触发页面刷新）
  ///
  /// 用于在页面内部状态变化时更新路由信息，供"询问当前上下文"功能使用。
  /// 注意：此方法只更新内存中的上下文，不会触发导航或页面重建。
  ///
  /// [pageId] 页面唯一标识符（通常是路由名称）
  /// [title] 页面标题
  /// [params] 当前页面参数
  /// [icon] 页面图标（可选）
  ///
  /// 示例：
  /// ```dart
  /// // 日记日历切换日期时更新上下文
  /// RouteHistoryManager.updateCurrentContext(
  ///   pageId: '/diary_detail',
  ///   title: '日记详情',
  ///   params: {'date': '2025-12-22'},
  /// );
  /// ```
  static void updateCurrentContext({
    required String pageId,
    required String title,
    Map<String, dynamic>? params,
    IconData? icon,
  }) {
    final manager = instance;
    final now = DateTime.now().millisecondsSinceEpoch;

    manager._currentRouteContext = PageVisitRecord(
      pageId: pageId,
      title: title,
      iconCodePoint: icon?.codePoint,
      timestamp: now,
      visitCount: 1,
      params: params,
    );

    // 绑定到当前栈顶页面路由，pop 返回该页面时按它恢复（保留参数）
    final topRoute = manager._currentTopPageRoute;
    if (topRoute != null) {
      manager._manualRouteContexts[topRoute] = manager._currentRouteContext!;
    }

    debugPrint('RouteHistoryManager: 更新当前路由上下文 "$pageId"，参数: $params');
  }

  /// 获取当前路由上下文
  ///
  /// 返回当前页面的路由信息，包括页面ID、标题和参数。
  /// 如果当前没有路由上下文，则返回 null。
  static PageVisitRecord? getCurrentContext() {
    return instance._currentRouteContext;
  }

  /// 获取当前路由参数
  ///
  /// 便捷方法，直接返回当前路由的参数Map。
  /// 如果没有参数或没有当前上下文，返回空Map。
  static Map<String, dynamic> getCurrentParams() {
    return instance._currentRouteContext?.params ?? {};
  }

  /// 获取当前路由的特定参数
  ///
  /// [key] 参数键
  /// [defaultValue] 默认值（参数不存在时返回）
  static T? getCurrentParam<T>(String key, {T? defaultValue}) {
    final params = getCurrentParams();
    return params[key] as T? ?? defaultValue;
  }
}
