import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// CustomBottomBar - flutter_floating_bottom_bar 外壳 + DS 弧形圆盘底部导航
///
/// 外壳保留浮动条、滚动隐藏、回顶按钮、body 让位等机制;
/// 导航本体为 [DSBottomNavigation](弧形 dock + 滑动药丸),点按经 [tabController] 切换页。
///
/// ## 常用参数说明
/// - [items]: 底部导航项([DSNavItem],自绘图标 + 文案)
/// - [currentIndex]: 当前选中的 Tab 索引
/// - [tabController]: Tab 控制器(驱动 body 的 TabBarView 与选中态)
/// - [body]: 底部栏上方的内容(通常是 TabBarView)
/// - [fab]: 悬浮操作钮(可选),停靠在子栏右圆钮位置(缩放至 35,与圆钮同尺寸)
/// - [subLabels]/[subOption]/[onSubOptionChange]: 上层子栏双选项(可选)
class CustomBottomBar extends StatefulWidget {
  /// 底部导航项
  final List<DSNavItem> items;

  /// 当前选中的 Tab 索引
  final int currentIndex;

  /// Tab 控制器
  final TabController tabController;

  /// 底部栏上方的内容(通常是 TabBarView)
  final Widget Function(BuildContext context, ScrollController controller) body;

  /// 悬浮操作钮(可选),停靠在子栏右圆钮位置
  final Widget? fab;

  /// 上层子栏双选项文案(null 则不启用子栏)
  final (String, String)? subLabels;

  /// 子栏弧线左端的常驻浮动圆钮图标(如标签管理入口)
  final Widget? leadingAction;

  /// 左侧浮动圆钮点击回调
  final VoidCallback? onLeadingTap;

  /// 当前选中的子栏选项
  final RadialSubOption subOption;

  /// 子栏选项切换回调
  final ValueChanged<RadialSubOption>? onSubOptionChange;

  /// 底部栏宽度占屏幕宽度的比例,默认 0.85
  final double widthRatio;

  /// 底部栏偏移量,默认 12
  final double offset;

  /// 底部栏高度测量键(用于外部获取高度)
  final GlobalKey? bottomBarKey;

  /// 是否启用滚动隐藏,默认 true
  final bool hideOnScroll;

  const CustomBottomBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.tabController,
    required this.body,
    this.fab,
    this.subLabels,
    this.leadingAction,
    this.onLeadingTap,
    this.subOption = RadialSubOption.left,
    this.onSubOptionChange,
    this.widthRatio = 0.85,
    this.offset = 12,
    this.bottomBarKey,
    this.hideOnScroll = true,
  });

  @override
  State<CustomBottomBar> createState() => _CustomBottomBarState();
}

class _CustomBottomBarState extends State<CustomBottomBar> {
  // DS 果冻导航(选中块 46 + 间距 + 文案 + 内边距)实测约 80,初值贴近避免首帧遮挡
  double _bottomBarHeight = 80;

  /// 滚动隐藏状态(仅移动端 hideOnScroll 生效),驱动注入 padding 收放
  bool _barHidden = false;

  void _setBarHidden(bool hidden) {
    if (_barHidden == hidden) return;
    setState(() => _barHidden = hidden);
  }

  /// 调度底部栏高度测量
  void _scheduleBottomBarHeightMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.bottomBarKey?.currentContext != null) {
        final renderBox =
            widget.bottomBarKey!.currentContext!.findRenderObject()
                as RenderBox;
        final newHeight = renderBox.size.height;
        if (_bottomBarHeight != newHeight) {
          setState(() {
            _bottomBarHeight = newHeight;
          });
        }
      }
    });
  }

  /// 构建向上箭头图标(滚动到顶部功能)
  Widget _buildScrollToTopIcon(double width, double height) {
    return Center(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return DSIconButton(
            icon: DsIconKind.chevronUp,
            size: width,
            color: theme.surfaceAlt,
            iconColor: theme.primary,
            onPressed: () {
              if (widget.tabController.indexIsChanging) return;
              if (widget.currentIndex != 0) {
                widget.tabController.animateTo(0);
              }
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _scheduleBottomBarHeightMeasurement();
    final theme = DSThemeBridge.resolve(context);
    final mediaQuery = MediaQuery.of(context);

    // 根部自包桥:外壳内的 DS 导航/图标不依赖宿主提供 AppTheme 祖树
    return DSThemeBridge(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          BottomBar(
            fit: StackFit.expand,
            icon: _buildScrollToTopIcon,
            borderRadius: BorderRadius.circular(25),
            duration: const Duration(milliseconds: 300),
            curve: Curves.decelerate,
            showIcon: true,
            width: mediaQuery.size.width * widget.widthRatio,
            // 外壳透明,外观由 DSBottomNavigation 的弧形 dock 呈现
            barColor: Colors.transparent,
            start: 2,
            end: 0,
            offset: widget.offset,
            barAlignment: Alignment.bottomCenter,
            iconHeight: 35,
            iconWidth: 35,
            reverse: false,
            iconDecoration: BoxDecoration(
              color: theme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
            ),
            hideOnScroll:
                widget.hideOnScroll &&
                !kIsWeb &&
                defaultTargetPlatform != TargetPlatform.macOS &&
                defaultTargetPlatform != TargetPlatform.windows &&
                defaultTargetPlatform != TargetPlatform.linux,
            scrollOpposite: false,
            onBottomBarHidden: () => _setBarHidden(true),
            onBottomBarShown: () => _setBarHidden(false),
            body:
                (context, controller) => MediaQuery(
                  data: mediaQuery.copyWith(
                    padding: mediaQuery.padding.copyWith(
                      bottom:
                          (_barHidden ? 0 : _bottomBarHeight + widget.offset) +
                          mediaQuery.padding.bottom,
                    ),
                  ),
                  // body 全屏绘制,页面背景延伸到悬浮 bar 下方,
                  // 内容通过注入的 padding.bottom 自行避让(bar 隐藏时收起,只留安全区)
                  child: widget.body(context, controller),
                ),
            child: Stack(
              key: widget.bottomBarKey,
              clipBehavior: Clip.none,
              children: [
                DSBottomNavigation(
                  items: widget.items,
                  currentIndex: widget.currentIndex,
                  onTap: (index) => widget.tabController.animateTo(index),
                  // fab 停靠到子栏右圆钮位置:等比缩到 35,
                  // 与其他圆钮(35 圆 + 16 图标)同尺寸
                  floatingAction:
                      widget.fab == null
                          ? null
                          : SizedBox(
                            width: 35,
                            height: 35,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: widget.fab,
                            ),
                          ),
                  subLabels: widget.subLabels,
                  subOption: widget.subOption,
                  onSubOptionChange: widget.onSubOptionChange,
                  leadingAction: widget.leadingAction,
                  onLeadingTap: widget.onLeadingTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 简单的 CustomBottomBar 快捷构造函数(无 FAB)
///
/// 适用于不需要悬浮按钮的场景
class SimpleCustomBottomBar extends CustomBottomBar {
  const SimpleCustomBottomBar({
    super.key,
    required super.items,
    required super.currentIndex,
    required super.tabController,
    required super.body,
    super.widthRatio,
    super.offset,
    super.bottomBarKey,
    super.hideOnScroll,
  });
}
