/// 条纹纸卡风格的公共斜纹绘制工具
///
/// 手绘纸卡风小组件（半圆仪表盘 / 分段进度条等）共用的斜纹填充：
/// 右上斜线（斜率 0.85），纹宽与间距由调用方随卡片 scale 缩放。
/// 参考视觉源头：StripedWeeklyChartCard 的条纹柱。
library;

import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, Rect;

/// 在 [clip] 裁剪区域内铺斜纹
///
/// [bounds] 为铺纹覆盖的包围盒；条纹会向左右各多延伸一个高度，
/// 保证斜线贯穿任意角度的裁剪区域（扇环、胶囊、矩形均可）。
/// [spacing] 为条纹横向间距，[slope] 为水平/垂直斜率（0.85 ≈ 50°）。
void paintDiagonalStripes(
  Canvas canvas,
  Path clip,
  Rect bounds, {
  required Color color,
  required double strokeWidth,
  double spacing = 6.5,
  double slope = 0.85,
}) {
  canvas.save();
  canvas.clipPath(clip);
  final paint =
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
  final h = bounds.height + 4;
  for (var x = bounds.left - h; x < bounds.right + h; x += spacing) {
    canvas.drawLine(
      Offset(x, bounds.bottom + 2),
      Offset(x + h * slope, bounds.top - 2),
      paint,
    );
  }
  canvas.restore();
}
