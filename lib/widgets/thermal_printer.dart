import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 通用热敏打印机组件
///
/// 复刻热敏打印吐纸效果：顶部黑色出纸槽，纸张分 5 步吐出（步进电机节奏），
/// 打印完成后自动回滚展示顶部再滑到底部，之后支持拖拽/滚轮上下查看。
/// 打印内容完全由外部通过 [child] 传入（宽度会被约束为 [paperWidth]）。
class ThermalPrinter extends StatefulWidget {
  /// 要打印的纸张内容（顶部对齐，超出部分随吐纸动画逐步显露）
  final Widget child;

  /// 纸张宽度
  final double paperWidth;

  /// 进入后是否自动开始打印
  final bool autoStart;

  /// 是否显示底部锯齿撕纸边缘
  final bool serratedEdge;

  /// 是否显示右上角「重新打印」按钮
  final bool showReplayButton;

  /// 舞台背景色
  final Color backgroundColor;

  /// 出纸槽颜色
  final Color slotColor;

  /// 纸张颜色
  final Color paperColor;

  const ThermalPrinter({
    super.key,
    required this.child,
    this.paperWidth = 326,
    this.autoStart = true,
    this.serratedEdge = true,
    this.showReplayButton = true,
    this.backgroundColor = const Color(0xFFF3F3F1),
    this.slotColor = const Color(0xFF1A1A1A),
    this.paperColor = Colors.white,
  });

  @override
  State<ThermalPrinter> createState() => ThermalPrinterState();
}

class ThermalPrinterState extends State<ThermalPrinter>
    with SingleTickerProviderStateMixin {
  final GlobalKey _contentKey = GlobalKey();
  late final AnimationController _ctrl;

  // 当前动画插值参数
  double _fromH = 0, _toH = 0, _fromY = 0, _toY = 0;
  Curve _curve = Curves.linear;

  double _clipH = 0;
  double _currentY = 0;
  double _contentH = 0;
  double _viewportH = 0;
  bool _visible = false;
  bool _isPrinting = false;
  double _curlOpacity = 1;
  bool _slotShadow = false;
  int _gen = 0;
  double _dragStartY = 0;
  double _dragLocalStart = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this)..addListener(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measure();
      if (widget.autoStart) replay();
    });
  }

  @override
  void dispose() {
    _gen++;
    _ctrl.dispose();
    super.dispose();
  }

  void _measure() {
    final h = _contentKey.currentContext?.size?.height;
    if (h != null && h > 0) _contentH = h;
  }

  void _onTick() {
    final t = _curve.transform(_ctrl.value);
    setState(() {
      _clipH = _fromH + (_toH - _fromH) * t;
      _currentY = _fromY + (_toY - _fromY) * t;
    });
  }

  Future<void> _animateTo({
    required double fromH,
    required double toH,
    required double fromY,
    required double toY,
    required Duration duration,
    required Curve curve,
  }) {
    _fromH = fromH;
    _toH = toH;
    _fromY = fromY;
    _toY = toY;
    _curve = curve;
    _ctrl.duration = duration;
    return _ctrl.forward(from: 0).orCancel.catchError((_) {});
  }

  /// 重新触发打印序列（公开，供外部通过 GlobalKey 调用）
  Future<void> replay() async {
    final gen = ++_gen;
    bool alive() => mounted && gen == _gen;

    _ctrl.stop();
    _measure();
    setState(() {
      _isPrinting = true;
      _visible = false;
      _clipH = 0;
      _currentY = 0;
      _curlOpacity = 1;
      _slotShadow = false;
    });

    await Future.delayed(const Duration(milliseconds: 420));
    if (!alive()) return;
    setState(() {
      _visible = true;
      _slotShadow = true;
    });

    final maxVisiblePaperH = math.min(_viewportH - 55, 510.0);
    final maxScrollUpY = -math.max(0.0, _contentH - maxVisiblePaperH);

    const steps = [
      (ratio: 0.34, yRatio: 0.0, duration: 680, pause: 160),
      (ratio: 0.61, yRatio: 0.0, duration: 650, pause: 160),
      (ratio: 0.76, yRatio: 0.32, duration: 620, pause: 150),
      (ratio: 0.94, yRatio: 0.85, duration: 640, pause: 140),
      (ratio: 1.00, yRatio: 1.00, duration: 460, pause: 650),
    ];

    double prevH = 0, prevY = 0;
    for (final step in steps) {
      final nextH = _contentH * step.ratio;
      final nextY = maxScrollUpY * step.yRatio;
      await _animateTo(
        fromH: prevH,
        toH: nextH,
        fromY: prevY,
        toY: nextY,
        duration: Duration(milliseconds: step.duration),
        curve: Curves.easeOutCubic,
      );
      if (!alive()) return;
      prevH = nextH;
      prevY = nextY;
      await Future.delayed(Duration(milliseconds: step.pause));
      if (!alive()) return;
    }

    setState(() => _curlOpacity = 0);

    // 回滚到顶部展示内容开头
    await _animateTo(
      fromH: _contentH,
      toH: _contentH,
      fromY: prevY,
      toY: 0,
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeInOutCubic,
    );
    if (!alive()) return;
    await Future.delayed(const Duration(milliseconds: 520));
    if (!alive()) return;

    // 再上滑展示底部完整内容
    await _animateTo(
      fromH: _contentH,
      toH: _contentH,
      fromY: 0,
      toY: maxScrollUpY,
      duration: const Duration(milliseconds: 780),
      curve: Curves.easeInOutCubic,
    );
    if (!alive()) return;
    setState(() => _isPrinting = false);
  }

  double _clampY(double y) {
    final minScroll = -math.max(0.0, _contentH - (_viewportH - 60));
    return y.clamp(minScroll, 18.0);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_isPrinting) return;
    setState(
      () => _currentY =
          _clampY(_dragStartY + d.localPosition.dy - _dragLocalStart),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.only(top: 36),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 纸张视口：从出纸槽开口处向下延伸
                    Positioned(
                      top: 9,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _viewportH = constraints.maxHeight;
                          return ClipRect(
                            child: Listener(
                              onPointerSignal: (e) {
                                if (e is PointerScrollEvent && !_isPrinting) {
                                  setState(
                                    () => _currentY = _clampY(
                                      _currentY - e.scrollDelta.dy * 0.65,
                                    ),
                                  );
                                }
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: (d) {
                                  if (_isPrinting) return;
                                  _dragStartY = _currentY;
                                  _dragLocalStart = d.localPosition.dy;
                                },
                                onVerticalDragUpdate: _onDragUpdate,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: OverflowBox(
                                    alignment: Alignment.topCenter,
                                    minHeight: 0,
                                    maxHeight: double.infinity,
                                    child: Transform.translate(
                                      offset: Offset(0, _currentY),
                                      child: Opacity(
                                        opacity: _visible ? 1 : 0,
                                        child: _buildMover(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // 出纸槽投射在纸张顶部的阴影
                    Positioned(
                      top: 9,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _slotShadow ? 1 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: Container(
                            width: widget.paperWidth,
                            height: 22,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x47000000),
                                  Color(0x1A000000),
                                  Color(0x00000000),
                                ],
                                stops: [0, 0.45, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 顶部黑色出纸槽
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildSlot()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 右上角重播按钮
          if (widget.showReplayButton)
            Positioned(
              top: 16,
              right: 16,
              child: Opacity(
                opacity: 0.6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: replay,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.replay,
                            size: 13,
                            color: Color(0xFF333333),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '重新打印',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 出纸槽：黑色圆角槽口 + 内部凹陷开口
  Widget _buildSlot() {
    return SizedBox(
      width: widget.paperWidth + 30,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: widget.slotColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          // 内部凹陷开口（用背景色遮住纸张上半段）
          Positioned(
            top: 9,
            left: 8,
            right: 8,
            height: 19,
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x47000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 纸张位移容器：裁剪区（动态高度）+ 底部锯齿撕口
  Widget _buildMover() {
    return SizedBox(
      width: widget.paperWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.paperWidth,
            height: _clipH,
            decoration: BoxDecoration(
              color: widget.paperColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                  spreadRadius: -6,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                  spreadRadius: -1,
                ),
              ],
            ),
            foregroundDecoration: const BoxDecoration(
              // 纸张两侧微妙的卷曲暗边
              gradient: LinearGradient(
                colors: [
                  Color(0x05000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x05000000),
                ],
                stops: [0, 0.06, 0.94, 1],
              ),
            ),
            child: ClipRect(
              child: Stack(
                children: [
                  OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: widget.paperWidth,
                    maxWidth: widget.paperWidth,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: KeyedSubtree(
                      key: _contentKey,
                      child: widget.child,
                    ),
                  ),
                  // 打印中底部卷纸光影
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 36,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _curlOpacity,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00000000),
                                Color(0x09000000),
                                Color(0xB3FFFFFF),
                                Color(0x0F000000),
                              ],
                              stops: [0, 0.55, 0.85, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 锯齿撕口
          if (widget.serratedEdge)
            CustomPaint(
              size: Size(widget.paperWidth, 10),
              painter: SerratedEdgePainter(paperColor: widget.paperColor),
            ),
        ],
      ),
    );
  }
}

/// 底部锯齿撕纸边缘（viewBox 326x10，横向拉伸）
class SerratedEdgePainter extends CustomPainter {
  final Color paperColor;

  SerratedEdgePainter({this.paperColor = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(326, 0)
      ..lineTo(326, 2);
    for (double x = 320; x >= 2; x -= 6) {
      path.lineTo(x, x % 12 == 8 ? 9 : 2);
    }
    path
      ..lineTo(0, 6)
      ..close();

    canvas.save();
    canvas.scale(size.width / 326, size.height / 10);
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.5), 6, false);
    canvas.drawPath(path, Paint()..color = paperColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SerratedEdgePainter oldDelegate) =>
      oldDelegate.paperColor != paperColor;
}
