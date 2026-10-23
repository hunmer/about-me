import 'dart:io';
import 'dart:typed_data';

import 'asset_materialization.dart';

Future<MaterializedAsset> materializeAssetBytes(Uint8List bytes, String fileName) async {
  final extension = RegExp(r'\.[a-zA-Z0-9]{1,10}$').firstMatch(fileName)?.group(0) ?? '';
  final directory = await Directory.systemTemp.createTemp('aboutme_asset_');
  try {
    final file = File('${directory.path}/asset$extension');
    await file.writeAsBytes(bytes, flush: true);
    return MaterializedAsset(path: file.path, release: () async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
  } catch (_) {
    await directory.delete(recursive: true);
    rethrow;
  }
}
