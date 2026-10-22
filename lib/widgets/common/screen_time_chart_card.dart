/// 屏幕时间堆叠柱状图卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆框头像徽章 + 总时长 / 淡墨网格线与垂直虚线 /
/// 斜纹堆叠柱（各分段数据色浅底 + 数据色浓斜纹 + 数据色描边，
/// 逐柱错峰自底向上生长）/ X 轴刻度。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 屏幕时间数据分段
class ScreenTimeSegment {
  final String category;
  final double percentage;

  const ScreenTimeSegment({required this.category, required this.percentage});

  /// 从 JSON 创建
  factory ScreenTimeSegment.fromJson(Map<String, dynamic> json) {
    return ScreenTimeSegment(
      category: json['category'] as String? ?? 'gray',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'category': category, 'percentage': percentage};
  }
}

/// 屏幕时间数据点
class ScreenTimeDataPoint {
  final String timeLabel;
  final List<ScreenTimeSegment> segments;
  final double heightPercentage;

  const ScreenTimeDataPoint({
    required this.timeLabel,
    required this.segments,
    required this.heightPercentage,
  });

  /// 从 JSON 创建
  factory ScreenTimeDataPoint.fromJson(Map<String, dynamic> json) {
    return ScreenTimeDataPoint(
      timeLabel: json['timeLabel'] as String? ?? '',
      segments:
          (json['segments'] as List<dynamic>?)
              ?.map(
                (e) => ScreenTimeSegment.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      heightPercentage: (json['heightPercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'timeLabel': timeLabel,
      'segments': segments.map((e) => e.toJson()).toList(),
      'heightPercentage': heightPercentage,
    };
  }
}

/// 屏幕时间统计图表小组件
class ScreenTimeChartCardWidget extends StatefulWidget {
  /// 头像 URL（可选）
  final String? avatarUrl;

  /// 总小时数
  final int totalHours;

  /// 总分钟数
  final int totalMinutes;

  /// 数据点列表
  final List<ScreenTimeDataPoint> dataPoints;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const ScreenTimeChartCardWidget({
    super.key,
    this.avatarUrl,
    required this.totalHours,
    required this.totalMinutes,
    required this.dataPoints,
    this.size = const MediumSize(),
  });

  @override
  State<ScreenTimeChartCardWidget> createState() =>
      _ScreenTimeChartCardWidgetState();
}

class _ScreenTimeChartCardWidgetState extends State<ScreenTimeChartCardWidget>
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
    // 确保动画立即开始播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(ScreenTimeChartCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当数据变化时重新播放动画
    if (oldWidget.dataPoints != widget.dataPoints ||
        oldWidget.totalHours != widget.totalHours ||
        oldWidget.totalMinutes != widget.totalMinutes) {
      _animationController.reset();
      _animationController.forward();
    }
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
      radius: BorderRadius.circular(24 * scale),
      padding: widget.size.getPadding(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 顶部区域：头像 + 时间
          _buildHeader(theme),
          SizedBox(height: widget.size.getTitleSpacing()),
          // 中间区域：图表
          Expanded(child: _buildChart(theme)),
          SizedBox(height: widget.size.getTitleSpacing() * 0.6),
        ],
      ),
    );

    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: panel,
      ),
    );
  }

  /// 构建头部区域
  Widget _buildHeader(AppThemeData theme) {
    final iconSize = widget.size.getIconSize();
    final containerSize = iconSize * widget.size.iconContainerScale;
    final smallSpacing = widget.size.getSmallSpacing();
    final valueFontSize = widget.size.getLargeFontSize() * 0.85;
    final scale = widget.size.scale;

    return Row(
      children: [
        // 头像：手绘圆框徽章（surfaceAlt 底 + 墨线描边）
        if (widget.avatarUrl != null)
          Container(
            width: containerSize,
            height: containerSize,
            decoration: dsSketchDecoration(
              theme: theme,
              radius: BorderRadius.circular(containerSize / 2),
              fillColor: theme.surfaceAlt,
            ),
            // 内缩留出墨线描边（描边贴容器真实边界）
            child: Padding(
              padding: EdgeInsets.all(1.5 * scale),
              child: ClipOval(
                child: Image.network(
                  widget.avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: theme.surfaceAlt,
                      alignment: Alignment.center,
                      child: WiredIcon(
                        icon: Icons.person,
                        size: iconSize * 0.8,
                        color: theme.textSub,
                        drawConfig: theme.wired.drawConfig,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        SizedBox(width: smallSpacing * 4),
        // 时间显示
        Text(
          '${widget.totalHours}h ${widget.totalMinutes}m',
          style: TextStyle(
            fontSize: valueFontSize * 0.7,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
            color: theme.text,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  /// 构建图表区域
  Widget _buildChart(AppThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final xLabelHeight = widget.size.getLegendFontSize() * 1.5;

        return SizedBox.expand(
          child: Stack(
            children: [
              // 背景网格线（限制在柱状图区域内）
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: xLabelHeight,
                child: _buildGridLines(theme),
              ),
              // 垂直虚线
              _buildVerticalDashedLines(theme),
              // 柱状图
              _buildBars(theme, constraints.maxHeight),
              // X轴标签
              _buildXAxisLabels(theme),
            ],
          ),
        );
      },
    );
  }

  /// 构建背景网格线
  Widget _buildGridLines(AppThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildGridLine(theme, '60m', Alignment.topRight),
        _buildGridLine(theme, '30m', Alignment.topRight),
        _buildGridLine(theme, '0m', Alignment.topRight),
      ],
    );
  }

  Widget _buildGridLine(AppThemeData theme, String label, Alignment alignment) {
    final legendFontSize = widget.size.getLegendFontSize();

    return Stack(
      children: [
        // 淡墨网格线
        Container(
          height: 1,
          color: theme.ink.withValues(alpha: 0.18),
        ),
        Align(
          alignment: alignment,
          child: Container(
            padding: EdgeInsets.only(left: widget.size.getSmallSpacing() * 2),
            color: theme.surface,
            child: Text(
              label,
              style: TextStyle(
                fontSize: legendFontSize,
                fontWeight: FontWeight.w500,
                color: theme.textSub,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建垂直虚线
  Widget _buildVerticalDashedLines(AppThemeData theme) {
    return Positioned.fill(
      child: Row(
        children: [
          _buildVerticalDashedLine(theme),
          Expanded(child: Container()),
          _buildVerticalDashedLine(theme),
        ],
      ),
    );
  }

  Widget _buildVerticalDashedLine(AppThemeData theme) {
    return Container(
      width: 1,
      color: theme.ink.withValues(alpha: 0.14),
    );
  }

  /// 构建柱状图
  Widget _buildBars(AppThemeData theme, double maxHeight) {
    final barWidth = widget.size.getBarWidth();
    final smallSpacing = widget.size.getSmallSpacing();
    final xLabelHeight = widget.size.getLegendFontSize() * 1.5;
    // Y 轴标签宽度（"60m" 等文字 + padding）
    final yAxisLabelWidth = widget.size.getLegendFontSize() * 3.5 + smallSpacing * 2;

    return Positioned(
      left: smallSpacing * 2,
      right: yAxisLabelWidth,
      bottom: xLabelHeight,
      height: maxHeight - xLabelHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.dataPoints.length, (index) {
          final dataPoint = widget.dataPoints[index];
          return _Bar(
            segments: dataPoint.segments,
            heightPercentage: dataPoint.heightPercentage,
            maxHeight: maxHeight - xLabelHeight,
            animation: _animation,
            index: index,
            size: widget.size,
            barWidth: barWidth,
          );
        }),
      ),
    );
  }

  /// 构建X轴标签
  Widget _buildXAxisLabels(AppThemeData theme) {
    final legendFontSize = widget.size.getLegendFontSize();
    final smallSpacing = widget.size.getSmallSpacing();
    final xLabelHeight = legendFontSize * 1.5;
    // Y 轴标签宽度（与柱状图保持一致）
    final yAxisLabelWidth = legendFontSize * 3.5 + smallSpacing * 2;

    return Positioned(
      left: smallSpacing * 2,
      right: yAxisLabelWidth,
      bottom: 0,
      height: xLabelHeight,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomLeft,
            child: Text('6 AM', style: _xLabelStyle(theme, legendFontSize)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Text('12 PM', style: _xLabelStyle(theme, legendFontSize)),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Text('6 PM', style: _xLabelStyle(theme, legendFontSize)),
          ),
        ],
      ),
    );
  }

  TextStyle _xLabelStyle(AppThemeData theme, double legendFontSize) {
    return TextStyle(
      fontSize: legendFontSize,
      fontWeight: FontWeight.w500,
      color: theme.textSub,
    );
  }
}

/// 单个柱状图条
///
/// AnimatedBuilder 逐帧驱动柱高生长；SizedBox 给紧宽高，
/// 防止无 child 的 CustomPaint 塌缩。
class _Bar extends StatelessWidget {
  final List<ScreenTimeSegment> segments;
  final double heightPercentage;
  final double maxHeight;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;
  final double barWidth;

  const _Bar({
    required this.segments,
    required this.heightPercentage,
    required this.maxHeight,
    required this.animation,
    required this.index,
    required this.size,
    required this.barWidth,
  });

  @override
  Widget build(BuildContext context) {
    // 计算每个柱子的动画区间，确保 start < end 且都在 [0, 1] 范围内
    final totalBars = 7; // 估计的最大柱子数量
    final animationDuration = 0.6; // 动画持续时间比例
    final startDelay = index / totalBars; // 每个柱子的起始延迟
    final start = startDelay.clamp(0.0, 0.9);
    final end = (startDelay + animationDuration / totalBars).clamp(0.1, 1.0);

    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        start,
        end,
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, _) {
        final barHeight = maxHeight * heightPercentage * itemAnimation.value;
        return SizedBox(
          width: barWidth,
          height: barHeight,
          child: barHeight > 0
              ? CustomPaint(
                  painter: _StripedStackedBarPainter(
                    segments: segments,
                    scale: size.scale,
                  ),
                )
              : null,
        );
      },
    );
  }
}

/// 分段类别对应的数据色（随数据走，非主题色）
Color _segmentColor(String category) {
  switch (category) {
    case 'blue':
      return const Color(0xFF007AFF);
    case 'teal':
      return const Color(0xFF5AC8FA);
    case 'orange':
      return const Color(0xFFFF9500);
    case 'gray':
    default:
      return const Color(0xFF98989D);
  }
}

/// 斜纹堆叠柱绘制器
///
/// 各分段（按 segments 顺序自底向上）铺数据色浅底（0.28）+
/// 数据色斜纹（0.9）+ 数据色描边（0.85），
/// 首段底 / 尾段顶胶囊圆角；柱高由外层 SizedBox 随动画撑起。
class _StripedStackedBarPainter extends CustomPainter {
  final List<ScreenTimeSegment> segments;
  final double scale;

  const _StripedStackedBarPainter({
    required this.segments,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || segments.isEmpty) return;
    final capsule = Radius.circular(size.width / 2);
    var y = size.height;
    for (var i = 0; i < segments.length; i++) {
      final height = size.height * segments[i].percentage;
      y -= height;
      if (height > 0.5) {
        final rect = Rect.fromLTWH(0, y, size.width, height);
        final isBottom = i == 0;
        final isTop = i == segments.length - 1;
        final rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: isTop ? capsule : Radius.zero,
          topRight: isTop ? capsule : Radius.zero,
          bottomLeft: isBottom ? capsule : Radius.zero,
          bottomRight: isBottom ? capsule : Radius.zero,
        );
        final color = _segmentColor(segments[i].category);
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
    }
  }

  @override
  bool shouldRepaint(covariant _StripedStackedBarPainter oldDelegate) {
    return oldDelegate.segments != segments || oldDelegate.scale != scale;
  }
}
