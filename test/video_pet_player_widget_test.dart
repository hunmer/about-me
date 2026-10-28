import 'dart:convert';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_player.dart';
import 'package:flutter/gestures.dart';
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

  testWidgets(
    'movement completion is actual, once-only and cancellation-safe',
    (tester) async {
      String? movement = 'click';
      var paused = false;
      var completions = 0;
      Widget view() => MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: VideoPetPlayer(
            manifest: manifest,
            baseUri: '',
            movementAnimationId: movement,
            movementLoop: false,
            paused: paused,
            onMovementComplete: () => completions++,
          ),
        ),
      );
      await tester.pumpWidget(view());
      await loaded(tester, loop: false);
      expect(completions, 0);
      final stale = tester
          .widget<SpriteAnimation>(find.byType(SpriteAnimation))
          .onComplete!;
      paused = true;
      await tester.pumpWidget(view());
      stale();
      expect(completions, 0);
      movement = null;
      paused = false;
      await tester.pumpWidget(view());
      stale();
      expect(completions, 0);
      await loaded(tester, loop: true);
      movement = 'click';
      await tester.pumpWidget(view());
      await loaded(tester, loop: false);
      final complete = tester
          .widget<SpriteAnimation>(find.byType(SpriteAnimation))
          .onComplete!;
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 300));
      await loaded(tester, loop: true);
      expect(completions, 1);
      complete();
      expect(completions, 1);
      await tester.pumpWidget(view());
      await tester.pump(const Duration(seconds: 1));
      expect(completions, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'busy changes safely for hover and manual, movement is not busy',
    (tester) async {
      final manual = ValueNotifier<String?>(null);
      final busy = <bool>[];
      final pet = manifest.copyWith(
        hover: const VideoPetBinding(animationIds: ['click']),
      );
      var rebuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 200,
              height: 200,
              child: VideoPetPlayer(
                manifest: pet,
                baseUri: '',
                movementAnimationId: 'idle',
                animationRequest: manual,
                onPlaybackBusyChanged: (value) {
                  busy.add(value);
                  setState(() => rebuilds++);
                },
              ),
            ),
          ),
        ),
      );
      await loaded(tester, loop: true);
      expect(busy, isEmpty);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(799, 599));
      await mouse.moveTo(tester.getCenter(find.byType(VideoPetPlayer)));
      await loaded(tester, loop: true);
      await tester.pump();
      expect(busy, [true]);
      manual.value = 'click';
      await loaded(tester, loop: false);
      await mouse.moveTo(const Offset(799, 599));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 300));
      await loaded(tester, loop: true);
      await tester.pump();
      expect(busy, [true, false]);
      expect(rebuilds, 2);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      manual.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('drag interface overrides manual and restores it on release', (
    tester,
  ) async {
    final manual = ValueNotifier<String?>('click');
    String? drag;
    final busy = <bool>[];
    Widget view() => MaterialApp(
      home: SizedBox(
        width: 200,
        height: 200,
        child: VideoPetPlayer(
          manifest: manifest,
          baseUri: '',
          animationRequest: manual,
          dragAnimationId: drag,
          onPlaybackBusyChanged: busy.add,
        ),
      ),
    );
    await tester.pumpWidget(view());
    await loaded(tester, loop: false);
    final stale = tester
        .widget<SpriteAnimation>(find.byType(SpriteAnimation))
        .onComplete!;
    drag = 'idle';
    await tester.pumpWidget(view());
    await loaded(tester, loop: true);
    stale();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<SpriteAnimation>(find.byType(SpriteAnimation)).loop,
      true,
    );
    drag = null;
    await tester.pumpWidget(view());
    await loaded(tester, loop: false);
    expect(busy, [true]);
    await tester.pumpWidget(const SizedBox.shrink());
    manual.dispose();
  });

  testWidgets('drag forwards Flutter details without triggering tap', (
    tester,
  ) async {
    final starts = <DragStartDetails>[];
    final updates = <DragUpdateDetails>[];
    final ends = <DragEndDetails>[];
    var cancels = 0;
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: VideoPetPlayer(
              manifest: manifest,
              baseUri: '',
              onTap: (_, _) => taps++,
              onDragStart: starts.add,
              onDragUpdate: updates.add,
              onDragEnd: ends.add,
              onDragCancel: () => cancels++,
            ),
          ),
        ),
      ),
    );
    await loaded(tester);
    final center = tester.getCenter(find.byType(VideoPetPlayer));
    final drag = await tester.startGesture(center);
    await drag.moveBy(const Offset(40, 0));
    await drag.moveBy(const Offset(20, 10));
    await drag.up();
    expect(starts, hasLength(1));
    expect(updates, isNotEmpty);
    expect(ends, hasLength(1));
    expect(taps, 0);
    final cancel = await tester.startGesture(center);
    await cancel.cancel();
    expect(cancels, 1);
    expect(taps, 0);
    await tester.tapAt(center);
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('identical parent rebuilds preserve movement loading', (
    tester,
  ) async {
    Widget view() => MaterialApp(
      home: SizedBox(
        width: 200,
        height: 200,
        child: VideoPetPlayer(
          manifest: manifest,
          baseUri: '',
          movementAnimationId: 'click',
          movementLoop: false,
        ),
      ),
    );
    await tester.pumpWidget(view());
    for (var i = 0; i < 10; i++) {
      await tester.pumpWidget(view());
    }
    await loaded(tester, loop: false);
    final controller = tester
        .widget<SpriteAnimation>(find.byType(SpriteAnimation))
        .controller;
    for (var i = 0; i < 5; i++) {
      await tester.pumpWidget(view());
    }
    expect(
      tester.widget<SpriteAnimation>(find.byType(SpriteAnimation)).controller,
      same(controller),
    );
    await tester.pumpWidget(const SizedBox.shrink());
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
