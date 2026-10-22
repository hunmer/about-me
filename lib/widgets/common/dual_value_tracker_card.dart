import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 双数值追踪卡片
///
/// 用于显示两个关联数值和趋势的卡片组件，适用于血压、血糖、
/// 体重等需要同时展示两个数值的健康指标追踪。
///
/// 手绘纸墨风（纸底 + 淡排线 + rough 墨线框，WiredDraw 墨线描画入场）：
/// 图标徽章 + 标题头部 / 双数值计数动画 / 周趋势柱状图
/// （淡墨斜纹轨道 + 数据色斜纹数据段，见 design.md §9.5）。
///
/// 特性：
/// - 双数值显示（如收缩压/舒张压）
/// - 入场计数动画与柱状图生长动画
/// - 深浅色一律走 AppTheme 语义色
/// - 周趋势柱状图
/// - 可配置颜色和图标
/// - 支持自定义标签和单位
///
/// 示例用法：
/// ```dart
/// // 血压追踪
/// DualValueTrackerCard(
///   title: 'Blood Pressure',
///   primaryValue: 128,
///   secondaryValue: 80,
///   status: 'Stable Range',
///   unit: 'mmHg',
///   icon: Icons.water_drop,
///   weekData: [
///     WeekData(label: 'M', normalPercent: 0.60, elevatedPercent: 0.20),
///     WeekData(label: 'T', normalPercent: 0.70, elevatedPercent: 0.30),
///   ],
/// )
///
/// // 血糖追踪
/// DualValueTrackerCard(
///   title: 'Blood Sugar',
///   primaryValue: 5.8,
///   secondaryValue: 6.2,
///   status: 'Normal',
///   unit: 'mmol/L',
///   icon: Icons.bloodtype,
///   decimalPlaces: 1,
/// )
/// ```
class DualValueTrackerCard extends StatefulWidget {
  /// 卡片标题
  final String title;

  /// 主数值（如收缩压、空腹血糖）
  final double primaryValue;

  /// 次数值（如舒张压、餐后血糖）
  final double secondaryValue;

  /// 状态描述
  final String? status;

  /// 单位
  final String unit;

  /// 图标
  final IconData icon;

  /// 主色调
  final Color? primaryColor;

  /// 小数位数（用于显示浮点数）
  final int decimalPlaces;

  /// 周数据
  final List<WeekData> weekData;

  /// 是否显示右侧按钮
  final bool showActionButton;

  /// 动作按钮标签
  final String? actionLabel;

  /// 动作按钮点击回调
  final VoidCallback? onActionPressed;

  /// 卡片宽度
  final double? width;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const DualValueTrackerCard({
    super.key,
    required this.title,
    required this.primaryValue,
    required this.secondaryValue,
    this.status,
    required this.unit,
    required this.icon,
    this.primaryColor,
    this.decimalPlaces = 0,
    required this.weekData,
    this.showActionButton = true,
    this.actionLabel,
    this.onActionPressed,
    this.width,
    this.size = const MediumSize(),
  });

  @override
  State<DualValueTrackerCard> createState() => _DualValueTrackerCardState();
}

class _DualValueTrackerCardState extends State<DualValueTrackerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    final size = widget.size;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 获取卡片的可用高度
        final availableHeight = constraints.maxHeight;
        final hasHeightConstraint =
            availableHeight.isFinite && availableHeight > 0;

        // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 墨线描画入场
        return WiredDraw(
          child: DsSketchPanel(
            theme: theme,
            width: widget.width ?? double.infinity,
            radius: BorderRadius.circular(24 * size.scale),
            padding: size.getPadding(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                _buildHeader(theme),
                // 数值显示
                _buildDualValue(theme),
                SizedBox(height: size.getItemSpacing()),
                // 周趋势图 - 填满剩余空间
                if (hasHeightConstraint)
                  Expanded(
                    child: _buildWeekTrendChart(
                      availableChartHeight: _calculateAvailableChartHeight(
                        availableHeight,
                        size,
                      ),
                    ),
                  )
                else
                  _buildWeekTrendChart(availableChartHeight: null),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 计算柱状图可用高度
  double _calculateAvailableChartHeight(
    double totalHeight,
    HomeWidgetSize size,
  ) {
    final padding = size.getPadding();
    final headerHeight =
        size.getIconSize() + size.getSmallSpacing() * 4; // 图标容器 + padding
    final valueFontSize = size.getLargeFontSize() * 0.5;
    final valueHeight = valueFontSize * 1.5; // 数值行高度
    final statusHeight =
        size.getSmallSpacing() + size.getLegendFontSize() * 1.2; // 状态文本高度
    final itemSpacing = size.getItemSpacing();

    // 可用高度 = 总高度 - padding - 标题 - 数值 - 状态 - 间距
    final usedHeight =
        padding.top +
        padding.bottom +
        headerHeight +
        valueHeight +
        statusHeight +
        itemSpacing;
    final available = totalHeight - usedHeight;
    return available > 0 ? available : size.getIconSize() * 2; // 最小高度保底
  }

  Widget _buildHeader(AppThemeData theme) {
    final primaryColor = widget.primaryColor ?? theme.primary;
    final size = widget.size;
    final iconSize = size.getIconSize();
    // 图标徽章：纸底实底 + 墨线描边（大圆角被 rough 引擎钳制成圆）
    final badgeSize = iconSize + size.getSmallSpacing() * 4;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: badgeSize,
                height: badgeSize,
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(badgeSize / 2),
                  fillColor: theme.surfaceAlt,
                ),
                child: Center(
                  child: WiredIcon(
                    icon: widget.icon,
                    size: iconSize,
                    color: primaryColor,
                    drawConfig: theme.wired.drawConfig,
                  ),
                ),
              ),
              SizedBox(width: size.getSmallSpacing() * 3),
              Flexible(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: size.getTitleFontSize(),
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
        // 动作胶囊：纸底实底 + 墨线描边（大圆角钳制成胶囊）
        if (widget.showActionButton)
          GestureDetector(
            onTap: widget.onActionPressed,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: size.getSmallSpacing() * 2.5,
                vertical: size.getSmallSpacing() * 1.2,
              ),
              decoration: dsSketchDecoration(
                theme: theme,
                radius: BorderRadius.circular(999),
                fillColor: theme.surfaceAlt,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.actionLabel ?? 'Today',
                    style: TextStyle(
                      color: theme.textSub,
                      fontSize: size.getSubtitleFontSize(),
                    ),
                  ),
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

  Widget _buildDualValue(AppThemeData theme) {
    final primaryColor = widget.primaryColor ?? theme.primary;
    final size = widget.size;
    final valueFontSize = size.getLargeFontSize() * 0.5; // 约 18-28px
    final unitFontSize = size.getSubtitleFontSize();
    final statusFontSize = size.getLegendFontSize();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // 主数值
            AnimatedCountText(
              count: widget.primaryValue,
              duration: const Duration(milliseconds: 1000),
              decimalPlaces: widget.decimalPlaces,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: valueFontSize,
                color: primaryColor,
              ),
            ),
            Text(
              '/',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: valueFontSize,
                color: primaryColor,
              ),
            ),
            // 次数值
            AnimatedCountText(
              count: widget.secondaryValue,
              duration: const Duration(milliseconds: 1000),
              decimalPlaces: widget.decimalPlaces,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: valueFontSize,
                color: primaryColor,
              ),
            ),
            SizedBox(width: size.getSmallSpacing()),
            Text(
              widget.unit,
              style: TextStyle(
                color: theme.textSub,
                fontWeight: FontWeight.w500,
                fontSize: unitFontSize,
              ),
            ),
          ],
        ),
        // 状态描述
        if (widget.status != null)
          Text(
            widget.status!,
            style: TextStyle(
              color: theme.textSub,
              fontSize: statusFontSize,
            ),
          ),
      ],
    );
  }

  Widget _buildWeekTrendChart({required double? availableChartHeight}) {
    final size = widget.size;
    final barWidth = size.getBarWidth();
    final labelFontSize = size.getLegendFontSize();
    final spacing = size.getSmallSpacing() * 2;

    // 计算柱状图区域高度
    final labelHeight = labelFontSize * 1.2;
    // 使用传入的可用高度或回退到默认计算
    final maxBarHeight =
        availableChartHeight != null
            ? (availableChartHeight - spacing - labelHeight).clamp(
              size.getIconSize(),
              double.infinity,
            )
            : size.getIconSize() * 2;

    // 找到所有数据中的最大总百分比，用于按比例缩放
    final maxTotalPercent = widget.weekData.fold<double>(
      0.0,
      (max, data) =>
          (data.normalPercent + data.elevatedPercent) > max
              ? data.normalPercent + data.elevatedPercent
              : max,
    );

    return SizedBox(
      height: maxBarHeight + spacing + labelHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children:
            widget.weekData.map((dayData) {
              return WeekBar(
                label: dayData.label,
                normalPercent: dayData.normalPercent,
                elevatedPercent: dayData.elevatedPercent,
                maxTotalPercent: maxTotalPercent,
                animationController: _animationController,
                primaryColor: widget.primaryColor,
                size: size,
                maxBarHeight: maxBarHeight,
                barWidth: barWidth,
                labelFontSize: labelFontSize,
                spacing: spacing,
              );
            }).toList(),
      ),
    );
  }
}

/// 周数据柱状图组件
///
/// 柱区为平直几何 + 斜纹填充（design.md §9.5）：淡墨斜纹轨道垫底，
/// 正常段数据色淡斜纹（0.45）、升高段数据色浓斜纹（0.9）叠放，
/// 生长动画由 [animationController] 插值。
class WeekBar extends StatelessWidget {
  final String label;
  final double normalPercent;
  final double elevatedPercent;
  final double maxTotalPercent;
  final AnimationController animationController;
  final Color? primaryColor;
  final HomeWidgetSize size;
  final double maxBarHeight;
  final double barWidth;
  final double labelFontSize;
  final double spacing;

  const WeekBar({
    super.key,
    required this.label,
    required this.normalPercent,
    required this.elevatedPercent,
    required this.maxTotalPercent,
    required this.animationController,
    this.primaryColor,
    required this.size,
    required this.maxBarHeight,
    required this.barWidth,
    required this.labelFontSize,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final barColor = primaryColor ?? theme.primary;

    // 根据最大百分比计算缩放比例
    final totalPercent = normalPercent + elevatedPercent;
    final scale = maxTotalPercent > 0 ? totalPercent / maxTotalPercent : 0.0;
    final barHeight = maxBarHeight * scale;

    // 正常段/升高段的最终高度（生长插值在 painter 内完成）
    final normalHeight =
        totalPercent > 0 ? normalPercent * barHeight / totalPercent : 0.0;
    final elevatedHeight =
        totalPercent > 0 ? elevatedPercent * barHeight / totalPercent : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 柱状图（CustomPaint 无 child，由 SizedBox 给紧宽紧高）
        SizedBox(
          height: maxBarHeight,
          width: barWidth,
          child: AnimatedBuilder(
            animation: animationController,
            builder: (context, _) {
              return CustomPaint(
                size: Size(barWidth, maxBarHeight),
                painter: _WeekBarPainter(
                  progress: animationController.value,
                  normalHeight: normalHeight,
                  elevatedHeight: elevatedHeight,
                  barColor: barColor,
                  theme: theme,
                  scale: size.scale,
                ),
              );
            },
          ),
        ),
        SizedBox(height: spacing),
        // 标签
        Text(
          label,
          style: TextStyle(
            color: theme.textSub,
            fontWeight: FontWeight.w500,
            fontSize: labelFontSize,
          ),
        ),
      ],
    );
  }
}

/// 周趋势柱绘制器：斜纹轨道 + 斜纹数据段（design.md §9.5）
///
/// 轨道柱：surfaceAlt 底 + 淡墨斜纹（ink 0.28）+ 淡墨描边（ink 0.45）；
/// 正常段：数据色浅底（0.28）+ 数据色淡斜纹（0.45 浅档）+ 数据色描边（0.85）；
/// 升高段：数据色浅底（0.28）+ 数据色浓斜纹（0.9）+ 数据色描边（0.85）。
/// [progress]（0~1）对两段高度做入场生长插值。
class _WeekBarPainter extends CustomPainter {
  final double progress;
  final double normalHeight;
  final double elevatedHeight;
  final Color barColor;
  final AppThemeData theme;
  final double scale;

  const _WeekBarPainter({
    required this.progress,
    required this.normalHeight,
    required this.elevatedHeight,
    required this.barColor,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final width = size.width;
    final corner = math.min(width * 0.25, size.height / 2);

    // 轨道柱（完整可用高度，仅顶部圆角）
    final trackRect = Rect.fromLTWH(0, 0, width, size.height);
    final trackRadius = Radius.circular(corner);
    final trackRRect = RRect.fromRectAndCorners(
      trackRect,
      topLeft: trackRadius,
      topRight: trackRadius,
    );
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

    final p = progress.clamp(0.0, 1.0);

    // 数据段：数据色浅底 + 斜纹 + 描边（平直几何，禁 rough）
    void paintSegment(Rect rect, Color stripesColor) {
      final radius = Radius.circular(math.min(corner, rect.height / 2));
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: radius,
        topRight: radius,
      );
      canvas.drawRRect(
        rrect,
        Paint()..color = barColor.withValues(alpha: 0.28),
      );
      paintDiagonalStripes(
        canvas,
        Path()..addRRect(rrect),
        rect,
        color: stripesColor,
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = barColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }

    // 正常段（底部，浅档斜纹）
    final nH = normalHeight * p;
    if (nH > 0.5) {
      paintSegment(
        Rect.fromLTWH(0, size.height - nH, width, nH),
        barColor.withValues(alpha: 0.45),
      );
    }
    // 升高段（叠在正常段之上，浓斜纹）
    final eH = elevatedHeight * p;
    if (eH > 0.5) {
      paintSegment(
        Rect.fromLTWH(0, size.height - normalHeight - eH, width, eH),
        barColor.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeekBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.normalHeight != normalHeight ||
        oldDelegate.elevatedHeight != elevatedHeight ||
        oldDelegate.barColor != barColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}

/// 数字计数动画组件
class AnimatedCountText extends StatefulWidget {
  final double count;
  final Duration duration;
  final int decimalPlaces;
  final TextStyle? style;

  const AnimatedCountText({
    super.key,
    required this.count,
    required this.duration,
    this.decimalPlaces = 0,
    this.style,
  });

  @override
  State<AnimatedCountText> createState() => _AnimatedCountTextState();
}

class _AnimatedCountTextState extends State<AnimatedCountText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _animation = Tween<double>(
      begin: 0.0,
      end: widget.count,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        final displayValue =
            widget.decimalPlaces > 0
                ? value.toStringAsFixed(widget.decimalPlaces)
                : value.toInt().toString();
        return Text(displayValue, style: widget.style);
      },
    );
  }
}

/// 周数据模型
///
/// 表示一周中某一天的数据，用于柱状图展示。
class WeekData {
  /// 标签（如 'M', 'T', 'W' 或周一、周二）
  final String label;

  /// 正常范围百分比 (0.0-1.0)
  final double normalPercent;

  /// 升高范围百分比 (0.0-1.0)
  final double elevatedPercent;

  const WeekData({
    required this.label,
    required this.normalPercent,
    required this.elevatedPercent,
  });

  /// 创建默认的空数据
  factory WeekData.empty(String label) {
    return WeekData(label: label, normalPercent: 0.0, elevatedPercent: 0.0);
  }

  /// 从 JSON 创建
  factory WeekData.fromJson(Map<String, dynamic> json) {
    return WeekData(
      label: json['label'] as String,
      normalPercent: (json['normalPercent'] as num?)?.toDouble() ?? 0.0,
      elevatedPercent: (json['elevatedPercent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'normalPercent': normalPercent,
      'elevatedPercent': elevatedPercent,
    };
  }
}

/// 双数值追踪卡片包装器（用于 widgets_gallery 兼容性）
///
/// 提供从 props 创建实例的工厂方法，用于公共小组件系统。
class DualValueTrackerCardWrapper extends StatelessWidget {
  /// 卡片标题
  final String title;

  /// 主数值
  final double primaryValue;

  /// 次数值
  final double secondaryValue;

  /// 状态描述
  final String? status;

  /// 单位
  final String unit;

  /// 图标代码
  final String icon;

  /// 主色调
  final Color? primaryColor;

  /// 小数位数
  final int decimalPlaces;

  /// 周数据
  final List<WeekData> weekData;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const DualValueTrackerCardWrapper({
    super.key,
    required this.title,
    required this.primaryValue,
    required this.secondaryValue,
    this.status,
    required this.unit,
    required this.icon,
    this.primaryColor,
    this.decimalPlaces = 0,
    required this.weekData,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory DualValueTrackerCardWrapper.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final weekDataList = props['weekData'] as List?;
    final weekData =
        weekDataList?.map((item) {
          return WeekData.fromJson(item as Map<String, dynamic>);
        }).toList() ??
        <WeekData>[];

    return DualValueTrackerCardWrapper(
      title: props['title'] as String? ?? '统计',
      primaryValue: (props['primaryValue'] as num?)?.toDouble() ?? 0.0,
      secondaryValue: (props['secondaryValue'] as num?)?.toDouble() ?? 0.0,
      status: props['status'] as String?,
      unit: props['unit'] as String? ?? '',
      icon: props['icon'] as String? ?? 'info',
      primaryColor:
          props['primaryColor'] != null
              ? Color(props['primaryColor'] as int)
              : null,
      decimalPlaces: props['decimalPlaces'] as int? ?? 0,
      weekData: weekData,
      size: size,
    );
  }

  IconData _getIconData(String iconCode) {
    // 简化的图标映射
    switch (iconCode) {
      case 'water_drop':
        return Icons.water_drop;
      case 'favorite':
        return Icons.favorite;
      case 'timeline':
        return Icons.timeline;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DualValueTrackerCard(
      title: title,
      primaryValue: primaryValue,
      secondaryValue: secondaryValue,
      status: status,
      unit: unit,
      icon: _getIconData(icon),
      primaryColor: primaryColor,
      decimalPlaces: decimalPlaces,
      weekData: weekData,
      showActionButton: false,
      size: size,
    );
  }
}
