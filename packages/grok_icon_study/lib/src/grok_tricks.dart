// Ported from grok-icon-study replica/src/tricks.js — hop / pn / spinBounce / spinDizzy / spinWild.
// Source symbols: hr, ai, wie, ys.
import 'dart:math' as math;

import 'grok_math.dart';

class HopSeg {
  final double h, d;
  const HopSeg(this.h, this.d);
}

const List<HopSeg> hopSegs = [
  HopSeg(48, 0.5),
  HopSeg(28, 0.382),
  HopSeg(14, 0.27),
  HopSeg(6, 0.177),
];
final double hopDur = hopSegs.fold<double>(0, (s, x) => s + x.d);

/// 返回 null 表示 hop 已结束。
double? hopY(double hopAt, double now) {
  if (hopAt < 0) return 0;
  final et = (now - hopAt) / 1000;
  if (et >= hopDur) return null;
  var en = 0.0;
  for (final seg in hopSegs) {
    if (et < en + seg.d) {
      final bn = (et - en) / seg.d;
      return -4 * seg.h * bn * (1 - bn);
    }
    en += seg.d;
  }
  return 0;
}

class Trick {
  final String kind;
  final double t0;
  final int dir;
  final int turns;
  const Trick(this.kind, this.t0, this.dir, this.turns);
}

Trick? startTrick(String kind, bool reduce, double now, math.Random rnd) {
  if (reduce) return null;
  final dir = signOf(rnd);
  final turns = kind == 'spinDizzy'
      ? randOf(rnd, 3, 4).round()
      : kind == 'spinWild'
          ? 9
          : 1;
  return Trick(kind, now, dir, turns);
}

class TrickFrame {
  final double? turn;
  final double kr, yi, ki, yr, zr, wi;
  final double? lidMul;
  final double? eyeBoost;
  final double hop;
  final bool done;
  final bool wantHop;
  const TrickFrame({
    this.turn,
    this.kr = 0,
    this.yi = 0,
    this.ki = 0,
    this.yr = 0,
    this.zr = 0,
    this.wi = 0,
    this.lidMul,
    this.eyeBoost,
    this.hop = 0,
    this.done = false,
    this.wantHop = false,
  });
}

TrickFrame evalTrick(Trick? trick, double now) {
  if (trick == null) return const TrickFrame(done: true);
  final et = (now - trick.t0) / 1000;
  final kind = trick.kind, dir = trick.dir, turns = trick.turns;
  double? turn;
  var kr = 0.0, yi = 0.0, ki = 0.0, yr = 0.0, zr = 0.0, wi = 0.0;
  double? lidMul, eyeBoost;
  var done = false, wantHop = false;

  if (kind == 'spinDizzy') {
    final on = 0.55 + turns * 0.16, bn = 1.5;
    if (et < on) {
      final cn = et / on;
      turn = turns * math.pi * 2 * dir * (cn * cn);
    } else if (et < on + bn) {
      final cn = et - on;
      final bi = math.pow(1 - cn / bn, 1.3).toDouble();
      kr = math.sin(cn * 10) * 17 * dir * bi;
      yi = math.cos(cn * 10) * 10 * dir * bi;
      ki = math.sin(cn * 20) * 3 * bi;
      lidMul = 0.46 + 0.14 * math.sin(cn * 21);
      eyeBoost = 1.03;
    } else {
      done = true;
    }
  } else if (kind == 'spinWild') {
    const ud = 2.3 - 0.3;
    const pc = 0.5;
    const go = math.pi * 2;
    const inOut = 0.24 + 2.3 + 1.25;
    final gm = (turns * go + pc) / (0.3 / 2 + ud + 1.25 / 4);
    if (et < inOut + 1.7) {
      double cr;
      if (et < 0.24) {
        cr = -pc * (1 - math.cos((et / 0.24) * math.pi)) / 2;
      } else if (et < 0.24 + 0.3) {
        final ua = et - 0.24;
        cr = -pc + gm * ua * ua / (2 * 0.3);
      } else if (et < 0.24 + 2.3) {
        cr = -pc + gm * (0.3 / 2 + (et - 0.24 - 0.3));
      } else if (et < inOut) {
        final ua = (et - 0.24 - 2.3) / 1.25;
        cr = -pc + gm * (0.3 / 2 + ud) + gm * 1.25 * (1 - math.pow(1 - ua, 4)) / 4;
      } else {
        cr = (turns * go).toDouble();
      }
      turn = cr * dir;
      var pl = 0.0;
      if (et > 0.24 + 2.3) {
        final ua = math.min((et - 0.24 - 2.3) / 1.25, 1.0);
        pl = ua < 0.4 ? 0 : math.pow((ua - 0.4) / 0.6, 2).toDouble();
        if (et >= inOut) pl = math.pow(1 - (et - inOut) / 1.7, 1.6).toDouble();
      }
      final yl = math.max(et - 0.24 - 2.3, 0);
      yr = cr / (turns * go) * 3 * 360 * dir;
      kr = math.sin(yl * 9.2) * 11 * dir * pl;
      yi = (math.cos(yl * 9.2) - 1) * 6 * dir * pl;
      ki = math.sin(yl * 18.4) * 2.6 * pl;
      zr = math.sin(yl * 11.5) * 13 * dir * pl;
      wi = (math.cos(yl * 9) - 1) * 3.5 * pl;
      lidMul = 1.14 - 0.44 * pl + 0.1 * math.sin(yl * 16) * pl;
      eyeBoost = 1.12 - 0.09 * pl;
    } else {
      done = true;
    }
  } else if (kind == 'spinBounce') {
    if (et < 0.7) {
      turn = turns * math.pi * 2 * dir * k2(et / 0.7);
    } else {
      wantHop = true;
      done = true;
    }
  }

  return TrickFrame(
    turn: turn, kr: kr, yi: yi, ki: ki, yr: yr, zr: zr, wi: wi,
    lidMul: lidMul, eyeBoost: eyeBoost, done: done, wantHop: wantHop,
  );
}

Spring makeSpinTurn(int turns, int dir) {
  final s = Spring(0);
  s.t = turns * math.pi * 2 * dir;
  return s;
}

bool spinTurnSettled(Spring s) =>
    (s.t - s.x).abs() < 0.004 && s.v.abs() < 0.015;
