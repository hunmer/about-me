import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// 手绘骨架屏：呼吸式透明度脉冲，加载占位用
class DSSkeleton extends StatefulWidget {
  const DSSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.circle = false,
    this.color,
    this.radius,
  });

  /// 为 null 时占满可用宽度
  final double? width;
  final double height;

  /// 圆形（头像占位）
  final bool circle;
  final Color? color;

  /// 覆盖圆角（默认按高度取胶囊圆角）
  final BorderRadiusGeometry? radius;

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
          borderRadius: widget.circle
              ? null
              : (widget.radius ?? BorderRadius.circular(widget.height)),
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
    // 手绘白卡：纸色实底 + 淡墨描边（无阴影）
    return Container(
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: theme.radii.lg,
        stroke: theme.ink.withValues(alpha: 0.5),
        strokeWidth: 1.4,
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
