import '../plugin_data.dart';
import '../types.dart';
import 'record_domain_support.dart';

/// System 域业务：服务器全局系统配置（插件注册表/商店配置）+ 插件设置
/// 统一通道（configs/ 前缀）。
///
/// 系统配置落 system/ 分区（system/plugin_registry.json、
/// system/store_config.json）；服务端启动时负责把 dataDir 顶层同名旧文件
/// 一次性搬入分区，SDK 只认分区路径。注册表在服务端只读
/// （安装/卸载执行在 Dart 服务器不支持，返回 501）。
///
/// configs/ 前缀为客户端设置生态（ConfigManager/插件 settings/路由历史等）
/// 的原始布局，config 命令借 'configs' 分区原地读写保持零迁移兼容
/// （与 database 域借 'databases' 分区访问顶层旧文件同一惯例）；
/// 前缀本身进 LegacyWritePolicy 封闭后，这里是唯一写入口。
PluginHandlers createSystemHandlers(PluginData data) {
  const plugin = 'system';

  Future<Map<String, dynamic>> readObject(String fileName) async {
    final raw = await data.read(plugin, fileName);
    if (raw == null) return <String, dynamic>{};
    if (raw is! Map)
      throw const DomainFailure('CORRUPT_DATA', 'Expected object');
    return Map<String, dynamic>.from(raw);
  }

  // configs/ 下相对路径（如 app_config.json、bill/settings.json、
  // scripts_center_installed_scripts），防穿越与非法字符。
  String checkConfigKey(dynamic value) {
    if (value is! String || value.isEmpty)
      throw ArgumentError('key required');
    final key = value.trim();
    if (key.startsWith('/') ||
        key.contains('..') ||
        key.contains('\\') ||
        !RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.\-/]*$').hasMatch(key)) {
      throw ArgumentError('invalid config key');
    }
    return key;
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

    // ===== configs/ 设置统一通道（key 为 configs/ 下相对路径）=====
    'getConfig': domainAction(
      (p) async => {'value': await data.read('configs', checkConfigKey(p['key']))},
    ),
    'setConfig': domainAction((p) async {
      final key = checkConfigKey(p['key']);
      if (!p.containsKey('value')) throw ArgumentError('value required');
      await data.write('configs', key, p['value']);
      return {'key': key};
    }),
    'deleteConfig': domainAction((p) async {
      final key = checkConfigKey(p['key']);
      return {'deleted': await data.delete('configs', key)};
    }),
  };
}
