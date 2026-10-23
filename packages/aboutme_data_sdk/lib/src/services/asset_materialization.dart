import 'dart:typed_data';

import 'asset_materialization_stub.dart'
    if (dart.library.io) 'asset_materialization_io.dart' as platform;

/// 系统播放器等宿主能力使用的临时句柄；调用方用完必须 dispose。
class MaterializedAsset {
  MaterializedAsset({required this.path, required Future<void> Function() release})
      : _release = release;
  final String path;
  final Future<void> Function() _release;
  Future<void>? _disposing;
  Future<void> dispose() => _disposing ??= _release();
}

Future<MaterializedAsset> materializeAssetBytes(Uint8List bytes, String fileName) =>
    platform.materializeAssetBytes(bytes, fileName);
