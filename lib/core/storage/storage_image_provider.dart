import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'storage_manager.dart';

/// 经 [StorageManager] 加载的图片 Provider（HTTP 远端存储或 Web IndexedDB）。
///
/// 远端存储的文件是 AES-GCM 密文，无法直接用 [NetworkImage] 指向服务器
/// URL，必须经 `readBytes` 下载解密后解码。加载完成后由 Flutter 全局
/// ImageCache 统一缓存，同一 [path] 不会重复下载。
class StorageImageProvider extends ImageProvider<StorageImageProvider> {
  const StorageImageProvider(this.manager, this.path, {this.scale = 1.0});

  final StorageManager manager;
  final String path;
  final double scale;

  @override
  Future<StorageImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<StorageImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    StorageImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
    );
  }

  Future<ui.Codec> _loadAsync(
    StorageImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await manager.readBytes(key.path);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('存储中不存在图片: ${key.path}');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is StorageImageProvider &&
      other.runtimeType == runtimeType &&
      other.path == path &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(path, scale);

  @override
  String toString() => 'StorageImageProvider("$path", scale: $scale)';
}
