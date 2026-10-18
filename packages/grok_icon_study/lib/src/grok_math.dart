// Ported from grok-icon-study replica/src/math.js — springs, easing, path flatten, span, 3D.
// Source symbols: xl / $Be / l_t / gm.
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'grok_geometry.dart';

/// 弹簧：x 当前值，v 速度，t 目标值。
class Spring {
  double x;
  double v;
  double t;
  Spring(this.x)
      : v = 0,
        t = x;
}

void stepSpring(Spring s, double freq, double damp, double dt) {
  s.v += (-2 * damp * freq * s.v - freq * freq * (s.x - s.t)) * dt;
  s.x += s.v * dt;
  if (!s.x.isFinite || !s.v.isFinite) {
    s.x = s.t;
    s.v = 0;
  }
}

const double springDt = 1 / 120;
int springSteps(double dt) => math.max(1, (dt / springDt).ceil());

double clampN(double n, double a, double b) => n < a ? a : (n > b ? b : n);
double lerpN(double a, double b, double t) => a + (b - a) * t;
double randOf(math.Random rnd, double a, double b) => a + rnd.nextDouble() * (b - a);
int signOf(math.Random rnd) => rnd.nextDouble() < 0.5 ? -1 : 1;

double k2(double n) => n < 0.5 ? 4 * n * n * n : 1 - math.pow(-2 * n + 2, 3) / 2.0;
double rc3(double n) => 1 - math.pow(1 - n, 3).toDouble();
double y1e(double n) =>
    1 + 2.70158 * math.pow(n - 1, 3) + 1.70158 * math.pow(n - 1, 2);
double dke(double n) => n * n * (3 - 2 * n);
double xExp(double n, double e) => 1 - math.exp(math.log(1 - n) * 60 * e);
/// 帧率无关平滑因子（Source Rn）。
double rnSmooth(double n, [double bs = 1 / 60]) => xExp(n, bs);

Offset centroid(List<Offset> pts) {
  double x = 0, y = 0;
  for (final p in pts) {
    x += p.dx;
    y += p.dy;
  }
  return Offset(x / pts.length, y / pts.length);
}

List<Offset> lerpPoly(List<Offset> a, List<Offset> b, double t) =>
    List.generate(a.length, (i) => Offset(a[i].dx + (b[i].dx - a[i].dx) * t, a[i].dy + (b[i].dy - a[i].dy) * t));

GrokFacePort lerpFace(GrokFacePort n, GrokFacePort e, double t) => GrokFacePort(
      x: n.x + (e.x - n.x) * t,
      y: n.y + (e.y - n.y) * t,
      sx: n.sx + (e.sx - n.sx) * t,
      sy: n.sy + (e.sy - n.sy) * t,
      eye: n.eye + (e.eye - n.eye) * t,
      leftDX: n.leftDX + (e.leftDX - n.leftDX) * t,
    );

/// 引擎内部使用的脸部参数（geometry 中的 GrokFace 的可变副本）。
class GrokFacePort {
  double x, y, sx, sy, eye, leftDX;
  GrokFacePort({
    this.x = 0,
    this.y = 0,
    this.sx = 1,
    this.sy = 1,
    this.eye = 1,
    this.leftDX = 0,
  });
  factory GrokFacePort.from(GrokFace f) =>
      GrokFacePort(x: f.x, y: f.y, sx: f.sx, sy: f.sy, eye: f.eye, leftDX: f.leftDX);
}

/// 解析绝对坐标 SVG path（M/L/C/Q/Z）为折线点集。数据源仅含绝对命令。
List<Offset> flattenPath(String d, [double e = 4]) {
  final tokens = RegExp(
          r'[MLCQZmlcqz]|-?\d*\.?\d+(?:e[-+]?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  final pts = <Offset>[];
  int r = 0;
  String cmd = '';
  double ox = 0, oy = 0, sx0 = 0, sy0 = 0;
  double rd() => double.parse(tokens[r++]);
  void sample(Offset Function(double t) f, double roughLen) {
    final y = math.max(2, (roughLen / e).ceil());
    for (int k = 1; k <= y; k++) {
      final p = f(k / y);
      pts.add(p);
    }
  }

  while (r < tokens.length) {
    if (RegExp('[a-zA-Z]').hasMatch(tokens[r])) cmd = tokens[r++].toUpperCase();
    if (cmd == 'Z') {
      final gap = math.hypot(ox - sx0, oy - sy0);
      if (gap > 0.01) {
        sample((f) => Offset(sx0 + (ox - sx0) * f, sy0 + (oy - sy0) * f), gap);
      }
      ox = sx0;
      oy = sy0;
      continue;
    }
    if (r >= tokens.length) break;
    if (cmd == 'M') {
      ox = rd();
      oy = rd();
      sx0 = ox;
      sy0 = oy;
      pts.add(Offset(ox, oy));
      cmd = 'L';
    } else if (cmd == 'L') {
      final fx = rd(), fy = rd();
      sample((y) => Offset(ox + (fx - ox) * y, oy + (fy - oy) * y), math.hypot(fx - ox, fy - oy));
      ox = fx;
      oy = fy;
    } else if (cmd == 'Q') {
      final fx = rd(), fy = rd(), tx = rd(), ty = rd();
      final vx = ox, vy = oy;
      sample(
        (x) {
          final n = 1 - x;
          return Offset(n * n * vx + 2 * n * x * fx + x * x * tx,
              n * n * vy + 2 * n * x * fy + x * x * ty);
        },
        math.hypot(fx - ox, fy - oy) + math.hypot(tx - fx, ty - fy),
      );
      ox = tx;
      oy = ty;
    } else if (cmd == 'C') {
      final f1x = rd(), f1y = rd(), f2x = rd(), f2y = rd(), vx = rd(), vy = rd();
      final bx = ox, by = oy;
      sample(
        (e2) {
          final a = 1 - e2;
          return Offset(
            a * a * a * bx + 3 * a * a * e2 * f1x + 3 * a * e2 * e2 * f2x + e2 * e2 * e2 * vx,
            a * a * a * by + 3 * a * a * e2 * f1y + 3 * a * e2 * e2 * f2y + e2 * e2 * e2 * vy,
          );
        },
        math.hypot(f1x - ox, f1y - oy) +
            math.hypot(f2x - f1x, f2y - f1y) +
            math.hypot(vx - f2x, vy - f2y),
      );
      ox = vx;
      oy = vy;
    } else {
      r++;
    }
  }
  return pts;
}

/// 水平跨度查询：给定 y，返回 (left, right)。
typedef SpanFn = (double, double) Function(double y);

SpanFn buildSpan(List<Offset> pts, double re, [int e = 160]) {
  double top = double.infinity, bottom = double.negativeInfinity;
  for (final p in pts) {
    if (p.dy < top) top = p.dy;
    if (p.dy > bottom) bottom = p.dy;
  }
  final range = bottom - top;
  final left = List<double>.filled(e, 0);
  final right = List<double>.filled(e, 0);
  for (int m = 0; m < e; m++) {
    final y = top + range * (m + 0.5) / e;
    double h = double.negativeInfinity, l = double.infinity;
    for (int b = 0; b < pts.length; b++) {
      final x0 = pts[b], x1 = pts[(b + 1) % pts.length];
      if ((x0.dy <= y) == (x1.dy <= y)) continue;
      final ex = x0.dx + (x1.dx - x0.dx) * (y - x0.dy) / (x1.dy - x0.dy);
      if (ex <= re) {
        if (ex > h) h = ex;
      } else if (ex < l) {
        l = ex;
      }
    }
    left[m] = h.isFinite ? h : re;
    right[m] = l.isFinite ? l : re;
  }
  return (y) {
    final fy = clampN((y - top) / range * e - 0.5, 0, e - 1);
    final k = fy.floor();
    final v = fy - k;
    final b = math.min(k + 1, e - 1);
    return (left[k] + (left[b] - left[k]) * v, right[k] + (right[b] - right[k]) * v);
  };
}

final Map<String, SpanFn> _spanCache = {};
SpanFn spanAt(String path, double re) =>
    _spanCache.putIfAbsent(path, () => buildSpan(flattenPath(path), re));

/// Source z_t — 形变过程中折线在 y 处的实时跨度。
(double, double) spanPoly(List<Offset> poly, double y, double re) {
  double t = double.negativeInfinity, s = double.infinity;
  for (int r = 0; r < poly.length; r++) {
    final i = poly[r], o = poly[(r + 1) % poly.length];
    if ((i.dy <= y) == (o.dy <= y)) continue;
    final l = i.dx + (o.dx - i.dx) * (y - i.dy) / (o.dy - i.dy);
    if (l <= re) {
      if (l > t) t = l;
    } else if (l < s) {
      s = l;
    }
  }
  return (t.isFinite ? t : re, s.isFinite ? s : re);
}

/// 欧拉角（度）→ 3x3 旋转矩阵（行主序，9 元素）。
List<double> rot3(double turn, double tilt, double roll) {
  final d = math.pi / 180;
  final ui = math.cos(turn * d), si = math.sin(turn * d);
  final ea = math.cos(tilt * d), ca = math.sin(tilt * d);
  final wo = math.cos(roll * d), sc = math.sin(roll * d);
  return [
    wo * ui - sc * ca * si, -sc * ea, wo * si + sc * ca * ui,
    sc * ui + wo * ca * si, wo * ea, sc * si - wo * ca * ui,
    -ea * si, ca, ea * ui,
  ];
}

/// 相对旋转矩阵（gn × Gn^T）。
List<double> relRot(List<double> gn, List<double> gn2) => [
      gn[0] * gn2[0] + gn[1] * gn2[1] + gn[2] * gn2[2],
      gn[0] * gn2[3] + gn[1] * gn2[4] + gn[2] * gn2[5],
      gn[0] * gn2[6] + gn[1] * gn2[7] + gn[2] * gn2[8],
      gn[3] * gn2[0] + gn[4] * gn2[1] + gn[5] * gn2[2],
      gn[3] * gn2[3] + gn[4] * gn2[4] + gn[5] * gn2[5],
      gn[3] * gn2[6] + gn[4] * gn2[7] + gn[5] * gn2[8],
      gn[6] * gn2[0] + gn[7] * gn2[1] + gn[8] * gn2[2],
      gn[6] * gn2[3] + gn[7] * gn2[4] + gn[8] * gn2[5],
      gn[6] * gn2[6] + gn[7] * gn2[7] + gn[8] * gn2[8],
    ];

/// Source HBe — 旋转体在偏航角 angle 下的轮廓半径。
List<double> solidRadii(List<List<double>> solid, double angle, [int n = 96]) {
  final c = math.cos(angle), s = math.sin(angle);
  final r = solid.map((t) => (t[0] * c + t[2] * s, t[1], t[3])).toList();
  final raw = List<double>.filled(n, 0);
  for (int idx = 0; idx < n; idx++) {
    final u = (idx / n) * math.pi * 2;
    final d = math.cos(u), m = math.sin(u);
    double f = 0;
    for (final (h, y, k) in r) {
      final v = d * h + m * y;
      final b = v * v - (h * h + y * y) + k * k;
      if (b <= 0) continue;
      final x = v + math.sqrt(b);
      if (x > f) f = x;
    }
    raw[idx] = f;
  }
  final o = raw.length;
  return List.generate(
    n,
    (i) =>
        (raw[(i - 2 + o) % o] + 4 * raw[(i - 1 + o) % o] + 6 * raw[i] + 4 * raw[(i + 1) % o] + raw[(i + 2) % o]) /
        16,
  );
}

/// Source Po().turnAt — 按 HBe(yaw)/HBe(0) 缩放极坐标环。
List<Offset> Function(double yaw) makeTurnAt(
    List<List<double>> solid, List<Offset> ring, double re) {
  final rest = solidRadii(solid, 0);
  return (yaw) {
    var v = solidRadii(solid, yaw)
        .asMap()
        .entries
        .map((e) => clampN((e.value + 12) / (rest[e.key] + 12), 0.32, 1.5))
        .toList();
    final n = v.length;
    for (int p = 0; p < 3; p++) {
      final prev = v;
      v = List.generate(
        n,
        (a) =>
            (prev[(a - 2 + n) % n] + 4 * prev[(a - 1 + n) % n] + 6 * prev[a] + 4 * prev[(a + 1) % n] + prev[(a + 2) % n]) /
            16,
      );
    }
    return List.generate(
        ring.length, (i) => Offset(re + (ring[i].dx - re) * v[i], re + (ring[i].dy - re) * v[i]));
  };
}

/// Source _Fe — 指针映射为角色周围的椭圆注视点（输入相对中心的本地坐标）。
Offset mapPointer(double width, double height, Offset rel, {double jfe = 0.6, double iin = 22, double ain = 14, double oin = 2}) {
  final o = math.min(1.0, math.sqrt(rel.distance / (width * oin)));
  final l = math.atan2(rel.dy, rel.dx);
  return Offset(
    jfe * (ain / iin) * o * math.cos(l) * width,
    jfe * o * math.sin(l) * height,
  );
}
