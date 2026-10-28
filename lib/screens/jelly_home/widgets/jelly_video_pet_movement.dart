import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';

/// 视频播放器与移动舞台之间的动作和交互回调。
class JellyVideoPetPlayback {
  const JellyVideoPetPlayback({
    required this.animationId,
    required this.loop,
    required this.onComplete,
    required this.onBusyChanged,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });
  final String? animationId;
  final bool loop;
  final VoidCallback onComplete;
  final ValueChanged<bool> onBusyChanged;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;
}

class JellyVideoPetStage extends StatefulWidget {
  const JellyVideoPetStage({
    super.key,
    required this.modelId,
    required this.movement,
    required this.enabled,
    required this.petSize,
    required this.builder,
    this.topInset = 0,
    this.bottomInset = 0,
    this.initialBottomGap = 0,
    this.active = true,
    this.random,
  });

  final String modelId;
  final VideoPetMovement movement;
  final ValueNotifier<bool> enabled;
  final Size petSize;
  final Widget Function(BuildContext, JellyVideoPetPlayback) builder;
  final double topInset;
  final double bottomInset;
  final double initialBottomGap;
  final bool active;
  final math.Random? random;

  static String preferenceKey(String modelId) =>
      'jelly_video_pet.${Uri.encodeComponent(modelId)}';

  @override
  State<JellyVideoPetStage> createState() => _JellyVideoPetStageState();
}

class _JellyVideoPetStageState extends State<JellyVideoPetStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_tick);
  late final math.Random _random = widget.random ?? math.Random();
  Timer? _wait;
  SharedPreferences? _prefs;
  Offset? _normalized;
  Offset _position = Offset.zero;
  Size _range = Size.zero;
  bool _loaded = false;
  bool _dragging = false;
  bool _busy = false;
  bool _foreground = true;
  bool _left = false;
  bool _turning = false;
  bool _walking = false;
  double _target = 0;
  Duration _previous = Duration.zero;
  int _generation = 0;
  int _phase = 0;
  bool _facingLeft = false;

  bool get _canWalk =>
      _loaded &&
      widget.enabled.value &&
      widget.movement.enabled &&
      widget.active &&
      _foreground &&
      !_dragging &&
      !_busy &&
      _range.width > 1;
  String get _key => JellyVideoPetStage.preferenceKey(widget.modelId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    widget.enabled.addListener(_enabledChanged);
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _loaded = false;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || generation != _generation) return;
    _prefs = prefs;
    final x = prefs.getDouble('$_key.x');
    final y = prefs.getDouble('$_key.y');
    _normalized = x != null && y != null && x.isFinite && y.isFinite
        ? Offset(x.clamp(0, 1), y.clamp(0, 1))
        : null;
    widget.enabled.value = prefs.getBool('$_key.walk') ?? false;
    setState(() => _loaded = true);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant JellyVideoPetStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      oldWidget.enabled.removeListener(_enabledChanged);
      widget.enabled.addListener(_enabledChanged);
    }
    if (oldWidget.modelId != widget.modelId) {
      _stop();
      _normalized = null;
      _busy = false;
      _dragging = false;
      _left = false;
      _facingLeft = false;
      unawaited(_load());
    } else if (oldWidget.active != widget.active ||
        oldWidget.movement != widget.movement) {
      _stop();
      _schedule();
    }
  }

  void _enabledChanged() {
    _stop();
    if (_loaded) {
      unawaited(_prefs!.setBool('$_key.walk', widget.enabled.value));
    }
    if (mounted) setState(() {});
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    setState(_stop);
    _schedule();
  }

  void _stop() {
    ++_phase;
    _wait?.cancel();
    _wait = null;
    _ticker.stop();
    _turning = false;
    _walking = false;
  }

  void _schedule() {
    if (!_canWalk || _wait != null || _turning || _walking) return;
    final movement = widget.movement;
    final seconds =
        movement.minIdleSeconds +
        _random.nextDouble() *
            (movement.maxIdleSeconds - movement.minIdleSeconds);
    _wait = Timer(
      Duration(microseconds: math.max(100000, (seconds * 1000000).round())),
      () {
        _wait = null;
        if (!_canWalk) return;
        _target = _random.nextDouble() * _range.width;
        if ((_target - _position.dx).abs() < 1) {
          _schedule();
          return;
        }
        final left = _target < _position.dx;
        final turn = left
            ? movement.turnLeftAnimationId
            : movement.turnRightAnimationId;
        setState(() {
          ++_phase;
          _turning = left != _facingLeft && turn.isNotEmpty;
          _left = left;
          if (!_turning) _startWalking();
        });
      },
    );
  }

  void _startWalking() {
    if (!_canWalk) return;
    _facingLeft = _left;
    _turning = false;
    _walking = true;
    _previous = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final seconds = (elapsed - _previous).inMicroseconds / 1000000;
    _previous = elapsed;
    if (!_canWalk) {
      setState(_stop);
      return;
    }
    final distance = widget.movement.speed * seconds;
    final remaining = _target - _position.dx;
    setState(() {
      final x = remaining.abs() <= distance
          ? _target
          : _position.dx + (remaining.isNegative ? -distance : distance);
      _position = Offset(x.clamp(0, _range.width), _position.dy);
      _rememberPosition();
      if (remaining.abs() <= distance || x <= 0 || x >= _range.width) _stop();
    });
    _schedule();
  }

  void _rememberPosition() {
    _normalized = Offset(
      _range.width > 0 ? _position.dx / _range.width : (_normalized?.dx ?? 0.5),
      _range.height > 0 ? _position.dy / _range.height : (_normalized?.dy ?? 1),
    );
  }

  void _dragStart(DragStartDetails details) {
    if (!_loaded) return;
    setState(() {
      _stop();
      _dragging = true;
    });
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final mirror =
        _left &&
        widget.movement.leftAnimationId == widget.movement.rightAnimationId;
    setState(() {
      _position = Offset(
        (_position.dx + details.delta.dx * (mirror ? -1 : 1)).clamp(
          0,
          _range.width,
        ),
        (_position.dy + details.delta.dy).clamp(0, _range.height),
      );
      _rememberPosition();
    });
  }

  void _dragEnd() {
    if (!_dragging) return;
    _dragging = false;
    _rememberPosition();
    final position = _normalized!;
    final key = _key;
    final prefs = _prefs;
    if (prefs != null) {
      unawaited(prefs.setDouble('$key.x', position.dx));
      unawaited(prefs.setDouble('$key.y', position.dy));
    }
    _schedule();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final availableHeight = math.max(
        0.0,
        constraints.maxHeight - widget.topInset - widget.bottomInset,
      );
      final scale = math.min(
        1.0,
        math.min(
          widget.petSize.width > 0
              ? constraints.maxWidth / widget.petSize.width
              : 1.0,
          widget.petSize.height > 0
              ? availableHeight / widget.petSize.height
              : 1.0,
        ),
      );
      final size = Size(
        widget.petSize.width * scale,
        widget.petSize.height * scale,
      );
      final range = Size(
        math.max(0, constraints.maxWidth - size.width),
        math.max(0, availableHeight - size.height),
      );
      if (_range != range) {
        _stop();
        _range = range;
      }
      _position = _normalized == null
          ? Offset(
              range.width / 2,
              (range.height - widget.initialBottomGap).clamp(0, range.height),
            )
          : Offset(
              _normalized!.dx * range.width,
              _normalized!.dy * range.height,
            );
      _schedule();
      final movement = widget.movement;
      final animation = _turning
          ? (_left
                ? movement.turnLeftAnimationId
                : movement.turnRightAnimationId)
          : _walking
          ? (_left ? movement.leftAnimationId : movement.rightAnimationId)
          : null;
      final phase = _phase;
      return Stack(
        children: [
          Positioned(
            left: _position.dx,
            top: widget.topInset + _position.dy,
            width: size.width,
            height: size.height,
            child: Transform.flip(
              flipX:
                  _left &&
                  movement.leftAnimationId == movement.rightAnimationId,
              child: widget.builder(
                context,
                JellyVideoPetPlayback(
                  animationId: animation,
                  loop: !_turning,
                  onComplete: () {
                    if (mounted && phase == _phase && _turning && _canWalk) {
                      setState(_startWalking);
                    }
                  },
                  onBusyChanged: (busy) {
                    if (_busy == busy || !mounted) return;
                    setState(() {
                      _busy = busy;
                      _stop();
                    });
                    _schedule();
                  },
                  onDragStart: _dragStart,
                  onDragUpdate: _dragUpdate,
                  onDragEnd: (_) => _dragEnd(),
                  onDragCancel: _dragEnd,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  @override
  void dispose() {
    ++_generation;
    widget.enabled.removeListener(_enabledChanged);
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _ticker.dispose();
    super.dispose();
  }
}
