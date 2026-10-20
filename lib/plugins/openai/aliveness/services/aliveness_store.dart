import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';

/// 每 agent 独立活人感数据的读写入口。
/// 数据布局：`app_data/openai/aliveness/<agentId>/` 下的 `state.json`、`stats.json`、`decisions.log`。
/// 全局决策层配置：`app_data/openai/aliveness/settings.json`
class AlivenessStore {
  AlivenessStore._();
  static final AlivenessStore instance = AlivenessStore._();

  static const String _defaultJevApiKey =
      'apikey_xxxxx';

  String _dir(String agentId) =>
      '${OpenAIPlugin.instance.storageDir}/aliveness/$agentId';

  /// storage.read 底层返回 dynamic（实际为 dynamic map），
  /// 必须显式转换，否则在 await 边界触发隐式 downcast 崩溃
  Map<String, dynamic> _asStringMap(dynamic data) =>
      Map<String, dynamic>.from(data as Map);
  // ---------- per-agent 状态 ----------

  Future<AgentState> loadState(String agentId) async {
    final data = await AboutmeDataService.instance.readPath(
      '${_dir(agentId)}/state.json',
    );
    if (data == null || data.isEmpty) {
      return AgentState(updatedAt: DateTime.now());
    }
    return AgentState.fromJson(_asStringMap(data));
  }

  Future<void> saveState(String agentId, AgentState state) async {
    await AboutmeDataService.instance.writePath('${_dir(agentId)}/state.json', {
      ...state.toJson(),
      'agentId': agentId,
    });
  }

  // ---------- per-agent 统计（主动消息冷却/计数，Phase 3 使用，先落盘） ----------

  Future<Map<String, dynamic>> loadStats(String agentId) async {
    final data = await AboutmeDataService.instance.readPath(
      '${_dir(agentId)}/stats.json',
    );
    return data is Map && data.isNotEmpty
        ? _asStringMap(data)
        : <String, dynamic>{};
  }

  Future<void> saveStats(
    String agentId,
    Map<String, dynamic> stats,
  ) async {
    await AboutmeDataService.instance.writePath('${_dir(agentId)}/stats.json', {
      ...stats,
      'agentId': agentId,
    });
  }

  // ---------- per-agent 记忆（Phase 2） ----------

  Future<Map<String, dynamic>> loadMemoryExtractionState() async {
    final data = await AboutmeDataService.instance.readPath(
      '${OpenAIPlugin.instance.storageDir}/aliveness/memory_extraction.json',
    );
    return data is Map ? _asStringMap(data) : <String, dynamic>{};
  }

  Future<void> saveMemoryExtractionState(Map<String, dynamic> data) =>
      AboutmeDataService.instance.writePath(
        '${OpenAIPlugin.instance.storageDir}/aliveness/memory_extraction.json', data,
      );

  Future<Map<String, dynamic>> loadMemory(String agentId) async {
    final data = await AboutmeDataService.instance.readPath(
      '${_dir(agentId)}/memory/fragments.json',
    );
    return data is Map ? _asStringMap(data) : <String, dynamic>{};
  }

  Future<void> saveMemory(String agentId, Map<String, dynamic> data) async {
    await AboutmeDataService.instance.writePath(
      '${_dir(agentId)}/memory/fragments.json',
      data,
    );
  }

  Future<Map<String, dynamic>> loadOpenLoops(String agentId) async {
    final data = await AboutmeDataService.instance.readPath(
      '${_dir(agentId)}/memory/open_loops.json',
    );
    return data is Map ? _asStringMap(data) : <String, dynamic>{};
  }

  Future<void> saveOpenLoops(String agentId, Map<String, dynamic> data) async {
    await AboutmeDataService.instance.writePath(
      '${_dir(agentId)}/memory/open_loops.json',
      data,
    );
  }

  // ---------- 决策日志（可观测性，滚动保留最近 200 条） ----------

  Future<void> appendDecision(String agentId, Map<String, dynamic> entry) async {
    final path = '${_dir(agentId)}/decisions.log';
    final data = await AboutmeDataService.instance.readPath(path);
    final List<dynamic> logs =
        data is Map ? (data['logs'] as List<dynamic>? ?? []) : [];
    logs.add({
      'ts': DateTime.now().toIso8601String(),
      ...entry,
    });
    if (logs.length > 200) {
      logs.removeRange(0, logs.length - 200);
    }
    await AboutmeDataService.instance.writePath(path, {'logs': logs});
  }

  Future<List<dynamic>> loadDecisions(String agentId) async {
    final data = await AboutmeDataService.instance.readPath(
      '${_dir(agentId)}/decisions.log',
    );
    return data is Map ? (data['logs'] as List<dynamic>? ?? []) : [];
  }

  // ---------- per-agent 每日日程（AI 的真实生活安排） ----------

  Future<Map<String, dynamic>?> loadSchedule(String agentId) async {
    final data = await AboutmeDataService.instance.readPath(
      '${_dir(agentId)}/schedule.json',
    );
    return data is Map && data.isNotEmpty ? _asStringMap(data) : null;
  }

  Future<void> saveSchedule(
    String agentId,
    Map<String, dynamic> data,
  ) async {
    await AboutmeDataService.instance.writePath(
      '${_dir(agentId)}/schedule.json',
      data,
    );
  }

  // ---------- 全局决策层（Jev）配置 ----------

  Future<Map<String, dynamic>> loadSettings() async {
    final data = await AboutmeDataService.instance.readPath(
      '${OpenAIPlugin.instance.storageDir}/aliveness/settings.json',
    );
    return data is Map && data.isNotEmpty
        ? _asStringMap(data)
        : {
          'jevBaseUrl': 'https://api.typesafe.ai/v1/systemone',
          'jevApiKey': _defaultJevApiKey,
          'jevModel': 'jev-latest',
          'confidenceThreshold': 0.65,
        };
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await AboutmeDataService.instance.writePath(
      '${OpenAIPlugin.instance.storageDir}/aliveness/settings.json',
      settings,
    );
  }
}
