import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/store/widgets/store_view/product_list.dart';
import 'package:aboutme/plugins/store/widgets/store_view/user_items.dart';
import 'package:aboutme/plugins/store/widgets/store_view/points_history.dart';
import 'package:aboutme/plugins/store/widgets/add_product_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/custom_bottom_bar.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/store/store_plugin.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';

/// Store 插件的底部栏组件
/// 提供商品列表、用户物品和积分历史三个 Tab 的切换功能
class StoreBottomBar extends StatefulWidget {
  final StorePlugin plugin;

  const StoreBottomBar({super.key, required this.plugin});

  @override
  State<StoreBottomBar> createState() => _StoreBottomBarState();
}

class _StoreBottomBarState extends State<StoreBottomBar>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentPage;
  final GlobalKey _bottomBarKey = GlobalKey();

  // 使用插件主题色和辅助色
  final List<Color> _colors = [
    Colors.purple, // Tab0 - 商品列表 (插件主色)
    Colors.blue.shade600, // Tab1 - 用户物品
    Colors.green.shade600, // Tab2 - 积分历史
  ];

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.animation?.addListener(() {
      final value = _tabController.animation!.value.round();
      if (value != _currentPage && mounted) {
        setState(() {
          _currentPage = value;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 显示添加积分对话框
  void _showAddPointsDialog() {
    final TextEditingController pointsController = TextEditingController();
    final TextEditingController reasonController = TextEditingController(
      text: 'store_pointsAdjustmentDefaultReason'.tr,
    );

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'store_addPointsDialogTitle'.tr,
                        textAlign: TextAlign.center,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      DSInput(
                        controller: pointsController,
                        keyboardType: TextInputType.number,
                        label: 'store_pointsAmountLabel'.tr,
                        hint: '请输入积分数量',
                        prefix: DsIcon(
                          DsIconKind.plus,
                          size: 18,
                          color: theme.textSub,
                        ),
                      ),
                      SizedBox(height: theme.spacing.md),
                      DSInput(
                        controller: reasonController,
                        label: 'store_reasonLabel'.tr,
                        hint: '请输入添加原因',
                        prefix: DsIcon(
                          DsIconKind.book,
                          size: 18,
                          color: theme.textSub,
                        ),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: DSButton(
                              label: 'store_cancel'.tr,
                              variant: DSButtonVariant.outline,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          SizedBox(width: theme.spacing.md),
                          Expanded(
                            child: DSButton(
                              label: 'store_add'.tr,
                              onPressed: () async {
                                final points = int.tryParse(
                                  pointsController.text,
                                );
                                if (points == null || points <= 0) {
                                  Toast.error('store_priceInvalid'.tr);
                                  return;
                                }

                                final reason =
                                    reasonController.text.isEmpty
                                        ? 'store_pointsAdjustmentDefaultReason'
                                            .tr
                                        : reasonController.text;

                                Navigator.pop(context);
                                await widget.plugin.controller.addPoints(
                                  points,
                                  reason,
                                );

                                if (mounted) {
                                  Toast.success(
                                    '${'store_pointsAdded'.tr}: +$points',
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }

  /// 构建 FAB
  Widget _buildFab() {
    // DSFab 需 AppTheme 祖先，包一层主题桥
    return DSThemeBridge(
      child: DSFab(
        size: 56,
        color: widget.plugin.color,
        iconColor:
            widget.plugin.color.computeLuminance() < 0.5
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF000000),
        icon: _currentPage == 0 ? DsIconKind.cart : DsIconKind.plus,
        onPressed: () {
          if (_currentPage == 0) {
            NavigationHelper.push(
              context,
              AddProductPage(controller: widget.plugin.controller),
            );
          } else if (_currentPage == 2) {
            _showAddPointsDialog();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomBar(
      colors: _colors,
      currentIndex: _currentPage,
      tabController: _tabController,
      bottomBarKey: _bottomBarKey,
      body:
          (context, controller) => TabBarView(
            controller: _tabController,
            dragStartBehavior: DragStartBehavior.start,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ProductList(controller: widget.plugin.controller),
              UserItems(controller: widget.plugin.controller),
              PointsHistory(controller: widget.plugin.controller),
            ],
          ),
      fab: _buildFab(),
      children: [
        Tab(icon: Icon(Icons.shopping_bag), text: 'store_productList'.tr),
        Tab(icon: Icon(Icons.inventory), text: 'store_myItems'.tr),
        Tab(icon: Icon(Icons.history), text: 'store_pointsHistory'.tr),
      ],
    );
  }
}
