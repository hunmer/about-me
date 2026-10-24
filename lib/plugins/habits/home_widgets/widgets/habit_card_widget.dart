/// 习惯追踪插件 - 习惯卡片小组件
library;

import 'dart:async';
import 'package:aboutme/core/event/event_args.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/habits/models/habit.dart';
import 'package:aboutme/plugins/habits/models/skill.dart';
import 'package:aboutme/plugins/habits/controllers/habit_controller.dart';
import 'package:aboutme/plugins/habits/controllers/timer_controller.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/habits/habits_plugin.dart';
import 'package:aboutme/plugins/habits/widgets/timer_dialog.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/widgets/common/habit_card.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// HabitCard 数据模型
class HabitCardData {
  final String id;
  final String title;
  final String? icon;
  final String? skillTitle;
  final String? group;
  final int themeColor;
  final int completionCount;
  final int todayCount;
  final int totalDurationMinutes;
  final List<bool> last7DaysStatus;
  final int durationMinutes;
  final int currentTotalDurationMinutes;
  final bool isTiming;
  final String timerText;

  const HabitCardData({
    required this.id,
    required this.title,
    this.icon,
    this.skillTitle,
    this.group,
    required this.themeColor,
    required this.completionCount,
    required this.todayCount,
    required this.totalDurationMinutes,
    required this.last7DaysStatus,
    required this.durationMinutes,
    required this.currentTotalDurationMinutes,
    required this.isTiming,
    required this.timerText,
  });

  /// 从 JSON 创建
  factory HabitCardData.fromJson(Map<String, dynamic> json) {
    final last7Days =
        (json['last7DaysStatus'] as List<dynamic>?)
            ?.map((e) => e as bool)
            .toList() ??
        List.filled(7, false);

    return HabitCardData(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String?,
      skillTitle: json['skillTitle'] as String?,
      group: json['group'] as String?,
      themeColor: json['themeColor'] as int? ?? 0xFF607AFB,
      completionCount: json['completionCount'] as int? ?? 0,
      todayCount: json['todayCount'] as int? ?? 0,
      totalDurationMinutes: json['totalDurationMinutes'] as int? ?? 0,
      last7DaysStatus: last7Days,
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      currentTotalDurationMinutes:
          json['currentTotalDurationMinutes'] as int? ?? 0,
      isTiming: json['isTiming'] as bool? ?? false,
      timerText: json['timerText'] as String? ?? '00:00',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'skillTitle': skillTitle,
      'group': group,
      'themeColor': themeColor,
      'completionCount': completionCount,
      'todayCount': todayCount,
      'totalDurationMinutes': totalDurationMinutes,
      'last7DaysStatus': last7DaysStatus,
      'durationMinutes': durationMinutes,
      'currentTotalDurationMinutes': currentTotalDurationMinutes,
      'isTiming': isTiming,
      'timerText': timerText,
    };
  }
}

class HabitCard extends StatefulWidget {
  final Habit? habit;
  final HabitCardData? data;
  final Skill? skill;
  final HabitController? controller;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const HabitCard({
    super.key,
    this.habit,
    this.data,
    this.skill,
    this.controller,
    this.onTap,
    this.onLongPress,
  }) : assert(habit != null || data != null);

  /// 从 props 创建实例（用于公共小组件系统）
  factory HabitCard.fromProps(Map<String, dynamic> props, HomeWidgetSize size) {
    final data =
        props['data'] != null
            ? HabitCardData.fromJson(props['data'] as Map<String, dynamic>)
            : null;

    return HabitCard(
      data: data,
      onTap: props['onTap'] as VoidCallback?,
      onLongPress: props['onLongPress'] as VoidCallback?,
    );
  }

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  late Color _themeColor;
  int _completionCount = 0;
  int _todayCount = 0;
  int _totalDurationMinutes = 0;
  List<bool> _last7DaysStatus = List.filled(7, false);
  bool _isTiming = false;
  String _timerText = "00:00";
  TimerController? _timerController;
  Timer? _uiUpdateTimer;
  Habit? _currentHabit;

  /// 判断是否使用 data 模式（command widget）
  bool get _useDataMode => widget.data != null;

  @override
  void initState() {
    super.initState();

    if (_useDataMode) {
      // Data 模式：直接使用 widget.data
      _initFromData();
    } else {
      // Habit 模式：从 controller 加载数据
      _initFromHabit();
    }
  }

  /// 从 data 初始化（command widget 模式）
  void _initFromData() {
    final data = widget.data!;
    _themeColor = Color(data.themeColor);
    _completionCount = data.completionCount;
    _todayCount = data.todayCount;
    _totalDurationMinutes = data.totalDurationMinutes;
    _last7DaysStatus = data.last7DaysStatus;
    _isTiming = data.isTiming;
    _timerText = data.timerText;
  }

  @override
  void didUpdateWidget(covariant HabitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_useDataMode) {
      _initFromData();
    }
  }

  /// 从 habit 初始化（原有模式）
  void _initFromHabit() {
    _currentHabit = widget.habit!;
    _themeColor = _getColor(widget.habit!.skillId ?? widget.habit!.id);

    final habitsPlugin =
        PluginManager.instance.getPlugin('habits') as HabitsPlugin?;
    _timerController = habitsPlugin?.timerController ?? TimerController();

    _loadStats();
    _checkTimerStatus();

    EventManager.instance.subscribe(
      'habit_timer_started',
      _onTimerStateChanged,
    );
    EventManager.instance.subscribe(
      'habit_timer_stopped',
      _onTimerStateChanged,
    );
    EventManager.instance.subscribe('habit_data_changed', _onHabitDataChanged);
    EventManager.instance.subscribe('habits_cache_updated', _onStatsChanged);
    EventManager.instance.subscribe(
      'habit_completion_record_saved',
      _onStatsChanged,
    );
  }

  @override
  void dispose() {
    _stopUIUpdateTimer();
    if (!_useDataMode) {
      EventManager.instance.unsubscribe(
        'habit_timer_started',
        _onTimerStateChanged,
      );
      EventManager.instance.unsubscribe(
        'habit_timer_stopped',
        _onTimerStateChanged,
      );
      EventManager.instance.unsubscribe(
        'habit_data_changed',
        _onHabitDataChanged,
      );
      EventManager.instance.unsubscribe('habits_cache_updated', _onStatsChanged);
      EventManager.instance.unsubscribe(
        'habit_completion_record_saved',
        _onStatsChanged,
      );
    }
    super.dispose();
  }

  void _onStatsChanged(EventArgs args) {
    if (!mounted) return;
    if (args is Value && args.value is Map) {
      final habitId = (args.value as Map)['habitId'];
      if (habitId != null && habitId != widget.habit?.id) return;
    }
    debugPrint(
      '[HabitsSync] reload card habit=${widget.habit?.id} event=${args.runtimeType}',
    );
    _loadStats();
  }

  void _onHabitDataChanged(EventArgs args) {
    if (args is Value) {
      final data = args.value;
      if (data is Map && data.containsKey('habit')) {
        final updatedHabit = data['habit'] as Habit;
        if (updatedHabit.id == widget.habit?.id && mounted) {
          setState(() {
            _currentHabit = updatedHabit;
          });
        }
      }
    }
  }

  void _onTimerStateChanged(EventArgs args) {
    if (args is HabitTimerEventArgs && args.habitId == widget.habit?.id) {
      if (mounted) {
        setState(() {
          _isTiming = args.isRunning;
          _timerText = _formatDuration(args.elapsedSeconds);

          if (!_isTiming) {
            _stopUIUpdateTimer();
          } else {
            _startUIUpdateTimer();
          }
        });
      }
    }
  }

  void _checkTimerStatus() {
    if (_timerController == null) return;

    final isTiming = _timerController!.isHabitTiming(widget.habit!.id);
    final timerData = _timerController!.getTimerData(widget.habit!.id);

    if (mounted) {
      setState(() {
        _isTiming = isTiming;
        if (timerData != null) {
          _timerText = _formatDuration(timerData['elapsedSeconds'] ?? 0);
        }
      });
    }

    if (isTiming) {
      _startUIUpdateTimer();
    } else {
      _stopUIUpdateTimer();
    }
  }

  void _startUIUpdateTimer() {
    _stopUIUpdateTimer();
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_timerController == null || widget.habit == null) return;

      final timerData = _timerController!.getTimerData(widget.habit!.id);
      if (timerData != null) {
        final elapsed = timerData['elapsedSeconds'] ?? 0;
        final newText = _formatDuration(elapsed);
        if (mounted) {
          setState(() {
            _timerText = newText;
          });
        }
      }
    });
  }

  void _stopUIUpdateTimer() {
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _loadStats() async {
    if (!mounted || widget.habit == null) return;

    final habitsPlugin =
        PluginManager.instance.getPlugin('habits') as HabitsPlugin?;
    if (habitsPlugin == null) return;

    final recordController = habitsPlugin.getRecordController();

    try {
      final count = await recordController.getCompletionCount(widget.habit!.id);
      final duration = await recordController.getTotalDuration(
        widget.habit!.id,
      );

      final records = await recordController.getHabitCompletionRecords(
        widget.habit!.id,
      );
      final now = DateTime.now();
      final last7Days = List.generate(7, (index) {
        return now.subtract(Duration(days: 6 - index));
      });

      final status =
          last7Days
              .map((date) {
                return records.any(
                  (r) =>
                      r.date.year == date.year &&
                      r.date.month == date.month &&
                      r.date.day == date.day,
                );
              })
              .cast<bool>()
              .toList();

      final today = DateTime.now();
      final todayRecords = records.where(
        (r) =>
            r.date.year == today.year &&
            r.date.month == today.month &&
            r.date.day == today.day,
      );

      if (mounted) {
        setState(() {
          _completionCount = count;
          _todayCount = todayRecords.length;
          _totalDurationMinutes = duration;
          _last7DaysStatus = status;
        });
        debugPrint(
          '[HabitsSync] card updated habit=${widget.habit!.id} '
          'count=$count today=$_todayCount minutes=$duration',
        );
      }
    } catch (e) {
      debugPrint('Error loading habit stats: $e');
    }
  }

  Color _getColor(String id) {
    final colors = [
      const Color(0xFF607AFB),
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFF9D81E8),
      const Color(0xFFFFD93D),
      const Color(0xFFFF8D29),
    ];
    return colors[id.hashCode.abs() % colors.length];
  }

  String _formatTotalDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    // Data 模式：使用公共组件渲染
    if (_useDataMode && widget.data != null) {
      return HabitCardWidget(
        data: widget.data!,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
      );
    }

    // Habit 模式：使用原有的交互式渲染
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: JellyBox(
              padding: const EdgeInsets.all(12),
              radius: BorderRadius.circular(12),
              raised: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _themeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(_icon, color: _themeColor, size: 24),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              style: DsTypography.heading.copyWith(
                                color: theme.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _skillTitle,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Heatmap
                  SizedBox(
                    height: 24,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Row(
                          children:
                              _last7DaysStatus.asMap().entries.map((entry) {
                                final index = entry.key;
                                final isActive = entry.value;
                                final date = DateTime.now().subtract(
                                  Duration(days: 6 - index),
                                );

                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color:
                                          isActive
                                              ? _themeColor
                                              : theme.surfaceAlt,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${date.day}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isActive
                                                  ? DsColors.white
                                                  : theme.textSub,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        if (_todayCount > 0)
                          Positioned(
                            right: -4,
                            top: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _themeColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.background,
                                  width: 1.5,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Center(
                                child: Text(
                                  '$_todayCount',
                                  style: const TextStyle(
                                    color: DsColors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Stats
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        // 文本
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_formatTotalDuration(_totalDurationMinutes)}($_completionCount)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.text,
                              ),
                            ),
                            Text(
                              ' / $_durationMinutes m',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textSub,
                              ),
                            ),
                            if (_currentTotalDurationMinutes > 0) ...[
                              Text(
                                ' | ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textSub,
                                ),
                              ),
                              Text(
                                '总${_formatTotalDuration(_currentTotalDurationMinutes)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textSub,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 进度条
                        DSLinearProgress(
                          value:
                              _durationMinutes > 0
                                  ? (_totalDurationMinutes / _durationMinutes)
                                  : 0.0,
                          height: 3,
                          color: _themeColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: Pressable(
                      onPressed: _handleTimerAction,
                      builder: (context, states) {
                        final pressed = states.contains(WidgetState.pressed);
                        return AnimatedScale(
                          scale: pressed ? 0.97 : 1.0,
                          duration: const Duration(milliseconds: 120),
                          child: JellyBox(
                            height: 36,
                            radius: BorderRadius.circular(8),
                            color:
                                _isTiming
                                    ? _themeColor
                                    : _themeColor.withValues(alpha: 0.2),
                            alignment: Alignment.center,
                            raised: _isTiming,
                            child: Center(
                              child:
                                  _isTiming
                                      ? Text(
                                        _timerText,
                                        style: const TextStyle(
                                          color: DsColors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      )
                                      : DsIcon(
                                        DsIconKind.play,
                                        color: _themeColor,
                                        size: 24,
                                      ),
                            ),
                          ),
                        );
                      },
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

  /// 获取标题
  String get _title => widget.data?.title ?? widget.habit?.title ?? '';

  /// 获取图标
  IconData get _icon {
    final iconCode = widget.data?.icon ?? widget.habit?.icon;
    if (iconCode != null) {
      return dynamicIconData(int.parse(iconCode), fontFamily: 'MaterialIcons');
    }
    final skillIconCode = widget.skill?.icon;
    if (skillIconCode != null) {
      return dynamicIconData(int.parse(skillIconCode), fontFamily: 'MaterialIcons');
    }
    return Icons.auto_awesome;
  }

  /// 获取技能标题
  String get _skillTitle =>
      widget.data?.skillTitle ??
      widget.skill?.title ??
      widget.habit?.group ??
      'Uncategorized';

  /// 获取目标时长
  int get _durationMinutes =>
      widget.data?.durationMinutes ?? widget.habit?.durationMinutes ?? 0;

  /// 获取当前总累计时长
  int get _currentTotalDurationMinutes =>
      widget.data?.currentTotalDurationMinutes ??
      _currentHabit?.totalDurationMinutes ??
      0;

  Future<void> _handleTimerAction() async {
    if (widget.habit == null || widget.controller == null) return;

    final result = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => _TimerDialogWrapper(
            habit: widget.habit!,
            controller: widget.controller!,
            timerController: _timerController!,
          ),
    );

    if (result == true) {
      await _loadStats();
    }
  }
}

class _TimerDialogWrapper extends StatelessWidget {
  final Habit habit;
  final HabitController controller;
  final TimerController timerController;

  const _TimerDialogWrapper({
    required this.habit,
    required this.controller,
    required this.timerController,
  });

  @override
  Widget build(BuildContext context) {
    final timerData = timerController.getTimerData(habit.id);
    return TimerDialog(
      habit: habit,
      controller: controller,
      initialTimerData: timerData,
    );
  }
}
