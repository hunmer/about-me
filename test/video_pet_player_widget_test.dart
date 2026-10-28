import 'dart:convert';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spritesheet_animation/flutter_spritesheet_animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  final image = img.Image(width: 4, height: 2, numChannels: 4);
  image.setPixelRgba(0, 0, 255, 0, 0, 255);
  image.setPixelRgba(2, 0, 0, 255, 0, 255);
  final uri = Uri.dataFromBytes(
    img.encodePng(image),
    mimeType: 'image/png',
  ).toString();
  const sheet = VideoPetSpritesheet(
    frameWidth: 2,
    frameHeight: 2,
    columns: 2,
    rows: 1,
    frameCount: 2,
    fps: 10,
  );
  final manifest = VideoPetManifest(
    id: 'test',
    name: 'test',
    canvasWidth: 2,
    canvasHeight: 2,
    idleAnimationId: 'idle',
    animations: [
      VideoPetAnimation(
        id: 'idle',
        name: 'idle',
        sources: {'png': uri},
        spritesheet: sheet,
      ),
      VideoPetAnimation(
        id: 'click',
        name: 'click',
        sources: {'png': uri},
        spritesheet: sheet,
      ),
    ],
    click: const VideoPetBinding(animationIds: ['click']),
  );

  Future<void> loaded(WidgetTester tester, {bool? loop}) async {
    bool ready() =>
        find.byType(SpriteAnimation).evaluate().length == 1 &&
        (loop == null ||
            tester.widget<SpriteAnimation>(find.byType(SpriteAnimation)).loop ==
                loop);
    for (var i = 0; i < 30 && !ready(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(ready(), isTrue);
    await tester.pump();
  }

  testWidgets('sprite playback pauses, resumes and completes a click', (
    tester,
  ) async {
    var paused = false;
    final request = ValueNotifier<String?>(null);
    Widget view() => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: VideoPetPlayer(
            manifest: manifest,
            baseUri: '',
            paused: paused,
            animationRequest: request,
          ),
        ),
      ),
    );
    await tester.pumpWidget(view());
    await loaded(tester);
    SpriteAnimation sprite() =>
        tester.widget<SpriteAnimation>(find.byType(SpriteAnimation));
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump(const Duration(milliseconds: 110));
    expect(sprite().controller!.isPlaying, isTrue);
    paused = true;
    await tester.pumpWidget(view());
    final frame = sprite().controller!.currentFrame;
    await tester.pump(const Duration(seconds: 1));
    expect(sprite().controller!.currentFrame, frame);
    expect(sprite().controller!.isPlaying, isFalse);
    paused = false;
    await tester.pumpWidget(view());
    expect(sprite().controller!.isPlaying, isTrue);
    request.value = 'click';
    await loaded(tester, loop: false);
    expect(sprite().loop, isFalse);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 300));
    await loaded(tester, loop: true);
    expect(sprite().loop, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    request.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('WebP decodes, uses mappings and preserves PNG package copies', (
    tester,
  ) async {
    const webpBase64 =
        'UklGRnoAAABXRUJQVlA4WAoAAAAQAAAAAwAAAQAAQUxQSAkAAAAA/wD/AAAAAAAAVlA4IEoAAACwAgCdASoEAAIAAkA4JagCdLoB+AH4gM4AyQAHugAA/uLq9tR1fu/9UwcuikwBkGvtw//Kv/8sD2DXyoeHWd/+WB7Br5UP/OMAAA==';
    for (final format in ['webp', 'png']) {
      final source = 'spritesheet/idle.$format';
      final data = format == 'webp'
          ? 'data:image/webp;base64,$webpBase64'
          : uri;
      final mapped = manifest.copyWith(
        id: 'dsh-pet',
        animations: [
          for (final animation in manifest.animations)
            animation.copyWith(sources: {format: source}),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: VideoPetPlayer(
              manifest: mapped,
              baseUri: 'assets/live2d/video/dsh_pet/',
              resolvedSources: {
                Uri.parse(
                  'assets/live2d/video/dsh_pet/',
                ).resolve(source).toString(): data,
              },
            ),
          ),
        ),
      );
      await loaded(tester);
      final sprite = tester.widget<SpriteAnimation>(
        find.byType(SpriteAnimation),
      );
      final provider = sprite.image as MemoryImage;
      expect(
        provider.bytes,
        format == 'webp'
            ? base64Decode(webpBase64)
            : Uri.parse(uri).data!.contentAsBytes(),
      );
      expect(sprite.columns, sheet.columns);
      expect(sprite.rows, sheet.rows);
      expect(sprite.frameCount, sheet.frameCount);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'contain letterbox ignores taps and edit pointers are normalized',
    (tester) async {
      final taps = <String?>[];
      final points = <Offset>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 400,
              height: 200,
              child: VideoPetPlayer(
                manifest: manifest,
                baseUri: '',
                onTap: (id, name) => taps.add(id),
                onEditPointer: (type, x, y) {
                  if (type == 'pointerdown') points.add(Offset(x, y));
                },
              ),
            ),
          ),
        ),
      );
      await loaded(tester);
      final rect = tester.getRect(find.byType(VideoPetPlayer));
      await tester.tapAt(rect.topLeft + const Offset(20, 100));
      expect(taps, isEmpty);
      expect(points, isEmpty);
      await tester.tapAt(rect.center);
      expect(taps, hasLength(1));
      expect(points.single, const Offset(.5, .5));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
