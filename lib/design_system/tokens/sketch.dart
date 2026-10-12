/// 手绘风格共享层：skribble rough 引擎的统一封装
///
/// 全部组件的手绘墨线都从这一个文件出去，保证：
/// - 墨色/纸色/笔宽与 [AppThemeData] 语义色一致（深浅模式自动适配）
/// - 粗糙度、笔刷走同一套 DrawConfig（与 Wired* 组件同源）
/// - 固定 seed：rebuild 时墨迹不抖变
///
/// 填充分档（项目约定）：
/// - 小控件（按钮/输入框/勾选框）：纯色实底 + 墨线描边
/// - 大容器（卡片/对话框/面板）：纸底 + 淡排线（hachure）
library;

import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';

/// 手绘主题派生：从语义主题取墨/纸/笔参数
extension DsSketchTheme on AppThemeData {
  /// 墨线色：手绘描边与手绘图标的主色
  Color get ink => isDark ? text : DsColors.text;

  /// 纸色：手绘件填充底色
  Color get paper => surface;

  /// 排线色：大容器的淡彩涂色（主色调淡）
  Color get hatch => primary.withValues(alpha: isDark ? 0.30 : 0.22);

  /// 对应的 skribble 主题：Wired* 组件经 WiredTheme.of 取色的数据源
  WiredThemeData get wired => _wiredCache[this] ??= WiredThemeData(
        borderColor: isDark ? text : DsColors.text,
        textColor: text,
        disabledTextColor: textSub,
        fillColor: surface,
        markerColor: primary,
        strokeWidth: 2.2,
        roughnessLevel: WiredRoughness.playful,
      );
}

/// [AppThemeData] 实例 → WiredThemeData 缓存（AppThemeData 是 const 构造，
/// 实例在主题切换间稳定，缓存避免每次 build 重建作用域）
final Expando<WiredThemeData> _wiredCache = Expando();

/// 统一手绘装饰构造器
///
/// 返回 [RoughBoxDecoration]（Decoration 子类，直接给 Container.decoration）。
///
/// - [fillColor] 非空时按 [hachure] 决定填充：排线（大容器）或纯色实底（小控件）
/// - [stroke] 默认墨线；pill 圆角（999）会被 rough 引擎自动钳制成胶囊
/// - [seed] 保持稳定默认值即可；列表项可传唯一值增加墨迹变化
RoughBoxDecoration dsSketchDecoration({
  required AppThemeData theme,
  Color? fillColor,
  Color? stroke,
  double strokeWidth = 1.8,
  BorderRadius? radius,
  bool circle = false,
  bool hachure = false,
  Color? hachureColor,
  double hachureGap = 8,
  int seed = 1,
}) {
  final Filler? filler = fillColor == null
      ? null
      : hachure
          ? HachureFiller(
              FillerConfig.build(
                drawConfig: theme.wired.drawConfig,
                hachureGap: hachureGap,
                fillWeight: 1.4,
              ),
            )
          : SolidFiller();
  return RoughBoxDecoration(
    shape: circle
        ? RoughBoxShape.circle
        : (radius == null
            ? RoughBoxShape.rectangle
            : RoughBoxShape.roundedRectangle),
    borderRadius: circle ? null : (radius ?? BorderRadius.zero),
    borderStyle: RoughDrawingStyle(
      width: strokeWidth,
      color: stroke ?? theme.ink,
    ),
    fillStyle: fillColor == null
        ? null
        : RoughDrawingStyle(
            color: hachure ? (hachureColor ?? theme.hatch) : fillColor,
          ),
    filler: filler,
    drawConfig: theme.wired.drawConfig,
    seed: seed,
  );
}

/// 大容器手绘面板：纸底 + 淡排线 + 墨线框（内容层在排线之上）
///
/// 大面积容器（卡片/对话框/浮层面板）的标准组合。
class DsSketchPanel extends StatelessWidget {
  const DsSketchPanel({
    super.key,
    this.child,
    required this.theme,
    this.fillColor,
    this.radius,
    this.padding,
    this.width,
    this.height,
    this.stroke,
    this.hachureColor,
    this.alignment,
    this.hachure = true,
    this.seed = 1,
  });

  final Widget? child;
  final AppThemeData theme;

  /// 纸底色（默认主题 surface）
  final Color? fillColor;
  final BorderRadius? radius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? stroke;
  final Color? hachureColor;
  final AlignmentGeometry? alignment;

  /// 关闭后不画排线（纯纸底 + 描边）
  final bool hachure;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        color: fillColor ?? theme.surface,
        borderRadius: radius,
      ),
      child: Container(
        decoration: dsSketchDecoration(
          theme: theme,
          radius: radius,
          stroke: stroke,
          fillColor: hachure ? DsColors.transparent : null,
          hachure: hachure,
          hachureColor: hachureColor,
          hachureGap: 10,
          seed: seed,
        ),
        child: child,
      ),
    );
  }
}

/// 局部墨色作用域：让某个 Wired*/自绘组件用指定描边色/标记色
///
/// Wired* 组件从 `WiredTheme.of(context)` 取色，嵌套本作用域即可
/// 实现「危险按钮红墨、主按钮紫墨」的组件级变色，不影响外层主题。
class DsInkScope extends StatelessWidget {
  const DsInkScope({
    super.key,
    required this.child,
    this.border,
    this.text,
    this.fill,
    this.marker,
  });

  final Widget child;
  final Color? border;
  final Color? text;
  final Color? fill;
  final Color? marker;

  @override
  Widget build(BuildContext context) {
    final data = WiredTheme.of(context).copyWith(
      borderColor: border,
      textColor: text,
      fillColor: fill,
      markerColor: marker,
    );
    return WiredThemeScope(data: data, child: child);
  }
}
