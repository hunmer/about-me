/// 每日反思卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 星期几 + 蝴蝶装饰插画（保留）/ 中央引导性问题（逐项浮现）/
/// 数据色墨线按钮组（New / Sync，逐项错峰浮现）。
/// darkBackgroundColor 为旧深色卡字段，仅为 props 兼容保留。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import '../models/daily_reflection_card_data.dart';

/// 每日反思卡片小组件
///
/// 一个引导用户每日思考和记录的卡片组件，包含：
/// - 星期几显示
/// - 引导性问题文本
/// - 新建和同步操作按钮
/// - 蝴蝶装饰图标
class DailyReflectionCardWidget extends StatefulWidget {
  /// 星期几标签
  final String dayOfWeek;

  /// 引导性问题
  final String question;

  /// 卡片背景色（深色模式）——旧深色卡字段，仅为 props 兼容保留
  final Color? darkBackgroundColor;

  /// 主色调（按钮颜色）
  final Color? primaryColor;

  /// 卡片大小（用于自适应）
  final HomeWidgetSize size;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  const DailyReflectionCardWidget({
    super.key,
    required this.dayOfWeek,
    required this.question,
    this.darkBackgroundColor,
    this.primaryColor,
    this.size = const MediumSize(),
    this.inline = false,
  });

  /// 从 props 创建
  factory DailyReflectionCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final data = props['data'] is DailyReflectionCardData
        ? props['data'] as DailyReflectionCardData
        : DailyReflectionCardData.fromJson(props['data'] as Map<String, dynamic>? ?? {});

    return DailyReflectionCardWidget(
      dayOfWeek: data.dayOfWeek,
      question: data.question,
      darkBackgroundColor: data.darkBackgroundColor != null
          ? Color(data.darkBackgroundColor!)
          : null,
      primaryColor: data.primaryColor != null
          ? Color(data.primaryColor!)
          : null,
      size: size,
      inline: props['inline'] as bool? ?? false,
    );
  }

  @override
  State<DailyReflectionCardWidget> createState() =>
      _DailyReflectionCardWidgetState();
}

class _DailyReflectionCardWidgetState extends State<DailyReflectionCardWidget>
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

    // 主色调（数据色 props，缺省回落主题色）
    final primaryColor = widget.primaryColor ?? theme.primary;

    // 悬停颜色
    final hoverColor = primaryColor.withValues(alpha: 0.8);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : widget.size.width * 80.0 + 100,
        height: widget.inline ? double.maxFinite : widget.size.height * 80.0 + 100,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部行：星期几 + 蝴蝶图标
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.dayOfWeek,
                  style: TextStyle(
                    color: theme.textSub,
                    fontSize: widget.size.getSubtitleFontSize(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _ButterflyIcon(animation: _animation, size: widget.size.width == 1 ? 24 : 32),
              ],
            ),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 中间：引导性问题
            Expanded(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    widget.question,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: widget.size.getLargeFontSize() - 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 底部：按钮组
            _ButtonGroup(
              animation: _animation,
              primaryColor: primaryColor,
              hoverColor: hoverColor,
              size: widget.size,
            ),
          ],
        ),
      ),
    );
  }
}

/// 蝴蝶装饰图标
class _ButterflyIcon extends StatelessWidget {
  final Animation<double> animation;
  final double size;

  const _ButterflyIcon({required this.animation, required this.size});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _ButterflyPainter()),
      ),
    );
  }
}

/// 蝴蝶绘制器
class _ButterflyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 24;

    // 左翅膀（紫色渐变）
    final leftWingPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx - 8 * scale, center.dy - 4 * scale)
      ..lineTo(center.dx - 7 * scale, center.dy)
      ..lineTo(center.dx - 7 * scale, center.dy + 3 * scale)
      ..close();

    final leftWingGradient = LinearGradient(
      colors: [const Color(0xFF818CF8), const Color(0xFFC084FC)],
    ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));

    canvas.drawPath(leftWingPath, Paint()..shader = leftWingGradient);

    // 右翅膀（橙红色渐变）
    final rightWingPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx + 8 * scale, center.dy - 4 * scale)
      ..lineTo(center.dx + 7 * scale, center.dy)
      ..lineTo(center.dx + 7 * scale, center.dy + 3 * scale)
      ..close();

    final rightWingGradient = LinearGradient(
      colors: [const Color(0xFFF87171), const Color(0xFFFB923C)],
    ).createShader(Rect.fromCircle(center: center, radius: size.width / 2));

    canvas.drawPath(rightWingPath, Paint()..shader = rightWingGradient);

    // 左下翼（浅紫色）
    final leftLowerPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx - 7 * scale, center.dy + 5 * scale)
      ..lineTo(center.dx - 6 * scale, center.dy + 3 * scale)
      ..close();

    canvas.drawPath(leftLowerPath, Paint()..color = const Color(0xFFA5B4FC));

    // 右下翼（浅粉色）
    final rightLowerPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx + 7 * scale, center.dy + 5 * scale)
      ..lineTo(center.dx + 6 * scale, center.dy + 3 * scale)
      ..close();

    canvas.drawPath(rightLowerPath, Paint()..color = const Color(0xFFFCA5A5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 按钮组
class _ButtonGroup extends StatelessWidget {
  final Animation<double> animation;
  final Color primaryColor;
  final Color hoverColor;
  final HomeWidgetSize size;

  const _ButtonGroup({
    required this.animation,
    required this.primaryColor,
    required this.hoverColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // New 按钮
        Expanded(
          child: _AnimatedButton(
            animation: animation,
            index: 0,
            color: primaryColor,
            hoverColor: hoverColor,
            icon: Icons.edit_note,
            label: 'New',
            onTap: () {
              // TODO: 处理新建操作
            },
            size: size,
          ),
        ),
        SizedBox(width: size.getItemSpacing()),
        // Sync 按钮
        _AnimatedButton(
          animation: animation,
          index: 1,
          color: primaryColor,
          hoverColor: hoverColor,
          icon: Icons.sync,
          isIconOnly: true,
          onTap: () {
            // TODO: 处理同步操作
          },
          size: size,
        ),
      ],
    );
  }
}

/// 动画按钮
class _AnimatedButton extends StatefulWidget {
  final Animation<double> animation;
  final int index;
  final Color color;
  final Color hoverColor;
  final IconData icon;
  final String? label;
  final bool isIconOnly;
  final VoidCallback onTap;
  final HomeWidgetSize size;

  const _AnimatedButton({
    required this.animation,
    required this.index,
    required this.color,
    required this.hoverColor,
    required this.icon,
    this.label,
    this.isIconOnly = false,
    required this.onTap,
    required this.size,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 计算延迟动画
    final step = 0.1;
    final itemAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: Interval(
        widget.index * step,
        0.6 + widget.index * step,
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + 0.2 * itemAnimation.value,
          child: Opacity(opacity: itemAnimation.value, child: child),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 56,
            width: 80,
            // 胶囊徽章：数据色实底 + 墨线描边（大圆角被 rough 引擎钳成胶囊）
            decoration: dsSketchDecoration(
              theme: theme,
              radius: BorderRadius.circular(28),
              fillColor: _isHovered ? widget.hoverColor : widget.color,
            ),
            child: widget.isIconOnly
                ? Center(
                    child: WiredIcon(
                      icon: widget.icon,
                      size: 24,
                      color: theme.onPrimary,
                      drawConfig: theme.wired.drawConfig,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      WiredIcon(
                        icon: widget.icon,
                        size: 20,
                        color: theme.onPrimary,
                        drawConfig: theme.wired.drawConfig,
                      ),
                      SizedBox(width: widget.size.getItemSpacing()),
                      Text(
                        widget.label!,
                        style: TextStyle(
                          color: theme.onPrimary,
                          fontSize: widget.size.getSubtitleFontSize(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
