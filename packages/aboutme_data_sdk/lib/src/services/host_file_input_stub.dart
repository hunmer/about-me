import 'dart:typed_data';
import '../storage_errors.dart';

Future<Uint8List> readHostSelectedFile(String selectedPath, int maxBytes) async =>
    throw const StorageException(StorageErrorKind.unsupported,
      '此平台请选择文件字节并使用 assets.upload');
