import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

String fileUri(String path) =>
    Uri.file(path, windows: Platform.isWindows).toString();

Future<Uint8List?> readFile(Uri uri) async {
  final file = File.fromUri(uri);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<String?> persistFiles(
  Map<String, Uint8List> files,
  String manifestPath,
) async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory.fromUri(
    support.uri.resolve('video_pet_packages/${const Uuid().v4()}/'),
  );
  try {
    await directory.create(recursive: true);
    for (final entry in files.entries) {
      final target = File.fromUri(
        directory.uri.resolve(
          Uri(pathSegments: entry.key.split('/')).toString(),
        ),
      );
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.value, flush: true);
    }
    return directory.uri
        .resolve(Uri(pathSegments: manifestPath.split('/')).toString())
        .resolve('.')
        .toString();
  } catch (_) {
    if (await directory.exists()) await directory.delete(recursive: true);
    rethrow;
  }
}

/// 向已持久化的宠物包目录追加文件（动作商店下载的精灵图/音频）。
///
/// [baseUri] 必须是 persistFiles 返回的 file: 目录 URI，否则返回 null
/// 表示调用方应回落到 data URI。已存在的目标文件一律拒绝覆盖（防止
/// 不同批次下载互相破坏）；任何写入失败时只回滚删除本次新写入的文件
/// 并重新抛出，包内原有文件不受影响。
Future<String?> appendFiles(String baseUri, Map<String, Uint8List> files) async {
  final directory = Uri.tryParse(baseUri);
  if (directory == null || !directory.isScheme('file')) return null;
  final written = <Uri>[];
  try {
    for (final entry in files.entries) {
      final segments = entry.key.split('/');
      if (segments.contains('..') || segments.first.isEmpty) {
        throw FormatException('包内路径越界: ${entry.key}');
      }
      final target = File.fromUri(
        directory.resolve(Uri(pathSegments: segments).toString()),
      );
      if (await target.exists()) {
        throw FormatException('包内文件已存在，拒绝覆盖: ${entry.key}');
      }
      await target.parent.create(recursive: true);
      await target.writeAsBytes(entry.value, flush: true);
      written.add(target.uri);
    }
    return baseUri;
  } catch (_) {
    for (final uri in written.reversed) {
      try {
        await File.fromUri(uri).delete();
      } catch (_) {
        // 回滚尽力而为，原始错误优先上抛。
      }
    }
    rethrow;
  }
}
