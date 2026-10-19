import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/event_args.dart';
import 'package:aboutme/plugins/habits/models/completion_record.dart';
import 'package:aboutme/plugins/habits/models/skill.dart';
import 'package:aboutme/plugins/habits/sample_data.dart';

class SkillController {
  final StorageManager storage;
  static const _skillsKey = 'habits/skills.json';
  List<Skill> _skills = [];

  SkillController(this.storage) {
    loadSkills();
  }

  Future<List<CompletionRecord>> getSkillCompletionRecords(
    String skillId,
  ) async {
    try {
      final data = await AboutmeDataService.instance.readPath(
        'habits/records/$skillId.json',
        [],
      );
      List<Map<String, dynamic>> recordMaps = [];
      if (data is List) {
        recordMaps = List<Map<String, dynamic>>.from(
          data.whereType<Map>().where((m) => m.isNotEmpty),
        );
      }
      return recordMaps
          .map((e) => CompletionRecord.fromMap(e))
          .where((r) => r != null)
          .toList();
    } catch (e) {
      print('Error loading completion records: $e');
      return [];
    }
  }

  Future<List<Skill>> loadSkills() async {
    try {
      final data = await AboutmeDataService.instance.readPath(_skillsKey, []);
      List<Map<String, dynamic>> skillMaps = [];
      if (data is List) {
        skillMaps = List<Map<String, dynamic>>.from(
          data.whereType<Map>().where((m) => m.isNotEmpty),
        );
      }

      _skills =
          skillMaps
              .map((e) => Skill.fromMap(e))
              .where((s) => s != null)
              .toList();

      return _skills;
    } catch (e) {
      print('Error loading skills: $e');
      return _skills = [];
    }
  }

  /// 创建示例技能数据（存储为空时写入，供首次打开引导选择调用）
  Future<void> createDefaultSkills() async {
    final existing = await AboutmeDataService.instance.readPath(_skillsKey, []);
    if (existing is List && existing.isNotEmpty) return;

    // 使用示例数据创建默认技能
    final sampleData = HabitsSampleData.getSampleData();
    final skillMaps = sampleData['skills'] as List<Map<String, dynamic>>;
    final defaultSkills = skillMaps.map((m) => Skill.fromMap(m)).toList();

    _skills = defaultSkills;
    await AboutmeDataService.instance.writePath(
      _skillsKey,
      defaultSkills.map((s) => s.toMap()).toList(),
    );
    print('Created default skills: ${defaultSkills.length} items');
  }

  List<Skill> getSkills() {
    return _skills;
  }

  Skill? getSkillById(String id) {
    try {
      return _skills.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveSkill(Skill skill) async {
    final index = _skills.indexWhere((s) => s.id == skill.id);

    if (index >= 0) {
      _skills[index] = skill;
    } else {
      _skills.add(skill);
    }
    await AboutmeDataService.instance.writePath(
      _skillsKey,
      _skills.map((s) => s.toMap()).toList(),
    );

    // 广播技能数据变更事件，同步小组件
    EventManager.instance.broadcast(
      'skill_data_changed',
      Value({'skill': skill}),
    );

    // 同步到小组件
    await _syncWidget();
  }

  Future<void> deleteSkill(String id) async {
    _skills.removeWhere((s) => s.id == id);
    await AboutmeDataService.instance.writePath(
      _skillsKey,
      _skills.map((s) => s.toMap()).toList(),
    );

    // 广播技能数据变更事件，同步小组件
    EventManager.instance.broadcast(
      'skill_data_changed',
      Value({'skillId': id}),
    );

    // 同步到小组件
    await _syncWidget();
  }

  Future<void> _syncWidget() async {
    await PluginWidgetSyncHelper.instance.syncHabits();
  }

  /// Gets a skill by its title.
  /// Returns null if:
  /// - title is null or empty
  /// - no skill with matching title is found
  /// - multiple skills with same title exist (to avoid ambiguity)
  Skill? getSkillByTitle(String? title) {
    if (title == null || title.isEmpty) {
      return null;
    }

    final matchingSkills = _skills.where((s) => s.title == title).toList();

    if (matchingSkills.isEmpty) {
      return null;
    }

    if (matchingSkills.length > 1) {
      return null; // Avoid returning ambiguous results
    }

    return matchingSkills.first;
  }
}
