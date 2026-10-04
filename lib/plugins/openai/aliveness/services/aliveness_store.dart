import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';

/// 每 agent 独立活人感数据的读写入口。
/// 数据布局：`app_data/openai/aliveness/<agentId>/` 下的 `state.json`、`stats.json`、`decisions.log`。
/// 全局决策层配置：`app_data/openai/aliveness/settings.json`
class AlivenessStore {
  AlivenessStore._();
  static final AlivenessStore instance = AlivenessStore._();

  static const String _defaultJevApiKey =
      'apikey_278601a56a42a0a4d298d52e2fb5000158c_a1817949613f48c69a84066214f77c352fadf41f0e332a2f0fcfd1a900392409';

  String _dir(String agentId) =>
      '${OpenAIPlugin.instance.storageDir}/aliveness/$agentId';

  // ---------- per-agent 状态 ----------

  Future<AgentState> loadState(String agentId) async {
    final data = await OpenAIPlugin.instance.storage.read(
      '${_dir(agentId)}/state.json',
    );
    if (data.isEmpty) return AgentState(updatedAt: DateTime.now());
    return AgentState.fromJson(data);
  }

  Future<void> saveState(String agentId, AgentState state) async {
    await OpenAIPlugin.instance.storage.write('${_dir(agentId)}/state.json', {
      ...state.toJson(),
      'agentId': agentId,
    });
  }

  // ---------- per-agent 统计（主动消息冷却/计数，Phase 3 使用，先落盘） ----------

  Future<Map<String, dynamic>> loadStats(String agentId) async {
    final data = await OpenAIPlugin.instance.storage.read(
      '${_dir(agentId)}/stats.json',
    );
    return data.isEmpty ? <String, dynamic>{} : data;
  }

  Future<void> saveStats(
    String agentId,
    Map<String, dynamic> stats,
  ) async {
    await OpenAIPlugin.instance.storage.write('${_dir(agentId)}/stats.json', {
      ...stats,
      'agentId': agentId,
    });
  }

  // ---------- per-agent 记忆（Phase 2） ----------

  Future<Map<String, dynamic>> loadMemory(String agentId) async {
    final data = await OpenAIPlugin.instance.storage.read(
      '${_dir(agentId)}/memory/fragments.json',
    );
    return data;
  }

  Future<void> saveMemory(String agentId, Map<String, dynamic> data) async {
    await OpenAIPlugin.instance.storage.write(
      '${_dir(agentId)}/memory/fragments.json',
      data,
    );
  }

  Future<Map<String, dynamic>> loadOpenLoops(String agentId) async {
    final data = await OpenAIPlugin.instance.storage.read(
      '${_dir(agentId)}/memory/open_loops.json',
    );
    return data;
  }

  Future<void> saveOpenLoops(String agentId, Map<String, dynamic> data) async {
    await OpenAIPlugin.instance.storage.write(
      '${_dir(agentId)}/memory/open_loops.json',
      data,
    );
  }

  // ---------- 决策日志（可观测性，滚动保留最近 200 条） ----------

  Future<void> appendDecision(String agentId, Map<String, dynamic> entry) async {
    final path = '${_dir(agentId)}/decisions.log';
    final data = await OpenAIPlugin.instance.storage.read(path);
    final List<dynamic> logs = data['logs'] as List<dynamic>? ?? [];
    logs.add({
      'ts': DateTime.now().toIso8601String(),
      ...entry,
    });
    if (logs.length > 200) {
      logs.removeRange(0, logs.length - 200);
    }
    await OpenAIPlugin.instance.storage.write(path, {'logs': logs});
  }

  Future<List<dynamic>> loadDecisions(String agentId) async {
    final data = await OpenAIPlugin.instance.storage.read(
      '${_dir(agentId)}/decisions.log',
    );
    return data['logs'] as List<dynamic>? ?? [];
  }

  // ---------- 全局决策层（Jev）配置 ----------

  Future<Map<String, dynamic>> loadSettings() async {
    final data = await OpenAIPlugin.instance.storage.read(
      '${OpenAIPlugin.instance.storageDir}/aliveness/settings.json',
    );
    return data.isEmpty
        ? {
          'jevBaseUrl': 'https://api.typesafe.ai/v1/systemone',
          'jevApiKey': _defaultJevApiKey,
          'jevModel': 'jev-latest',
          'confidenceThreshold': 0.65,
        }
        : data;
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await OpenAIPlugin.instance.storage.write(
      '${OpenAIPlugin.instance.storageDir}/aliveness/settings.json',
      settings,
    );
  }
}
