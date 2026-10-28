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
