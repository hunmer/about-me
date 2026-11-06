import 'package:flutter/material.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../../../../widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import '../models/subscription.dart';
import '../bill_plugin.dart';
import 'subscription_edit_screen.dart';
import '../widgets/subscription_card.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

class SubscriptionListScreen extends StatefulWidget {
  final BillPlugin billPlugin;

  const SubscriptionListScreen({super.key, required this.billPlugin});

  @override
  State<SubscriptionListScreen> createState() => _SubscriptionListScreenState();
}

class _SubscriptionListScreenState extends State<SubscriptionListScreen> {
  late final void Function() _listener;
  bool _isGridView = true;
  static const String _viewModeKey = 'subscription_list_view_mode_grid';

  // 搜索相关状态
  String _searchQuery = '';
  final Map<String, bool> _searchFilters = {
    'name': true, // 是否搜索名称
    'category': true, // 是否搜索分类
  };

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    _listener = () {
      if (mounted) setState(() {});
    };
    widget.billPlugin.controller.subscriptions.addListener(_listener);

    // 设置路由上下文
    _updateRouteContext();
  }

  /// 更新路由上下文,使"询问当前上下文"功能能识别当前页面
  void _updateRouteContext() {
    RouteHistoryManager.updateCurrentContext(
      pageId: '/bill_subscriptions',
      title: '订阅服务',
      params: {},
    );
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isGridView = prefs.getBool(_viewModeKey) ?? true;
      });
    }
  }

  Future<void> _toggleViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !_isGridView;
    await prefs.setBool(_viewModeKey, newValue);
    if (mounted) {
      setState(() {
        _isGridView = newValue;
      });
    }
  }

  List<Subscription> _filterSubscriptions(List<Subscription> subscriptions) {
    if (_searchQuery.isEmpty) {
      return subscriptions;
    }

    final query = _searchQuery.toLowerCase();
    return subscriptions.where((subscription) {
      // 按名称搜索
      final matchName =
          _searchFilters['name'] == true &&
          subscription.name.toLowerCase().contains(query);

      // 按分类搜索
      final matchCategory =
          _searchFilters['category'] == true &&
          subscription.category.toLowerCase().contains(query);

      return matchName || matchCategory;
    }).toList();
  }

  @override
  void dispose() {
    widget.billPlugin.controller.subscriptions.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions =
        widget.billPlugin.controller.subscriptions.subscriptions;
    final activeSubscriptions = _filterSubscriptions(
      subscriptions.where((s) => s.isActive).toList(),
    );
    final inactiveSubscriptions = _filterSubscriptions(
      subscriptions.where((s) => !s.isActive).toList(),
    );

    return SuperCupertinoNavigationWrapper(
      title: Text('bill_subscription'.tr),
      largeTitle: 'bill_subscription'.tr,
      enableSearchBar: true,
      searchPlaceholder: '搜索订阅服务...',
      onSearchChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      enableSearchFilter: true,
      filterLabels: const {'name': '名称', 'category': '分类'},
      onSearchFilterChanged: (filters) {
        setState(() {
          _searchFilters.addAll(filters);
        });
      },
      searchBody: _buildSearchBody(),
      body: _buildMainBody(activeSubscriptions, inactiveSubscriptions),
      actions: [
        // SuperAppBar 的 actions 经 Overlay 渲染,DS 按钮需自带 DSThemeBridge
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: _isGridView ? DsIconKind.list : DsIconKind.grid,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip:
                    _isGridView
                        ? 'bill_switchToListView'.tr
                        : 'bill_switchToGridView'.tr,
                onPressed: _toggleViewMode,
              );
            },
          ),
        ),
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.plus,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                onPressed: () => _navigateToEdit(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMainBody(
    List<Subscription> activeSubscriptions,
    List<Subscription> inactiveSubscriptions,
  ) {
    final allSubscriptions = [...activeSubscriptions, ...inactiveSubscriptions];

    if (allSubscriptions.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (activeSubscriptions.isNotEmpty) ...[
          _buildSectionHeader(
            '${"bill_activeSubscriptions".tr} (${activeSubscriptions.length})',
          ),
          _buildSubscriptionList(activeSubscriptions),
        ],
        if (inactiveSubscriptions.isNotEmpty) ...[
          _buildSectionHeader(
            '${"bill_inactiveSubscriptions".tr} (${inactiveSubscriptions.length})',
          ),
          _buildSubscriptionList(inactiveSubscriptions, isInactive: true),
        ],
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ), // Bottom padding for FAB
      ],
    );
  }

  Widget _buildSearchBody() {
    final subscriptions =
        widget.billPlugin.controller.subscriptions.subscriptions;
    final filteredSubscriptions = _filterSubscriptions(subscriptions);

    if (_searchQuery.isNotEmpty && filteredSubscriptions.isEmpty) {
      return const DSThemeBridge(
        child: DSEmptyState(emoji: '🔍', title: '未找到匹配的订阅服务'),
      );
    }

    if (filteredSubscriptions.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSubscriptionList(filteredSubscriptions),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildSubscriptionList(
    List<Subscription> subscriptions, {
    bool isInactive = false,
  }) {
    if (_isGridView) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            return SubscriptionCard(
              subscription: subscriptions[index],
              onTap: () => _navigateToEdit(subscription: subscriptions[index]),
              onLongPress: () => _showMenuDialog(subscriptions[index]),
              isInactive: isInactive,
            );
          }, childCount: subscriptions.length),
        ),
      );
    } else {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SubscriptionListTile(
                subscription: subscriptions[index],
                onTap:
                    () => _navigateToEdit(subscription: subscriptions[index]),
                onLongPress: () => _showMenuDialog(subscriptions[index]),
                isInactive: isInactive,
              ),
            );
          }, childCount: subscriptions.length),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return DSThemeBridge(
      child: DSEmptyState(
        emoji: '🔁',
        title: 'bill_noSubscriptions'.tr,
        message: 'bill_clickToAddSubscription'.tr,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(
              title,
              style: DsTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.textSub,
                letterSpacing: 0.5,
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToEdit({Subscription? subscription}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => SubscriptionEditScreen(
              billPlugin: widget.billPlugin,
              subscription: subscription,
            ),
      ),
    );
  }

  void _showMenuDialog(Subscription subscription) {
    SmoothBottomSheet.show(
      context: context,
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSheetAction(
                        context,
                        icon: DsIconKind.edit,
                        label: 'bill_edit'.tr,
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToEdit(subscription: subscription);
                        },
                      ),
                      if (subscription.isActive)
                        _buildSheetAction(
                          context,
                          icon: DsIconKind.stop,
                          label: 'bill_terminateSubscription'.tr,
                          onTap: () {
                            Navigator.pop(context);
                            _showTerminateDialog(subscription);
                          },
                        ),
                      _buildSheetAction(
                        context,
                        icon: DsIconKind.trash,
                        label: 'bill_delete'.tr,
                        destructive: true,
                        onTap: () {
                          Navigator.pop(context);
                          _showDeleteDialog(subscription);
                        },
                      ),
                    ],
                  ),
            ),
          ),
    );
  }

  /// 底部操作行（自绘，随 DS 令牌着色）
  Widget _buildSheetAction(
    BuildContext context, {
    required DsIconKind icon,
    required String label,
    bool destructive = false,
    required VoidCallback onTap,
  }) {
    final theme = DSThemeBridge.resolve(context);
    final color = destructive ? theme.danger : theme.text;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: pressed ? theme.surfaceAlt : null,
          child: Row(
            children: [
              DsIcon(icon, size: 24, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: DsTypography.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTerminateDialog(Subscription subscription) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'bill_terminateSubscription'.tr,
                    message: 'bill_terminateConfirm'.tr.replaceAll(
                      '{name}',
                      subscription.name,
                    ),
                    cancelText: 'bill_cancel'.tr,
                    confirmText: 'bill_save'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onConfirm: () {
                      widget.billPlugin.controller.subscriptions
                          .terminateSubscription(subscription.id);
                      Navigator.of(context).pop();
                    },
                  ),
            ),
          ),
    );
  }

  void _showDeleteDialog(Subscription subscription) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'bill_deleteSubscription'.tr,
                    message: 'bill_deleteConfirm'.tr.replaceAll(
                      '{name}',
                      subscription.name,
                    ),
                    cancelText: 'bill_cancel'.tr,
                    confirmText: 'bill_delete'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onConfirm: () {
                      widget.billPlugin.controller.subscriptions
                          .deleteSubscription(subscription.id);
                      Navigator.of(context).pop();
                    },
                  ),
            ),
          ),
    );
  }
}
