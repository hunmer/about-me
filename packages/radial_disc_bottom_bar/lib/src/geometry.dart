import 'dart:math' as math;
import 'dart:ui' show Offset, Path, Rect;

/// 弧形圆盘导航栏几何
///
/// 与参考实现（SVG 380×146 画布）保持一致：曲率圆心位于画布下方
/// (190, 636)，主 dock 与上层子栏是两条同心圆扇环，滑动药丸同样
/// 沿同心圆弧生成，保证与背景曲线完全贴合。
abstract final class RadialGeometry {
  static const double canvasWidth = 380;
  static const double canvasHeight = 146;
  static const double centerX = canvasWidth / 2; // 190
  static const double centerY = 636; // 曲率圆心，位于画布下方

  // 上层子栏扇环半径
  static const double subOuterRadius = 624; // 顶部弧线 y = 12
  static const double subInnerRadius = 588; // 厚度 36
  static const double subMidRadius = (subOuterRadius + subInnerRadius) / 2; // 606

  // 子栏滑动药丸（内外各缩进 2.5）
  static const double subPillOuterRadius = 621.5;
  static const double subPillInnerRadius = 590.5;

  // 主 dock 扇环半径
  static const double mainOuterRadius = 580; // 顶部弧线 y = 56
  static const double mainInnerRadius = 526; // 厚度 54
  static const double mainMidRadius = (mainOuterRadius + mainInnerRadius) / 2; // 553

  // 扇环角度范围（度）
  static const double mainSectorSpan = 16.2;
  static const double subSectorSpan = 10.8;

  // tab 沿主弧线的角度范围 ±13.5°
  static const double tabAngleSpan = 13.5;

  // 子栏元素角度
  static const double leadingAngle = -15.4; // 左圆按钮
  static const double trailingAngle = 15.4; // 右圆按钮
  static const double optionLeftAngle = -5.4; // 选项一
  static const double optionRightAngle = 5.4; // 选项二
  static const double subPillHalfWidth = 4.8; // 药丸角宽度的一半 (10.2-0.6)/2

  // 尺寸
  static const double pillWidth = 56;
  static const double pillHeight = 42;
  static const double pillRadius = 21;
  static const double tabButtonWidth = 48;
  static const double tabButtonHeight = 40;
  static const double roundButtonSize = 35;
  static const double optionButtonWidth = 92;
  static const double optionButtonHeight = 30;

  /// 背景扇环路径（预生成，静态复用）
  static final Path mainRibbon =
      annularSector(-mainSectorSpan, mainSectorSpan, mainInnerRadius, mainOuterRadius);
  static final Path subRibbon =
      annularSector(-subSectorSpan, subSectorSpan, subInnerRadius, subOuterRadius);

  /// 第 [index] 个（共 [count] 个）tab 的角度，均匀分布在 ±[span]
  static double tabAngle(
    int index,
    int count, {
    double span = tabAngleSpan,
  }) =>
      continuousTabAngle(index.toDouble(), count, span: span);

  /// 连续（可动画插值）的 tab 角度
  static double continuousTabAngle(
    double index,
    int count, {
    double span = tabAngleSpan,
  }) =>
      count <= 1 ? 0 : -span + 2 * span * index / (count - 1);

  /// 极坐标转画布坐标：0° 指向正上方（弧顶），正角向右
  static Offset polar(double angleDeg, double radius) {
    final rad = angleDeg * math.pi / 180;
    return Offset(
      centerX + radius * math.sin(rad),
      centerY - radius * math.cos(rad),
    );
  }

  /// 圆角扇环路径：内外同心圆弧 + 两端半圆帽
  ///
  /// 角度单位为度，范围 [minAngleDeg, maxAngleDeg]（0 为弧顶，正角向右）。
  static Path annularSector(
    double minAngleDeg,
    double maxAngleDeg,
    double innerRadius,
    double outerRadius,
  ) {
    final capRadius = (outerRadius - innerRadius) / 2;
    final midRadius = (outerRadius + innerRadius) / 2;
    final curvatureCenter = const Offset(centerX, centerY);
    final innerLeft = polar(minAngleDeg, innerRadius);
    final outerLeft = polar(minAngleDeg, outerRadius);
    final innerRight = polar(maxAngleDeg, innerRadius);
    final outerRight = polar(maxAngleDeg, outerRadius);
    final leftCapCenter = polar(minAngleDeg, midRadius);
    final rightCapCenter = polar(maxAngleDeg, midRadius);
    final sweep = (maxAngleDeg - minAngleDeg) * math.pi / 180;

    double angleOf(Offset point, Offset center) =>
        math.atan2(point.dy - center.dy, point.dx - center.dx);

    return Path()
      ..moveTo(innerLeft.dx, innerLeft.dy)
      // 左端半圆帽（内 → 外，顺时针）
      ..arcTo(
        Rect.fromCircle(center: leftCapCenter, radius: capRadius),
        angleOf(innerLeft, leftCapCenter),
        math.pi,
        false,
      )
      // 外弧（左 → 右，沿弧顶顺时针）
      ..arcTo(
        Rect.fromCircle(center: curvatureCenter, radius: outerRadius),
        angleOf(outerLeft, curvatureCenter),
        sweep,
        false,
      )
      // 右端半圆帽（外 → 内，顺时针）
      ..arcTo(
        Rect.fromCircle(center: rightCapCenter, radius: capRadius),
        angleOf(outerRight, rightCapCenter),
        math.pi,
        false,
      )
      // 内弧（右 → 左，回程逆时针）
      ..arcTo(
        Rect.fromCircle(center: curvatureCenter, radius: innerRadius),
        angleOf(innerRight, curvatureCenter),
        -sweep,
        false,
      )
      ..close();
  }
}
