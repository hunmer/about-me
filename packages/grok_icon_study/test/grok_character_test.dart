import 'package:flutter_test/flutter_test.dart';
import 'package:grok_icon_study/grok_icon_study.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('引擎冒烟：全状态 + 全身形 + 特技 tick 无异常且输出有限值', () {
    final bot = GrokCharacter(mode: 'hold', state: 'curious', seed: 1);
    double now = 0;
    for (final group in grokGroups) {
      for (final state in group.states) {
        bot.setStateName(state, resetEyes: true);
        for (int i = 0; i < 240; i++) {
          // 约 2 秒 @120fps
          now += 1000 / 60;
          final frame = bot.tick(now);
          expect(frame.tx.isFinite, isTrue, reason: '$state tx');
          expect(frame.ty.isFinite, isTrue, reason: '$state ty');
          expect(frame.rotDeg.isFinite, isTrue, reason: '$state rot');
          expect(frame.sx > 0 && frame.sx.isFinite, isTrue, reason: '$state sx');
          expect(frame.sy > 0 && frame.sy.isFinite, isTrue, reason: '$state sy');
          expect(frame.zoom.isFinite && frame.zoom > 0, isTrue, reason: '$state zoom');
          expect(frame.bodyPath.getBounds().isEmpty, isFalse, reason: '$state body');
          expect(frame.eyes.eyes.length, 2, reason: '$state eyes');
          for (final eye in frame.eyes.eyes) {
            for (final p in eye.poly) {
              expect(p.dx.isFinite && p.dy.isFinite, isTrue, reason: '$state eye poly');
            }
          }
        }
      }
    }
    for (final shape in GrokGeometry.shapes.keys) {
      bot.setShape(shape);
      for (int i = 0; i < 120; i++) {
        now += 1000 / 60;
        bot.tick(now);
      }
    }
    bot.spinOnce(2);
    bot.bounceOnce();
    bot.burstOnce();
    for (int i = 0; i < 120; i++) {
      now += 1000 / 60;
      bot.tick(now);
    }
    expect(bot.snapshot().state, isNotEmpty);
    bot.dispose();
  });

  test('onboardMood 与源码一致', () {
    expect(onboardMood(0), 'idle');
    expect(onboardMood(1), 'curious');
    expect(onboardMood(2), 'idle');
    expect(onboardMood(3), 'happy');
    expect(onboardMood(16), 'idle');
    expect(onboardMood(17), 'curious'); // 8 态循环回绕
  });
}
