import 'dart:math';

import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/tracker/models/goal.dart';
import 'package:aboutme/plugins/tracker/models/record.dart';
import 'package:aboutme/plugins/tracker/controllers/tracker_controller.dart';
import 'package:aboutme/plugins/tracker/widgets/timer_dialog.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  final TrackerController controller;
  final VoidCallback onTap;

  const GoalCard({
    super.key,
    required this.goal,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // 卡片可能渲染在第三方导航容器内，DS 组件先过桥
      child: WiredDraw(
        // 挂载即播墨线描画入场（design.md §10）
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            final drawProgress = WiredDrawTransition.progressOf(context);
            final seed = goal.id.hashCode & 0x7fffffff;
            final progress = controller.calculateProgress(goal).clamp(0.0, 1.0);
            final isCompleted = controller.calculateProgress(goal) >= 1.0;
            final remainingDays = goal.dateSettings.endDate
                ?.difference(DateTime.now())
                .inDays;

            // 参考稿风格：由目标色派生 粉彩底色/深色文字/饱和波浪
            final base = goal.progressColor != null
                ? Color(goal.progressColor!)
                : theme.primary;
            final pastel = base.mixWhite(0.86);
            final deep = base.mixBlack(0.55);
            final mid = base.mixBlack(0.28);
            final hasImage =
                goal.imagePath != null && goal.imagePath!.isNotEmpty;

            return SizedBox(
              height: 190,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Stack(
                  children: [
                    // 右下硬偏移墨影（零模糊实底影，参考稿 shadow-[3.5px_3.5px_0px_ink]）
                    Positioned.fill(
                      left: 3.5,
                      top: 3.5,
                      child: DecoratedBox(
                        decoration: dsSketchDecoration(
                          theme: theme,
                          fillColor: theme.ink,
                          stroke: theme.ink,
                          strokeWidth: 1.2,
                          radius: theme.radii.xxl,
                          seed: seed + 13,
                          progress: drawProgress,
                        ),
                      ),
                    ),
                    // 卡体：粉彩实底 + 墨线框（内容层）
                    Container(
                      decoration: dsSketchDecoration(
                        theme: theme,
                        fillColor: pastel,
                        radius: theme.radii.xxl,
                        seed: seed,
                        progress: drawProgress,
                      ),
                      child: Stack(
                        children: [
                          // 图片与波浪在自身层做圆角裁剪，墨线抖动描边不被裁
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: theme.radii.xxl,
                              child: Stack(
                                children: [
                                  if (hasImage) ...[
                                    Positioned.fill(
                                      child: AdaptiveImage(
                                        imagePath: goal.imagePath,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    // 彩色罩：让图片融入粉彩卡片并保证深色文字可读
                                    Positioned.fill(
                                      child: ColoredBox(
                                        color: pastel.withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ],
                                  // 液体波浪进度填充
                                  _WaveFill(
                                    progress: progress,
                                    color: base,
                                    drawProgress: drawProgress,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Pressable(
                              onPressed: onTap,
                              builder: (context, states) => Opacity(
                                opacity: states.contains(WidgetState.pressed)
                                    ? 0.92
                                    : 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _buildIconBadge(
                                            theme,
                                            drawProgress,
                                            base,
                                          ),
                                          const Spacer(),
                                          _circleAction(
                                            theme: theme,
                                            drawProgress: drawProgress,
                                            icon: isCompleted
                                                ? Icons.check_rounded
                                                : Icons.add_rounded,
                                            semanticLabel:
                                                'tracker_quickAction'.tr,
                                            onTap: () =>
                                                _showActionSheet(context),
                                            color: isCompleted
                                                ? Colors.white
                                                : base,
                                            fillColor: isCompleted
                                                ? base.mixBlack(0.45)
                                                : theme.paper,
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            '${_fmt(goal.currentValue)}${goal.unitType}',
                                            style: TextStyle(
                                              fontSize: 28,
                                              height: 1,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.5,
                                              color: deep,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isCompleted
                                                ? 'tracker_completed'.tr
                                                : '/${_fmt(goal.targetValue)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              height: 1,
                                              fontWeight: FontWeight.w700,
                                              color: mid,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        goal.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.2,
                                          fontWeight: FontWeight.w700,
                                          color: deep,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text.rich(
                                        TextSpan(
                                          text: goal.group,
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.3,
                                            fontWeight: FontWeight.w500,
                                            color: mid,
                                          ),
                                          children: [
                                            if (remainingDays != null)
                                              TextSpan(
                                                text:
                                                    ' · ${remainingDays > 0 ? 'tracker_remainingDays'.trParams({'days': remainingDays.toString()}) : 'tracker_expired'.tr}',
                                                style: TextStyle(
                                                  color: remainingDays <= 0
                                                      ? theme.danger
                                                      : mid,
                                                ),
                                              ),
                                          ],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// 左上角 48px 纸色圆形图标徽章（手绘墨圈）
  Widget _buildIconBadge(
    AppThemeData theme,
    Animation<double>? drawProgress,
    Color tint,
  ) {
    return Container(
      width: 48,
      height: 48,
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.paper,
        circle: true,
        strokeWidth: 1.5,
        progress: drawProgress,
      ),
      child: Center(
        // goal.icon 为持久化 codePoint 字符串，保留 Material IconData
        child: Icon(
          dynamicIconData(int.parse(goal.icon), fontFamily: 'MaterialIcons'),
          size: 26,
          color: goal.iconColor != null ? Color(goal.iconColor!) : tint,
        ),
      ),
    );
  }

  /// 右上角 36px 圆形操作按钮（手绘墨圈）
  Widget _circleAction({
    required AppThemeData theme,
    Animation<double>? drawProgress,
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
    required Color color,
    Color? fillColor,
  }) {
    return Pressable(
      onPressed: onTap,
      semanticLabel: semanticLabel,
      builder: (context, states) => AnimatedScale(
        scale: states.contains(WidgetState.pressed) ? 0.88 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 36,
          height: 36,
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: fillColor ?? theme.paper,
            circle: true,
            strokeWidth: 1.4,
            progress: drawProgress,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  /// 卡片唯一操作入口：快捷添加进度 / 计时 / 完成切换
  void _showActionSheet(BuildContext context) {
    showGoalActionSheet(context, goal: goal, controller: controller);
  }
}

/// 目标快捷操作面板入口：快捷/自定义添加进度 + 计时 + 完成切换（卡片/列表共用）
void showGoalActionSheet(
  BuildContext context, {
  required Goal goal,
  required TrackerController controller,
}) {
  showDSBottomSheet(
    context: context,
    title: goal.name,
    builder: (sheetContext) => _GoalActionSheet(
      goal: goal,
      controller: controller,
      onTimer: () => showDSDialog(
        context: context,
        theme: DSThemeBridge.resolve(context),
        builder: (dialogContext) =>
            TimerDialog(goal: goal, controller: controller),
      ),
      onToggleComplete: () {
        final done = controller.calculateProgress(goal) >= 1.0;
        controller.updateGoal(
          goal.id,
          goal.copyWith(currentValue: done ? 0 : goal.targetValue),
        );
      },
    ),
  );
}

/// 列表视图的横向紧凑目标卡片：左图标 + 名称/分组 + 右数值/操作，
/// 波浪进度为水平填充（自左向右）
class GoalListCard extends StatelessWidget {
  final Goal goal;
  final TrackerController controller;
  final VoidCallback onTap;

  const GoalListCard({
    super.key,
    required this.goal,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // 卡片可能渲染在第三方导航容器内，DS 组件先过桥
      child: WiredDraw(
        // 挂载即播墨线描画入场（design.md §10）
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            final drawProgress = WiredDrawTransition.progressOf(context);
            final seed = goal.id.hashCode & 0x7fffffff;
            final progress = controller.calculateProgress(goal).clamp(0.0, 1.0);
            final isCompleted = progress >= 1.0;
            final remainingDays = goal.dateSettings.endDate
                ?.difference(DateTime.now())
                .inDays;

            // 与 GoalCard 一致：由目标色派生 粉彩底色/深色文字/饱和波浪
            final base = goal.progressColor != null
                ? Color(goal.progressColor!)
                : theme.primary;
            final pastel = base.mixWhite(0.86);
            final deep = base.mixBlack(0.55);
            final mid = base.mixBlack(0.28);

            return SizedBox(
              height: 84,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Stack(
                  children: [
                    // 右下硬偏移墨影（紧凑列表卡取小一档偏移）
                    Positioned.fill(
                      left: 2.5,
                      top: 2.5,
                      child: DecoratedBox(
                        decoration: dsSketchDecoration(
                          theme: theme,
                          fillColor: theme.ink,
                          stroke: theme.ink,
                          strokeWidth: 1.2,
                          radius: theme.radii.xl,
                          seed: seed + 13,
                          progress: drawProgress,
                        ),
                      ),
                    ),
                    // 卡体：粉彩实底 + 墨线框（内容层）
                    Container(
                      decoration: dsSketchDecoration(
                        theme: theme,
                        fillColor: pastel,
                        radius: theme.radii.xl,
                        seed: seed,
                        progress: drawProgress,
                      ),
                      child: Stack(
                        children: [
                          // 波浪圆角裁剪在自身层完成，墨线描边不被裁
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: theme.radii.xl,
                              // 液体波浪进度填充（水平风格，自左向右）
                              child: _WaveFill(
                                progress: progress,
                                color: base,
                                horizontal: true,
                                drawProgress: drawProgress,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Pressable(
                              onPressed: onTap,
                              builder: (context, states) => Opacity(
                                opacity: states.contains(WidgetState.pressed)
                                    ? 0.92
                                    : 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      _buildIconBadge(
                                        theme,
                                        drawProgress,
                                        base,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              goal.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15,
                                                height: 1.2,
                                                fontWeight: FontWeight.w700,
                                                color: deep,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text.rich(
                                              TextSpan(
                                                text: goal.group,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  height: 1.3,
                                                  fontWeight: FontWeight.w500,
                                                  color: mid,
                                                ),
                                                children: [
                                                  if (remainingDays != null)
                                                    TextSpan(
                                                      text:
                                                          ' · ${remainingDays > 0 ? 'tracker_remainingDays'.trParams({'days': remainingDays.toString()}) : 'tracker_expired'.tr}',
                                                      style: TextStyle(
                                                        color:
                                                            remainingDays <= 0
                                                            ? theme.danger
                                                            : mid,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text.rich(
                                        TextSpan(
                                          text: _fmt(goal.currentValue),
                                          style: TextStyle(
                                            fontSize: 18,
                                            height: 1,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                            color: deep,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: isCompleted
                                                  ? ' ${'tracker_completed'.tr}'
                                                  : '/${_fmt(goal.targetValue)}${goal.unitType}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                height: 1,
                                                fontWeight: FontWeight.w700,
                                                color: mid,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      _circleAction(
                                        theme: theme,
                                        drawProgress: drawProgress,
                                        icon: isCompleted
                                            ? Icons.check_rounded
                                            : Icons.add_rounded,
                                        semanticLabel: 'tracker_quickAction'.tr,
                                        onTap: () => showGoalActionSheet(
                                          context,
                                          goal: goal,
                                          controller: controller,
                                        ),
                                        color: isCompleted
                                            ? Colors.white
                                            : base,
                                        fillColor: isCompleted
                                            ? base.mixBlack(0.45)
                                            : theme.paper,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// 左侧 40px 纸色圆形图标徽章（手绘墨圈）
  Widget _buildIconBadge(
    AppThemeData theme,
    Animation<double>? drawProgress,
    Color tint,
  ) {
    return Container(
      width: 40,
      height: 40,
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.paper,
        circle: true,
        strokeWidth: 1.4,
        progress: drawProgress,
      ),
      child: Center(
        // goal.icon 为持久化 codePoint 字符串，保留 Material IconData
        child: Icon(
          dynamicIconData(int.parse(goal.icon), fontFamily: 'MaterialIcons'),
          size: 22,
          color: goal.iconColor != null ? Color(goal.iconColor!) : tint,
        ),
      ),
    );
  }

  /// 右侧 32px 圆形操作按钮（手绘墨圈）
  Widget _circleAction({
    required AppThemeData theme,
    Animation<double>? drawProgress,
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
    required Color color,
    Color? fillColor,
  }) {
    return Pressable(
      onPressed: onTap,
      semanticLabel: semanticLabel,
      builder: (context, states) => AnimatedScale(
        scale: states.contains(WidgetState.pressed) ? 0.88 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 32,
          height: 32,
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: fillColor ?? theme.paper,
            circle: true,
            strokeWidth: 1.4,
            progress: drawProgress,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

/// 卡片液体波浪填充：双层正弦波 + 渐变波体，
/// 绘制方式参考 wave_progress_indicator 的 WavePainter。
/// vertical 自下而上填充，horizontal（列表视图）自左向右填充；
/// [drawProgress] 接外层 WiredDraw 描画进度，波浪在 30%–100% 阶段浮现
class _WaveFill extends StatefulWidget {
  const _WaveFill({
    required this.progress,
    required this.color,
    this.horizontal = false,
    this.drawProgress,
  });

  final double progress;
  final Color color;
  final bool horizontal;
  final Animation<double>? drawProgress;

  @override
  State<_WaveFill> createState() => _WaveFillState();
}

class _WaveFillState extends State<_WaveFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draw = widget.drawProgress;
    return AnimatedBuilder(
      animation: draw == null
          ? _controller
          : Listenable.merge([_controller, draw]),
      builder: (context, _) => CustomPaint(
        painter: _WavePainter(
          progress: widget.progress,
          animationValue: _controller.value,
          drawValue: draw?.value ?? 1,
          color: widget.color,
          horizontal: widget.horizontal,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.progress,
    required this.animationValue,
    required this.drawValue,
    required this.color,
    this.horizontal = false,
  });

  final double progress;
  final double animationValue;

  /// 外层 WiredDraw 描画进度；1 = 无动画环境，立即全画
  final double drawValue;
  final Color color;
  final bool horizontal;

  /// 墨线描边先描（0–65%），波体随后浮现（30%–100%），见 design.md §10
  double get fillPhase => ((drawValue - 0.3) / 0.7).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || fillPhase <= 0) return;
    if (horizontal) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  void _paintVertical(Canvas canvas, Size size) {
    // 后层波：更浅、反向流动，形成前后景深
    _drawWave(
      canvas,
      size,
      level: -8,
      amp: 9,
      phase: -animationValue * 2 * pi,
      horizontal: false,
      paint: Paint()
        ..color = color.mixWhite(0.25).withValues(alpha: 0.45 * fillPhase),
    );
    // 前层波 + 波体：自下而上渐弱
    _drawWave(
      canvas,
      size,
      level: 0,
      amp: 7,
      phase: animationValue * 2 * pi,
      horizontal: false,
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            color.withValues(alpha: 0.60 * fillPhase),
            color.withValues(alpha: 0.38 * fillPhase),
            color.withValues(alpha: 0.24 * fillPhase),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  void _paintHorizontal(Canvas canvas, Size size) {
    // 列表卡片较矮，波幅收敛避免波浪吞掉整行
    _drawWave(
      canvas,
      size,
      level: -5,
      amp: 6,
      phase: -animationValue * 2 * pi,
      horizontal: true,
      paint: Paint()
        ..color = color.mixWhite(0.25).withValues(alpha: 0.45 * fillPhase),
    );
    // 前层波 + 波体：自左向右渐弱
    _drawWave(
      canvas,
      size,
      level: 0,
      amp: 5,
      phase: animationValue * 2 * pi,
      horizontal: true,
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.60 * fillPhase),
            color.withValues(alpha: 0.38 * fillPhase),
            color.withValues(alpha: 0.24 * fillPhase),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required double level,
    required double amp,
    required double phase,
    required bool horizontal,
    required Paint paint,
  }) {
    final path = horizontal
        ? _buildHorizontalPath(size, level, amp, phase)
        : _buildVerticalPath(size, level, amp, phase);
    canvas.drawPath(path, paint);
  }

  /// 垂直填充：波面沿 x 轴起伏，水位线 y = height * (1 - progress)
  Path _buildVerticalPath(Size size, double level, double amp, double phase) {
    final base = size.height * (1 - progress) + level;
    final path = Path()..moveTo(0, base);
    for (double x = 0; x <= size.width; x++) {
      final y = base + sin((x / size.width * 2 * pi) + phase) * amp;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  /// 水平填充：波面沿 y 轴起伏，进度线 x = width * progress
  Path _buildHorizontalPath(Size size, double level, double amp, double phase) {
    final base = size.width * progress + level;
    final path = Path()..moveTo(base, 0);
    for (double y = 0; y <= size.height; y++) {
      final x = base + sin((y / size.height * 2 * pi) + phase) * amp;
      path.lineTo(x, y);
    }
    path
      ..lineTo(0, size.height)
      ..lineTo(0, 0)
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.animationValue != animationValue ||
      old.progress != progress ||
      old.drawValue != drawValue ||
      old.color != color ||
      old.horizontal != horizontal;
}

/// 目标快捷操作面板：快捷/自定义添加进度 + 计时 + 完成切换
class _GoalActionSheet extends StatefulWidget {
  final Goal goal;
  final TrackerController controller;
  final VoidCallback onTimer;
  final VoidCallback onToggleComplete;

  const _GoalActionSheet({
    required this.goal,
    required this.controller,
    required this.onTimer,
    required this.onToggleComplete,
  });

  @override
  State<_GoalActionSheet> createState() => _GoalActionSheetState();
}

class _GoalActionSheetState extends State<_GoalActionSheet> {
  final _inputController = TextEditingController();
  String? _errorText;

  bool get _isCompleted =>
      widget.controller.calculateProgress(widget.goal) >= 1.0;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _add(double value) {
    widget.controller.addRecord(
      Record(
        id: const Uuid().v4(),
        goalId: widget.goal.id,
        value: value,
        recordedAt: DateTime.now(),
        note: null,
      ),
      widget.goal,
    );
    Navigator.pop(context);
  }

  void _addCustom() {
    final text = _inputController.text;
    if (text.isEmpty) {
      setState(() => _errorText = 'tracker_enterValueError'.tr);
      return;
    }
    final value = double.tryParse(text);
    if (value == null) {
      setState(() => _errorText = 'tracker_invalidNumberError'.tr);
      return;
    }
    _add(value);
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // Sheet 路由在主题树之外，先过桥再取令牌
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final goal = widget.goal;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 当前进度
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
                child: Text(
                  '${_fmt(goal.currentValue)}/${_fmt(goal.targetValue)} ${goal.unitType}',
                  style: DsTypography.body.copyWith(color: theme.textSub),
                ),
              ),
              SizedBox(height: theme.spacing.lg),
              // 快捷进度值
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
                child: Row(
                  children: [
                    for (final v in const [1, 5, 10, 30]) ...[
                      Expanded(
                        child: DSChip(
                          label: '$v',
                          selected: false,
                          onSelected: (_) => _add(v.toDouble()),
                        ),
                      ),
                      if (v != 30) SizedBox(width: theme.spacing.md),
                    ],
                  ],
                ),
              ),
              SizedBox(height: theme.spacing.lg),
              // 自定义输入
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: DSInput(
                        controller: _inputController,
                        errorText: _errorText,
                        hint: 'tracker_customProgressHint'.trParams({
                          'unit': goal.unitType,
                        }),
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _addCustom(),
                      ),
                    ),
                    SizedBox(width: theme.spacing.md),
                    DSButton(label: 'app_save'.tr, onPressed: _addCustom),
                  ],
                ),
              ),
              SizedBox(height: theme.spacing.md),
              // 其余操作
              DSSheetAction(
                icon: DsIconKind.clock,
                label: 'tracker_timer'.tr,
                onTap: () {
                  Navigator.pop(context);
                  widget.onTimer();
                },
              ),
              DSSheetAction(
                icon: DsIconKind.check,
                label: _isCompleted
                    ? 'tracker_cancelComplete'.tr
                    : 'tracker_completeNow'.tr,
                onTap: () {
                  Navigator.pop(context);
                  widget.onToggleComplete();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
