import '../plugin_data.dart';
import '../types.dart';
import 'record_domain_support.dart';

/// live2d v2 分文件存储（2026-11）：不再把全部存档写进单个 archives.json。
/// - 元数据 `archives_v2.json`：只存 { selectedId }
/// - 每个存档独立文件 `archives_v2/<id>.json`
/// - 旧 archives.json 不做迁移，v2 从空态开始。
PluginHandlers createLive2dHandlers(PluginData data) {
  const plugin = 'live2d';
  const metaFile = 'archives_v2.json';
  const dir = 'archives_v2';

  Future<Map<String, dynamic>> readMeta() async {
    final raw = await data.read(plugin, metaFile);
    if (raw == null) return <String, dynamic>{};
    if (raw is! Map) throw const DomainFailure('CORRUPT_DATA', 'Expected object');
    return Map<String, dynamic>.from(raw);
  }

  return {
    'getSnapshot': domainAction((_) async {
      final meta = await readMeta();
      final files = await data.listFiles(plugin, '$dir/*.json');
      final archives = <Map<String, dynamic>>[];
      for (final file in files) {
        final raw = await data.read(plugin, file);
        if (raw is Map && raw['id'] is String) {
          archives.add(Map<String, dynamic>.from(raw));
        }
      }
      return {
        'selectedId': meta['selectedId'],
        'archives': archives,
      };
    }),
    // v2：快照只落 selectedId；archives 一律走 upsertArchive / deleteArchive
    'saveSnapshot': domainAction((p) async {
      final snapshot = p['snapshot'];
      if (snapshot is! Map) throw ArgumentError('snapshot required');
      final meta = await readMeta();
      meta['selectedId'] = snapshot['selectedId'];
      await data.write(plugin, metaFile, meta);
      return meta;
    }),
    'upsertArchive': domainAction((p) async {
      // 路由为 PUT /archives/:id，须从 params 取同名路径参数 id
      final id = p['id'];
      if (id is! String || id.isEmpty) throw ArgumentError('id required');
      final archive = p['archive'];
      if (archive is! Map || archive['id'] != id) {
        throw ArgumentError('archive with matching id required');
      }
      await data.write(plugin, '$dir/$id.json', Map<String, dynamic>.from(archive));
      return archive;
    }),
    'deleteArchive': domainAction((p) async {
      final id = p['id'];
      if (id is! String || id.isEmpty) throw ArgumentError('id required');
      await data.delete(plugin, '$dir/$id.json');
      return {'id': id};
    }),
  };
}
