/// 渐变进度卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 圆形图标徽章 + 标题 / 标签与百分比 / 斜纹进度条
/// （accent 数据色斜纹数据段 + 淡墨轨道胶囊 + 纸底指示圆点，可拖动）。
/// [gradientColors] 为旧渐变轨道字段，仅为 props 兼容保留。
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

class GradientProgressCardWidget extends StatefulWidget {
  final String title;
  final String label;
  final double progress;
  final IconData icon;
  final List<Color> gradientColors;
  final Color accentColor;
  final ValueChanged<double>? onChanged;
  final bool inline;
  final HomeWidgetSize size;

  const GradientProgressCardWidget({
    super.key,
    this.title = '',
    this.label = '',
    this.progress = 0,
    this.icon = Icons.analytics_rounded,
    this.gradientColors = const [
      Color(0xFFCBBBE3),
      Color(0xFFF5E5B8),
      Color(0xFFFCE1D9),
      Color(0xFFD88AF8),
    ],
    this.accentColor = const Color(0xFFDF92F7),
    this.onChanged,
    this.inline = false,
    this.size = const Large3Size(),
  });

  factory GradientProgressCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final rawColors = props['gradientColors'];
    final colors = rawColors is List
        ? rawColors
              .map((value) => _parseColor(value, Colors.transparent))
              .toList()
        : <Color>[];

    return GradientProgressCardWidget(
      title: props['title'] as String? ?? '',
      label: props['label'] as String? ?? '',
      progress: (props['progress'] as num?)?.toDouble() ?? 0,
      icon: _parseIcon(props['icon'], Icons.analytics_rounded),
      gradientColors: colors.length >= 2
          ? colors
          : const [
              Color(0xFFCBBBE3),
              Color(0xFFF5E5B8),
              Color(0xFFFCE1D9),
              Color(0xFFD88AF8),
            ],
      accentColor: _parseColor(props['accentColor'], const Color(0xFFDF92F7)),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<GradientProgressCardWidget> createState() =>
      _GradientProgressCardWidgetState();
}

class _GradientProgressCardWidgetState extends State<GradientProgressCardWidget> {
  late double _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.progress.clamp(0.0, 1.0).toDouble();
  }

  @override
  void didUpdateWidget(covariant GradientProgressCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progress = widget.progress.clamp(0.0, 1.0).toDouble();
    }
  }

  double get _height {
    final scale = widget.size.scale;
    if (widget.size is Wide2Size) return 240 * scale;
    if (widget.size is Large3Size) return 280 * scale;
    return 180 * scale;
  }

  void _updateProgress(double dx, double width, double thumbSize) {
    final travel = math.max(0.0, width - thumbSize);
    if (travel == 0) return;
    final next = ((dx - thumbSize / 2) / travel).clamp(0.0, 1.0).toDouble();
    if (next == _progress) return;
    setState(() => _progress = next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : _height,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(AppThemeData theme) {
    final scale = widget.size.scale;

    return Column(
      children: [
        Row(
          children: [
            // 圆形图标徽章：surfaceAlt 实底 + 墨线描边
            Container(
              width: 44 * scale,
              height: 44 * scale,
              // 大圆角被 rough 引擎自动钳制成圆
              decoration: dsSketchDecoration(
                theme: theme,
                radius: BorderRadius.circular(22 * scale),
                fillColor: theme.surfaceAlt,
              ),
              child: Center(
                child: WiredIcon(
                  icon: widget.icon,
                  size: 24 * scale,
                  color: theme.primary,
                  drawConfig: theme.wired.drawConfig,
                ),
              ),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  color: theme.text,
                  fontSize: widget.size.getSubtitleFontSize() + 2 * scale,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: theme.textSub,
                  fontSize: widget.size.getSubtitleFontSize(),
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(_progress * 100).round()}%',
              key: const Key('gradient-progress-value'),
              style: TextStyle(
                color: theme.text,
                fontSize: widget.size is Wide2Size ? 30 * scale : 26 * scale,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        SizedBox(height: 8 * scale),
        _buildTrack(theme),
      ],
    );
  }

  Widget _buildTrack(AppThemeData theme) {
    final scale = widget.size.scale;
    final trackHeight = 40 * scale;
    final thumbSize = 32 * scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final travel = math.max(0.0, width - thumbSize);
        final thumbLeft = travel * _progress;
        // 数据段宽度跟随指示圆点中心（含拖动中的实时位置）
        final fillWidth = (thumbLeft + thumbSize / 2)
            .clamp(0.0, width)
            .toDouble();

        return GestureDetector(
          key: const Key('gradient-progress-track'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _updateProgress(details.localPosition.dx, width, thumbSize),
          onHorizontalDragDown: (details) =>
              _updateProgress(details.localPosition.dx, width, thumbSize),
          onHorizontalDragUpdate: (details) =>
              _updateProgress(details.localPosition.dx, width, thumbSize),
          child: SizedBox(
            height: trackHeight,
            child: CustomPaint(
              painter: _StripedTrackPainter(
                fillWidth: fillWidth,
                thumbLeft: thumbLeft,
                thumbSize: thumbSize,
                accentColor: widget.accentColor,
                theme: theme,
                scale: scale,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 斜纹进度条绘制器（见 design.md §9.5）
///
/// 轨道胶囊：surfaceAlt 底 + 淡墨斜纹（0.28）+ 淡墨描边（0.45）；
/// 数据段：accent 数据色浅底（0.28）+ 浓斜纹（0.9）+ 描边（0.85）；
/// 指示圆点：纸底实心 + accent 描边平直几何（数据区不上 rough 墨线）。
class _StripedTrackPainter extends CustomPainter {
  final double fillWidth;
  final double thumbLeft;
  final double thumbSize;
  final Color accentColor;
  final AppThemeData theme;
  final double scale;

  const _StripedTrackPainter({
    required this.fillWidth,
    required this.thumbLeft,
    required this.thumbSize,
    required this.accentColor,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final barHeight = 20 * scale;
    final barTop = (size.height - barHeight) / 2;
    final trackRect = Rect.fromLTWH(0, barTop, size.width, barHeight);
    final trackRRect = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(barHeight / 2),
    );

    // 轨道胶囊
    canvas.drawRRect(trackRRect, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(trackRRect),
      trackRect,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      trackRRect,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    // 数据段：accent 数据色斜纹填充
    if (fillWidth > 0.5) {
      final fillRect = Rect.fromLTWH(0, barTop, fillWidth, barHeight);
      final fillRRect = RRect.fromRectAndRadius(
        fillRect,
        Radius.circular(barHeight / 2),
      );
      canvas.drawRRect(
        fillRRect,
        Paint()..color = accentColor.withValues(alpha: 0.28),
      );
      paintDiagonalStripes(
        canvas,
        Path()..addRRect(fillRRect),
        fillRect,
        color: accentColor.withValues(alpha: 0.9),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawRRect(
        fillRRect,
        Paint()
          ..color = accentColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }

    // 指示圆点
    final center = Offset(thumbLeft + thumbSize / 2, size.height / 2);
    final knobRadius = thumbSize / 2 - 2.25 * scale;
    canvas.drawCircle(center, knobRadius, Paint()..color = theme.surface);
    canvas.drawCircle(
      center,
      knobRadius,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _StripedTrackPainter oldDelegate) {
    return oldDelegate.fillWidth != fillWidth ||
        oldDelegate.thumbLeft != thumbLeft ||
        oldDelegate.thumbSize != thumbSize ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.theme != theme ||
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

IconData _parseIcon(dynamic value, IconData fallback) {
  if (value is IconData) return value;
  final codePoint = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (codePoint == null) return fallback;
  return dynamicIconData(codePoint, fontFamily: 'MaterialIcons');
}
