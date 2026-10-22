/// 迷你趋势卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆形图标徽章 + 标题头部 / 当前数值（翻牌计数器）+ 单位 + 副标题 /
/// 趋势折线图（数据色平直折线 + 斜纹面积填充）/ 星期标签。
/// 折线描画与数值动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 迷你趋势卡片小组件
///
/// 显示标题、图标、当前数值、单位、副标题、星期标签和趋势折线图
class MiniTrendCardWidget extends StatefulWidget {
  /// 标题
  final String title;

  /// 图标
  final IconData icon;

  /// 当前数值
  final int currentValue;

  /// 单位
  final String unit;

  /// 副标题
  final String subtitle;

  /// 星期标签（7个字符）
  final List<String> weekDays;

  /// 趋势数据（0-100之间）
  final List<double> trendData;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const MiniTrendCardWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.currentValue,
    required this.unit,
    required this.subtitle,
    required this.weekDays,
    required this.trendData,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory MiniTrendCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return MiniTrendCardWidget(
      title: props['title'] as String? ?? '',
      icon: _getIcon(props['icon'] as String? ?? 'monitor_heart'),
      currentValue: (props['currentValue'] as num?)?.toInt() ?? 0,
      unit: props['unit'] as String? ?? '',
      subtitle: props['subtitle'] as String? ?? '',
      weekDays:
          (props['weekDays'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      trendData:
          (props['trendData'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  static IconData _getIcon(String iconName) {
    return {
          'monitor_heart': Icons.monitor_heart,
          'favorite': Icons.favorite,
          'fitness_center': Icons.fitness_center,
          'speed': Icons.speed,
          'timeline': Icons.timeline,
        }[iconName] ??
        Icons.monitor_heart;
  }

  @override
  State<MiniTrendCardWidget> createState() => _MiniTrendCardWidgetState();
}

class _MiniTrendCardWidgetState extends State<MiniTrendCardWidget>
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

  double _defaultHeight() {
    final scale = widget.size.scale;
    if (widget.size is SmallSize) return 150 * scale;
    if (widget.size is MediumSize || widget.size is WideSize) {
      return 190 * scale;
    }
    if (widget.size is LargeSize || widget.size is Wide2Size) {
      return 330 * scale;
    }
    return 430 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 判断是否为 wide 类型
    final isWide = widget.size.width == 4;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 380 * scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildHeader(theme),
            SizedBox(height: widget.size.getTitleSpacing()),

            // 主要内容
            Expanded(
              child: isWide
                  ? // wide 类型：数值显示 + 趋势图
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 数值显示
                        Flexible(
                          flex: 6,
                          child: _buildValueDisplay(theme),
                        ),
                        const SizedBox(width: 8),
                        // 趋势迷你图靠右
                        Flexible(
                          flex: 7,
                          child: _buildMiniTrendChart(theme),
                        ),
                      ],
                    )
                  : // 非 wide 类型：只显示趋势图（占满宽度）
                  _buildMiniTrendChart(theme),
            ),
          ],
        ),
      ),
    );
  }

  /// 头部：手绘圆形图标徽章 + 标题 + Today 入口
  Widget _buildHeader(AppThemeData theme) {
    final iconSize = widget.size.getIconSize();
    final containerSize = iconSize * widget.size.iconContainerScale;

    return Row(
      children: [
        // 左侧图标和标题区域
        Expanded(
          child: Row(
            children: [
              Container(
                width: containerSize,
                height: containerSize,
                // 大圆角被 rough 引擎自动钳制成圆
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
          onTap: () {},
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
                WiredIcon(
                  icon: Icons.chevron_right,
                  size: iconSize * 0.8,
                  color: theme.textSub,
                  drawConfig: theme.wired.drawConfig,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 数值（翻牌计数器）+ 单位 + 副标题
  Widget _buildValueDisplay(AppThemeData theme) {
    final scoreFontSize = widget.size.getLargeFontSize() * 0.7;
    final unitFontSize = widget.size.getLargeFontSize() * 0.35;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedFlipCounter(
              value: widget.currentValue * _animation.value,
              textStyle: TextStyle(
                fontSize: scoreFontSize,
                fontWeight: FontWeight.bold,
                color: theme.text,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: widget.size.getItemSpacing()),
              child: Text(
                widget.unit,
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
            widget.subtitle,
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

  /// 趋势迷你图 + 星期标签
  Widget _buildMiniTrendChart(AppThemeData theme) {
    final chartHeight = widget.size.getLargeFontSize() * 1.15;

    return Column(
      children: [
        Expanded(
          child: _AnimatedTrendLine(
            data: widget.trendData,
            color: theme.primary,
            animation: _animation,
            chartHeight: chartHeight,
            scale: widget.size.scale,
          ),
        ),
        SizedBox(height: widget.size.getItemSpacing()),
        // 星期标签
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
              widget.weekDays.map((day) {
                return Text(
                  day,
                  style: TextStyle(
                    fontSize: widget.size.getLegendFontSize(),
                    fontWeight: FontWeight.w500,
                    color: theme.textSub,
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }
}

/// 动画趋势折线图组件
class _AnimatedTrendChart extends StatelessWidget {
  final List<double> data;
  final Color color;
  final Animation<double> animation;
  final double chartHeight;
  final double scale;

  const _AnimatedTrendChart({
    required this.data,
    required this.color,
    required this.animation,
    required this.chartHeight,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _TrendLinePainter(
          data: data,
          color: color,
          progress: animation.value,
          chartHeight: chartHeight,
          scale: scale,
        ),
      ),
    );
  }
}

/// 趋势折线画笔
///
/// 数据色平直折线（无 rough 抖动），线下面积用数据色浅底 + 淡斜纹填充
/// （§9.5 斜纹数据填充，替代原渐变）。
class _TrendLinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double progress;
  final double chartHeight;
  final double scale;

  _TrendLinePainter({
    required this.data,
    required this.color,
    required this.progress,
    required this.chartHeight,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final chartWidth = size.width;
    final maxHeight =
        data.isEmpty ? 1.0 : data.reduce((a, b) => a > b ? a : b).toDouble();
    final stepX = data.length > 1 ? chartWidth / (data.length - 1) : chartWidth;

    // 绘制斜纹面积填充（数据色浅底 + 数据色淡斜纹）
    final areaPath = Path();
    areaPath.moveTo(0, chartHeight);
    for (int i = 0; i < data.length * progress; i++) {
      final x = i * stepX;
      final y = chartHeight - (data[i] / maxHeight) * chartHeight * progress;
      areaPath.lineTo(x, y);
    }
    final lastX =
        (data.length * progress - 1).clamp(0, data.length - 1).toInt() * stepX;
    areaPath.lineTo(lastX, chartHeight);
    areaPath.close();

    canvas.drawPath(areaPath, Paint()..color = color.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      areaPath,
      areaPath.getBounds(),
      color: color.withValues(alpha: 0.45),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );

    // 绘制折线（平直干净的数据色描边）
    final linePath = Path();
    for (int i = 0; i < data.length * progress; i++) {
      final x = i * stepX;
      final y = chartHeight - (data[i] / maxHeight) * chartHeight * progress;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final linePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.data != data ||
        oldDelegate.scale != scale;
  }
}

/// 动画趋势折线图组件（使用 AnimatedBuilder）
class _AnimatedTrendLine extends StatelessWidget {
  final List<double> data;
  final Color color;
  final Animation<double> animation;
  final double chartHeight;
  final double scale;

  const _AnimatedTrendLine({
    required this.data,
    required this.color,
    required this.animation,
    required this.chartHeight,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return _AnimatedTrendChart(
          data: data,
          color: color,
          animation: animation,
          chartHeight: chartHeight,
          scale: scale,
        );
      },
    );
  }
}
