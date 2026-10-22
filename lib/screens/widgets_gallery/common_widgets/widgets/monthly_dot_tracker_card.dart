/// 月度点追踪卡片 - 公共小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 + 状态 / 右上数值翻牌计数 / 月度圆点矩阵（已打卡主题色实底
/// 墨线圆点、未打卡淡底圆点，逐点错峰生长）。
/// 旧版为 lib/widgets/common/dot_tracker_card.dart 的适配器，
/// 现已内联手绘化，对外 props 契约不变。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 月度点追踪卡片小组件
class MonthlyDotTrackerCardWidget extends StatefulWidget {
  final Map<String, dynamic> props;
  final HomeWidgetSize size;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  const MonthlyDotTrackerCardWidget({
    super.key,
    required this.props,
    required this.size,
    this.inline = false,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory MonthlyDotTrackerCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return MonthlyDotTrackerCardWidget(
      props: props,
      size: size,
      inline: props['inline'] as bool? ?? false,
    );
  }

  @override
  State<MonthlyDotTrackerCardWidget> createState() =>
      _MonthlyDotTrackerCardWidgetState();
}

class _MonthlyDotTrackerCardWidgetState
    extends State<MonthlyDotTrackerCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  /// 翻牌计数目标值（postFrame 后置入以播放 0 → 目标动画）
  int _displayValue = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _displayValue = widget.props['currentValue'] as int? ?? 0;
        });
        _animationController.forward();
      }
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
    final title = widget.props['title'] as String? ?? '月度追踪';
    final currentValue = widget.props['currentValue'] as int? ?? 0;
    final totalDays = widget.props['totalDays'] as int? ?? 30;
    final daysData =
        (widget.props['daysData'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    // 从 daysData 提取数据：日期标签 + 单点打卡状态
    final dayLabels = <String>[];
    final dotStates = <bool>[];
    for (final dayData in daysData) {
      final day = dayData['day'] as int? ?? 1;
      final isChecked = dayData['isChecked'] as bool? ?? false;
      dayLabels.add('$day');
      dotStates.add(isChecked);
    }

    // 如果 daysData 为空，使用默认当月天数
    if (dayLabels.isEmpty) {
      for (int i = 1; i <= totalDays; i++) {
        dayLabels.add('$i');
        dotStates.add(false);
      }
    }

    // 计算状态文本
    final percentage = totalDays > 0 ? currentValue / totalDays : 0.0;
    String status;
    if (percentage >= 1.0) {
      status = '已完成';
    } else if (percentage >= 0.7) {
      status = '进行中';
    } else if (percentage > 0) {
      status = '刚开始';
    } else {
      status = '未开始';
    }

    // 根据尺寸计算高度（沿用旧适配器的高度推导）
    final constraints = widget.size.getHeightConstraints();
    final height =
        widget.inline
            ? double.maxFinite
            : (constraints.maxHeight + constraints.minHeight) / 2;
    final unit = '/$totalDays 天';

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : null,
        height: height,
        radius: BorderRadius.circular(24 * widget.size.scale),
        padding: widget.size.getPadding(),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, title, status),
                SizedBox(height: widget.size.getTitleSpacing()),
                Expanded(child: _buildDotsGrid(theme, dotStates)),
              ],
            ),
            // 数值显示（右上角，不受 padding 影响）
            Positioned(
              top: widget.size.getSmallSpacing() * 4,
              right: 0,
              child: _buildValueDisplay(theme, unit),
            ),
          ],
        ),
      ),
    );
  }

  /// 头部：标题 + 状态
  Widget _buildHeader(AppThemeData theme, String title, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: widget.size.getTitleFontSize() * 0.75,
            fontWeight: FontWeight.bold,
            color: theme.text,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: widget.size.getSmallSpacing()),
        Text(
          status,
          style: TextStyle(
            fontSize: widget.size.getSubtitleFontSize(),
            fontWeight: FontWeight.w500,
            color: theme.textSub,
          ),
        ),
      ],
    );
  }

  /// 右上数值：翻牌计数 + 单位
  Widget _buildValueDisplay(AppThemeData theme, String unit) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedFlipCounter(
          value: _displayValue.toDouble(),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          textStyle: TextStyle(
            fontSize: widget.size.getLargeFontSize() * 0.6,
            fontWeight: FontWeight.w800,
            color: theme.text,
            height: 1.0,
            letterSpacing: -1,
          ),
        ),
        SizedBox(width: widget.size.getSmallSpacing() * 1.5),
        Text(
          unit,
          style: TextStyle(
            fontSize: widget.size.getSubtitleFontSize() * 0.7,
            fontWeight: FontWeight.w600,
            color: theme.textSub,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  /// 圆点矩阵：已打卡主题色实底墨线圆点 / 未打卡淡底圆点，逐点错峰生长
  Widget _buildDotsGrid(AppThemeData theme, List<bool> dotStates) {
    final dayCount = dotStates.length;
    if (dayCount == 0) return const SizedBox.shrink();

    final crossAxisCount = dayCount <= 14 ? dayCount : 7;
    final rows = (dayCount / crossAxisCount).ceil();
    final step = dayCount > 1 ? 0.35 / (dayCount - 1) : 0.0;

    // 根据尺寸计算圆点大小（沿用旧点阵卡的取值）
    final dotSize =
        widget.size is SmallSize
            ? 16.0
            : (widget.size is MediumSize || widget.size is WideSize
                ? 26.0
                : 30.0);
    final dotSpacing = widget.size.getSmallSpacing();

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowExtent =
            constraints.maxHeight.isFinite
                ? constraints.maxHeight / rows
                : dotSize * 2.0;
        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 0,
            crossAxisSpacing: dotSpacing * 0.5,
            mainAxisExtent: rowExtent,
          ),
          itemCount: dayCount,
          itemBuilder: (context, index) {
            final itemAnimation = CurvedAnimation(
              parent: _animationController,
              curve: Interval(
                index * step,
                0.65 + index * step,
                curve: Curves.easeOutCubic,
              ),
            );
            return _DayDot(
              isEnabled: dotStates[index],
              theme: theme,
              animation: itemAnimation,
              dotSize: dotSize,
            );
          },
        );
      },
    );
  }
}

/// 单个打卡圆点
class _DayDot extends StatelessWidget {
  final bool isEnabled;
  final AppThemeData theme;
  final Animation<double> animation;
  final double dotSize;

  const _DayDot({
    required this.isEnabled,
    required this.theme,
    required this.animation,
    required this.dotSize,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: isEnabled ? animation.value : 1.0,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: dsSketchDecoration(
              theme: theme,
              circle: true,
              fillColor: isEnabled ? theme.primary : theme.surfaceAlt,
              stroke: theme.ink.withValues(alpha: isEnabled ? 0.45 : 0.22),
              strokeWidth: 1.2,
            ),
          ),
        );
      },
    );
  }
}
