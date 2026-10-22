/// 每周步数进度卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆徽标（主题色底 + 手绘图标）+ 标题/日期范围 / 总步数翻牌计数器 /
/// 斜纹步数柱（选中柱主题色浓斜纹、未选中柱淡墨轨道纹，逐柱错峰生长）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 每日步数数据模型
///
/// 表示单日的步数数据，包含日期简写、完整日期、步数、
/// 百分比变化（可选）和选中状态。
class DailyStepData {
  /// 日期简写（如 "Mon", "Tue"）
  final String day;

  /// 步数
  final int steps;

  /// 完整日期（如 "17 Jun 2024"）
  final String date;

  /// 百分比变化（如 "+2,4%"）
  final String? percentage;

  /// 是否选中
  final bool isSelected;

  const DailyStepData({
    required this.day,
    required this.steps,
    required this.date,
    this.percentage,
    this.isSelected = false,
  });

  /// 从 JSON 创建
  factory DailyStepData.fromJson(Map<String, dynamic> json) {
    return DailyStepData(
      day: json['day'] as String? ?? '',
      steps: json['steps'] as int? ?? 0,
      date: json['date'] as String? ?? '',
      percentage: json['percentage'] as String?,
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'steps': steps,
      'date': date,
      'percentage': percentage,
      'isSelected': isSelected,
    };
  }
}

/// 每周步数进度卡片组件
///
/// 显示一周内的每日步数统计，包含总步数、平均值、
/// 日期范围以及柱状图。
///
/// 特性：
/// - 动画数字计数器（使用 AnimatedFlipCounter）
/// - 柱状图独立延迟动画
/// - 可选某一天查看详情
/// - 根据尺寸自动调整所有元素大小
///
/// 示例用法：
/// ```dart
/// WeeklyStepsProgressCard(
///   title: 'Steps',
///   totalSteps: 16254,
///   dateRange: '17-23 Jun 2024',
///   averageSteps: 6028,
///   dailyData: [
///     DailyStepData(
///       day: 'Mon',
///       steps: 4500,
///       date: '17 Jun 2024',
///     ),
///     DailyStepData(
///       day: 'Fri',
///       steps: 12800,
///       date: '21 Jun 2024',
///       percentage: '+2,4%',
///       isSelected: true,
///     ),
///   ],
///   onDaySelected: (index) {
///     print('选中第 $index 天');
///   },
/// )
/// ```
class WeeklyStepsProgressCard extends StatefulWidget {
  /// 卡片标题（默认为 "Steps"）
  final String title;

  /// 总步数
  final int totalSteps;

  /// 日期范围显示文本
  final String dateRange;

  /// 平均步数
  final int averageSteps;

  /// 每日数据列表
  final List<DailyStepData> dailyData;

  /// 图标（默认为 Icons.directions_walk）
  final IconData? icon;

  /// 小组件尺寸（默认为 MediumSize）
  final HomeWidgetSize size;

  /// 日期选择回调
  final ValueChanged<int>? onDaySelected;

  /// 菜单按钮回调
  final VoidCallback? onMenuPressed;

  const WeeklyStepsProgressCard({
    super.key,
    this.title = 'Steps',
    required this.totalSteps,
    required this.dateRange,
    required this.averageSteps,
    required this.dailyData,
    this.icon,
    this.size = const MediumSize(),
    this.onDaySelected,
    this.onMenuPressed,
  });

  @override
  State<WeeklyStepsProgressCard> createState() =>
      _WeeklyStepsProgressCardState();
}

class _WeeklyStepsProgressCardState extends State<WeeklyStepsProgressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _counterAnimation;

  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _counterAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    // 默认选中最高的步数日期
    if (widget.dailyData.any((d) => d.isSelected)) {
      _selectedIndex = widget.dailyData.indexWhere((d) => d.isSelected);
    } else {
      final maxSteps = widget.dailyData
          .map((d) => d.steps)
          .reduce((a, b) => a > b ? a : b);
      _selectedIndex = widget.dailyData.indexWhere((d) => d.steps == maxSteps);
    }

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectDay(int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.onDaySelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildHeader(theme),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 总步数和时间切换
            _buildTotalSection(theme),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 柱状图区域
            _buildChartSection(theme),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(AppThemeData theme) {
    final size = widget.size;
    final iconSize = size.getIconSize();
    final containerSize = iconSize * size.iconContainerScale;
    final titleFontSize = size.getTitleFontSize();
    final labelFontSize = size.getSubtitleFontSize();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 手绘圆徽标：主题色实底 + 墨线描边 + 手绘图标
              Container(
                width: containerSize,
                height: containerSize,
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(containerSize / 2),
                  fillColor: theme.primary,
                ),
                child: Center(
                  child: WiredIcon(
                    icon: widget.icon ?? Icons.directions_walk,
                    size: iconSize,
                    color: theme.onPrimary,
                    drawConfig: theme.wired.drawConfig,
                  ),
                ),
              ),
              SizedBox(width: size.getSmallSpacing() * 3),
              Flexible(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: theme.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.dateRange,
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w500,
                  color: theme.textSub,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (widget.onMenuPressed != null) ...[
              SizedBox(width: size.getSmallSpacing()),
              IconButton(
                icon: DsIcon(DsIconKind.more, color: theme.textSub),
                onPressed: widget.onMenuPressed,
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 构建总数区域
  ///
  /// 翻牌计数器消费 _counterAnimation.value，
  /// 需 AnimatedBuilder 逐帧 rebuild 驱动。
  Widget _buildTotalSection(AppThemeData theme) {
    final size = widget.size;
    final valueFontSize = size.getLargeFontSize() * 0.75; // 约 27/36/42
    final labelFontSize = size.getSubtitleFontSize();

    return AnimatedBuilder(
      animation: _counterAnimation,
      builder: (context, _) => SizedBox(
        height: valueFontSize,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: valueFontSize * 4,
              height: valueFontSize,
              child: OverflowBox(
                maxWidth: valueFontSize * 4,
                child: Center(
                  child: AnimatedFlipCounter(
                    value:
                        widget.totalSteps.toDouble() * _counterAnimation.value,
                    fractionDigits: 0,
                    textStyle: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'steps',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w500,
                color: theme.textSub,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建柱状图区域
  Widget _buildChartSection(AppThemeData theme) {
    final size = widget.size;
    final maxSteps = widget.dailyData
        .map((d) => d.steps)
        .reduce((a, b) => a > b ? a : b);
    final chartHeight =
        size.getHeightConstraints().maxHeight * 0.5; // 图表高度约为最大高度的一半

    return Expanded(
      child: SizedBox(
        height: chartHeight,
        child: Padding(
          padding: EdgeInsets.only(left: size.getLegendFontSize() * 8),
          child: SizedBox(
            height: chartHeight,
            child: _StepsBars(
              dailyData: widget.dailyData,
              animation: _fadeAnimation,
              selectedIndex: _selectedIndex ?? 0,
              maxSteps: maxSteps,
              averageSteps: widget.averageSteps,
              onTap: _selectDay,
              theme: theme,
              accentColor: theme.primary,
              availableHeight: chartHeight,
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

/// 柱状图组件（私有）
class _StepsBars extends StatelessWidget {
  final List<DailyStepData> dailyData;
  final Animation<double> animation;
  final int selectedIndex;
  final int maxSteps;
  final int averageSteps;
  final Function(int) onTap;
  final AppThemeData theme;
  final Color accentColor;
  final double availableHeight;
  final HomeWidgetSize size;

  const _StepsBars({
    required this.dailyData,
    required this.animation,
    required this.selectedIndex,
    required this.maxSteps,
    required this.averageSteps,
    required this.onTap,
    required this.theme,
    required this.accentColor,
    required this.availableHeight,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final barWidth = size.getBarWidth();
    final legendFontSize = size.getLegendFontSize();
    // 根据是否显示底部文本来计算最大高度
    final showBottomText = size is WideSize || size is Wide2Size;
    // 底部预留空间：间距 + 文本高度
    final bottomSpace = showBottomText ? legendFontSize * 2.5 : 0;
    // 确保柱子最大高度不超过可用空间减去底部空间
    final maxHeight = (availableHeight - bottomSpace).clamp(
      0.0,
      availableHeight,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int index = 0; index < dailyData.length; index++) ...[
          Expanded(
            child: _buildBar(
              dailyData[index],
              index,
              maxHeight,
              barWidth,
              legendFontSize,
              showBottomText,
            ),
          ),
          if (index < dailyData.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }

  Widget _buildBar(
    DailyStepData data,
    int index,
    double maxHeight,
    double barWidth,
    double legendFontSize,
    bool showBottomText,
  ) {
    final barHeight = (data.steps / maxSteps) * maxHeight;
    final isSelected = index == selectedIndex;

    // 错开动画
    final step = 0.08;
    final barAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        index * step,
        0.5 + index * step,
        curve: Curves.easeOutCubic,
      ),
    );

    return GestureDetector(
      onTap: () => onTap(index),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight + (showBottomText ? legendFontSize * 2 : 0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 斜纹步数柱：AnimatedBuilder 逐帧驱动柱高生长
            Flexible(
              child: AnimatedBuilder(
                animation: barAnimation,
                builder: (context, _) {
                  final height = barHeight * barAnimation.value;
                  return SizedBox(
                    width: barWidth,
                    height: height,
                    child: CustomPaint(
                      painter: _StepsBarPainter(
                        selected: isSelected,
                        accentColor: accentColor,
                        theme: theme,
                        scale: size.scale,
                      ),
                    ),
                  );
                },
              ),
            ),
            // 文本始终在下方，固定显示
            if (showBottomText) SizedBox(height: legendFontSize * 0.5),
            if (showBottomText)
              Text(
                data.day,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: legendFontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? theme.text : theme.textSub,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 斜纹步数柱绘制器
///
/// 选中柱：主题色浅底 + 主题色浓斜纹 + 主题色描边；
/// 未选中柱：surfaceAlt 底 + 淡墨斜纹 + 淡墨描边（轨道语言）。
/// 顶部胶囊圆角，与条纹柱状图卡片同款纹样。
class _StepsBarPainter extends CustomPainter {
  final bool selected;
  final Color accentColor;
  final AppThemeData theme;
  final double scale;

  const _StepsBarPainter({
    required this.selected,
    required this.accentColor,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final capsule = Radius.circular(size.width / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: capsule,
      topRight: capsule,
    );
    final background = selected ? accentColor.withValues(alpha: 0.28) : theme.surfaceAlt;
    final stripe = selected
        ? accentColor.withValues(alpha: 0.9)
        : theme.ink.withValues(alpha: 0.28);
    final border = selected
        ? accentColor.withValues(alpha: 0.85)
        : theme.ink.withValues(alpha: 0.45);

    canvas.drawRRect(rrect, Paint()..color = background);
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(rrect),
      rect,
      color: stripe,
      strokeWidth: (selected ? 3 : 1.5) * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _StepsBarPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}
