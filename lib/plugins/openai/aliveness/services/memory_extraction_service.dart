import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'aliveness_store.dart';
import 'memory_service.dart';

/// 独立的记忆批次调度器。每个来源、频道、Agent 保存待处理轮次和成功水位。
/// 时间模式仅在有待处理轮次时运行；重启后恢复，失败不推进成功水位。
class MemoryExtractionService {
  MemoryExtractionService({
    required this.load,
    required this.save,
    required this.resolveAgent,
    required this.extract,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  static final instance = MemoryExtractionService(
    load: AlivenessStore.instance.loadMemoryExtractionState,
    save: AlivenessStore.instance.saveMemoryExtractionState,
    resolveAgent: (id) async {
      try {
        return await AgentController().getAgent(id);
      } catch (_) {
        return null;
      }
    },
    extract: (agent, turns) async {
      final success = await MemoryService.instance.extractFromConversation(
        agent,
        userText: turns
            .asMap()
            .entries
            .map((e) => '[第${e.key + 1}轮 ${e.value['at']}] ${e.value['user']}')
            .join('\n'),
        assistantText: turns
            .asMap()
            .entries
            .map((e) => '[第${e.key + 1}轮] ${e.value['assistant']}')
            .join('\n'),
      );
      if (success) {
        await MemoryService.instance.applyForgetting(
          agent.id,
          halfLifeDays: agent.alivenessConfig!.forgettingHalfLifeDays,
        );
      }
      return success;
    },
  );

  final Future<Map<String, dynamic>> Function() load;
  final Future<void> Function(Map<String, dynamic>) save;
  final Future<AIAgent?> Function(String) resolveAgent;
  final Future<bool> Function(AIAgent, List<Map<String, dynamic>>) extract;
  final DateTime Function() now;
  final _states = <String, Map<String, dynamic>>{};
  final _inFlight = <String>{};
  final _agentRuns = <String, Future<void>>{};
  Future<void>? _loading;
  Future<void> _saving = Future.value();
  Timer? _timer;

  Future<void> _ready() => _loading ??= () async {
    final data = await load();
    for (final entry in data.entries) {
      _states[entry.key] = Map<String, dynamic>.from(entry.value as Map);
    }
  }();

  Future<void> start() async {
    await _ready();
    _timer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(checkDue()),
    );
    unawaited(checkDue());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _persist() {
    // 冻结快照并串行写盘，多个频道同时完成时不会以旧快照覆盖新进度。
    final snapshot = jsonDecode(jsonEncode(_states)) as Map<String, dynamic>;
    final task = _saving.catchError((Object _) {}).then((_) => save(snapshot));
    _saving = task;
    return task;
  }

  Future<void> recordTurn({
    required AIAgent agent,
    required String scope,
    required String channelId,
    required String turnId,
    required String userText,
    required String assistantText,
  }) async {
    try {
      if (agent.alivenessConfig?.memoryEnabled != true ||
          userText.trim().isEmpty ||
          assistantText.trim().isEmpty) {
        return;
      }
      await _ready();
      final key = jsonEncode([scope, channelId, agent.id]);
      final state = _states.putIfAbsent(
        key,
        () => {
          'scope': scope,
          'channelId': channelId,
          'agentId': agent.id,
          'pending': <dynamic>[],
          'lastExtractedAt': null,
          'lastTurnId': null,
        },
      );
      final pending = state['pending'] as List;
      if (state['lastTurnId'] == turnId ||
          pending.any((t) => t['id'] == turnId)) {
        return;
      }
      pending.add({
        'id': turnId,
        'at': now().toIso8601String(),
        'user': userText,
        'assistant': assistantText,
      });
      await _persist();
      debugPrint(
        '[记忆调度] 入队 | $scope:$channelId agent=${agent.id} 待提取=${pending.length}轮',
      );
      await _check(key, agent);
    } catch (e) {
      debugPrint('[记忆调度] 记录失败: $e');
    }
  }

  Future<void> checkDue() async {
    try {
      await _ready();
      final tasks = <Future<void>>[];
      for (final key in _states.keys.toList()) {
        final state = _states[key]!;
        if ((state['pending'] as List).isEmpty || _inFlight.contains(key)) {
          continue;
        }
        final agent = await resolveAgent(state['agentId'] as String);
        if (agent != null) tasks.add(_check(key, agent));
      }
      await Future.wait(tasks);
    } catch (e) {
      debugPrint('[记忆调度] 检查失败: $e');
    }
  }

  Future<void> _check(String key, AIAgent agent) async {
    final state = _states[key]!;
    final config = agent.alivenessConfig;
    final pending = state['pending'] as List;
    if (config?.memoryEnabled != true ||
        pending.isEmpty ||
        _inFlight.contains(key)) {
      return;
    }
    final retryAt = DateTime.tryParse(state['retryAt'] as String? ?? '');
    if (retryAt != null && now().isBefore(retryAt)) return;
    final since =
        DateTime.tryParse(state['lastExtractedAt'] as String? ?? '') ??
        DateTime.parse(pending.first['at'] as String);
    final due = config!.memoryExtractionMode == 'interval'
        ? now().difference(since) >=
              Duration(
                minutes: config.memoryExtractionIntervalMin.clamp(1, 1440),
              )
        : pending.length >= config.memoryExtractionRounds.clamp(1, 100);
    if (!due) return;
    _inFlight.add(key);
    final batch = pending
        .map((t) => Map<String, dynamic>.from(t as Map))
        .toList();
    // 同一 Agent 的不同频道共享记忆库，串行提取，避免互相覆盖碎片。
    final previous = _agentRuns[agent.id] ?? Future.value();
    final task = previous.catchError((Object _) {}).then((_) async {
      try {
        debugPrint(
          '[记忆调度] 开始批次 | channel=${state['channelId']} mode=${config.memoryExtractionMode} rounds=${batch.length}',
        );
        final success = await extract(agent, batch);
        if (success) {
          final ids = batch.map((t) => t['id']).toSet();
          pending.removeWhere((t) => ids.contains(t['id']));
          state['lastTurnId'] = batch.last['id'];
          state['lastExtractedAt'] = now().toIso8601String();
          state['retryAt'] = null;
        } else {
          state['retryAt'] = now()
              .add(const Duration(minutes: 1))
              .toIso8601String();
        }
        await _persist();
        debugPrint(
          '[记忆调度] 批次${success ? '成功' : '失败，保留进度'} | channel=${state['channelId']} pending=${pending.length}',
        );
      } catch (e) {
        state['retryAt'] = now()
            .add(const Duration(minutes: 1))
            .toIso8601String();
        debugPrint('[记忆调度] 提取异常，保留待提取轮次: $e');
      } finally {
        _inFlight.remove(key);
      }
    });
    _agentRuns[agent.id] = task;
    await task;
    if (identical(_agentRuns[agent.id], task)) _agentRuns.remove(agent.id);
  }
}
