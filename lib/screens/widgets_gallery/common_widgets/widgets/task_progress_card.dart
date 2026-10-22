/// 任务进度卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 / 斜纹进度条（主题色浅底 + 斜纹 + 描边，轨道淡墨斜纹）/
/// 待办列表（墨线分隔线）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 任务进度卡片小组件
class TaskProgressCardWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final int completedTasks;
  final int totalTasks;
  final List<String> pendingTasks;

  /// 进度标签（默认"进度"）
  final String progressLabel;

  /// 待办列表标签（默认"待办"）
  final String pendingLabel;

  /// 最大显示待办数量（null表示显示全部）
  final int? maxPendingTasks;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const TaskProgressCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.completedTasks,
    required this.totalTasks,
    this.pendingTasks = const [],
    this.progressLabel = '进度',
    this.pendingLabel = '待办',
    this.maxPendingTasks,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory TaskProgressCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return TaskProgressCardWidget(
      title: props['title'] as String? ?? '',
      subtitle: props['subtitle'] as String? ?? '',
      completedTasks: props['completedTasks'] as int? ?? 0,
      totalTasks: props['totalTasks'] as int? ?? 0,
      pendingTasks:
          (props['pendingTasks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      progressLabel: props['progressLabel'] as String? ?? '进度',
      pendingLabel: props['pendingLabel'] as String? ?? '待办',
      maxPendingTasks: props['maxPendingTasks'] as int?,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<TaskProgressCardWidget> createState() => _TaskProgressCardWidgetState();
}

class _TaskProgressCardWidgetState extends State<TaskProgressCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : null,
        height: widget.inline ? double.maxFinite : null,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题部分
            _buildHeaderSection(theme),

            SizedBox(height: widget.size.getTitleSpacing()),

            // 进度条部分
            _buildProgressSection(theme),

            if (widget.pendingTasks.isNotEmpty) ...[
              SizedBox(height: widget.size.getTitleSpacing()),
              // 待办任务列表
              Expanded(child: _buildPendingTasksSection(theme)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            fontSize: widget.size.getTitleFontSize(),
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.subtitle.isNotEmpty)
          Text(
            widget.subtitle,
            style: TextStyle(
              fontSize: widget.size.getLegendFontSize(),
              fontWeight: FontWeight.w500,
              color: theme.textSub,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildProgressSection(AppThemeData theme) {
    final progress =
        widget.totalTasks > 0
            ? widget.completedTasks / widget.totalTasks
            : 0.0;
    final legendFontSize = widget.size.getLegendFontSize();
    final iconSize = widget.size.getIconSize() * 0.6;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                DsIcon(DsIconKind.list, size: iconSize, color: theme.textSub),
                SizedBox(width: widget.size.getSmallSpacing()),
                Text(
                  widget.progressLabel,
                  style: TextStyle(
                    fontSize: legendFontSize,
                    fontWeight: FontWeight.w500,
                    color: theme.textSub,
                  ),
                ),
              ],
            ),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Row(
                  children: [
                    SizedBox(
                      width: legendFontSize * 2,
                      height: legendFontSize * 1.3,
                      child: AnimatedFlipCounter(
                        value: widget.completedTasks.toDouble() * _animation.value,
                        fractionDigits: 0,
                        textStyle: TextStyle(
                          fontSize: legendFontSize,
                          fontWeight: FontWeight.w500,
                          color: theme.textSub,
                        ),
                      ),
                    ),
                    Text(
                      ' / ',
                      style: TextStyle(
                        fontSize: legendFontSize,
                        color: theme.textSub,
                      ),
                    ),
                    SizedBox(
                      width: legendFontSize * 2,
                      height: legendFontSize * 1.3,
                      child: AnimatedFlipCounter(
                        value: widget.totalTasks.toDouble(),
                        fractionDigits: 0,
                        textStyle: TextStyle(
                          fontSize: legendFontSize,
                          fontWeight: FontWeight.w500,
                          color: theme.textSub,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        SizedBox(height: widget.size.getItemSpacing()),
        // 斜纹进度条：数据区主题色浅底 + 斜纹 + 描边，轨道淡墨斜纹
        SizedBox(
          height: widget.size.getLegendIndicatorHeight(),
          width: double.infinity,
          child: CustomPaint(
            painter: _StripedProgressBarPainter(
              theme: theme,
              scale: widget.size.scale,
              color: theme.primary,
              progress: progress,
              animation: _animation,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingTasksSection(AppThemeData theme) {
    final tasks =
        widget.maxPendingTasks == null
            ? widget.pendingTasks
            : widget.pendingTasks.take(widget.maxPendingTasks!).toList();
    final legendFontSize = widget.size.getLegendFontSize();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: widget.size.getSmallSpacing()),
          child: Text(
            widget.pendingLabel,
            style: TextStyle(
              fontSize: legendFontSize,
              fontWeight: FontWeight.w500,
              color: theme.textSub,
            ),
          ),
        ),
        Expanded(
          child: Scrollbar(
            thickness: 4,
            radius: const Radius.circular(2),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < tasks.length; i++) ...[
                    if (i > 0)
                      Container(height: 1, color: theme.ink.withValues(alpha: 0.18)),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: widget.size.getSmallSpacing(),
                      ),
                      child: Text(
                        tasks[i],
                        style: TextStyle(
                          fontSize: legendFontSize,
                          fontWeight: FontWeight.w500,
                          color: theme.text,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 斜纹进度条绘制器（§9.5 标准纹样）
///
/// 胶囊轨道：surfaceAlt 底 + 淡墨斜纹（0.28）+ 淡墨描边（0.45）；
/// 数据区：数据色浅底（0.28）+ 数据色斜纹（0.9）+ 数据色描边（0.85）。
class _StripedProgressBarPainter extends CustomPainter {
  final AppThemeData theme;
  final double scale;

  /// 数据色
  final Color color;

  /// 目标占比（0-1）
  final double progress;

  /// 入场动画（null = 已完成，直接全画）
  final Animation<double>? animation;

  _StripedProgressBarPainter({
    required this.theme,
    required this.scale,
    required this.color,
    required this.progress,
    this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final fraction = (progress * (animation?.value ?? 1)).clamp(0.0, 1.0);
    final bounds = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(size.height / 2),
    );

    canvas.save();
    canvas.clipRRect(rrect);
    // 轨道：浅底 + 淡墨斜纹
    canvas.drawRect(bounds, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      Path()..addRect(bounds),
      bounds,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    // 数据区：浅底 + 浓斜纹 + 描边
    if (fraction > 0) {
      final rect = Rect.fromLTWH(0, 0, size.width * fraction, size.height);
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.28));
      paintDiagonalStripes(
        canvas,
        Path()..addRect(rect),
        rect,
        color: color.withValues(alpha: 0.9),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }
    canvas.restore();

    // 外框淡墨描边
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _StripedProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}
