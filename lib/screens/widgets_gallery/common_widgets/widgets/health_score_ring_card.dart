/// 健康分数环形统计卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 顶部为分段斜纹圆环统计图（每段带数据色手绘图标徽章，中心显示总分数），
/// 底部为对应的统计项目列表（图标徽章 + 斜纹进度条 + 分数，逐项错峰入场）。
library;

import 'dart:math' as math;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

class HealthScoreRingCardWidget extends StatefulWidget {
  /// 中心总分数（如 8.8）
  final double score;

  /// 列表标题（如 'Health systems'），为 null 时不显示
  final String? title;

  /// 列表右上角筛选标签（如 'All'），为 null 时不显示
  final String? filterLabel;

  /// 统计项目列表
  final List<HealthRingItemData> items;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 统计项点击回调（如点击图例筛选对应记录），null 时不可点击
  final void Function(int index)? onItemTap;

  /// 组件尺寸
  final HomeWidgetSize size;

  const HealthScoreRingCardWidget({
    super.key,
    required this.score,
    this.title,
    this.filterLabel,
    required this.items,
    this.inline = false,
    this.onItemTap,
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
    final theme = AppTheme.of(context);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * widget.size.scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        radius: BorderRadius.circular(24 * widget.size.scale),
        padding: widget.size.getPadding(),
        child: _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(AppThemeData theme) {
    // 小尺寸只显示圆环
    if (widget.size is SmallSize) {
      return Center(
        child: _RingChart(
          score: widget.score,
          items: widget.items,
          progress: _animation.value,
          size: widget.size,
          theme: theme,
        ),
      );
    }

    // 其余尺寸：圆环在上（宽型居左上），列表在下
    final isWide = widget.size.width > widget.size.height;
    return Column(
      children: [
        Expanded(
          flex: 55,
          child: Align(
            alignment: isWide ? Alignment.centerLeft : Alignment.center,
            child: _RingChart(
              score: widget.score,
              items: widget.items,
              progress: _animation.value,
              size: widget.size,
              theme: theme,
            ),
          ),
        ),
        Expanded(
          flex: 45,
          child: _buildItemList(theme),
        ),
      ],
    );
  }

  Widget _buildItemList(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title != null || widget.filterLabel != null)
          _buildListHeader(theme),
        SizedBox(height: widget.size.getItemSpacing() * 1.5),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildItems(theme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader(AppThemeData theme) {
    final scale = widget.size.scale;
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.title ?? '',
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
        if (widget.filterLabel != null)
          // 手绘墨线实底筛选胶囊
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 6 * scale,
            ),
            decoration: dsSketchDecoration(
              theme: theme,
              // 大圆角被 rough 引擎自动钳制成胶囊
              radius: BorderRadius.circular(20 * scale),
              fillColor: theme.ink,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.filterLabel!,
                  style: TextStyle(
                    color: theme.surface,
                    fontSize: widget.size.getLegendFontSize(),
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
                SizedBox(width: 4 * scale),
                DsIcon(
                  DsIconKind.chevronDown,
                  size: widget.size.getLegendFontSize() + 2,
                  color: theme.surface,
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _buildItems(AppThemeData theme) {
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
        items.add(SizedBox(height: widget.size.getItemSpacing() * 3.5));
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
          child: _wrapTap(
            _StatItemRow(
              item: item,
              size: widget.size,
              theme: theme,
              animatedScore: item.score * itemAnimation.value,
            ),
            i,
          ),
        ),
      );
    }

    return items;
  }

  /// 统计项点击包装（onItemTap 为 null 时原样返回）
  Widget _wrapTap(Widget child, int index) {
    if (widget.onItemTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onItemTap!.call(index),
      child: child,
    );
  }
}

/// 分段圆环统计图（中心显示总分数，每段带数据色图标徽章）
class _RingChart extends StatelessWidget {
  final double score;
  final List<HealthRingItemData> items;
  final double progress;
  final HomeWidgetSize size;
  final AppThemeData theme;

  const _RingChart({
    required this.score,
    required this.items,
    required this.progress,
    required this.size,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final ringRadius = side / 2;
        final strokeWidth = ringRadius * 0.26;
        final iconCircleRadius = strokeWidth * 0.52;
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
                  theme: theme,
                  scale: size.scale,
                ),
              ),
              // 每段中间的图标徽章（数据色手绘圆底）
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
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(iconCircleRadius),
                      fillColor: segment.item.color,
                    ),
                    child: Center(
                      child: WiredIcon(
                        icon: segment.item.icon,
                        size: iconCircleRadius * 1.1,
                        color: theme.ink,
                        drawConfig: theme.wired.drawConfig,
                      ),
                    ),
                  ),
                ),
              // 中心分数
              Center(
                child: AnimatedFlipCounter(
                  value: score * progress,
                  fractionDigits: 1,
                  textStyle: TextStyle(
                    color: theme.text,
                    fontSize: ringRadius * 0.62,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
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

/// 圆环分段之间的间隙占比（总间隙 = 2π × 该值 × 段数）
const _ringGapFraction = 0.025;

/// 计算每段的起止角度（顶部开始，逆时针，段之间留间隙）
List<_RingSegment> _computeSegments(List<HealthRingItemData> items) {
  if (items.isEmpty) return [];

  final gapAngle = 2 * math.pi * _ringGapFraction;
  final totalValue = items.fold<double>(0, (sum, item) => sum + item.value);
  final available = 2 * math.pi - gapAngle * items.length;

  final segments = <_RingSegment>[];
  // 从顶部开始逆时针排列：角度递减
  var endAngle = -math.pi / 2;

  for (final item in items) {
    final ratio = totalValue > 0 ? item.value / totalValue : 0;
    final sweepAngle = available * ratio;
    final a2 = endAngle - gapAngle / 2;
    final a1 = a2 - sweepAngle;
    segments.add(
      _RingSegment(
        item: item,
        startAngle: a1,
        sweepAngle: sweepAngle,
        midAngle: a1 + sweepAngle / 2,
      ),
    );
    endAngle = a1 - gapAngle / 2;
  }

  return segments;
}

/// 圆环绘制器（平直几何 + 斜纹）
///
/// 每段扇环铺数据色浅底 + 数据色浓斜纹 + 数据色描边，
/// 所有段同步生长（每段扫角 = 满幅 × progress）。
class _RingChartPainter extends CustomPainter {
  final List<_RingSegment> segments;
  final double progress;
  final double strokeWidth;
  final AppThemeData theme;
  final double scale;

  _RingChartPainter({
    required this.segments,
    required this.progress,
    required this.strokeWidth,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rOut = size.width / 2;
    final rIn = rOut - strokeWidth;
    final bounds = Offset.zero & size;

    for (final segment in segments) {
      final sweep = segment.sweepAngle * progress;
      if (sweep <= 0.01) continue;
      final path = _sector(
        center,
        rIn,
        rOut,
        segment.startAngle,
        segment.startAngle + sweep,
      );
      canvas.drawPath(
        path,
        Paint()..color = segment.item.color.withValues(alpha: 0.28),
      );
      paintDiagonalStripes(
        canvas,
        path,
        bounds,
        color: segment.item.color.withValues(alpha: 0.9),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = segment.item.color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }
  }

  /// 平直扇环路径（与 half_gauge_card 的 _sector 同款；支持逆时针小段）
  Path _sector(Offset c, double rIn, double rOut, double a0, double a1) {
    final clockwise = a1 > a0;
    final largeArc = (a1 - a0).abs() > math.pi;
    final path = Path();
    final startRad = clockwise ? a0 : a1;
    final endRad = clockwise ? a1 : a0;
    path.moveTo(
      c.dx + rOut * math.cos(startRad),
      c.dy + rOut * math.sin(startRad),
    );
    path.arcToPoint(
      Offset(c.dx + rOut * math.cos(endRad), c.dy + rOut * math.sin(endRad)),
      radius: Radius.circular(rOut),
      largeArc: largeArc,
      clockwise: clockwise,
    );
    path.lineTo(c.dx + rIn * math.cos(endRad), c.dy + rIn * math.sin(endRad));
    path.arcToPoint(
      Offset(c.dx + rIn * math.cos(startRad), c.dy + rIn * math.sin(startRad)),
      radius: Radius.circular(rIn),
      largeArc: largeArc,
      clockwise: !clockwise,
    );
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _RingChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale ||
        oldDelegate.segments.length != segments.length;
  }
}

/// 统计项目列表行
class _StatItemRow extends StatelessWidget {
  final HealthRingItemData item;
  final HomeWidgetSize size;
  final AppThemeData theme;
  final double animatedScore;

  const _StatItemRow({
    required this.item,
    required this.size,
    required this.theme,
    required this.animatedScore,
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = math.max(4.0, size.getLegendIndicatorHeight() * 0.7);
    final iconSize = size.getThumbnailImageSize();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2 * size.scale),
      child: Row(
        children: [
          // 图标徽章（数据色手绘圆底）
          Container(
            width: iconSize,
            height: iconSize,
            decoration: dsSketchDecoration(
              theme: theme,
              radius: BorderRadius.circular(iconSize / 2),
              fillColor: item.color,
            ),
            child: Center(
              child: WiredIcon(
                icon: item.icon,
                size: iconSize * 0.55,
                color: theme.ink,
                drawConfig: theme.wired.drawConfig,
              ),
            ),
          ),
          SizedBox(width: 12 * size.scale),
          // 名称 + 斜纹进度条
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: size.getSubtitleFontSize(),
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                SizedBox(height: size.getSmallSpacing() + 2),
                SizedBox(
                  // CustomPaint 无 child 时取 constraints.smallest，须显式撑宽
                  width: double.infinity,
                  height: barHeight,
                  child: CustomPaint(
                    painter: _StripedItemBarPainter(
                      fraction:
                          (item.score / item.maxScore).clamp(0.0, 1.0).toDouble(),
                      color: item.color,
                      theme: theme,
                      scale: size.scale,
                    ),
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
                  color: theme.text,
                  fontSize: size.getTitleFontSize() * 0.9,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              Text(
                ' /${item.maxScore.toStringAsFixed(0)}',
                style: TextStyle(
                  color: theme.textSub,
                  fontSize: size.getLegendFontSize(),
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 统计项斜纹进度条绘制器
///
/// 胶囊轨道（surfaceAlt 底 + 淡墨斜纹 + 淡描边）+ 按占比铺
/// 数据色浅底 + 浓斜纹 + 描边的填充段。
class _StripedItemBarPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final AppThemeData theme;
  final double scale;

  const _StripedItemBarPainter({
    required this.fraction,
    required this.color,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );

    // 轨道
    final trackPath = Path()..addRRect(rrect);
    canvas.drawPath(trackPath, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      trackPath,
      Offset.zero & size,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawPath(
      trackPath,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    // 数据填充段
    final f = fraction.clamp(0.0, 1.0);
    if (f > 0.02) {
      final fillRect = Rect.fromLTWH(0, 0, size.width * f, size.height);
      canvas.clipRRect(rrect);
      canvas.drawRect(fillRect, Paint()..color = color.withValues(alpha: 0.28));
      paintDiagonalStripes(
        canvas,
        Path()..addRect(fillRect),
        Offset.zero & size,
        color: color.withValues(alpha: 0.9),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawRect(
        fillRect,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripedItemBarPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.color != color ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
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
