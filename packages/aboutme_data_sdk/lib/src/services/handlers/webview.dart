import '../plugin_data.dart';
import '../types.dart';
import 'record_domain_support.dart';

/// WebView 域业务：settings.json 全局设置、tabs.json 标签页、
/// cards.json 卡片（三者整文件读写），以及网页 JS 经 bridge 读写的
/// webview/{key} 任意 JSON KV（key 做路径安全校验）。
///
/// app_store_manager 的源配置在 configs/ 前缀（独立于本域，
/// 经 system 域 config 命令读写），不在此处。
PluginHandlers createWebviewHandlers(PluginData data) {
  const plugin = 'webview';

  Future<Map<String, dynamic>> readObject(String fileName) async {
    final raw = await data.read(plugin, fileName);
    if (raw == null) return <String, dynamic>{};
    if (raw is! Map)
      throw const DomainFailure('CORRUPT_DATA', 'Expected object');
    return Map<String, dynamic>.from(raw);
  }

  Future<List<dynamic>> readList(String fileName) async {
    final raw = await data.read(plugin, fileName);
    if (raw == null) return [];
    if (raw is! List)
      throw const DomainFailure('CORRUPT_DATA', 'Expected array');
    return raw;
  }

  String checkStorageKey(dynamic value) {
    if (value is! String ||
        value.isEmpty ||
        value.contains('/') ||
        value.contains('\\') ||
        value.contains('..'))
      throw ArgumentError('key required');
    return value;
  }

  return {
    'getSettings': domainAction((_) => readObject('settings.json')),
    'updateSettings': domainAction((p) async {
      final settings = await readObject('settings.json');
      settings.addAll(domainPatch(p));
      await data.write(plugin, 'settings.json', settings);
      return settings;
    }),
    'getTabs': domainAction((_) => readList('tabs.json')),
    'saveTabs': domainAction((p) async {
      final tabs = p['tabs'];
      if (tabs is! List) throw ArgumentError('tabs required');
      await data.write(plugin, 'tabs.json', tabs);
      return {'count': tabs.length};
    }),
    'getCards': domainAction((_) => readList('cards.json')),
    'saveCards': domainAction((p) async {
      final cards = p['cards'];
      if (cards is! List) throw ArgumentError('cards required');
      await data.write(plugin, 'cards.json', cards);
      return {'count': cards.length};
    }),
    // 网页 JS bridge KV：key 为 webview/ 下单段文件名（无扩展名限制）
    'getWebStorage': domainAction(
      (p) => data.read(plugin, checkStorageKey(p['key'])),
    ),
    'setWebStorage': domainAction((p) async {
      final key = checkStorageKey(p['key']);
      await data.write(plugin, key, p['value']);
      return {'key': key};
    }),
    'deleteWebStorage': domainAction((p) async {
      final key = checkStorageKey(p['key']);
      await data.delete(plugin, key);
      return {'key': key};
    }),
  };
}
