// 临时诊断：观察各状态/帧率下 grokbot 转圈的圈数来源。
// 跑法：flutter test test/grok_spin_debug_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:grok_icon_study/grok_icon_study.dart';

void main() {
  void run({
    required String label,
    required List<(String, double)> script, // (state, 持续秒)
    required int fps,
  }) {
    final c = GrokCharacter(mode: 'hold', state: 'idle');
    var now = 0.0; // ms
    // 预热 1 秒稳定姿态
    for (var i = 0; i < fps; i++) {
      now += 1000 / fps;
      c.tick(now);
    }
    var lastTurn = 0.0;
    var travel = 0.0; // 角度行程累计（rad）
    var maxAbs = 0.0;
    final log = <String>[];
    for (final (state, dur) in script) {
      if (state != 'idle') c.setStateName(state);
      final frames = (dur * fps).round();
      for (var i = 0; i < frames; i++) {
        now += 1000 / fps;
        c.tick(now);
        // 渲染口径：spinTurn 优先，settle 后落到 extras.turn（镜像保持），不叠加
        final t = c.spinTurn?.x ?? c.extras.turn ?? 0;
        travel += (t - lastTurn).abs();
        if (t.abs() > maxAbs) maxAbs = t.abs();
        lastTurn = t;
      }
      log.add('$state dur=${dur}s');
    }
    // ignore: avoid_print
    print(
      '[$label fps=$fps] script=${log.join(",")} '
      'travel=${(travel / 6.28318).toStringAsFixed(2)}圈 maxAbs=${(maxAbs / 6.28318).toStringAsFixed(2)}圈',
    );
    c.dispose();
  }

  test('idle 20s 不应转圈', () {
    run(label: 'idle', script: const [('idle', 20)], fps: 60);
  });

  test('happy 2s + idle 15s，60fps', () {
    run(
      label: 'happy→idle',
      script: const [('happy', 2), ('idle', 15)],
      fps: 60,
    );
  });

  test('happy 2s + idle 15s，8fps（dt clamp）', () {
    run(
      label: 'happy→idle',
      script: const [('happy', 2), ('idle', 15)],
      fps: 8,
    );
  });

  test('happy 2s + idle 15s，3fps（重 clamp）', () {
    run(
      label: 'happy→idle',
      script: const [('happy', 2), ('idle', 15)],
      fps: 3,
    );
  });

  test('连续换形状 6 次（模拟多 bot 切换），恒单圈', () {
    final shapes = GrokGeometry.shapes.keys.toList();
    final c = GrokCharacter(mode: 'hold', state: 'idle');
    var now = 0.0;
    for (var i = 0; i < 60; i++) {
      now += 1000 / 60;
      c.tick(now);
    }
    var lastTurn = 0.0;
    var travel = 0.0;
    var maxAbs = 0.0;
    // ignore: avoid_print
    print('[shapes] 共 ${shapes.length} 个: ${shapes.take(8).toList()}');
    for (var s = 0; s < 6; s++) {
      c.setShape(shapes[s % shapes.length]);
      var segTravel = 0.0;
      var segMax = 0.0;
      for (var i = 0; i < 120; i++) {
        now += 1000 / 60;
        c.tick(now);
        // 渲染口径：spinTurn 优先，settle 后落到 extras.turn（镜像保持），不叠加
        final t = c.spinTurn?.x ?? c.extras.turn ?? 0;
        segTravel += (t - lastTurn).abs();
        if (t.abs() > segMax) segMax = t.abs();
        lastTurn = t;
      }
      travel += segTravel;
      if (segMax > maxAbs) maxAbs = segMax;
      // ignore: avoid_print
      print(
        '  [setShape#$s ${shapes[s % shapes.length]}] '
        'travel=${(segTravel / 6.28318).toStringAsFixed(2)}圈 '
        'maxAbs=${(segMax / 6.28318).toStringAsFixed(2)}圈',
      );
    }
    // ignore: avoid_print
    print(
      '[setShape×6 fps=60] travel=${(travel / 6.28318).toStringAsFixed(2)}圈 '
      'maxAbs=${(maxAbs / 6.28318).toStringAsFixed(2)}圈',
    );
    c.dispose();
  });
}
