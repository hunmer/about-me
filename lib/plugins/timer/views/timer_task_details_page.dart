import 'dart:math';

import 'package:aboutme/plugins/timer/models/timer_item.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/timer/models/timer_task.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/plugins/timer/services/white_noise_service.dart';
import 'package:aboutme/plugins/timer/timer_plugin.dart';
import 'package:aboutme/widgets/cute_fruit_timer_demo.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 专注详情页（手绘纸墨风）：
/// 纸底 + 任务色主卡片（墨线框 / 阶段行 / 进度环 / 目标 pill）+ 手绘三圆控制 + 呼吸提示。
class TimerTaskDetailsPage extends StatefulWidget {
  final String taskId;

  const TimerTaskDetailsPage({super.key, required this.taskId});

  @override
  State<TimerTaskDetailsPage> createState() => _TimerTaskDetailsPageState();
}

class _TimerTaskDetailsPageState extends State<TimerTaskDetailsPage>
    with SingleTickerProviderStateMixin {
  /// 配色跟随 app 主题（DS 手绘主题），卡片与强调色仍用任务色
  AppThemeData get _dsTheme => DSThemeBridge.resolve(context);

  late TimerPlugin _plugin;
  late TimerTask _currentTask;
  late int _currentTimerIndex;
  late bool _isRunning;
  // 结算弹窗防重弹：本会话任务运行过 + 尚未弹过
  bool _taskHasRun = false;
  bool _settlementShown = false;
  // 水果卡片模式（持久化）：开启后专注卡片替换为水果物理堆叠卡片
  static const _fruitBgPrefKey = 'timer_details_fruit_bg';
  static const _fruitKindPrefKey = 'timer_details_fruit_kind';
  bool _fruitBg = false;
  CuteFruitKind? _fruitKind = CuteFruitKind.orange;
  // Header 水果设置 popover（Overlay 挂载）
  final GlobalKey _fruitBtnKey = GlobalKey();
  OverlayEntry? _fruitPopover;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _plugin = PluginManager.instance.getPlugin('timer') as TimerPlugin;
    _loadTask();
    _loadFruitPrefs();
    _subscribeToEvents();
    _updateRouteContext();
    WhiteNoiseService.instance.error.addListener(_onNoiseError);
  }

  /// 在线音源加载失败提示（消费后清理）
  void _onNoiseError() {
    final key = WhiteNoiseService.instance.error.value;
    if (key == null || !mounted) return;
    showDSToast(context, message: key.tr, type: DSToastType.warning);
    WhiteNoiseService.instance.error.value = null;
  }

  void _loadTask() {
    final tasks = _plugin.getTasks();
    final task = tasks.firstWhereOrNull((t) => t.id == widget.taskId);
    if (task != null) {
      _currentTask = task;
      _currentTimerIndex = _currentTask.getCurrentIndex();
      if (_currentTimerIndex == -1) _currentTimerIndex = 0;
      _isRunning = _currentTask.isRunning;
      _taskHasRun = _isRunning;
    }
  }

  /// 加载水果卡片模式偏好（开关 + 水果类型）
  Future<void> _loadFruitPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fruitBg = prefs.getBool(_fruitBgPrefKey) ?? false;
      final index = prefs.getInt(_fruitKindPrefKey);
      if (index != null) {
        _fruitKind = index < 0
            ? null
            : index < CuteFruitKind.values.length
            ? CuteFruitKind.values[index]
            : CuteFruitKind.orange;
      }
    });
  }

  void _setFruitBg(bool value) {
    setState(() => _fruitBg = value);
    _fruitPopover?.markNeedsBuild();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_fruitBgPrefKey, value),
    );
  }

  void _setFruitKind(CuteFruitKind? kind) {
    setState(() => _fruitKind = kind);
    _fruitPopover?.markNeedsBuild();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt(_fruitKindPrefKey, kind?.index ?? -1),
    );
  }

  /// 任务总进度：所有阶段已完成时长 / 总时长（0..1），驱动果堆数量
  double _taskTotalProgress() {
    final total = _currentTask.timerItems.fold<int>(
      0,
      (sum, item) => sum + item.duration.inSeconds,
    );
    if (total <= 0) return 0;
    final done = _currentTask.timerItems.fold<int>(
      0,
      (sum, item) => sum + item.completedDuration.inSeconds,
    );
    return (done / total).clamp(0.0, 1.0);
  }

  void _subscribeToEvents() {
    EventManager.instance.subscribe('timer_task_changed', onTimerTaskChanged);
    EventManager.instance.subscribe('timer_item_progress', onTimerItemProgress);
    EventManager.instance.subscribe('timer_item_changed', onTimerItemChanged);
  }

  void onTimerItemProgress(EventArgs args) {
    if (args is TimerItemEventArgs &&
        _currentTask.timerItems.any((item) => item.id == args.timer.id)) {
      if (mounted) {
        setState(() {});
        _maybeShowSettlement();
      }
    }
  }

  void onTimerTaskChanged(EventArgs args) {
    if (args is TimerTaskEventArgs && args.task.id == _currentTask.id) {
      if (mounted) {
        setState(() {
          _currentTask = args.task;
          _isRunning = _currentTask.isRunning;
          if (_isRunning) _taskHasRun = true;
        });
        _updateRouteContext();
        _maybeShowSettlement();
      }
    }
  }

  void onTimerItemChanged(EventArgs args) {
    if (args is TimerItemEventArgs &&
        _currentTask.timerItems.any((item) => item.id == args.timer.id)) {
      if (mounted) {
        setState(() {
          _currentTimerIndex = _currentTask.timerItems.indexWhere(
            (item) => item.id == args.timer.id,
          );
        });
        _updateRouteContext();
        _maybeShowSettlement();
      }
    }
  }

  /// 任务全部阶段跑完（且本会话内运行过）时弹一次结算对话框
  void _maybeShowSettlement() {
    if (!_taskHasRun || _settlementShown) return;
    if (!_currentTask.isCompleted) return;
    _settlementShown = true;
    WhiteNoiseService.instance.pause();
    _showSettlementDialog();
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
    _closeFruitPopover();
    _pulse.dispose();
    WhiteNoiseService.instance.error.removeListener(_onNoiseError);
    EventManager.instance.unsubscribe('timer_task_changed', onTimerTaskChanged);
    EventManager.instance.unsubscribe(
      'timer_item_progress',
      onTimerItemProgress,
    );
    EventManager.instance.unsubscribe('timer_item_changed', onTimerItemChanged);
    super.dispose();
  }

  void _handlePlayPause() {
    if (_isRunning) {
      _currentTask.pause();
      WhiteNoiseService.instance.pause();
    } else {
      // 已完成的任务再次点开始：先重置再重新跑，否则会立即触发结算
      if (_currentTask.isCompleted) {
        _currentTask.reset();
        _settlementShown = false;
      }
      _currentTask.start();
      _taskHasRun = true;
      WhiteNoiseService.instance.resume();
    }
    // 立即更新本地状态
    setState(() {
      _isRunning = _currentTask.isRunning;
    });
    _plugin.updateTask(_currentTask);
  }

  void _handleReset() {
    _currentTask.reset();
    _settlementShown = false;
    _taskHasRun = false;
    _plugin.updateTask(_currentTask);
  }

  void _showComingSoon() {
    showDSToast(
      context,
      message: 'timer_comingSoon'.tr,
      type: DSToastType.info,
    );
  }

  /// 专注结算对话框（手绘面板：达成徽章 + 总时长 + 统计格 + 心情自评）
  Future<void> _showSettlementDialog() async {
    final theme = _dsTheme;
    final accent = _currentTask.color;

    final totalDuration =
        _currentTask.timerItems.fold<Duration>(
          Duration.zero,
          (sum, item) => sum + item.duration,
        ) *
        _currentTask.repeatCount;
    final totalMinutes = totalDuration.inMinutes;
    final noiseName =
        WhiteNoiseService.instance.currentPreset?.nameKey.tr ??
        'timer_noNoise'.tr;
    int mood = -1; // 0 平静 1 心流 2 疲惫

    await showDSDialog(
      context: context,
      barrierDismissible: false,
      theme: theme,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => DsSketchPanel(
          theme: theme,
          radius: BorderRadius.circular(28),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 达成徽章：手绘胶囊
              JellyBox(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                radius: DsRadii.pill,
                color: theme.hatch,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DsIcon(DsIconKind.star, size: 16, color: theme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'timer_sessionCompleted'.tr,
                      style: DsTypography.label.copyWith(color: theme.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _formatClock(totalDuration),
                style: DsTypography.display.copyWith(
                  fontSize: 44,
                  height: 1.1,
                  letterSpacing: -1,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currentTask.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
              const SizedBox(height: 18),
              // 统计块
              Row(
                children: [
                  _buildStatCell(
                    theme: theme,
                    icon: DsIconKind.fire,
                    iconColor: theme.primary,
                    value: '${_currentTask.timerItems.length}',
                    label: 'timer_statPhases'.tr,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCell(
                    theme: theme,
                    icon: DsIconKind.sprout,
                    iconColor: theme.primary,
                    value: '$totalMinutes min',
                    label: 'timer_statDuration'.tr,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCell(
                    theme: theme,
                    icon: DsIconKind.graphicEq,
                    iconColor: theme.textSub,
                    value: noiseName,
                    label: 'timer_statAmbience'.tr,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // 状态自评
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'timer_moodTitle'.tr,
                  style: DsTypography.label.copyWith(color: theme.textSub),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildMoodOption(
                    theme: theme,
                    emoji: '😌',
                    label: 'timer_moodCalm'.tr,
                    selected: mood == 0,
                    accent: accent,
                    onTap: () => setDialogState(() => mood = 0),
                  ),
                  const SizedBox(width: 6),
                  _buildMoodOption(
                    theme: theme,
                    emoji: '⚡️',
                    label: 'timer_moodFlow'.tr,
                    selected: mood == 1,
                    accent: accent,
                    onTap: () => setDialogState(() => mood = 1),
                  ),
                  const SizedBox(width: 6),
                  _buildMoodOption(
                    theme: theme,
                    emoji: '😴',
                    label: 'timer_moodTired'.tr,
                    selected: mood == 2,
                    accent: accent,
                    onTap: () => setDialogState(() => mood = 2),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 主按钮：记录并完成
              DSButton(
                label: 'timer_saveFinish'.tr,
                expand: true,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
              DSButton(
                label: 'timer_nextRound'.tr,
                variant: DSButtonVariant.outline,
                expand: true,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _handleReset();
                  _currentTask.start();
                  setState(() {
                    _isRunning = _currentTask.isRunning;
                    _taskHasRun = _isRunning;
                  });
                  _plugin.updateTask(_currentTask);
                  WhiteNoiseService.instance.resume();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCell({
    required AppThemeData theme,
    required DsIconKind icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surfaceAlt.withValues(alpha: 0.5),
          radius: BorderRadius.circular(16),
          strokeWidth: 1.4,
        ),
        child: Column(
          children: [
            DsIcon(icon, size: 18, color: iconColor),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.heading.copyWith(color: theme.text),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.caption.copyWith(
                fontSize: 10,
                color: theme.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodOption({
    required AppThemeData theme,
    required String emoji,
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return Transform.scale(
            scale: pressed ? 0.95 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: selected
                    ? accent.withValues(alpha: 0.10)
                    : theme.surfaceAlt,
                stroke: selected ? accent : null,
                strokeWidth: 1.2,
                radius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(emoji, style: DsTypography.body.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.label.copyWith(
                      color: selected ? accent : theme.textSub,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 白噪音选择弹窗（手绘 sheet，分本地/在线两组）
  void _openSoundscapeSheet() {
    final theme = _dsTheme;
    SmoothBottomSheet.showWithTitle(
      context: context,
      title: 'timer_soundscapes'.tr,
      child: Builder(
        builder: (sheetContext) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVolumeRow(theme),
                Flexible(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      WhiteNoiseService.instance.currentId,
                      WhiteNoiseService.instance.loadingId,
                    ]),
                    builder: (context, _) => SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(theme, 'timer_noise_local'.tr),
                          _buildNoiseGrid(
                            theme,
                            WhiteNoiseService.localPresets,
                          ),
                          const SizedBox(height: 14),
                          _buildSectionLabel(theme, 'timer_noise_online'.tr),
                          _buildNoiseGrid(
                            theme,
                            WhiteNoiseService.onlinePresets,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(AppThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: DsTypography.label.copyWith(
          color: theme.textSub.withValues(alpha: 0.6),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// 音量调节行：图标 + 滑杆 + 百分比
  Widget _buildVolumeRow(AppThemeData theme) {
    final service = WhiteNoiseService.instance;
    return StatefulBuilder(
      builder: (context, setSheetState) => Row(
        children: [
          DsIcon(
            service.volume <= 0 ? DsIconKind.volumeOff : DsIconKind.volumeUp,
            size: 18,
            color: theme.textSub,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: service.volume,
                activeColor: _currentTask.color,
                inactiveColor: theme.surfaceAlt,
                onChanged: (value) {
                  setSheetState(() {});
                  service.setVolume(value);
                },
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '${(service.volume * 100).toInt()}%',
              textAlign: TextAlign.end,
              style: DsTypography.label.copyWith(color: theme.textSub),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoiseGrid(AppThemeData theme, List<WhiteNoisePreset> presets) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: [
        for (final preset in presets)
          _buildNoiseTile(
            theme,
            preset,
            WhiteNoiseService.instance.currentId.value == preset.id,
            WhiteNoiseService.instance.loadingId.value == preset.id,
          ),
      ],
    );
  }

  Widget _buildNoiseTile(
    AppThemeData theme,
    WhiteNoisePreset preset,
    bool active,
    bool loading,
  ) {
    final highlight = _currentTask.color;
    return Pressable(
      onPressed: () {
        WhiteNoiseService.instance.toggle(preset.id);
        Navigator.of(context).pop();
      },
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.scale(
          scale: pressed ? 0.94 : 1.0,
          child: Container(
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: active ? theme.hatch : theme.surfaceAlt,
              stroke: active ? highlight : null,
              strokeWidth: 1.2,
              radius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (loading)
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: highlight,
                            ),
                          )
                        else
                          WiredIcon(
                            icon: preset.icon,
                            size: 24,
                            color: active ? highlight : theme.textSub,
                            drawConfig: theme.wired.drawConfig,
                          ),
                        const SizedBox(height: 6),
                        Text(
                          preset.nameKey.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsTypography.label.copyWith(
                            color: active ? highlight : theme.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 在线音源角标
                if (preset.isOnline)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: DsIcon(
                      DsIconKind.cloud,
                      size: 12,
                      color: active
                          ? highlight
                          : theme.textSub.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatClock(Duration duration) {
    if (duration < Duration.zero) duration = Duration.zero;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  /// 任务色卡片上的前景色：按卡片底色亮度取纸色/墨色
  Color _onCardOf(Color cardColor) =>
      cardColor.computeLuminance() < 0.5 ? DsColors.white : DsColors.text;

  @override
  Widget build(BuildContext context) {
    if (_currentTask.timerItems.isEmpty) {
      return Scaffold(
        backgroundColor: _dsTheme.paper,
        body: Center(child: Text('timer_taskEmpty'.tr)),
      );
    }

    final theme = _dsTheme;
    final currentTimer = _currentTask.timerItems[_currentTimerIndex];
    final progress =
        (currentTimer.completedDuration.inSeconds /
                currentTimer.duration.inSeconds)
            .clamp(0.0, 1.0);
    final cardColor = _currentTask.color;

    // 水果模式：全屏水果卡片 + 顶部工具条，三个控制按钮传入卡片内部
    if (_fruitBg) {
      return Scaffold(
        backgroundColor: dsTransparentWhenGlobalBackground(theme.paper),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: CuteFruitTimerCard(
                  fruitKind: _fruitKind,
                  fullscreen: true,
                  progress: _taskTotalProgress(),
                  timeText: _formatClock(currentTimer.remainingDuration),
                  subtitle: _currentTask.name,
                  isRunning: _isRunning,
                  controls: _buildControls(theme, cardColor),
                ),
              ),
              // 顶栏必须 Positioned 定位：否则作为非定位子节点把 Stack 压成顶栏高度，
              // Positioned.fill 的全屏卡片随之只剩几十像素高
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _buildTopBar(theme, cardColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: dsTransparentWhenGlobalBackground(theme.paper),
      body: SafeArea(
        child: Stack(
          children: [
            // 背景水印：任务图标幽灵涂鸦斜置
            Positioned.fill(
              child: Center(
                child: Transform.rotate(
                  angle: 12 * pi / 180,
                  child: WiredIcon(
                    icon: _currentTask.icon,
                    size: 340,
                    color: cardColor.withValues(alpha: 0.07),
                    drawConfig: theme.wired.drawConfig,
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _buildTopBar(theme, cardColor),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildFocusCard(
                      theme,
                      currentTimer,
                      progress,
                      cardColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildControls(theme, cardColor),
                const SizedBox(height: 20),
                _buildBreathingPill(theme, cardColor),
                const SizedBox(height: 14),
                _buildImmersiveHint(theme),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppThemeData theme, Color cardColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _roundIconBtn(
          theme: theme,
          size: 40,
          background: theme.paper,
          icon: DsIconKind.close,
          iconColor: theme.text,
          onTap: () => Navigator.of(context).pop(),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 水果设置按钮：点击弹出 popover（总开关 + 水果类型）
              _buildFruitPopoverButton(theme, cardColor),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: Listenable.merge([
                  WhiteNoiseService.instance.currentId,
                  WhiteNoiseService.instance.loadingId,
                ]),
                builder: (context, _) {
                  final service = WhiteNoiseService.instance;
                  final playing = service.currentId.value != null;
                  final loading = service.loadingId.value != null;
                  return Pressable(
                    onPressed: _openSoundscapeSheet,
                    builder: (context, states) {
                      final pressed = states.contains(WidgetState.pressed);
                      return Transform.scale(
                        scale: pressed ? 0.96 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: dsSketchDecoration(
                            theme: theme,
                            fillColor: theme.surfaceAlt,
                            radius: DsRadii.pill,
                            strokeWidth: 1.4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (loading)
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cardColor,
                                  ),
                                )
                              else
                                DsIcon(
                                  DsIconKind.graphicEq,
                                  size: 16,
                                  color: cardColor,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                playing
                                    ? service.currentPreset!.nameKey.tr
                                    : 'timer_whiteNoise'.tr,
                                style: DsTypography.label.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Header 水果设置按钮（手绘水果徽标），点击弹出设置 popover
  Widget _buildFruitPopoverButton(AppThemeData theme, Color cardColor) {
    return Pressable(
      key: _fruitBtnKey,
      onPressed: _toggleFruitPopover,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.scale(
          scale: pressed ? 0.9 : 1.0,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: dsSketchDecoration(
              theme: theme,
              circle: true,
              fillColor: _fruitBg ? cardColor : theme.paper,
              stroke: _fruitBg ? cardColor : null,
              strokeWidth: 1.8,
            ),
            child: CuteFruitBadge(kind: _fruitKind, size: _fruitBg ? 24 : 20),
          ),
        );
      },
    );
  }

  void _toggleFruitPopover() {
    if (_fruitPopover != null) {
      _closeFruitPopover();
      return;
    }
    final btnContext = _fruitBtnKey.currentContext;
    if (btnContext == null || !mounted) return;
    final box = btnContext.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    final position = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    const panelWidth = 254.0;
    final screen = overlayBox.size;
    final left = (position.dx + box.size.width - panelWidth).clamp(
      12.0,
      screen.width - panelWidth - 12,
    );
    _fruitPopover = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // 点击空白处关闭
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeFruitPopover,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: position.dy + box.size.height + 8,
            child: _buildFruitPanel(_dsTheme, _currentTask.color),
          ),
        ],
      ),
    );
    overlay.insert(_fruitPopover!);
  }

  void _closeFruitPopover() {
    _fruitPopover?.remove();
    _fruitPopover = null;
  }

  /// 水果设置 popover 面板：总开关 + 掉落水果类型
  Widget _buildFruitPanel(AppThemeData theme, Color cardColor) {
    return SizedBox(
      width: 254,
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CuteFruitBadge(kind: _fruitKind, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '水果专注模式',
                    style: DsTypography.label.copyWith(color: theme.text),
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _fruitBg,
                    onChanged: _setFruitBg,
                    activeColor: cardColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '掉落水果',
              style: DsTypography.caption.copyWith(
                color: theme.textSub.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in CuteFruitKind.values)
                  _buildFruitChip(theme, cardColor, kind),
                _buildFruitChip(theme, cardColor, null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFruitChip(
    AppThemeData theme,
    Color cardColor,
    CuteFruitKind? kind,
  ) {
    final selected = _fruitKind == kind;
    return Pressable(
      onPressed: () => _setFruitKind(kind),
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.scale(
          scale: pressed ? 0.94 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: selected
                  ? cardColor.withValues(alpha: 0.12)
                  : theme.surfaceAlt,
              stroke: selected ? cardColor : null,
              strokeWidth: 1.2,
              radius: DsRadii.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CuteFruitBadge(kind: kind, size: 17),
                const SizedBox(width: 5),
                Text(
                  kind == null ? '混合' : cuteFruitKindName(kind),
                  style: DsTypography.caption.copyWith(
                    color: selected ? cardColor : theme.textSub,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFocusCard(
    AppThemeData theme,
    TimerItem currentTimer,
    double progress,
    Color cardColor,
  ) {
    final onCard = _onCardOf(cardColor);
    // 与列表卡片 TimerCardWidget(enableHero) 共享 tag，实现转场放大
    return Hero(
      tag: 'timer_task_card_${widget.taskId}',
      child: Container(
        width: double.infinity,
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: cardColor,
          radius: BorderRadius.circular(32),
          strokeWidth: 2.2,
          seed: widget.taskId.hashCode & 0x7FFFFFFF,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              // 卡片右上角任务图标幽灵涂鸦
              Positioned(
                right: -56,
                top: -56,
                child: WiredIcon(
                  icon: _currentTask.icon,
                  size: 280,
                  color: onCard.withValues(alpha: 0.10),
                  drawConfig: theme.wired.drawConfig,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCardHeader(theme, onCard, currentTimer),
                    _buildRing(onCard, progress),
                    _buildHabitPill(theme, onCard),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(
    AppThemeData theme,
    Color onCard,
    TimerItem currentTimer,
  ) {
    return Row(
      children: [
        _PulsingDot(controller: _pulse, color: onCard),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${'timer_phase'.tr} ${_currentTimerIndex + 1}/${_currentTask.timerItems.length}'
            ' · ${currentTimer.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsTypography.label.copyWith(
              color: onCard,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: onCard.withValues(alpha: 0.20),
            stroke: onCard.withValues(alpha: 0.5),
            strokeWidth: 1.2,
            radius: DsRadii.pill,
          ),
          child: Text(
            _isRunning ? 'timer_running'.tr : 'timer_paused'.tr,
            style: DsTypography.caption.copyWith(color: onCard),
          ),
        ),
      ],
    );
  }

  Widget _buildRing(Color onCard, double progress) {
    final remaining =
        _currentTask.timerItems[_currentTimerIndex].remainingDuration;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(
          280.0,
          min(constraints.maxWidth, constraints.maxHeight),
        );
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
                color: onCard.withValues(alpha: 0.20),
              ),
              // 进度弧平滑过渡：每秒刷新时以 1s 线性补间，形成连续扫动
              TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: const Duration(seconds: 1),
                curve: Curves.linear,
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  color: onCard,
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatClock(remaining),
                      style: DsTypography.display.copyWith(
                        fontSize: hasHours ? 44 : 64,
                        height: 1.0,
                        letterSpacing: -1,
                        color: onCard,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _currentTask.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.heading.copyWith(
                        fontSize: 15,
                        color: onCard.withValues(alpha: 0.95),
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

  Widget _buildHabitPill(AppThemeData theme, Color onCard) {
    final totalMinutes = _currentTask.timerItems.fold<int>(
      0,
      (sum, item) => sum + item.duration.inMinutes,
    );
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: onCard.withValues(alpha: 0.15),
          stroke: onCard.withValues(alpha: 0.5),
          strokeWidth: 1.2,
          radius: DsRadii.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsIcon(DsIconKind.fire, size: 16, color: onCard),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${_currentTask.timerItems.length} ${'timer_phase'.tr} · $totalMinutes min',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsTypography.body.copyWith(fontSize: 13, color: onCard),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(AppThemeData theme, Color cardColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _roundIconBtn(
          theme: theme,
          size: 48,
          background: theme.surfaceAlt,
          icon: DsIconKind.replay,
          iconColor: theme.text,
          onTap: _handleReset,
        ),
        const SizedBox(width: 28),
        _roundIconBtn(
          theme: theme,
          size: 80,
          background: _onCardOf(cardColor),
          icon: _isRunning ? DsIconKind.pause : DsIconKind.play,
          iconColor: cardColor,
          iconScale: 0.5,
          onTap: _handlePlayPause,
        ),
        const SizedBox(width: 28),
        _roundIconBtn(
          theme: theme,
          size: 48,
          background: theme.surfaceAlt,
          icon: DsIconKind.chevronRight,
          iconColor: theme.text,
          onTap: _showComingSoon,
        ),
      ],
    );
  }

  Widget _buildBreathingPill(AppThemeData theme, Color cardColor) {
    return Center(
      child: JellyBox(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        radius: DsRadii.pill,
        color: theme.surfaceAlt,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingDot(controller: _pulse, color: cardColor),
            const SizedBox(width: 10),
            Text(
              'timer_breathingHint'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImmersiveHint(AppThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DsIcon(
          DsIconKind.refresh,
          size: 14,
          color: theme.textSub.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 6),
        Text(
          'timer_immersiveHint'.tr,
          style: DsTypography.caption.copyWith(
            color: theme.textSub.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _roundIconBtn({
    required AppThemeData theme,
    required double size,
    required Color background,
    required DsIconKind icon,
    required Color iconColor,
    required VoidCallback onTap,
    double iconScale = 0.45,
  }) {
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.scale(
          scale: pressed ? 0.9 : 1.0,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: dsSketchDecoration(
              theme: theme,
              circle: true,
              fillColor: background,
              strokeWidth: 1.8,
            ),
            child: DsIcon(icon, size: size * iconScale, color: iconColor),
          ),
        );
      },
    );
  }
}

/// 脉冲扩散小圆点（设计稿中的 ping 动画）
class _PulsingDot extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _PulsingDot({required this.controller, required this.color});

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
                  color: color.withValues(alpha: 0.45 * (1 - t)),
                ),
              );
            },
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ],
      ),
    );
  }
}
