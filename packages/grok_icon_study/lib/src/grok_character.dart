// Ported from grok-icon-study replica/src/character.js — GrokCharacter orchestrator.
// Source: $_t + sd(). 驱动方式由 requestAnimationFrame 改为外部 tick。
import 'dart:math' as math;
import 'dart:ui' show Offset, Path, Size;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/painting.dart' show Color;

import 'grok_eyes.dart';
import 'grok_fx.dart';
import 'grok_geometry.dart';
import 'grok_math.dart';
import 'grok_pose.dart';
import 'grok_tables.dart' as t;
import 'grok_tricks.dart' as tr;

class GrokSnapshot {
  final String state, mode, shape, color, scheme;
  final int eyeFrom, eyeTo;
  final double spin, tx, ty, squash, blink;
  final String? overlay;
  const GrokSnapshot({
    required this.state,
    required this.mode,
    required this.shape,
    required this.color,
    required this.scheme,
    required this.eyeFrom,
    required this.eyeTo,
    required this.spin,
    required this.tx,
    required this.ty,
    required this.squash,
    required this.blink,
    this.overlay,
  });
}

/// 单帧渲染数据（SVG 用户坐标系，viewBox -15..244）。
class GrokFrame {
  final double tx, ty, rotDeg, sx, sy;
  final double groupOpacity;
  final double poseScale;
  final double zoom; // viewBox 缩放（>1 = 拉近视口）
  final Path bodyPath;
  final EyesResult eyes;
  final FxFrame fx;
  const GrokFrame({
    required this.tx,
    required this.ty,
    required this.rotDeg,
    required this.sx,
    required this.sy,
    required this.groupOpacity,
    required this.poseScale,
    required this.zoom,
    required this.bodyPath,
    required this.eyes,
    required this.fx,
  });
}

final Map<String, Path> _svgPathCache = {};
Path parseSvgPath(String d) =>
    _svgPathCache.putIfAbsent(d, () => _polyToPath(flattenPath(d)));

Path _polyToPath(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final pt in pts.skip(1)) {
    p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

class GrokCharacter extends ChangeNotifier {
  final math.Random rnd;
  String shapeName;
  String colorId;
  String scheme;
  String mode;
  String _state;
  final bool loginWrap;
  late final bool eyeTopology;
  late final t.FaceTune? faceTune;
  final double poseTurn, poseTilt, poseRoll;
  final double homeTurn, homeTilt, homeRoll;
  double poseScaleVal = 1;
  late final bool uniformEyes;
  double eyeScaleProp = 1;
  bool emphasis = false;
  bool followPointer;
  Offset? gazeTargetRel;
  Size? _pointerSize;
  bool paused = false;
  final bool reduceMotion;
  final Color badgeColor;
  final Color? eyeColor;

  final Spring spin = Spring(0);
  final Spring txS = Spring(0);
  final Spring tyS = Spring(0);
  final Spring squash = Spring(1);
  final Spring blink = Spring(1);
  final Spring eyeScale = Spring(1);
  final Spring gazeX = Spring(0);
  final Spring gazeY = Spring(0);
  final Spring eyeMorph = Spring(1);
  final Spring overlay = Spring(0);
  final Spring overlayMix = Spring(1);
  final Spring notify = Spring(0);
  final Spring humDots = Spring(0);
  final Spring shapeSpring = Spring(1);
  final Spring overlayTurn = Spring(0);
  double emphasisBlend = 0;

  int eyeFrom = 0, eyeTo = 0, eyeIdx = 0;
  double eyeStiffness = 7;
  List<List<Offset>>? _fromPolys;

  double t0 = 0, stateAt = 0, last = 0;
  double nowMs = 0;
  int moodN = 0;
  double eyeUntil = 0, blinkUntil = 0, gazeUntil = 0;
  final List<BlinkKey> blinkQueue = [];
  double winkAt = -1e9;
  int winkEye = 0;
  double winkUntil = 0;
  Spring? spinTurn;
  tr.Trick? trick;
  double hopAt = -1;
  double trickAt = 0;
  bool wildWide = false;
  double ovSpin = 0;
  double ovTurnAcc = 0;
  bool ovOn = false;
  int ovTurnDir = 1;
  double pointerTx = 0, pointerTy = 0;
  Offset? pointerRel;
  late String prevShape;
  GrokFacePort? prevFace;
  List<Offset>? prevRing;
  double? prevTilt;
  double? prevBelt;
  late PoseCtx ctx;
  String? ovKind;
  String? ovPrev;
  String? ovTarget;
  bool ovRest = false;
  double ovRestAt = 0;
  double pxW = 190;
  double pxAt = 0;
  double partScale = 1;
  double celebrateAt = -1;
  TrickExtras extras = const TrickExtras();

  late final OverlayLayer fx = OverlayLayer();
  late final Particles particles;

  GrokFrame? frame;

  GrokCharacter({
    this.shapeName = 'blob',
    this.colorId = 'black',
    this.scheme = 'light',
    this.mode = 'onboarding',
    String state = 'idle',
    this.loginWrap = true,
    bool? eyeTopologyOverride,
    t.FaceTune? faceTuneOverride,
    this.poseTurn = t.poseTurn,
    this.poseTilt = t.poseTilt,
    this.poseRoll = t.poseRoll,
    this.homeTurn = t.poseHomeTurn,
    this.homeTilt = t.poseHomeTilt,
    this.homeRoll = t.poseHomeRoll,
    bool? uniformEyesOverride,
    double? eyeScaleOverride,
    this.emphasis = false,
    this.followPointer = false,
    this.paused = false,
    this.reduceMotion = false,
    Color? badgeColor,
    this.eyeColor,
    int? seed,
  })  : _state = state,
        badgeColor = badgeColor ?? const Color(0xFF1D9BF0),
        rnd = math.Random(seed) {
    eyeTopology = eyeTopologyOverride ?? loginWrap;
    faceTune = faceTuneOverride ?? (loginWrap ? t.faceTune : null);
    uniformEyes =
        uniformEyesOverride ?? (loginWrap ? t.uniformEyesDefault : false);
    eyeScaleProp =
        eyeScaleOverride ?? (loginWrap ? t.shapeEyeScaleOf(shapeName) : 1);
    particles = Particles(
      getRadius: () {
        final sh = GrokGeometry.shapes[shapeName]!;
        final k = k2(clampN(shapeSpring.x, 0, 1));
        final to = sh.beltRadius ?? beltRadius(sh.path, GrokGeometry.re);
        var je = k < 0.999 && prevBelt != null
            ? prevBelt! + (to - prevBelt!) * k
            : to;
        if (state == 'loading') {
          je += (52 - je) * clampN(overlay.x, 0, 1);
        }
        return je;
      },
      rnd: rnd,
      reduce: reduceMotion,
    );
    t0 = 0;
    stateAt = 0;
    last = 0;
    nowMs = 0;
    moodN = 0;
    eyeUntil =
        t0 + randOf(rnd, t.eyeHoldMs['idle']!.$1, t.eyeHoldMs['idle']!.$2);
    blinkUntil = t0 + randOf(rnd, 1500, 7000);
    gazeUntil = t0 + 800;
    winkAt = -1e9;
    winkUntil = t0 + randOf(rnd, 3000, 8000);
    spinTurn = null;
    trick = null;
    hopAt = -1;
    trickAt = t0 + randOf(rnd, 2500, 5000);
    wildWide = false;
    ovSpin = 0;
    ovTurnAcc = 0;
    ovOn = false;
    ovTurnDir = 1;
    prevShape = shapeName;
    ctx = PoseCtx()..reset(t0, rnd);
    ovKind = null;
    ovPrev = null;
    ovTarget = null;
    ovRest = false;
    ovRestAt = 0;
    pxW = 190;
    pxAt = 0;
    partScale = 1;
    celebrateAt = -1;
    extras = const TrickExtras();
    _applyPoseScale();
    setStateName(_state, resetEyes: true);
    _paint(t0);
  }

  String get state => _state;

  @override
  void dispose() {
    particles.clear();
    super.dispose();
  }

  void setMode(String m) {
    mode = m;
    if (m == 'onboarding') {
      moodN = 0;
      stateAt = nowMs;
      setStateName('idle', resetEyes: true);
    }
  }

  void setPaused(bool v) => paused = v;

  void setEmphasis(bool v) => emphasis = v;

  void setFollowPointer(bool v) {
    followPointer = v;
    if (!v) {
      pointerRel = null;
      gazeTargetRel = null;
    }
  }

  /// [rel] 指针相对角色中心的位置（本地坐标），[size] 角色渲染区域大小。
  void updatePointer(Offset? rel, Size size) {
    pointerRel = rel;
    _pointerSize = size;
  }

  void setShape(String name) {
    if (!GrokGeometry.shapes.containsKey(name) || name == shapeName) return;
    final r = GrokGeometry.re;
    final k = k2(clampN(shapeSpring.x, 0, 1));
    final rest = shapeMetrics(GrokGeometry.shapes[shapeName]!, r);
    if (k >= 1 || prevFace == null || prevRing == null) {
      prevFace = GrokFacePort.from(rest.face);
      prevRing = rest.ring;
      prevTilt = rest.tilt;
      prevBelt = rest.belt;
    } else {
      prevFace = lerpFace(prevFace!, GrokFacePort.from(rest.face), k);
      prevRing = lerpRing(prevRing!, rest.ring, k);
      prevTilt = prevTilt! + (rest.tilt - prevTilt!) * k;
      prevBelt = prevBelt! + (rest.belt - prevBelt!) * k;
    }
    prevShape = shapeName;
    shapeName = name;
    shapeSpring
      ..x = 0
      ..v = 0
      ..t = 1;
    if (loginWrap) eyeScaleProp = t.shapeEyeScaleOf(name);
    _applyPoseScale();
    _cycleShapeTrick();
  }

  void setColor(String id, [String? schemeVal]) {
    colorId = id;
    if (schemeVal != null) scheme = schemeVal;
  }

  void setStateName(String name, {bool resetEyes = false}) {
    if (!t.eyePlaylist.containsKey(name)) return;
    _state = name;
    stateAt = nowMs;
    final list = t.eyePlaylist[name]!;
    eyeIdx = 0;
    if (resetEyes) {
      eyeFrom = list[0];
      eyeTo = list[0];
      _fromPolys = null;
      eyeMorph
        ..x = 1
        ..t = 1
        ..v = 0;
    } else if (name != 'sleeping' && name != 'waking') {
      _morphEyes(list[0], name == 'excited' ? 10 : 8);
    }
    final hold = t.eyeHoldMs[name]!;
    eyeUntil = stateAt + randOf(rnd, hold.$1, hold.$2);
    final bc = t.blinkMs[name];
    blinkUntil =
        bc == null ? double.infinity : stateAt + randOf(rnd, 1500, 7000);
    gazeUntil = stateAt + randOf(rnd, 500, 1400);
    winkUntil = stateAt + randOf(rnd, 3000, 8000);
    ctx = PoseCtx()..reset(stateAt, rnd);
    ctx.stAt = stateAt +
        (name == 'excited'
            ? randOf(rnd, 400, 1100)
            : name == 'searching'
                ? randOf(rnd, 800, 1600)
                : name == 'working'
                    ? randOf(rnd, 1200, 2400)
                    : randOf(rnd, 6000, 10000));
    celebrateAt = name == 'celebrate' ? stateAt + 140 : -1;
    trick = null;
    spinTurn = null;
    hopAt = -1;
    wildWide = false;
    if (name != 'writing') fx.resetInk();
    if (name != 'waking' && name != 'sleeping' && name != 'drowsy') {
      queueBlink(blinkQueue, stateAt, rnd);
    }
    notifyListeners();
  }

  GrokSnapshot snapshot() => GrokSnapshot(
        state: _state,
        mode: mode,
        shape: shapeName,
        color: colorId,
        scheme: scheme,
        eyeFrom: eyeFrom,
        eyeTo: eyeTo,
        spin: spin.x,
        tx: txS.x,
        ty: tyS.x,
        squash: squash.x,
        blink: blink.x,
        overlay: ovKind,
      );

  void spinOnce([int turns = 1]) => _pn(turns);

  void bounceOnce() => _hop(nowMs);

  void burstOnce() {
    if (!reduceMotion) particles.burst(22, 1.1, 0.3);
  }

  void updateRenderWidth(double w) => pxW = w;

  /// 姿态弹簧立即吸附到目标值：挂载出场时直接呈现稳定姿态，
  /// 消除从偏移位置弹入的位移动画（不影响后续表情/跳动动画）
  void snapPose() {
    for (final s in [
      spin,
      txS,
      tyS,
      squash,
      blink,
      eyeScale,
      gazeX,
      gazeY,
      eyeMorph,
      overlay,
      overlayMix,
      notify,
      humDots,
      shapeSpring,
      overlayTurn,
    ]) {
      s.x = s.t;
      s.v = 0;
    }
  }

  void _applyPoseScale() {
    poseScaleVal = loginWrap ? t.poseScaleOf(shapeName) : 1;
  }

  void _morphEyes(int index, [double stiffness = 7]) {
    if (index == eyeTo && eyeMorph.t == 1) return;
    final tv = clampN(eyeMorph.x, 0, 1);
    eyeFrom = eyeTo;
    _fromPolys = _currentPolys(tv);
    eyeTo = index;
    eyeMorph
      ..x = 0
      ..v = 0
      ..t = 1;
    eyeStiffness = stiffness;
  }

  List<List<Offset>> _currentPolys(double tv) {
    final eyes = GrokGeometry.eyes;
    final from = _fromPolys ?? eyes[eyeFrom];
    final to = eyes[eyeTo];
    return [lerpPoly(from[0], to[0], tv), lerpPoly(from[1], to[1], tv)];
  }

  void _pn([int turns = 1, int? dir]) {
    if (reduceMotion || paused || spinTurn != null) return;
    spinTurn = tr.makeSpinTurn(turns, dir ?? signOf(rnd));
  }

  void _hop(double now) {
    if (hopAt < 0) hopAt = now;
  }

  void _cycleShapeTrick() {
    if (reduceMotion || paused) return;
    wildWide = false;
    // 换形彩蛋统一为单圈俏皮旋转：曾按 5 次循环轮换 spinDizzy(3-4 圈)/
    // _pn(2) 多圈，叠加转圈观感差，频繁切换形状（多 bot）场景尤甚
    _pn(1);
    particles.burst(16, 0.95, 0.3);
  }

  void _stepOverlay(double now) {
    final want = overlayMap[_state];
    if (want != ovTarget) {
      ovTarget = want;
      fx.overlayAt = now;
      ovRest = false;
      ovRestAt = 0;
    }
    var on = want != null;
    if (want != null && overlayCycle.contains(_state)) {
      if (!ovRest && now - fx.overlayAt > (cycleOnMs[_state] ?? 2500)) {
        ovRest = true;
        ovRestAt = now;
      } else if (ovRest && now - ovRestAt > cycleOffMs) {
        ovRest = false;
        fx.overlayAt = now;
      }
      on = !ovRest;
    }
    overlay.t = on ? 1 : 0;
    if (on != ovOn) {
      if (!reduceMotion) {
        if (on) ovTurnDir = signOf(rnd);
        ovTurnAcc += math.pi * ovTurnDir;
        overlayTurn.t = ovTurnAcc;
      }
      ovOn = on;
    }
    if (want != null && want != ovKind) {
      if (ovKind != null && overlay.x > 0.02) {
        ovPrev = ovKind;
        overlayMix
          ..x = 0
          ..v = 0
          ..t = 1;
      } else {
        ovPrev = null;
        overlayMix
          ..x = 1
          ..v = 0
          ..t = 1;
      }
      ovKind = want;
      fx.overlayAt = now;
      if (want != 'pencil') fx.resetInk();
    }
    if (want == null && overlay.x < 0.004) {
      ovKind = null;
      ovPrev = null;
    }
    if (overlayMix.x > 0.996) ovPrev = null;
  }

  void _updatePointer(double now) {
    final src = gazeTargetRel ?? (followPointer ? pointerRel : null);
    final size = _pointerSize;
    if (src != null && size != null && size.width > 0) {
      final mapped = gazeTargetRel != null
          ? src
          : mapPointer(size.width, size.height, src);
      pointerTx = clampN(mapped.dx / size.width, -0.6, 0.6) * 22;
      pointerTy = clampN(mapped.dy / size.height, -0.6, 0.6) * 14;
    } else {
      pointerTx = 0;
      pointerTy = 0;
    }
    final z = rnSmooth(0.16);
    _pointerX += (pointerTx - _pointerX) * z;
    _pointerY += (pointerTy - _pointerY) * z;
  }

  double _pointerX = 0, _pointerY = 0;

  /// 每帧驱动：[now] 单调毫秒时钟。
  GrokFrame tick(double now) {
    nowMs = now;
    final dt = math.min((now - last) / 1000, 0.1);
    _pendingDt = dt;
    last = now;
    if (paused) {
      _paint(now);
      return frame!;
    }

    if (mode == 'onboarding' && now - stateAt >= t.onboardingMs) {
      moodN += 1;
      setStateName(t.onboardMood(moodN));
    }

    final mt = (now - t0) / 1000;
    final dtState = (now - stateAt) / 1000;
    final pose = applyPose(_state, mt, dtState, now, ctx, rnd,
        eyeTo: eyeTo, eyeMorphX: eyeMorph.x, blinkX: blink.x);
    spin.t = pose.spin;
    txS.t = pose.tx;
    tyS.t = pose.ty;
    squash.t = pose.squash;
    eyeScale.t = pose.eyeBoost;
    if (ctx.tyKick != 0) {
      tyS.v += ctx.tyKick;
      ctx.tyKick = 0;
    }
    if (ctx.spinKick != 0) {
      spin.v += ctx.spinKick;
      ctx.spinKick = 0;
    }
    if (ctx.forceSleepEye) {
      ctx.forceSleepEye = false;
      _morphEyes(13, 11);
    }
    if (ctx.wakeEye != null) {
      _morphEyes(ctx.wakeEye![0].toInt(), ctx.wakeEye![1]);
      ctx.wakeEye = null;
    }
    if (ctx.wakeBlink && !ctx.wakingBlinked && blinkQueue.isEmpty) {
      queueBlink(blinkQueue, now, rnd);
      ctx.wakingBlinked = true;
    }
    ctx.wakeBlink = false;
    if (ctx.wantBlink) {
      queueBlink(blinkQueue, now, rnd);
      ctx.wantBlink = false;
    }
    if (ctx.wantPn != null) {
      _pn(ctx.wantPn![0].toInt(), ctx.wantPn![1].toInt());
      ctx.wantPn = null;
    }
    if (ctx.wantBurst != null) {
      particles.burst(ctx.wantBurst![0].toInt(), ctx.wantBurst![1]);
      ctx.wakingBurst = true;
      ctx.wantBurst = null;
    }

    _stepOverlay(now);

    if (celebrateAt > 0 &&
        now >= celebrateAt &&
        trick == null &&
        spinTurn == null) {
      trick = tr.startTrick('spinWild', reduceMotion, now, rnd);
      celebrateAt = now + 6200;
    }

    if (now >= trickAt) {
      if ((t.vT.contains(_state) || t.bT.contains(_state)) &&
          spinTurn == null &&
          hopAt < 0 &&
          trick == null) {
        final z = rnd.nextDouble();
        if (t.vT.contains(_state)) {
          if (z < 0.55) {
            _pn(1);
          } else {
            trick = tr.startTrick('spinBounce', reduceMotion, now, rnd);
          }
        } else if (z < 0.34) {
          trick = tr.startTrick('spinBounce', reduceMotion, now, rnd);
        } else if (z < 0.62) {
          _hop(now);
        } else if (z < 0.86) {
          trick = tr.startTrick('spinDizzy', reduceMotion, now, rnd);
        } else {
          _pn(1);
        }
      }
      trickAt = now + randOf(rnd, 9000, 18000);
    }

    final tf = tr.evalTrick(trick, now);
    if (tf.wantHop) _hop(now);
    if (tf.done) trick = null;
    var hop = tr.hopY(hopAt, now);
    if (hop == null) {
      hopAt = -1;
      hop = 0;
    }
    var turn = tf.turn;
    if (spinTurn != null) {
      turn = (turn ?? 0) + spinTurn!.x;
      if (tr.spinTurnSettled(spinTurn!)) spinTurn = null;
    }
    extras = TrickExtras(
      turn: turn,
      kr: tf.kr,
      yi: tf.yi,
      ki: tf.ki,
      yr: tf.yr,
      zr: tf.zr,
      wi: tf.wi,
      hop: hop,
    );

    if (tf.eyeBoost != null) eyeScale.t = tf.eyeBoost!;

    if (_state != 'waking' && _state != 'sleeping' && now >= eyeUntil) {
      final list = t.eyePlaylist[_state]!;
      eyeIdx = (eyeIdx + 1 + rnd.nextInt(list.length - 1)) % list.length;
      final stiff = _state == 'searching' || _state == 'excited' ? 10.0 : 6.0;
      _morphEyes(list[eyeIdx], stiff);
      final hold = t.eyeHoldMs[_state]!;
      eyeUntil = now + randOf(rnd, hold.$1, hold.$2);
    }

    final blinkCadence = t.blinkMs[_state];
    if (blinkCadence != null && now >= blinkUntil) {
      queueBlink(blinkQueue, now, rnd);
      blinkUntil = now + randOf(rnd, blinkCadence.$1, blinkCadence.$2);
    }
    final blinkKey = consumeBlink(blinkQueue, now);
    blink.t =
        blinkKey ?? (blinkQueue.isNotEmpty ? blink.t : (tf.lidMul ?? pose.lid));

    if (now >= gazeUntil) {
      final gz = nextGaze(_state, rnd);
      gazeX.t = gz.x;
      gazeY.t = gz.y;
      gazeUntil = now + randOf(rnd, gz.hold.$1, gz.hold.$2);
    }

    if (t.winkStates.contains(_state) && now >= winkUntil) {
      winkAt = now;
      winkEye = rnd.nextDouble() < 0.5 ? 0 : 1;
      winkUntil = now + randOf(rnd, 4500, 10000);
    }

    emphasisBlend += ((emphasis ? 1 : 0) - emphasisBlend) * rnSmooth(0.12);

    if (emphasis) {
      eyeScale.t = math.max(eyeScale.t, 1.32);
      blink.t = math.max(blink.t, 1.18);
    }

    final humming = _state == 'humming';
    final loading = _state == 'loading';
    if ((humming || loading) && !reduceMotion) {
      final zt = dtState;
      final dn = loading ? 3.0 : 1.6;
      final on = zt < 0.5
          ? 7 * k2(zt / 0.5)
          : zt < 1.3
              ? 7 + (dn - 7) * k2((zt - 0.5) / 0.8)
              : dn + 0.3 * math.sin(zt * 0.5);
      ovSpin += on * dt;
    }

    if (reduceMotion) {
      _morphEyes(t.eyePlaylist[_state]![0]);
      spin.t = 0;
      txS.t = 0;
      tyS.t = 0;
      squash.t = 1;
      blink.t = 1;
      eyeScale.t = 1;
    }

    final nSteps = springSteps(dt);
    final step = dt / nSteps;
    for (int i = 0; i < nSteps; i++) {
      stepSpring(eyeMorph, eyeStiffness, 1, step);
      if (spinTurn != null) {
        final (f, d) = t.springs['spinTurn']!;
        stepSpring(spinTurn!, f, d, step);
      }
      _stepAllSprings(step);
    }
    if (reduceMotion) {
      overlayMix.x = 1;
      overlayTurn.x = overlayTurn.t;
      overlay.x = overlay.t;
    }
    notify.t = _state == 'notifying' ? 1 : 0;
    humDots.t = _state == 'humming' ? 1 : 0;

    var spinAngle = 0.0;
    if (spinTurn != null) {
      spinAngle = spinTurn!.x;
    } else if (extras.turn != null) {
      spinAngle = extras.turn!;
    } else if (humming || loading) {
      spinAngle = ovSpin;
    }
    if (now - pxAt > 500) {
      final w = pxW;
      if (w > 0) {
        partScale = clampN(math.pow(340 / w, 0.7).toDouble(), 1, 2.6);
      }
      pxAt = now;
    }

    _updatePointer(now);
    _paint(now, spinAngle: spinAngle);

    notifyListeners();
    return frame!;
  }

  void _stepAllSprings(double step) {
    void ss(Spring s, String key) {
      final (f, d) = t.springs[key]!;
      stepSpring(s, f, d, step);
    }

    ss(spin, 'spin');
    ss(txS, 'x');
    ss(tyS, 'y');
    ss(squash, 'squash');
    ss(blink, 'blink');
    ss(eyeScale, 'eyeScale');
    ss(notify, 'notify');
    ss(humDots, 'humDots');
    ss(gazeX, 'gazeX');
    ss(gazeY, 'gazeY');
    ss(overlay, 'overlay');
    ss(overlayMix, 'overlayMix');
    ss(shapeSpring, 'shape');
    ss(overlayTurn, 'overlayTurn');
  }

  Color get foreground {
    final pal = GrokGeometry.palette[colorId] ?? GrokGeometry.palette['black']!;
    return Color(scheme == 'dark' ? pal.$2 : pal.$1);
  }

  Color get eyeFill => eyeColor ?? const Color(0xFFF3EFE6);

  void _paint(double now, {double spinAngle = 0}) {
    final r = GrokGeometry.re;
    final shape = GrokGeometry.shapes[shapeName]!;
    final fxFrame = FxFrame();
    particles.update(
        now,
        _pendingDt,
        spinAngle,
        partScale,
        (trick?.kind == 'spinWild') || wildWide || _state == 'humming',
        _state == 'humming' || _state == 'loading',
        fxFrame);

    final morphK = k2(clampN(shapeSpring.x, 0, 1));
    final morphing = morphK < 0.999 && prevFace != null;
    GrokFacePort face;
    if (morphing) {
      face = lerpFace(prevFace!, GrokFacePort.from(shape.face), morphK);
    } else {
      face = GrokFacePort.from(shape.face);
    }
    final fromTilt =
        prevTilt ?? (GrokGeometry.shapes[prevShape]?.tiltScale ?? 1);
    final tilt = morphing
        ? fromTilt + (shape.tiltScale - fromTilt) * morphK
        : shape.tiltScale;

    final yl = clampN(overlay.x, 0, 1);
    final mix = clampN(overlayMix.x, 0, 1);
    fx.setReduce(reduceMotion);
    final ov = fx.extras(now, stateAt, ovKind, ovPrev, yl, mix);
    final bodyW = 1 - yl;
    final ex = extras;
    final tx = txS.x * bodyW + ex.yi * bodyW + ov.yre * yl;
    final ty = (tyS.x + ex.hop) * bodyW +
        ex.ki * bodyW -
        ov.rx.lift * ov.lee +
        ov.ax * yl;
    final rot =
        (spin.x * bodyW + ex.kr * bodyW) * tilt + ex.yr * bodyW + ov.wl * yl;
    final sx = bodyW + ov.wre * yl;
    final sy = squash.x * bodyW + ov.wre * yl;
    final groupOpacity = (1 - (1 - ov.rx.tone) * ov.lee) * (1 - ov.fade);

    final jc = clampN(yl / pBlend, 0, 1);
    final isPencil = ovKind == 'pencil' || ovPrev == 'pencil';
    final tear = GrokGeometry.shapes['teardrop']?.path;
    final spinAmt = ex.turn;
    final spinning = spinAmt != null;
    final restRing = morphing
        ? lerpRing(prevRing!, shapeRing(shape.path, r), morphK)
        : shapeRing(shape.path, r);
    var liveRing = restRing;
    var turned = false;
    final turnAt =
        !morphing && spinning ? turnAtOf(shapeName, shape.path, r) : null;
    if (turnAt != null) {
      liveRing = turnAt(spinAmt!);
      turned = true;
    }
    var faceTop = shape.top;
    var faceBottom = shape.bottom;
    if (morphing || turned) {
      faceTop = double.infinity;
      faceBottom = double.negativeInfinity;
      for (final p in liveRing) {
        if (p.dy < faceTop) faceTop = p.dy;
        if (p.dy > faceBottom) faceBottom = p.dy;
      }
    }
    Path bodyD;
    if (jc >= 1) {
      bodyD =
          isPencil ? closedSpline(overlayRing(ovKind, r, tear)) : fx.circlePath;
    } else if (jc <= 0 && !morphing && !turned) {
      bodyD = parseSvgPath(shape.path);
    } else {
      final to = overlayRing(ovKind ?? ovPrev, r, tear);
      bodyD = closedSpline(jc <= 0 ? liveRing : lerpRing(liveRing, to, k2(jc)));
    }

    fx.paint(fxFrame, now, stateAt, ovKind, ovPrev, yl, mix, r,
        reduce: reduceMotion);

    final shrink = 1 - dke(clampN((pxW - 44) / 90, 0, 1));
    final pScale = poseScaleVal;
    final zCur = t.overlayViewZoomOf(ovKind, pScale);
    final zPrev = t.overlayViewZoomOf(ovPrev, pScale);
    final zoom = 1 + (zCur * mix + zPrev * (1 - mix) - 1) * yl * shrink;

    final morphT = clampN(eyeMorph.x, 0, 1);
    final polys = _currentPolys(morphT);
    final cr = eyeTopology
        ? relRot(rot3(poseTurn, poseTilt, poseRoll),
            rot3(homeTurn, homeTilt, homeRoll))
        : null;
    final overlayLive =
        yl > 0.001 || (overlayTurn.t - overlayTurn.x).abs() > 0.01;
    double? cyl = overlayLive ? overlayTurn.x : null;
    if (ex.turn != null) cyl = (cyl ?? 0) + ex.turn!;
    final ringHint = morphing || turned ? liveRing : null;
    final hasPtr =
        gazeTargetRel != null || (followPointer && pointerRel != null);
    final eyesResult = computeEyes(EyesInput(
      now: now,
      polys: polys,
      morphT: morphT,
      shape: shape,
      face: face,
      faceTune: faceTune,
      uniformEyes: uniformEyes,
      eyeScaleProp: eyeScaleProp,
      blinkX: blink.x,
      gazeX: gazeX.x,
      gazeY: gazeY.x,
      winkAt: winkAt,
      winkEye: winkEye,
      turn: cyl,
      cr: cr,
      pointer: hasPtr ? Offset(_pointerX, _pointerY) : null,
      notifyX: notify.x,
      overlayX: overlay.x,
      eyeBoostX: eyeScale.x,
      re: r,
      g9e: GrokGeometry.g9e,
      vjt: GrokGeometry.vjt,
      extras: extras,
      ringHint: ringHint,
      badgeRing: restRing,
      top: faceTop,
      bottom: faceBottom,
      emphasisBlend: emphasisBlend,
    ));

    final hum = clampN(humDots.x, 0, 1);
    if (hum > 0.01) {
      for (int i = 0; i < 2; i++) {
        final gn = ovSpin * 0.85 + i * math.pi;
        final ti = shape.radius * 1.3;
        final ui = math.cos(gn);
        final si = 0.55 + 0.45 * clampN((ui + 1) / 2, 0, 1);
        fxFrame.parts.add(FxCircleDraw(
          cx: r + ti * math.sin(gn),
          cy: r - ti * 0.38 * math.cos(gn) - 8,
          r: 7.5 * si * hum,
          opacity: (0.3 + 0.7 * si) * hum,
        ));
      }
    }

    frame = GrokFrame(
      tx: tx,
      ty: ty,
      rotDeg: rot,
      sx: sx,
      sy: sy,
      groupOpacity: groupOpacity,
      poseScale: pScale,
      zoom: zoom,
      bodyPath: bodyD,
      eyes: eyesResult,
      fx: fxFrame,
    );
  }

  /// 供 _paint 中粒子更新使用的本帧 dt。
  double _pendingDt = 0;
}
