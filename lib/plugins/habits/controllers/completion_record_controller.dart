import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/event/event_args.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/habits/controllers/habit_controller.dart';
import 'package:aboutme/plugins/habits/controllers/skill_controller.dart';
import 'package:aboutme/plugins/habits/models/completion_record.dart';

class CompletionRecordController {
  final StorageManager storage;
  final HabitController habitController;
  final SkillController skillControlle;

  CompletionRecordController(
    this.storage, {
    required this.habitController,
    required this.skillControlle,
  });

  /// 业务命令结果校验：失败抛错（与旧文件读写失败路径一致）
  dynamic _resultData(Map<String, dynamic> res) {
    if (res['success'] != true) {
      throw Exception('habits 数据命令失败: ${res['error']}');
    }
    return res['data'];
  }

  List<CompletionRecord> _decodeRecords(dynamic payload) {
    final data = payload is Map ? payload['data'] : null;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .where((m) => m.isNotEmpty)
        .map((e) => CompletionRecord.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveCompletionRecord(
    String habitId,
    CompletionRecord record,
  ) async {
    await AboutmeDataService.instance.call(
      'habits',
      'addRecord',
      record.toMap(),
    );

    // 更新习惯的总累计时长缓存
    final records = await getHabitCompletionRecords(habitId);
    final totalMinutes = records.fold<int>(
      0,
      (sum, r) => sum + r.duration.inMinutes,
    );
    await habitController.updateTotalDuration(habitId, totalMinutes);

    // 广播完成记录已保存的事件，触发小组件同步
    EventManager.instance.broadcast(
      'habit_completion_record_saved',
      Value({'habitId': habitId, 'record': record}),
    );
  }

  getSkillHabitIds(skillId) async {
    final habits = habitController.getHabits();
    return habits
        .where((habit) => habit.skillId == skillId)
        .map((habit) => habit.id)
        .toList();
  }

  getHabitIds() {
    final habits = habitController.getHabits();
    return habits.map((habit) => habit.id).toList();
  }

  Future<List<CompletionRecord>> getSkillCompletionRecords(
    String skillId,
  ) async {
    final matchingRecords = <CompletionRecord>[];

    // 1. 获取所有属于指定skillId的habitIds
    final skillHabitIds = await getSkillHabitIds(skillId);

    // 2. 获取这些habitIds对应的records
    for (final habitId in skillHabitIds) {
      matchingRecords.addAll(await getHabitCompletionRecords(habitId));
    }

    return matchingRecords;
  }

  Future<int> getTotalDuration(String habitId) async {
    final stats = _resultData(
      await AboutmeDataService.instance.get('habits', 'getStats', {
        'habitId': habitId,
      }),
    ) as Map;
    return (stats['totalDurationMinutes'] as num?)?.toInt() ?? 0;
  }

  Future<int> getCompletionCount(String habitId) async {
    final stats = _resultData(
      await AboutmeDataService.instance.get('habits', 'getStats', {
        'habitId': habitId,
      }),
    ) as Map;
    return (stats['completionCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteCompletionRecord(String recordId) async {
    final res = await AboutmeDataService.instance.call(
      'habits',
      'deleteRecord',
      {'id': recordId},
    );
    if (res['success'] != true) {
      throw Exception('Completion record not found: $recordId');
    }
    final data = res['data'];
    final habitId = data is Map ? data['parentId'] : null;
    if (habitId is! String || habitId.isEmpty) return;

    // 更新习惯的总累计时长缓存
    final records = await getHabitCompletionRecords(habitId);
    final totalMinutes = records.fold<int>(
      0,
      (sum, r) => sum + r.duration.inMinutes,
    );
    await habitController.updateTotalDuration(habitId, totalMinutes);
  }

  Future<void> clearAllCompletionRecords(String habitId) async {
    await AboutmeDataService.instance.call('habits', 'clearRecords', {
      'parentId': habitId,
    });
    // 清空记录后，重置总累计时长为 0
    await habitController.updateTotalDuration(habitId, 0);
  }

  Future<List<CompletionRecord>> getHabitCompletionRecords(
    String habitId,
  ) async {
    final res = await AboutmeDataService.instance.get('habits', 'getRecords', {
      'parentId': habitId,
    });
    return _decodeRecords(_resultData(res));
  }
}
