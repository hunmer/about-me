import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 伪3D翻转卡片工作模式
enum Pseudo3DMode {
  /// 指针跟随倾斜 + 点击翻转
  interactive,

  /// 360° 持续立体旋转
  spin360,

  /// 悬浮摇摆展示
  wobble,
}

/// 图片伪3D翻转卡片
///
/// 将单张 2D 图片沿 Z 轴堆叠多层切片（Extrusion Layers），
/// 配合透视变换、动态流光高光与底部投影，模拟真实徽章的立体翻转质感。
///
/// 交互：
/// - 指针移动（鼠标悬停 / 触摸拖动）跟随倾斜
/// - 指针离开后平滑复位
/// - 点击卡片进行 180° 弹性翻转
///
/// 外部可通过 [GlobalKey<Pseudo3DFlipCardState>] 调用
/// [Pseudo3DFlipCardState.flipY] / [Pseudo3DFlipCardState.flipX] /
/// [Pseudo3DFlipCardState.resetPose]。
class Pseudo3DFlipCard extends StatefulWidget {
  const Pseudo3DFlipCard({
    super.key,
    required this.image,
    this.width = 280,
    this.height = 300,
    this.thickness = 16,
    this.maxTilt = 32,
    this.perspective = 900,
    this.glareEnabled = true,
    this.embossBack = true,
    this.mode = Pseudo3DMode.interactive,
    this.onPoseChanged,
    this.onRequestInteractiveMode,
  });

  /// 展示图片（建议使用透明背景 PNG/WebP）
  final ImageProvider image;

  /// 卡片尺寸
  final double width;
  final double height;

  /// 立体边缘厚度（Z 轴堆叠层数，px）
  final int thickness;

  /// 指针跟随最大倾角（度）
  final double maxTilt;

  /// 3D 透视景深（px），越小广角畸变越强烈
  final double perspective;

  /// 是否显示动态流光高光
  final bool glareEnabled;

  /// 背面是否应用浮雕暗纹滤镜
  final bool embossBack;

  /// 当前工作模式
  final Pseudo3DMode mode;

  /// 姿态变化回调（X 轴角度, Y 轴角度）
  final void Function(double rotX, double rotY)? onPoseChanged;

  /// 自动播放模式（spin360 / wobble）下点击卡片时回调，
  /// 外部可借此切换回 [Pseudo3DMode.interactive]。
  final VoidCallback? onRequestInteractiveMode;

  @override
  State<Pseudo3DFlipCard> createState() => Pseudo3DFlipCardState();
}

class Pseudo3DFlipCardState extends State<Pseudo3DFlipCard>
    with TickerProviderStateMixin {
  static const _flipDuration = Duration(milliseconds: 650);
  static const _flipCurve = Cubic(0.22, 1, 0.36, 1);

  /// 点击触发的 180° 累加翻转角（目标值）
  double _flipX = 0;
  double _flipY = 0;

  /// 翻转动画起始快照
  double _fromFlipX = 0;
  double _fromFlipY = 0;

  /// 指针实时倾角（目标值，立即生效）
  double _tiltX = 0;
  double _tiltY = 0;

  /// 倾斜复位动画起始快照
  double _fromTiltX = 0;
  double _fromTiltY = 0;

  /// 流光高光位置（百分比 0~100）
  double _glareX = 50;
  double _glareY = 30;

  late final AnimationController _flipAnim = AnimationController(
    vsync: this,
    duration: _flipDuration,
    value: 1,
  )..addListener(_onTick);

  late final AnimationController _tiltAnim = AnimationController(
    vsync: this,
    duration: _flipDuration,
    value: 1,
  )..addListener(_onTick);

  late AnimationController _autoAnim;

  @override
  void initState() {
    super.initState();
    _autoAnim = AnimationController(vsync: this, duration: _autoDuration)
      ..addListener(_onTick);
    _syncAutoAnim();
  }

  Duration get _autoDuration =>
      widget.mode == Pseudo3DMode.spin360
          ? const Duration(seconds: 6)
          : const Duration(seconds: 8);

  @override
  void didUpdateWidget(Pseudo3DFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _flipAnim
        ..stop()
        ..value = 1;
      _fromFlipX = _flipX;
      _fromFlipY = _flipY;
      if (widget.mode != Pseudo3DMode.interactive) {
        _tiltX = 0;
        _tiltY = 0;
        _fromTiltX = 0;
        _fromTiltY = 0;
        _tiltAnim
          ..stop()
          ..value = 1;
      }
      _autoAnim.dispose();
      _autoAnim = AnimationController(vsync: this, duration: _autoDuration)
        ..addListener(_onTick);
      _syncAutoAnim();
    }
  }

  void _syncAutoAnim() {
    if (widget.mode == Pseudo3DMode.interactive) {
      _autoAnim.stop();
    } else {
      _autoAnim.repeat();
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _flipAnim.dispose();
    _tiltAnim.dispose();
    _autoAnim.dispose();
    super.dispose();
  }

  /// 水平翻转 180°（累加）
  void flipY() {
    setState(() {
      _fromFlipX = _displayFlipX;
      _fromFlipY = _displayFlipY;
      _flipY += 180;
      _flipAnim.forward(from: 0);
    });
    _notifyPose();
  }

  /// 垂直翻转 180°（累加）
  void flipX() {
    setState(() {
      _fromFlipX = _displayFlipX;
      _fromFlipY = _displayFlipY;
      _flipX += 180;
      _flipAnim.forward(from: 0);
    });
    _notifyPose();
  }

  /// 复位全部姿态角
  void resetPose() {
    setState(() {
      _fromFlipX = _displayFlipX;
      _fromFlipY = _displayFlipY;
      _flipX = 0;
      _flipY = 0;
      _flipAnim.forward(from: 0);
      _fromTiltX = _displayTiltX;
      _fromTiltY = _displayTiltY;
      _tiltX = 0;
      _tiltY = 0;
      _tiltAnim.forward(from: 0);
    });
    _notifyPose();
  }

  double get _displayFlipX =>
      _fromFlipX + (_flipX - _fromFlipX) * _flipCurve.transform(_flipAnim.value);
  double get _displayFlipY =>
      _fromFlipY + (_flipY - _fromFlipY) * _flipCurve.transform(_flipAnim.value);
  double get _displayTiltX =>
      _fromTiltX + (_tiltX - _fromTiltX) * _flipCurve.transform(_tiltAnim.value);
  double get _displayTiltY =>
      _fromTiltY + (_tiltY - _fromTiltY) * _flipCurve.transform(_tiltAnim.value);

  void _notifyPose() {
    widget.onPoseChanged
        ?.call(_displayFlipX + _displayTiltX, _displayFlipY + _displayTiltY);
  }

  void _handlePointer(Offset local, Size stageSize) {
    if (widget.mode != Pseudo3DMode.interactive) return;
    final normX =
        ((local.dx - stageSize.width / 2) / (stageSize.width * 0.42))
            .clamp(-1.0, 1.0);
    final normY =
        ((local.dy - stageSize.height / 2) / (stageSize.height * 0.42))
            .clamp(-1.0, 1.0);
    _tiltAnim.stop();
    setState(() {
      _tiltY = normX * widget.maxTilt;
      _tiltX = -normY * widget.maxTilt;
      _fromTiltX = _tiltX;
      _fromTiltY = _tiltY;
      _tiltAnim.value = 1;
      _glareX = 50 - normX * 40;
      _glareY = 50 - normY * 40;
    });
    _notifyPose();
  }

  void _resetTilt() {
    if (widget.mode != Pseudo3DMode.interactive) return;
    if (_tiltX == 0 && _tiltY == 0) return;
    setState(() {
      _fromTiltX = _displayTiltX;
      _fromTiltY = _displayTiltY;
      _tiltX = 0;
      _tiltY = 0;
      _glareX = 50;
      _glareY = 30;
      _tiltAnim.forward(from: 0);
    });
    _notifyPose();
  }

  void _handleTap() {
    if (widget.mode != Pseudo3DMode.interactive) {
      widget.onRequestInteractiveMode?.call();
    }
    flipY();
  }

  @override
  Widget build(BuildContext context) {
    double rotX;
    double rotY;
    double dy = 0;
    if (widget.mode == Pseudo3DMode.spin360) {
      final t = _autoAnim.value;
      rotY = 360 * t;
      rotX = 8 * math.cos(2 * math.pi * t);
    } else if (widget.mode == Pseudo3DMode.wobble) {
      final t = _autoAnim.value;
      dy = _lerpKeyframes(t, const [0, -10, -4, -12, 0]);
      rotX = _lerpKeyframes(t, const [14, -12, 16, -14, 14]);
      rotY = _lerpKeyframes(t, const [-22, 24, 180, 335, 338]);
    } else {
      rotX = _displayFlipX + _displayTiltX;
      rotY = _displayFlipY + _displayTiltY;
    }

    final rotXRad = rotX * math.pi / 180;
    final rotYRad = rotY * math.pi / 180;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stageSize = Size(constraints.maxWidth, widget.height + 80);
        return MouseRegion(
          onHover: (e) => _handlePointer(e.localPosition, stageSize),
          onExit: (_) => _resetTilt(),
          child: Listener(
            onPointerMove: (e) => _handlePointer(e.localPosition, stageSize),
            onPointerUp: (_) => _resetTilt(),
            onPointerCancel: (_) => _resetTilt(),
            behavior: HitTestBehavior.opaque,
            child: GestureDetector(
              onTap: _handleTap,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: double.infinity,
                height: stageSize.height,
                child: Center(
                  child: _buildCard(rotXRad, rotYRad, dy),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(double rotXRad, double rotYRad, double dy) {
    final half = widget.thickness / 2;
    final slices = <({double z, _SliceKind kind})>[
      for (int i = 1; i < widget.thickness; i++)
        (z: half - i, kind: _SliceKind.edge),
      (z: -half, kind: _SliceKind.back),
      (z: half, kind: _SliceKind.front),
    ];

    // Flutter 不做真实 3D 深度排序，按旋转后的有效 Z 值手动排序绘制
    final depthSign = math.cos(rotXRad) * math.cos(rotYRad);
    slices.sort(
      (a, b) => (a.z * depthSign).compareTo(b.z * depthSign),
    );

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, -1 / widget.perspective)
        ..translate(0.0, dy)
        ..rotateX(rotXRad)
        ..rotateY(rotYRad),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final slice in slices)
              Positioned.fill(child: _buildSlice(slice.z, slice.kind)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlice(double z, _SliceKind kind) {
    Widget image = Image(
      image: widget.image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    final matrix = Matrix4.translationValues(0.0, 0.0, z);
    if (kind == _SliceKind.back) {
      matrix.rotateY(math.pi);
      if (widget.embossBack) {
        image = ColorFiltered(
          colorFilter: const ColorFilter.matrix(_embossMatrix),
          child: image,
        );
      }
    } else if (kind == _SliceKind.edge) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_edgeMatrix),
        child: image,
      );
    }

    if (kind == _SliceKind.front && widget.glareEnabled) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          image,
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: RadialGradient(
                  center: Alignment(_glareX / 50 - 1, _glareY / 50 - 1),
                  radius: 0.9,
                  colors: const [
                    Color(0x8CFFFFFF),
                    Color(0x2EFFFFFF),
                    Color(0x00FFFFFF),
                  ],
                  stops: const [0.0, 0.28, 0.65],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: image,
    );
  }

  /// 分段线性插值（摇摆动画关键帧）
  static double _lerpKeyframes(double t, List<double> frames) {
    final segments = frames.length - 1;
    final pos = (t * segments).clamp(0.0, segments - 1e-9);
    final index = pos.floor();
    final local = pos - index;
    return frames[index] + (frames[index + 1] - frames[index]) * local;
  }

  /// 边缘厚度层滤镜：brightness(0.86) contrast(1.15)
  static const _edgeMatrix = <double>[
    0.989, 0, 0, 0, -16.4,
    0, 0.989, 0, 0, -16.4,
    0, 0, 0.989, 0, -16.4,
    0, 0, 0, 1, 0,
  ];

  /// 背面浮雕滤镜：brightness(0.72) contrast(1.25)
  static const _embossMatrix = <double>[
    0.9, 0, 0, 0, -23,
    0, 0.9, 0, 0, -23,
    0, 0, 0.9, 0, -23,
    0, 0, 0, 1, 0,
  ];
}

enum _SliceKind { edge, back, front }
