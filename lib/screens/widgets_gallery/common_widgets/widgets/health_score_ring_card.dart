import 'dart:math' as math;
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 健康分数环形统计卡片
///
/// 顶部为分段圆环统计图（每段带图标，中心显示总分数），
/// 底部为对应的统计项目列表（图标 + 进度条 + 分数）。
class HealthScoreRingCardWidget extends StatefulWidget {
  /// 中心总分数（如 8.8）
  final double score;

  /// 中心分数下方的标签（如 'your health score'）
  final String scoreLabel;

  /// 列表标题（如 'Health systems'），为 null 时不显示
  final String? title;

  /// 列表右上角筛选标签（如 'All'），为 null 时不显示
  final String? filterLabel;

  /// 统计项目列表
  final List<HealthRingItemData> items;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const HealthScoreRingCardWidget({
    super.key,
    required this.score,
    this.scoreLabel = 'your health score',
    this.title,
    this.filterLabel,
    required this.items,
    this.inline = false,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例
  factory HealthScoreRingCardWidget.fromProps(
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

    // 解析统计项目
    List<HealthRingItemData> parseItems(dynamic itemsData) {
      if (itemsData == null) return [];
      if (itemsData is List) {
        return itemsData.map((item) {
          if (item is Map<String, dynamic>) {
            final iconValue = item['icon'];
            return HealthRingItemData(
              label: item['label'] as String? ?? '',
              icon:
                  iconValue is IconData
                      ? iconValue
                      : dynamicIconData(
                          (iconValue as num?)?.toInt() ?? Icons.circle.codePoint,
                          fontFamily: 'MaterialIcons',
                        ),
              color: parseColor(item['color']),
              score: (item['score'] as num?)?.toDouble() ?? 0.0,
              maxScore: (item['maxScore'] as num?)?.toDouble() ?? 10.0,
              value: (item['value'] as num?)?.toDouble() ?? 0.0,
            );
          }
          return HealthRingItemData(
            label: '',
            icon: Icons.circle,
            color: Colors.blue,
            score: 0,
            value: 0,
          );
        }).toList();
      }
      return [];
    }

    return HealthScoreRingCardWidget(
      score: (props['score'] as num?)?.toDouble() ?? 0.0,
      scoreLabel: props['scoreLabel'] as String? ?? 'your health score',
      title: props['title'] as String?,
      filterLabel: props['filterLabel'] as String?,
      items: parseItems(props['items']),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<HealthScoreRingCardWidget> createState() =>
      _HealthScoreRingCardWidgetState();
}

class _HealthScoreRingCardWidgetState extends State<HealthScoreRingCardWidget>
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
    if (widget.size is SmallSize ||
        widget.size is MediumSize ||
        widget.size is WideSize) {
      return 170 * scale;
    }
    if (widget.size is LargeSize || widget.size is Wide2Size) {
      return 330 * scale;
    }
    return 430 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.inline ? double.maxFinite : 384 * widget.size.scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF7F3EB),
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
          child: _buildContent(isDark),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    // 小尺寸只显示圆环
    if (widget.size is SmallSize) {
      return Center(
        child: _RingChart(
          score: widget.score,
          scoreLabel: widget.scoreLabel,
          items: widget.items,
          progress: _animation.value,
          size: widget.size,
          isDark: isDark,
        ),
      );
    }

    // 宽型尺寸：圆环在左，列表在右
    if (widget.size.width > widget.size.height) {
      return Row(
        children: [
          _RingChart(
            score: widget.score,
            scoreLabel: widget.size is MediumSize ? null : widget.scoreLabel,
            items: widget.items,
            progress: _animation.value,
            size: widget.size,
            isDark: isDark,
          ),
          SizedBox(width: widget.size.getTitleSpacing() * 0.6),
          Expanded(
            child: _buildItemList(isDark),
          ),
        ],
      );
    }

    // 高型尺寸：圆环在上，列表在下
    return Column(
      children: [
        Expanded(
          flex: 55,
          child: Center(
            child: _RingChart(
              score: widget.score,
              scoreLabel: widget.scoreLabel,
              items: widget.items,
              progress: _animation.value,
              size: widget.size,
              isDark: isDark,
            ),
          ),
        ),
        Expanded(
          flex: 45,
          child: _buildItemList(isDark),
        ),
      ],
    );
  }

  Widget _buildItemList(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title != null || widget.filterLabel != null)
          _buildListHeader(isDark),
        SizedBox(height: widget.size.getItemSpacing() * 1.5),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildItems(isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.title ?? '',
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
        if (widget.filterLabel != null)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * widget.size.scale,
              vertical: 6 * widget.size.scale,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : const Color(0xFF211D15),
              borderRadius: BorderRadius.circular(20 * widget.size.scale),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.filterLabel!,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF211D15) : Colors.white,
                    fontSize: widget.size.getLegendFontSize(),
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: 4 * widget.size.scale),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: isDark ? const Color(0xFF211D15) : Colors.white,
                  size: widget.size.getLegendFontSize() + 2,
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _buildItems(bool isDark) {
    final items = <Widget>[];
    final step = 0.6 / math.max(widget.items.length, 1);

    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final itemAnimation = CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          0.3 + i * step,
          math.min(0.9 + i * step, 1.0),
          curve: Curves.easeOutCubic,
        ),
      );

      if (i > 0) {
        items.add(SizedBox(height: widget.size.getItemSpacing() * 2.5));
      }

      items.add(
        AnimatedBuilder(
          animation: itemAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: itemAnimation.value,
              child: Transform.translate(
                offset: Offset(
                  10 * widget.size.scale * (1 - itemAnimation.value),
                  0,
                ),
                child: child,
              ),
            );
          },
          child: _StatItemRow(
            item: item,
            size: widget.size,
            isDark: isDark,
            animatedScore: item.score * itemAnimation.value,
          ),
        ),
      );
    }

    return items;
  }
}

/// 分段圆环统计图（中心显示总分数，每段带图标）
class _RingChart extends StatelessWidget {
  final double score;
  final String? scoreLabel;
  final List<HealthRingItemData> items;
  final double progress;
  final HomeWidgetSize size;
  final bool isDark;

  const _RingChart({
    required this.score,
    this.scoreLabel,
    required this.items,
    required this.progress,
    required this.size,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final ringRadius = side / 2;
        final strokeWidth = ringRadius * 0.26;
        final iconCircleRadius = strokeWidth * 0.62;
        final segments = _computeSegments(items);

        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(side, side),
                painter: _RingChartPainter(
                  segments: segments,
                  progress: progress,
                  strokeWidth: strokeWidth,
                ),
              ),
              // 每段中间的图标圆
              for (final segment in segments)
                Positioned(
                  left:
                      ringRadius +
                      (ringRadius - strokeWidth / 2) *
                          math.cos(segment.midAngle) -
                      iconCircleRadius,
                  top:
                      ringRadius +
                      (ringRadius - strokeWidth / 2) *
                          math.sin(segment.midAngle) -
                      iconCircleRadius,
                  child: Container(
                    width: iconCircleRadius * 2,
                    height: iconCircleRadius * 2,
                    decoration: BoxDecoration(
                      color: segment.item.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      segment.item.icon,
                      size: iconCircleRadius * 1.1,
                      color: isDark ? Colors.white : const Color(0xFF2B271E),
                    ),
                  ),
                ),
              // 中心分数
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedFlipCounter(
                      value: score * progress,
                      fractionDigits: 1,
                      textStyle: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF211D15),
                        fontSize: ringRadius * 0.62,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    if (scoreLabel != null) ...[
                      SizedBox(height: size.getSmallSpacing()),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              scoreLabel!,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF8A8474),
                                fontSize: ringRadius * 0.2,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(width: 2 * size.scale),
                          Icon(
                            Icons.info_outline,
                            size: ringRadius * 0.18,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF8A8474),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 圆环分段几何信息
class _RingSegment {
  final HealthRingItemData item;
  final double startAngle;
  final double sweepAngle;
  final double midAngle;

  const _RingSegment({
    required this.item,
    required this.startAngle,
    required this.sweepAngle,
    required this.midAngle,
  });
}

/// 计算每段的起止角度（顶部开始，顺时针，段之间留间隙）
List<_RingSegment> _computeSegments(List<HealthRingItemData> items) {
  if (items.isEmpty) return [];

  const gapFraction = 0.028;
  final gapAngle = 2 * math.pi * gapFraction;
  final totalValue = items.fold<double>(0, (sum, item) => sum + item.value);
  final available = 2 * math.pi - gapAngle * items.length;

  final segments = <_RingSegment>[];
  var startAngle = -math.pi / 2;

  for (final item in items) {
    final ratio = totalValue > 0 ? item.value / totalValue : 0;
    final sweepAngle = available * ratio;
    startAngle += gapAngle / 2;
    segments.add(
      _RingSegment(
        item: item,
        startAngle: startAngle,
        sweepAngle: sweepAngle,
        midAngle: startAngle + sweepAngle / 2,
      ),
    );
    startAngle += sweepAngle + gapAngle / 2;
  }

  return segments;
}

/// 圆环绘制器
class _RingChartPainter extends CustomPainter {
  final List<_RingSegment> segments;
  final double progress;
  final double strokeWidth;

  _RingChartPainter({
    required this.segments,
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    var drawnAngle = 0.0;
    final totalAngle = 2 * math.pi - 2 * math.pi * 0.028 * segments.length;

    for (final segment in segments) {
      final remaining = totalAngle * progress - drawnAngle;
      if (remaining <= 0) break;

      final paint =
          Paint()
            ..color = segment.item.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round;

      final sweep = math.min(segment.sweepAngle, remaining);
      if (sweep > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          segment.startAngle,
          sweep,
          false,
          paint,
        );
      }
      drawnAngle += segment.sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _RingChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.segments.length != segments.length;
  }
}

/// 统计项目列表行
class _StatItemRow extends StatelessWidget {
  final HealthRingItemData item;
  final HomeWidgetSize size;
  final bool isDark;
  final double animatedScore;

  const _StatItemRow({
    required this.item,
    required this.size,
    required this.isDark,
    required this.animatedScore,
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = math.max(4.0, size.getLegendIndicatorHeight() * 0.7);
    final iconSize = size.getThumbnailImageSize();

    return Row(
      children: [
        // 图标圆
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: item.color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            item.icon,
            size: iconSize * 0.55,
            color: isDark ? Colors.white : const Color(0xFF2B271E),
          ),
        ),
        SizedBox(width: 12 * size.scale),
        // 名称 + 进度条
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF211D15),
                  fontSize: size.getSubtitleFontSize(),
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              SizedBox(height: size.getSmallSpacing() + 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(barHeight),
                child: Stack(
                  children: [
                    Container(
                      height: barHeight,
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFEAE3D5),
                    ),
                    FractionallySizedBox(
                      widthFactor:
                          (item.score / item.maxScore).clamp(0.0, 1.0).toDouble(),
                      child: Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(barHeight),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12 * size.scale),
        // 分数
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedFlipCounter(
              value: animatedScore,
              fractionDigits: 1,
              textStyle: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF211D15),
                fontSize: size.getTitleFontSize() * 0.9,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            Text(
              ' /${item.maxScore.toStringAsFixed(0)}',
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF8A8474),
                fontSize: size.getLegendFontSize(),
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 健康环统计项目数据模型
class HealthRingItemData {
  /// 项目名称
  final String label;

  /// 图标
  final IconData icon;

  /// 颜色（圆环分段 + 列表进度条共用）
  final Color color;

  /// 分数（如 8.3）
  final double score;

  /// 满分（如 10）
  final double maxScore;

  /// 圆环占比（所有项目自动归一化）
  final double value;

  const HealthRingItemData({
    required this.label,
    required this.icon,
    required this.color,
    required this.score,
    this.maxScore = 10.0,
    required this.value,
  });
}
