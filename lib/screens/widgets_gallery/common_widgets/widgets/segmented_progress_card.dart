/// 分段进度条统计小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 + 翻牌计数器 / 斜纹分段进度条（各分段数据色斜纹 + 墨线胶囊框）/
/// 图例列表（手绘色块指示器 + 标签 + 数值，逐项错峰入场）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 分段数据模型
class SegmentData {
  final String label;
  final double value;
  final Color color;

  /// 格式化显示文本（用于显示小时/分钟等格式）
  final String display;

  const SegmentData({
    required this.label,
    required this.value,
    required this.color,
    this.display = '',
  });

  /// 从 JSON 创建
  factory SegmentData.fromJson(Map<String, dynamic> json) {
    return SegmentData(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      color: Color(json['color'] as int? ?? 0xFF000000),
      display: json['display'] as String? ?? '',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
      'color': color.value,
      'display': display,
    };
  }
}

/// 分段进度条统计小组件
class SegmentedProgressCardWidget extends StatefulWidget {
  /// 卡片标题
  final String title;

  /// 当前值
  final double currentValue;

  /// 目标值
  final double targetValue;

  /// 分段数据
  final List<SegmentData> segments;

  /// 数值单位
  final String unit;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const SegmentedProgressCardWidget({
    super.key,
    required this.title,
    required this.currentValue,
    required this.targetValue,
    required this.segments,
    this.unit = '',
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory SegmentedProgressCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final segmentsList =
        (props['segments'] as List<dynamic>?)
            ?.map((e) => SegmentData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return SegmentedProgressCardWidget(
      title: props['title'] as String? ?? '',
      currentValue: (props['currentValue'] as num?)?.toDouble() ?? 0.0,
      targetValue: (props['targetValue'] as num?)?.toDouble() ?? 0.0,
      segments: segmentsList,
      unit: props['unit'] as String? ?? '',
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<SegmentedProgressCardWidget> createState() =>
      _SegmentedProgressCardWidgetState();
}

class _SegmentedProgressCardWidgetState
    extends State<SegmentedProgressCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    // 立即启动动画，确保 AnimatedFlipCounter 能接收到从 0 到目标值的变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 340 * scale,
        height: widget.inline ? double.maxFinite : 340 * scale,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和数值
            _buildHeader(theme),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 分段进度条
            _buildProgressBar(theme),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 分段列表（支持滚动）
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildSegmentList(theme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题和数值部分
  Widget _buildHeader(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            color: theme.textSub,
            fontSize: widget.size.getSubtitleFontSize(),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: widget.size.getSmallSpacing() * 2),
        SizedBox(
          height:
              widget.size.getLargeFontSize() + widget.size.getSmallSpacing(),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedFlipCounter(
                    value: widget.currentValue * _animation.value,
                    fractionDigits: 0,
                    textStyle: TextStyle(
                      color: theme.text,
                      fontSize: widget.size.getLargeFontSize(),
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '/ ${widget.targetValue.toInt()}',
                    style: TextStyle(
                      color: theme.textSub,
                      fontSize: widget.size.getLargeFontSize() * 0.5,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建分段进度条（斜纹分段 + 墨线胶囊框）
  Widget _buildProgressBar(AppThemeData theme) {
    final scale = widget.size.scale;
    return SizedBox(
      height: widget.size.getLegendIndicatorHeight(),
      width: double.infinity,
      child: CustomPaint(
        painter: _StripedSegmentBarPainter(
          segments: widget.segments,
          theme: theme,
          scale: scale,
        ),
      ),
    );
  }

  /// 构建分段列表
  List<Widget> _buildSegmentList(AppThemeData theme) {
    final List<Widget> items = [];

    for (int i = 0; i < widget.segments.length; i++) {
      final segment = widget.segments[i];

      // 为每个列表项创建延迟动画
      // 确保 Interval 的 end 值不超过 1.0
      final end = (0.5 + i * 0.08).clamp(0.0, 1.0);
      final itemAnimation = CurvedAnimation(
        parent: _animationController,
        curve: Interval(i * 0.08, end, curve: Curves.easeOutCubic),
      );

      if (i > 0) {
        items.add(SizedBox(height: widget.size.getItemSpacing() * 2));
      }

      items.add(
        AnimatedBuilder(
          animation: itemAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: itemAnimation.value,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - itemAnimation.value)),
                child: _SegmentItem(
                  segment: segment,
                  theme: theme,
                  animation: itemAnimation,
                  unit: widget.unit,
                  size: widget.size,
                ),
              ),
            );
          },
        ),
      );
    }

    return items;
  }
}

/// 单个分段项
class _SegmentItem extends StatelessWidget {
  final SegmentData segment;
  final AppThemeData theme;
  final Animation<double> animation;
  final String unit;
  final HomeWidgetSize size;

  const _SegmentItem({
    required this.segment,
    required this.theme,
    required this.animation,
    required this.unit,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final indicatorSize = size.getLegendIndicatorWidth();

    return Row(
      children: [
        // 手绘色块指示器：数据色实底 + 墨线描边
        Container(
          width: indicatorSize,
          height: indicatorSize,
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(indicatorSize / 4),
            fillColor: segment.color,
          ),
        ),
        SizedBox(width: size.getItemSpacing()),
        // 标签
        Text(
          segment.label,
          style: TextStyle(
            color: theme.text,
            fontSize: size.getSubtitleFontSize(),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        // 数值 - 优先使用 display 字段
        SizedBox(
          height: size.getSubtitleFontSize(),
          child: Text(
            segment.display.isNotEmpty
                ? segment.display
                : (unit == ''
                    ? '${segment.value.toInt()}'
                    : '$unit${segment.value.toInt()}'),
            style: TextStyle(
              color: theme.text,
              fontSize: size.getSubtitleFontSize(),
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

/// 斜纹分段进度条绘制器
///
/// 胶囊内按占比切分：每段铺数据色浅底 + 数据色斜纹（0.9 透明度，
/// 与半圆仪表盘/条纹柱同款：右上斜率 0.85、6.5 间距），外框淡墨描边。
class _StripedSegmentBarPainter extends CustomPainter {
  final List<SegmentData> segments;
  final AppThemeData theme;
  final double scale;

  const _StripedSegmentBarPainter({
    required this.segments,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || segments.isEmpty) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );

    canvas.save();
    canvas.clipRRect(rrect);
    final total = segments.fold<double>(0, (sum, seg) => sum + seg.value);
    var x = 0.0;
    for (final segment in segments) {
      final w = total > 0 ? size.width * (segment.value / total) : 0.0;
      if (w > 0.5) {
        final rect = Rect.fromLTWH(x, 0, w, size.height);
        canvas.drawRect(
          rect,
          Paint()..color = segment.color.withValues(alpha: 0.28),
        );
        paintDiagonalStripes(
          canvas,
          Path()..addRect(rect),
          rect,
          color: segment.color.withValues(alpha: 0.9),
          strokeWidth: 3 * scale,
          spacing: 6.5 * scale,
        );
      }
      x += w;
    }
    canvas.restore();

    // 墨线胶囊描边
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _StripedSegmentBarPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}
