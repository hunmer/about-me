import 'dart:convert';
import 'dart:io';

import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_schema_builder.dart';
import 'package:aboutme/plugins/timer/timer_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_models/repositories/habits/habits_repository.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_models/usecases/habits/habits_usecase.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_models/utils/result.dart';

class _FakeHabitsRepository implements IHabitsRepository {
  HabitDto? createdHabit;
  SkillDto? createdSkill;

  @override
  Future<Result<HabitDto>> createHabit(HabitDto habit) async {
    createdHabit = habit;
    return Result.success(habit);
  }

  @override
  Future<Result<SkillDto>> createSkill(SkillDto skill) async {
    createdSkill = skill;
    return Result.success(skill);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final configs = jsonDecode(
    File('lib/plugins/agent_chat/tools/timer.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('timer 工具描述方法名与 JS API 注册名一致', () {
    final methods = TimerPlugin().defineJSAPI();
    // timer.json 的 key 带插件前缀，与 FC 分发时的 methodName 剥前缀逻辑一致
    final describedMethods = configs.keys
        .map((k) => k.startsWith('timer_') ? k.substring(6) : k)
        .toSet();
    for (final method in describedMethods) {
      expect(methods.containsKey(method), isTrue, reason: method);
    }
    for (final key in methods.keys) {
      expect(describedMethods.contains(key), isTrue, reason: key);
    }
  });

  test('getTimerStatus 不传 timerId 时不再被分发层判为缺少必填参数', () {
    final config = ToolConfig.fromJson(
      configs['timer_getTimerStatus'] as Map<String, dynamic>,
    );
    // schema 仍要求 timerId 时，Agent 的无参状态查询会在到达实现层前被拒绝，
    // 只能靠猜测 ID 重试（测试会话 198ce5c3 的失败模式）
    expect(
      ToolSchemaBuilder.missingRequiredParameters(config, {}),
      isEmpty,
    );
    expect(
      ToolSchemaBuilder.invocationParameters(config)
          .singleWhere((p) => p.name == 'timerId')
          .optional,
      isTrue,
    );
  });

  test('createHabit/createSkill 传入空串 id 时回退为生成的 uuid', () async {
    final repository = _FakeHabitsRepository();
    final useCase = HabitsUseCase(repository);

    final habitResult = await useCase.createHabit({
      'title': '每天阅读',
      'durationMinutes': 30,
      'id': '',
    });
    expect(habitResult.isSuccess, isTrue);
    expect((habitResult.dataOrNull!['id'] as String).isNotEmpty, isTrue);
    expect(repository.createdHabit!.id, isNotEmpty);

    final skillResult = await useCase.createSkill({
      'title': '编程',
      'id': '  ',
    });
    expect(skillResult.isSuccess, isTrue);
    expect((skillResult.dataOrNull!['id'] as String).isNotEmpty, isTrue);
    expect(repository.createdSkill!.id, isNotEmpty);
  });
}
