import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// CustomBottomBar - flutter_floating_bottom_bar 外壳 + DS 果冻底部导航
///
/// 外壳保留浮动条、滚动隐藏、回顶按钮、FAB 定位、body 让位等机制;
/// 导航本体为 [DSBottomNavigation](选中项凸起果冻方块),点按经 [tabController] 切换页。
///
/// ## 常用参数说明
/// - [items]: 底部导航项([DSNavItem],自绘图标 + 文案)
/// - [currentIndex]: 当前选中的 Tab 索引
/// - [tabController]: Tab 控制器(驱动 body 的 TabBarView 与选中态)
/// - [body]: 底部栏上方的内容(通常是 TabBarView)
/// - [fab]: 悬浮按钮(可选)
/// - [fabLocation]: FAB 位置,默认顶部居中
class CustomBottomBar extends StatefulWidget {
  /// 底部导航项
  final List<DSNavItem> items;

  /// 当前选中的 Tab 索引
  final int currentIndex;

  /// Tab 控制器
  final TabController tabController;

  /// 底部栏上方的内容(通常是 TabBarView)
  final Widget Function(BuildContext context, ScrollController controller) body;

  /// 悬浮按钮(可选)
  final Widget? fab;

  /// FAB 位置,默认顶部居中
  final AlignmentGeometry fabLocation;

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
    this.fabLocation = Alignment.topCenter,
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
            // 外壳透明,外观由 DSBottomNavigation 的果冻盒呈现
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
              alignment: widget.fabLocation,
              clipBehavior: Clip.none,
              children: [
                DSBottomNavigation(
                  items: widget.items,
                  currentIndex: widget.currentIndex,
                  onTap: (index) => widget.tabController.animateTo(index),
                ),
              ],
            ),
          ),
          // FAB 容器:与 BottomBar 相同宽度,FAB 在 BottomBar 上方
          if (widget.fab != null)
            Builder(
              builder: (context) {
                final screenWidth = mediaQuery.size.width;
                final barWidth = screenWidth * widget.widthRatio;
                final horizontalPadding = (screenWidth - barWidth) / 2;

                double? left;
                double? right;
                double bottomOffset;

                // 水平位置
                if (widget.fabLocation == Alignment.topCenter ||
                    widget.fabLocation == Alignment.center ||
                    widget.fabLocation == Alignment.bottomCenter) {
                  // 居中
                  left = horizontalPadding + barWidth / 2 - 28;
                } else if (widget.fabLocation == Alignment.topRight ||
                    widget.fabLocation == Alignment.centerRight ||
                    widget.fabLocation == Alignment.bottomRight) {
                  // 右侧,再向右偏移一半(28)
                  right = horizontalPadding - 28;
                } else {
                  // 左侧
                  left = horizontalPadding;
                }

                // 垂直位置:top 表示 FAB 一半在 BottomBar 上方
                if (widget.fabLocation == Alignment.topLeft ||
                    widget.fabLocation == Alignment.topCenter ||
                    widget.fabLocation == Alignment.topRight) {
                  // FAB 中心对齐 BottomBar 顶部
                  bottomOffset = widget.offset + _bottomBarHeight - 28;
                } else {
                  bottomOffset = widget.offset;
                }

                return Positioned(
                  bottom: bottomOffset,
                  left: left,
                  right: right,
                  child: widget.fab!,
                );
              },
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
