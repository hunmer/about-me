/// 堆叠条形图小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘迷你柱标 + 标题 + 增长率翻牌（主题色手绘趋势图标）/
/// 副标题 / 斜纹堆叠条（浅/中/深三层各数据色浅底 + 浓斜纹 + 描边，
/// 逐条错峰自底向上生长）。
library;

import 'dart:math' as math;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 堆叠条形图小组件
///
/// 用于显示分层的堆叠条形图，支持三层数据（浅色、中间色、深色），
/// 每个条形独立动画，适用于统计、对比、趋势分析等场景。
///
/// 特性：
/// - 三层堆叠数据展示（浅色/中间色/深色）
/// - 独立条形延迟动画（斜纹条自底向上生长）
/// - 增长率翻牌计数器
/// - 可配置数据颜色
/// - 支持不同尺寸自适应
class StackedBarChartWidget extends StatefulWidget {
  /// 卡片标题
  final String title;

  /// 卡片副标题
  final String subtitle;

  /// 增长率百分比
  final double growthRate;

  /// 条形图数据
  final List<StackedBarData> data;

  /// 浅色层颜色
  final Color? lightColor;

  /// 中间层颜色
  final Color? midColor;

  /// 深色层颜色
  final Color? darkColor;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const StackedBarChartWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.growthRate,
    required this.data,
    this.lightColor,
    this.midColor,
    this.darkColor,
    this.size = const MediumSize(),
  });

  @override
  State<StackedBarChartWidget> createState() => _StackedBarChartWidgetState();
}

class _StackedBarChartWidgetState extends State<StackedBarChartWidget>
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
    final scale = widget.size.scale;

    // 条形图数据色（props 优先，缺省浅/中/深三阶）
    final lightColor = widget.lightColor ?? const Color(0xFFCCEFF9);
    final midColor = widget.midColor ?? const Color(0xFF0064A7);
    final darkColor = widget.darkColor ?? const Color(0xFF000045);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          radius: BorderRadius.circular(24 * scale),
          padding: widget.size.getPadding(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              _buildTitleRow(theme),
              SizedBox(height: widget.size.getTitleSpacing()),
              // 副标题
              _buildSubtitle(theme),
              SizedBox(height: widget.size.getTitleSpacing()),
              // 条形图
              Expanded(
                child: _buildBars(lightColor, midColor, darkColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标题行
  Widget _buildTitleRow(AppThemeData theme) {
    final iconSize = widget.size.getIconSize();
    final titleFontSize = widget.size.getTitleFontSize();
    final subtitleFontSize = widget.size.getSubtitleFontSize();
    final smallSpacing = widget.size.getSmallSpacing();

    return Row(
      children: [
        // 迷你柱形标（手绘墨底色块）
        SizedBox(
          height: iconSize,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: iconSize * 0.25,
                height: iconSize * 0.5,
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(iconSize * 0.1),
                  fillColor: theme.ink,
                ),
              ),
              SizedBox(width: smallSpacing),
              Container(
                width: iconSize * 0.25,
                height: iconSize * 0.8,
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(iconSize * 0.1),
                  fillColor: theme.ink,
                ),
              ),
              SizedBox(width: smallSpacing),
              Container(
                width: iconSize * 0.25,
                height: iconSize * 0.65,
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(iconSize * 0.1),
                  fillColor: theme.ink,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: smallSpacing * 3),
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: theme.text,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        // 增长率（翻牌计数器消费 _animation.value，需 AnimatedBuilder 逐帧驱动）
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: smallSpacing,
            vertical: smallSpacing * 0.5,
          ),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => Row(
              children: [
                WiredIcon(
                  icon: Icons.trending_up,
                  size: iconSize * 0.8,
                  color: theme.primary,
                  drawConfig: theme.wired.drawConfig,
                ),
                SizedBox(width: smallSpacing),
                AnimatedFlipCounter(
                  value: widget.growthRate * _animation.value,
                  fractionDigits: 0,
                  prefix: '+',
                  suffix: '%',
                  textStyle: TextStyle(
                    color: theme.primary,
                    fontSize: subtitleFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建副标题
  Widget _buildSubtitle(AppThemeData theme) {
    return Text(
      widget.subtitle,
      style: TextStyle(
        fontSize: widget.size.getSubtitleFontSize(),
        color: theme.textSub,
        height: 1.5,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 构建条形图区域
  Widget _buildBars(Color lightColor, Color midColor, Color darkColor) {
    return Row(
      children: List.generate(widget.data.length, (index) {
        final barData = widget.data[index];

        // 为每个条形创建延迟动画，确保 end <= 1.0
        final step = 0.05;
        final start = index * step;
        final end = (0.6 + index * step).clamp(0.0, 1.0);
        final barAnimation = CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            start,
            end,
            curve: Curves.easeOutCubic,
          ),
        );

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right:
                  index < widget.data.length - 1
                      ? widget.size.getSmallSpacing()
                      : 0,
            ),
            child: _StackedBar(
              data: barData,
              animation: barAnimation,
              lightColor: lightColor,
              midColor: midColor,
              darkColor: darkColor,
              size: widget.size,
            ),
          ),
        );
      }),
    );
  }
}

/// 单个堆叠条形：整条一个 CustomPaint 绘制斜纹堆叠层
/// （SizedBox.expand 给紧约束，防止无 child 的 CustomPaint 塌缩）
class _StackedBar extends StatelessWidget {
  final StackedBarData data;
  final Animation<double> animation;
  final Color lightColor;
  final Color midColor;
  final Color darkColor;
  final HomeWidgetSize size;

  const _StackedBar({
    required this.data,
    required this.animation,
    required this.lightColor,
    required this.midColor,
    required this.darkColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => SizedBox.expand(
        child: CustomPaint(
          painter: _StackedBarPainter(
            data: data,
            lightColor: lightColor,
            midColor: midColor,
            darkColor: darkColor,
            progress: animation.value,
            gap: size.getSmallSpacing(),
            scale: size.scale,
          ),
        ),
      ),
    );
  }
}

/// 斜纹堆叠条绘制器
///
/// 浅/中/深三层各铺数据色浅底（0.28）+ 数据色斜纹（0.9）+ 数据色描边
/// （0.85），顶层顶圆角、底层底圆角，整条按 [progress]（逐条错峰）
/// 自底向上生长。
class _StackedBarPainter extends CustomPainter {
  final StackedBarData data;
  final Color lightColor;
  final Color midColor;
  final Color darkColor;
  final double progress;
  final double gap;
  final double scale;

  const _StackedBarPainter({
    required this.data,
    required this.lightColor,
    required this.midColor,
    required this.darkColor,
    required this.progress,
    required this.gap,
    required this.scale,
  });

  void _paintLayer(
    Canvas canvas,
    Rect rect,
    Color color, {
    Radius topRadius = Radius.zero,
    Radius bottomRadius = Radius.zero,
  }) {
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: topRadius,
      topRight: topRadius,
      bottomLeft: bottomRadius,
      bottomRight: bottomRadius,
    );
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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0) return;
    // 自底向上：深色层（底圆角）→ 中间层 → 浅色层（顶圆角）
    final layers = <(double, Color, Radius, Radius)>[
      (data.darkValue, darkColor, Radius.zero, Radius.circular(size.width * 0.25)),
      (data.midValue, midColor, Radius.zero, Radius.zero),
      (data.lightValue, lightColor, Radius.circular(size.width * 0.25), Radius.zero),
    ];
    final visible = layers.where((l) => l.$1 > 0).toList();
    if (visible.isEmpty) return;
    final total = visible.fold<double>(0, (sum, l) => sum + l.$1);
    if (total <= 0) return;

    final availableHeight = math.max(
      0.0,
      size.height - gap * (visible.length - 1),
    );

    var y = size.height;
    for (final (value, color, topRadius, bottomRadius) in visible) {
      final height = availableHeight * (value / total) * progress;
      y -= height;
      if (height > 0.5) {
        _paintLayer(
          canvas,
          Rect.fromLTWH(0, y, size.width, height),
          color,
          topRadius: topRadius,
          bottomRadius: bottomRadius,
        );
      }
      y -= gap;
    }
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.lightColor != lightColor ||
        oldDelegate.midColor != midColor ||
        oldDelegate.darkColor != darkColor ||
        oldDelegate.progress != progress ||
        oldDelegate.gap != gap ||
        oldDelegate.scale != scale;
  }
}

/// 堆叠条形数据模型
///
/// 表示单个条形的三层数据结构。
class StackedBarData {
  /// 浅色层高度百分比 (0-100)
  final double lightValue;

  /// 中间层高度百分比 (0-100)
  final double midValue;

  /// 深色层高度百分比 (0-100)
  final double darkValue;

  const StackedBarData({
    required this.lightValue,
    required this.midValue,
    required this.darkValue,
  });
}
