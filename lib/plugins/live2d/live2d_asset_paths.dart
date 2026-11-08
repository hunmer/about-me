import 'dart:io';

import 'package:path/path.dart' as p;

/// 将旧容器内的素材引用迁移到当前 Application Support 目录。
/// 只处理本插件管理的目录，且目标存在时才改写，避免覆盖外部资源引用。
Map<String, dynamic>? relocateLive2DAssetPaths(
  Map<String, dynamic> data,
  String supportPath,
) {
  var changed = false;

  String relocate(String value) {
    final uri = Uri.tryParse(value);
    final isFileUri = uri?.scheme == 'file';
    if (uri != null && uri.hasScheme && !isFileUri) return value;
    final path = isFileUri ? uri!.toFilePath() : value;
    if (!p.isAbsolute(path)) return value;

    final normalized = p.normalize(path);
    for (final folder in const ['live2d_models', 'video_pet_packages']) {
      final marker = '${p.separator}$folder${p.separator}';
      final index = normalized.indexOf(marker);
      if (index < 0) continue;
      final oldRoot = normalized.substring(0, index);
      // iOS 的容器 UUID 会变化；Android 的 files 路径也可能随安装位置变化。
      if (!oldRoot.endsWith(
            '${p.separator}Library${p.separator}Application Support',
          ) &&
          !oldRoot.endsWith('${p.separator}files')) {
        return value;
      }
      final newPath = p.join(supportPath, normalized.substring(index + 1));
      if (p.equals(normalized, newPath) ||
          (!File(newPath).existsSync() && !Directory(newPath).existsSync())) {
        return value;
      }
      changed = true;
      final moved = isFileUri ? Uri.file(newPath).toString() : newPath;
      return path.endsWith(p.separator) && !moved.endsWith(p.separator)
          ? '$moved${p.separator}'
          : moved;
    }
    return value;
  }

  Object? visit(Object? node) {
    if (node is String) return relocate(node);
    if (node is List) return node.map(visit).toList();
    if (node is Map) {
      return node.map<String, dynamic>(
        (key, value) => MapEntry(relocate(key.toString()), visit(value)),
      );
    }
    return node;
  }

  final result = Map<String, dynamic>.from(visit(data) as Map);
  return changed ? result : null;
}
