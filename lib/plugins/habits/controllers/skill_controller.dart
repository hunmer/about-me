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
  List<Skill> _skills = [];

  /// 初始数据加载（构造即触发），供 UI 等待首次数据就绪
  late final Future<List<Skill>> initialized;

  SkillController(this.storage) {
    initialized = loadSkills();
  }

  Future<List<CompletionRecord>> getSkillCompletionRecords(
    String skillId,
  ) async {
    try {
      final res = await AboutmeDataService.instance.get('habits', 'getRecords', {
        'parentId': skillId,
      });
      if (res['success'] != true) {
        throw Exception('加载完成记录失败: ${res['error']}');
      }
      final payload = res['data'];
      final recordsData = payload is Map ? payload['data'] : null;

      List<Map<String, dynamic>> recordMaps = [];
      if (recordsData is List) {
        recordMaps = List<Map<String, dynamic>>.from(
          recordsData.whereType<Map>().where((m) => m.isNotEmpty),
        );
      }
      return recordMaps.map((e) => CompletionRecord.fromMap(e)).toList();
    } catch (e) {
      print('Error loading completion records: $e');
      return [];
    }
  }

  Future<List<Skill>> loadSkills() async {
    try {
      final res = await AboutmeDataService.instance.get(
        'habits', 'getSkills',
      );
      if (res['success'] != true) {
        throw Exception('加载技能失败: ${res['error']}');
      }
      final payload = res['data'];
      final skillsData = payload is Map ? payload['data'] : null;

      List<Map<String, dynamic>> skillMaps = [];
      if (skillsData is List) {
        skillMaps = List<Map<String, dynamic>>.from(
          skillsData.whereType<Map>().where((m) => m.isNotEmpty),
        );
      }

      _skills = skillMaps.map((e) => Skill.fromMap(e)).toList();

      return _skills;
    } catch (e) {
      print('Error loading skills: $e');
      return _skills = [];
    }
  }

  /// 创建示例技能数据（存储为空时写入，供首次打开引导选择调用）
  Future<void> createDefaultSkills() async {
    final existing = _skills.isNotEmpty ? _skills : await loadSkills();
    if (existing.isNotEmpty) return;

    // 使用示例数据创建默认技能（SDK 端按空集合判重）
    final sampleData = HabitsSampleData.getSampleData();
    await AboutmeDataService.instance.call('habits', 'seedExamples', {
      'skills': sampleData['skills'],
    });
    await loadSkills();
    print('Created default skills: ${_skills.length} items');
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
    await AboutmeDataService.instance.call(
      'habits',
      index >= 0 ? 'updateSkill' : 'createSkill',
      skill.toMap(),
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
    await AboutmeDataService.instance.call(
      'habits', 'deleteSkill', {'id': id},
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
