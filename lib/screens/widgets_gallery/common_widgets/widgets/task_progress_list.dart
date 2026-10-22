/// 任务进度列表小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘图标 + 标题 / 任务进度列表（数据色迷你斜纹进度条、逐项错峰浮现）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 任务进度数据模型
class TaskProgressData {
  final String title;
  final String time;
  final double progress;
  final Color color;

  const TaskProgressData({
    required this.title,
    required this.time,
    required this.progress,
    required this.color,
  });

  factory TaskProgressData.fromJson(Map<String, dynamic> json) {
    return TaskProgressData(
      title: json['title'] as String? ?? '',
      time: json['time'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      color: Color(json['color'] as int? ?? 0xFF000000),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'time': time,
      'progress': progress,
      'color': color.value,
    };
  }
}

/// 任务进度列表小组件
class TaskProgressListWidget extends StatefulWidget {
  final List<TaskProgressData> tasks;
  final int moreCount;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const TaskProgressListWidget({
    super.key,
    required this.tasks,
    this.moreCount = 0,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory TaskProgressListWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final tasksList = (props['tasks'] as List<dynamic>?)
            ?.map((e) => TaskProgressData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return TaskProgressListWidget(
      tasks: tasksList,
      moreCount: props['moreCount'] as int? ?? 0,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<TaskProgressListWidget> createState() => _TaskProgressListWidgetState();
}

class _TaskProgressListWidgetState extends State<TaskProgressListWidget>
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
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 360,
        height: widget.inline ? double.maxFinite : null,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Row(
              children: [
                WiredIcon(
                  icon: Icons.check_circle_outline,
                  size: 20 * scale,
                  color: theme.textSub,
                  drawConfig: theme.wired.drawConfig,
                ),
                const SizedBox(width: 8),
                Text(
                  'Progress',
                  style: TextStyle(
                    color: theme.textSub,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 任务列表 - 添加滚动支持
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(
                      widget.tasks.length,
                      (index) => _TaskProgressItem(
                        task: widget.tasks[index],
                        animation: _animation,
                        index: index,
                        isLast: index == widget.tasks.length - 1,
                        size: widget.size,
                      ),
                    ),
                    // 更多链接
                    if (widget.moreCount > 0) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          '+${widget.moreCount} more',
                          style: TextStyle(
                            color: theme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 任务进度项组件（数据色迷你斜纹进度条，逐项错峰浮现）
class _TaskProgressItem extends StatelessWidget {
  final TaskProgressData task;
  final Animation<double> animation;
  final int index;
  final bool isLast;
  final HomeWidgetSize size;

  const _TaskProgressItem({
    required this.task,
    required this.animation,
    required this.index,
    required this.isLast,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 计算每个元素的延迟动画，确保 end <= 1.0
    final start = index * 0.12;
    final end = (0.6 + index * 0.12).clamp(0.0, 1.0);
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        start,
        end,
        curve: Curves.easeOutCubic,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: itemAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: itemAnimation.value,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - itemAnimation.value)),
                child: Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 20,
                            child: Text(
                              task.title,
                              style: TextStyle(
                                color: theme.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 16,
                            child: Text(
                              task.time,
                              style: TextStyle(
                                color: theme.textSub,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 迷你斜纹进度条（数据色斜纹 + 淡墨轨道）
                    SizedBox(
                      width: 48,
                      height: 6,
                      child: CustomPaint(
                        painter: _MiniStripedBarPainter(
                          theme: theme,
                          scale: size.scale,
                          color: task.color,
                          progress: task.progress.clamp(0.0, 1.0),
                          animation: itemAnimation,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (!isLast) ...[
          SizedBox(height: size.getItemSpacing()),
          // 墨线分隔线
          Container(height: 1, color: theme.ink.withValues(alpha: 0.18)),
          SizedBox(height: size.getItemSpacing()),
        ],
      ],
    );
  }
}

/// 迷你斜纹进度条绘制器（§9.5 标准纹样）
///
/// 胶囊轨道：surfaceAlt 底 + 淡墨斜纹（0.28）+ 淡墨描边（0.45）；
/// 数据区：数据色浅底（0.28）+ 数据色斜纹（0.9）+ 数据色描边（0.85）。
class _MiniStripedBarPainter extends CustomPainter {
  final AppThemeData theme;
  final double scale;

  /// 数据色
  final Color color;

  /// 目标占比（0-1）
  final double progress;

  /// 入场动画（null = 已完成，直接全画）
  final Animation<double>? animation;

  _MiniStripedBarPainter({
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
  bool shouldRepaint(covariant _MiniStripedBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}
