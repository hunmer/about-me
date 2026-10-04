import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';

/// 状态机服务：读取时惰性演化（能量恢复/亲密度衰减），互动后落盘。
/// 读改写都经过这里，保证所有消费方拿到的是演化后的状态。
class StateService {
  StateService._();
  static final StateService instance = StateService._();

  final _store = AlivenessStore.instance;

  /// 内存缓存，避免同一轮决策/生成期间多次读盘
  final Map<String, AgentState> _cache = {};

  Future<AgentState> load(String agentId, {int intimacyHalfLifeDays = 14}) async {
    final raw = await _store.loadState(agentId);
    final decayed = raw.decayTo(
      DateTime.now(),
      intimacyHalfLifeDays: intimacyHalfLifeDays,
    );
    _cache[agentId] = decayed;
    return decayed;
  }

  AgentState cached(String agentId) =>
      _cache[agentId] ?? const AgentState();

  Future<AgentState> applyAfterInteraction(
    String agentId, {
    required double generatedLength,
    required double userEmotion,
    required int userMessageCount,
  }) async {
    final current = _cache[agentId] ?? await load(agentId);
    final next = current.applyAfterInteraction(
      generatedLength: generatedLength,
      userEmotion: userEmotion,
      userMessageCount: userMessageCount,
    );
    _cache[agentId] = next;
    await _store.saveState(agentId, next);
    return next;
  }
}
