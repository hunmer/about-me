import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/event_args.dart';
import 'package:aboutme/plugins/habits/models/habit.dart';
import 'package:aboutme/plugins/habits/controllers/timer_controller.dart';
import 'package:aboutme/plugins/habits/controllers/skill_controller.dart';
import 'package:aboutme/plugins/habits/sample_data.dart';

typedef TimerModeListener = void Function(String habitId, bool isCountdown);

/// 习惯缓存更新事件参数（携带数据，性能优化）
class HabitCacheUpdatedEventArgs extends EventArgs {
  /// 所有习惯列表
  final List<Habit> habits;

  /// 习惯数量
  final int count;

  /// 缓存日期
  final DateTime cacheDate;

  HabitCacheUpdatedEventArgs({
    required this.habits,
    required this.cacheDate,
  }) : count = habits.length,
       super('habits_cache_updated');
}

class HabitController {
  final List<TimerModeListener> _timerModeListeners = [];
  final StorageManager storage;
  final TimerController timerController;
  final SkillController skillController;
  List<Habit> _habits = [];

  /// 初始数据加载（构造即触发），供 UI 等待首次数据就绪
  late final Future<void> initialized;

  HabitController(
    this.storage, {
    required this.timerController,
    required this.skillController,
  }) {
    initialized = _initialize();
  }

  Future<void> _initialize() async {
    // 先确保技能数据加载完成
    await skillController.loadSkills();
    // 再加载习惯数据
    await loadHabits();
  }

  Future<List<Habit>> loadHabits() async {
    try {
      final res = await AboutmeDataService.instance.get(
        'habits', 'getSnapshot',
      );
      if (res['success'] != true) {
        throw Exception('加载习惯失败: ${res['error']}');
      }
      final snapshot = res['data'];
      final habitsData = snapshot is Map ? snapshot['habits'] : null;

      List<Map<String, dynamic>> habitMaps = [];
      if (habitsData is List) {
        habitMaps = List<Map<String, dynamic>>.from(
          habitsData.whereType<Map>().where((m) => m.isNotEmpty),
        );
      }

      _habits = habitMaps.map((e) => Habit.fromMap(e)).toList();

      return _habits;
    } catch (e) {
      print('Error loading habits: $e');
      return _habits = [];
    }
  }

  /// 创建示例习惯数据（存储为空时写入，供首次打开引导选择调用）
  Future<void> createDefaultHabits() async {
    final existing = _habits.isNotEmpty ? _habits : await loadHabits();
    if (existing.isNotEmpty) return;

    // 使用示例数据创建默认习惯与对应完成记录（SDK 端按空集合判重）
    final sampleData = HabitsSampleData.getSampleData();
    await AboutmeDataService.instance.call('habits', 'seedExamples', {
      'habits': sampleData['habits'],
      'records': sampleData['records'],
    });
    await loadHabits();
    print('Created default habits: ${_habits.length} items');
  }

  List<Habit> getHabits() => _habits;

  Future<void> saveHabit(Habit habit) async {
    final habits = getHabits();
    final index = habits.indexWhere((h) => h.id == habit.id);

    if (index >= 0) {
      habits[index] = habit;
    } else {
      habits.add(habit);
    }

    await AboutmeDataService.instance.call(
      'habits',
      index >= 0 ? 'update' : 'create',
      habit.toMap(),
    );

    // 广播习惯数据变更事件，同步小组件
    EventManager.instance.broadcast('habit_data_changed', Value({'habit': habit}));

    // 广播缓存更新事件（携带数据，性能优化）
    EventManager.instance.broadcast(
      'habits_cache_updated',
      HabitCacheUpdatedEventArgs(
        habits: List.from(habits),
        cacheDate: DateTime.now(),
      ),
    );

    // 同步到小组件
    await _syncWidget();
  }

  Future<void> deleteHabit(String id) async {
    final habits = getHabits();
    habits.removeWhere((h) => h.id == id);
    await AboutmeDataService.instance.call('habits', 'delete', {'id': id});

    // 广播习惯数据变更事件，同步小组件
    EventManager.instance.broadcast('habit_data_changed', Value({'habitId': id}));

    // 广播缓存更新事件（携带数据，性能优化）
    EventManager.instance.broadcast(
      'habits_cache_updated',
      HabitCacheUpdatedEventArgs(
        habits: List.from(habits),
        cacheDate: DateTime.now(),
      ),
    );

    // 同步到小组件
    await _syncWidget();
  }

  void addTimerModeListener(TimerModeListener listener) {
    _timerModeListeners.add(listener);
  }

  void removeTimerModeListener(TimerModeListener listener) {
    _timerModeListeners.remove(listener);
  }

  void notifyTimerModeChanged(String habitId, bool isCountdown) {
    for (final listener in _timerModeListeners) {
      listener(habitId, isCountdown);
    }
  }

  // 同步小组件数据
  Future<void> _syncWidget() async {
    await PluginWidgetSyncHelper.instance.syncHabits();
  }

  /// 更新习惯的总累计时长（仅在记录变更时调用，避免重复计算）
  Future<void> updateTotalDuration(String habitId, int totalMinutes) async {
    final habits = getHabits();
    final index = habits.indexWhere((h) => h.id == habitId);

    if (index >= 0) {
      final oldHabit = habits[index];
      // 创建新的习惯对象，更新总时长
      final updatedHabit = Habit(
        id: oldHabit.id,
        title: oldHabit.title,
        notes: oldHabit.notes,
        group: oldHabit.group,
        icon: oldHabit.icon,
        image: oldHabit.image,
        reminderDays: oldHabit.reminderDays,
        intervalDays: oldHabit.intervalDays,
        durationMinutes: oldHabit.durationMinutes,
        tags: oldHabit.tags,
        skillId: oldHabit.skillId,
        totalDurationMinutes: totalMinutes,
      );

      habits[index] = updatedHabit;
      await AboutmeDataService.instance.call('habits', 'update', {
        'id': habitId,
        'totalDurationMinutes': totalMinutes,
      });

      // 广播习惯数据变更事件
      EventManager.instance.broadcast('habit_data_changed', Value({'habit': updatedHabit}));

      // 广播缓存更新事件（携带数据，性能优化）
      EventManager.instance.broadcast(
        'habits_cache_updated',
        HabitCacheUpdatedEventArgs(
          habits: List.from(habits),
          cacheDate: DateTime.now(),
        ),
      );
    }
  }
}
