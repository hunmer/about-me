import 'dart:math';

import 'package:aboutme/plugins/timer/models/timer_item.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/timer/models/timer_task.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/plugins/timer/timer_plugin.dart';

/// 专注详情页，复刻 Warm Minimalist 设计稿：
/// 暖奶油底 + 任务色主卡片（阶段行 / 进度环 / 目标 pill）+ 三圆控制 + 呼吸提示。
/// 白噪音入口仅为占位。
class TimerTaskDetailsPage extends StatefulWidget {
  final String taskId;

  const TimerTaskDetailsPage({
    super.key,
    required this.taskId,
  });

  @override
  State<TimerTaskDetailsPage> createState() => _TimerTaskDetailsPageState();
}

class _TimerTaskDetailsPageState extends State<TimerTaskDetailsPage>
    with SingleTickerProviderStateMixin {
  // 复刻设计稿配色
  static const Color _canvas = Color(0xFFFBF9F5);
  static const Color _containerLow = Color(0xFFF5F3EF);
  static const Color _container = Color(0xFFEFEFEA);
  static const Color _onSurface = Color(0xFF2C2825);
  static const Color _onSurfaceVariant = Color(0xFF6E655E);
  static const Color _muted = Color(0xFF8C847D);

  late TimerPlugin _plugin;
  late TimerTask _currentTask;
  late int _currentTimerIndex;
  late bool _isRunning;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _plugin = PluginManager.instance.getPlugin('timer') as TimerPlugin;
    _loadTask();
    _subscribeToEvents();
    _updateRouteContext();
  }

  void _loadTask() {
    final tasks = _plugin.getTasks();
    final task = tasks.firstWhereOrNull((t) => t.id == widget.taskId);
    if (task != null) {
      _currentTask = task;
      _currentTimerIndex = _currentTask.getCurrentIndex();
      if (_currentTimerIndex == -1) _currentTimerIndex = 0;
      _isRunning = _currentTask.isRunning;
    }
  }

  void _subscribeToEvents() {
    EventManager.instance.subscribe('timer_task_changed', onTimerTaskChanged);
    EventManager.instance.subscribe('timer_item_progress', onTimerItemProgress);
    EventManager.instance.subscribe('timer_item_changed', onTimerItemChanged);
  }

  void onTimerItemProgress(EventArgs args) {
    if (args is TimerItemEventArgs &&
        _currentTask.timerItems.any((item) => item.id == args.timer.id)) {
      if (mounted) setState(() {});
    }
  }

  void onTimerTaskChanged(EventArgs args) {
    if (args is TimerTaskEventArgs && args.task.id == _currentTask.id) {
      if (mounted) {
        setState(() {
          _currentTask = args.task;
          _isRunning = _currentTask.isRunning;
        });
        _updateRouteContext();
      }
    }
  }

  void onTimerItemChanged(EventArgs args) {
    if (args is TimerItemEventArgs &&
        _currentTask.timerItems.any((item) => item.id == args.timer.id)) {
      if (mounted) {
        setState(() {
          _currentTimerIndex = _currentTask.timerItems
              .indexWhere((item) => item.id == args.timer.id);
        });
        _updateRouteContext();
      }
    }
  }

  void _updateRouteContext() {
    final currentTimer = _currentTask.timerItems[_currentTimerIndex];
    RouteHistoryManager.updateCurrentContext(
      pageId: "/timer_details",
      title: '计时器详情 - ${_currentTask.name}',
      params: {
        'taskId': _currentTask.id,
        'taskName': _currentTask.name,
        'currentTimerName': currentTimer.name,
        'isRunning': _isRunning.toString(),
      },
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    EventManager.instance.unsubscribe('timer_task_changed', onTimerTaskChanged);
    EventManager.instance.unsubscribe('timer_item_progress', onTimerItemProgress);
    EventManager.instance.unsubscribe('timer_item_changed', onTimerItemChanged);
    super.dispose();
  }

  void _handlePlayPause() {
    if (_isRunning) {
      _currentTask.pause();
    } else {
      _currentTask.start();
    }
    // 立即更新本地状态
    setState(() {
      _isRunning = _currentTask.isRunning;
    });
    _plugin.updateTask(_currentTask);
  }

  void _handleReset() {
    _currentTask.reset();
    _plugin.updateTask(_currentTask);
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('timer_comingSoon'.tr),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatClock(Duration duration) {
    if (duration < Duration.zero) duration = Duration.zero;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTask.timerItems.isEmpty) {
      return Scaffold(
        backgroundColor: _canvas,
        body: Center(child: Text('timer_taskEmpty'.tr)),
      );
    }

    final currentTimer = _currentTask.timerItems[_currentTimerIndex];
    final progress = (currentTimer.completedDuration.inSeconds /
            currentTimer.duration.inSeconds)
        .clamp(0.0, 1.0);
    final cardColor = _currentTask.color;

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: Stack(
          children: [
            // 背景水印：任务图标淡色斜置
            Positioned.fill(
              child: Center(
                child: Transform.rotate(
                  angle: 12 * pi / 180,
                  child: Icon(
                    _currentTask.icon,
                    size: 340,
                    color: cardColor.withOpacity(0.07),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _buildTopBar(cardColor),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildFocusCard(currentTimer, progress, cardColor),
                  ),
                ),
                const SizedBox(height: 24),
                _buildControls(cardColor),
                const SizedBox(height: 20),
                _buildBreathingPill(cardColor),
                const SizedBox(height: 14),
                _buildImmersiveHint(),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color cardColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _roundIconBtn(
          size: 40,
          background: Colors.white,
          icon: Icons.close_rounded,
          iconColor: _onSurface,
          onTap: () => Navigator.of(context).pop(),
        ),
        Material(
          color: _container,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _showComingSoon,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.graphic_eq_rounded,
                      size: 16, color: _currentTask.color),
                  const SizedBox(width: 6),
                  Text(
                    'timer_whiteNoise'.tr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFocusCard(TimerItem currentTimer, double progress, Color cardColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // 卡片右上角任务图标剪影
            Positioned(
              right: -56,
              top: -56,
              child: Icon(
                _currentTask.icon,
                size: 280,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCardHeader(currentTimer),
                  _buildRing(progress),
                  _buildHabitPill(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(TimerItem currentTimer) {
    return Row(
      children: [
        _PulsingDot(controller: _pulse, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${'timer_phase'.tr} ${_currentTimerIndex + 1}/${_currentTask.timerItems.length}'
            ' · ${currentTimer.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _isRunning ? 'timer_running'.tr : 'timer_paused'.tr,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRing(double progress) {
    final remaining =
        _currentTask.timerItems[_currentTimerIndex].remainingDuration;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            min(280.0, min(constraints.maxWidth, constraints.maxHeight));
        final hasHours = remaining.inHours > 0;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 1,
                strokeWidth: 7,
                color: Colors.white.withOpacity(0.20),
              ),
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                color: Colors.white,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatClock(remaining),
                      style: TextStyle(
                        fontSize: hasHours ? 44 : 64,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _currentTask.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHabitPill() {
    final totalMinutes = _currentTask.timerItems
        .fold<int>(0, (sum, item) => sum + item.duration.inMinutes);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${_currentTask.timerItems.length} ${'timer_phase'.tr} · $totalMinutes min',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(Color cardColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _roundIconBtn(
          size: 48,
          background: _container,
          icon: Icons.restart_alt_rounded,
          iconColor: _onSurface,
          onTap: _handleReset,
        ),
        const SizedBox(width: 28),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: cardColor.withOpacity(0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _roundIconBtn(
            size: 80,
            background: Colors.white,
            icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
            iconColor: cardColor,
            iconScale: 0.5,
            onTap: _handlePlayPause,
          ),
        ),
        const SizedBox(width: 28),
        _roundIconBtn(
          size: 48,
          background: _container,
          icon: Icons.skip_next_rounded,
          iconColor: _onSurface,
          onTap: _showComingSoon,
        ),
      ],
    );
  }

  Widget _buildBreathingPill(Color cardColor) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _containerLow,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: _onSurface.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingDot(controller: _pulse, color: cardColor),
            const SizedBox(width: 10),
            Text(
              'timer_breathingHint'.tr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImmersiveHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.screen_rotation_rounded, size: 14, color: _muted),
        const SizedBox(width: 6),
        Text(
          'timer_immersiveHint'.tr,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _muted,
          ),
        ),
      ],
    );
  }

  Widget _roundIconBtn({
    required double size,
    required Color background,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    double iconScale = 0.45,
  }) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * iconScale, color: iconColor),
        ),
      ),
    );
  }
}

/// 脉冲扩散小圆点（设计稿中的 ping 动画）
class _PulsingDot extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _PulsingDot({
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const size = 10.0;
    return SizedBox(
      width: size * 2.2,
      height: size * 2.2,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) {
              final t = controller.value;
              return Container(
                width: size + size * t * 1.2,
                height: size + size * t * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.45 * (1 - t)),
                ),
              );
            },
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
