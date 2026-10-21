import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/motion.dart';

/// 手绘骨架屏：呼吸式透明度脉冲 + 斜向流光扫过，加载占位用
///
/// 动效减弱（context.dsAnimationsDisabled）时两者都停，只保留静态骨块。
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

class _DSSkeletonState extends State<DSSkeleton> with TickerProviderStateMixin {
  late final AnimationController _breathe;
  late final AnimationController _shimmer;

  /// 呼吸周期（原有节奏不变）
  static const Duration _breatheDuration = Duration(milliseconds: 1100);

  /// 流光扫过周期（长循环动效，超出 DsMotion 过渡档位的时长）
  static const Duration _shimmerDuration = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: _breatheDuration,
      lowerBound: 0.4,
      upperBound: 1.0,
    );
    _shimmer = AnimationController(vsync: this, duration: _shimmerDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 动效减弱：全部停表退化静态骨块；恢复后自动续跑
    final disabled = context.dsAnimationsDisabled;
    if (disabled) {
      _breathe.stop();
      _shimmer.stop();
    } else {
      if (!_breathe.isAnimating) _breathe.repeat(reverse: true);
      if (!_shimmer.isAnimating) _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final base = widget.color ?? theme.surfaceAlt;

    final bone = Container(
      width: widget.circle ? (widget.width ?? widget.height * 2) : widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: base,
        shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: widget.circle
            ? null
            : (widget.radius ?? BorderRadius.circular(widget.height)),
      ),
    );

    if (context.dsAnimationsDisabled) return bone;

    // 呼吸（整体透明度）+ 流光（骨块形状内斜向高光带扫过）
    return FadeTransition(
      opacity: _breathe,
      child: CustomPaint(
        foregroundPainter: _ShimmerPainter(
          progress: _shimmer.value,
          color: DsColors.white,
          circle: widget.circle,
          radius: widget.radius?.resolve(Directionality.maybeOf(context)),
        ),
        child: bone,
      ),
    );
  }
}

/// 骨块流光：宽约 40%、45° 斜向白色渐变高光带（0 → 0.35 → 0 峰值）
/// 从左扫到右循环；裁剪在骨块形状（圆/圆角矩形）内
class _ShimmerPainter extends CustomPainter {
  const _ShimmerPainter({
    required this.progress,
    required this.color,
    required this.circle,
    this.radius,
  });

  /// 扫过进度 0.0 ~ 1.0
  final double progress;
  final Color color;
  final bool circle;
  final BorderRadius? radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    // 先裁剪到骨块形状，高光带不溢出
    if (circle) {
      canvas.clipPath(Path()..addOval(Offset.zero & size));
    } else if (radius != null) {
      canvas.clipRRect(radius!.toRRect(Offset.zero & size));
    } else {
      canvas.clipRect(Offset.zero & size);
    }

    // 旋转 45° 后画竖直渐变带，得到斜向高光
    final center = size.center(Offset.zero);
    canvas
      ..translate(center.dx, center.dy)
      ..rotate(math.pi / 4)
      ..translate(-center.dx, -center.dy);

    final bandWidth = size.width * 0.4;
    // 对角线长度（行程覆盖旋转后的范围：完全进入前 → 完全离开后）
    final diag = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final span = diag / 2 + bandWidth;
    final dx = -span + span * 2 * progress;

    final shader =
        LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(
          Offset(dx - bandWidth / 2, 0) & Size(bandWidth, diag * 2),
        );
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: diag * 3,
        height: diag * 3,
      ),
      Paint()..shader = shader,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.circle != circle ||
      oldDelegate.radius != radius;
}

/// 骨架屏组合：段落多行文本（末行 60% 宽）
class SkeletonParagraph extends StatelessWidget {
  const SkeletonParagraph({super.key, this.lines = 3});

  /// 行数（末行为短行）
  final int lines;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) SizedBox(height: theme.spacing.sm),
          if (i == lines - 1)
            FractionallySizedBox(
              widthFactor: 0.6,
              child: const DSSkeleton(width: double.infinity),
            )
          else
            const DSSkeleton(width: double.infinity),
        ],
      ],
    );
  }
}

/// 骨架屏组合：按钮占位（胶囊形，高 44）
class SkeletonButton extends StatelessWidget {
  const SkeletonButton({super.key, this.width = 120, this.height = 44});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // 默认圆角按高度取胶囊
    return DSSkeleton(width: width, height: height);
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
