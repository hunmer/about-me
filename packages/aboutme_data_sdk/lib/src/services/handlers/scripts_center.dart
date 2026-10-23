import '../../storage_errors.dart';
import '../plugin_data.dart';
import '../types.dart';
import 'record_domain_support.dart';

/// 脚本中心域命令：脚本、脚本配置、执行记录、商场持久化四组。
///
/// 数据布局（scripts_center 分区内）：
/// - scripts/{id}/metadata.json：脚本元数据（对象）
/// - scripts/{id}/script.js：脚本代码（值为 JSON 字符串，命令写入/读取即编解码，
///   客户端始终拿到裸文本 String）
/// - configs/{id}_config.json：脚本运行配置（对象原样透传，旧扁平/新 profiles
///   格式兼容逻辑留在客户端）
/// - execution_log.json：执行记录（List，头部插入、滚动 [execLogLimit] 条）
/// - store/sources.json 与 store/installed.json：商场源配置与已安装脚本（List）
///
/// id/scriptId 校验：非空且不含 `/`、`\`、`..`（防路径穿越）。
PluginHandlers createScriptsCenterHandlers(PluginData data) {
  const plugin = 'scripts_center';
  const execLogLimit = 200;

  String checkId(dynamic value, [String label = 'id']) {
    if (value is! String ||
        value.isEmpty ||
        value.contains('/') ||
        value.contains('\\') ||
        value.contains('..'))
      throw ArgumentError('$label required');
    return value;
  }

  /// 与客户端旧 _compareVersion 一致的语义化版本比较（点分整数，缺段为 0）。
  int compareVersion(String a, String b) {
    int parse(String s, int i) {
      final parts = s.split('.');
      return i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0;
    }

    final aLen = a.split('.').length;
    final bLen = b.split('.').length;
    final len = aLen > bLen ? aLen : bLen;
    for (var i = 0; i < len; i++) {
      final va = parse(a, i);
      final vb = parse(b, i);
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  /// 读取脚本元数据；缺失返回 null，顶层非对象视为损坏。
  Future<Map<String, dynamic>?> readMeta(String id) async {
    final raw = await data.read(plugin, 'scripts/$id/metadata.json');
    if (raw == null) return null;
    if (raw is! Map)
      throw const DomainFailure('CORRUPT_DATA', 'Expected object');
    return Map<String, dynamic>.from(raw);
  }

  /// 读取顶层 List 文件；缺失返回 []（损坏数据明确报错）。
  Future<List<dynamic>> readListFile(String file) async {
    final raw = await data.read(plugin, file);
    if (raw == null) return [];
    if (raw is! List)
      throw const DomainFailure('CORRUPT_DATA', 'Expected array');
    return raw;
  }

  return {
    // ==================== scripts 组 ====================
    // 扫描 scripts/*/metadata.json；单个元数据损坏（非法 JSON 或顶层非对象）
    // 跳过该 id，不阻断整体（跳过产生的读异常由事务层放行，见 execute 的 fault 检查）
    'listScripts': domainAction((_) async {
      final names = await data.listFiles(plugin, 'scripts/*/metadata.json');
      final scripts = <Map<String, dynamic>>[];
      for (final name in names) {
        // name 形如 scripts/{id}/metadata.json
        final id = name.split('/')[1];
        try {
          final raw = await data.read(plugin, 'scripts/$id/metadata.json');
          if (raw is Map)
            scripts.add({'id': id, 'metadata': Map<String, dynamic>.from(raw)});
        } on StorageException {
          // 单个 metadata.json 内容损坏：跳过该 id
        }
      }
      return scripts;
    }),
    'getMeta': domainAction((p) => readMeta(checkId(p['id']))),
    'saveMeta': domainAction((p) async {
      final id = checkId(p['id']);
      final metadata = p['metadata'];
      if (metadata is! Map) throw ArgumentError('metadata required');
      final result = Map<String, dynamic>.from(metadata);
      await data.write(plugin, 'scripts/$id/metadata.json', result);
      return result;
    }),
    'getCode': domainAction((p) async {
      final id = checkId(p['id']);
      final raw = await data.read(plugin, 'scripts/$id/script.js');
      if (raw == null) return null;
      if (raw is! String)
        throw const DomainFailure('CORRUPT_DATA', 'Expected string');
      return raw;
    }),
    'saveCode': domainAction((p) async {
      final id = checkId(p['id']);
      final code = p['code'];
      if (code is! String) throw ArgumentError('code required');
      await data.write(plugin, 'scripts/$id/script.js', code);
      return {'id': id};
    }),
    // 事务内写 metadata + code；id 已存在拒绝（CONFLICT）
    'createScript': domainAction((p) async {
      final id = checkId(p['id']);
      final metadata = p['metadata'];
      if (metadata is! Map) throw ArgumentError('metadata required');
      final code = p['code'];
      if (code is! String) throw ArgumentError('code required');
      if (await readMeta(id) != null)
        throw DomainFailure('CONFLICT', 'Script already exists: $id');
      await data.write(
        plugin,
        'scripts/$id/metadata.json',
        Map<String, dynamic>.from(metadata),
      );
      await data.write(plugin, 'scripts/$id/script.js', code);
      return {'id': id};
    }),
    // 级联删除脚本目录两个文件与运行配置
    'deleteScript': domainAction((p) async {
      final id = checkId(p['id']);
      final existed = await readMeta(id) != null;
      await data.delete(plugin, 'scripts/$id/metadata.json');
      await data.delete(plugin, 'scripts/$id/script.js');
      await data.delete(plugin, 'configs/${id}_config.json');
      return {'deleted': existed};
    }),
    'existsScript': domainAction(
      (p) async => await readMeta(checkId(p['id'])) != null,
    ),
    // 内置脚本同步：无旧元数据或 assets 版本更高则覆盖，否则跳过
    'syncBuiltin': domainAction((p) async {
      final items = p['items'];
      if (items is! List) throw ArgumentError('items required');
      final synced = <String>[];
      final skipped = <String>[];
      for (final item in items) {
        if (item is! Map) throw ArgumentError('Invalid item');
        final id = checkId(item['id']);
        final metadata = item['metadata'];
        if (metadata is! Map) throw ArgumentError('metadata required');
        final code = item['code'];
        if (code is! String) throw ArgumentError('code required');
        final oldMeta = await readMeta(id);
        final oldVersion = oldMeta?['version']?.toString() ?? '0.0.0';
        final newVersion = metadata['version']?.toString() ?? '0.0.0';
        if (oldMeta != null && compareVersion(oldVersion, newVersion) >= 0) {
          skipped.add(id);
          continue;
        }
        await data.write(
          plugin,
          'scripts/$id/metadata.json',
          Map<String, dynamic>.from(metadata),
        );
        await data.write(plugin, 'scripts/$id/script.js', code);
        synced.add(id);
      }
      return {'synced': synced, 'skipped': skipped};
    }),
    // ==================== scriptConfig 组（对象原样透传）====================
    'getConfig': domainAction((p) async {
      final scriptId = checkId(p['scriptId'], 'scriptId');
      final raw = await data.read(plugin, 'configs/${scriptId}_config.json');
      if (raw == null) return null;
      if (raw is! Map)
        throw const DomainFailure('CORRUPT_DATA', 'Expected object');
      return Map<String, dynamic>.from(raw);
    }),
    'setConfig': domainAction((p) async {
      final scriptId = checkId(p['scriptId'], 'scriptId');
      final config = p['config'];
      if (config is! Map) throw ArgumentError('config required');
      final result = Map<String, dynamic>.from(config);
      await data.write(plugin, 'configs/${scriptId}_config.json', result);
      return result;
    }),
    'deleteConfig': domainAction((p) async {
      final scriptId = checkId(p['scriptId'], 'scriptId');
      return {
        'deleted': await data.delete(plugin, 'configs/${scriptId}_config.json'),
      };
    }),
    // ==================== execLog 组（头部插入 + 滚动上限在命令内保证）====================
    'getExecLog': domainAction((_) => readListFile('execution_log.json')),
    'recordExecution': domainAction((p) async {
      final entry = p['entry'];
      if (entry is! Map) throw ArgumentError('entry required');
      final rows = await readListFile('execution_log.json');
      rows.insert(0, Map<String, dynamic>.from(entry));
      await data.write(
        plugin,
        'execution_log.json',
        rows.take(execLogLimit).toList(),
      );
      return {'count': rows.length > execLogLimit ? execLogLimit : rows.length};
    }),
    'clearExecLog': domainAction((_) async {
      await data.write(plugin, 'execution_log.json', []);
      return {'count': 0};
    }),
    // ==================== store 组（商场源配置 / 已安装脚本）====================
    'getSources': domainAction((_) => readListFile('store/sources.json')),
    'saveSources': domainAction((p) async {
      final sources = p['sources'];
      if (sources is! List) throw ArgumentError('sources required');
      await data.write(plugin, 'store/sources.json', sources);
      return {'count': sources.length};
    }),
    'getInstalled': domainAction((_) => readListFile('store/installed.json')),
    'saveInstalled': domainAction((p) async {
      final installed = p['installed'];
      if (installed is! List) throw ArgumentError('installed required');
      await data.write(plugin, 'store/installed.json', installed);
      return {'count': installed.length};
    }),
  };
}
