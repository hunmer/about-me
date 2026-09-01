import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 渲染图标，支持 emoji 字符串和 MaterialIcons codePoint
Widget _renderIcon(String icon, {double size = 28}) {
  // 尝试解析为 MaterialIcons codePoint
  final codePoint = int.tryParse(icon);
  if (codePoint != null) {
    return Icon(IconData(codePoint, fontFamily: 'MaterialIcons'), size: size);
  }
  // 否则作为普通 emoji 字符串处理
  return Text(icon, style: TextStyle(fontSize: size));
}

/// 指标进度数据模型
class MetricProgressData {
  /// 图标（支持 MaterialIcons codePoint 字符串或 emoji 字符串）
  /// 例如：'58352'（MaterialIcons.codePoint）或 '🏃'（emoji）
  final String emoji;

  /// 进度值 0-100
  final double progress;

  /// 进度条颜色
  final Color progressColor;

  /// 标题
  final String title;

  /// 副标题
  final String subtitle;

  /// 数值
  final double value;

  /// 单位
  final String unit;

  const MetricProgressData({
    required this.emoji,
    required this.progress,
    required this.progressColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
  });

  /// 从 JSON 创建（用于公共小组件系统）
  factory MetricProgressData.fromJson(Map<String, dynamic> json) {
    return MetricProgressData(
      emoji: json['emoji'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      progressColor: Color(json['progressColor'] as int? ?? 0xFF000000),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
    );
  }

  /// 转换为 JSON（用于公共小组件系统）
  Map<String, dynamic> toJson() {
    return {
      'emoji': emoji,
      'progress': progress,
      'progressColor': progressColor.value,
      'title': title,
      'subtitle': subtitle,
      'value': value,
      'unit': unit,
    };
  }
}

/// 多指标进度卡片小组件
class MultiMetricProgressCardWidget extends StatefulWidget {
  /// 追踪器数据列表
  final List<MetricProgressData> trackers;

  /// 卡片背景色
  final Color? backgroundColor;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const MultiMetricProgressCardWidget({
    super.key,
    required this.trackers,
    this.backgroundColor,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory MultiMetricProgressCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final trackersList =
        (props['trackers'] as List<dynamic>?)
            ?.map((e) => MetricProgressData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final bgColorInt = props['backgroundColor'] as int?;
    final bgColor = bgColorInt != null ? Color(bgColorInt) : null;

    return MultiMetricProgressCardWidget(
      trackers: trackersList,
      backgroundColor: bgColor,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<MultiMetricProgressCardWidget> createState() =>
      _MultiMetricProgressCardWidgetState();
}

class _MultiMetricProgressCardWidgetState
    extends State<MultiMetricProgressCardWidget>
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
    final theme = Theme.of(context);
    final bgColor =
        widget.backgroundColor ?? theme.colorScheme.primary.withOpacity(0.85);

    return Container(
      width: widget.inline ? double.maxFinite : 380,
      height: widget.inline ? double.maxFinite : 380,
      constraints: widget.inline ? null : const BoxConstraints(minWidth: 280),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white.withOpacity(0.1), Colors.transparent],
                  ),
                ),
              ),
            ),
            // 追踪器列表
            Padding(
              padding: widget.size.getPadding(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 350),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < widget.trackers.length; i++) ...[
                        if (i > 0)
                          SizedBox(height: widget.size.getItemSpacing()),
                        _MetricProgressItem(
                          data: widget.trackers[i],
                          animation: _animation,
                          index: i,
                          size: widget.size,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个指标进度项
class _MetricProgressItem extends StatelessWidget {
  final MetricProgressData data;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _MetricProgressItem({
    required this.data,
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // 为每个项目添加延迟动画
        final end = (0.6 + index * 0.15).clamp(0.0, 1.0);
        final itemAnimation = CurvedAnimation(
          parent: animation,
          curve: Interval(index * 0.15, end, curve: Curves.easeOutCubic),
        );

        return Opacity(
          opacity: itemAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - itemAnimation.value)),
            child: Row(
              children: [
                // 带进度条的图标
                _IconWithProgress(
                  emoji: data.emoji,
                  progress: data.progress,
                  progressColor: data.progressColor,
                  animation: itemAnimation,
                  size: size,
                ),
                SizedBox(width: size.getSmallSpacing() * 4),
                // 标题和副标题
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size.getTitleFontSize() * 0.55,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: size.getSmallSpacing()),
                      Text(
                        data.subtitle,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: size.getSubtitleFontSize() * 0.75,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // 数值和单位
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedFlipCounter(
                      value: data.value * itemAnimation.value,
                      fractionDigits: data.value % 1 != 0 ? 2 : 0,
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: size.getTitleFontSize() * 0.8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(height: size.getSmallSpacing()),
                    Text(
                      data.unit,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: size.getSubtitleFontSize() * 0.75,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 带进度条的图标
class _IconWithProgress extends StatelessWidget {
  final String emoji;
  final double progress;
  final Color progressColor;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _IconWithProgress({
    required this.emoji,
    required this.progress,
    required this.progressColor,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size.getIconSize();
    final containerSize = iconSize * size.iconContainerScale;
    final strokeWidth = size.getStrokeWidth() * size.progressStrokeScale;

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _CircularProgressPainter(
              progress: progress / 100 * animation.value,
              progressColor: progressColor,
              backgroundColor: Colors.white.withOpacity(0.2),
              strokeWidth: strokeWidth,
            ),
            child: Center(child: _renderIcon(emoji, size: iconSize)),
          );
        },
      ),
    );
  }
}

/// 圆形进度条绘制器
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    this.strokeWidth = 3.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth; // 确保圆环不超出容器

    // 背景圆环
    final backgroundPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // 进度圆弧
    if (progress > 0) {
      final progressPaint =
          Paint()
            ..color = progressColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round;

      const startAngle = -90 * 3.14159 / 180; // 从顶部开始
      final sweepAngle = 2 * 3.14159 * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
