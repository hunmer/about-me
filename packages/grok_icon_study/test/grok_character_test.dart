import 'package:flutter_test/flutter_test.dart';
import 'package:grok_icon_study/grok_icon_study.dart';
import 'package:grok_icon_study/src/grok_fx.dart';

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

  test('pencil/bang 路径几何：胶囊 30x88、锥形上宽 30 下宽 17 长 96', () {
    final r = GrokGeometry.re;
    // capsule(30, 88, R)：宽 30、总长 88、上下半圆端帽，左右对称于 x=R
    final pencil = capsulePath(30, 88, r);
    final pb = pencil.getBounds();
    expect(pb.width, closeTo(30, 0.01));
    expect(pb.height, closeTo(88, 0.01));
    expect(pb.left, closeTo(r - 15, 0.01));
    expect(pb.top, closeTo(r - 44, 0.01));

    // taper(30, 17, 96, R)：顶部半圆宽 30、底部半圆宽 17、总长 96
    final bang = taperPath(30, 17, 96, r);
    final bb = bang.getBounds();
    expect(bb.width, closeTo(30, 0.01));
    expect(bb.height, closeTo(96, 0.01));
    expect(bb.left, closeTo(r - 15, 0.01));
    expect(bb.top, closeTo(r - 48, 0.01));

    // 顶帽（上半圆，圆心 (R, R-33) 半径 15）：y=R-40 处 ±13 在内、±15 在外
    expect(bang.contains(Offset(r - 13, r - 40)), isTrue);
    expect(bang.contains(Offset(r + 13, r - 40)), isTrue);
    expect(bang.contains(Offset(r - 15.5, r - 40)), isFalse);
    // 底帽（下半圆，圆心 (R, R+39.5) 半径 8.5）：y=R+44 处 ±7 在内、±10 在外
    expect(bang.contains(Offset(r - 7, r + 44)), isTrue);
    expect(bang.contains(Offset(r + 7, r + 44)), isTrue);
    expect(bang.contains(Offset(r - 10, r + 44)), isFalse);
    // 中部锥形收窄：y=R 处 ±11 在内、±13 在外
    expect(bang.contains(Offset(r - 11, r)), isTrue);
    expect(bang.contains(Offset(r - 13, r)), isFalse);
  });
}
