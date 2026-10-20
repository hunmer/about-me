import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_extraction_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';

void main() {
  late DateTime clock;
  late Map<String, dynamic> disk;
  late AIAgent agent;
  late List<List<Map<String, dynamic>>> batches;
  late MemoryExtractionService service;
  bool succeeds = true;

  MemoryExtractionService createService({
    Future<bool> Function(AIAgent, List<Map<String, dynamic>>)? extraction,
  }) => MemoryExtractionService(
    now: () => clock,
    load: () async => jsonDecode(jsonEncode(disk)) as Map<String, dynamic>,
    save: (state) async {
      disk = state;
    },
    resolveAgent: (_) async => agent,
    extract:
        extraction ??
        (_, turns) async {
          batches.add(turns);
          return succeeds;
        },
  );

  Future<void> turn(int i, {String channel = 'a'}) => service.recordTurn(
    agent: agent,
    scope: 'chat',
    channelId: channel,
    turnId: '$i',
    userText: '用户$i',
    assistantText: '回复$i',
  );

  setUp(() {
    clock = DateTime(2026, 10, 20, 12);
    disk = {};
    batches = [];
    succeeds = true;
    agent = AIAgent.fromJson({
      'id': 'agent',
      'name': 'test',
      'description': '',
      'serviceProviderId': 'test',
      'baseUrl': 'https://example.com/v1',
      'alivenessConfig': {'memoryEnabled': true},
    });
    service = createService();
  });

  test('默认配置为10轮；时间模式默认10分钟，序列化和copyWith保留', () {
    final config = AlivenessConfig.fromJson({});
    expect(config.memoryExtractionMode, 'rounds');
    expect(config.memoryExtractionRounds, 10);
    expect(config.memoryExtractionIntervalMin, 10);
    final restored = AlivenessConfig.fromJson(
      config
          .copyWith(
            memoryExtractionMode: 'interval',
            memoryExtractionIntervalMin: 20,
          )
          .toJson(),
    );
    expect(restored.memoryExtractionMode, 'interval');
    expect(restored.memoryExtractionRounds, 10);
    expect(restored.memoryExtractionIntervalMin, 20);
  });

  test('前9轮不提取，第10轮批量包含完整10轮；成功后清空并保存水位', () async {
    for (int i = 1; i < 10; i++) {
      await turn(i);
    }
    expect(batches, isEmpty);
    await turn(10);
    expect(batches.single.length, 10);
    expect(batches.single.first['user'], '用户1');
    expect(batches.single.last['assistant'], '回复10');
    final state = disk.values.single;
    expect(state['pending'], isEmpty);
    expect(state['lastTurnId'], '10');
    expect(state['lastExtractedAt'], clock.toIso8601String());
    await turn(10);
    expect(batches.length, 1);
  });

  test('各频道独立累计，重启恢复未满阈值的轮次', () async {
    for (int i = 1; i <= 5; i++) {
      await turn(i);
    }
    for (int i = 1; i <= 5; i++) {
      await turn(i, channel: 'b');
    }
    expect(batches, isEmpty);
    service = createService();
    for (int i = 6; i <= 10; i++) {
      await turn(i);
    }
    expect(batches.length, 1);
    expect(
      (disk.values.firstWhere((s) => s['channelId'] == 'b')['pending'] as List)
          .length,
      5,
    );
  });

  test('轮数模式不会因时间到期触发', () async {
    await turn(1);
    clock = clock.add(const Duration(days: 1));
    await service.checkDue();
    expect(batches, isEmpty);
  });

  test('时间模式不会因轮数触发，10分钟时无需新消息即可提取，无待提取时不调用', () async {
    agent = agent.copyWith(
      alivenessConfig: agent.alivenessConfig!.copyWith(
        memoryExtractionMode: 'interval',
      ),
    );
    for (int i = 1; i <= 10; i++) {
      await turn(i);
    }
    expect(batches, isEmpty);
    clock = clock.add(const Duration(minutes: 9));
    await service.checkDue();
    expect(batches, isEmpty);
    service = createService();
    clock = clock.add(const Duration(minutes: 1));
    await service.checkDue();
    expect(batches.single.length, 10);
    clock = clock.add(const Duration(minutes: 10));
    await service.checkDue();
    expect(batches.length, 1);
  });

  test('失败不推进成功水位，保留完整批次，冷却后重试', () async {
    succeeds = false;
    for (int i = 1; i <= 10; i++) {
      await turn(i);
    }
    expect((disk.values.single['pending'] as List).length, 10);
    expect(disk.values.single['lastExtractedAt'], isNull);
    await service.checkDue();
    expect(batches.length, 1);
    succeeds = true;
    clock = clock.add(const Duration(minutes: 1));
    await service.checkDue();
    expect(batches.length, 2);
    expect(disk.values.single['pending'], isEmpty);
  });

  test('提取期间到达的新轮次保留，不被成功批次误清除', () async {
    agent = agent.copyWith(
      alivenessConfig: agent.alivenessConfig!.copyWith(
        memoryExtractionRounds: 1,
      ),
    );
    final started = Completer<void>();
    final finish = Completer<bool>();
    service = createService(
      extraction: (_, turns) async {
        started.complete();
        return finish.future;
      },
    );
    final first = turn(1);
    await started.future;
    await turn(2);
    finish.complete(true);
    await first;
    expect((disk.values.single['pending'] as List).single['id'], '2');
    expect(disk.values.single['lastTurnId'], '1');
  });

  test('关闭记忆管理后暂停已持久化批次，重新启用可继续', () async {
    await turn(1);
    agent = agent.copyWith(
      alivenessConfig: agent.alivenessConfig!.copyWith(
        memoryEnabled: false,
        memoryExtractionRounds: 1,
      ),
    );
    await service.checkDue();
    expect(batches, isEmpty);
    agent = agent.copyWith(
      alivenessConfig: agent.alivenessConfig!.copyWith(memoryEnabled: true),
    );
    await service.checkDue();
    expect(batches.single.length, 1);
  });
}
