import '../plugin_data.dart';
import '../types.dart';
import 'record_domain_support.dart';

/// Toolbox 域业务：工具箱 AI 生图与图片搜索两个小工具的配置和历史。
///
/// - 工具配置存 `configs/toolbox/{tool}_config.json`（对象），首次读取时
///   自动从旧脚本中心 `configs/scripts_center/{tool}_config.json` 迁移落盘
///   （与原客户端 ensureLoaded 行为一致，文件布局不变）。
/// - 生图历史 `toolbox/ai_image/history.json` 顶层 List（上限 100 条）：
///   客户端全量持有并负责产物图片存在性校验，命令提供整表读写。
/// - 搜图历史 `toolbox/image_search_history.json` 顶层 List（上限 50 条）：
///   去重置顶、截断、按时间戳删除等语义在命令内闭环。
///
/// 生图产物 PNG 为二进制资产（原经 StorageManager 直写），不在本域内。
PluginHandlers createToolboxHandlers(PluginData data) {
  const plugin = 'toolbox';
  const imageSearchHistoryLimit = 50;

  /// 读取工具配置（缺失时空对象；首次自动迁移旧脚本中心配置）。
  Future<Map<String, dynamic>> readToolConfig(String tool) async {
    final file = 'toolbox/${tool}_config.json';
    final raw = await data.read('configs', file);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    final legacy = await data.read(
      'configs',
      'scripts_center/${tool}_config.json',
    );
    if (legacy is Map) {
      final config = Map<String, dynamic>.from(legacy);
      await data.write('configs', file, config);
      return config;
    }
    return <String, dynamic>{};
  }

  /// 历史文件读取：顶层 List，每行必须是对象（损坏数据明确报错）。
  Future<List<Map<String, dynamic>>> readHistory(String file) async {
    final raw = await data.read(plugin, file);
    if (raw == null) return [];
    if (raw is! List)
      throw const DomainFailure('CORRUPT_DATA', 'Expected array');
    final rows = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map)
        throw DomainFailure('CORRUPT_DATA', 'Invalid toolbox/$file row');
      rows.add(Map<String, dynamic>.from(e));
    }
    return rows;
  }

  /// 历史整表写入的入参校验（行必须是对象）。
  List<Map<String, dynamic>> parseHistoryRows(dynamic raw, String label) {
    if (raw is! List) throw ArgumentError('$label required');
    final rows = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map) throw ArgumentError('Invalid $label row');
      rows.add(Map<String, dynamic>.from(e));
    }
    return rows;
  }

  String requireString(Map<String, dynamic> p, String key) {
    final value = p[key];
    if (value is! String) throw ArgumentError('$key required');
    return value;
  }

  return {
    // ---- AI 生图：配置 ----
    // POST 而非 GET：首次读取含旧配置迁移落盘（查询不得写入持久化）。
    'getAiImageConfig': domainAction((_) => readToolConfig('ai_image')),
    'saveAiImageConfig': domainAction((p) async {
      final config = p['config'];
      if (config is! Map) throw ArgumentError('config required');
      final result = Map<String, dynamic>.from(config);
      await data.write('configs', 'toolbox/ai_image_config.json', result);
      return result;
    }),
    // ---- AI 生图：生成历史（整表读写，客户端校验产物图片存在性）----
    'getAiImageHistory': domainAction(
      (_) => readHistory('ai_image/history.json'),
    ),
    'saveAiImageHistory': domainAction((p) async {
      final rows = parseHistoryRows(p['history'], 'history');
      for (final row in rows) {
        final images = row['images'];
        if (images != null && images is! List)
          throw ArgumentError('images must be a list');
      }
      await data.write(plugin, 'ai_image/history.json', rows);
      return {'count': rows.length};
    }),
    // ---- AI 生图：绘画预设（用户自建，整表读写）----
    'getAiImagePresets': domainAction(
      (_) => readHistory('ai_image/presets.json'),
    ),
    'saveAiImagePresets': domainAction((p) async {
      final rows = parseHistoryRows(p['presets'], 'presets');
      await data.write(plugin, 'ai_image/presets.json', rows);
      return {'count': rows.length};
    }),
    // ---- 图片搜索：配置 ----
    // POST 而非 GET：首次读取含旧配置迁移落盘（查询不得写入持久化）。
    'getImageSearchConfig': domainAction((_) => readToolConfig('image_search')),
    'saveImageSearchConfig': domainAction((p) async {
      final config = p['config'];
      if (config is! Map) throw ArgumentError('config required');
      final result = Map<String, dynamic>.from(config);
      await data.write('configs', 'toolbox/image_search_config.json', result);
      return result;
    }),
    // ---- 图片搜索：搜索历史（语义在命令内闭环）----
    'getImageSearchHistory': domainAction(
      (_) => readHistory('image_search_history.json'),
    ),
    'addImageSearchHistory': domainAction((p) async {
      final mode = requireString(p, 'mode');
      final query = requireString(p, 'query');
      final imageUrl = requireString(p, 'imageUrl');
      final provider = requireString(p, 'provider');
      final file = 'image_search_history.json';
      final rows = await readHistory(file);
      // 相同关键词+模式+图源的去重置顶（与原客户端 addHistory 一致）
      rows.removeWhere(
        (e) =>
            e['mode'] == mode &&
            e['query'] == query &&
            e['imageUrl'] == imageUrl &&
            e['provider'] == provider,
      );
      final ts = p['ts'] is num
          ? (p['ts'] as num).toInt()
          : DateTime.now().millisecondsSinceEpoch;
      rows.insert(0, {
        'mode': mode,
        'query': query,
        'imageUrl': imageUrl,
        'provider': provider,
        'ts': ts,
      });
      await data.write(plugin, file, rows.take(imageSearchHistoryLimit).toList());
      return rows;
    }),
    'removeImageSearchHistory': domainAction((p) async {
      final ts = p['ts'];
      if (ts == null) throw ArgumentError('ts required');
      final file = 'image_search_history.json';
      final rows = await readHistory(file);
      rows.removeWhere((e) => '${e['ts']}' == '$ts');
      await data.write(plugin, file, rows);
      return rows;
    }),
    'clearImageSearchHistory': domainAction((_) async {
      await data.write(plugin, 'image_search_history.json', []);
      return {'count': 0};
    }),
  };
}
