/// 水平监测卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆形图标徽章 + 标题 + Today 入口 / 当前分数 + 状态描述 /
/// 每周斜纹柱（主题色浓斜纹，逐柱错峰生长）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 每周水平数据模型
///
/// 用于表示某一天的水平值（如压力、情绪等）
class WeeklyLevelData {
  /// 星期几标签（如 'Mon', 'Tue' 等）
  final String day;

  /// 水平值 (0.0 - 1.0)
  final double value;

  /// 是否被选中
  final bool isSelected;

  const WeeklyLevelData({
    required this.day,
    required this.value,
    required this.isSelected,
  });

  /// 从 JSON 创建
  factory WeeklyLevelData.fromJson(Map<String, dynamic> json) {
    return WeeklyLevelData(
      day: json['day'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'day': day, 'value': value, 'isSelected': isSelected};
  }

  /// 创建副本
  WeeklyLevelData copyWith({String? day, double? value, bool? isSelected}) {
    return WeeklyLevelData(
      day: day ?? this.day,
      value: value ?? this.value,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// 水平监测卡片组件
///
/// 用于展示水平值（如压力、情绪等）的监测卡片，支持动画效果和主题适配。
/// 显示当前分数、状态描述和一周水平值的柱状图。
///
/// 使用示例：
/// ```dart
/// LevelMonitorCard(
///   title: 'Stress Level',
///   icon: Icons.error_outline,
///   currentScore: 4.2,
///   status: 'Stressed Out',
///   weeklyData: [
///     WeeklyLevelData(day: 'Mon', value: 0.45, isSelected: false),
///     WeeklyLevelData(day: 'Tue', value: 0.25, isSelected: false),
///     // ... 更多数据
///   ],
///   onTodayTap: () => print('Today tapped'),
///   onBarTap: (index, data) => print('Bar $index tapped'),
/// )
/// ```
class LevelMonitorCard extends StatefulWidget {
  /// 标题
  final String title;

  /// 图标
  final IconData icon;

  /// 当前分数
  final double currentScore;

  /// 状态描述
  final String status;

  /// 分数单位（如 'pts'）
  final String scoreUnit;

  /// 一周数据
  final List<WeeklyLevelData> weeklyData;

  /// "Today" 按钮点击回调
  final VoidCallback? onTodayTap;

  /// 柱状图点击回调
  final void Function(int index, WeeklyLevelData data)? onBarTap;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const LevelMonitorCard({
    super.key,
    required this.title,
    required this.icon,
    required this.currentScore,
    required this.status,
    required this.weeklyData,
    this.scoreUnit = 'pts',
    this.onTodayTap,
    this.onBarTap,
    this.inline = false,
    this.size = const MediumSize(),
  });

  @override
  State<LevelMonitorCard> createState() => _LevelMonitorCardState();
}

class _LevelMonitorCardState extends State<LevelMonitorCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scoreAnimation;
  late List<Animation<double>> _barAnimations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scoreAnimation = Tween<double>(
      begin: 0.0,
      end: widget.currentScore,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // 为每个进度条创建动画
    _barAnimations = List.generate(
      widget.weeklyData.length,
      (index) => Tween<double>(
        begin: 0.0,
        end: widget.weeklyData[index].value,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            0.2 + (index * 0.1),
            0.8 + (index * 0.03),
            curve: Curves.easeOut,
          ),
        ),
      ),
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
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 380,
        height: widget.inline ? double.maxFinite : 380,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildHeader(theme),
            SizedBox(height: widget.size.getTitleSpacing()),

            // 分数和进度条在同一行
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 当前分数和状态
                Flexible(
                  flex: 6,
                  child: _buildScoreSection(theme),
                ),
                const SizedBox(width: 8),
                // 每周进度条靠右
                Flexible(flex: 7, child: _buildWeeklyBars(theme)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeData theme) {
    final iconSize = widget.size.getIconSize();
    final containerSize = iconSize * widget.size.iconContainerScale;

    return Row(
      children: [
        // 左侧图标和标题区域
        Expanded(
          child: Row(
            children: [
              // 手绘圆形图标徽章
              Container(
                width: containerSize,
                height: containerSize,
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(containerSize / 2),
                  fillColor: theme.surfaceAlt,
                ),
                child: Center(
                  child: WiredIcon(
                    icon: widget.icon,
                    size: iconSize,
                    color: theme.primary,
                    drawConfig: theme.wired.drawConfig,
                  ),
                ),
              ),
              SizedBox(width: widget.size.getItemSpacing()),
              Flexible(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: widget.size.getTitleFontSize(),
                    fontWeight: FontWeight.w600,
                    color: theme.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Today 按钮
        InkWell(
          onTap: widget.onTodayTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.size.getItemSpacing(),
              vertical: widget.size.getItemSpacing() / 2,
            ),
            child: Row(
              children: [
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: widget.size.getLegendFontSize(),
                    fontWeight: FontWeight.w400,
                    color: theme.textSub,
                  ),
                ),
                SizedBox(width: widget.size.getItemSpacing()),
                DsIcon(
                  DsIconKind.chevronRight,
                  size: iconSize * 0.8,
                  color: theme.textSub,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreSection(AppThemeData theme) {
    final scoreFontSize = widget.size.getLargeFontSize() * 0.7;
    final unitFontSize = widget.size.getLargeFontSize() * 0.35;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedBuilder(
              animation: _scoreAnimation,
              builder: (context, child) {
                return AnimatedFlipCounter(
                  value: _scoreAnimation.value,
                  fractionDigits: 1,
                  textStyle: TextStyle(
                    fontSize: scoreFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.text,
                  ),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.only(bottom: widget.size.getItemSpacing()),
              child: Text(
                widget.scoreUnit,
                style: TextStyle(
                  fontSize: unitFontSize,
                  fontWeight: FontWeight.w500,
                  color: theme.text,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: widget.size.getItemSpacing()),
        Flexible(
          child: Text(
            widget.status,
            style: TextStyle(
              fontSize: widget.size.getSubtitleFontSize(),
              fontWeight: FontWeight.w400,
              color: theme.textSub,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyBars(AppThemeData theme) {
    // 计算所有柱子的总宽度
    final barWidth = widget.size.getBarWidth();
    final barSpacing = widget.size.getItemSpacing();
    final totalBarWidth = (barWidth + barSpacing) * widget.weeklyData.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        // 如果总宽度不超过最大宽度，不需要滚动，直接居中显示
        if (totalBarWidth <= maxWidth) {
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(widget.weeklyData.length, (index) {
                final data = widget.weeklyData[index];
                return _WeeklyBar(
                  day: data.day.substring(0, 1),
                  value: data.value,
                  animation: _barAnimations[index],
                  isSelected: data.isSelected,
                  theme: theme,
                  onTap: () => widget.onBarTap?.call(index, data),
                  size: widget.size,
                );
              }),
            ),
          );
        }

        // 需要滚动，设置固定宽度以触发滚动，居中显示
        return SizedBox(
          width: maxWidth,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(widget.weeklyData.length, (index) {
                  final data = widget.weeklyData[index];
                  return _WeeklyBar(
                    day: data.day.substring(0, 1),
                    value: data.value,
                    animation: _barAnimations[index],
                    isSelected: data.isSelected,
                    theme: theme,
                    onTap: () => widget.onBarTap?.call(index, data),
                    size: widget.size,
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 每周进度条单项（斜纹柱：主题色浓斜纹生长于淡墨斜纹轨道）
class _WeeklyBar extends StatelessWidget {
  final String day;
  final double value;
  final Animation<double> animation;
  final bool isSelected;
  final AppThemeData theme;
  final VoidCallback? onTap;
  final HomeWidgetSize size;

  const _WeeklyBar({
    required this.day,
    required this.value,
    required this.animation,
    required this.isSelected,
    required this.theme,
    this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final barWidth = size.getBarWidth();
    final barHeight = size.getLargeFontSize() * 1.15;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: size.getItemSpacing() / 2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: Size(barWidth, barHeight),
                  painter: _StripedWeeklyBarPainter(
                    fillRatio: animation.value.clamp(0.0, 1.0),
                    dataColor: theme.primary,
                    theme: theme,
                    scale: size.scale,
                  ),
                ),
                SizedBox(height: size.getItemSpacing()),
                Text(
                  day,
                  style: TextStyle(
                    fontSize: size.getLegendFontSize(),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? theme.text : theme.textSub,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 斜纹周柱绘制器：胶囊轨道（surfaceAlt 底 + 淡墨斜纹 + 淡墨描边），
/// 数据色浅底 + 浓斜纹 + 数据色描边自底部生长。
class _StripedWeeklyBarPainter extends CustomPainter {
  final double fillRatio;
  final Color dataColor;
  final AppThemeData theme;
  final double scale;

  const _StripedWeeklyBarPainter({
    required this.fillRatio,
    required this.dataColor,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = Radius.circular(size.width / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // 轨道
    canvas.drawRRect(rrect, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(rrect),
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

    final h = size.height * fillRatio;
    if (h > 0.5) {
      final fillRect = Rect.fromLTWH(0, size.height - h, size.width, h);
      final fillRRect = RRect.fromRectAndRadius(fillRect, radius);
      canvas.drawRRect(
        fillRRect,
        Paint()..color = dataColor.withValues(alpha: 0.28),
      );
      paintDiagonalStripes(
        canvas,
        Path()..addRRect(fillRRect),
        fillRect,
        color: dataColor.withValues(alpha: 0.9),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawRRect(
        fillRRect,
        Paint()
          ..color = dataColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripedWeeklyBarPainter oldDelegate) {
    return oldDelegate.fillRatio != fillRatio ||
        oldDelegate.dataColor != dataColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}
