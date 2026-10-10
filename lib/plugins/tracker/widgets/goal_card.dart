import 'dart:math';

import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
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
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final progress = controller.calculateProgress(goal).clamp(0.0, 1.0);
          final isCompleted = controller.calculateProgress(goal) >= 1.0;
          final remainingDays =
              goal.dateSettings.endDate?.difference(DateTime.now()).inDays;

          // 参考稿风格：由目标色派生 粉彩底色/深色文字/饱和波浪
          final base =
              goal.progressColor != null
                  ? Color(goal.progressColor!)
                  : theme.primary;
          final pastel = base.mixWhite(0.86);
          final deep = base.mixBlack(0.55);
          final mid = base.mixBlack(0.28);
          final hasImage = goal.imagePath != null && goal.imagePath!.isNotEmpty;

          return SizedBox(
            height: 190,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: pastel,
                  borderRadius: theme.radii.xxl,
                  // 细白描边提升粉彩卡的轮廓质感
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1,
                  ),
                  boxShadow: theme.shadows.card,
                ),
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
                    Positioned.fill(
                      child: _WaveFill(progress: progress, color: base),
                    ),
                    Positioned.fill(
                      child: Pressable(
                        onPressed: onTap,
                        builder:
                            (context, states) => Opacity(
                              opacity:
                                  states.contains(WidgetState.pressed)
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
                                        _buildIconBadge(base),
                                        const Spacer(),
                                        _circleAction(
                                          icon:
                                              isCompleted
                                                  ? Icons.check_rounded
                                                  : Icons.add_rounded,
                                          semanticLabel: '快捷操作',
                                          onTap: () => _showActionSheet(context),
                                          color:
                                              isCompleted
                                                  ? Colors.white
                                                  : base,
                                          fillColor:
                                              isCompleted
                                                  ? base.mixBlack(0.45)
                                                  : Colors.white,
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
                                                  ' · ${remainingDays > 0 ? '剩余$remainingDays天' : '已过期'}',
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
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// 左上角 48px 白色圆形图标徽章
  Widget _buildIconBadge(Color tint) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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

  /// 右上角 36px 圆形操作按钮
  Widget _circleAction({
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
    required Color color,
    Color? fillColor,
  }) {
    return Pressable(
      onPressed: onTap,
      semanticLabel: semanticLabel,
      builder:
          (context, states) => AnimatedScale(
            scale: states.contains(WidgetState.pressed) ? 0.88 : 1,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: fillColor ?? Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: color),
            ),
          ),
    );
  }

  void _startTimer(BuildContext context) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => TimerDialog(goal: goal, controller: controller),
    );
  }

  /// 卡片唯一操作入口：快捷添加进度 / 计时 / 完成切换
  void _showActionSheet(BuildContext context) {
    showDSBottomSheet(
      context: context,
      title: goal.name,
      builder:
          (sheetContext) => _GoalActionSheet(
            goal: goal,
            controller: controller,
            onTimer: () => _startTimer(context),
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
}

/// 卡片底部液体波浪填充：双层正弦波 + 渐变波体，
/// 绘制方式参考 wave_progress_indicator 的 WavePainter
class _WaveFill extends StatefulWidget {
  const _WaveFill({required this.progress, required this.color});

  final double progress;
  final Color color;

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
    return AnimatedBuilder(
      animation: _controller,
      builder:
          (context, _) => CustomPaint(
            painter: _WavePainter(
              progress: widget.progress,
              animationValue: _controller.value,
              color: widget.color,
            ),
          ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.progress,
    required this.animationValue,
    required this.color,
  });

  final double progress;
  final double animationValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    // 后层波：更浅、反向流动，形成前后景深
    _drawWave(
      canvas,
      size,
      level: -8,
      amp: 9,
      phase: -animationValue * 2 * pi,
      paint: Paint()
        ..color = color.mixWhite(0.25).withValues(alpha: 0.45),
    );
    // 前层波 + 波体：自下而上渐弱
    _drawWave(
      canvas,
      size,
      level: 0,
      amp: 7,
      phase: animationValue * 2 * pi,
      paint:
          Paint()
            ..shader =
                LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    color.withValues(alpha: 0.60),
                    color.withValues(alpha: 0.38),
                    color.withValues(alpha: 0.24),
                  ],
                ).createShader(
                  Rect.fromLTWH(0, 0, size.width, size.height),
                ),
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required double level,
    required double amp,
    required double phase,
    required Paint paint,
  }) {
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
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.animationValue != animationValue ||
      old.progress != progress ||
      old.color != color;
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
      setState(() => _errorText = '请输入记录值');
      return;
    }
    final value = double.tryParse(text);
    if (value == null) {
      setState(() => _errorText = '请输入有效的数字');
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
                        hint: '自定义进度 (${goal.unitType})',
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
                label: '计时',
                onTap: () {
                  Navigator.pop(context);
                  widget.onTimer();
                },
              ),
              DSSheetAction(
                icon: DsIconKind.check,
                label: _isCompleted ? '取消完成' : '一键完成',
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
