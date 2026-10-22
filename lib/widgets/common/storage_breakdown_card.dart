import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 分段分类数据模型
///
/// 用于表示分段统计卡片中的每个分类项，支持名称、数值和颜色配置。
/// 适用于存储分段、预算分类、时间分段等多种分段统计场景。
class SegmentedCategory {
  /// 分类名称
  final String name;

  /// 分类数值（如存储空间GB、预算金额等）
  final double value;

  /// 分类显示颜色（可选，未指定时使用默认颜色）
  final Color? color;

  const SegmentedCategory({
    required this.name,
    required this.value,
    this.color,
  });

  /// 从 JSON 创建实例
  factory SegmentedCategory.fromJson(Map<String, dynamic> json) {
    return SegmentedCategory(
      name: json['name'] as String,
      value: (json['value'] as num).toDouble(),
      color: json['color'] != null
          ? Color(int.parse(json['color'] as String))
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'color': color?.value.toRadixString(16),
    };
  }

  /// 复制并修改部分属性
  SegmentedCategory copyWith({
    String? name,
    double? value,
    Color? color,
  }) {
    return SegmentedCategory(
      name: name ?? this.name,
      value: value ?? this.value,
      color: color ?? this.color,
    );
  }
}

/// 分段统计卡片小组件
///
/// 手绘纸墨风（纸底 + 淡排线 + rough 墨线框，WiredDraw 墨线描画入场）：
/// 分段占比条按 design.md §9.5 斜纹填充（数据色浅底 + 浓斜纹 + 描边，
/// 未指定数据色的段走淡墨轨道档）；图例色块为墨线描边实底小圆；
/// 翻牌计数与逐项错峰动画保留。
/// 适用于展示设备存储、云存储、预算分类、时间分段等多种分段统计场景。
///
/// 使用示例：
/// ```dart
/// StorageBreakdownCard(
///   title: 'Device Storage',
///   used: 345,
///   total: 512,
///   categories: [
///     SegmentedCategory(
///       name: 'Application',
///       value: 96,
///       color: Color(0xFFFF3B30),
///     ),
///     SegmentedCategory(
///       name: 'Photos',
///       value: 62,
///       color: Color(0xFF34C759),
///     ),
///     SegmentedCategory(
///       name: 'iCloud Drive',
///       value: 41,
///       color: Color(0xFFFF9500),
///     ),
///     SegmentedCategory(name: 'System Data', value: 146, color: null),
///   ],
/// )
/// ```
class StorageBreakdownCard extends StatefulWidget {
  /// 卡片标题
  final String title;

  /// 已使用存储空间（GB）
  final double used;

  /// 总存储空间（GB）
  final double total;

  /// 分类列表
  final List<SegmentedCategory> categories;

  /// 小组件尺寸
  final HomeWidgetSize size;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  const StorageBreakdownCard({
    super.key,
    required this.title,
    required this.used,
    required this.total,
    required this.categories,
    this.size = const MediumSize(),
    this.inline = false,
  });

  /// 从 props 创建实例
  factory StorageBreakdownCard.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final categories = (props['categories'] as List<dynamic>?)
            ?.map((e) => SegmentedCategory.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <SegmentedCategory>[];
    return StorageBreakdownCard(
      title: props['title'] as String? ?? '',
      used: (props['used'] as num?)?.toDouble() ?? 0,
      total: (props['total'] as num?)?.toDouble() ?? 1,
      categories: categories,
      size: size,
    );
  }

  @override
  State<StorageBreakdownCard> createState() => _StorageBreakdownCardState();
}

class _StorageBreakdownCardState extends State<StorageBreakdownCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  double get usagePercentage => widget.used / widget.total;

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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final padding = widget.size.getPadding();
    final titleSpacing = widget.size.getTitleSpacing();
    final itemSpacing = widget.size.getItemSpacing();

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 墨线描画入场
    return ConstrainedBox(
      constraints: widget.size.getHeightConstraints(),
      child: WiredDraw(
        child: DsSketchPanel(
          theme: theme,
          width:
              widget.inline ? double.maxFinite : widget.size.getWidthForChart(),
          radius: BorderRadius.circular(24 * widget.size.scale),
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题和容量显示
              _HeaderSection(
                title: widget.title,
                used: widget.used,
                total: widget.total,
                animation: _animation,
                size: widget.size,
              ),
              SizedBox(height: titleSpacing),

              // 分段进度条
              _StorageBar(
                categories: widget.categories,
                total: widget.total,
                animation: _animation,
                size: widget.size,
              ),
              SizedBox(height: itemSpacing),

              // 图例
              Expanded(
                child: _LegendSection(
                  categories: widget.categories,
                  animation: _animation,
                  size: widget.size,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 头部信息区域（翻牌计数 + 错峰入场动画保留）
class _HeaderSection extends StatelessWidget {
  final String title;
  final double used;
  final double total;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _HeaderSection({
    required this.title,
    required this.used,
    required this.total,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.5, curve: Curves.easeOutCubic),
    );

    // 根据 size 计算字体大小
    final titleFontSize = size.getSubtitleFontSize();
    final valueFontSize = size.getLargeFontSize() * 0.35; // 约 13-20px
    final unitFontSize = size.getSubtitleFontSize() * 0.85;
    final smallSpacing = size.getSmallSpacing();

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: itemAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - itemAnimation.value)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w500,
                    color: theme.textSub,
                  ),
                ),
                SizedBox(height: smallSpacing),
                Row(
                  children: [
                    AnimatedFlipCounter(
                      value: used * itemAnimation.value,
                      fractionDigits: 0,
                      textStyle: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                        letterSpacing: -1,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    SizedBox(width: smallSpacing),
                    Padding(
                      padding: EdgeInsets.only(top: smallSpacing),
                      child: Text(
                        'GB',
                        style: TextStyle(
                          fontSize: unitFontSize,
                          fontWeight: FontWeight.w500,
                          color: theme.textSub,
                        ),
                      ),
                    ),
                    SizedBox(width: smallSpacing),
                    Padding(
                      padding: EdgeInsets.only(left: smallSpacing, top: smallSpacing),
                      child: Text(
                        '/ $total GB',
                        style: TextStyle(
                          fontSize: unitFontSize,
                          fontWeight: FontWeight.w500,
                          color: theme.textSub.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 分段占比条（design.md §9.5：斜纹数据填充 + 逐段生长动画）
class _StorageBar extends StatelessWidget {
  final List<SegmentedCategory> categories;
  final double total;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _StorageBar({
    required this.categories,
    required this.total,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    );

    // 根据 size 计算高度
    final barHeight = size.getLegendIndicatorHeight() * 3;
    final gap = size.getBarSpacing();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: itemAnimation.value,
          child: SizedBox(
            // CustomPaint 无 child 时取 constraints.smallest，须显式撑宽
            width: double.infinity,
            height: barHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;

                // 计算每段的累积位置与逐段生长宽度
                double currentLeft = 0;
                final segments = <_BarSegment>[];

                for (int index = 0; index < categories.length; index++) {
                  final category = categories[index];
                  final width = (category.value / total) * barWidth;

                  // 计算每个段的延迟动画
                  const step = 0.08;
                  final start = (index * step).clamp(0.0, 0.5);
                  final end = (0.4 + index * step).clamp(0.0, 1.0);
                  final segmentAnimation = CurvedAnimation(
                    parent: animation,
                    curve: Interval(start, end, curve: Curves.easeOutCubic),
                  );

                  final animatedWidth =
                      (width - (index < categories.length - 1 ? gap : 0)) *
                          segmentAnimation.value;

                  segments.add(
                    _BarSegment(
                      color: category.color,
                      left: currentLeft,
                      width: animatedWidth,
                    ),
                  );

                  currentLeft += width;
                }

                return CustomPaint(
                  size: Size(barWidth, barHeight),
                  painter: _StorageBarPainter(
                    segments: segments,
                    theme: theme,
                    scale: size.scale,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// 单个分段（left/width 为生长动画插值后的绘制值）
class _BarSegment {
  final Color? color;
  final double left;
  final double width;

  const _BarSegment({required this.color, required this.left, required this.width});
}

/// 分段占比条绘制器：平直胶囊几何 + 斜纹填充（design.md §9.5）
///
/// 有数据色的段：数据色浅底（0.28）+ 数据色浓斜纹（0.9）+ 数据色描边（0.85）；
/// 未指定数据色的段走轨道档：surfaceAlt 底 + 淡墨斜纹（0.28）+ 淡墨描边（0.45）。
class _StorageBarPainter extends CustomPainter {
  final List<_BarSegment> segments;
  final AppThemeData theme;
  final double scale;

  const _StorageBarPainter({
    required this.segments,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = Radius.circular(size.height / 2);

    for (final segment in segments) {
      if (segment.width <= 0.5) continue;
      final rect = Rect.fromLTWH(segment.left, 0, segment.width, size.height);
      final rrect = RRect.fromRectAndRadius(rect, radius);
      final path = Path()..addRRect(rrect);

      if (segment.color != null) {
        // 数据段：数据色浅底 + 浓斜纹 + 描边
        canvas.drawRRect(
          rrect,
          Paint()..color = segment.color!.withValues(alpha: 0.28),
        );
        paintDiagonalStripes(
          canvas,
          path,
          rect,
          color: segment.color!.withValues(alpha: 0.9),
          strokeWidth: 3 * scale,
          spacing: 6.5 * scale,
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = segment.color!.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * scale,
        );
      } else {
        // 未指定数据色的段走轨道档：surfaceAlt 底 + 淡墨斜纹 + 淡墨描边
        canvas.drawRRect(rrect, Paint()..color = theme.surfaceAlt);
        paintDiagonalStripes(
          canvas,
          path,
          rect,
          color: theme.ink.withValues(alpha: 0.28),
          strokeWidth: 1.5 * scale,
          spacing: 6.5 * scale,
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = theme.ink.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * scale,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StorageBarPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}

/// 图例区域（逐项错峰入场动画保留）
class _LegendSection extends StatelessWidget {
  final List<SegmentedCategory> categories;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _LegendSection({
    required this.categories,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    );

    // 根据 size 计算间距
    final mainAxisSpacing = size.getSmallSpacing();
    final crossAxisSpacing = size.getSmallSpacing() * 0.5;

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: itemAnimation.value,
          child: GridView.count(
            crossAxisCount: 2,
            physics: const ClampingScrollPhysics(),
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: size is SmallSize ? 4.0 : 4.5,
            children: List.generate(categories.length, (index) {
              final category = categories[index];
              const step = 0.1;
              final start = (index * step).clamp(0.0, 0.4);
              final end = (0.6 + index * step).clamp(0.0, 1.0);
              final legendAnimation = CurvedAnimation(
                parent: animation,
                curve: Interval(start, end, curve: Curves.easeOutCubic),
              );

              return _LegendItem(
                name: category.name,
                color: category.color ?? theme.surfaceAlt,
                animation: legendAnimation,
                size: size,
              );
            }),
          ),
        );
      },
    );
  }
}

/// 单个图例项
///
/// 色块为 dsSketchDecoration 实底小圆 + 墨线描边（禁彩色柔影）。
class _LegendItem extends StatelessWidget {
  final String name;
  final Color color;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _LegendItem({
    required this.name,
    required this.color,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 根据 size 计算尺寸
    final indicatorSize = size.getLegendIndicatorWidth() * 0.75;
    final indicatorHeight = size.getLegendIndicatorHeight() * 0.75;
    final fontSize = size.getLegendFontSize();
    final spacing = size.getSmallSpacing() * 0.75;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - animation.value)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Container(
                  width: indicatorSize,
                  height: indicatorHeight,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    circle: true,
                    fillColor: color,
                  ),
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: theme.textSub,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
