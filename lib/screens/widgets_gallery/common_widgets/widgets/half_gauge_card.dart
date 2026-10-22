/// 半圆仪表盘小组件（条纹纸卡风格，参考 StripedWeeklyChartCard）
///
/// 圆角纸卡（内白描边 + 柔影 + 淡入上移入场）：圆形图标徽章 + 标题头部 /
/// 斜纹半圆仪表盘（灰底轨道 + 主题色斜纹进度扇环 + 深色指针）/ 0%-100% 刻度 /
/// 底部余额。仪表盘尺寸同时受宽高约束、内容上下居中，任意尺寸不溢出。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 半圆仪表盘小组件
class HalfGaugeCardWidget extends StatefulWidget {
  final String title;
  final double totalBudget;
  final double remaining;
  final String currency;

  /// 进度弧主题色（斜纹 + 描边）
  final Color activeColor;

  /// 进度弧底色
  final Color activeBackgroundColor;

  /// 组件尺寸
  final HomeWidgetSize size;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  const HalfGaugeCardWidget({
    super.key,
    this.title = 'Shopping',
    required this.totalBudget,
    required this.remaining,
    this.currency = 'AED',
    this.activeColor = const Color(0xFFD972F8),
    this.activeBackgroundColor = const Color(0xFFF3C4FF),
    this.size = const MediumSize(),
    this.inline = false,
  });

  /// 从 props 创建实例
  factory HalfGaugeCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return HalfGaugeCardWidget(
      title: props['title'] as String? ?? 'Shopping',
      totalBudget: (props['totalBudget'] as num?)?.toDouble() ?? 0.0,
      remaining: (props['remaining'] as num?)?.toDouble() ?? 0.0,
      currency: props['currency'] as String? ?? 'AED',
      activeColor: _parseColor(
        props['activeColor'],
        const Color(0xFFD972F8),
      ),
      activeBackgroundColor: _parseColor(
        props['activeBackgroundColor'],
        const Color(0xFFF3C4FF),
      ),
      size: size,
      inline: props['inline'] as bool? ?? false,
    );
  }

  @override
  State<HalfGaugeCardWidget> createState() => _HalfGaugeCardWidgetState();
}

class _HalfGaugeCardWidgetState extends State<HalfGaugeCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  double get progress => widget.totalBudget <= 0
      ? 0.0
      : (widget.totalBudget - widget.remaining) / widget.totalBudget;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HalfGaugeCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalBudget != widget.totalBudget ||
        oldWidget.remaining != widget.remaining) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  double _defaultHeight() {
    final scale = widget.size.scale;
    if (widget.size is SmallSize) return 150 * scale;
    if (widget.size is MediumSize || widget.size is WideSize) {
      return 190 * scale;
    }
    if (widget.size is LargeSize || widget.size is Wide2Size) {
      return 330 * scale;
    }
    return 430 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = widget.size.scale;

    return AnimatedBuilder(
      animation: _progressAnimation,
      child: Container(
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF9FBFD),
          borderRadius: BorderRadius.circular(30 * scale),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.white,
            width: scale,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.28 : 0.05),
              blurRadius: 20 * scale,
              offset: Offset(0, 5 * scale),
            ),
          ],
        ),
        child: Padding(
          padding: widget.size.getPadding(),
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _buildContent(isDark, constraints),
          ),
        ),
      ),
      builder: (context, child) {
        return Opacity(
          opacity: _progressAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - _progressAnimation.value)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildContent(bool isDark, BoxConstraints constraints) {
    final scale = widget.size.scale;
    final titleFontSize = widget.size.getSubtitleFontSize() + 2 * scale;
    final gaugeAmountFontSize = widget.size.getSubtitleFontSize() + 2;
    final gaugeIconSize = widget.size.getIconSize();
    final gaugeLabelFontSize = widget.size.getLegendFontSize();
    final gaugeRemainLabelFontSize = widget.size.getLegendFontSize() - 2;
    final gapUnit = widget.size.getSmallSpacing() * 2;

    // 头部徽章随卡片高度收敛，矮卡不挤占仪表盘空间
    final badgeSize = constraints.maxHeight.isFinite
        ? math.min(44 * scale, constraints.maxHeight * 0.24)
        : 44 * scale;

    // 仪表盘同时受宽度与高度预算约束，杜绝小尺寸下溢出：
    // 画布高 ≈ 宽 * 0.56（半圆 + 笔宽余量），刻度行可让位
    var gaugeWidth = constraints.maxWidth * 0.82;
    var showLabels = true;
    if (constraints.maxHeight.isFinite) {
      final reserved =
          badgeSize + gapUnit * 2 + gaugeAmountFontSize * 1.6;
      final withLabels =
          (constraints.maxHeight - reserved - gaugeLabelFontSize * 1.6) / 0.6;
      if (withLabels >= 64) {
        gaugeWidth = math.min(gaugeWidth, withLabels);
      } else {
        showLabels = false;
        gaugeWidth = math.min(
          gaugeWidth,
          (constraints.maxHeight - reserved) / 0.6,
        );
      }
    }
    gaugeWidth = math.max(gaugeWidth, 48);
    final showRemainBlock = gaugeWidth >= 96;
    final gaugeCanvasHeight = gaugeWidth * 0.56;

    Widget gaugeBlock = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 半圆仪表盘 + 中央剩余提示
        SizedBox(
          width: gaugeWidth,
          height: gaugeCanvasHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(gaugeWidth, gaugeCanvasHeight),
                      painter: _StripedGaugePainter(
                        sweep: progress * _progressAnimation.value,
                        activeColor: widget.activeColor,
                        activeBackgroundColor: widget.activeBackgroundColor,
                        isDark: isDark,
                        scale: scale,
                      ),
                    );
                  },
                ),
              ),
              if (showRemainBlock)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: gaugeCanvasHeight * 0.08,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'REMAIN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: gaugeRemainLabelFontSize,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF7C8088),
                        ),
                      ),
                      SizedBox(height: widget.size.getSmallSpacing() * 2),
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: gaugeIconSize,
                        color: isDark ? Colors.white : const Color(0xFF3B82F6),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // 刻度标记
        if (showLabels)
          SizedBox(
            width: gaugeWidth,
            height: gaugeLabelFontSize * 1.6,
            child: Stack(
              children: [
                for (final (label, align) in const [
                  ('0%', Alignment.centerLeft),
                  ('50%', Alignment.center),
                  ('100%', Alignment.centerRight),
                ])
                  Align(
                    alignment: align,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: gaugeLabelFontSize,
                        fontWeight: FontWeight.w500,
                        height: 1,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF52555C),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        SizedBox(height: gapUnit),

        // 底部金额显示
        Text(
          '${_formatAmount(widget.remaining)}.${_getDecimalPart(widget.remaining)} / ${_formatAmount(widget.totalBudget)}.${_getDecimalPart(widget.totalBudget)} (${widget.currency})',
          style: TextStyle(
            fontSize: gaugeAmountFontSize,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: isDark ? Colors.white : const Color(0xFF141414),
          ),
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
    if (constraints.maxHeight.isFinite) {
      gaugeBlock = Expanded(child: Center(child: gaugeBlock));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(isDark, badgeSize, titleFontSize),
        SizedBox(height: gapUnit),
        gaugeBlock,
      ],
    );
  }

  /// 头部：圆形图标徽章 + 标题（+ 币种副标题）
  Widget _buildHeader(bool isDark, double badgeSize, double titleFontSize) {
    final scale = widget.size.scale;
    return Row(
      children: [
        Container(
          width: badgeSize,
          height: badgeSize,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFDCE4EC),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? Colors.white24 : const Color(0xFF222222),
              width: scale,
            ),
          ),
          child: Icon(
            Icons.shopping_bag_outlined,
            size: badgeSize * 0.55,
            color: isDark ? Colors.white : const Color(0xFF3B82F6),
          ),
        ),
        SizedBox(width: 12 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF141414),
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.currency.isNotEmpty) ...[
                SizedBox(height: 3 * scale),
                Text(
                  widget.currency,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF7C8088),
                    fontSize: widget.size.getLegendFontSize(),
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatAmount(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    return parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _getDecimalPart(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    return parts[1];
  }
}

/// 斜纹半圆仪表盘绘制器
///
/// 灰底轨道扇环（淡灰斜纹 + 灰描边）垫底，主题色进度扇环（浅色底 +
/// 浓斜纹 + 主题色描边）按 [sweep]（0~1，含入场动画插值）扫过，
/// 指针为径向深色实心小三角。
class _StripedGaugePainter extends CustomPainter {
  final double sweep;
  final Color activeColor;
  final Color activeBackgroundColor;
  final bool isDark;
  final double scale;

  const _StripedGaugePainter({
    required this.sweep,
    required this.activeColor,
    required this.activeBackgroundColor,
    required this.isDark,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final thickness = math.max(10.0, size.width * 0.11);
    final center = Offset(size.width / 2, size.height - thickness * 0.35);
    final rOut = size.width / 2 - 2;
    final rIn = rOut - thickness;
    final inset = math.asin(
      math.min(1.0, thickness * 0.6 / ((rIn + rOut) / 2)),
    );
    final start = math.pi + inset;
    final span = math.pi - 2 * inset;

    // 轨道扇环
    final trackPath = _sector(center, rIn, rOut, start, start + span);
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = isDark ? const Color(0xFF334155) : const Color(0xFFE4E6E9),
    );
    _paintStripes(
      canvas,
      trackPath,
      size,
      (isDark ? const Color(0xFF94A3B8) : const Color(0xFF9BA0A8))
          .withOpacity(0.45),
      1.5 * scale,
    );
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = isDark ? const Color(0xFF64748B) : const Color(0xFF595959)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    final s = sweep.clamp(0.0, 1.0);
    if (s <= 0.004) return;

    // 进度扇环
    final progressPath = _sector(center, rIn, rOut, start, start + span * s);
    canvas.drawPath(progressPath, Paint()..color = activeBackgroundColor);
    _paintStripes(
      canvas,
      progressPath,
      size,
      activeColor.withOpacity(0.9),
      3 * scale,
    );
    canvas.drawPath(
      progressPath,
      Paint()
        ..color = activeColor.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    // 指针：径向深色小三角
    final angle = start + span * s;
    final dir = Offset(math.cos(angle), math.sin(angle));
    final tang = Offset(-dir.dy, dir.dx);
    final ps = thickness * 0.42;
    final tip = center + dir * (rOut - thickness * 0.06);
    final base = center + dir * (rIn + thickness * 0.06);
    final pointer =
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(base.dx + tang.dx * ps, base.dy + tang.dy * ps)
          ..lineTo(base.dx - tang.dx * ps, base.dy - tang.dy * ps)
          ..close();
    canvas.drawPath(
      pointer,
      Paint()..color = isDark ? Colors.white : const Color(0xFF222222),
    );
  }

  /// 在 [clip] 内铺斜纹（与 StripedWeeklyChartCard 柱纹同款：右上斜率 0.85）
  void _paintStripes(
    Canvas canvas,
    Path clip,
    Size size,
    Color color,
    double strokeWidth,
  ) {
    canvas.save();
    canvas.clipPath(clip);
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;
    final spacing = 6.5 * scale;
    final h = size.height + 4;
    for (var x = -h; x < size.width + h; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height + 2),
        Offset(x + h * 0.85, -2),
        paint,
      );
    }
    canvas.restore();
  }

  Path _sector(Offset c, double rIn, double rOut, double a0, double a1) {
    final largeArc = (a1 - a0) > math.pi;
    final path = Path();
    path.moveTo(c.dx + rOut * math.cos(a0), c.dy + rOut * math.sin(a0));
    path.arcToPoint(
      Offset(c.dx + rOut * math.cos(a1), c.dy + rOut * math.sin(a1)),
      radius: Radius.circular(rOut),
      largeArc: largeArc,
      clockwise: true,
    );
    path.lineTo(c.dx + rIn * math.cos(a1), c.dy + rIn * math.sin(a1));
    path.arcToPoint(
      Offset(c.dx + rIn * math.cos(a0), c.dy + rIn * math.sin(a0)),
      radius: Radius.circular(rIn),
      largeArc: largeArc,
      clockwise: false,
    );
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _StripedGaugePainter oldDelegate) {
    return oldDelegate.sweep != sweep ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.activeBackgroundColor != activeBackgroundColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.scale != scale;
  }
}

Color _parseColor(dynamic value, Color fallback) {
  if (value is Color) return value;
  if (value is int) return Color(value);
  if (value is String) {
    try {
      final hex = value.startsWith('#')
          ? value.substring(1)
          : value.startsWith('0x')
          ? value.substring(2)
          : '';
      if (hex.length == 6) {
        return Color(0xFF000000 | int.parse(hex, radix: 16));
      }
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }
  return fallback;
}
