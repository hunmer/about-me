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

  Future<void> saveCompletionRecord(
    String habitId,
    CompletionRecord record,
  ) async {
    final path = 'habits/records/$habitId.json';
    // readPath 对不存在的文件默认返回 {}，必须显式传 [] 才不会走单条记录分支
    final data = await AboutmeDataService.instance.readPath(path, []);
    final records = <CompletionRecord>[];

    if (data != null) {
      // 处理不同的数据格式
      if (data is List) {
        records.addAll(
          data.whereType<Map>().where((m) => m.isNotEmpty).map((e) {
            final stringKeyMap = Map<String, dynamic>.from(e);
            return CompletionRecord.fromMap(stringKeyMap);
          }),
        );
      } else if (data is Map && data.isNotEmpty) {
        // 如果是单个记录对象
        final stringKeyMap = Map<String, dynamic>.from(data);
        records.add(CompletionRecord.fromMap(stringKeyMap));
      }
    }

    records.add(record);
    await AboutmeDataService.instance.writePath(
      path,
      records.map((r) => r.toMap()).toList(),
    );

    // 更新习惯的总累计时长缓存
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
      final path = 'habits/records/$habitId.json';
      if (await AboutmeDataService.instance.existsPath(path)) {
        final data = await AboutmeDataService.instance.readPath(path);
        if (data != null) {
          if (data is List) {
            matchingRecords.addAll(
              data.whereType<Map>().where((m) => m.isNotEmpty).map((e) {
                final stringKeyMap = Map<String, dynamic>.from(e);
                return CompletionRecord.fromMap(stringKeyMap);
              }),
            );
          } else if (data is Map && data.isNotEmpty) {
            final stringKeyMap = Map<String, dynamic>.from(data);
            matchingRecords.add(CompletionRecord.fromMap(stringKeyMap));
          }
        }
      }
    }

    return matchingRecords;
  }

  Future<int> getTotalDuration(String habitId) async {
    final records = await getHabitCompletionRecords(habitId);
    return records.fold<int>(
      0,
      (sum, record) => sum + record.duration.inMinutes,
    );
  }

  Future<int> getCompletionCount(String habitId) async {
    final records = await getHabitCompletionRecords(habitId);
    return records.length;
  }

  Future<void> deleteCompletionRecord(String recordId) async {
    bool recordFound = false;

    for (final habitId in getHabitIds()) {
      final records = await getHabitCompletionRecords(habitId);
      final initialLength = records.length;
      records.removeWhere((record) => record.id == recordId);

      if (records.length < initialLength) {
        recordFound = true;
        await AboutmeDataService.instance.writePath(
          'habits/records/$habitId.json',
          records.map((r) => r.toMap()).toList(),
        );

        // 更新习惯的总累计时长缓存
        final totalMinutes = records.fold<int>(
          0,
          (sum, r) => sum + r.duration.inMinutes,
        );
        await habitController.updateTotalDuration(habitId, totalMinutes);
        break;
      }
    }

    if (!recordFound) {
      throw Exception('Completion record not found: $recordId');
    }
  }

  Future<void> clearAllCompletionRecords(String habitId) async {
    await AboutmeDataService.instance.writePath(
      'habits/records/$habitId.json',
      [],
    );
    // 清空记录后，重置总累计时长为 0
    await habitController.updateTotalDuration(habitId, 0);
  }

  Future<List<CompletionRecord>> getHabitCompletionRecords(
    String habitId,
  ) async {
    // readPath 对不存在的文件默认返回 {}，必须显式传 [] 才不会走单条记录分支
    final data = await AboutmeDataService.instance.readPath(
      'habits/records/$habitId.json',
      [],
    );

    final records = <CompletionRecord>[];
    if (data is List) {
      records.addAll(
        data.whereType<Map>().where((m) => m.isNotEmpty).map((e) {
          final stringKeyMap = Map<String, dynamic>.from(e);
          return CompletionRecord.fromMap(stringKeyMap);
        }),
      );
    } else if (data is Map && data.isNotEmpty) {
      final stringKeyMap = Map<String, dynamic>.from(data);
      records.add(CompletionRecord.fromMap(stringKeyMap));
    }

    return records;
  }
}
