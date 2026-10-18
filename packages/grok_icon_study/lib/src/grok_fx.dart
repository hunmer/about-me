// Ported from grok-icon-study replica/src/fx.js — overlay glyphs + particle ribbons.
// Source symbols: E_t I_t za/$a/Ms/oi/_r/ua/No/Eo/Ho/hl/cd/Bt.
import 'dart:math' as math;
import 'dart:ui' show Path;

import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'grok_geometry.dart';
import 'grok_math.dart';
import 'package:flutter/painting.dart' show Color, HSLColor;

const double re0 = 114.2705;
const int starColorValue = GrokGeometry.starColor;
const List<int> particlePalette = [
  0xFFF9705C, 0xFF5B95F0, 0xFF3FBE86, 0xFFF5B13F, 0xFF9A72EE, 0xFF35C3BD,
];

/// 状态 → overlay 种类。
const Map<String, String> overlayMap = {
  'thinking': 'dots',
  'orbit': 'orbit',
  'radar': 'radar',
  'progress': 'progress',
  'spawning': 'gather',
  'dictating': 'wave',
  'sending': 'send',
  'receiving': 'receive',
  'uploading': 'dock',
  'bouncing': 'ball',
  'loading': 'whirl',
  'powering-down': 'standby',
  'writing': 'pencil',
  'alerting': 'bang',
};
const Set<String> overlayCycle = {'progress', 'spawning'};
const Map<String, double> cycleOnMs = {'progress': 2500, 'spawning': 2000};
const double cycleOffMs = 1500;
const Map<String, double> overlayScale = {
  'dots': 1.5, 'orbit': 1.14, 'radar': 1.14, 'progress': 1.32, 'gather': 1.15,
  'wave': 1.42, 'send': 1.12, 'receive': 1.12, 'dock': 1.3, 'ball': 1.22,
  'whirl': 1.45, 'pencil': 1.18, 'bang': 1.28, 'standby': 1.75,
};
const Map<String, double> overlayRadius = {
  'dots': 22, 'orbit': 19, 'radar': 19, 'progress': 19, 'gather': 19, 'wave': 16,
  'send': 20, 'receive': 20, 'dock': 20, 'ball': 18, 'whirl': 15, 'pencil': 17,
  'bang': 13, 'standby': 13,
};
const double pBlend = 0.62;
const double dotR = 22;
const double dotGap = 62;
const double pop0 = 0.84;
const double pop1 = 0.22;
const double sendMs = 1500;
const double recvMs = 1700;
const double pencilMs = 2500;

final Path starPathObj = _polyPath(flattenPath(GrokGeometry.starPath));

Path _polyPath(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final pt in pts.skip(1)) {
    p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// Source closedSpline — Catmull-Rom 风格闭合样条。
Path closedSpline(List<Offset> pts) {
  final e = pts.length;
  final p = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (int s = 0; s < e; s++) {
    final r = pts[(s - 1 + e) % e], i = pts[s], o = pts[(s + 1) % e], l = pts[(s + 2) % e];
    p.cubicTo(
      i.dx + (o.dx - r.dx) / 6, i.dy + (o.dy - r.dy) / 6,
      o.dx - (l.dx - i.dx) / 6, o.dy - (l.dy - i.dy) / 6,
      o.dx, o.dy,
    );
  }
  return p..close();
}

List<Offset> circleRing(double r, [int n = 96]) => List.generate(n, (e) {
      final a = (e / n) * math.pi * 2;
      return Offset(r + math.cos(a) * r, r + math.sin(a) * r);
    });

List<Offset> polarRing(List<Offset> pts, double r, [int n = 96]) =>
    List.generate(n, (idx) {
      final s = (idx / n) * math.pi * 2, c = math.cos(s), i = math.sin(s);
      var o = 0.0;
      for (int l = 0; l < pts.length; l++) {
        final a = pts[l], b = pts[(l + 1) % pts.length];
        final d = a.dx - r, m = a.dy - r, f = b.dx - r, h = b.dy - r;
        final y = (f - d) * i - (h - m) * c;
        if (y.abs() < 1e-9) continue;
        final k = (d * i - m * c) / -y;
        if (k < 0 || k > 1) continue;
        final v = (d + (f - d) * k) * c + (m + (h - m) * k) * i;
        if (v > o) o = v;
      }
      return Offset(r + c * o, r + i * o);
    });

List<Offset> rotateRing(List<Offset> ring, int e, double r) {
  final n = ring.length;
  final s = (e / n) * math.pi * 2, c = math.cos(s), i = math.sin(s);
  return List.generate(n, (l) {
    final p = ring[((l - e) % n + n) % n];
    final d = p.dx - r, m = p.dy - r;
    return Offset(r + d * c - m * i, r + d * i + m * c);
  });
}

List<Offset> lerpRing(List<Offset> a, List<Offset> b, double t) =>
    List.generate(a.length, (i) => Offset(a[i].dx + (b[i].dx - a[i].dx) * t, a[i].dy + (b[i].dy - a[i].dy) * t));

(double, double) spanHalf(List<Offset> ring, double y, double r) {
  var left = double.negativeInfinity, right = double.infinity;
  for (int i = 0; i < ring.length; i++) {
    final a = ring[i], b = ring[(i + 1) % ring.length];
    if ((a.dy <= y) == (b.dy <= y)) continue;
    final x = a.dx + (b.dx - a.dx) * (y - a.dy) / (b.dy - a.dy);
    if (x <= r) {
      if (x > left) left = x;
    } else if (x < right) {
      right = x;
    }
  }
  return (left.isFinite ? left : r, right.isFinite ? right : r);
}

/// Source capsule — 胶囊（铅笔笔身）。
Path capsulePath(double n, double e, double r) {
  final w = n / 2, top = r - e / 2 + w, bot = r + e / 2 - w;
  final rect1 = Rect.fromCircle(center: Offset(r - w, top), radius: w);
  final rect2 = Rect.fromCircle(center: Offset(r + w, bot), radius: w);
  return Path()
    ..moveTo(r - w, top)
    ..arcTo(rect1, math.pi, math.pi / 2, false)
    ..arcTo(Rect.fromCircle(center: Offset(r + w, top), radius: w), -math.pi / 2, math.pi / 2, false)
    ..lineTo(r + w, bot)
    ..arcTo(rect2, -math.pi / 2, math.pi / 2, false)
    ..arcTo(Rect.fromCircle(center: Offset(r - w, bot), radius: w), math.pi / 2, math.pi / 2, false)
    ..close();
}

/// Source taper — 锥形（感叹号）。
Path taperPath(double n, double e, double len, double r) {
  final s = n / 2, rr = e / 2, i = r - len / 2, o = r + len / 2;
  final topArc = Rect.fromCircle(center: Offset(r - s, i + s), radius: s);
  return Path()
    ..moveTo(r - s, i + s)
    ..arcTo(topArc, math.pi, math.pi / 2, false)
    ..arcTo(Rect.fromCircle(center: Offset(r + s, i + s), radius: s), -math.pi / 2, math.pi / 2, false)
    ..lineTo(r + rr, o - rr)
    ..arcTo(Rect.fromCircle(center: Offset(r - rr, o - rr), radius: rr), -math.pi / 2, math.pi / 2, false)
    ..arcTo(Rect.fromCircle(center: Offset(r + rr, o - rr), radius: rr), math.pi / 2, math.pi / 2, false)
    ..close();
}

final Map<String, List<Offset>> _ringCache = {};
List<Offset> shapeRing(String path, double r) =>
    _ringCache.putIfAbsent(path, () => polarRing(flattenPath(path), r));

class PencilPose {
  final double x, y, wig, rot;
  final bool lift;
  const PencilPose(this.x, this.y, this.wig, this.rot, this.lift);
}

PencilPose pencilPose(double now, double stateAt) {
  final pt = now - stateAt;
  final mt = (((pt / pencilMs) % 1) + 1) % 1;
  if (mt < 0.68) {
    final mtN = mt / 0.68;
    final lt = mtN * mtN * (3 - 2 * mtN);
    final yn = clampN(mtN / 0.08, 0, 1) * clampN((1 - mtN) / 0.08, 0, 1);
    return PencilPose(-54 + 118 * lt, 26, math.sin(mtN * 24) * 3.2 * yn,
        17 + math.sin(pt * 6e-4) * 1, false);
  }
  final dt = k2((mt - 0.68) / 0.32);
  return PencilPose(
    64 - 118 * dt,
    26 - 20 * math.sin(dt * math.pi),
    0,
    17 - 2 * math.sin(dt * math.pi) + math.sin(pt * 6e-4) * 1,
    true,
  );
}

Path smoothLine(List<Offset> pts) {
  final pt = pts.length;
  final p = Path()..moveTo(pts[0].dx, pts[0].dy);
  if (pt == 2) return p..lineTo(pts[1].dx, pts[1].dy);
  for (int d = 0; d < pt - 1; d++) {
    final m = pts[math.max(d - 1, 0)], l = pts[d], y = pts[d + 1], a = pts[math.min(d + 2, pt - 1)];
    p.cubicTo(
      l.dx + (y.dx - m.dx) / 6, l.dy + (y.dy - m.dy) / 6,
      y.dx - (a.dx - l.dx) / 6, y.dy - (a.dy - l.dy) / 6,
      y.dx, y.dy,
    );
  }
  return p;
}

double waveAmt(double ze) =>
    0.42 + 0.29 * math.sin(ze * 0.0021) * math.sin(ze * 0.0034) + 0.29 * math.sin(ze * 0.0013 + 1.7);

// ---------------------------------------------------------------------------
// 绘制记录（替代 DOM 元素）
// ---------------------------------------------------------------------------

/// translate + rotate(deg) + scale + translate(-R,-R) 的组合矩阵。
Matrix4 trsMatrix(double tx, double ty, double rotDeg, double scale, double pivot) =>
    Matrix4.identity()
      ..translate(tx, ty)
      ..multiply(Matrix4.rotationZ(rotDeg * math.pi / 180))
      ..scale(scale)
      ..translate(-pivot, -pivot);

class FxDotDraw {
  final Matrix4 matrix;
  final double opacity;
  const FxDotDraw(this.matrix, this.opacity);
}

class FxCircleDraw {
  final double cx, cy, r, opacity;
  final bool stroke;
  final double strokeWidth;
  final double? dashSweep; // 非空 → 弧线（progress），起点 -90°
  const FxCircleDraw({
    required this.cx,
    required this.cy,
    required this.r,
    required this.opacity,
    this.stroke = false,
    this.strokeWidth = 0,
    this.dashSweep,
  });
}

class FxGlyphDraw {
  final Path path;
  final Matrix4 matrix;
  final double opacity;
  final bool asStroke;
  final double strokeWidth;
  const FxGlyphDraw(this.path, this.matrix, this.opacity, {this.asStroke = false, this.strokeWidth = 0});
}

class FxGradientDraw {
  final Offset a, b;
  final List<Color> stops;
  const FxGradientDraw(this.a, this.b, this.stops);
}

/// 粒子条带：back 在身体后，front 在身前，共享同一渐变。
class FxRibbonDraw {
  final Path? back;
  final Path? front;
  final double opacity;
  final FxGradientDraw? gradient;
  const FxRibbonDraw(this.back, this.front, this.opacity, this.gradient);
}

/// 爆裂粒子。
class FxBurstDraw {
  final Offset center;
  final double r;
  final double capsuleHeight; // 仅 capsule 使用
  final double rotDeg;
  final Color color;
  final double opacity;
  final FxBurstKind kind;
  const FxBurstDraw(this.center, this.r, this.rotDeg, this.color, this.opacity, this.kind, {this.capsuleHeight = 0});
}

enum FxBurstKind { circle, star, capsule }

/// 每帧收集的 overlay/粒子绘制指令（按 DOM 层序分桶）。
class FxFrame {
  final List<FxBurstDraw> backShapes = [];
  final List<FxRibbonDraw> ribbons = [];
  final List<FxDotDraw> dots = [];
  final List<FxCircleDraw> rings = [];
  final List<FxCircleDraw> parts = [];
  final List<FxGlyphDraw> glyphs = [];
  final List<FxBurstDraw> frontShapes = [];
}

// ---------------------------------------------------------------------------
// 粒子系统（Source createParticles）
// ---------------------------------------------------------------------------

class _HistPt {
  final double x, y, l, z;
  const _HistPt(this.x, this.y, this.l, this.z);
}

class _Orbit {
  double lam, lamVel, tilt, roll, rad, radVel, follow, arc;
  double carry = 0;
  _Orbit({
    required this.lam,
    required this.lamVel,
    required this.tilt,
    required this.roll,
    required this.rad,
    required this.radVel,
    required this.follow,
    required this.arc,
  });
}

class _Particle {
  double x, y, vx, vy;
  double ret = 0, life = 0;
  final double max;
  final double r;
  double rot;
  final double vr;
  final Color color;
  final bool round;
  final bool star;
  _Orbit? orbit;
  double? hue;
  double? hueSpan;
  double? hueVel;
  List<_HistPt> hist = [];
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.max,
    required this.r,
    required this.rot,
    required this.vr,
    required this.color,
    this.round = false,
    this.star = false,
    this.orbit,
    this.hue,
    this.hueSpan,
    this.hueVel,
  });
}

class _Plane {
  final double tilt, roll;
  const _Plane(this.tilt, this.roll);
}

class Particles {
  final bool reduce;
  final double Function() getRadius;
  final math.Random rnd;
  double scale() => getRadius() / re0;
  double spin = 0, sizeScale = 1;
  bool wide = false, sustain = false;
  double last = -1;
  List<_Particle> parts = [];
  List<_Plane> planes = [];
  double hue0 = 0;
  int beltN = 4;
  List<({double at, int i})> spawnQ = [];
  double prevSpin = 0, spinVel = 0;
  bool seeding = false, cooling = false;
  int trailId = 0;
  static const double thresh = 0.9, hard = 5;

  Particles({required this.getRadius, required this.rnd, this.reduce = false});

  void burst(int w, [double h = 1, double g = 0]) {
    if (reduce || parts.length > 120) return;
    final r = GrokGeometry.re;
    for (int y = 0; y < w; y++) {
      final u = (y / w) * math.pi * 2 + randOf(rnd, -0.35, 0.35);
      final ee = randOf(rnd, 96, 116) * scale();
      final te = randOf(rnd, 170, 360) * h;
      final ne = -math.sin(u), j = math.cos(u), z = g * te * 0.2;
      final x = rnd.nextDouble() < 0.18;
      parts.add(_Particle(
        x: r + math.cos(u) * ee,
        y: r + math.sin(u) * ee,
        vx: math.cos(u) * te + ne * z,
        vy: math.sin(u) * te + j * z - randOf(rnd, 20, 75),
        max: randOf(rnd, 0.45, 0.85),
        r: x ? randOf(rnd, 4, 7) : randOf(rnd, 3.5, 8),
        rot: randOf(rnd, 0, 360),
        vr: randOf(rnd, -260, 260),
        color: x
            ? Color(starColorValue)
            : Color(particlePalette[rnd.nextInt(particlePalette.length)]),
        round: !x && rnd.nextDouble() < 0.3,
        star: x,
      ));
    }
  }

  void makePlanes([int w = 1]) {
    final h = randOf(rnd, -0.85, 0.85);
    planes = List.generate(
      w,
      (g) => _Plane(randOf(rnd, 0.16, 0.5), h + (g * math.pi) / w + randOf(rnd, -0.12, 0.12)),
    );
    beltN = w > 1 ? w * 3 : randOf(rnd, 3, 5).round();
    hue0 = randOf(rnd, 0, 360);
  }

  void spawnBelt(double lam, int dir, int i) {
    if (parts.length > 110) return;
    if (planes.isEmpty) makePlanes();
    final y = planes[i % planes.length];
    final r = GrokGeometry.re;
    final ringLevel = (i / planes.length).floor();
    final denom = math.max((beltN / planes.length).ceil() - 1, 1);
    parts.add(_Particle(
      x: r,
      y: r,
      vx: 0,
      vy: 0,
      max: 9,
      r: beltN <= 3
          ? randOf(rnd, 8, 10.5)
          : beltN == 4
              ? randOf(rnd, 6.6, 8.6)
              : randOf(rnd, 5.6, 7.4),
      rot: randOf(rnd, 0, 360),
      vr: randOf(rnd, -240, 240),
      color: Color(particlePalette[rnd.nextInt(particlePalette.length)]),
      hue: hue0 + (i * 360) / math.max(beltN, 1) + randOf(rnd, -14, 14),
      hueSpan: randOf(rnd, 45, 95) * (rnd.nextDouble() < 0.5 ? 1 : -1),
      hueVel: randOf(rnd, 18, 42) * (rnd.nextDouble() < 0.5 ? 1 : -1),
      orbit: _Orbit(
        lam: lam,
        lamVel: dir * randOf(rnd, 0.5, 1.1),
        tilt: y.tilt + randOf(rnd, -0.04, 0.04),
        roll: y.roll + randOf(rnd, -0.05, 0.05),
        rad: scale() * 116 + ringLevel * (38 / denom) + randOf(rnd, -1.5, 1.5),
        radVel: randOf(rnd, 0, 2.5),
        follow: randOf(rnd, 0.74, 0.94),
        arc: randOf(rnd, 2.2, 3.4),
      ),
    ));
  }

  Offset project(_Orbit w, double h) {
    final g = w.rad * math.sin(h), y = -w.rad * math.cos(h) * math.sin(w.tilt);
    final u = math.cos(w.roll), e = math.sin(w.roll);
    final r = GrokGeometry.re;
    return Offset(r + g * u - y * e, r + g * e + y * u);
  }

  double depth(_Orbit w, double h) => math.cos(h) * math.cos(w.tilt);

  (Path, Path) ribbon(List<_HistPt> w, double h) {
    final g = w.length;
    var yTotal = 0.0;
    for (int le = 1; le < g; le++) {
      yTotal += math.sqrt(
          (w[le].x - w[le - 1].x) * (w[le].x - w[le - 1].x) + (w[le].y - w[le - 1].y) * (w[le].y - w[le - 1].y));
    }
    final u = math.min(h, yTotal * 0.34);
    final ee = <double>[], te = <double>[];
    for (int le = 0; le < g; le++) {
      final q = w[le > 0 ? le - 1 : 0], ae = w[le < g - 1 ? le + 1 : g - 1];
      var ce = ae.x - q.x, xe = ae.y - q.y;
      final se = math.sqrt(ce * ce + xe * xe);
      final seN = se == 0 ? 1 : se;
      ce /= seN;
      xe /= seN;
      final fe = (u * (0.5 + 0.5 * (le / (g - 1)))) / 2;
      ee.add(-xe * fe);
      te.add(ce * fe);
    }

    Path band(int le, int q) {
      final p = Path();
      for (int ce = le; ce <= q; ce++) {
        final x = w[ce].x + ee[ce], y = w[ce].y + te[ce];
        if (ce == le) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      if (q == g - 1) {
        final r = math.max(math.sqrt(ee[q] * ee[q] + te[q] * te[q]), 0.2);
        p.arcTo(Rect.fromCircle(center: Offset(w[q].x, w[q].y), radius: r), 0, math.pi, false);
      }
      for (int ce = q; ce >= le; ce--) {
        p.lineTo(w[ce].x - ee[ce], w[ce].y - te[ce]);
      }
      if (le == 0) {
        final r = math.max(math.sqrt(ee[0] * ee[0] + te[0] * te[0]), 0.2);
        p.arcTo(Rect.fromCircle(center: Offset(w[0].x, w[0].y), radius: r), math.pi, math.pi, false);
      }
      return p..close();
    }

    final front = Path(), back = Path();
    if (yTotal < 2) return (front, back);
    int se2 = 0;
    while (se2 < g) {
      final frontSide = w[se2].z >= 0;
      var q = se2;
      while (q + 1 < g && (w[q + 1].z >= 0) == frontSide) {
        q++;
      }
      final ae = math.max(se2 - 1, 0), ce = math.min(q + 1, g - 1);
      if (ce > ae) {
        final bandPath = band(ae, ce);
        if (frontSide) {
          front.addPath(bandPath, Offset.zero);
        } else {
          back.addPath(bandPath, Offset.zero);
        }
      }
      se2 = q + 1;
    }
    return (front, back);
  }

  void tickVel(double dt) {
    var h = spin - prevSpin;
    if (!h.isFinite || h.abs() > 1.2) h = 0;
    prevSpin = spin;
    final was = spinVel.abs() >= thresh;
    spinVel = dt > 0 ? h / dt : 0;
    final nowFast = spinVel.abs() >= thresh;
    if (!was && nowFast) {
      makePlanes(wide ? 3 : 1);
      seeding = false;
      cooling = false;
    }
    if (was && !nowFast) {
      spawnQ.clear();
      cooling = false;
    }
  }

  void seedBelts(double now) {
    if (reduce) return;
    final h = spinVel.abs();
    final live = parts.any((u) => u.orbit != null && u.ret < 1);
    if (sustain && seeding && spawnQ.isEmpty && h >= thresh && !live) {
      seeding = false;
      cooling = true;
    }
    if (!seeding && (h >= hard || (sustain && cooling && h >= thresh))) {
      seeding = true;
      cooling = false;
      spawnQ = [];
      for (int u = 0; u < beltN; u++) {
        spawnQ.add((at: now + u * randOf(rnd, 55, 105), i: u));
      }
    }
    while (spawnQ.isNotEmpty && now >= spawnQ.first.at) {
      final u = spawnQ.removeAt(0);
      spawnBelt(spin - randOf(rnd, 0, 0.18), spinVel >= 0 ? 1 : -1, u.i);
    }
  }

  void step(double dt, double realDt, FxFrame frame) {
    if (parts.isEmpty) return;
    final spinning = spinVel.abs() >= thresh;
    final keep = <_Particle>[];
    for (final j in parts) {
      j.life += j.life > 0 ? realDt : dt;
      final z = clampN(j.life / j.max, 0, 1);
      if (j.orbit != null) {
        final ce = !spinning || z > 0.55;
        j.ret = clampN(j.ret + (ce ? realDt / 0.5 : -realDt / 0.35), 0, 1);
        if (j.ret >= 1) continue;
      } else if (j.life >= j.max) {
        continue;
      }
      final x = j.orbit != null
          ? math.min(1.0, j.life / 0.26)
          : z < 0.1
              ? z / 0.1
              : math.pow(1 - (z - 0.1) / 0.9, 1.7).toDouble();
      if (j.orbit != null) {
        final ce = j.orbit!;
        if (spinning) {
          ce.carry = spinVel * ce.follow;
          ce.lam += spinVel * dt * ce.follow + ce.lamVel * dt;
          ce.rad += ce.radVel * dt;
        } else {
          ce.lam += (ce.carry + ce.lamVel) * dt;
          ce.carry *= math.exp(-2.6 * dt);
          ce.lamVel *= math.exp(-2.6 * dt);
          ce.rad += ce.radVel * dt;
        }
        final xe = project(ce, ce.lam);
        j.x = xe.dx;
        j.y = xe.dy;
        final se = depth(ce, ce.lam);
        final fe = 0.72 + 0.28 * clampN(se, 0, 1);
        final ke = math.min(j.life / 0.34, 1.0);
        final be = ke * ke * (3 - 2 * ke);
        final ne = math.max(j.r * fe * 1.7 * sizeScale * be * (1 - 0.72 * j.ret * j.ret), 0.5);
        final ae = j.hist;
        final oe = ae.isNotEmpty ? ae.last.l : ce.lam;
        final ve = ce.lam - oe;
        final ge = math.min((ve.abs() / 0.09).ceil(), 24);
        for (int de = 1; de <= ge; de++) {
          final te2 = oe + (ve * de) / ge, je = project(ce, te2);
          ae.add(_HistPt(je.dx, je.dy, te2, depth(ce, te2)));
        }
        if (ae.isEmpty) ae.add(_HistPt(j.x, j.y, ce.lam, se));
        final ye = ce.arc * (1 - j.ret * j.ret * (3 - 2 * j.ret));
        while (ae.length > 2 && (ce.lam - ae[0].l).abs() > ye) {
          ae.removeAt(0);
        }
        final ue = (ce.lam - ae[0].l).abs() - ye;
        if (ae.length >= 2 && ue > 0) {
          final de = ae[0].l + ((ce.lam - ae[0].l) >= 0 ? 1 : -1) * ue;
          final te2 = project(ce, de);
          ae[0] = _HistPt(te2.dx, te2.dy, de, depth(ce, de));
        }
        if (ae.length > 48) ae.removeRange(0, ae.length - 48);
        if (ae.length >= 2) {
          final (front, back) = ribbon(ae, ne);
          final stops = <Color>[];
          final qe = (j.hue ?? 0) + (j.hueVel ?? 0) * j.life;
          for (int we = 0; we < 5; we++) {
            final pe = we / (5 - 1), je = qe + pe * (j.hueSpan ?? 120);
            final hue = ((je % 360) + 360) % 360;
            stops.add(HSLColor.fromAHSL(1, hue, 0.56, (0.56 + 0.11 * pe).clamp(0, 1)).toColor());
          }
          frame.ribbons.add(FxRibbonDraw(
            back,
            front,
            x,
            FxGradientDraw(Offset(ae[0].x, ae[0].y), Offset(ae.last.x, ae.last.y), stops),
          ));
        }
        keep.add(j);
        continue;
      }
      j.x += j.vx * dt;
      j.y += j.vy * dt;
      final se = math.pow(0.94, dt * 60).toDouble();
      j.vx *= se;
      j.vy = j.vy * se + 40 * dt;
      final le = j.life / j.max;
      final q = le < 0.1 ? le / 0.1 : math.pow(1 - (le - 0.1) / 0.9, 1.7).toDouble();
      final ae = math.max(j.r * (1 - le * 0.4), 0.5);
      final kind = j.star
          ? FxBurstKind.star
          : j.round
              ? FxBurstKind.circle
              : FxBurstKind.capsule;
      j.rot += j.vr * dt;
      var rotDeg = j.rot;
      if (kind == FxBurstKind.capsule) {
        rotDeg = math.atan2(j.vy, j.vx) * 180 / math.pi;
      }
      frame.backShapes.add(FxBurstDraw(
        Offset(j.x, j.y),
        kind == FxBurstKind.capsule ? math.max(ae * 2, math.min(math.sqrt(j.vx * j.vx + j.vy * j.vy) * 0.05, 30)) : ae,
        rotDeg,
        j.color,
        q,
        kind,
        capsuleHeight: ae * 1.5,
      ));
      keep.add(j);
    }
    parts = keep;
  }

  void clear() {
    parts = [];
    spawnQ = [];
    seeding = false;
    cooling = false;
  }

  void update(double now, double dt, double spinAngle, double szScale, bool wideStyle, bool sustainBelts, FxFrame frame) {
    final y = last < 0 ? dt : math.max((now - last) / 1000, 0);
    last = now;
    sizeScale = szScale;
    spin = spinAngle;
    wide = wideStyle;
    sustain = sustainBelts;
    tickVel(dt);
    seedBelts(now);
    step(dt, y, frame);
  }

  bool get hasLife => parts.isNotEmpty || spawnQ.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Overlay 层（Source OverlayLayer）
// ---------------------------------------------------------------------------

class DotsPulse {
  final double lift, pop, tone;
  const DotsPulse(this.lift, this.pop, this.tone);
}

class FxExtras {
  final double lee;
  final DotsPulse rx;
  final double yre, ax, wl, wre, fade, zoom, a2;
  const FxExtras(this.lee, this.rx, this.yre, this.ax, this.wl, this.wre, this.fade, this.zoom, this.a2);
}

class OverlayLayer {
  double overlayAt = 0;
  late final Path circlePath;
  late final Path pencilPath;
  late final Path bangPath;
  final List<Offset> ink = [];
  double recvDir = -0.7;
  int recvTick = -1;
  bool _reduce = false;

  OverlayLayer() {
    final r = GrokGeometry.re;
    circlePath = closedSpline(circleRing(r));
    pencilPath = capsulePath(30, 88, r);
    bangPath = taperPath(30, 17, 96, r);
  }

  double amount(String? name, String? cur, String? prev, double yl, double mix) {
    if (name == cur) return yl * mix;
    if (name == prev) return yl * (1 - mix);
    return 0;
  }

  void setReduce(bool v) => _reduce = v;

  DotsPulse dotsPulse(double now, int slot, double yl, [bool reduce = false]) {
    final dt = ((((now - overlayAt) / 1400 + 0.119) % 1) + 1) % 1;
    var mt = (dt - slot / 3).abs();
    mt = math.min(mt, 1 - mt);
    final lt = reduce ? 1.0 : math.exp(-(mt * mt) / (2 * 0.15 * 0.15));
    final yn = reduce ? 0.0 : 1.0;
    return DotsPulse(lt * 9 * yl * yn, 1 + yn * (pop0 + pop1 * lt - 1), 1 - yn * 0.5 * (1 - lt));
  }

  void paint(FxFrame frame, double now, double stateAt, String? cur, String? prev, double yl, double mix, double r, {bool reduce = false}) {
    _reduce = reduce;
    final extra = extras(now, stateAt, cur, prev, yl, mix);
    double kl(String? name) => amount(name, cur, prev, yl, mix);
    void run(String name, void Function(double a) fn) {
      final a = kl(name);
      if (a > 0.004) fn(a);
    }

    run('dots', (a) => paintDots(frame, a, now, r));
    run('orbit', (a) => paintOrbit(frame, a, now, r));
    run('radar', (a) => paintRadar(frame, a, now, r, extra.a2));
    run('progress', (a) => paintProgress(frame, a, now, r));
    run('gather', (a) => paintGather(frame, a, now, r));
    run('wave', (a) => paintWave(frame, a, now, r));
    run('send', (a) => paintSend(frame, a, now, stateAt, r));
    run('receive', (a) => paintRecv(frame, a, now, stateAt, r));
    run('dock', (a) => paintDock(frame, a, now, stateAt, r));
    run('pencil', (a) => paintPencil(frame, a, now, stateAt, r));
    run('bang', (a) => paintBang(frame, a, now, stateAt, r));
    run('standby', (a) => paintStandby(frame, a, now, r));
  }

  void paintDots(FxFrame frame, double ze, double now, double r) {
    final xs = [r - dotGap, r + dotGap];
    for (int d = 0; d < 2; d++) {
      final lt = clampN((ze - d * 0.12) / (1 - d * 0.12), 0, 1);
      if (lt <= 0.004) continue;
      final yn = rc3(lt), an = y1e(lt);
      final et = dotsPulse(now, d == 0 ? 0 : 2, ze, _reduce);
      final en = (dotR * yn * et.pop) / r * 1.02;
      final m = Matrix4.identity()
        ..translate(r + (xs[d] - r) * an, r - et.lift)
        ..scale(en)
        ..translate(-r, -r);
      frame.dots.add(FxDotDraw(m, yn * et.tone));
    }
  }

  void paintOrbit(FxFrame frame, double ze, double now, double r) {
    final mt = rc3(ze), mtS = 52 * y1e(ze), lt = 12.0, yn = now * 0.0017;
    for (int an = 0; an < 5; an++) {
      final en = yn + (an * math.pi * 2) / 5, zt = math.cos(en);
      final dn = 0.5 + 0.5 * clampN(zt, 0, 1);
      frame.parts.add(FxCircleDraw(
        cx: r + mtS * math.sin(en),
        cy: r - mtS * 0.42 * math.cos(en),
        r: math.max(lt * dn * mt, 0.3),
        opacity: clampN((zt + 0.4) / 0.6, 0.18, 1) * mt,
      ));
    }
  }

  void paintRadar(FxFrame frame, double ze, double now, double r, double bodyR) {
    final dt = rc3(ze);
    for (int yn = 0; yn < 3; yn++) {
      final et = (now / 1300 + yn / 3) % 1;
      frame.rings.add(FxCircleDraw(
        cx: r,
        cy: r,
        r: bodyR + (104 - bodyR) * et,
        opacity: dt * (1 - et) * 0.9,
        stroke: true,
        strokeWidth: 3.4 * (1 - et * 0.55),
      ));
    }
  }

  void paintProgress(FxFrame frame, double ze, double now, double r) {
    final mt = rc3(ze), dt = y1e(ze);
    const mtR = 62.0;
    final lt = clampN((now - overlayAt) / cycleOnMs['progress']!, 0, 1);
    final yn = clampN(lt / 0.85, 0, 1);
    frame.rings.add(FxCircleDraw(
      cx: r,
      cy: r,
      r: mtR * dt,
      opacity: mt * 0.16,
      stroke: true,
      strokeWidth: 5,
    ));
    final en = mtR * dt, zt = 2 * math.pi * en;
    frame.rings.add(FxCircleDraw(
      cx: r,
      cy: r,
      r: en,
      opacity: mt,
      stroke: true,
      strokeWidth: 5,
      dashSweep: math.pi * 2 * yn,
    ));
  }

  void paintGather(FxFrame frame, double ze, double now, double r) {
    final mt = rc3(ze);
    const dt = 2000.0;
    for (int m = 0; m < 5; m++) {
      final yn = clampN(((now - overlayAt) / dt - m * 0.09) / 0.62, 0, 1);
      if (yn >= 1) continue;
      final an = 1 - math.pow(1 - yn, 3).toDouble(), et = m * 2.4 + yn * 2.2, en = 96 * (1 - an);
      frame.parts.add(FxCircleDraw(
        cx: r + en * math.cos(et),
        cy: r + en * math.sin(et) * 0.8,
        r: 9 * (0.5 + 0.5 * an) * mt,
        opacity: mt * clampN(yn * 5, 0, 1) * (1 - an * 0.25),
      ));
    }
  }

  void paintWave(FxFrame frame, double ze, double now, double r) {
    const xs = [-2.0, -1.0, 1.0, 2.0];
    const dt = 44.0;
    for (int m = 0; m < 4; m++) {
      final yn = xs[m];
      final an = clampN((ze - yn.abs() * 0.1) / (1 - yn.abs() * 0.1), 0, 1);
      if (an <= 0.004) continue;
      final et = y1e(an), en = waveAmt(now) * (0.55 + 0.45 * math.sin(now * 0.012 - yn.abs() * 1.05));
      final zt = (7 + 9 * clampN(en, 0.08, 1)) * rc3(an), dn = 6 * clampN(en, 0, 1) * an;
      if (m < 2) {
        final on = (zt / r) * 1.02;
        final mat = Matrix4.identity()
          ..translate(r + yn * dt * et, r - dn)
          ..scale(on)
          ..translate(-r, -r);
        frame.dots.add(FxDotDraw(mat, an));
      } else {
        frame.parts.add(FxCircleDraw(cx: r + yn * dt * et, cy: r - dn, r: zt, opacity: an));
      }
    }
  }

  void paintSend(FxFrame frame, double ze, double now, double stateAt, double r) {
    final mt = rc3(ze);
    final dt = ((((now - stateAt) / sendMs) % 1) + 1) % 1;
    final mtN = clampN((dt - 0.18) / 0.55, 0, 1), lt = mtN * mtN * (0.4 + 0.6 * mtN);
    const yn = 0.74, an = -0.62;
    final et = 108 * lt;
    final on = mtN > 0 && mtN < 1;
    if (on) {
      frame.parts.add(FxCircleDraw(
        cx: r + yn * et,
        cy: r + an * et,
        r: 10 * (1 - lt * 0.55) * mt,
        opacity: mt * (1 - lt * lt),
      ));
    }
    final on2 = clampN((dt - 0.26) / 0.55, 0, 1), bn = on2 * on2 * (0.4 + 0.6 * on2);
    final cn = mtN > 0 && on2 > 0 && on2 < 1;
    if (cn) {
      final bi = 108 * bn;
      frame.parts.add(FxCircleDraw(
        cx: r + yn * bi,
        cy: r + an * bi,
        r: 5 * (1 - bn * 0.6) * mt,
        opacity: mt * 0.3 * (1 - bn),
      ));
    }
    final on3 = clampN((dt - 0.18) / 0.3, 0, 1);
    final bn3 = on3 > 0 && on3 < 1;
    if (bn3) {
      frame.rings.add(FxCircleDraw(
        cx: r,
        cy: r,
        r: 20 + 34 * rc3(on3),
        opacity: mt * (1 - on3) * 0.8,
        stroke: true,
        strokeWidth: 2.8 * (1 - on3),
      ));
    }
  }

  void paintRecv(FxFrame frame, double ze, double now, double stateAt, double r, [math.Random? rnd]) {
    final mt = rc3(ze), dt = now - stateAt;
    final mtI = (dt / recvMs).floor();
    if (mtI != recvTick) {
      recvTick = mtI;
      recvDir = randOf(rnd ?? math.Random(), -math.pi * 1.25, math.pi * 0.25);
    }
    final lt = (((dt / recvMs) % 1) + 1) % 1, yn = clampN(lt / 0.6, 0, 1), an = 1 - math.pow(1 - yn, 3).toDouble();
    final et = math.cos(recvDir), en = math.sin(recvDir), zt = 108 * (1 - an);
    final bn = yn < 1;
    if (bn) {
      final cn = 18 * math.sin(yn * math.pi) * (1 - an * 0.7);
      frame.parts.add(FxCircleDraw(
        cx: r + et * zt + -en * cn,
        cy: r + en * zt + et * cn,
        r: 3.5 + 6.5 * an,
        opacity: mt * clampN(yn * 3.5, 0, 1) * (0.3 + 0.7 * an),
      ));
    }
    final bn2 = clampN((lt - 0.58) / 0.32, 0, 1);
    final cn = bn2 > 0 && bn2 < 1;
    if (cn) {
      frame.rings.add(FxCircleDraw(
        cx: r,
        cy: r,
        r: 20 + 26 * rc3(bn2),
        opacity: mt * (1 - bn2) * 0.8,
        stroke: true,
        strokeWidth: 2.8 * (1 - bn2),
      ));
    }
  }

  void paintDock(FxFrame frame, double ze, double now, double stateAt, double r) {
    final mt = rc3(ze), dt = (now - stateAt) / 1000;
    const mtS = 42.0, lt = 1.1;
    for (int yn = 0; yn < 2; yn++) {
      final et = clampN((dt - (0.2 + yn * 1.3)) / 0.9, 0, 1);
      if (et <= 0) continue;
      final en = 1 - math.pow(1 - et, 3).toDouble();
      final zt = now * 0.001 * lt + yn * math.pi;
      final dn = r + mtS * math.sin(zt), on = r + mtS * 0.5 * math.cos(zt) + math.sin(now * 0.003 + yn) * 2;
      final bn = r - 120 + yn * 30, cn = r + 95;
      frame.parts.add(FxCircleDraw(
        cx: bn + (dn - bn) * en,
        cy: cn + (on - cn) * en,
        r: (7 + 3 * en) * mt,
        opacity: mt * clampN(et * 4, 0, 1),
      ));
    }
  }

  void paintPencil(FxFrame frame, double ze, double now, double stateAt, double r) {
    final mt = pencilPose(now, stateAt);
    final lt = (mt.rot - 90) * math.pi / 180;
    const yn = 68.0;
    final an = math.cos(lt) * yn, et = math.sin(lt) * yn;
    final m = Matrix4.identity()
      ..translate(r + (mt.x + an) * ze, r + (mt.y + mt.wig * 0.15 + et) * ze)
      ..multiply(Matrix4.rotationZ(mt.rot * ze * math.pi / 180))
      ..scale(rc3(ze))
      ..translate(-r, -r);
    frame.glyphs.add(FxGlyphDraw(pencilPath, m, clampN(ze * 1.6 - 0.3, 0, 1)));
    if (ze > 0.6 && !mt.lift) {
      final x = r + mt.x, y = r + mt.y + mt.wig + 19;
      if (ink.isEmpty || math.sqrt((x - ink.last.dx) * (x - ink.last.dx) + (y - ink.last.dy) * (y - ink.last.dy)) > 2.4) {
        ink.add(Offset(x, y));
        if (ink.length > 64) ink.removeAt(0);
      } else {
        ink[ink.length - 1] = Offset(x, y);
      }
    } else if (ink.isNotEmpty) {
      ink.removeRange(0, math.min(2, ink.length));
    }
    if (ink.length >= 2) {
      frame.glyphs.add(FxGlyphDraw(
        smoothLine(ink),
        Matrix4.identity(),
        clampN(ze * 1.2, 0, 1),
        asStroke: true,
        strokeWidth: 6,
      ));
    }
  }

  void paintBang(FxFrame frame, double ze, double now, double stateAt, double r) {
    final dt = (now - stateAt) / 1000;
    final mt = rc3(clampN(ze * 1.1, 0, 1));
    final lt = math.exp(-((dt % 2.2) * 5.5)), yn = math.sin(dt * 42) * 2.2 * lt;
    final m = Matrix4.identity()
      ..translate(0, -26 - (1 - mt) * 70)
      ..translate(r, r - 74)
      ..multiply(Matrix4.rotationZ(yn * math.pi / 180))
      ..translate(-r, -(r - 74))
      ..translate(r, r)
      ..scale(clampN(ze * 1.2, 0, 1))
      ..translate(-r, -r);
    frame.glyphs.add(FxGlyphDraw(bangPath, m, clampN(ze * 1.5 - 0.2, 0, 1)));
  }

  void paintStandby(FxFrame frame, double ze, double now, double r) {
    final mt = rc3(ze);
    final lt = 0.5 + 0.5 * math.sin(now * 0.0016);
    frame.parts.add(FxCircleDraw(cx: r, cy: r, r: 26 + 7 * lt, opacity: mt * (0.06 + 0.1 * lt)));
    final show = ze < 0.995;
    if (show) {
      frame.rings.add(FxCircleDraw(
        cx: r,
        cy: r,
        r: 104 - 88 * mt,
        opacity: (1 - mt) * 0.5,
        stroke: true,
        strokeWidth: 2.4,
      ));
    }
  }

  FxExtras extras(double now, double stateAt, String? cur, String? prev, double yl, double mix) {
    double kl(String? name) => amount(name, cur, prev, yl, mix);
    final lee = kl('dots');
    final rx = dotsPulse(now, 1, yl, _reduce);
    var iX = 1.0;
    if (cur == 'dots' || prev == 'dots') {
      iX = 1 + (rx.pop - 1) * (lee / math.max(yl, 0.001));
    }
    final fme = kl('receive');
    if (fme > 0.004) {
      final t2 = ((((now - stateAt) / recvMs) % 1) + 1) % 1;
      final gn = clampN((t2 - 0.58) / 0.34, 0, 1);
      iX *= 1 + 0.11 * math.sin(gn * math.pi) * fme;
    }
    final zme = kl('send');
    if (zme > 0.004) {
      final t2 = ((((now - stateAt) / sendMs) % 1) + 1) % 1;
      final gn = t2 < 0.18 ? -0.06 * math.sin((t2 / 0.18) * math.pi) : 0.0;
      final gn2 = t2 >= 0.18 && t2 < 0.42 ? 0.05 * math.sin(((t2 - 0.18) / 0.24) * math.pi) : 0.0;
      iX *= 1 + (gn + gn2) * zme;
    }
    final qee = kl('bang');
    if (qee > 0.004) {
      iX *= 1 + 0.04 * math.exp(-(((now - stateAt) / 1000) % 2.2) * 5.5) * qee;
    }
    var yre = 0.0, ax = 0.0, wl = 0.0;
    final c1 = kl('pencil');
    if (c1 > 0.004) {
      final t2 = pencilPose(now, stateAt);
      yre += t2.x * c1;
      ax += (t2.y + t2.wig * 0.5) * c1;
      wl += t2.rot * c1;
    }
    if (qee > 0.004) ax += 58 * qee;
    final jee = kl('whirl');
    if (jee > 0.004) {
      final t2 = now / 1000;
      yre += (math.sin(t2 * 0.9) * 2 + math.sin(t2 * 1.7) * 0.8) * jee;
      ax += (math.sin(t2 * 1.3) * 2.4 + math.sin(t2 * 0.6) * 1.2) * jee;
    }
    final kre = kl('ball');
    if (kre > 0.004) {
      final t2 = (now - stateAt) / 1000;
      const gn = 0.62, gn2 = 52.0;
      final ti = (8 * gn2) / (gn * gn);
      const ui = 40.0;
      final si = math.sqrt((2 * ui) / ti);
      double ea;
      if (t2 < si) {
        ea = ui - 0.5 * ti * t2 * t2;
      } else {
        final ca = (((t2 - si) / gn) % 1 + 1) % 1;
        ea = 4 * gn2 * ca * (1 - ca);
      }
      ax += (40 - ea) * kre;
    }
    double mixRTbl(String? cur, String? prev) {
      if (cur == null) return 19;
      return (overlayRadius[cur] ?? 19) * mix + (prev != null ? (overlayRadius[prev] ?? overlayRadius[cur] ?? 19) : (overlayRadius[cur] ?? 19)) * (1 - mix);
    }

    final a2 = mixRTbl(cur, prev);
    final wre = (a2 / (GrokGeometry.re)) * iX;
    final standby = kl('standby');
    final fade = standby > 0 ? (0.28 + 0.2 * math.sin(now * 0.0016)) * standby : 0.0;
    final zoomCur = cur != null ? math.max(overlayScale[cur] ?? 1, 1) : 1.0;
    final zoomPrev = prev != null ? math.max(overlayScale[prev] ?? 1, 1) : zoomCur;
    final zoom = 1 + (zoomCur * mix + zoomPrev * (1 - mix) - 1) * yl;
    return FxExtras(lee, rx, yre, ax, wl, wre, fade, zoom, a2);
  }

  void resetInk() => ink.clear();
}

// ---------------------------------------------------------------------------
// 形状工具（Source turnAtOf / beltRadius / shapeMetrics / overlayRing）
// ---------------------------------------------------------------------------

final Map<String, List<Offset> Function(double yaw)> _turnAtCache = {};
List<Offset> Function(double yaw)? turnAtOf(String name, String path, double r) {
  if (_turnAtCache.containsKey(name)) return _turnAtCache[name];
  final solid = GrokGeometry.solids[name];
  List<Offset> Function(double yaw)? fn;
  if (solid != null) {
    fn = makeTurnAt(solid, shapeRing(path, r), r);
  }
  _turnAtCache[name] = fn;
  return fn;
}

final Map<String, double> _beltCache = {};
double beltRadius(String path, double r) {
  final cached = _beltCache[path];
  if (cached != null) return cached;
  final ring = shapeRing(path, r);
  var top = double.infinity, bot = double.negativeInfinity;
  for (final p in ring) {
    if (p.dy < top) top = p.dy;
    if (p.dy > bot) bot = p.dy;
  }
  var m = 0.0;
  for (double y = top; y <= bot; y += 2) {
    final (l, right) = spanHalf(ring, y, r);
    final half = (right - l) / 2;
    if (half > m) m = half;
  }
  _beltCache[path] = m;
  return m;
}

class ShapeMetrics {
  final GrokFace face;
  final List<Offset> ring;
  final double tilt;
  final double belt;
  const ShapeMetrics(this.face, this.ring, this.tilt, this.belt);
}

ShapeMetrics shapeMetrics(GrokShapeData shape, double r) => ShapeMetrics(
      shape.face,
      shapeRing(shape.path, r),
      shape.tiltScale,
      shape.beltRadius ?? beltRadius(shape.path, r),
    );

List<Offset> overlayRing(String? kind, double r, String? teardropPath) {
  if (kind == 'pencil' && teardropPath != null) {
    final ring = polarRing(flattenPath(teardropPath), r);
    return rotateRing(ring, ring.length ~/ 2, r);
  }
  return circleRing(r);
}
