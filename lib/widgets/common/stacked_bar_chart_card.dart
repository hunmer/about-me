/// 堆叠柱状图卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 + 手绘筛选按钮 / 斜纹堆叠柱（各分段数据色浅底 + 数据色浓斜纹 +
/// 数据色描边，自底向上逐柱错峰生长）/ 底部图例（手绘色块指示器）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 图表分类数据
class ChartCategory {
  final String name;
  final Color color;

  const ChartCategory({required this.name, required this.color});

  /// 从 JSON 创建（用于公共小组件系统）
  factory ChartCategory.fromJson(Map<String, dynamic> json) {
    return ChartCategory(
      name: json['name'] as String? ?? '',
      color: Color(json['color'] as int? ?? 0xFF000000),
    );
  }

  /// 转换为 JSON（用于公共小组件系统）
  Map<String, dynamic> toJson() {
    return {'name': name, 'color': color.value};
  }
}

/// 图表分段数值
class ChartSegmentValue {
  final double value;
  final int categoryIndex;

  const ChartSegmentValue({required this.value, required this.categoryIndex});

  /// 从 JSON 创建（用于公共小组件系统）
  factory ChartSegmentValue.fromJson(Map<String, dynamic> json) {
    return ChartSegmentValue(
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      categoryIndex: json['categoryIndex'] as int? ?? 0,
    );
  }

  /// 转换为 JSON（用于公共小组件系统）
  Map<String, dynamic> toJson() {
    return {'value': value, 'categoryIndex': categoryIndex};
  }
}

/// 堆叠柱状图卡片小组件
///
/// 用于展示堆叠柱状图数据的卡片组件，支持动画效果和主题适配。
/// 适用于展示多种分类的堆叠数据，如时间序列数据、对比数据等。
///
/// 使用示例：
/// ```dart
/// StackedBarChartCard(
///   title: 'America',
///   categories: [
///     ChartCategory(name: '2010', color: Color(0xFF0F4C81)),
///     ChartCategory(name: '2011', color: Color(0xFF48C6E0)),
///   ],
///   data: [
///     [ChartSegmentValue(value: 15, categoryIndex: 0)],
///     [ChartSegmentValue(value: 25, categoryIndex: 1)],
///   ],
///   size: const MediumSize(),
///   inline: false,
/// )
/// ```
///
/// 使用 fromProps 从 props 创建：
/// ```dart
/// StackedBarChartCard.fromProps(props, size)
/// ```
class StackedBarChartCard extends StatefulWidget {
  /// 卡片标题
  final String title;

  /// 分类列表
  final List<ChartCategory> categories;

  /// 数据列表（外层为列，内层为分段）
  final List<List<ChartSegmentValue>> data;

  /// 是否显示筛选按钮
  final bool showFilterButton;

  /// 筛选按钮点击回调
  final VoidCallback? onFilterPressed;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const StackedBarChartCard({
    super.key,
    required this.title,
    required this.categories,
    required this.data,
    this.showFilterButton = true,
    this.onFilterPressed,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory StackedBarChartCard.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final categoriesList =
        (props['categories'] as List<dynamic>?)
            ?.map((e) => ChartCategory.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    final dataList =
        (props['data'] as List<dynamic>?)
            ?.map(
              (e) =>
                  (e as List<dynamic>)
                      .map(
                        (seg) => ChartSegmentValue.fromJson(
                          seg as Map<String, dynamic>,
                        ),
                      )
                      .toList(),
            )
            .toList() ??
        const [];

    return StackedBarChartCard(
      title: props['title'] as String? ?? '',
      categories: categoriesList,
      data: dataList,
      showFilterButton: props['showFilterButton'] as bool? ?? true,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<StackedBarChartCard> createState() => _StackedBarChartCardState();
}

class _StackedBarChartCardState extends State<StackedBarChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
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
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    final Widget panel = DsSketchPanel(
      theme: theme,
      width: widget.inline ? double.maxFinite : null,
      height: widget.inline ? double.maxFinite : null,
      radius: BorderRadius.circular(24 * scale),
      padding: widget.size.getPadding(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏 - 固定高度
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: widget.size.getTitleFontSize(),
                    fontWeight: FontWeight.bold,
                    color: theme.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (widget.showFilterButton)
                _FilterButton(
                  onPressed: widget.onFilterPressed,
                  size: widget.size,
                ),
            ],
          ),
          SizedBox(height: widget.size.getTitleSpacing()),

          // 堆叠柱状图 - 使用 Expanded 填充可用高度
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(widget.data.length, (columnIndex) {
                final start = (columnIndex * 0.04).clamp(0.0, 0.5);
                final end = (start + 0.5).clamp(0.0, 1.0);
                final columnAnimation = CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    start,
                    end,
                    curve: Curves.easeOutCubic,
                  ),
                );
                return Expanded(
                  child: _StackedBarColumn(
                    segments: widget.data[columnIndex],
                    categories: widget.categories,
                    animation: columnAnimation,
                    size: widget.size,
                  ),
                );
              }),
            ),
          ),

          // 分类图例 - 固定在卡片底部
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(widget.categories.length, (index) {
                final category = widget.categories[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right:
                        index < widget.categories.length - 1
                            ? widget.size.getItemSpacing()
                            : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 手绘图例色块：数据色实底 + 墨线描边
                      Container(
                        width: widget.size.getLegendIndicatorWidth(),
                        height: widget.size.getLegendIndicatorHeight(),
                        decoration: dsSketchDecoration(
                          theme: theme,
                          radius: BorderRadius.circular(
                            widget.size.getLegendIndicatorHeight() / 2,
                          ),
                          fillColor: category.color,
                        ),
                      ),
                      SizedBox(width: widget.size.getSmallSpacing()),
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: widget.size.getSubtitleFontSize(),
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );

    return WiredDraw(
      child: widget.inline
          ? panel
          : ConstrainedBox(
              constraints: widget.size.getHeightConstraints(),
              child: panel,
            ),
    );
  }
}

/// 堆叠柱子组件：整柱一个 CustomPaint 绘制斜纹堆叠段
/// （SizedBox.expand 给紧约束，防止无 child 的 CustomPaint 塌缩）
class _StackedBarColumn extends StatelessWidget {
  final List<ChartSegmentValue> segments;
  final List<ChartCategory> categories;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _StackedBarColumn({
    required this.segments,
    required this.categories,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => SizedBox.expand(
        child: CustomPaint(
          painter: _StackedBarColumnPainter(
            segments: segments,
            categories: categories,
            progress: animation.value,
            horizontalMargin: size.getBarSpacing(),
            gap: size.getSmallSpacing(),
            scale: size.scale,
          ),
        ),
      ),
    );
  }
}

/// 斜纹堆叠柱绘制器
///
/// 各分段铺数据色浅底（0.28）+ 数据色斜纹（0.9）+ 数据色描边（0.85），
/// 首段顶/尾段底胶囊圆角，整柱按 [progress]（逐柱错峰）自底向上生长。
class _StackedBarColumnPainter extends CustomPainter {
  final List<ChartSegmentValue> segments;
  final List<ChartCategory> categories;
  final double progress;
  final double horizontalMargin;
  final double gap;
  final double scale;

  const _StackedBarColumnPainter({
    required this.segments,
    required this.categories,
    required this.progress,
    required this.horizontalMargin,
    required this.gap,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0 || segments.isEmpty) return;
    final visible = segments.where((s) => s.value > 0).toList();
    if (visible.isEmpty || categories.isEmpty) return;
    final total = visible.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final barWidth = math.max(0.0, size.width - horizontalMargin * 2);
    if (barWidth <= 0) return;
    final gapTotal = gap * (visible.length - 1);
    final availableHeight = math.max(0.0, size.height - gapTotal);
    final capsule = Radius.circular(barWidth / 2);

    var y = size.height;
    for (var i = visible.length - 1; i >= 0; i--) {
      final segment = visible[i];
      final height = availableHeight * (segment.value / total) * progress;
      y -= height;
      if (height > 0.5) {
        final rect = Rect.fromLTWH(horizontalMargin, y, barWidth, height);
        final rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: i == 0 ? capsule : Radius.zero,
          topRight: i == 0 ? capsule : Radius.zero,
          bottomLeft: i == visible.length - 1 ? capsule : Radius.zero,
          bottomRight: i == visible.length - 1 ? capsule : Radius.zero,
        );
        final color = categories[segment.categoryIndex].color;
        canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.28));
        paintDiagonalStripes(
          canvas,
          Path()..addRRect(rrect),
          rect,
          color: color.withValues(alpha: 0.9),
          strokeWidth: 3 * scale,
          spacing: 6.5 * scale,
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = color.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * scale,
        );
      }
      y -= gap;
    }
  }

  @override
  bool shouldRepaint(covariant _StackedBarColumnPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.categories != categories ||
        oldDelegate.progress != progress ||
        oldDelegate.horizontalMargin != horizontalMargin ||
        oldDelegate.gap != gap ||
        oldDelegate.scale != scale;
  }
}

/// 筛选按钮组件（手绘图标）
class _FilterButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final HomeWidgetSize size;

  const _FilterButton({this.onPressed, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.all(size.getSmallSpacing()),
        child: DsIcon(
          DsIconKind.tune,
          size: size.getIconSize(),
          color: theme.textSub,
        ),
      ),
    );
  }
}
