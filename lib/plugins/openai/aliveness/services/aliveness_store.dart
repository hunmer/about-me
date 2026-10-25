import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';
import 'package:aboutme/plugins/openai/aliveness/models/memory_library.dart';
import 'package:uuid/uuid.dart';

/// 每 agent 独立活人感数据的读写入口。
/// 数据布局：`app_data/openai/aliveness/<agentId>/` 下的 `state.json`、`stats.json`、`decisions.log`。
/// 全局决策层配置：`app_data/openai/aliveness/settings.json`
/// 经 SDK 命令（openai 域文件层）读写，文件布局不变。
class AlivenessStore {
  AlivenessStore._();
  static final AlivenessStore instance = AlivenessStore._();

  static const String _defaultJevApiKey =
      'apikey_xxxxx';
  static const String _memoryLibrariesKind = 'memory_libraries';
  static const String _memoryKind = 'memory_library';
  static const String _memoryLoopsKind = 'memory_library_loops';
  static const Uuid _uuid = Uuid();
  Future<void> _libraryWrites = Future<void>.value();

  /// call 返回的 data 为 dynamic（实际为 dynamic map），
  /// 必须显式转换，否则在 await 边界触发隐式 downcast 崩溃
  Map<String, dynamic> _asStringMap(dynamic data) =>
      Map<String, dynamic>.from(data as Map);

  /// 读取 aliveness 文档：缺失/失败返回 null（调用方按空对象兜底，
  /// 对齐旧文件层"文件不存在返回空对象 + 异常 catch 兜底"语义）
  Future<Map<String, dynamic>?> _getDoc(
    String kind, {
    String? agentId,
    String? memoryId,
  }) async {
    final res = await AboutmeDataService.instance.call(
      'openai',
      'alivenessGetDoc',
      {
        if (agentId != null) 'agentId': agentId,
        if (memoryId != null) 'memoryId': memoryId,
        'kind': kind,
      },
    );
    if (res['success'] != true) {
      if (kind == _memoryLibrariesKind ||
          kind == _memoryKind ||
          kind == _memoryLoopsKind) {
        throw StateError(
          '读取 aliveness 文档失败: ${res['error'] ?? res['code'] ?? 'unknown'}',
        );
      }
      return null;
    }
    final data = res['data'];
    return data is Map ? _asStringMap(data) : null;
  }

  Future<void> _setDoc(
    String kind,
    Map<String, dynamic> doc, {
    String? agentId,
    String? memoryId,
  }) async {
    final res = await AboutmeDataService.instance.call(
      'openai',
      'alivenessSetDoc',
      {
        if (agentId != null) 'agentId': agentId,
        if (memoryId != null) 'memoryId': memoryId,
        'kind': kind,
        'doc': doc,
      },
    );
    if (res['success'] != true) {
      throw StateError(
        '写入 aliveness 文档失败: ${res['error'] ?? res['code'] ?? 'unknown'}',
      );
    }
  }

  // ---------- memory library metadata and independent memory ----------

  Future<List<MemoryLibrary>> loadMemoryLibraries() async {
    final data = await _getDoc(_memoryLibrariesKind);
    final libraries = data?['libraries'];
    if (libraries is! List) return <MemoryLibrary>[];
    return libraries
        .whereType<Map>()
        .map((item) => MemoryLibrary.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<MemoryLibrary> createMemoryLibrary(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError.value(name, 'name');

    late Future<MemoryLibrary> operation;
    operation = _libraryWrites.then((_) async {
      final library = MemoryLibrary(
        id: _uuid.v4(),
        name: trimmedName,
        createdAt: DateTime.now().toUtc(),
      );
      final libraries = await loadMemoryLibraries();
      await _setDoc(_memoryLibrariesKind, {
        'libraries': [
          ...libraries.map((item) => item.toJson()),
          library.toJson(),
        ],
      });
      return library;
    });
    _libraryWrites = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<MemoryLibrary> requireMemoryLibrary(String memoryId) async {
    if (memoryId.trim().isEmpty) throw ArgumentError.value(memoryId, 'memoryId');
    for (final library in await loadMemoryLibraries()) {
      if (library.id == memoryId) return library;
    }
    throw StateError('Memory library not found: $memoryId');
  }

  Future<Map<String, dynamic>> loadMemory(String memoryId) async {
    await requireMemoryLibrary(memoryId);
    final data = await _getDoc(_memoryKind, memoryId: memoryId);
    return data ?? <String, dynamic>{};
  }

  Future<void> saveMemory(String memoryId, Map<String, dynamic> data) async {
    await requireMemoryLibrary(memoryId);
    await _setDoc(_memoryKind, data, memoryId: memoryId);
  }

  Future<Map<String, dynamic>> loadOpenLoops(String memoryId) async {
    await requireMemoryLibrary(memoryId);
    final data = await _getDoc(_memoryLoopsKind, memoryId: memoryId);
    return data ?? <String, dynamic>{};
  }

  Future<void> saveOpenLoops(String memoryId, Map<String, dynamic> data) async {
    await requireMemoryLibrary(memoryId);
    await _setDoc(_memoryLoopsKind, data, memoryId: memoryId);
  }

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
