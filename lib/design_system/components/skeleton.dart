import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// 果冻骨架屏：呼吸式透明度脉冲，加载占位用
class DSSkeleton extends StatefulWidget {
  const DSSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.circle = false,
    this.color,
  });

  /// 为 null 时占满可用宽度
  final double? width;
  final double height;

  /// 圆形（头像占位）
  final bool circle;
  final Color? color;

  @override
  State<DSSkeleton> createState() => _DSSkeletonState();
}

class _DSSkeletonState extends State<DSSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.4,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final base = widget.color ?? theme.surfaceAlt;

    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: widget.circle
            ? (widget.width ?? widget.height * 2)
            : widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              widget.circle ? null : BorderRadius.circular(widget.height),
        ),
      ),
    );
  }
}

/// 骨架屏组合：头像 + 三行文本（列表项加载占位）
class DSSkeletonListItem extends StatelessWidget {
  const DSSkeletonListItem({super.key, this.height = 64});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.radii.lg,
        border: Border.all(color: theme.stroke, width: 1.4),
        boxShadow: theme.shadows.soft,
      ),
      child: Row(
        children: [
          const DSSkeleton(width: 40, height: 40, circle: true),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DSSkeleton(width: double.infinity),
                SizedBox(height: theme.spacing.sm),
                const DSSkeleton(width: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
