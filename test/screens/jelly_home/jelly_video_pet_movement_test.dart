import 'dart:math';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_preferences.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_video_pet_movement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FixedRandom implements Random {
  FixedRandom([this.value = 0]);
  final double value;
  @override
  double nextDouble() => value;
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
    double randomValue = 0,
    List<VideoPetAnimation> animations = const [],
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
          animations: animations,
          enabled: enabled,
          petSize: const Size(100, 100),
          topInset: 20,
          bottomInset: 30,
          active: active,
          random: FixedRandom(randomValue),
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

  for (final facing in ['left', 'right']) {
    for (final moveLeft in [true, false]) {
      testWidgets(
        '$facing resource mirrors correctly when moveLeft=$moveLeft',
        (tester) async {
          await tester.pumpWidget(
            stage(
              randomValue: moveLeft ? 0 : .99,
              config: movement.copyWith(turnLeftAnimationId: ''),
              animations: [
                VideoPetAnimation(id: 'walk', name: 'walk', facing: facing),
              ],
            ),
          );
          await tester.pump();
          VideoPetPreferences.randomWalkEnabled.value = true;
          await tester.pump(const Duration(seconds: 1));
          expect(playback.animationId, 'walk');
          final transform = tester.widget<Transform>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('pet')),
                  matching: find.byType(Transform),
                )
                .first,
          );
          final flipped = transform.transform.entry(0, 0) < 0;
          expect(flipped, (facing == 'left') != moveLeft);
          playback.onDragStart(DragStartDetails());
          await tester.pump();
          final dragTransform = tester.widget<Transform>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('pet')),
                  matching: find.byType(Transform),
                )
                .first,
          );
          expect(dragTransform.transform.entry(0, 0), 1);
          playback.onDragCancel();
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

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
    double randomValue = 0,
    VideoPetMovement config = movement,
  }) async {
    await tester.pumpWidget(
      stage(
        model: model,
        active: active,
        width: width,
        randomValue: randomValue,
        config: config,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('default walk starts at 10 seconds, not 9.9', (tester) async {
    await load(
      tester,
      config: const VideoPetMovement(
        leftAnimationId: 'walk',
        rightAnimationId: 'walk',
      ),
    );
    VideoPetPreferences.randomWalkEnabled.value = true;
    await tester.pump(const Duration(milliseconds: 9900));
    expect(playback.animationId, isNull);
    await tester.pump(const Duration(milliseconds: 100));
    expect(playback.animationId, 'walk');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('busy completion starts a fresh full 10 second wait', (
    tester,
  ) async {
    await load(
      tester,
      config: const VideoPetMovement(
        leftAnimationId: 'walk',
        rightAnimationId: 'walk',
      ),
    );
    VideoPetPreferences.randomWalkEnabled.value = true;
    await tester.pump(const Duration(seconds: 9));
    playback.onBusyChanged(true);
    await tester.pump(const Duration(seconds: 30));
    expect(playback.animationId, isNull);
    final before = tester.getTopLeft(find.byKey(const ValueKey('pet')));
    playback.onBusyChanged(false);
    await tester.pump(const Duration(milliseconds: 9900));
    expect(playback.animationId, isNull);
    expect(tester.getTopLeft(find.byKey(const ValueKey('pet'))), before);
    await tester.pump(const Duration(milliseconds: 100));
    expect(playback.animationId, 'walk');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('drag completion starts a fresh full 10 second wait', (
    tester,
  ) async {
    await load(
      tester,
      config: const VideoPetMovement(
        leftAnimationId: 'walk',
        rightAnimationId: 'walk',
      ),
    );
    VideoPetPreferences.randomWalkEnabled.value = true;
    await tester.pump(const Duration(seconds: 9));
    playback.onDragStart(DragStartDetails());
    await tester.pump(const Duration(seconds: 30));
    expect(playback.animationId, isNull);
    playback.onDragEnd(DragEndDetails());
    await tester.pump(const Duration(milliseconds: 9900));
    expect(playback.animationId, isNull);
    await tester.pump(const Duration(milliseconds: 100));
    expect(playback.animationId, 'walk');
    await tester.pumpWidget(const SizedBox());
  });

  for (final randomValue in [0.5, 0.501]) {
    testWidgets(
      'near target $randomValue keeps this walk and travels visibly',
      (tester) async {
        await load(tester, randomValue: randomValue);
        VideoPetPreferences.randomWalkEnabled.value = true;
        await tester.pump(const Duration(seconds: 1));
        expect(playback.animationId, 'turn');
        playback.onComplete();
        await tester.pump();
        expect(playback.animationId, 'walk');
        await tester.pump(const Duration(seconds: 2));
        expect(
          tester.getRect(find.byKey(const ValueKey('pet'))).left,
          closeTo(70, 0.01),
        );
        expect(playback.animationId, 'walk');
        await tester.pumpWidget(const SizedBox());
      },
    );
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

  testWidgets('missing movement stays idle even with horizontal space', (
    tester,
  ) async {
    await load(tester, config: const VideoPetMovement(), width: 100);
    VideoPetPreferences.randomWalkEnabled.value = true;
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

  testWidgets('full width stays centered and clamps, persists and resizes', (
    tester,
  ) async {
    await load(tester, width: 100);
    final pet = find.byKey(const ValueKey('pet'));
    expect(tester.getRect(pet), const Rect.fromLTWH(0, 170, 100, 100));
    await tester.drag(pet, const Offset(1000, -1000));
    await tester.pump();
    expect(tester.getTopLeft(pet), const Offset(50, 20));
    var prefs = await SharedPreferences.getInstance();
    final key = JellyVideoPetStage.preferenceKey('a');
    expect(prefs.getDouble('$key.x'), 1);
    await tester.dragFrom(const Offset(75, 60), const Offset(-1000, 1000));
    await tester.pump();
    expect(tester.getTopLeft(pet), const Offset(-50, 170));
    expect(prefs.getDouble('$key.x'), 0);
    // A fresh stage restores the normalized left edge on the new bounds.
    await tester.pumpWidget(const SizedBox());
    await load(tester, width: 80);
    expect(tester.getTopLeft(pet), const Offset(-40, 190));
    expect(tester.getSize(pet).width, 80);
    await load(tester, width: 200);
    expect(tester.getTopLeft(pet), const Offset(0, 170));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'full width walks horizontally and mirrored drag follows pointer',
    (tester) async {
      final logs = <String>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        await load(tester, width: 100);
        VideoPetPreferences.randomWalkEnabled.value = true;
        await tester.pump(const Duration(seconds: 1));
        expect(playback.animationId, 'turn');
        playback.onComplete();
        await tester.pump();
        expect(playback.animationId, 'walk');
        await tester.pump(const Duration(milliseconds: 500));
        final pet = find.byKey(const ValueKey('pet'));
        expect(tester.getRect(pet).left, closeTo(-20, .01));
        expect(logs.any((line) => line.contains('xBounds=[-50.0,50.0]')), true);
        expect(
          logs.any((line) => line.contains('target selected x=-50.0')),
          true,
        );
        expect(
          logs.any((line) => line.contains('blocked=[noHorizontalSpace]')),
          false,
        );
        VideoPetPreferences.randomWalkEnabled.value = false;
        await tester.pump();
        final before = tester.getRect(pet).left;
        await tester.dragFrom(const Offset(40, 210), const Offset(30, 0));
        await tester.pump();
        expect(tester.getRect(pet).left, greaterThan(before));
        final right = tester.getRect(pet).left;
        await tester.dragFrom(const Offset(50, 210), const Offset(-30, 0));
        await tester.pump();
        expect(tester.getRect(pet).left, lessThan(right));
        expect(tester.getSize(pet).width, 100);
        await tester.pumpWidget(const SizedBox());
      } finally {
        debugPrint = previous;
      }
    },
  );

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

  testWidgets(
    'zero idle and target at current position walks without retry wait',
    (tester) async {
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
      await tester.pump(const Duration(milliseconds: 100));
      expect(playback.animationId, 'walk');
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('pet'))).dx,
        closeTo(80, 0.01),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

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
