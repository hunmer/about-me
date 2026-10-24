import 'package:path/path.dart' as p;

import 'storage_errors.dart';

/// 已迁移域的 local/HTTP 原始文件写入共同边界。
class LegacyWritePolicy {
  static const migratedDomains = <String>[
    'diary',
    'todo',
    'tracker',
    'notes',
    'nodes',
    'contact',
    'day',
    'calendar',
    'checkin',
    'habits',
    'bill',
    'goods',
    'store',
    'calendar_album',
    'media_log',
    'database',
    'agent_chat',
    'activity',
    'timer',
    'achievement',
    'reminder',
    'live2d',
    'tts',
    'webview',
    'scripts_center',
    'openai',
    'toolbox',
    'photo_editor',
  ];
  static const _protectedRoots = [...migratedDomains, 'assets', 'asset_references',
    'stickers/collections.json', 'sdk_migrations', '.sdk',
    // 插件设置统一通道落 configs/ 前缀（system 域 config 命令是唯一写入口）
    'configs'];

  /// 非域类的保护前缀（capabilities 对外声明，管理端删除预判用）。
  static const protectedPrefixes = ['assets', 'asset_references',
    'stickers/collections.json', 'sdk_migrations', '.sdk', 'configs'];

  static void check(String path, {bool prefix = false}) {
    // Windows 大小写等价路径也不能绕过限制。
    final normalized = p.posix.normalize(path.replaceAll('\\', '/')).toLowerCase()
        .split('/').map((part) => part.replaceFirst(RegExp(r'[. ]+$'), '')).join('/');
    final key = normalized == '.' ? '' : normalized;
    for (final root in _protectedRoots) {
      if (key == root ||
          key.startsWith('$root/') ||
          (prefix && (key.isEmpty || root.startsWith(key)))) {
        throw const StorageException(
          StorageErrorKind.unsupported,
          '业务域已迁移，请升级客户端并使用 SDK 业务命令；原始文件写入已禁用',
          statusCode: 426,
        );
      }
    }
  }
}
