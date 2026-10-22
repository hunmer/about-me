import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 月度进度圆点小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 33 格圆点矩阵（已过日期数据色实底墨线圆点 / 未过日期淡底圆点，
/// 逐点错峰生长）/ 标题与百分比翻牌计数。
/// [backgroundColor] 为旧卡底色字段，仅为 props 兼容保留，
/// 现作为激活圆点的默认数据色。
class MonthlyProgressWithDotsCardWidget extends StatefulWidget {
  /// 标题（如习惯名称）
  final String title;

  /// 副标题（如月份、状态描述）
  final String? subtitle;

  /// 当前天数
  final int currentDay;

  /// 总天数
  final int totalDays;

  /// 百分比
  final int percentage;

  /// 背景颜色
  final Color backgroundColor;

  /// 已过日期的颜色（圆点颜色）
  final Color? activeDotColor;

  /// 未过日期的颜色（圆点颜色）
  final Color? inactiveDotColor;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const MonthlyProgressWithDotsCardWidget({
    super.key,
    required this.title,
    this.subtitle,
    required this.currentDay,
    required this.totalDays,
    required this.percentage,
    required this.backgroundColor,
    this.activeDotColor,
    this.inactiveDotColor,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory MonthlyProgressWithDotsCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return MonthlyProgressWithDotsCardWidget(
      title: props['title'] as String? ?? props['month'] as String? ?? '',
      subtitle: props['subtitle'] as String?,
      currentDay: props['currentDay'] as int? ?? 0,
      totalDays: props['totalDays'] as int? ?? 31,
      percentage: props['percentage'] as int? ?? 0,
      backgroundColor:
          props.containsKey('backgroundColor')
              ? Color(props['backgroundColor'] as int)
              : const Color(0xFF148690),
      activeDotColor:
          props['activeDotColor'] != null
              ? Color(props['activeDotColor'] as int)
              : null,
      inactiveDotColor:
          props['inactiveDotColor'] != null
              ? Color(props['inactiveDotColor'] as int)
              : null,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<MonthlyProgressWithDotsCardWidget> createState() =>
      _MonthlyProgressWithDotsCardWidgetState();
}

class _MonthlyProgressWithDotsCardWidgetState
    extends State<MonthlyProgressWithDotsCardWidget>
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

    // 数据色（props）：激活点默认回落旧卡底色字段，未激活点回落主题淡底
    final effectiveActiveDotColor =
        widget.activeDotColor ?? widget.backgroundColor;
    final effectiveInactiveDotColor =
        widget.inactiveDotColor ?? theme.surfaceAlt;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 250,
        height: widget.inline ? double.maxFinite : 250,
        radius: BorderRadius.circular(24 * widget.size.scale),
        padding: widget.size.getPadding(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 圆点矩阵（3行，每行11个点，代表33天）
            _DotMatrixGrid(
              currentDay: widget.currentDay,
              activeDotColor: effectiveActiveDotColor,
              inactiveDotColor: effectiveInactiveDotColor,
              animation: _animation,
              size: widget.size,
            ),

            // 底部信息
            _buildBottomInfo(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfo(AppThemeData theme) {
    final infoAnimation = CurvedAnimation(
      parent: _animation,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: infoAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: infoAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - infoAnimation.value)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: widget.size.getLargeFontSize() * 0.5,
                    fontWeight: FontWeight.w600,
                    color: theme.text,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: widget.size.getItemSpacing() * 0.25),
                Text(
                  widget.subtitle ??
                      '${widget.currentDay}d/${widget.totalDays}d',
                  style: TextStyle(
                    fontSize: widget.size.getLargeFontSize() * 0.29,
                    fontWeight: FontWeight.w500,
                    color: theme.textSub,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: widget.size.getItemSpacing()),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    AnimatedFlipCounter(
                      value: widget.percentage.toDouble() * infoAnimation.value,
                      fractionDigits: 0,
                      suffix: '%',
                      textStyle: TextStyle(
                        fontSize: widget.size.getLargeFontSize(),
                        fontWeight: FontWeight.w800,
                        color: theme.text,
                        height: 1,
                        letterSpacing: -1.5,
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

/// 圆点矩阵网格
class _DotMatrixGrid extends StatelessWidget {
  final int currentDay;
  final Color activeDotColor;
  final Color inactiveDotColor;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _DotMatrixGrid({
    required this.currentDay,
    required this.activeDotColor,
    required this.inactiveDotColor,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final dots = _generateDotStates();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int row = 0; row < 3; row++)
          Padding(
            padding: EdgeInsets.only(bottom: size.getItemSpacing() * 0.75),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int col = 0; col < 11; col++)
                  _Dot(
                    isActive: dots[row * 11 + col],
                    activeColor: activeDotColor,
                    inactiveColor: inactiveDotColor,
                    animation: animation,
                    index: row * 11 + col,
                    size: size,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// 生成圆点状态列表
  List<bool> _generateDotStates() {
    final List<bool> states = [];
    for (int i = 0; i < 33; i++) {
      states.add(i < currentDay);
    }
    return states;
  }
}

/// 单个圆点：手绘墨线圆（数据色实底 + 淡墨描边，逐点错峰生长）
class _Dot extends StatelessWidget {
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _Dot({
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final dotAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        (index * 0.02).clamp(0.0, 0.3),
        0.3 + (index * 0.015).clamp(0.0, 0.3),
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: dotAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.3 + 0.7 * dotAnimation.value,
          child: Container(
            width: size.getIconSize() * 0.42,
            height: size.getIconSize() * 0.42,
            decoration: dsSketchDecoration(
              theme: theme,
              circle: true,
              fillColor: isActive ? activeColor : inactiveColor,
              stroke: theme.ink.withValues(alpha: isActive ? 0.45 : 0.22),
              strokeWidth: 1.2,
            ),
          ),
        );
      },
    );
  }
}
