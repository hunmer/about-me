import 'package:get/get.dart';
import 'dart:async';

import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/habits/habits_plugin.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/habits/models/habit.dart';
import 'package:aboutme/plugins/habits/models/completion_record.dart';
import 'package:aboutme/plugins/habits/controllers/habit_controller.dart';

class TimerDialog extends StatefulWidget {
  final Habit habit;
  final HabitController controller;
  final Map<String, dynamic>? initialTimerData;

  const TimerDialog({
    super.key,
    required this.habit,
    required this.controller,
    this.initialTimerData,
  });

  @override
  State<TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<TimerDialog> {
  bool _isCountdown = true;
  bool _isRunning = false;
  Duration _duration = const Duration(minutes: 25);
  Duration _elapsed = Duration.zero;
  final TextEditingController _notesController = TextEditingController();
  String _lastSavedNotes = '';
  late Color _themeColor;

  // ignore: prefer_typing_uninitialized_variables
  var _timer;

  @override
  void initState() {
    super.initState();
    _themeColor = _getColor(widget.habit.skillId ?? widget.habit.id);
    _duration = Duration(minutes: widget.habit.durationMinutes);

    if (widget.initialTimerData != null) {
      _isCountdown = widget.initialTimerData!['isCountdown'] ?? true;
      _elapsed = Duration(
        seconds: widget.initialTimerData!['elapsedSeconds'] ?? 0,
      );
      _notesController.text = widget.initialTimerData!['notes'] ?? '';
      // 不初始化_isRunning，因为会在_toggleTimer中初始化，此处仅用于判断是否需要启动计时器。
      if (widget.initialTimerData!['isRunning']) _toggleTimer();
    }

    // 设置路由上下文
    _updateRouteContext();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前页面状态
  void _updateRouteContext() {
    RouteHistoryManager.updateCurrentContext(
      pageId: '/habit_timer',
      title: '习惯计时器 - ${widget.habit.title}',
      params: {'habitId': widget.habit.id, 'habitTitle': widget.habit.title},
    );
  }

  Color _getColor(String id) {
    final colors = [
      const Color(0xFF607AFB), // Read (Blue)
      const Color(0xFFFF6B6B), // Workout (Red)
      const Color(0xFF4ECDC4), // Water (Teal)
      const Color(0xFF9D81E8), // Sleep (Purple)
      const Color(0xFFFFD93D), // Yellow
      const Color(0xFFFF8D29), // Orange
    ];
    return colors[id.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // 对话框路由在主题树之外，内部组件先过桥再取令牌
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return JellyBox(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header: Close Button (Top Right)
                  Align(
                    alignment: Alignment.centerRight,
                    child: DSIconButton(
                      icon: DsIconKind.close,
                      size: 36,
                      color: theme.surfaceAlt,
                      iconColor: theme.textSub,
                      onPressed: () => _closeDialog(context), // 仅关闭对话框，保持计时器运行
                    ),
                  ),

                  // Habit Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      widget.habit.icon != null
                          ? IconData(
                            int.parse(widget.habit.icon!),
                            fontFamily: 'MaterialIcons',
                          )
                          : Icons.auto_stories, // Fallback
                      color: _themeColor,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Habit Title
                  Text(
                    widget.habit.title,
                    style: DsTypography.display.copyWith(color: theme.text),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Timer Display
                  GestureDetector(
                    onTap: _toggleTimerMode,
                    child: Text(
                      _formatDuration(
                        _isCountdown ? _duration - _elapsed : _elapsed,
                      ),
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w600,
                        color: theme.text,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pause/Play Button
                      Pressable(
                        onPressed: _toggleTimer,
                        builder: (context, states) {
                          final pressed = states.contains(WidgetState.pressed);
                          return AnimatedScale(
                            scale: pressed ? 0.96 : 1.0,
                            duration: const Duration(milliseconds: 120),
                            child: JellyBox(
                              width: 160,
                              height: 64,
                              radius: BorderRadius.circular(32),
                              color: _themeColor,
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  DsIcon(
                                    _isRunning
                                        ? DsIconKind.pause
                                        : DsIconKind.play,
                                    size: 28,
                                    color: DsColors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isRunning ? 'Pause' : 'Start',
                                    style: DsTypography.button.copyWith(
                                      fontSize: 18,
                                      color: DsColors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      // Restart Button
                      DSIconButton(
                        icon: DsIconKind.refresh,
                        size: 64,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: _resetTimer,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Quick Notes Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Quick Notes',
                      style: DsTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DSInput(
                    controller: _notesController,
                    hint: 'Add a quick note...',
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons Row
                  Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: DSButton(
                            label: 'Cancel',
                            variant: DSButtonVariant.outline,
                            onPressed: () => _cancelTimer(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Complete Button
                      Expanded(
                        child: Pressable(
                          onPressed: () => _completeTimer(context),
                          builder: (context, states) {
                            final pressed = states.contains(
                              WidgetState.pressed,
                            );
                            return AnimatedScale(
                              scale: pressed ? 0.96 : 1.0,
                              duration: const Duration(milliseconds: 120),
                              child: JellyBox(
                                height: 48,
                                radius: theme.radii.lg,
                                color: _themeColor,
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    DsIcon(
                                      DsIconKind.check,
                                      size: 20,
                                      color: DsColors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Complete',
                                      style: DsTypography.button.copyWith(
                                        color: DsColors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours > 0 ? '${twoDigits(hours)}:' : ''}'
        '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  void _toggleTimer() {
    if (!mounted) return;
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        widget.controller.timerController.startTimer(widget.habit, (elapsed) {
          if (!mounted) return;
          setState(() {
            _elapsed = Duration(seconds: elapsed);
            if (_isCountdown && _elapsed >= _duration) {
              _isRunning = false;
              // TODO 完成提示
            }
          });
          // 只在笔记内容变更时更新
          if (_notesController.text != _lastSavedNotes) {
            _lastSavedNotes = _notesController.text;
            widget.controller.timerController.updateTimerData(widget.habit.id, {
              'notes': _notesController.text,
            });
          }
        });
      } else {
        widget.controller.timerController.pauseTimer(widget.habit.id);
        widget.controller.timerController.updateTimerData(widget.habit.id, {
          'elapsedSeconds': _elapsed.inSeconds,
          'isRunning': false,
        });
      }
    });
  }

  void _resetTimer() {
    setState(() {
      _elapsed = Duration.zero;
      _isRunning = false;
    });
    // 完全清除计时器状态，确保重新打开对话框时不会恢复
    widget.controller.timerController.stopTimer(widget.habit.id);
    widget.controller.timerController.clearTimerData(widget.habit.id);
  }

  void _toggleTimerMode() {
    if (_isCountdown && _elapsed >= _duration) return;
    setState(() {
      _isCountdown = !_isCountdown;
      widget.controller.timerController.setCountdownMode(
        widget.habit.id,
        _isCountdown,
      );
      widget.controller.notifyTimerModeChanged(widget.habit.id, _isCountdown);
    });
  }

  /// 仅关闭对话框，不停止计时器
  void _closeDialog(BuildContext context) {
    _timer?.cancel();

    // 保存当前状态（笔记和已过时间）
    widget.controller.timerController.updateTimerData(widget.habit.id, {
      'notes': _notesController.text,
      'elapsedSeconds': _elapsed.inSeconds,
      'isRunning': _isRunning,
      'isCountdown': _isCountdown,
    });

    Navigator.pop(context, false); // false表示未完成
  }

  /// 取消计时器（不保存记录）
  Future<void> _cancelTimer(BuildContext context) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSDialog(
            title: 'habits_cancelTimer'.tr,
            message:
                '确定要取消计时吗？\n'
                '已计时: ${_formatDuration(_elapsed)}\n\n'
                '⚠️ 本次计时记录将不会保存',
            cancelText: 'habits_continueTimer'.tr,
            confirmText: 'habits_confirmCancel'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () => Navigator.pop(context, true),
          ),
    );

    if (confirmed == true) {
      _timer?.cancel();

      // 停止并清除计时器状态
      widget.controller.timerController.stopTimer(widget.habit.id);
      widget.controller.timerController.clearTimerData(widget.habit.id);

      if (context.mounted) {
        Navigator.pop(context, false); // false表示未完成
      }
    }
  }

  /// 完成计时并保存记录
  Future<void> _completeTimer(BuildContext context) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSDialog(
            title: 'habits_completeTimer'.tr,
            message:
                '确定要完成计时并保存记录吗？\n'
                '已计时: ${_formatDuration(_elapsed)}\n'
                '${_notesController.text.isNotEmpty ? '备注: ${_notesController.text}\n' : ''}\n'
                '✅ 本次计时将保存到历史记录',
            cancelText: 'habits_continueAdjust'.tr,
            confirmText: 'habits_confirmComplete'.tr,
            onConfirm: () => Navigator.pop(context, true),
          ),
    );

    if (confirmed == true) {
      _timer?.cancel();

      // 1. 先保存记录（在触发停止事件之前）
      final record = CompletionRecord(
        id: const Uuid().v4(),
        parentId: widget.habit.id,
        date: DateTime.now(),
        duration: _elapsed,
        notes: _notesController.text,
      );

      final recordController =
          (PluginManager.instance.getPlugin('habits') as HabitsPlugin?)
              ?.getRecordController();
      await recordController.saveCompletionRecord(widget.habit.id, record);

      // 2. 然后停止计时器并清理前台通知服务（触发事件）
      if (_isRunning) {
        widget.controller.timerController.stopTimer(widget.habit.id);
      } else {
        // 即使暂停状态也要清理前台通知
        widget.controller.timerController.clearTimerData(widget.habit.id);
      }

      // 3. 关闭对话框
      if (context.mounted) {
        Navigator.pop(context, true); // true表示已完成
      }
    }
  }
}
