import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';

/// 每 agent 独立活人感数据的读写入口。
/// 数据布局：`app_data/openai/aliveness/<agentId>/` 下的 `state.json`、`stats.json`、`decisions.log`。
/// 全局决策层配置：`app_data/openai/aliveness/settings.json`
/// 经 SDK 命令（openai 域文件层）读写，文件布局不变。
class AlivenessStore {
  AlivenessStore._();
  static final AlivenessStore instance = AlivenessStore._();

  static const String _defaultJevApiKey =
      'apikey_xxxxx';

  /// call 返回的 data 为 dynamic（实际为 dynamic map），
  /// 必须显式转换，否则在 await 边界触发隐式 downcast 崩溃
  Map<String, dynamic> _asStringMap(dynamic data) =>
      Map<String, dynamic>.from(data as Map);

  /// 读取 aliveness 文档：缺失/失败返回 null（调用方按空对象兜底，
  /// 对齐旧文件层"文件不存在返回空对象 + 异常 catch 兜底"语义）
  Future<Map<String, dynamic>?> _getDoc(
    String kind, {
    String? agentId,
  }) async {
    final res = await AboutmeDataService.instance.call(
      'openai',
      'alivenessGetDoc',
      {
        if (agentId != null) 'agentId': agentId,
        'kind': kind,
      },
    );
    final data = res['success'] == true ? res['data'] : null;
    return data is Map ? _asStringMap(data) : null;
  }

  Future<void> _setDoc(
    String kind,
    Map<String, dynamic> doc, {
    String? agentId,
  }) => AboutmeDataService.instance.call('openai', 'alivenessSetDoc', {
    if (agentId != null) 'agentId': agentId,
    'kind': kind,
    'doc': doc,
  });

  // ---------- per-agent 状态 ----------

  Future<AgentState> loadState(String agentId) async {
    final data = await _getDoc('state', agentId: agentId);
    if (data == null || data.isEmpty) {
      return AgentState(updatedAt: DateTime.now());
    }
    return AgentState.fromJson(data);
  }

  Future<void> saveState(String agentId, AgentState state) async {
    await _setDoc(
      'state',
      {...state.toJson(), 'agentId': agentId},
      agentId: agentId,
    );
  }

  // ---------- per-agent 统计（主动消息冷却/计数，Phase 3 使用，先落盘） ----------

  Future<Map<String, dynamic>> loadStats(String agentId) async {
    final data = await _getDoc('stats', agentId: agentId);
    return data != null && data.isNotEmpty ? data : <String, dynamic>{};
  }

  Future<void> saveStats(
    String agentId,
    Map<String, dynamic> stats,
  ) async {
    await _setDoc(
      'stats',
      {...stats, 'agentId': agentId},
      agentId: agentId,
    );
  }

  // ---------- per-agent 记忆（Phase 2） ----------

  Future<Map<String, dynamic>> loadMemoryExtractionState() async {
    final data = await _getDoc('memoryExtraction');
    return data ?? <String, dynamic>{};
  }

  Future<void> saveMemoryExtractionState(Map<String, dynamic> data) =>
      _setDoc('memoryExtraction', data);

  Future<Map<String, dynamic>> loadMemory(String agentId) async {
    final data = await _getDoc('fragments', agentId: agentId);
    return data ?? <String, dynamic>{};
  }

  Future<void> saveMemory(String agentId, Map<String, dynamic> data) async {
    await _setDoc('fragments', data, agentId: agentId);
  }

  Future<Map<String, dynamic>> loadOpenLoops(String agentId) async {
    final data = await _getDoc('openLoops', agentId: agentId);
    return data ?? <String, dynamic>{};
  }

  Future<void> saveOpenLoops(String agentId, Map<String, dynamic> data) async {
    await _setDoc('openLoops', data, agentId: agentId);
  }

  // ---------- 决策日志（可观测性，滚动保留最近 200 条） ----------

  Future<void> appendDecision(String agentId, Map<String, dynamic> entry) async {
    final data = await _getDecisions(agentId);
    final List<dynamic> logs =
        data != null ? (data['logs'] as List<dynamic>? ?? []) : [];
    logs.add({
      'ts': DateTime.now().toIso8601String(),
      ...entry,
    });
    if (logs.length > 200) {
      logs.removeRange(0, logs.length - 200);
    }
    await AboutmeDataService.instance.call('openai', 'alivenessSaveDecisions', {
      'agentId': agentId,
      'logs': {'logs': logs},
    });
  }

  Future<Map<String, dynamic>?> _getDecisions(String agentId) async {
    final res = await AboutmeDataService.instance.call(
      'openai',
      'alivenessGetDecisions',
      {'agentId': agentId},
    );
    final data = res['success'] == true ? res['data'] : null;
    return data is Map ? _asStringMap(data) : null;
  }

  Future<List<dynamic>> loadDecisions(String agentId) async {
    final data = await _getDecisions(agentId);
    return data?['logs'] as List<dynamic>? ?? [];
  }

  // ---------- per-agent 每日日程（AI 的真实生活安排） ----------

  Future<Map<String, dynamic>?> loadSchedule(String agentId) async {
    final data = await _getDoc('schedule', agentId: agentId);
    return data != null && data.isNotEmpty ? data : null;
  }

  Future<void> saveSchedule(
    String agentId,
    Map<String, dynamic> data,
  ) async {
    await _setDoc('schedule', data, agentId: agentId);
  }

  // ---------- 全局决策层（Jev）配置 ----------

  Future<Map<String, dynamic>> loadSettings() async {
    final data = await _getDoc('settings');
    return data != null && data.isNotEmpty
        ? data
        : {
          'jevBaseUrl': 'https://api.typesafe.ai/v1/systemone',
          'jevApiKey': _defaultJevApiKey,
          'jevModel': 'jev-latest',
          'confidenceThreshold': 0.65,
        };
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _setDoc('settings', settings);
  }
}
