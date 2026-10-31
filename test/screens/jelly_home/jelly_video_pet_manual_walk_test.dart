import 'dart:math';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_video_pet_movement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedRandom implements Random {
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

  Widget stage(GlobalKey<JellyVideoPetStageState> stageKey) => MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 400,
        height: 300,
        child: JellyVideoPetStage(
          key: stageKey,
          modelId: 'manual-walk-test',
          movement: movement,
          enabled: enabled,
          petSize: const Size(100, 100),
          topInset: 20,
          bottomInset: 30,
          random: _FixedRandom(),
          builder: (context, value) {
            playback = value;
            return const ColoredBox(key: ValueKey('pet'), color: Colors.red);
          },
        ),
      ),
    ),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    enabled = ValueNotifier(true);
  });

  Future<void> mount(
    WidgetTester tester,
    GlobalKey<JellyVideoPetStageState> stageKey,
  ) async {
    await tester.pumpWidget(stage(stageKey));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('manual left walk skips turn animation', (tester) async {
    final stageKey = GlobalKey<JellyVideoPetStageState>();
    await mount(tester, stageKey);

    final before = tester.getRect(find.byKey(const ValueKey('pet'))).left;
    stageKey.currentState!.walkNow(left: true);
    await tester.pump();

    expect(playback.animationId, 'walk');
    expect(playback.loop, false);
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.getRect(find.byKey(const ValueKey('pet'))).left,
      lessThan(before),
    );

    playback.onComplete();
    await tester.pump();
    expect(playback.animationId, isNull);
    final afterWalk = tester.getRect(find.byKey(const ValueKey('pet')));
    await tester.pump(const Duration(milliseconds: 990));
    expect(playback.animationId, isNull);
    expect(tester.getRect(find.byKey(const ValueKey('pet'))), afterWalk);
    await tester.pump(const Duration(milliseconds: 10));
    expect(playback.animationId, 'turn');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('wall reverse flips immediately and resets random walk delay', (
    tester,
  ) async {
    final stageKey = GlobalKey<JellyVideoPetStageState>();
    await mount(tester, stageKey);

    stageKey.currentState!.walkNow(left: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(playback.animationId, 'walk');
    final reverseTransform = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('pet')),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(reverseTransform.transform.entry(0, 0), greaterThan(0));

    final atWall = tester.getRect(find.byKey(const ValueKey('pet'))).left;
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.getRect(find.byKey(const ValueKey('pet'))).left,
      greaterThan(atWall),
    );
    expect(playback.animationId, isNull);

    final afterManualWalk = tester.getRect(find.byKey(const ValueKey('pet')));
    await tester.pump(const Duration(milliseconds: 990));
    expect(playback.animationId, isNull);
    expect(tester.getRect(find.byKey(const ValueKey('pet'))), afterManualWalk);
    await tester.pump(const Duration(milliseconds: 10));
    expect(playback.animationId, 'turn');

    await tester.pumpWidget(const SizedBox());
  });
}
