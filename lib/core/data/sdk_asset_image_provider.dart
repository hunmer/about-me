import 'dart:ui' as ui;

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 图片缓存身份包含 SDK 实例，账号/后端之间不会共享同一图片缓存项。
class SdkAssetImageProvider extends ImageProvider<SdkAssetImageProvider> {
  const SdkAssetImageProvider(this.data, this.assetId);
  final AboutmeData data;
  final String assetId;

  @override
  Future<SdkAssetImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(SdkAssetImageProvider key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await data.assets.read(assetId);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is SdkAssetImageProvider &&
      identical(data, other.data) && assetId == other.assetId;
  @override
  int get hashCode => Object.hash(identityHashCode(data), assetId);
}
