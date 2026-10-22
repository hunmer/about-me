/// 花瓣径向统计卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 将圆等分为若干扇形花瓣：底层为满幅淡墨斜纹轨道花瓣，
/// 上层按数值比例填充数据色斜纹花瓣，每个花瓣沿分角线标注数值与标签。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

class PetalRadialChartCardWidget extends StatefulWidget {
  /// 花瓣数据列表
  final List<PetalChartItemData> items;

  /// 数值上限（用于计算填充比例），为 null 时取 items 中的最大值
  final double? maxValue;

  /// 卡片标题，为 null 时不显示
  final String? title;

  /// 数值显示的小数位（默认 0，如 12）
  final int fractionDigits;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const PetalRadialChartCardWidget({
    super.key,
    required this.items,
    this.maxValue,
    this.title,
    this.fractionDigits = 0,
    this.inline = false,
    this.size = const LargeSize(),
  });

  /// 从 props 创建实例
  factory PetalRadialChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    // 解析颜色
    Color parseColor(dynamic colorValue) {
      if (colorValue == null) return Colors.blue;
      if (colorValue is Color) return colorValue;
      if (colorValue is int) return Color(colorValue);
      if (colorValue is String) {
        try {
          if (colorValue.startsWith('#')) {
            return Color(
              int.parse(colorValue.substring(1), radix: 16) + 0xFF000000,
            );
          }
          if (colorValue.startsWith('0x')) {
            return Color(int.parse(colorValue.substring(2), radix: 16));
          }
        } catch (e) {
          // 解析失败，返回默认颜色
        }
      }
      return Colors.blue;
    }

    // 解析花瓣数据
    List<PetalChartItemData> parseItems(dynamic itemsData) {
      if (itemsData == null) return [];
      if (itemsData is List) {
        return itemsData.map((item) {
          if (item is Map<String, dynamic>) {
            return PetalChartItemData(
              label: item['label'] as String? ?? '',
              value: (item['value'] as num?)?.toDouble() ?? 0.0,
              color: parseColor(item['color']),
            );
          }
          return PetalChartItemData(
            label: '',
            value: 0,
            color: Colors.blue,
          );
        }).toList();
      }
      return [];
    }

    return PetalRadialChartCardWidget(
      items: parseItems(props['items']),
      maxValue: (props['maxValue'] as num?)?.toDouble(),
      title: props['title'] as String?,
      fractionDigits: (props['fractionDigits'] as num?)?.toInt() ?? 0,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<PetalRadialChartCardWidget> createState() =>
      _PetalRadialChartCardWidgetState();
}

class _PetalRadialChartCardWidgetState extends State<PetalRadialChartCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.addListener(() {
      setState(() {});
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double _defaultHeight() {
    final scale = widget.size.scale;
    if (widget.size is SmallSize || widget.size is MediumSize) {
      return 170 * scale;
    }
    if (widget.size is Large3Size || widget.size is Wide3Size) {
      return 380 * scale;
    }
    return 300 * scale;
  }

  double get _effectiveMaxValue {
    if (widget.maxValue != null && widget.maxValue! > 0) {
      return widget.maxValue!;
    }
    final maxItem = widget.items.fold<double>(
      0,
      (max, item) => item.value > max ? item.value : max,
    );
    return maxItem > 0 ? maxItem : 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * widget.size.scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        radius: BorderRadius.circular(24 * widget.size.scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title != null)
              Padding(
                padding: EdgeInsets.only(
                  bottom: widget.size.getItemSpacing() * 1.5,
                ),
                child: Text(
                  widget.title!,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: widget.size.getTitleFontSize(),
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            // AnimatedBuilder 驱动花瓣径向生长 rebuild，否则 progress 恒为首帧 0
            Expanded(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final side = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                  return Center(
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: CustomPaint(
                        painter: _PetalRadialChartPainter(
                          items: widget.items,
                          maxValue: _effectiveMaxValue,
                          progress: _animation.value,
                          fractionDigits: widget.fractionDigits,
                          showText: widget.size is! SmallSize,
                          theme: theme,
                          scale: widget.size.scale,
                        ),
                      ),
                    ),
                  );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 花瓣径向统计图绘制器（平直几何 + 斜纹）
///
/// 底瓣为满幅轨道（surfaceAlt 底 + 淡墨斜纹 + 淡描边），
/// 填充花瓣为数据色浅底 + 浓斜纹 + 数据色描边，按 [progress] 径向生长；
/// 文字颜色一律取 [theme] 语义色。
class _PetalRadialChartPainter extends CustomPainter {
  final List<PetalChartItemData> items;
  final double maxValue;
  final double progress;
  final int fractionDigits;
  final bool showText;
  final AppThemeData theme;
  final double scale;

  _PetalRadialChartPainter({
    required this.items,
    required this.maxValue,
    required this.progress,
    required this.fractionDigits,
    required this.showText,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width / 2;
    // 花瓣汇聚于中心，不留中心孔
    final rInner = 0.0;
    final n = items.length;
    final sweep = 2 * math.pi / n;
    // 第一个扇形的边界位于正上方
    final startAngle = -math.pi / 2 - sweep / 2;
    // 花瓣之间的角间隙
    final gapAngle = math.min(sweep * 0.12, 2 * math.pi * 0.02);
    final bounds = Offset.zero & size;

    // 底瓣（满幅轨道：淡墨底 + 低透明度斜纹 + 淡描边）
    for (int i = 0; i < n; i++) {
      final path = _petalPath(
        center: center,
        rOuter: rOuter,
        rInner: rInner,
        a1: startAngle + i * sweep + gapAngle / 2,
        a2: startAngle + (i + 1) * sweep - gapAngle / 2,
      );
      canvas.drawPath(path, Paint()..color = theme.surfaceAlt);
      paintDiagonalStripes(
        canvas,
        path,
        bounds,
        color: theme.ink.withValues(alpha: 0.28),
        strokeWidth: 1.5 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.ink.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }

    // 填充花瓣（数据色浅底 + 浓斜纹 + 描边）
    for (int i = 0; i < n; i++) {
      final item = items[i];
      final fraction = (item.value / maxValue).clamp(0.0, 1.0).toDouble();
      final rFill =
          rInner +
          (rOuter - rInner) * fraction * progress -
          rOuter * 0.02 * (1 - progress);
      if (rFill <= rInner + 1) continue;

      final path = _petalPath(
        center: center,
        rOuter: rFill,
        rInner: rInner,
        a1: startAngle + i * sweep + gapAngle / 2,
        a2: startAngle + (i + 1) * sweep - gapAngle / 2,
      );
      canvas.drawPath(
        path,
        Paint()..color = item.color.withValues(alpha: 0.28),
      );
      paintDiagonalStripes(
        canvas,
        path,
        bounds,
        color: item.color.withValues(alpha: 0.9),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = item.color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }

    // 数值与标签（数值在上、标签在下的竖排文字块，按扇形弦宽自适应缩放）
    if (!showText) return;

    final halfAngle = (sweep - gapAngle) / 2;
    final blockRadius = rInner + (rOuter - rInner) * 0.72;
    final textScale = math.min(1.0, 10 / n);

    final numberFontSize = rOuter * 0.13;
    final labelFontSize = rOuter * 0.085;
    final numberStyle = TextStyle(
      fontSize: numberFontSize,
      fontWeight: FontWeight.w800,
      height: 1.1,
      color: theme.text,
    );
    final labelStyle = TextStyle(
      fontSize: labelFontSize,
      fontWeight: FontWeight.w500,
      height: 1.15,
      color: theme.textSub,
    );

    // 以原始字号测量两行文字块的高度，文字块最内侧半径处的弦宽为收缩基准
    final measureTp = TextPainter(
      text: TextSpan(children: [
        TextSpan(text: '0', style: numberStyle),
        TextSpan(text: '\nA', style: labelStyle),
      ]),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final innerRadius = (blockRadius - measureTp.height / 2).clamp(
      rInner + 4,
      double.infinity,
    );
    final chord =
        math.max(8.0, 2 * innerRadius * math.sin(halfAngle) * 0.88);

    for (int i = 0; i < n; i++) {
      final item = items[i];
      final bisector = startAngle + (i + 0.5) * sweep;
      final fraction = (item.value / maxValue).clamp(0.0, 1.0).toDouble();
      final rFill = rInner + (rOuter - rInner) * fraction;
      final onFill = blockRadius <= rFill;

      final number = item.value.toStringAsFixed(fractionDigits);
      // 按两行中较宽的一行收缩字号，保证不超出扇形
      final scale =
          math.min(
            _fitScale(number, numberStyle, chord),
            _fitScale(item.label, labelStyle, chord),
          ) *
          textScale;

      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(
            text: number,
            style: numberStyle.copyWith(
              fontSize: numberFontSize * scale,
              color: onFill ? theme.ink : theme.text,
            ),
          ),
          TextSpan(
            text: '\n${item.label}',
            style: labelStyle.copyWith(
              fontSize: labelFontSize * scale,
              color: theme.textSub,
            ),
          ),
        ]),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final pos = center + Offset(
        blockRadius * math.cos(bisector),
        blockRadius * math.sin(bisector),
      );
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// 计算文字在不超过 [maxWidth] 时的字号缩放系数
  double _fitScale(String text, TextStyle style, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return math.min(1.0, maxWidth / tp.width);
  }

  /// 圆角扇形（花瓣）路径：外缘弧 + 四角圆角；rInner 为 0 时花瓣汇聚于中心尖点
  Path _petalPath({
    required Offset center,
    required double rOuter,
    required double rInner,
    required double a1,
    required double a2,
  }) {
    final sweep = a2 - a1;
    final radialLength = rOuter - rInner;
    // 圆角随花瓣尺寸等比缩放，保证端部圆润
    final outerRc = math.min(15.0, math.max(3.0, radialLength * 0.32));
    final outerCornerSweep = outerRc / rOuter;

    Offset polar(double r, double a) =>
        center + Offset(r * math.cos(a), r * math.sin(a));

    // 汇聚于中心尖点的花瓣
    if (rInner <= 0) {
      return Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(polar(rOuter - outerRc, a1).dx, polar(rOuter - outerRc, a1).dy)
        ..quadraticBezierTo(
          polar(rOuter, a1).dx,
          polar(rOuter, a1).dy,
          polar(rOuter, a1 + outerCornerSweep).dx,
          polar(rOuter, a1 + outerCornerSweep).dy,
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: rOuter),
          a1 + outerCornerSweep,
          sweep - 2 * outerCornerSweep,
          false,
        )
        ..quadraticBezierTo(
          polar(rOuter, a2).dx,
          polar(rOuter, a2).dy,
          polar(rOuter - outerRc, a2).dx,
          polar(rOuter - outerRc, a2).dy,
        )
        ..lineTo(center.dx, center.dy)
        ..close();
    }

    final innerRc = math.min(2.0, math.max(1.0, radialLength * 0.1));
    final innerCornerSweep = innerRc / rInner;

    final path = Path()
      // 左径向边底部（内左角圆角之后）
      ..moveTo(
        polar(rInner + innerRc, a1 + innerCornerSweep).dx,
        polar(rInner + innerRc, a1 + innerCornerSweep).dy,
      )
      // 左径向边向上
      ..lineTo(polar(rOuter - outerRc, a1).dx, polar(rOuter - outerRc, a1).dy)
      // 外左角圆角
      ..quadraticBezierTo(
        polar(rOuter, a1).dx,
        polar(rOuter, a1).dy,
        polar(rOuter, a1 + outerCornerSweep).dx,
        polar(rOuter, a1 + outerCornerSweep).dy,
      )
      // 外缘弧
      ..arcTo(
        Rect.fromCircle(center: center, radius: rOuter),
        a1 + outerCornerSweep,
        sweep - 2 * outerCornerSweep,
        false,
      )
      // 外右角圆角
      ..quadraticBezierTo(
        polar(rOuter, a2).dx,
        polar(rOuter, a2).dy,
        polar(rOuter - outerRc, a2).dx,
        polar(rOuter - outerRc, a2).dy,
      )
      // 右径向边向内
      ..lineTo(polar(rInner + innerRc, a2).dx, polar(rInner + innerRc, a2).dy)
      // 内右角圆角
      ..quadraticBezierTo(
        polar(rInner, a2).dx,
        polar(rInner, a2).dy,
        polar(rInner, a2 - innerCornerSweep).dx,
        polar(rInner, a2 - innerCornerSweep).dy,
      )
      // 内缘弧（逆时针）
      ..arcTo(
        Rect.fromCircle(center: center, radius: rInner),
        a2 - innerCornerSweep,
        -(sweep - 2 * innerCornerSweep),
        false,
      )
      // 内左角圆角
      ..quadraticBezierTo(
        polar(rInner, a1).dx,
        polar(rInner, a1).dy,
        polar(rInner + innerRc, a1).dx,
        polar(rInner + innerRc, a1).dy,
      )
      ..close();

    return path;
  }

  @override
  bool shouldRepaint(covariant _PetalRadialChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale ||
        oldDelegate.items.length != items.length;
  }
}

/// 花瓣统计数据模型
class PetalChartItemData {
  /// 标签（如 'Happiness'）
  final String label;

  /// 数值（如 12）
  final double value;

  /// 填充颜色
  final Color color;

  const PetalChartItemData({
    required this.label,
    required this.value,
    required this.color,
  });
}
