import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 相机背面（大取景器形态）面板的长宽比例样式
enum SwatchFrameRatio {
  /// 原始 294x312
  original(294, 312),

  /// 竖长 9:16（198x352）
  portrait9x16(198, 352),

  /// 横宽 16:9（336x189）
  landscape16x9(336, 189);

  const SwatchFrameRatio(this.backWidth, this.backHeight);

  /// 背面面板宽度（场景坐标）
  final double backWidth;

  /// 背面面板高度（场景坐标）
  final double backHeight;
}

/// "Swatch This" 3D 相机交互动画相框
///
/// 相框固定为 390x780（1:2）样式，内部场景等比居中适配。
/// [ratio] 控制相机翻转到背面时的面板比例样式（原始 / 9:16 / 16:9）。
/// 点击相机/手套播放一段 3D 翻转拍照动画，完成后进入奖励态，
/// 奖励态点击任意处返回初始态。1.6 秒无操作自动播放（可用 [autoPlay] 关闭）。
class SwatchCameraFrame extends StatefulWidget {
  const SwatchCameraFrame({
    super.key,
    this.ratio = SwatchFrameRatio.original,
    this.autoPlay = true,
  });

  final SwatchFrameRatio ratio;
  final bool autoPlay;

  @override
  State<SwatchCameraFrame> createState() => _SwatchCameraFrameState();
}

enum _AnimMode { idle, playing, reward, resetting }

class _SwatchCameraFrameState extends State<SwatchCameraFrame>
    with SingleTickerProviderStateMixin {
  static const double sceneW = 390;
  static const double sceneH = 780;

  late final Ticker _ticker;
  final _CameraState _s = _CameraState();
  _AnimMode _mode = _AnimMode.idle;
  double _animStartMs = 0;
  Duration? _lastTick;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _s.backW = widget.ratio.backWidth;
    _s.backH = widget.ratio.backHeight;
    _ticker = createTicker(_onTick)..start();
    if (widget.autoPlay) {
      _autoPlayTimer = Timer(const Duration(milliseconds: 1600), () {
        if (_mode == _AnimMode.idle) _trigger();
      });
    }
  }

  @override
  void didUpdateWidget(covariant SwatchCameraFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ratio != widget.ratio) {
      _s.backW = widget.ratio.backWidth;
      _s.backH = widget.ratio.backHeight;
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last != null) {
      _s.nowMs += (elapsed - last).inMicroseconds / 1000.0;
    }
    _update();
    if (mounted) setState(() {});
  }

  void _trigger() {
    if (_mode != _AnimMode.idle) return;
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
    _mode = _AnimMode.playing;
    _animStartMs = _s.nowMs;
  }

  void _resetToIdle() {
    if (_mode != _AnimMode.reward && _mode != _AnimMode.playing) return;
    _mode = _AnimMode.resetting;
    _animStartMs = _s.nowMs;
  }

  void _onTapUp(TapUpDetails details) {
    final p = details.localPosition;
    if (_mode == _AnimMode.idle) {
      final camRect =
          Rect.fromCenter(center: Offset(_s.cx, _s.cy), width: 230, height: 210);
      final handRect = Rect.fromCenter(
          center: Offset(_s.handX, _s.handY), width: 100, height: 120);
      if (camRect.contains(p) || handRect.contains(p)) _trigger();
    } else if (_mode == _AnimMode.reward) {
      _resetToIdle();
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _clamp(double v, [double min = 0, double max = 1]) =>
      math.max(min, math.min(max, v));

  static double _easeInOutCubic(double t) {
    if (t < 0.5) return 4 * t * t * t;
    final u = -2 * t + 2;
    return 1 - u * u * u / 2;
  }

  static double _easeOutBack(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    final u = t - 1;
    return 1 + c3 * u * u * u + c1 * u * u;
  }

  static double _easeOutCubic(double t) {
    final u = 1 - t;
    return 1 - u * u * u;
  }

  void _update() {
    final s = _s;
    final now = s.nowMs;

    switch (_mode) {
      case _AnimMode.idle:
        final floatY = math.sin(now * 0.003) * 3;
        s.cx = 195;
        s.cy = 360 + floatY;
        s.morph = 0;
        s.scale = 1;
        s.ry = -22;
        s.rx = 12;
        s.rz = 4.5;
        s.depth = 18;
        s.silverTheme = 0;
        s.screenOn = 0;
        s.shutterPress = 0;

        final handBob = math.sin(now * 0.005) * 5;
        s.handOpacity = 1;
        s.handX = 216 - handBob * 0.4;
        s.handY = 512 + handBob;
        s.handScale = 1;

        s.introOpacity = 1;
        s.backBtnOpacity = 1;
        s.rewardOpacity = 0;
        s.popoutOpacity = 0;

      case _AnimMode.playing:
        final elapsed = (now - _animStartMs) / 1000;

        // 0.00s ~ 0.35s: 手指点击相机，相机按压回弹
        if (elapsed < 0.35) {
          final p = elapsed / 0.35;
          final tapCurve = math.sin(p * math.pi);
          s.handX = _lerp(216, 198, tapCurve);
          s.handY = _lerp(512, 415, tapCurve);
          s.handScale = 1 - tapCurve * 0.12;
          s.scale = 1 -
              math.sin(_clamp((elapsed - 0.08) / 0.25) * math.pi) * 0.08;
        } else {
          final fadeOut = _clamp(1 - (elapsed - 0.35) / 0.25);
          s.handOpacity = fadeOut;
          s.introOpacity = fadeOut;
          s.backBtnOpacity = fadeOut;
        }

        // 0.35s ~ 1.45s: 3D 翻转放大为拟物化背部取景器
        if (elapsed >= 0.35 && elapsed < 1.45) {
          final t = _clamp((elapsed - 0.35) / 1.1);
          final e = _easeInOutCubic(t);

          s.cx = 195;
          s.cy = _lerp(360, 412, e);
          s.morph = e;
          s.scale = 1;
          s.ry = _lerp(-22, 180, e);
          s.rx = _lerp(12, 0, e);
          s.rz = _lerp(4.5, 0, e) - math.sin(t * math.pi) * 11;
          s.depth = _lerp(18, 14, e) + math.sin(t * math.pi) * 14;
          s.screenOn = _clamp((t - 0.72) / 0.28);
        }

        // 1.45s ~ 2.45s: 取景器对焦取色
        if (elapsed >= 1.45 && elapsed < 2.45) {
          s.cx = 195;
          s.cy = 412;
          s.morph = 1;
          s.ry = 180;
          s.rx = 0;
          s.rz = 0;
          s.depth = 14;
          s.screenOn = 1;

          s.reticlePulse =
              1 + math.sin(((elapsed - 1.45) / 1.0) * math.pi * 2) * 0.12;

          if (elapsed > 2.2) {
            s.shutterPress =
                math.sin(_clamp((elapsed - 2.2) / 0.25) * math.pi);
          } else {
            s.shutterPress = 0;
          }
        }

        // 2.45s ~ 3.65s: FLASH! 漫画弹窗与右上角色卡弹出
        if (elapsed >= 2.45 && elapsed < 3.65) {
          final subT = elapsed - 2.45;
          s.screenOn = 1;
          s.shutterPress = 0;

          s.flashOverlayOpacity = _clamp(1 - subT / 0.35) * 0.85;

          final shake =
              subT < 0.22 ? math.sin(subT * 70) * (1 - subT / 0.22) * 2.5 : 0.0;
          s.cx = 195 + shake;

          final comicIn = _easeOutBack(_clamp(subT / 0.26));
          final comicOut = _clamp(1 - (subT - 0.95) / 0.22);
          s.flashComicOpacity = comicOut;
          s.flashComicScale = comicIn * comicOut;

          final cardP = _easeOutBack(_clamp((subT - 0.06) / 0.38));
          final cardOut = _clamp(1 - (subT - 0.96) / 0.22);
          s.popoutX = _lerp(215, 258, cardP);
          s.popoutY = _lerp(300, 198, cardP);
          s.popoutRot = _lerp(-6, 8, cardP);
          s.popoutOpacity = _clamp(subT / 0.15) * cardOut;
          s.popoutScale = cardP * cardOut;
        } else {
          s.flashOverlayOpacity = 0;
          s.flashComicOpacity = 0;
          s.popoutOpacity = 0;
        }

        // 3.65s ~ 4.75s: 屏幕熄灭，翻转回银色小相机并上移
        if (elapsed >= 3.65 && elapsed < 4.75) {
          final t = _clamp((elapsed - 3.65) / 1.1);
          final e = _easeInOutCubic(t);

          s.screenOn = _clamp(1 - t / 0.18);
          s.silverTheme = _clamp((t - 0.4) / 0.2);

          s.cx = 195;
          s.cy = _lerp(412, 246, e);
          s.morph = 1 - e;
          s.scale = _lerp(1, 0.68, e);
          s.ry = _lerp(180, -22, e);
          s.rx = _lerp(0, 12, e);
          s.rz = _lerp(0, 5, e) - math.sin(t * math.pi) * 10;
          s.depth = _lerp(14, 20, e) + math.sin(t * math.pi) * 12;
        }

        // 4.55s+: 奖励元素依次弹性显现
        if (elapsed >= 4.55) {
          final rT = _clamp((elapsed - 4.55) / 0.45);
          final rEase = _easeOutCubic(rT);
          final cardPop = _easeOutBack(_clamp((elapsed - 4.62) / 0.48));

          s.backBtnOpacity = rEase;
          s.rewardOpacity = rEase;
          s.rewardCardY = _lerp(476, 456, rEase);
          s.rewardCardRot = _lerp(-8, -2, cardPop);
          s.rewardCardScale = cardPop;

          if (elapsed >= 5.25) {
            _mode = _AnimMode.reward;
          }
        }

      case _AnimMode.reward:
        final floatY = math.sin(now * 0.003) * 2.5;
        s.cx = 195;
        s.cy = 246 + floatY;
        s.morph = 0;
        s.scale = 0.68;
        s.ry = -22;
        s.rx = 12;
        s.rz = 5;
        s.depth = 20;
        s.silverTheme = 1;

        s.sparkleTRScale = 0.88 + math.sin(now * 0.006) * 0.16;
        s.sparkleBLScale = 0.62 + math.cos(now * 0.005) * 0.14;

      case _AnimMode.resetting:
        final t = _clamp((now - _animStartMs) / 550);
        final e = _easeInOutCubic(t);

        s.cx = 195;
        s.cy = _lerp(246, 360, e);
        s.scale = _lerp(0.68, 1, e);
        s.rz = _lerp(5, 4.5, e);
        s.silverTheme = 1 - e;

        s.rewardOpacity = 1 - e;
        s.introOpacity = e;
        s.handOpacity = e;

        if (t >= 1) {
          _mode = _AnimMode.idle;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: sceneW / sceneH,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fitScale = constraints.maxWidth / sceneW;
          final radius = 42.0 * fitScale;
          final borderRadius = BorderRadius.circular(radius);
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0E8),
              borderRadius: borderRadius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.65),
                width: math.max(1, fitScale),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  offset: Offset(0, 28),
                  blurRadius: 70,
                ),
                BoxShadow(
                  color: Color(0x0F000000),
                  offset: Offset(0, 4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: sceneW,
                  height: sceneH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: _onTapUp,
                    child: CustomPaint(
                      size: const Size(sceneW, sceneH),
                      painter: _SwatchScenePainter(_s),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 相机 3D 与场景 UI 的全部可变状态
class _CameraState {
  double nowMs = 0;

  // 相机背面面板尺寸（由 SwatchFrameRatio 决定）
  double backW = 294;
  double backH = 312;

  // 相机核心 3D 参数
  double cx = 195;
  double cy = 360;
  double morph = 0;
  double scale = 1;
  double ry = -22;
  double rx = 12;
  double rz = 4.5;
  double depth = 18;
  double silverTheme = 0;
  double screenOn = 0;
  double shutterPress = 0;

  // 手套指针
  double handOpacity = 1;
  double handX = 216;
  double handY = 512;
  double handScale = 1;

  // 引导与返回
  double introOpacity = 1;
  double backBtnOpacity = 1;

  // 奖励组
  double rewardOpacity = 0;
  double rewardCardY = 476;
  double rewardCardRot = -8;
  double rewardCardScale = 0;
  double sparkleTRScale = 1;
  double sparkleBLScale = 0.68;

  // 弹出色卡
  double popoutOpacity = 0;
  double popoutX = 260;
  double popoutY = 250;
  double popoutRot = 0;
  double popoutScale = 0;

  // 闪光特效
  double flashOverlayOpacity = 0;
  double flashComicOpacity = 0;
  double flashComicScale = 0;

  // 准星对焦呼吸
  double reticlePulse = 1;
}

class _SwatchScenePainter extends CustomPainter {
  _SwatchScenePainter(this.s);

  final _CameraState s;

  static const double _deg = math.pi / 180;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _SwatchScenePainter oldDelegate) => true;

  Color _a(Color c, double opacity) =>
      c.withValues(alpha: (c.a * opacity).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackButton(canvas);
    _paintIntroText(canvas);
    _paintRewardGroup(canvas);
    _paintPopoutCard(canvas);
    _paintCamera(canvas);
    _paintHand(canvas);
  }

  void _textBaseline(
    Canvas canvas,
    String text,
    double x,
    double baselineY,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final ascent =
        tp.computeLineMetrics().isEmpty ? style.fontSize! * 0.8 : tp.computeLineMetrics().first.ascent;
    tp.paint(canvas, Offset(x - tp.width / 2, baselineY - ascent));
  }

  void _ellipse(Canvas canvas, double cx, double cy, double rx, double ry,
      double rotDeg, Paint paint) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotDeg * _deg);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        paint);
    canvas.restore();
  }

  // ================= 左上角返回按钮 =================
  void _paintBackButton(Canvas canvas) {
    if (s.backBtnOpacity <= 0) return;
    final o = s.backBtnOpacity;
    canvas.save();
    canvas.translate(46, 56);

    // 黄色贴纸折角底座
    canvas.save();
    canvas.rotate(6 * _deg);
    final sticker = Path()
      ..moveTo(-12, -18)
      ..lineTo(19, -21)
      ..lineTo(23, 14)
      ..lineTo(-10, 16)
      ..close();
    canvas.drawPath(sticker, Paint()..color = _a(const Color(0xFFF5DF4D), o));
    canvas.restore();

    // 白色方块按钮
    canvas.save();
    canvas.rotate(-4 * _deg);
    final rect = Rect.fromLTWH(-17, -17, 34, 34);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(7));
    canvas.drawRRect(rr, Paint()..color = _a(Colors.white, o));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _a(const Color(0xFF222222), o)
          ..strokeWidth = 1.2);
    final chevron = Path()
      ..moveTo(3, -6)
      ..lineTo(-4, 0)
      ..lineTo(3, 6);
    canvas.drawPath(
        chevron,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _a(const Color(0xFF1A1A1A), o)
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
    canvas.restore();
  }

  // ================= 顶部引导文案 =================
  void _paintIntroText(Canvas canvas) {
    if (s.introOpacity <= 0) return;
    _textBaseline(
      canvas,
      'Tap on the camera & capture a color',
      195,
      224,
      TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: _a(const Color(0xFF181818), s.introOpacity),
      ),
    );
  }

  // ================= 奖励结果组 =================
  void _paintRewardGroup(Canvas canvas) {
    if (s.rewardOpacity <= 0) return;
    final o = s.rewardOpacity;

    // 提示文字（两行）
    final textColor = _a(const Color(0xFF181818), o);
    _textBaseline(
      canvas,
      'Nice color!',
      195,
      344,
      TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          color: textColor),
    );
    _textBaseline(
      canvas,
      "You've got 51 more colors to catch!",
      195,
      344 + 23,
      TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          color: textColor),
    );

    // 居中获得的拍立得色卡
    if (s.rewardCardScale > 0) {
      canvas.save();
      canvas.translate(195, s.rewardCardY);
      canvas.rotate(s.rewardCardRot * _deg);
      canvas.scale(s.rewardCardScale);

      // 纸张翘起底部阴影
      final curl = Path()
        ..moveTo(-40, 46)
        ..quadraticBezierTo(4, 40, 46, 50)
        ..lineTo(42, 34)
        ..lineTo(-40, 36)
        ..close();
      canvas.drawPath(
          curl,
          Paint()
            ..color = _a(const Color(0x3D000000), o)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5));

      // 色卡主体（带柔和投影）
      final card = Path()
        ..moveTo(-44, -50)
        ..lineTo(44, -50)
        ..lineTo(44, 47)
        ..quadraticBezierTo(12, 44, -44, 48)
        ..close();
      canvas.save();
      canvas.translate(0, 6);
      canvas.drawPath(
          card,
          Paint()
            ..color = _a(const Color(0x24000000), o)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      canvas.restore();
      canvas.drawPath(card, Paint()..color = _a(Colors.white, o));
      canvas.drawPath(
          card,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = _a(const Color(0xFFE5E2DA), o)
            ..strokeWidth = 1);

      // 银色圆形色块与名称
      canvas.drawCircle(
          Offset(0, -9), 26, Paint()..color = _a(const Color(0xFFA6A8AE), o));
      _textBaseline(
        canvas,
        'Silver',
        0,
        34,
        TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: _a(const Color(0xFF2C2D30), o)),
      );

      // 右上角大四角星
      canvas.save();
      canvas.translate(48, -46);
      canvas.scale(s.sparkleTRScale);
      _paintSparkle(canvas, o, withStroke: true);
      canvas.restore();

      // 左下角小四角星
      canvas.save();
      canvas.translate(-52, 48);
      canvas.scale(s.sparkleBLScale);
      _paintSparkle(canvas, o);
      canvas.restore();

      canvas.restore();
    }

    // 底部 Start your adventure 按钮
    canvas.save();
    canvas.translate(195, 712);
    final sticker = Path()
      ..moveTo(-88, -18)
      ..lineTo(98, -24)
      ..lineTo(91, 22)
      ..lineTo(-84, 20)
      ..close();
    canvas.drawPath(sticker, Paint()..color = _a(const Color(0xFFF5DF4D), o));
    final btnRect = Rect.fromLTWH(-92, -21, 184, 42);
    final btnRR = RRect.fromRectAndRadius(btnRect, const Radius.circular(7));
    canvas.save();
    canvas.translate(0, 6);
    canvas.drawRRect(
        btnRR,
        Paint()
          ..color = _a(const Color(0x24000000), o)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.restore();
    canvas.drawRRect(btnRR, Paint()..color = _a(Colors.white, o));
    canvas.drawRRect(
        btnRR,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _a(const Color(0xFFE4E1D8), o)
          ..strokeWidth = 1);
    _textBaseline(
      canvas,
      'Start your adventure',
      0,
      5,
      TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: _a(const Color(0xFF181818), o)),
    );
    canvas.restore();
  }

  Path _sparklePath() => Path()
    ..moveTo(0, -14)
    ..quadraticBezierTo(1, -1, 14, 0)
    ..quadraticBezierTo(1, 1, 0, 14)
    ..quadraticBezierTo(-1, 1, -14, 0)
    ..quadraticBezierTo(-1, -1, 0, -14)
    ..close();

  void _paintSparkle(Canvas canvas, double opacity, {bool withStroke = false}) {
    canvas.drawPath(
        _sparklePath(), Paint()..color = _a(const Color(0xFFF5D442), opacity));
    if (withStroke) {
      final half = Path()
        ..moveTo(0, -14)
        ..quadraticBezierTo(1, -1, 14, 0)
        ..quadraticBezierTo(1, 1, 0, 14);
      canvas.drawPath(
          half,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = _a(const Color(0xFFBCA028), opacity)
            ..strokeWidth = 0.6);
    }
  }

  // ================= 相机右上方弹出的色卡 =================
  void _paintPopoutCard(Canvas canvas) {
    if (s.popoutOpacity <= 0 || s.popoutScale <= 0) return;
    final o = s.popoutOpacity;
    canvas.save();
    canvas.translate(s.popoutX, s.popoutY);
    canvas.rotate(s.popoutRot * _deg);
    canvas.scale(s.popoutScale);

    final rect = Rect.fromLTWH(-39, -45, 78, 90);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.save();
    canvas.translate(0, 6);
    canvas.drawRRect(
        rr,
        Paint()
          ..color = _a(const Color(0x24000000), o)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.restore();
    canvas.drawRRect(rr, Paint()..color = _a(Colors.white, o));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _a(const Color(0xFFE5E2DC), o)
          ..strokeWidth = 1);
    canvas.drawCircle(
        Offset(0, -8), 22, Paint()..color = _a(const Color(0xFFA6A8AE), o));
    _textBaseline(
      canvas,
      'Silver',
      0,
      30,
      TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _a(const Color(0xFF2C2D30), o)),
    );
    canvas.restore();
  }

  // ================= 核心：3D 相机 =================
  void _paintCamera(Canvas canvas) {
    final w = _lerp(144, s.backW, s.morph);
    final h = _lerp(112, s.backH, s.morph);
    final panelR =
        42.0 * math.min(1.0, math.min(s.backW / 294, s.backH / 312));
    final r = _lerp(24, panelR, s.morph);

    final radY = s.ry * _deg;
    final radX = s.rx * _deg;
    final cosY = math.cos(radY);
    final sinY = math.sin(radY);
    final sinX = math.sin(radX);

    final faceScaleX = math.max(0.06, cosY.abs());
    final showingFront = cosY >= 0;

    canvas.save();
    canvas.translate(s.cx, s.cy);
    canvas.scale(s.scale);
    canvas.rotate(s.rz * _deg);

    // 机身柔和投影（近似 SVG feDropShadow）
    final faceZ = showingFront ? s.depth / 2 : -s.depth / 2;
    final shadowW = w * faceScaleX;
    final shadowR = math.min(
        r * faceScaleX + 4, math.min(shadowW / 2, h / 2));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-sinY * faceZ - shadowW / 2,
            sinX * faceZ - h / 2 + 10, shadowW, h),
        Radius.circular(shadowR),
      ),
      Paint()
        ..color = const Color(0x2E000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // 顶部左侧凸起的小快门按钮（仅正面小图标态）
    if (showingFront && s.morph < 0.45) {
      final btnZ = -s.depth * 0.15;
      final btnDx = -sinY * btnZ - w * 0.26 * faceScaleX;
      final btnDy = sinX * btnZ - h * 0.5 - 4.5;
      final btnRect =
          Rect.fromLTWH(btnDx - 11 * faceScaleX, btnDy, 22 * faceScaleX, 8);
      final btnRR = RRect.fromRectAndRadius(btnRect, const Radius.circular(3));
      canvas.drawRRect(btnRR, Paint()..color = const Color(0xFFC4C6CC));
      canvas.drawRRect(
          btnRR,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFF18181B)
            ..strokeWidth = 1.2);
    }

    // 22 层 3D 侧边挤压切片
    const sliceCount = 22;
    final sliceW = w * faceScaleX;
    final sliceR =
        math.min(r * faceScaleX + 4, math.min(sliceW / 2, h / 2));
    const metalGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFDCDEE3),
        Color(0xFFB4B6BD),
        Color(0xFF7C7E85),
        Color(0xFF484A50),
      ],
      stops: [0, 0.28, 0.65, 1],
    );
    for (var i = 0; i < sliceCount; i++) {
      final ratio = i / (sliceCount - 1);
      final z = showingFront
          ? _lerp(-s.depth / 2, s.depth / 2, ratio)
          : _lerp(s.depth / 2, -s.depth / 2, ratio);
      final dx = -sinY * z;
      final dy = sinX * z;
      final rect =
          Rect.fromLTWH(dx - sliceW / 2, dy - h / 2, sliceW, h);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(sliceR));
      canvas.drawRRect(rr, Paint()..shader = metalGrad.createShader(rect));
      final border = Paint()..style = PaintingStyle.stroke;
      if (i == 0 || i == sliceCount - 1) {
        border.color = const Color(0xFF18181B);
        border.strokeWidth = 1.4;
      } else {
        border.color = const Color(0xFF8C8E95);
        border.strokeWidth = 0.5;
      }
      canvas.drawRRect(rr, border);
    }

    if (showingFront) {
      _paintCameraFront(canvas, w, h, faceScaleX, sinY, sinX);
    } else {
      _paintCameraBack(canvas, w, h, faceScaleX, sinY, sinX);
    }

    canvas.restore();
  }

  void _paintCameraFront(Canvas canvas, double w, double h, double faceScaleX,
      double sinY, double sinX) {
    final frontZ = s.depth / 2;
    canvas.save();
    canvas.translate(-sinY * frontZ, sinX * frontZ);
    canvas.scale((w / 144) * faceScaleX, h / 112);

    // 正面圆角机身
    final bodyRect = Rect.fromLTWH(-72, -56, 144, 112);
    final bodyRR = RRect.fromRectAndRadius(bodyRect, const Radius.circular(24));
    final bodyPaint = Paint();
    if (s.silverTheme > 0.5) {
      bodyPaint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9A9CA3), Color(0xFF83858C), Color(0xFF6C6E75)],
        stops: [0, 0.5, 1],
      ).createShader(bodyRect);
    } else {
      bodyPaint.color = const Color(0xFF1B1B1E);
    }
    canvas.drawRRect(bodyRR, bodyPaint);
    canvas.drawRRect(
        bodyRR,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF111113)
          ..strokeWidth = 1.5);

    // 左上角闪光灯椭圆
    _ellipse(canvas, -39, -28, 6.5, 9, -14, Paint()..color = Colors.white);

    // 同心圆镜头
    canvas.save();
    canvas.translate(2, 4);
    const lensOuterRect = Rect.fromLTWH(-37, -37, 74, 74);
    canvas.drawCircle(
        Offset.zero,
        37,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0E1E5), Color(0xFFC2C4C9), Color(0xFF989A9F)],
            stops: [0, 0.5, 1],
          ).createShader(lensOuterRect));
    canvas.drawCircle(
        Offset.zero,
        37,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF141416)
          ..strokeWidth = 2);
    canvas.drawCircle(Offset.zero, 26, Paint()..color = const Color(0xFF8D8F95));
    canvas.drawCircle(
        Offset.zero, 15.5, Paint()..color = const Color(0xFF18181B));
    canvas.drawCircle(const Offset(-5, -5), 3.2,
        Paint()..color = Colors.white.withValues(alpha: 0.45));
    canvas.restore();

    canvas.restore();
  }

  void _paintCameraBack(Canvas canvas, double w, double h, double faceScaleX,
      double sinY, double sinX) {
    final backZ = -s.depth / 2;
    canvas.save();
    canvas.translate(-sinY * backZ, sinX * backZ);
    canvas.scale((w / s.backW) * faceScaleX, h / s.backH);

    // 背面面板按 backW x backH 真实布局，sx/sy 为相对原始 294x312 的比例
    final bw = s.backW;
    final bh = s.backH;
    final sx = bw / 294;
    final sy = bh / 312;
    final uni = math.min(sx, sy);

    // 背面机身外框与高光金属倒角
    final panelR = 42.0 * math.min(1.0, uni);
    final bodyRect = Rect.fromCenter(center: Offset.zero, width: bw, height: bh);
    final bodyRR =
        RRect.fromRectAndRadius(bodyRect, Radius.circular(panelR));
    canvas.drawRRect(bodyRR, Paint()..color = const Color(0xFF0D0D10));
    const bezelGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFFFFF),
        Color(0xFFD0D2D8),
        Color(0xFF64666D),
        Color(0xFF2C2D30),
        Color(0xFF8E9097),
      ],
      stops: [0, 0.22, 0.55, 0.85, 1],
    );
    canvas.drawRRect(
        bodyRR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..shader = bezelGrad.createShader(bodyRect));

    // 左上角流光高光弧线（跟随面板边缘）
    canvas.save();
    canvas.translate(-bw / 2 + 3, -bh / 2 + 2);
    canvas.scale(sx, sy);
    final rim = Path()
      ..moveTo(0, 49)
      ..lineTo(0, 38)
      ..arcToPoint(const Offset(40, 0),
          radius: const Radius.circular(40), clockwise: true)
      ..lineTo(239, 0);
    canvas.drawPath(
        rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white.withValues(alpha: 0.7)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
    canvas.restore();

    // 取景器视窗（保持与面板的相对边距：左右 16、顶部 18、底部 86 控制区）
    final screenW = bw - 32 * sx;
    final screenH = bh - 104 * sy;
    final clipRect =
        Rect.fromLTWH(-bw / 2 + 16 * sx, -bh / 2 + 18 * sy, screenW, screenH);
    final screenR = 30.0 * math.min(1.0, uni);
    final screenCenter = clipRect.center;
    final contentSx = screenW / 262;
    final contentSy = screenH / 208;
    final contentUni = math.min(contentSx, contentSy);
    final blackRect = Rect.fromLTRB(clipRect.left - 9, clipRect.top - 12,
        clipRect.right + 9, clipRect.bottom + 10);

    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(clipRect, Radius.circular(screenR)));

    // 屏幕黑底
    canvas.drawRect(blackRect, Paint()..color = const Color(0xFF070709));

    // 取景器实时散景画面
    if (s.screenOn > 0) {
      canvas.saveLayer(
        clipRect.inflate(60),
        Paint()..color = Colors.white.withValues(alpha: s.screenOn),
      );

      // 散景（整组高斯模糊，随屏幕比例拉伸铺满）
      final driftX =
          s.screenOn > 0.01 ? math.sin(s.nowMs * 0.0022) * 8 : 0.0;
      final driftY =
          s.screenOn > 0.01 ? math.cos(s.nowMs * 0.0018) * 6 : 0.0;
      canvas.save();
      canvas.translate(screenCenter.dx, screenCenter.dy);
      canvas.scale(contentSx, contentSy);
      canvas.translate(0, 34);
      canvas.saveLayer(
        Rect.fromLTWH(-220, -230, 440, 350),
        Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      );
      canvas.translate(driftX, driftY);
      canvas.drawRect(Rect.fromLTWH(-150, -160, 300, 240),
          Paint()..color = const Color(0xFF8C8881));
      _ellipse(canvas, -45, -75, 95, 50, -25,
          Paint()..color = const Color(0xFFE8CBA1));
      _ellipse(canvas, 65, -25, 90, 60, 20,
          Paint()..color = const Color(0xFFD9B88C));
      _ellipse(canvas, -60, 25, 85, 55, 15,
          Paint()..color = const Color(0xFF5C6873));
      _ellipse(canvas, 25, -85, 70, 45, -35,
          Paint()..color = const Color(0xFF626F7A));
      final stripe1 = Path()
        ..moveTo(-140, -130)
        ..lineTo(40, -20)
        ..lineTo(10, 10)
        ..lineTo(-140, -90)
        ..close();
      canvas.drawPath(stripe1,
          Paint()..color = const Color(0xFFF3DEC0).withValues(alpha: 0.65));
      final stripe2 = Path()
        ..moveTo(-20, -150)
        ..lineTo(130, -10)
        ..lineTo(95, 25)
        ..lineTo(-50, -120)
        ..close();
      canvas.drawPath(stripe2,
          Paint()..color = const Color(0xFF464D57).withValues(alpha: 0.55));
      canvas.drawCircle(const Offset(0, -34), 46,
          Paint()..color = const Color(0xFFB4B6BD).withValues(alpha: 0.65));
      canvas.restore(); // 应用模糊
      canvas.restore();

      // 屏幕内边缘暗角
      final vigRect = clipRect.inflate(4);
      canvas.drawRect(
          vigRect,
          Paint()
            ..shader = RadialGradient(
              radius: 0.65,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.55),
              ],
              stops: const [0.55, 1],
            ).createShader(vigRect));

      // 中心取景十字准星框（均匀缩放保持形状）
      canvas.save();
      canvas.translate(screenCenter.dx, screenCenter.dy);
      canvas.scale(contentUni * s.reticlePulse);
      final reticlePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final brackets = Path()
        ..moveTo(-13, -6)
        ..lineTo(-13, -13)
        ..lineTo(-6, -13)
        ..moveTo(6, -13)
        ..lineTo(13, -13)
        ..lineTo(13, -6)
        ..moveTo(-13, 6)
        ..lineTo(-13, 13)
        ..lineTo(-6, 13)
        ..moveTo(6, 13)
        ..lineTo(13, 13)
        ..lineTo(13, 6);
      canvas.drawPath(brackets, reticlePaint);
      final crossPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-3.5, 0), const Offset(3.5, 0), crossPaint);
      canvas.drawLine(const Offset(0, -3.5), const Offset(0, 3.5), crossPaint);
      canvas.restore();

      // 底部颜色识别胶囊标签（均匀缩放保持形状）
      canvas.save();
      canvas.translate(screenCenter.dx, screenCenter.dy + 84 * contentSy);
      canvas.scale(contentUni);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-36, -12, 72, 24), const Radius.circular(12)),
          Paint()..color = const Color(0xFF18181C).withValues(alpha: 0.76));
      canvas.drawCircle(
          const Offset(-19, 0), 6, Paint()..color = const Color(0xFFB5B7BD));
      canvas.drawCircle(
          const Offset(-19, 0),
          6,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = Colors.white.withValues(alpha: 0.5)
            ..strokeWidth = 0.8);
      _textBaseline(
        canvas,
        'Silver',
        6,
        4,
        const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: Colors.white),
      );
      canvas.restore();

      canvas.restore(); // screenOn 层
    }

    // 拍照瞬间闪光白幕
    if (s.flashOverlayOpacity > 0) {
      canvas.drawRect(blackRect,
          Paint()..color = Colors.white.withValues(alpha: s.flashOverlayOpacity));
    }

    // 漫画风 FLASH! 弹窗特效
    if (s.flashComicOpacity > 0 && s.flashComicScale > 0) {
      final o = s.flashComicOpacity;
      canvas.save();
      canvas.translate(screenCenter.dx, screenCenter.dy - 42 * contentSy);
      canvas.scale(s.flashComicScale * contentUni);

      final burstPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = _a(Colors.black, o)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-112, -28), const Offset(-98, -20), burstPaint);
      canvas.drawLine(const Offset(-116, 4), const Offset(-100, 4), burstPaint);
      canvas.drawLine(const Offset(102, -26), const Offset(116, -32), burstPaint);
      canvas.drawLine(const Offset(104, 12), const Offset(118, 18), burstPaint);

      canvas.save();
      canvas.rotate(-3 * _deg);
      const flashStyle = TextStyle(
        fontSize: 52,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: 2,
        height: 1.0,
      );
      // 蓝色偏移层（黑色描边）
      _textBaseline(
        canvas,
        'FLASH!',
        4,
        17,
        flashStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10
            ..strokeJoin = StrokeJoin.round
            ..color = _a(Colors.black, o),
        ),
      );
      _textBaseline(canvas, 'FLASH!', 4, 17,
          flashStyle.copyWith(color: _a(const Color(0xFF38B6FF), o)));
      // 白色主字层（黑色描边先画）
      _textBaseline(
        canvas,
        'FLASH!',
        0,
        14,
        flashStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeJoin = StrokeJoin.round
            ..color = _a(const Color(0xFF111111), o),
        ),
      );
      _textBaseline(
          canvas, 'FLASH!', 0, 14, flashStyle.copyWith(color: _a(Colors.white, o)));
      canvas.restore();

      canvas.restore();
    }

    // 取景器内边框描边
    canvas.drawRRect(
        RRect.fromRectAndRadius(clipRect, Radius.circular(screenR)),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF2C2D32)
          ..strokeWidth = 2);

    canvas.restore(); // 视窗裁剪

    // 底部操控区（随面板剩余空间整体缩放并居中）
    final controlsScale = math.min(1.0, uni);
    _paintBackControls(canvas, bh / 2 - 48 * sy, controlsScale);

    canvas.restore();
  }

  // ================= 背面底部操控区 =================
  void _paintBackControls(Canvas canvas, double centerY, double groupScale) {
    canvas.save();
    canvas.translate(0, centerY);
    canvas.scale(groupScale);

    // 左侧猫咪图标
    canvas.save();
    canvas.translate(-88, 0);
    final leftEar = Path()
      ..moveTo(-22, -8)
      ..lineTo(-19, -25)
      ..lineTo(-6, -14)
      ..close();
    canvas.drawPath(leftEar, Paint()..color = Colors.white);
    final rightEar = Path()
      ..moveTo(6, -14)
      ..lineTo(19, -25)
      ..lineTo(22, -8)
      ..close();
    canvas.drawPath(rightEar, Paint()..color = const Color(0xFF45474D));
    canvas.drawPath(
        rightEar,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF8C8E94)
          ..strokeWidth = 1);
    _ellipse(canvas, -11, 2, 4.5, 2.4, 18, Paint()..color = Colors.white);
    _ellipse(canvas, 11, 2, 4.5, 2.4, -18, Paint()..color = Colors.white);
    final nose = Path()
      ..moveTo(-2.5, 8)
      ..lineTo(2.5, 8)
      ..lineTo(0, 11)
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFF7C7E85));
    final whiskerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF686A70)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-24, 7), const Offset(-15, 8.5), whiskerPaint);
    canvas.drawLine(const Offset(-25, 11.5), const Offset(-15, 11.5), whiskerPaint);
    canvas.drawLine(const Offset(-23, 16), const Offset(-15, 14.5), whiskerPaint);
    canvas.drawLine(const Offset(24, 7), const Offset(15, 8.5), whiskerPaint);
    canvas.drawLine(const Offset(25, 11.5), const Offset(15, 11.5), whiskerPaint);
    canvas.drawLine(const Offset(23, 16), const Offset(15, 14.5), whiskerPaint);
    canvas.restore();

    // 中间拟物化快门大按钮
    canvas.save();
    canvas.scale(1 - s.shutterPress * 0.12);
    const shutterOuterRect = Rect.fromLTWH(-35, -35, 70, 70);
    canvas.drawCircle(
        Offset.zero,
        35,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAECEE), Color(0xFF92949B)],
          ).createShader(shutterOuterRect));
    canvas.drawCircle(
        Offset.zero,
        35,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF252629)
          ..strokeWidth = 1.5);
    canvas.drawCircle(Offset.zero, 29, Paint()..color = const Color(0xFF82848B));
    const shutterCapRect = Rect.fromLTWH(-27, -27, 54, 54);
    canvas.drawCircle(
        Offset.zero,
        27,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD5D6DA), Color(0xFFB2B4BA)],
          ).createShader(shutterCapRect));
    canvas.restore();

    // 右侧 3D 金属滚轮拨盘
    canvas.save();
    canvas.translate(82, 0);
    final slotRect = Rect.fromLTWH(-23, -27, 46, 54);
    final slotRR = RRect.fromRectAndRadius(slotRect, const Radius.circular(10));
    canvas.drawRRect(slotRR, Paint()..color = const Color(0xFF1D1E22));
    canvas.drawRRect(
        slotRR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFD0D2D8),
              Color(0xFF64666D),
              Color(0xFF2C2D30),
              Color(0xFF8E9097),
            ],
            stops: [0, 0.22, 0.55, 0.85, 1],
          ).createShader(slotRect));
    final rollerRect = Rect.fromLTWH(-17, -22, 34, 44);
    final rollerRR = RRect.fromRectAndRadius(rollerRect, const Radius.circular(6));
    canvas.drawRRect(
        rollerRR,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF45474C),
              Color(0xFFA8AAAF),
              Color(0xFFF3F4F7),
              Color(0xFFC6C8CE),
              Color(0xFF6E7076),
              Color(0xFF34353A),
            ],
            stops: [0, 0.18, 0.42, 0.62, 0.86, 1],
          ).createShader(rollerRect));
    canvas.drawRRect(
        rollerRR,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF111113)
          ..strokeWidth = 1);
    final ridgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF5A5C63).withValues(alpha: 0.65)
      ..strokeWidth = 1.1;
    for (final y in [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]) {
      canvas.drawLine(Offset(-15, y), Offset(15, y), ridgePaint);
    }
    canvas.restore();

    canvas.restore();
  }

  // ================= 卡通手套点击指针 =================
  void _paintHand(Canvas canvas) {
    if (s.handOpacity <= 0) return;
    final o = s.handOpacity;
    canvas.save();
    canvas.translate(s.handX, s.handY);
    canvas.scale(s.handScale);

    final glove = Path()
      ..moveTo(-8, -28)
      ..cubicTo(-8, -34, 1, -34, 1, -28)
      ..lineTo(1, -8)
      ..cubicTo(4, -11, 11, -10, 12, -5)
      ..cubicTo(16, -7, 22, -5, 22, 1)
      ..cubicTo(26, 0, 30, 4, 29, 10)
      ..lineTo(27, 21)
      ..cubicTo(25, 31, 16, 37, 4, 37)
      ..cubicTo(-7, 37, -14, 31, -18, 22)
      ..lineTo(-25, 10)
      ..cubicTo(-29, 4, -23, -3, -17, 2)
      ..lineTo(-8, 10)
      ..close();
    canvas.drawPath(glove, Paint()..color = _a(Colors.white, o));
    canvas.drawPath(
        glove,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _a(const Color(0xFF181818), o)
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _a(const Color(0xFF181818), o)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(3, 14), const Offset(2, 25), linePaint);
    canvas.drawLine(const Offset(11, 15), const Offset(11, 25), linePaint);

    final cuff = Path()
      ..moveTo(-11, 34)
      ..quadraticBezierTo(4, 39, 18, 34);
    canvas.drawPath(
        cuff,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _a(const Color(0xFF181818), o)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round);
    canvas.restore();
  }
}
