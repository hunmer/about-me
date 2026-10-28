import 'dart:math';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_preferences.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_video_pet_movement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FixedRandom implements Random {
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const movement = VideoPetMovement(
    leftAnimationId: 'walk',
    rightAnimationId: 'walk',
    turnLeftAnimationId: 'turn',
    speed: 40,
    minIdleSeconds: 1,
    maxIdleSeconds: 1,
  );
  late ValueNotifier<bool> enabled;
  late JellyVideoPetPlayback playback;

  Widget stage({
    String model = 'a',
    bool active = true,
    double width = 400,
    VideoPetMovement config = movement,
  }) => MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        height: 300,
        child: JellyVideoPetStage(
          modelId: model,
          movement: config,
          enabled: enabled,
          petSize: const Size(100, 100),
          topInset: 20,
          bottomInset: 30,
          active: active,
          random: FixedRandom(),
          builder: (context, value) {
            playback = value;
            return GestureDetector(
              onPanStart: value.onDragStart,
              onPanUpdate: value.onDragUpdate,
              onPanEnd: value.onDragEnd,
              onPanCancel: value.onDragCancel,
              child: const ColoredBox(key: ValueKey('pet'), color: Colors.red),
            );
          },
        ),
      ),
    ),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoPetPreferences.randomWalkEnabled.value = false;
    enabled = ValueNotifier(false);
  });

  Future<void> load(
    WidgetTester tester, {
    String model = 'a',
    bool active = true,
    double width = 400,
    VideoPetMovement config = movement,
  }) async {
    await tester.pumpWidget(
      stage(model: model, active: active, width: width, config: config),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'actual pet box starts bottom centered and drag clamps both axes',
    (tester) async {
      await load(tester);
      expect(
        tester.getRect(find.byKey(const ValueKey('pet'))),
        const Rect.fromLTWH(150, 170, 100, 100),
      );
      playback.onDragStart(DragStartDetails());
      playback.onDragUpdate(
        DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(1000, -1000),
        ),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('pet'))),
        const Offset(300, 20),
      );
      final prefs = await SharedPreferences.getInstance();
      final key = JellyVideoPetStage.preferenceKey('a');
      expect(prefs.getDouble('$key.x'), isNull);
      playback.onDragEnd(DragEndDetails());
      await tester.pump();
      expect(prefs.getDouble('$key.x'), 1);
      expect(prefs.getDouble('$key.y'), 0);
      await load(tester, width: 200);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('pet'))),
        const Offset(100, 20),
      );
    },
  );

  testWidgets(
    'global switch follows model changes while position persists per model',
    (tester) async {
      await load(tester);
      VideoPetPreferences.randomWalkEnabled.value = true;
      playback.onDragStart(DragStartDetails());
      playback.onDragUpdate(
        DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: const Offset(-150, -150),
        ),
      );
      playback.onDragEnd(DragEndDetails());
      await tester.pump();
      await load(tester, model: 'b');
      expect(enabled.value, true);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('pet'))),
        const Offset(150, 170),
      );
      await load(tester);
      expect(enabled.value, true);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('pet'))),
        const Offset(0, 20),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'turn completes before motion, busy cancels and resumes after waiting',
    (tester) async {
      await load(tester);
      VideoPetPreferences.randomWalkEnabled.value = true;
      await tester.pump(const Duration(seconds: 1));
      expect(playback.animationId, 'turn');
      expect(playback.loop, false);
      final before = tester.getTopLeft(find.byKey(const ValueKey('pet')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getTopLeft(find.byKey(const ValueKey('pet'))), before);
      playback.onComplete();
      await tester.pump();
      expect(playback.animationId, 'walk');
      expect(playback.loop, true);
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('pet'))).dx,
        closeTo(before.dx - 40, 0.01),
      );
      playback.onBusyChanged(true);
      await tester.pump();
      expect(playback.animationId, isNull);
      final paused = tester.getTopLeft(find.byKey(const ValueKey('pet')));
      await tester.pump(const Duration(seconds: 10));
      expect(tester.getTopLeft(find.byKey(const ValueKey('pet'))), paused);
      playback.onBusyChanged(false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(playback.animationId, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'route, controls active flag, drag and background cancel turning',
    (tester) async {
      await load(tester);
      VideoPetPreferences.randomWalkEnabled.value = true;
      await tester.pump(const Duration(seconds: 1));
      expect(playback.animationId, 'turn');
      await load(tester, active: false);
      playback.onComplete();
      await tester.pump(const Duration(seconds: 10));
      expect(playback.animationId, isNull);
      await load(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(playback.animationId, isNull);
      await tester.pump(const Duration(milliseconds: 500));
      playback.onDragStart(DragStartDetails());
      await tester.pump();
      expect(playback.animationId, isNull);
      playback.onDragCancel();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(playback.animationId, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));
      expect(playback.animationId, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('missing movement or no horizontal space stays idle', (
    tester,
  ) async {
    await load(tester, config: const VideoPetMovement());
    VideoPetPreferences.randomWalkEnabled.value = true;
    await tester.pump(const Duration(seconds: 20));
    expect(playback.animationId, isNull);
    await load(tester, width: 100);
    await tester.pump(const Duration(seconds: 20));
    expect(playback.animationId, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('drag binding clears on end and cancel without another update', (
    tester,
  ) async {
    await load(tester, config: movement.copyWith(dragAnimationId: 'drag'));
    playback.onDragStart(DragStartDetails());
    await tester.pump();
    expect(playback.dragAnimationId, 'drag');
    playback.onDragEnd(DragEndDetails());
    await tester.pump();
    expect(playback.dragAnimationId, isNull);
    playback.onDragStart(DragStartDetails());
    await tester.pump();
    expect(playback.dragAnimationId, 'drag');
    playback.onDragCancel();
    await tester.pump();
    expect(playback.dragAnimationId, isNull);
  });

  testWidgets('full width logs actual blocked reason once per state change', (
    tester,
  ) async {
    final logs = <String>[];
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      await load(tester, width: 100);
      VideoPetPreferences.randomWalkEnabled.value = true;
      await tester.pump();
      expect(
        logs.any(
          (line) =>
              line.contains('enabled=true') &&
              line.contains('blocked=[noHorizontalSpace]'),
        ),
        true,
      );
      expect(logs.any((line) => line.contains('range=Size(0.0, 150.0)')), true);
      final count = logs.length;
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpWidget(stage(width: 100));
      expect(logs.length, count);
      expect(playback.animationId, isNull);
      expect(tester.getSize(find.byKey(const ValueKey('pet'))).width, 100);
      await tester.pumpWidget(const SizedBox());
    } finally {
      debugPrint = previous;
    }
  });

  testWidgets('stale turn completion cannot start a later turn', (
    tester,
  ) async {
    await load(tester);
    VideoPetPreferences.randomWalkEnabled.value = true;
    await tester.pump(const Duration(seconds: 1));
    final staleComplete = playback.onComplete;
    playback.onBusyChanged(true);
    await tester.pump();
    playback.onBusyChanged(false);
    await tester.pump(const Duration(seconds: 1));
    expect(playback.animationId, 'turn');
    staleComplete();
    await tester.pump();
    expect(playback.animationId, 'turn');
    expect(playback.loop, false);
    playback.onComplete();
    await tester.pump();
    expect(playback.animationId, 'walk');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('zero idle duration at the target remains bounded and idle', (
    tester,
  ) async {
    await load(
      tester,
      config: movement.copyWith(minIdleSeconds: 0, maxIdleSeconds: 0),
    );
    playback.onDragStart(DragStartDetails());
    playback.onDragUpdate(
      DragUpdateDetails(
        globalPosition: Offset.zero,
        delta: const Offset(-150, 0),
      ),
    );
    playback.onDragEnd(DragEndDetails());
    VideoPetPreferences.randomWalkEnabled.value = true;
    await tester.pump(const Duration(seconds: 10));
    expect(playback.animationId, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'global setting overrides legacy model switch and stops immediately',
    (tester) async {
      final key = JellyVideoPetStage.preferenceKey('a');
      SharedPreferences.setMockInitialValues({'$key.walk': true});
      await load(tester);
      expect(enabled.value, false);
      await tester.pump(const Duration(seconds: 2));
      expect(playback.animationId, isNull);

      VideoPetPreferences.randomWalkEnabled.value = true;
      expect(enabled.value, true);
      await tester.pump(const Duration(seconds: 1));
      expect(playback.animationId, 'turn');
      playback.onComplete();
      await tester.pump();
      expect(playback.animationId, 'walk');

      VideoPetPreferences.randomWalkEnabled.value = false;
      expect(enabled.value, false);
      await tester.pump();
      expect(playback.animationId, isNull);
      final position = tester.getTopLeft(find.byKey(const ValueKey('pet')));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getTopLeft(find.byKey(const ValueKey('pet'))), position);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('$key.walk'), true);
      await tester.pumpWidget(const SizedBox());
      VideoPetPreferences.randomWalkEnabled.value = true;
      expect(enabled.value, false);
    },
  );

  testWidgets('new stage and replacement notifier use current global setting', (
    tester,
  ) async {
    VideoPetPreferences.randomWalkEnabled.value = true;
    await load(tester);
    expect(enabled.value, true);
    final previous = enabled;
    enabled = ValueNotifier(false);
    await load(tester);
    expect(enabled.value, true);
    VideoPetPreferences.randomWalkEnabled.value = false;
    expect(enabled.value, false);
    expect(previous.value, true);
    await tester.pumpWidget(const SizedBox());
    previous.dispose();
  });

  testWidgets('dispose before preferences resolve is safe', (tester) async {
    await tester.pumpWidget(stage());
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
