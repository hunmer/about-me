import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final manifestFile = File(kDefaultVideoPetManifestAsset);
  final manifest =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final animations = (manifest['animations'] as List)
      .cast<Map<String, dynamic>>();

  test('default manifest contains all 108 distinct WebP animations', () {
    VideoPetManifest.fromJson(manifest).validate();
    expect(animations, hasLength(108));
    expect(
      animations.map((animation) => animation['id']).toSet(),
      hasLength(108),
    );
    final sources = <String>{};
    for (final animation in animations) {
      final sourceMap = animation['sources'] as Map<String, dynamic>;
      expect(sourceMap.keys, unorderedEquals(['webp']));
      final source = sourceMap['webp'] as String;
      expect(source, startsWith('spritesheet/'));
      expect(source, endsWith('.webp'));
      sources.add(source);
    }
    expect(sources, hasLength(108));
  });

  test('Flutter decodes a full-size bundled WebP', () async {
    final source =
        (animations.first['sources'] as Map<String, dynamic>)['webp'] as String;
    final bytes = File.fromUri(
      manifestFile.uri.resolve(source),
    ).readAsBytesSync();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        expect(frame.image.width, 5120);
        expect(frame.image.height, 5400);
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  });

  for (final animation in animations.where(
    (animation) => animation['audio'] != null,
  )) {
    test('Flutter decodes ${animation['id']} full-size WebP', () async {
      final source =
          (animation['sources'] as Map<String, dynamic>)['webp'] as String;
      final bytes = File.fromUri(
        manifestFile.uri.resolve(source),
      ).readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        try {
          expect(frame.image.width, 5120);
          expect(frame.image.height, 16200);
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    });
  }

  for (final animation in animations) {
    test(
      '${animation['id']}: WebP, byte limit, grid metadata and effective-frame RGBA',
      () {
        final source =
            (animation['sources'] as Map<String, dynamic>)['webp'] as String;
        final spritesheet = animation['spritesheet'] as Map<String, dynamic>;
        for (final key in [
          'frameWidth',
          'frameHeight',
          'columns',
          'rows',
          'frameCount',
        ]) {
          expect(spritesheet[key], isA<int>(), reason: key);
          expect(spritesheet[key], greaterThan(0), reason: key);
        }
        final frameWidth = spritesheet['frameWidth'] as int;
        final frameHeight = spritesheet['frameHeight'] as int;
        final columns = spritesheet['columns'] as int;
        final rows = spritesheet['rows'] as int;
        final frameCount = spritesheet['frameCount'] as int;
        expect(spritesheet['fps'], isA<num>());
        final fps = spritesheet['fps'] as num;
        expect(fps.isFinite && fps > 0, isTrue);
        expect(frameCount, lessThanOrEqualTo(columns * rows));

        final imageFile = File.fromUri(manifestFile.uri.resolve(source));
        final metadataFile = File.fromUri(
          imageFile.uri.replace(
            path: imageFile.uri.path.replaceFirst(RegExp(r'\.webp$'), '.json'),
          ),
        );
        expect(imageFile.existsSync(), isTrue, reason: imageFile.path);
        expect(metadataFile.existsSync(), isTrue, reason: metadataFile.path);
        final metadata =
            jsonDecode(metadataFile.readAsStringSync()) as Map<String, dynamic>;
        expect(metadata['FrameWidth'], frameWidth);
        expect(metadata['FrameHeight'], frameHeight);
        expect(metadata['Columns'], columns);
        expect(metadata['Rows'], rows);
        expect(metadata['FrameCount'], frameCount);
        expect(metadata['SampleFps'], fps);
        expect(metadata['CanvasWidth'], frameWidth * columns);
        expect(metadata['CanvasHeight'], frameHeight * rows);
        expect(frameWidth, manifest['canvasWidth']);
        expect(frameHeight, manifest['canvasHeight']);
        expect(fps, 12);
        final isLongAnimation = const {
          '工作加班',
          '熬夜刷手机',
        }.contains(animation['id']);
        expect(
          frameCount,
          isLongAnimation ? 360 : (animation['id'] == '工作状态-垂头叹气冒汗' ? 59 : 120),
        );
        expect(frameWidth * columns, lessThanOrEqualTo(8192));
        expect(
          frameHeight * rows,
          lessThanOrEqualTo(isLongAnimation ? 16384 : 8192),
        );
        final sourceDuration = metadata['SourceDurationSeconds'] as num;
        expect(
          (frameCount / fps - sourceDuration).abs(),
          lessThanOrEqualTo(1 / fps),
          reason: '采样后的时长偏差不应超过一帧',
        );
        // WebM files are ignored local conversion inputs, not test fixtures.
        expect(metadata['SourceVideoBytes'], greaterThan(0));

        final bytes = imageFile.readAsBytesSync();
        expect(bytes, isNotEmpty);
        final maxBytes = isLongAnimation ? 4000000 : 1000000;
        expect(bytes.length, lessThan(maxBytes));
        expect(metadata['ImageFormat'], 'webp');
        expect(metadata['Lossless'], isFalse);
        expect(metadata['EncodedBytes'], bytes.length);
        expect(metadata['MaxImageBytes'], maxBytes);
        expect(metadata['EncodingQuality'], inInclusiveRange(0, 100));
        expect(metadata['AlphaQuality'], inInclusiveRange(1, 100));
        final image = img.decodeWebP(bytes);
        expect(image, isNotNull, reason: imageFile.path);
        expect(image!.width, frameWidth * columns);
        expect(image.height, frameHeight * rows);
        expect(image.numChannels, 4);
        if (isLongAnimation) {
          expect(metadata['SourcePixFmt'], 'yuva444p12le');
          expect(metadata['Alpha'], 'RGBA');
          expect(metadata['HasAudio'], isTrue);
          expect(metadata['AudioBytes'], greaterThan(0));
          expect(metadata['AudioNote'], contains('Source video has no audio'));
        }

        var hasTransparentPixel = false;
        var hasVisiblePixel = false;
        // Visit only actual frames: unused grid cells must not satisfy Alpha.
        frames:
        for (var frame = 0; frame < frameCount; frame++) {
          final left = (frame % columns) * frameWidth;
          final top = (frame ~/ columns) * frameHeight;
          for (var y = top; y < top + frameHeight; y++) {
            for (var x = left; x < left + frameWidth; x++) {
              final alpha = image.getPixel(x, y).a;
              hasTransparentPixel |= alpha == 0;
              hasVisiblePixel |= alpha > 0;
              if (hasTransparentPixel && hasVisiblePixel) break frames;
            }
          }
        }
        expect(hasTransparentPixel, isTrue, reason: '有效帧应包含透明像素');
        expect(hasVisiblePixel, isTrue, reason: '有效帧应包含可见像素');
      },
    );
  }
}
