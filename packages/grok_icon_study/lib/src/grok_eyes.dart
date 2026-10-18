// Ported from grok-icon-study replica/src/eyes.js — eye morph, wink, blink queue, placement.
// Source symbols: en / ks / mn / P2.
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'grok_geometry.dart';
import 'grok_math.dart';
import 'grok_tables.dart' as t;

class BlinkKey {
  final double at, v;
  const BlinkKey(this.at, this.v);
}

void queueBlink(List<BlinkKey> q, double now, math.Random rnd) {
  q
    ..add(BlinkKey(now, 0.05))
    ..add(BlinkKey(now + 70, 0.05))
    ..add(BlinkKey(now + 150, 1.08))
    ..add(BlinkKey(now + 300, 1));
  if (rnd.nextDouble() < 0.14) {
    q..add(BlinkKey(now + 370, 0.05))..add(BlinkKey(now + 480, 1));
  }
}

double? consumeBlink(List<BlinkKey> q, double now) {
  double? key;
  while (q.isNotEmpty && now >= q.first.at) {
    key = q.removeAt(0).v;
  }
  return key;
}

double winkLid(double base, double now, double winkAt, int winkEye, int i) {
  var lid = math.max(base, 0.04);
  if (i == winkEye && now < winkAt + 320) {
    final xr = (now - winkAt) / 320;
    final fr = xr < 0.42 ? 1 - xr / 0.42 : (xr - 0.42) / 0.58;
    lid = math.max(lid * clampN(fr, 0, 1), 0.04);
  }
  return lid;
}

class EyesInput {
  final double now;
  final List<List<Offset>> polys;
  final double morphT;
  final GrokShapeData shape;
  final GrokFacePort face;
  final t.FaceTune? faceTune;
  final bool uniformEyes;
  final double eyeScaleProp;
  final double blinkX;
  final double gazeX, gazeY;
  final double winkAt;
  final int winkEye;
  final double? turn;
  final List<double>? cr; // 3x3 眼眶相对旋转
  final Offset? pointer;
  final double notifyX;
  final double overlayX;
  final double eyeBoostX;
  final double re;
  final double g9e;
  final double vjt;
  final TrickExtras extras;
  final List<Offset>? ringHint;
  final List<Offset>? badgeRing;
  final double? top, bottom;
  final double emphasisBlend;

  const EyesInput({
    required this.now,
    required this.polys,
    required this.morphT,
    required this.shape,
    required this.face,
    required this.faceTune,
    required this.uniformEyes,
    required this.eyeScaleProp,
    required this.blinkX,
    required this.gazeX,
    required this.gazeY,
    required this.winkAt,
    required this.winkEye,
    required this.turn,
    required this.cr,
    required this.pointer,
    required this.notifyX,
    required this.overlayX,
    required this.eyeBoostX,
    required this.re,
    required this.g9e,
    required this.vjt,
    required this.extras,
    required this.ringHint,
    required this.badgeRing,
    required this.top,
    required this.bottom,
    required this.emphasisBlend,
  });
}

/// 附加的特技量（Source extras / tf）。
class TrickExtras {
  final double? turn;
  final double kr, yi, ki, yr, zr, wi, hop;
  const TrickExtras({
    this.turn,
    this.kr = 0,
    this.yi = 0,
    this.ki = 0,
    this.yr = 0,
    this.zr = 0,
    this.wi = 0,
    this.hop = 0,
  });
}

/// 单只眼睛的渲染指令：将 poly 以 (dx,dy) 平移、matrix 或 scale 缩放绘制。
class EyeRender {
  final List<Offset> poly;
  final bool visible;
  final double dx, dy;
  final double sx, sy;
  final List<double>? matrix; // [a, b, c, d]（SVG matrix 参数顺序）
  const EyeRender(this.poly, this.visible, this.dx, this.dy, this.sx, this.sy, this.matrix);
}

class BadgeRender {
  final double cx, cy, r;
  const BadgeRender(this.cx, this.cy, this.r);
}

class EyesResult {
  final List<EyeRender> eyes;
  final BadgeRender? badge;
  const EyesResult(this.eyes, this.badge);
}

EyesResult computeEyes(EyesInput opt) {
  final pulse = 1 + 0.07 * math.sin(opt.morphT * math.pi);
  final face = opt.face;
  final tune = opt.faceTune;
  final fi = GrokFacePort(
    x: face.x,
    y: face.y,
    sx: face.sx * (tune?.gap ?? 1),
    sy: face.sy * (tune?.height ?? 1),
    eye: face.eye * (tune?.size ?? 1),
    leftDX: face.leftDX,
  );
  final sX = opt.uniformEyes ? fi.leftDX : 0.0;
  final cents = [centroid(opt.polys[0]), centroid(opt.polys[1])];
  var a1 = 0.0, o1 = 0.0;
  for (final p in opt.polys[0]) {
    a1 = math.max(a1, (p.dx - cents[0].dx).abs());
  }
  for (final p in opt.polys[1]) {
    o1 = math.max(o1, (p.dx - cents[1].dx).abs());
  }
  final l1 = (cents[1].dx - (cents[0].dx + sX)).abs() * fi.sx;
  final pre = opt.uniformEyes ? 0.0 : opt.vjt;
  final ee = a1 + o1 > 0.5 ? clampN((l1 - pre) / (a1 + o1), 0.35, 4) : 4.0;
  final uee = (opt.uniformEyes ? 1 : fi.eye) * clampN(opt.eyeScaleProp, 0.25, 4);
  final ox = math.min(clampN(opt.eyeBoostX, 0.2, 2) * uee, ee / pulse);
  final hee = math.min(ox * clampN(tune?.eyeWidth ?? 1, 0.2, 3), ee / pulse);
  final u1 = ox * clampN(tune?.eyeHeight ?? 1, 0.2, 3);
  final re = opt.re;
  (double, double) liveSpan(double y) =>
      opt.ringHint != null ? spanPoly(opt.ringHint!, y, re) : spanAt(opt.shape.path, re)(y);
  final top = opt.top ?? opt.shape.top;
  final bottom = opt.bottom ?? opt.shape.bottom;
  final vn = opt.emphasisBlend;
  final midX = (cents[0].dx + cents[1].dx) / 2;
  final midY = (cents[0].dy + cents[1].dy) / 2;
  final pullX = (re - midX) * 0.42 * vn;
  final pullY = (re - midY) * 0.42 * vn;
  final gazeW = opt.pointer != null ? 0.2 : 1.0;
  final badgeRing = opt.badgeRing;
  final yl = badgeRing != null
      ? badgeRing[((badgeRing.length * 7 / 8).round()) % badgeRing.length]
      : Offset(re, opt.shape.top);

  final renders = <EyeRender>[];
  for (int i = 0; i < 2; i++) {
    final poly = opt.polys[i];
    final (gn, ti) = (cents[i].dx, cents[i].dy);
    final lid = winkLid(opt.blinkX, opt.now, opt.winkAt, opt.winkEye, i);
    final ea = gn + (i == 0 ? sX : 0.0);
    var ca = re + fi.x;
    var wo = (ea - re) * fi.sx;
    var c3 = 1.0, vre = 1.0, km = 1.0, ree = 0.0, fee = 0.0, zee = 1.0;
    var bre = true, tre = 1.0;
    var sre = clampN(re + fi.y + (ti - re) * fi.sy, top + 2, bottom - 2);
    final cr = opt.cr;
    final use3d = cr != null;

    if (use3d) {
      final xr = (ea - re) / re;
      final fr = (re - ti) / re;
      final ia = math.sqrt(math.max(0, 1 - xr * xr - fr * fr));
      final iaz = ia == 0 ? 0.02 : ia;
      final li = cr[0] * xr + cr[1] * fr + cr[2] * iaz;
      final bl = cr[3] * xr + cr[4] * fr + cr[5] * iaz;
      final io = cr[6] * xr + cr[7] * fr + cr[8] * iaz;
      wo = li * re * fi.sx;
      sre = clampN(re + fi.y - bl * re * fi.sy, top + 2, bottom - 2);
      var uo = -fr * xr, tl = 1 - fr * fr, zi = -fr * iaz;
      final yo = math.sqrt(uo * uo + tl * tl + zi * zi);
      if (yo < 1e-6) {
        uo = 0;
        tl = 0;
        zi = 1;
      } else {
        uo /= yo;
        tl /= yo;
        zi /= yo;
      }
      final md = fr * zi - iaz * tl, oc = iaz * uo - xr * zi, yu = xr * tl - fr * uo;
      final vm = cr[0] * uo + cr[1] * tl + cr[2] * zi;
      final hme = cr[3] * uo + cr[4] * tl + cr[5] * zi;
      final nre = cr[0] * md + cr[1] * oc + cr[2] * yu;
      final ere = cr[3] * md + cr[4] * oc + cr[5] * yu;
      final cre2 = md, ha = -oc, ci = uo, ys2 = -tl;
      final ku = cre2 * ys2 - ci * ha == 0 ? 1e-6 : cre2 * ys2 - ci * ha;
      final ql = ys2 / ku, gee = -ci / ku, bm = -ha / ku, ire = cre2 / ku;
      km = nre * ql + vm * bm;
      fee = nre * gee + vm * ire;
      ree = -ere * ql + -hme * bm;
      zee = -ere * gee + -hme * ire;
      c3 = math.max(math.sqrt(km * km + ree * ree), 0.02);
      vre = math.max(math.sqrt(fee * fee + zee * zee), 0.02);
      bre = io > 0.02;
      tre = dke(clampN(io / 0.5, 0, 1));
    }

    final turn = opt.turn;
    if (turn != null) {
      final (spL, spR) = liveSpan(sre);
      final rad = math.max((spR - spL) / 2, 12);
      ca = (spL + spR) / 2;
      final li0 = math.asin(clampN(wo / rad, -1, 1));
      final bl0 = li0 + turn;
      final io0 = math.cos(bl0);
      final uo0 = math.max(math.cos(li0), 0.02);
      bre = io0 > 0.02;
      c3 = math.max(io0, 0.02) / uo0;
      wo = rad * math.sin(bl0);
      tre = dke(clampN(io0 / 0.5, 0, 1));
    }

    var kj = math.sin(opt.now * 42e-5 + i) * 1.4 + math.sin(opt.now * 0.001 + i * 2) * 0.5;
    var ko = math.sin(opt.now * 58e-5 + i) * 0.9;
    final pointer = opt.pointer;
    if (pointer != null) {
      kj += pointer.dx * (1 - 0.6 * vn) + pullX;
      ko += pointer.dy * (1 - 0.6 * vn) + pullY;
    } else {
      kj += pullX;
      ko += pullY;
    }
    kj += opt.gazeX * gazeW + opt.extras.zr;
    ko += opt.gazeY * gazeW + opt.extras.wi;
    final ee2 = clampN(opt.notifyX, 0, 1);
    kj -= 10 * ee2;
    ko += 7 * ee2;

    final vee = clampN(c3 * hee * pulse, 0.02, 2.4);
    final w2 = clampN(vre * lid * u1 * pulse, 0.02, 2.4);
    final visible = bre && opt.overlayX < 0.5;
    final useTurnOr3d = turn != null || use3d;
    final ume = opt.g9e * w2 + 2;
    final vl = clampN(
      useTurnOr3d ? sre + ko * fi.sy : re + fi.y + (ti + ko - re) * fi.sy,
      top + ume,
      bottom - ume,
    );
    var o2 = double.negativeInfinity, xl = double.infinity;
    for (int p = 0; p < poly.length; p += 2) {
      final frp = (poly[p].dx - gn) * vee;
      final (ia2, li2) = liveSpan(vl + (poly[p].dy - ti) * w2);
      if (ia2 - frp > o2) o2 = ia2 - frp;
      if (li2 - frp < xl) xl = li2 - frp;
    }
    final xre = ca + wo + kj * fi.sx;
    final lX = o2 <= xl ? clampN(xre, o2, xl) : (o2 + xl) / 2;
    var dd = lX + (xre - lX) * (1 - tre);
    var yj = vl;
    if (opt.notifyX > 0.01) {
      final xr = 20 * clampN(opt.notifyX, 0, 1.4);
      final fr = dd - yl.dx, ia = yj - yl.dy;
      final li = math.sqrt(fr * fr + ia * ia);
      final liN = li == 0 ? 1 : li;
      final bl = fr / liN, io = ia / liN;
      final uo = (i == 0 ? a1 : o1) * vee;
      final tl = math.sqrt(uo * uo * bl * bl + opt.g9e * opt.g9e * w2 * w2 * io * io);
      final zi = xr + tl + 5;
      if (li < zi) {
        dd += bl * (zi - li);
        yj += io * (zi - li);
      }
    }

    List<double>? matrix;
    if (use3d) {
      final frm = clampN((turn != null ? c3 : 1) * hee * pulse, 0.02, 2.4);
      final iam = clampN(lid * u1 * pulse, 0.02, 2.4);
      final lim = km * frm, blm = ree * frm, iom = fee * iam, uom = zee * iam;
      matrix = [lim, blm, iom, uom];
    }
    renders.add(EyeRender(poly, visible, dd, yj, vee, w2, matrix));
  }

  BadgeRender? badge;
  if (opt.notifyX > 0.01) {
    final amt = clampN(opt.notifyX, 0, 1.4);
    badge = BadgeRender(yl.dx, yl.dy, 20 * amt);
  }
  return EyesResult(renders, badge);
}
