import '../plugin_data.dart';
import '../types.dart';
import 'record_domain_support.dart';

/// Photo editor 域业务：编辑器打开历史（薄文件层命令，客户端的
/// 去重置顶/上限截断/产物存在性过滤逻辑不上移）。
///
/// 数据落 photo_editor/ 分区 history.json（顶层 List，布局与旧客户端
/// 文件层写入一致，零迁移）；AI 编辑配置 configs/photo_editor/ai_edit_config.json
/// 已走 system 域 config 命令（configs 统一通道），不在此处。
PluginHandlers createPhotoEditorHandlers(PluginData data) {
  const plugin = 'photo_editor';
  const historyFile = 'history.json';

  Future<List<Map<String, dynamic>>> readHistory() async {
    final raw = await data.read(plugin, historyFile);
    if (raw == null) return [];
    if (raw is! List)
      throw const DomainFailure('CORRUPT_DATA', 'Expected array');
    final rows = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map)
        throw DomainFailure('CORRUPT_DATA', 'Invalid $plugin/$historyFile row');
      rows.add(Map<String, dynamic>.from(e));
    }
    return rows;
  }

  List<Map<String, dynamic>> parseRows(dynamic raw) {
    if (raw is! List) throw ArgumentError('history required');
    final rows = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map) throw ArgumentError('Invalid history row');
      rows.add(Map<String, dynamic>.from(e));
    }
    return rows;
  }

  return {
    'getHistory': domainAction((_) => readHistory()),
    'saveHistory': domainAction((p) async {
      final rows = parseRows(p['history']);
      await data.write(plugin, historyFile, rows);
      return {'count': rows.length};
    }),
    'clearHistory': domainAction((_) async {
      await data.write(plugin, historyFile, []);
      return {'count': 0};
    }),
  };
}
