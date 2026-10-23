import '../plugin_data.dart';
import '../types.dart';
import 'record_domain_support.dart';

/// System 域业务：服务器全局系统配置（插件注册表/商店配置）。
///
/// 数据落 system/ 分区（system/plugin_registry.json、
/// system/store_config.json）；服务端启动时负责把 dataDir 顶层同名旧文件
/// 一次性搬入分区，SDK 只认分区路径。注册表在服务端只读
/// （安装/卸载执行在 Dart 服务器不支持，返回 501）。
PluginHandlers createSystemHandlers(PluginData data) {
  const plugin = 'system';

  Future<Map<String, dynamic>> readObject(String fileName) async {
    final raw = await data.read(plugin, fileName);
    if (raw == null) return <String, dynamic>{};
    if (raw is! Map)
      throw const DomainFailure('CORRUPT_DATA', 'Expected object');
    return Map<String, dynamic>.from(raw);
  }

  return {
    'getPluginRegistry': domainAction(
      (_) => readObject('plugin_registry.json'),
    ),
    'getStoreConfig': domainAction((_) => readObject('store_config.json')),
    'updateStoreConfig': domainAction((p) async {
      final config = await readObject('store_config.json');
      config.addAll(domainPatch(p));
      await data.write(plugin, 'store_config.json', config);
      return config;
    }),
  };
}
