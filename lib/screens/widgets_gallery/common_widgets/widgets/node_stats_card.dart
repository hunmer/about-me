/// 节点统计卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 2x2 统计小卡（分类色浅底 + 墨线描边、翻牌计数错峰生长）
/// / 完成率 9.5 斜纹进度条（数据色浓纹 + 轨道淡墨纹）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 节点统计卡片小组件
///
/// 显示节点统计信息（总数、待办、进行中、已完成）
class NodeStatsCardWidget extends StatefulWidget {
  /// 节点总数
  final int totalNodes;

  /// 待办节点数
  final int todoNodes;

  /// 进行中节点数
  final int doingNodes;

  /// 已完成节点数
  final int doneNodes;

  /// 完成率
  final double completedRate;

  /// 是否为内联模式
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const NodeStatsCardWidget({
    super.key,
    required this.totalNodes,
    required this.todoNodes,
    required this.doingNodes,
    required this.doneNodes,
    required this.completedRate,
    this.inline = false,
    this.size = const LargeSize(),
  });

  /// 从 props 创建实例
  factory NodeStatsCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    // 从 props 中读取 size，如果不存在则使用传入的 size 参数
    HomeWidgetSize widgetSize = size;
    if (props['size'] != null) {
      widgetSize = HomeWidgetSize.fromJson(
        props['size'] as Map<String, dynamic>,
      );
    }

    return NodeStatsCardWidget(
      totalNodes: props['totalNodes'] as int? ?? 0,
      todoNodes: props['todoNodes'] as int? ?? 0,
      doingNodes: props['doingNodes'] as int? ?? 0,
      doneNodes: props['doneNodes'] as int? ?? 0,
      completedRate: (props['completedRate'] as num?)?.toDouble() ?? 0.0,
      inline: props['inline'] as bool? ?? false,
      size: widgetSize,
    );
  }

  @override
  State<NodeStatsCardWidget> createState() => _NodeStatsCardWidgetState();
}

class _NodeStatsCardWidgetState extends State<NodeStatsCardWidget>
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

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          width: widget.inline ? double.maxFinite : null,
          height: widget.inline ? double.maxFinite : null,
          radius: BorderRadius.circular(24 * scale),
          padding: widget.size.getPadding(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Padding(
                padding: EdgeInsets.only(
                  bottom: widget.size.getItemSpacing() * 0.5,
                ),
                child: Text(
                  '节点统计',
                  style: TextStyle(
                    fontSize: widget.size.getSubtitleFontSize(),
                    fontWeight: FontWeight.w600,
                    color: theme.text,
                  ),
                ),
              ),
              // 统计卡片网格
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 2.0,
                  mainAxisSpacing: widget.size.getItemSpacing() * 0.5,
                  crossAxisSpacing: widget.size.getItemSpacing() * 0.5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStatCard(
                      theme,
                      label: '总节点',
                      value: widget.totalNodes,
                      color: theme.primary,
                    ),
                    _buildStatCard(
                      theme,
                      label: '待办',
                      value: widget.todoNodes,
                      color: theme.warning,
                    ),
                    _buildStatCard(
                      theme,
                      label: '进行中',
                      value: widget.doingNodes,
                      color: theme.secondary,
                    ),
                    _buildStatCard(
                      theme,
                      label: '已完成',
                      value: widget.doneNodes,
                      color: theme.success,
                    ),
                  ],
                ),
              ),
              SizedBox(height: widget.size.getItemSpacing() * 0.5),
              // 完成率进度条
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '完成率',
                      style: TextStyle(
                        fontSize: widget.size.getSubtitleFontSize() * 0.8,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                  SizedBox(width: widget.size.getItemSpacing() * 0.5),
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final rate = widget.completedRate * _animation.value;
                      return Text(
                        '${rate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: widget.size.getSubtitleFontSize(),
                          fontWeight: FontWeight.w600,
                          color: theme.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: widget.size.getItemSpacing() * 0.3),
              // 9.5 斜纹进度条（与百分比文字同步生长）
              AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  final progress =
                      (widget.completedRate / 100).clamp(0.0, 1.0) *
                      _animation.value;
                  return SizedBox(
                    height: 8 * scale,
                    width: double.maxFinite,
                    child: CustomPaint(
                      painter: _StripedProgressPainter(
                        progress: progress,
                        dataColor: theme.primary,
                        theme: theme,
                        scale: scale,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    AppThemeData theme, {
    required String label,
    required int value,
    required Color color,
  }) {
    final scale = widget.size.scale;
    // 分类色浅底 + 墨线描边（小控件档）
    return Container(
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(10 * scale),
        fillColor: color.withValues(alpha: 0.10),
      ),
      padding: EdgeInsets.all(widget.size.getItemSpacing()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: widget.size.getSubtitleFontSize() * 0.8,
              color: theme.textSub,
            ),
          ),
          SizedBox(height: widget.size.getItemSpacing() * 0.3),
          AnimatedFlipCounter(
            value: value.toDouble() * _animation.value,
            textStyle: TextStyle(
              fontSize: widget.size.getLargeFontSize() * 0.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 9.5 斜纹进度条：进度段数据色浅底 0.28 + 浓斜纹 0.9 + 描边 0.85；
/// 轨道 surfaceAlt 底 + 淡墨斜纹 0.28 + 淡墨描边 0.45
class _StripedProgressPainter extends CustomPainter {
  final double progress;
  final Color dataColor;
  final AppThemeData theme;
  final double scale;

  const _StripedProgressPainter({
    required this.progress,
    required this.dataColor,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = Radius.circular(size.height / 2);
    final trackRect = Offset.zero & size;
    final track = RRect.fromRectAndRadius(trackRect, radius);

    // 轨道
    canvas.drawRRect(track, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(track),
      trackRect,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      track,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    // 进度段
    if (progress <= 0) return;
    final fillWidth = (trackRect.width * progress)
        .clamp(size.height, trackRect.width);
    final fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);
    final fill = RRect.fromRectAndRadius(fillRect, radius);
    canvas.drawRRect(fill, Paint()..color = dataColor.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(fill),
      fillRect,
      color: dataColor.withValues(alpha: 0.9),
      strokeWidth: 3 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      fill,
      Paint()
        ..color = dataColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _StripedProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.dataColor != dataColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}
