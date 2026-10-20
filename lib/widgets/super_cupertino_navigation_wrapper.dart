import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:get/get.dart';
import 'package:collection/collection.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/app_background_controller.dart';
import 'package:super_cupertino_navigation_bar/super_cupertino_navigation_bar.dart';
import 'super_cupertino_navigation_wrapper/filter_models.dart';
import 'super_cupertino_navigation_wrapper/multi_filter_bar.dart';

/// Super Cupertino Navigation Bar 的封装组件
///
/// 提供了一个统一的界面配置，包括：
/// - 大标题 (Large Title)
/// - 搜索栏 (Search Bar)
/// - 底部栏 (Bottom Bar)
/// - 多条件过滤栏 (Multi Filter Bar)
/// - 自定义主题和样式
class SuperCupertinoNavigationWrapper extends StatefulWidget {
  /// 导航栏标题
  final Widget title;

  /// 标题是否水平居中（Cupertino 默认居中）；
  /// false 时紧随返回按钮左对齐
  final bool centerTitle;

  /// 大标题
  final String largeTitle;

  /// 子 widget
  final Widget body;

  /// 是否启用大标题
  final bool enableLargeTitle;

  /// 是否启用搜索栏
  final bool enableSearchBar;

  /// 是否启用底部栏
  final bool enableBottomBar;

  /// 底部栏高度
  final double bottomBarHeight;

  /// 底部栏子 widget
  final Widget? bottomBarChild;

  /// 搜索栏占位符文本
  final String searchPlaceholder;

  /// 搜索栏回调函数
  final Function(String)? onSearchChanged;
  final Function(String)? onSearchSubmitted;

  /// 搜索结果页面内容Widget
  /// 当搜索框聚焦或有内容时显示此Widget
  final Widget? searchBody;

  /// 导航栏操作按钮
  final List<Widget>? actions;

  /// 大标题操作按钮
  final List<Widget>? largeTitleActions;

  /// 背景颜色
  final Color? backgroundColor;

  /// 是否自动显示返回按钮
  /// 当为 null 时,非移动端(桌面平台)默认不显示,移动端默认显示
  final bool? automaticallyImplyLeading;

  /// 是否让导航栏参与路由转场 Hero 动画。
  /// 同一路由下嵌套第二个本组件时（如 tab 内嵌页）必须传 false，
  /// 否则两个导航栏的默认 Hero tag 冲突
  final bool transitionBetweenRoutes;

  /// 返回按钮标题
  final String? previousPageTitle;

  /// 返回按钮标题文字样式
  /// 为 null 时默认使用 DS 风格（DsTypography.body + primaryText）
  final TextStyle? previousPageTitleStyle;

  /// 折叠状态回调
  final Function(bool)? onCollapsed;

  /// 强制导航栏折叠为小标题状态并锁定外层滚动
  /// （body 自持手势时使用，如画布视图的平移拖拽）
  final bool forceCollapsed;

  /// 是否启用拉伸效果
  final bool stretch;

  /// ========== 过滤栏相关配置 ==========

  /// 是否启用过滤栏
  final bool enableFilterBar;

  /// 过滤栏高度
  final double filterBarHeight;

  /// 过滤栏内容Widget
  final Widget? filterBarChild;

  /// 过滤条件变更回调
  final Function(Map<String, dynamic>)? onFilterChanged;

  /// ========== 高级搜索相关配置 ==========

  /// 是否启用高级搜索
  final bool enableAdvancedSearch;

  /// 搜索条件筛选器Widget列表
  final List<Widget>? searchFilters;

  /// 高级搜索变更回调
  final Function(Map<String, dynamic>)? onAdvancedSearchChanged;

  /// ========== 搜索过滤器相关配置 ==========

  /// 是否启用搜索过滤器
  final bool enableSearchFilter;

  /// 搜索过滤器标签配置
  final Map<String, String> filterLabels;

  /// 搜索过滤器状态回调
  final Function(Map<String, bool>)? onSearchFilterChanged;

  /// 返回按钮点击回调
  /// 如果提供此回调，在非移动端（桌面平台）将显示自定义返回按钮
  final VoidCallback? onLeadingPressed;

  /// 自定义左上角返回按钮
  /// 提供时替换默认的 DS 图标返回按钮，点击行为由该 widget 自行处理
  final Widget? backButton;

  /// ========== 多条件过滤相关配置 ==========

  /// 是否启用多条件过滤
  final bool enableMultiFilter;

  /// 多条件过滤项列表
  final List<FilterItem>? multiFilterItems;

  /// 多条件过滤栏高度
  final double multiFilterBarHeight;

  /// 多条件过滤变更回调
  final ValueChanged<Map<String, dynamic>>? onMultiFilterChanged;

  /// 是否启用多条件过滤切换按钮
  /// 当为 true 时，会在 actions 中自动添加一个切换按钮
  /// 点击按钮同时显示/隐藏过滤栏与搜索栏（两者默认隐藏），
  /// 隐藏时会清空已有的过滤条件与搜索内容；
  /// 仅启用搜索栏（无过滤项）的页面同样会出现该按钮，此时只切换搜索框
  final bool multiFilterToggleable;

  /// 初始多条件过滤值（用于页面跳转时传递初始筛选条件）
  final Map<String, dynamic>? initialMultiFilters;

  /// 多条件过滤栏第一层最右侧的固定尾部部件（如排序按钮）
  final Widget? multiFilterBarTrailing;

  const SuperCupertinoNavigationWrapper({
    super.key,
    required this.title,
    required this.body,
    this.centerTitle = true,
    this.largeTitle = '',
    this.enableLargeTitle = true,
    this.enableSearchBar = false,
    this.enableBottomBar = false,
    this.bottomBarHeight = 40,
    this.bottomBarChild,
    this.searchPlaceholder = '', // 改为空字符串，通过国际化获取默认值
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.searchBody,
    this.actions,
    this.largeTitleActions,
    this.backgroundColor,
    this.automaticallyImplyLeading,
    this.transitionBetweenRoutes = true,
    this.previousPageTitle,
    this.previousPageTitleStyle,
    this.onCollapsed,
    this.forceCollapsed = false,
    this.stretch = true,
    // 过滤栏参数
    this.enableFilterBar = false,
    this.filterBarHeight = 50,
    this.filterBarChild,
    this.onFilterChanged,
    // 高级搜索参数
    this.enableAdvancedSearch = false,
    this.searchFilters,
    this.onAdvancedSearchChanged,
    // 搜索过滤器参数
    this.enableSearchFilter = false,
    this.filterLabels = const {}, // 改为空映射，通过国际化获取默认值
    this.onSearchFilterChanged,
    this.onLeadingPressed,
    this.backButton,
    // 多条件过滤参数
    this.enableMultiFilter = false,
    this.multiFilterItems,
    this.multiFilterBarHeight = 50,
    this.onMultiFilterChanged,
    this.multiFilterToggleable = true,
    this.initialMultiFilters,
    this.multiFilterBarTrailing,
  });

  @override
  State<SuperCupertinoNavigationWrapper> createState() =>
      _SuperCupertinoNavigationWrapperState();
}

class _SuperCupertinoNavigationWrapperState
    extends State<SuperCupertinoNavigationWrapper> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false; // 搜索状态：基于文本内容判断
  bool _isTextFieldFocused = false; // 焦点状态：跟踪输入框是否获得焦点
  final Map<String, bool> _searchFilters = {
    'activity': true,
    'tag': true,
    'comment': true,
  };

  /// 多条件过滤状态
  late MultiFilterState _multiFilterState;

  /// 过滤栏与搜索栏显示状态（由切换按钮同时控制，默认隐藏）
  bool _isToolbarVisible = false;

  /// 是否存在多条件过滤切换（过滤栏与搜索框一起切换）
  bool get _hasFilterToggle =>
      widget.enableMultiFilter &&
      widget.multiFilterToggleable &&
      widget.multiFilterItems != null &&
      widget.multiFilterItems!.isNotEmpty;

  /// 是否仅存在搜索切换（无过滤项时切换按钮只控制搜索框）
  bool get _hasSearchToggle => widget.enableSearchBar && !_hasFilterToggle;

  /// 获取国际化文本
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _multiFilterState.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // 初始化多条件过滤状态
    _multiFilterState = MultiFilterState();
    // 如果有初始过滤值，则初始化
    if (widget.initialMultiFilters != null &&
        widget.initialMultiFilters!.isNotEmpty) {
      _multiFilterState.initializeFromMap(widget.initialMultiFilters!);
    }
    // 初始化搜索过滤器状态
    _searchFilters.addAll(
      widget.filterLabels.keys
          .where((key) => !_searchFilters.containsKey(key))
          .fold<Map<String, bool>>({}, (map, key) => map..[key] = true),
    );

    // 监听搜索框内容变化 - 使用 setState 强制重建 UI
    _searchController.addListener(() {
      final hasText = _searchController.text.isNotEmpty;
      if (mounted) {
        setState(() {
          _isSearchFocused = hasText || _isTextFieldFocused;
        });
      }
    });

    // 监听焦点变化 - 使用 setState 强制重建 UI
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isTextFieldFocused = _searchFocusNode.hasFocus;
          // 更新搜索状态：文本存在或输入框获得焦点
          _isSearchFocused =
              _searchController.text.isNotEmpty || _isTextFieldFocused;
        });
      }
    });
  }

  @override
  void didUpdateWidget(SuperCupertinoNavigationWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 进入画布等强制折叠态时同步收起过滤/搜索栏（清空搜索与过滤条件）
    if (widget.forceCollapsed &&
        !oldWidget.forceCollapsed &&
        _isToolbarVisible) {
      _hideToolbar();
    }
    // 外部过滤值变化时（如仓库卡片快切）同步到过滤栏状态
    if (!const MapEquality().equals(
      oldWidget.initialMultiFilters ?? const {},
      widget.initialMultiFilters ?? const {},
    )) {
      _multiFilterState.initializeFromMap(
        Map<String, dynamic>.from(widget.initialMultiFilters ?? const {}),
      );
    }
  }

  /// 更新搜索过滤器状态
  void _updateSearchFilter(String key, bool value) {
    setState(() {
      _searchFilters[key] = value;
    });
    widget.onSearchFilterChanged?.call(Map.from(_searchFilters));
  }

  /// 获取默认的搜索占位符
  String _getDefaultSearchPlaceholder() {
    return 'core_search'.tr;
  }

  /// 获取默认的过滤器标签
  Map<String, String> _getDefaultFilterLabels() {
    return {
      'activity': 'core_activity'.tr,
      'tag': 'core_tag'.tr,
      'comment': 'core_comment'.tr,
    };
  }

  /// 构建搜索过滤器
  Widget _buildSearchFilter() {
    if (!widget.enableSearchFilter) {
      return const SizedBox.shrink();
    }

    // 获取过滤器标签（使用默认或自定义）
    final filterLabels = widget.filterLabels.isNotEmpty
        ? widget.filterLabels
        : _getDefaultFilterLabels();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: dsNonOpaqueRouteBackdrop(context),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.12),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'core_searchScope'.tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: filterLabels.entries.map((entry) {
              final key = entry.key;
              final label = entry.value;
              final value = _searchFilters[key] ?? true;

              // 简化过滤项：让点击直接触发更新，不影响焦点
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DSCheckbox(
                    value: value,
                    onChanged: (bool? newValue) {
                      if (newValue != null) {
                        _updateSearchFilter(key, newValue);
                      }
                    },
                    semanticLabel: label,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// 获取显示用的标题文本
  String _getDisplayTitle() {
    // 如果启用大标题，使用 largeTitle
    if (widget.enableLargeTitle) {
      return widget.largeTitle;
    }

    // 如果没有启用大标题，尝试从 widget.title 中提取文本
    if (widget.title is Text) {
      final textWidget = widget.title as Text;
      return textWidget.data ?? '';
    }

    // 如果是其他类型的 Widget，使用 largeTitle 或空字符串
    return widget.largeTitle.isNotEmpty ? widget.largeTitle : '';
  }

  /// 退出搜索模式
  void _exitSearchMode() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearchFocused = false;
      _isTextFieldFocused = false;
    });
    // 通知外部搜索已清空
    widget.onSearchChanged?.call('');
  }

  /// 检查是否为移动端
  bool get _isMobile => UniversalPlatform.isAndroid || UniversalPlatform.isIOS;

  /// 解析界面背景色：显式传入时用之；未传入时若设置了全局自定义背景
  /// （背景图/纯色/网格）则透明以透出全局背景，否则取 DS 主题背景色
  /// （浅色为粉调，深色为 night）
  Color _resolveBackgroundColor() {
    if (widget.backgroundColor != null) return widget.backgroundColor!;
    if (AppBackgroundController().hasCustomBackground) {
      return DsColors.transparent;
    }
    return AppTheme.of(context).background;
  }

  @override
  Widget build(BuildContext context) {
    // 根据搜索状态选择显示哪个body - 使用 setState 保证实时更新
    final shouldShowSearchBody =
        widget.enableSearchBar && widget.searchBody != null && _isSearchFocused;
    final currentBody = shouldShowSearchBody ? widget.searchBody! : widget.body;

    // 移动端：搜索模式下拦截返回键
    return PopScope(
      canPop: !(_isMobile && _isSearchFocused),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isMobile && _isSearchFocused) {
          _exitSearchMode();
        }
      },
      child: Scaffold(
        backgroundColor: _resolveBackgroundColor(),
          body: SuperScaffold(
            onCollapsed: widget.onCollapsed,
            forceCollapsed: widget.forceCollapsed,
            stretch: widget.stretch,
            transitionBetweenRoutes: widget.transitionBetweenRoutes,
            appBar: _buildSuperAppBar(),
          body: Column(
            children: [
              // 高级搜索条件筛选器
              if (widget.enableAdvancedSearch &&
                  widget.searchFilters != null &&
                  widget.searchFilters!.isNotEmpty)
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: widget.searchFilters!,
                  ),
                ),
              // 搜索过滤器 - 依赖 _isSearchFocused 状态
              if (widget.enableSearchFilter && _isSearchFocused)
                _buildSearchFilter(),
              // 多条件过滤栏 - 只在非搜索状态下且可见时显示
              if (widget.enableMultiFilter &&
                  widget.multiFilterItems != null &&
                  widget.multiFilterItems!.isNotEmpty &&
                  !_isSearchFocused &&
                  _isToolbarVisible)
                MultiFilterBar(
                  filterItems: widget.multiFilterItems!,
                  filterState: _multiFilterState,
                  onFilterChanged: widget.onMultiFilterChanged,
                  height: widget.multiFilterBarHeight,
                  trailing: widget.multiFilterBarTrailing,
                ),
              // 过滤栏 - 只在非搜索状态下显示（保持向后兼容）
              if (widget.enableFilterBar &&
                  widget.filterBarChild != null &&
                  !_isSearchFocused &&
                  !widget.enableMultiFilter)
                Container(
                  height: widget.filterBarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: widget.filterBarChild,
                ),
              // 主体内容 - 根据搜索状态切换
              // iOS 上 SuperAppBar 的 header sliver 已含状态栏高度，页面内
              // SafeArea 再读 MediaQuery.padding.top 会双重留白，故统一消耗
              // 掉 top inset（各页面无需重复做平台判断）
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: UniversalPlatform.isIOS,
                  child: currentBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建 actions
  Widget? _buildActions() {
    final List<Widget> actionsList = [];

    // 过滤/搜索切换按钮：有过滤项时同时切换过滤栏与搜索框，
    // 仅启用搜索栏的页面也显示该按钮，只切换搜索框（默认隐藏）
    if (_hasFilterToggle || _hasSearchToggle) {
      final ds = AppTheme.of(context);
      actionsList.add(
        DSIconButton(
          icon: DsIconKind.search,
          size: 36,
          color: ds.surfaceAlt,
          iconColor: _isToolbarVisible ? ds.primary : ds.textSub,
          tooltip: _hasFilterToggle
              ? (_isToolbarVisible ? '隐藏过滤/搜索' : '显示过滤/搜索')
              : (_isToolbarVisible ? '隐藏搜索' : '显示搜索'),
          onPressed: _toggleToolbarVisibility,
        ),
      );
    }

    // 添加用户自定义的 actions
    if (widget.actions != null && widget.actions!.isNotEmpty) {
      actionsList.addAll(widget.actions!);
    }

    if (actionsList.isEmpty) {
      return null;
    }

    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actionsList,
    );
  }

  /// 切换过滤栏与搜索栏显示状态
  void _toggleToolbarVisibility() {
    if (!_isToolbarVisible) {
      setState(() => _isToolbarVisible = true);
      return;
    }
    _hideToolbar();
  }

  /// 隐藏过滤栏与搜索栏，退出搜索模式并清空所有过滤条件
  void _hideToolbar() {
    if (_isSearchFocused) {
      _exitSearchMode();
    }
    setState(() {
      _isToolbarVisible = false;
      _multiFilterState.clearAll();
      // 通知外部过滤条件已清空
      widget.onMultiFilterChanged?.call({});
    });
  }

  /// 解析左上角返回按钮
  ///
  /// 优先级：[backButton] 完全自定义 > 默认 DS 图标按钮（路由可返回且
  /// 非 fullscreenDialog 时显示）> 桌面端 [onLeadingPressed] 回调按钮
  /// （仅在显式关闭 automaticallyImplyLeading 时走到）；其余情况不显示
  Widget? _resolveLeading() {
    if (widget.backButton != null) return widget.backButton;

    final implyLeading = widget.automaticallyImplyLeading ?? true;

    if (implyLeading) {
      final route = ModalRoute.of(context);
      final canBack =
          route != null &&
          route.canPop &&
          !(route is PageRoute && route.fullscreenDialog);
      return canBack
          ? _buildDefaultBackButton(() => _defaultBack(context))
          : null;
    }

    if (!(UniversalPlatform.isAndroid || UniversalPlatform.isIOS) &&
        widget.onLeadingPressed != null) {
      return _buildDefaultBackButton(widget.onLeadingPressed!);
    }
    return null;
  }

  /// 默认返回行为：走 NavigationHelper 的返回路由表，
  /// 插件主界面（`/plugin/<id>`）固定回首页，其余页面正常返回上一级
  void _defaultBack(BuildContext context) {
    NavigationHelper.smartBack(context);
  }

  /// 默认的 DS 风格返回图标按钮（primary 果冻圆球，同 DSFab 质感）
  ///
  /// 外层 Align 用于对抗 NavigationToolbar 对 leading 的紧高度约束
  /// （会把固定高度的按钮拉成竖长条）：Align 向子级传递宽松约束，
  /// 保证按钮保持 36×36 正圆并在工具栏内垂直居中
  Widget _buildDefaultBackButton(VoidCallback onPressed) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1.0,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Builder(
          builder: (context) {
            final ds = AppTheme.of(context);
            // primary 整球太冲、surfaceAlt 又太平：取两者之间的浅薰衣草，
            // 保留渐变球体质感的同时压低饱和度
            final ballColor = Color.lerp(
              ds.surfaceAlt,
              ds.primary,
              ds.isDark ? 0.22 : 0.18,
            )!;
            return DSIconButton(
              icon: DsIconKind.chevronLeft,
              size: 36,
              color: ballColor,
              iconColor: ds.primaryText,
              tooltip: widget.previousPageTitle ?? 'core_back'.tr,
              onPressed: onPressed,
            );
          },
        ),
      ),
    );
  }

  /// 构建 SuperAppBar，根据 enableSearchBar 条件决定是否包含 searchBar
  SuperAppBar _buildSuperAppBar() {
    // 构建 searchBar：enableSearchBar 为 false，或存在过滤/搜索切换按钮
    // 且处于隐藏态时，传入 disabled 的 SuperSearchBar（高度归零即不占位）
    final searchBar =
        widget.enableSearchBar &&
            (!(_hasFilterToggle || _hasSearchToggle) || _isToolbarVisible)
        ? _buildSearchBar()
        : SuperSearchBar(
            enabled: false,
            scrollBehavior: SearchBarScrollBehavior.pinned,
            resultBehavior: SearchBarResultBehavior.neverVisible,
          );

    // 当 automaticallyImplyLeading 为 null 时,根据平台自动设置
    // 非移动端(桌面平台)默认不显示返回按钮,移动端默认显示
    final bool effectiveAutomaticallyImplyLeading =
        widget.automaticallyImplyLeading ??
        !(UniversalPlatform.isAndroid || UniversalPlatform.isIOS);

    return SuperAppBar(
      backgroundColor: _resolveBackgroundColor(),
      automaticallyImplyLeading: effectiveAutomaticallyImplyLeading,
      leading: _resolveLeading(),
      title: widget.title,
      centerTitle: widget.centerTitle,
      previousPageTitle: widget.previousPageTitle ?? 'core_back'.tr,
      previousPageTitleStyle:
          widget.previousPageTitleStyle ??
          DsTypography.body.copyWith(color: AppTheme.of(context).primaryText),
      actions: _buildActions(),
      bottom: _buildBottomBar(),
      largeTitle: SuperLargeTitle(
        height: 50,
        enabled: widget.enableLargeTitle,
        largeTitle: _getDisplayTitle(),
        actions: widget.largeTitleActions,
      ),
      // 只有当启用搜索栏时才传递 searchBar 参数
      searchBar: searchBar,
    );
  }

  /// 构建底部栏（保持向后兼容）
  SuperAppBarBottom? _buildBottomBar() {
    if (!widget.enableBottomBar) return null;
    return SuperAppBarBottom(
      enabled: true,
      height: widget.bottomBarHeight,
      color: Theme.of(context).colorScheme.surface,
      child: widget.filterBarChild ?? const SizedBox(),
    );
  }

  /// 构建搜索栏
  SuperSearchBar _buildSearchBar() {
    // 注意：此方法仅在 enableSearchBar=true 时被调用
    // 样式对齐设计系统 DSInput.search（本地 vendor 包提供了 decoration 插槽）
    final ds = AppTheme.of(context);
    return SuperSearchBar(
      enabled: true,
      scrollBehavior: SearchBarScrollBehavior.pinned,
      resultBehavior: SearchBarResultBehavior.neverVisible,
      height: 44,
      // 空态为浅紫填充 + 浅描边，进入搜索状态后填充/描边向主色调染，
      // 呼应 DSInput 的聚焦变色
      searchFieldDecoration: BoxDecoration(
        color: _isSearchFocused
            ? Color.lerp(ds.backgroundAlt, ds.primary, ds.isDark ? 0.30 : 0.14)!
            : ds.backgroundAlt,
        borderRadius: ds.radii.pill,
        border: Border.all(
          color: _isSearchFocused
              ? ds.primary
              : ds.textSub.withValues(alpha: 0.45),
          width: 1.6,
        ),
        boxShadow: ds.shadows.soft,
      ),
      prefixIcon: DsIcon(DsIconKind.search, size: 20, color: ds.textSub),
      textStyle: DsTypography.body.copyWith(color: ds.text),
      placeholderTextStyle: DsTypography.body.copyWith(
        color: ds.textSub.withValues(alpha: 0.75),
      ),
      cancelButtonText: 'core_cancel'.tr,
      cancelTextStyle: DsTypography.button.copyWith(color: ds.primaryText),
      placeholderText: widget.searchPlaceholder.isNotEmpty
          ? widget.searchPlaceholder
          : _getDefaultSearchPlaceholder(),
      searchController: _searchController,
      onChanged: (value) {
        widget.onSearchChanged?.call(value);
        widget.onAdvancedSearchChanged?.call({'query': value});
        // onChanged 回调已经在 _searchController.addListener 中处理了；
        // 这里额外直接同步搜索态，防止 controller 实例与 listener
        // 脱节（如热重载后 State 重建）导致 searchBody 不切换
        final expected = value.isNotEmpty || _isTextFieldFocused;
        if (mounted && _isSearchFocused != expected) {
          setState(() {
            _isSearchFocused = expected;
          });
        }
      },
      onSubmitted: widget.onSearchSubmitted,
    );
  }
}
