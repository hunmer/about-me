import 'package:get/get.dart';
import 'dart:async';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/services/timer/events/timer_events.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/tracker/utils/tracker_notification_utils.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/services/timer/unified_timer_controller.dart';
import 'package:aboutme/core/services/timer/models/timer_state.dart';
import 'package:aboutme/plugins/tracker/models/goal.dart';
import 'package:aboutme/plugins/tracker/models/record.dart';
import 'package:aboutme/plugins/tracker/controllers/tracker_controller.dart';

class TimerDialog extends StatefulWidget {
  final Goal goal;
  final TrackerController controller;

  const TimerDialog({super.key, required this.goal, required this.controller});

  @override
  State<TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<TimerDialog> {
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;
  bool _notificationInitialized = false;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _valueController = TextEditingController(
    text: '1',
  );

  @override
  void initState() {
    super.initState();
    // 在计时器对话框打开时初始化通知系统
    _initializeNotification();

    // 订阅统一计时器事件
    _subscribeToTimerEvents();
  }

  Future<void> _initializeNotification() async {
    if (!_notificationInitialized) {
      await TrackerNotificationUtils.initialize();
      _notificationInitialized = true;
    }
  }

  /// 订阅统一计时器事件
  void _subscribeToTimerEvents() {
    EventManager.instance.subscribe('unified_timer_updated', (args) {
      if (args is UnifiedTimerEventArgs) {
        final state = args.timerState as TimerState;
        // 只处理 tracker 插件的计时器
        if (state.pluginId != 'tracker') return;

        if (state.id == widget.goal.id) {
          setState(() {
            _seconds = state.elapsed.inSeconds;
            _isRunning = state.status == TimerStatus.running;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _noteController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _startTimer();
      } else {
        _pauseTimer();
      }
    });
  }

  /// 启动计时器（委托给统一控制器）
  ///
  /// icon/color 为统一计时器的注册表数据（跨插件 IconData），保留 Material。
  void _startTimer() {
    unifiedTimerController.startTimer(
      id: widget.goal.id,
      name: widget.goal.name,
      type: TimerType.countUp,
      color: Colors.orange,
      icon: Icons.track_changes,
      pluginId: 'tracker',
    );
  }

  /// 暂停计时器（委托给统一控制器）
  void _pauseTimer() {
    unifiedTimerController.pauseTimer(widget.goal.id);
  }

  /// 重置计时器（委托给统一控制器）
  void _resetTimer() {
    unifiedTimerController.stopTimer(widget.goal.id);

    setState(() {
      _seconds = 0;
      _isRunning = false;
    });
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _saveRecord() async {
    if (_seconds > 0) {
      // 获取用户输入的记录值
      final recordValue = double.tryParse(_valueController.text) ?? 1;

      final record = Record(
        id: const Uuid().v4(),
        goalId: widget.goal.id,
        value: recordValue,
        note: _noteController.text,
        recordedAt: DateTime.now(),
        durationSeconds: _seconds,
      );

      await widget.controller.addRecord(record, widget.goal);

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // 对话框路由在主题树之外，内部组件先过桥再取令牌
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${'tracker_timer'.tr} - ${widget.goal.name}',
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),
                Text(
                  _formatTime(_seconds),
                  textAlign: TextAlign.center,
                  style: DsTypography.display.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    DSIconButton(
                      icon: _isRunning ? DsIconKind.pause : DsIconKind.play,
                      onPressed: _toggleTimer,
                    ),
                    DSIconButton(
                      icon: DsIconKind.stop,
                      color: theme.surfaceAlt,
                      iconColor: theme.textSub,
                      onPressed: _resetTimer,
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.lg),
                DSInput(
                  controller: _valueController,
                  hint: 'tracker_recordValueWithUnit'.tr.replaceFirst(
                    '\${unit}',
                    widget.goal.unitType,
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: theme.spacing.md),
                DSInput(
                  controller: _noteController,
                  hint: '${'tracker_note'.tr} (${'tracker_noteHint'.tr})',
                  maxLines: 2,
                ),
                SizedBox(height: theme.spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: DSButton(
                        label: 'app_cancel'.tr,
                        variant: DSButtonVariant.outline,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: DSButton(
                        label: 'app_save'.tr,
                        onPressed: _seconds > 0 ? _saveRecord : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
