import 'package:flutter/widgets.dart';
import 'package:radial_disc_bottom_bar/radial_disc_bottom_bar.dart';

import '../theme/app_theme.dart';
import 'icons.dart';

// 公开 API 用到的包类型透出给 design_system 使用方
export 'package:radial_disc_bottom_bar/radial_disc_bottom_bar.dart'
    show RadialSubOption, RadialSubBarBehavior, RadialSubAction;

/// 底部导航项
class DSNavItem {
  const DSNavItem({
    required this.icon,
    required this.label,
    this.showBadge = false,
  });

  final DsIconKind icon;
  final String label;

  /// 图标右上角小红点
  final bool showBadge;
}

/// 弧形圆盘底部导航栏：同心圆弧 dock + 沿切线滑动的选中药丸
///
/// 实现为 packages/radial_disc_bottom_bar 包的主 dock 层；
/// 可选启用磨砂玻璃扇环、子栏右圆钮位置浮动操作钮与上层子栏双选项。
class DSBottomNavigation extends StatelessWidget {
  const DSBottomNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.floatingAction,
    this.frosted = true,
    this.subLabels,
    this.subActions,
    this.subOption = RadialSubOption.left,
    this.onSubOptionChange,
    this.leadingAction,
    this.onLeadingTap,
    this.trailingAction,
    this.onTrailingTap,
    this.trailingSelected = false,
    this.subBarBehavior,
    this.subBarVisible,
  });

  final List<DSNavItem> items;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  /// 子栏右圆钮位置的常驻浮动操作钮（如添加按钮），自带手势与外观
  final Widget? floatingAction;

  /// 扇环磨砂玻璃（降低填充不透明度 + 背景模糊）
  final bool frosted;

  /// 上层子栏双选项文案（null 则不启用子栏）
  final (String, String)? subLabels;

  /// 上层子栏图标动作（与 [subLabels] 互斥），沿子栏弧线均匀排布
  final List<RadialSubAction>? subActions;

  final RadialSubOption subOption;
  final ValueChanged<RadialSubOption>? onSubOptionChange;

  /// 上层子栏左侧圆按钮图标（null 则不渲染该按钮）；提供后启用子栏
  final Widget? leadingAction;

  /// 子栏左侧圆按钮点击回调
  final VoidCallback? onLeadingTap;

  /// 上层子栏右侧圆按钮图标（null 则不渲染该按钮）
  final Widget? trailingAction;

  /// 子栏右侧圆按钮点击回调
  final VoidCallback? onTrailingTap;

  /// 右侧圆按钮激活态（主题色实底高亮）
  final bool trailingSelected;

  /// 覆盖子栏展示策略的默认推断；子栏元素随 tab 动态出现的宿主
  /// 应恒传 auto，否则占位高度会在有无子栏的 tab 间跳变
  /// （never 始终只保留主 dock 高度）
  final RadialSubBarBehavior? subBarBehavior;

  /// 手动控制子栏显隐（如仅部分 tab 启用子栏）；子栏元素需常驻
  /// （不随 tab 增删），显隐切换才有弹簧折叠过渡动画。
  /// 收起后子栏不可命中
  final bool? subBarVisible;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    var style = RadialDiscBarStyle.fromBrightness(theme.isDark).copyWith(
      // dock 描边用淡墨线，贴近手绘纸墨，两主题均清晰可见
      strokeColor: theme.ink.withValues(alpha: 0.7),
      activePillColor: theme.primary,
      activeIconColor: theme.onPrimary,
      inactiveIconColor: theme.textSub,
    );
    if (frosted) {
      // 磨砂模式降低填充不透明度，让背景模糊可见；填充取纸色贴近手绘纸面
      style = style.copyWith(
        fillColor: theme.paper.withValues(alpha: theme.isDark ? 0.8 : 0.7),
      );
    }

    Widget bar = RadialDiscBottomBar(
      tabs: [
        for (final item in items)
          RadialDiscTab(
            label: item.label,
            iconBuilder: (_, selected) => DsIcon(
              item.icon,
              size: 20,
              color: selected ? theme.onPrimary : theme.textSub,
            ),
            badge: item.showBadge
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.danger,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: theme.stroke, width: 1.4),
                    ),
                  )
                : null,
          ),
      ],
      activeIndex: currentIndex.clamp(0, items.length - 1),
      onTabChange: onTap,
      floatingAction: floatingAction,
      frosted: frosted,
      subBarBehavior:
          subBarBehavior ??
          (subLabels == null &&
              subActions == null &&
              leadingAction == null &&
              trailingAction == null
          ? RadialSubBarBehavior.never
          : RadialSubBarBehavior.auto),
      subLabels: subLabels,
      subActions: subActions,
      subOption: subOption,
      onSubOptionChange: onSubOptionChange,
      subBarVisible: subBarVisible,
      leadingAction: leadingAction,
      onLeadingTap: onLeadingTap,
      trailingAction: trailingAction,
      onTrailingTap: onTrailingTap,
      trailingSelected: trailingSelected,
      style: style,
    );

    // 弧形 dock 固有宽 380：更宽容器内居中，更窄容器等比缩小。
    // heightFactor:1 关键——底部外壳给的是全屏高的松约束，无 factor 的
    // Center 会撑满整屏把 dock 顶到屏幕中心，且透明装饰盒吞掉全部点击
    bar = Center(
      heightFactor: 1,
      child: FittedBox(fit: BoxFit.scaleDown, child: bar),
    );
    if (onTap == null) bar = IgnorePointer(child: bar);
    return bar;
  }
}
