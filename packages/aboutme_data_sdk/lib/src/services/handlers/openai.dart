import '../plugin_data.dart';
import '../types.dart';
import 'record_domain_support.dart';

/// OpenAI 域文件层命令：保持旧客户端 openai/ 分区文件布局不变，
/// 客户端业务逻辑（初始化兜底、合并、版本比较、500/200 上限滚动）
/// 全部留在 Flutter 侧，命令只做文件级读写（薄封装）。
///
/// 数据布局（全 JSON）：
/// - agents.json / providers.json / prompt_presets.json：{xxx:[...]} 整文件读写
/// - aliveness/{agentId}/ 下的 state/stats/旧 fragments/open_loops/schedule
/// - aliveness/memory_libraries.json 与 aliveness/memory_libraries/{memoryId}/ 下的新记忆数据
///   与 aliveness/memory_extraction.json、aliveness/settings.json（单例读写）
/// - aliveness/{agentId}/decisions.log：扩展名 .log 但内容为 JSON
/// - moments/ 的 posts/ui_state/profile_bg/{agentId}/assets
/// - topic_collections/{id}.json 与 topic_agents_{collectionId}.json
///   （topic_collections.json 为旧遗留，仅提供删除命令）
PluginHandlers createOpenaiHandlers(PluginData data) {
  const plugin = 'openai';

  /// 整文件读：缺失返回 null（客户端按空对象兜底，对齐旧 readPath 语义），
  /// 顶层不是对象视为损坏（CORRUPT_DATA，客户端 catch 兜底）。
  Future<Map<String, dynamic>?> readObjectFile(String file) async {
    final raw = await data.read(plugin, file);
    if (raw == null) return null;
    if (raw is! Map)
      throw const DomainFailure('CORRUPT_DATA', 'Expected object');
    return Map<String, dynamic>.from(raw);
  }

  /// 整文件写：保持 {xxx:[...]} 顶层结构原样落盘。
  Future<Map<String, dynamic>> writeObjectFile(
    String file,
    dynamic doc,
    String label,
  ) async {
    if (doc is! Map) throw ArgumentError('$label required');
    final result = Map<String, dynamic>.from(doc);
    await data.write(plugin, file, result);
    return result;
  }

  String checkId(dynamic value, String label) {
    if (value is! String ||
        value.isEmpty ||
        value.contains('/') ||
        value.contains('\\') ||
        value.contains('..'))
      throw ArgumentError('$label required');
    return value;
  }

  // aliveness 文档类：kind 白名单映射文件路径
  // （{a} 占位 agentId 的为 per-agent 文档；其余为全局文档，无 agentId）
  const agentDocFiles = <String, String>{
    'state': 'aliveness/{a}/state.json',
    'stats': 'aliveness/{a}/stats.json',
    'fragments': 'aliveness/{a}/memory/fragments.json',
    'openLoops': 'aliveness/{a}/memory/open_loops.json',
    'schedule': 'aliveness/{a}/schedule.json',
  };
  const memoryDocFiles = <String, String>{
    'memory_library': 'aliveness/memory_libraries/{m}/memory.json',
    'memory_library_loops': 'aliveness/memory_libraries/{m}/open_loops.json',
  };
  const globalDocFiles = <String, String>{
    'memoryExtraction': 'aliveness/memory_extraction.json',
    'settings': 'aliveness/settings.json',
    'memory_libraries': 'aliveness/memory_libraries.json',
  };

  String alivenessDocPath(dynamic kind, dynamic agentId, dynamic memoryId) {
    final agentFile = agentDocFiles[kind];
    if (agentFile != null) {
      return agentFile.replaceFirst('{a}', checkId(agentId, 'agentId'));
    }
    final memoryFile = memoryDocFiles[kind];
    if (memoryFile != null) {
      if (agentId != null) {
        throw ArgumentError('memoryId required instead of agentId');
      }
      return memoryFile.replaceFirst('{m}', checkId(memoryId, 'memoryId'));
    }
    final globalFile = globalDocFiles[kind];
    if (globalFile != null) return globalFile;
    throw ArgumentError('Unknown aliveness doc kind: $kind');
  }

  return {
    // ---- 智能体 / 服务商 / 提示词预设（整文件读写）----
    'getAgents': domainAction((_) => readObjectFile('agents.json')),
    'saveAgents': domainAction(
      (p) => writeObjectFile('agents.json', p['agents'], 'agents'),
    ),
    'getProviders': domainAction((_) => readObjectFile('providers.json')),
    'saveProviders': domainAction(
      (p) => writeObjectFile('providers.json', p['providers'], 'providers'),
    ),
    'getPresets': domainAction((_) => readObjectFile('prompt_presets.json')),
    'savePresets': domainAction(
      (p) => writeObjectFile('prompt_presets.json', p['presets'], 'presets'),
    ),
    // ---- aliveness 文档类（kind 白名单；单例读写）----
    'alivenessGetDoc': domainAction(
      (p) => readObjectFile(
        alivenessDocPath(p['kind'], p['agentId'], p['memoryId']),
      ),
    ),
    'alivenessSetDoc': domainAction((p) async {
      final file = alivenessDocPath(p['kind'], p['agentId'], p['memoryId']);
      return writeObjectFile(file, p['doc'], 'doc');
    }),
    // ---- 决策日志（decisions.log 内容为 JSON；滚动 200 条在客户端）----
    'alivenessGetDecisions': domainAction((p) {
      final agentId = checkId(p['agentId'], 'agentId');
      return readObjectFile('aliveness/$agentId/decisions.log');
    }),
    'alivenessSaveDecisions': domainAction((p) async {
      final agentId = checkId(p['agentId'], 'agentId');
      return writeObjectFile(
        'aliveness/$agentId/decisions.log',
        p['logs'],
        'logs',
      );
    }),
    // ---- 朋友圈（posts / UI 偏好 / 背景映射 / 资产图索引）----
    'getPosts': domainAction((_) => readObjectFile('moments/posts.json')),
    'savePosts': domainAction(
      (p) => writeObjectFile('moments/posts.json', p['posts'], 'posts'),
    ),
    'getMomentsUiState': domainAction(
      (_) => readObjectFile('moments/ui_state.json'),
    ),
    'saveMomentsUiState': domainAction(
      (p) => writeObjectFile('moments/ui_state.json', p['uiState'], 'uiState'),
    ),
    'getProfileBg': domainAction(
      (_) => readObjectFile('moments/profile_bg.json'),
    ),
    'saveProfileBg': domainAction(
      (p) => writeObjectFile(
        'moments/profile_bg.json',
        p['backgrounds'],
        'backgrounds',
      ),
    ),
    'getAssets': domainAction((p) {
      final agentId = checkId(p['agentId'], 'agentId');
      return readObjectFile('moments/$agentId/assets.json');
    }),
    'saveAssets': domainAction((p) {
      final agentId = checkId(p['agentId'], 'agentId');
      return writeObjectFile(
        'moments/$agentId/assets.json',
        p['assets'],
        'assets',
      );
    }),
    // ---- 话题合集（单文件读写删）----
    'getTopicCollection': domainAction((p) {
      final id = checkId(p['id'], 'id');
      return readObjectFile('topic_collections/$id.json');
    }),
    'saveTopicCollection': domainAction((p) {
      final id = checkId(p['id'], 'id');
      return writeObjectFile(
        'topic_collections/$id.json',
        p['collection'],
        'collection',
      );
    }),
    'deleteTopicCollection': domainAction((p) async {
      final id = checkId(p['id'], 'id');
      return {'deleted': await data.delete(plugin, 'topic_collections/$id.json')};
    }),
    // ---- 话题 agent（extra storage：topic_agents_{collectionId}.json）----
    'getTopicAgents': domainAction((p) {
      final id = checkId(p['collectionId'], 'collectionId');
      return readObjectFile('topic_agents_$id.json');
    }),
    'saveTopicAgents': domainAction((p) {
      final id = checkId(p['collectionId'], 'collectionId');
      return writeObjectFile('topic_agents_$id.json', p['agents'], 'agents');
    }),
    'deleteTopicAgents': domainAction((p) async {
      final id = checkId(p['collectionId'], 'collectionId');
      return {'deleted': await data.delete(plugin, 'topic_agents_$id.json')};
    }),
    // ---- 旧遗留：openai/topic_collections.json（启动清理用，不存在不报错）----
    'deleteLegacyTopicCollections': domainAction(
      (_) async => {
        'deleted': await data.delete(plugin, 'topic_collections.json'),
      },
    ),
  };
}
