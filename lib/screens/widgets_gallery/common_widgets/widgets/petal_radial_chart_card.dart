import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 花瓣径向统计卡片
///
/// 将圆等分为若干扇形花瓣：底层为满幅的圆角扇形（track），
/// 上层按数值比例填充彩色花瓣，每个花瓣沿分角线标注数值与标签。
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

class _PetalRadialChartCardWidgetState
    extends State<PetalRadialChartCardWidget>
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + 0.7 * _animation.value,
          child: child,
        );
      },
      child: Container(
        width: widget.inline ? double.maxFinite : 384 * widget.size.scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF191919) : Colors.white,
          borderRadius: BorderRadius.circular(24 * widget.size.scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 20 * widget.size.scale,
              offset: Offset(0, 4 * widget.size.scale),
            ),
          ],
        ),
        child: Padding(
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
                      color: isDark ? Colors.white : const Color(0xFF211D15),
                      fontSize: widget.size.getTitleFontSize(),
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
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
                            isDark: isDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 花瓣径向统计图绘制器
class _PetalRadialChartPainter extends CustomPainter {
  final List<PetalChartItemData> items;
  final double maxValue;
  final double progress;
  final int fractionDigits;
  final bool showText;
  final bool isDark;

  _PetalRadialChartPainter({
    required this.items,
    required this.maxValue,
    required this.progress,
    required this.fractionDigits,
    required this.showText,
    required this.isDark,
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

    // 底瓣（满幅 track）
    final trackPaint =
        Paint()
          ..color = isDark ? const Color(0xFF4A4A4A) : const Color(0xFFE9E6E0)
          ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final path = _petalPath(
        center: center,
        rOuter: rOuter,
        rInner: rInner,
        a1: startAngle + i * sweep + gapAngle / 2,
        a2: startAngle + (i + 1) * sweep - gapAngle / 2,
      );
      canvas.drawPath(path, trackPaint);
    }

    // 填充花瓣
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
        Paint()
          ..color = item.color
          ..style = PaintingStyle.fill,
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
    );
    final labelStyle = TextStyle(
      fontSize: labelFontSize,
      fontWeight: FontWeight.w500,
      height: 1.15,
    );

    // 以原始字号测量两行文字块的高度，文字块最内侧半径处的弦宽为收缩基准
    final measureTp = TextPainter(
      text: TextSpan(children: [
        const TextSpan(text: '0'),
        const TextSpan(text: '\nA', style: TextStyle(height: 1.15)),
      ], style: numberStyle),
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

      final trackNumberColor =
          isDark ? Colors.white : const Color(0xFF333333);
      final trackLabelColor = isDark
          ? const Color(0xFFBFBFBF)
          : const Color(0xFF777777);
      // 填充花瓣为浅色，其上文字统一用深色
      const onFillColor = Color(0xFF1C1C1C);

      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(
            text: number,
            style: numberStyle.copyWith(
              fontSize: numberFontSize * scale,
              color: onFill ? onFillColor : trackNumberColor,
            ),
          ),
          TextSpan(
            text: '\n${item.label}',
            style: labelStyle.copyWith(
              fontSize: labelFontSize * scale,
              color: onFill
                  ? onFillColor.withOpacity(0.8)
                  : trackLabelColor,
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
        oldDelegate.isDark != isDark ||
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
