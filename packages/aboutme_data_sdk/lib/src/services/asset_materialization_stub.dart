import 'dart:typed_data';

import '../storage_errors.dart';
import 'asset_materialization.dart';

Future<MaterializedAsset> materializeAssetBytes(Uint8List bytes, String fileName) async =>
    throw const StorageException(StorageErrorKind.unsupported,
      '此平台不支持文件路径物化，请使用 assets.read 读取资源字节');
