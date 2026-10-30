import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_player_state.dart';

/// 视频播放器与移动舞台之间的动作和交互回调。
class JellyVideoPetPlayback {
  const JellyVideoPetPlayback({
    required this.animationId,
    this.dragAnimationId,
    required this.loop,
    required this.frameRequest,
    required this.onComplete,
    required this.onBusyChanged,
    required this.onAnimationFrame,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    this.movementInterrupt = 0,
  });
  final String? animationId;
  final String? dragAnimationId;
  final bool loop;

  /// 走动打断令牌：递增时播放器强制打断当前动画立即切到 movement。
  final int movementInterrupt;

  /// 一次性点播请求（撞墙动画），由舞台发出、播放器消费。
  final ValueListenable<VideoPetManualAnimation?> frameRequest;
  final VoidCallback onComplete;
  final ValueChanged<bool> onBusyChanged;
  final ValueChanged<VideoPetAnimationFrame> onAnimationFrame;
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
    this.animations = const [],
    this.regions = const [],
    this.topInset = 0,
    this.bottomInset = 0,
    this.initialBottomGap = 0,
    this.active = true,
    this.random,
  });

  final String modelId;
  final VideoPetMovement movement;
  final List<VideoPetAnimation> animations;

  /// 人物交互区域：启用区域的联合水平包围盒决定水平活动边界
  /// （人物一边顶到容器边缘即视为到达）；空 = 按整画布计算。
  final List<VideoPetRegion> regions;
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
  State<JellyVideoPetStage> createState() => JellyVideoPetStageState();
}

class JellyVideoPetStageState extends State<JellyVideoPetStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_tick);
  late final math.Random _random = widget.random ?? math.Random();
  Timer? _wait;
  SharedPreferences? _prefs;
  Offset? _normalized;
  Offset _position = Offset.zero;
  Size _range = Size.zero;
  double _minX = 0;
  double get _maxX => _minX + _range.width;
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

  /// 走动打断令牌：递增时通知播放器强制打断当前动画立即切到 movement。
  int _interruptToken = 0;

  /// 撞墙动画等一次性点播请求（nonce 每次递增去重）。
  final ValueNotifier<VideoPetManualAnimation?> _frameRequest =
      ValueNotifier<VideoPetManualAnimation?>(null);
  int _wallBumpNonce = 0;

  String? get _movementAnimationId => _turning
      ? (_left
            ? widget.movement.turnLeftAnimationId
            : widget.movement.turnRightAnimationId)
      : _walking
      ? (_left
            ? widget.movement.leftAnimationId
            : widget.movement.rightAnimationId)
      : null;

  List<VideoPetLocomotion>? get _moving {
    for (final animation in widget.animations) {
      if (animation.id == _movementAnimationId) return animation.moving;
    }
    return null;
  }

  int? _frameGeneration;
  String? _lastFrameReject;

  void _animationFrame(VideoPetAnimationFrame frame, int phase) {
    if (!mounted ||
        phase != _phase ||
        !_walking ||
        _turning ||
        !_canWalk ||
        frame.animationId != _movementAnimationId) {
      final reason = !mounted
          ? 'unmounted'
          : phase != _phase
          ? 'stalePhase($phase/$_phase)'
          : !_walking
          ? 'notWalking'
          : _turning
          ? 'turning'
          : !_canWalk
          ? 'blocked(${_blocked.join(',')})'
          : 'animMismatch(${frame.animationId}/$_movementAnimationId)';
      if (reason != _lastFrameReject) {
        _lastFrameReject = reason;
        _log('frame move REJECTED $reason');
      }
      return;
    }
    final moving = _moving;
    if (moving == null) return;
    if (_frameGeneration != null && frame.generation < _frameGeneration!) {
      return;
    }
    _frameGeneration = frame.generation;
    for (final segment in moving) {
      if (frame.currentFrame >= segment.startFrame &&
          frame.currentFrame <= segment.endFrame) {
        _move(segment.speed);
        return;
      }
    }
  }

  bool get _flipX {
    if (_dragging || _busy) return false;
    final id = _movementAnimationId;
    if (id == null) return false;
    for (final animation in widget.animations) {
      if (animation.id != id || animation.facing.isEmpty) continue;
      return (animation.facing == 'left') != _left;
    }
    return _left &&
        widget.movement.leftAnimationId == widget.movement.rightAnimationId;
  }

  String? _lastStatus;
  void _log(String message) =>
      debugPrint('[VideoPetStage] model=${widget.modelId} $message');

  List<String> get _blocked => [
    if (!_loaded) 'notLoaded',
    if (!widget.enabled.value) 'disabled',
    if (!widget.movement.enabled) 'missingMovement',
    if (!widget.active) 'inactive',
    if (!_foreground) 'background',
    if (_dragging) 'dragging',
    if (_busy) 'busy',
    if (_range.width <= 1) 'noHorizontalSpace',
  ];
  bool get _canWalk => _blocked.isEmpty;

  void _logStatus() {
    final status =
        'enabled=${widget.enabled.value} movement=${widget.movement.enabled} '
        'active=${widget.active} foreground=$_foreground range=$_range '
        'xBounds=[$_minX,$_maxX] '
        'blocked=[${_blocked.join(',')}]';
    if (status == _lastStatus) return;
    _lastStatus = status;
    _log(status);
  }

  String get _key => JellyVideoPetStage.preferenceKey(widget.modelId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = switch (
      WidgetsBinding.instance.lifecycleState) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      _ => false,
    };
    widget.enabled.addListener(_enabledChanged);
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _loaded = false;
    _logStatus();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || generation != _generation) return;
    _prefs = prefs;
    final x = prefs.getDouble('$_key.x');
    final y = prefs.getDouble('$_key.y');
    _normalized = x != null && y != null && x.isFinite && y.isFinite
        ? Offset(x.clamp(0, 1), y.clamp(0, 1))
        : null;
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
      _frameRequest.value = null;
      _wallBumpNonce = 0;
      unawaited(_load());
    } else if (oldWidget.active != widget.active ||
        oldWidget.movement != widget.movement ||
        oldWidget.animations != widget.animations) {
      // 动画/移动配置变化（如编辑器改分段）：播放器会重新 prepare，
      // generation 重新从 0 计数，必须清掉 _frameGeneration 闸门并
      // 复位走动状态，否则新帧全部被旧闸门拒绝、宠物冻结卡死。
      _stop();
      _schedule();
    }
  }

  void _enabledChanged() {
    _stop();
    if (mounted) setState(() {});
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // inactive 仅失焦（窗口仍可见，桌面端点菜单/浮层失焦是常态），
    // 不视为后台；只有 paused/hidden/detached 才停止走动。
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    setState(_stop);
    _schedule();
  }

  void _stop() {
    if (_turning) _log('turn cancelled phase=$_phase');
    if (_walking) {
      _log('walk end phase=$_phase position=$_position target=$_target');
    }
    if (_wait != null) _log('wait cancelled phase=$_phase');
    ++_phase;
    _wait?.cancel();
    _wait = null;
    _ticker.stop();
    _turning = false;
    _walking = false;
    _frameGeneration = null;
  }

  void _schedule() {
    _logStatus();
    if (!_canWalk || _wait != null || _turning || _walking) return;
    final movement = widget.movement;
    final seconds =
        movement.minIdleSeconds +
        _random.nextDouble() *
            (movement.maxIdleSeconds - movement.minIdleSeconds);
    _log('wait seconds=${math.max(0.1, seconds)} phase=$_phase');
    _wait = Timer(
      Duration(microseconds: math.max(100000, (seconds * 1000000).round())),
      () {
        _wait = null;
        _logStatus();
        if (!_canWalk) return;
        _beginWalk();
      },
    );
  }

  /// 立即朝指定方向走到边界并开始（转向 +）行走，跳过空闲等待。
  /// [left] 为 null 时随机选目标；true/false 分别走向左/右边界。
  /// 打断当前一次性/悬停动画（busy），供编辑器「向左/向右走动」按钮调用。
  void walkNow({bool? left}) {
    if (!_loaded ||
        !widget.enabled.value ||
        !widget.movement.enabled ||
        !widget.active ||
        !_foreground ||
        _dragging) {
      _logStatus();
      return;
    }
    // 强制干净重启：清掉可能卡住的 _turning/_walking/_frameGeneration
    // （如播放器重新 prepare 后 generation 重置导致帧被闸门拒绝），
    // 与「切换走动开关」的 _stop 等效，保证按钮每次都能触发。
    // 置 _busy=false 使打断后播放器上报 busy=false 不会再次杀掉走动，
    // 并递增打断令牌让 movement 动画立即替换当前动画。
    setState(() {
      _busy = false;
      _stop();
      ++_interruptToken;
    });
    if (_range.width <= 1) {
      // 无水平空间（人物区域已填满容器）时按钮不再被忽略：
      // 指定方向直接触发撞墙效果，方便测试撞墙动画（无位移）。
      if (left != null) {
        _target = left ? _minX : _maxX;
        _log(
          'target selected x=$_target from=${_position.dx} left=$left xBounds=[$_minX,$_maxX] (wall test, no space)',
        );
        _bumpWall();
      }
      return;
    }
    _beginWalk(left: left);
  }

  /// 外部帧区间点播（编辑器 AB 循环预览等）：直接注入点播请求。
  void playFrameAnimation(VideoPetManualAnimation request) {
    _frameRequest.value = request;
  }

  /// 取消外部点播，恢复正常播放调度。
  void cancelFrameAnimation() {
    _frameRequest.value = null;
  }

  /// 位置复位到舞台中央并清除持久化坐标，然后重新调度走动。
  void resetPosition() {
    final prefs = _prefs;
    if (prefs != null) {
      unawaited(prefs.remove('$_key.x'));
      unawaited(prefs.remove('$_key.y'));
    }
    setState(() {
      _stop();
      _normalized = null;
    });
  }

  void _beginWalk({bool? left}) {
    if (left == null) {
      _target = _minX + _random.nextDouble() * _range.width;
      final minDistance = math.min(80.0, _range.width / 2);
      if ((_target - _position.dx).abs() < minDistance) {
        // Keep this walk opportunity even when randomness picks our position.
        _target = _position.dx - _minX >= _maxX - _position.dx
            ? _minX
            : _maxX;
      }
    } else {
      // 指定方向：直接走到该侧边界（触发撞墙/反向逻辑）。
      _target = left ? _minX : _maxX;
    }
    _log(
      'target selected x=$_target from=${_position.dx} left=$left xBounds=[$_minX,$_maxX]',
    );
    _departToward();
  }

  /// 无撞墙动画时到达边界：转身并反向走回场地内部。
  void _reverseFromWall() {
    final minDistance = math.min(80.0, _range.width / 2);
    final atLeft = (_minX - _target).abs() < 0.5;
    final far = atLeft ? _maxX : _minX;
    final span = (far - _position.dx).abs();
    // 在反方向上取一个足够远的随机点，空间不足则直接走到对侧边界。
    final t = span >= minDistance
        ? (_random.nextDouble() * (1 - minDistance / span) + minDistance / span)
        : 1.0;
    _target = _position.dx + (far - _position.dx) * t;
    _log('wall reverse target=$_target from=${_position.dx}');
    _departToward();
  }

  /// 朝 [_target] 发起走动：按需先请求转身动画，再启动位移。
  void _departToward() {
    final movement = widget.movement;
    // bounds 可能因 regions/容器变化而缩小，目标夹回界内避免永远走不到。
    _target = _target.clamp(_minX, _maxX).toDouble();
    final left = _target < _position.dx;
    final turn = left
        ? movement.turnLeftAnimationId
        : movement.turnRightAnimationId;
    _log(
      'depart left=$left target=$_target from=${_position.dx} facingLeft=$_facingLeft '
      'turn=$turn canWalk=$_canWalk blocked=[${_blocked.join(',')}] phase=$_phase',
    );
    setState(() {
      ++_phase;
      _turning = left != _facingLeft && turn.isNotEmpty;
      _left = left;
      if (_turning) {
        _log('turn request animation=$turn left=$left phase=$_phase');
      }
      if (!_turning) _startWalking();
    });
  }

  void _startWalking() {
    if (!_canWalk) {
      _log('walk REJECTED blocked=[${_blocked.join(',')}]');
      return;
    }
    _facingLeft = _left;
    _turning = false;
    _walking = true;
    _lastFrameReject = null;
    _log(
      'walk start left=$_left from=${_position.dx} target=$_target speed=${widget.movement.speed} '
      'drive=${_moving == null ? 'ticker' : 'frames($_movementAnimationId)'} phase=$_phase',
    );
    _previous = Duration.zero;
    if (_moving == null) _ticker.start();
  }

  void _tick(Duration elapsed) {
    final seconds = (elapsed - _previous).inMicroseconds / 1000000;
    _previous = elapsed;
    if (!_canWalk) {
      _logStatus();
      setState(_stop);
      return;
    }
    if (_moving != null) return;
    _move(widget.movement.speed * seconds);
  }

  void _move(double distance) {
    final remaining = _target - _position.dx;
    final arrived = remaining.abs() <= distance;
    // 到达的目标恰好在左右边界 = 撞墙。
    final atBound =
        (_minX - _target).abs() < 0.5 || (_target - _maxX).abs() < 0.5;
    final hitWall = arrived && atBound;
    setState(() {
      final x = arrived
          ? _target
          : _position.dx + (remaining.isNegative ? -distance : distance);
      _position = Offset(x.clamp(_minX, _maxX), _position.dy);
      _rememberPosition();
      if (arrived) _stop();
    });
    if (hitWall) {
      // 配置了撞墙动画则播放；否则转身反向走回场地内部。
      if (widget.movement.wallBumpEnabled) {
        _bumpWall();
      } else {
        _reverseFromWall();
        return;
      }
    }
    _schedule();
  }

  /// 撞墙：请求播放撞墙动画（可带帧区间）；busy 期间走动自动暂停，
  /// 动画播完后 busy 解除、恢复调度。
  void _bumpWall() {
    final movement = widget.movement;
    final id = movement.wallBumpAnimationId;
    if (id.isEmpty) return;
    _frameRequest.value = VideoPetManualAnimation(
      animationId: id,
      startFrame: movement.wallBumpStartFrame,
      endFrame: movement.wallBumpEndFrame,
      nonce: ++_wallBumpNonce,
    );
    _log('wall bump animation=$id nonce=$_wallBumpNonce');
  }

  void _rememberPosition() {
    _normalized = Offset(
      _range.width > 0
          ? ((_position.dx - _minX) / _range.width).clamp(0, 1)
          : (_normalized?.dx ?? 0.5),
      _range.height > 0 ? _position.dy / _range.height : (_normalized?.dy ?? 1),
    );
  }

  void _dragStart(DragStartDetails details) {
    if (!_loaded) return;
    setState(() {
      _stop();
      _dragging = true;
      _log(
        'drag start animation=${widget.movement.dragAnimationId} position=$_position',
      );
      _logStatus();
    });
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final mirror = _flipX;
    setState(() {
      _position = Offset(
        (_position.dx + details.delta.dx * (mirror ? -1 : 1)).clamp(
          _minX,
          _maxX,
        ),
        (_position.dy + details.delta.dy).clamp(0, _range.height),
      );
      _rememberPosition();
    });
  }

  void _dragEnd({bool cancelled = false}) {
    if (!_dragging) return;
    setState(() => _dragging = false);
    _log('drag end cancelled=$cancelled position=$_position');
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
      // 人物区域边界：regions 启用项的联合水平包围盒（归一化）。
      // 人物一边顶到容器边缘即视为到达边界，画布透明留白可移出容器；
      // 未配置 regions 时沿用旧规则：full-width 画布按中心锚点 ±w/2，
      // 小画布保持整画布在容器内。
      var bodyLeft = 0.0;
      var bodyRight = 1.0;
      var hasBody = false;
      for (final region in widget.regions) {
        if (!region.enabled) continue;
        if (!hasBody) {
          bodyLeft = region.x;
          bodyRight = region.x + region.width;
          hasBody = true;
        } else {
          bodyLeft = math.min(bodyLeft, region.x);
          bodyRight = math.max(bodyRight, region.x + region.width);
        }
      }
      final fullWidth =
          size.width > 0 && (size.width - constraints.maxWidth).abs() < 0.01;
      final double minX;
      final double maxX;
      if (hasBody) {
        minX = -bodyLeft * size.width;
        maxX = math.max(minX, constraints.maxWidth - bodyRight * size.width);
      } else if (fullWidth) {
        minX = -size.width / 2;
        maxX = constraints.maxWidth - size.width / 2;
      } else {
        minX = 0.0;
        maxX = math.max(0.0, constraints.maxWidth - size.width);
      }
      final range = Size(
        maxX - minX,
        math.max(0, availableHeight - size.height),
      );
      if (_range != range || _minX != minX) {
        _stop();
        _range = range;
        _minX = minX;
        _log(
          'range changed range=$range xBounds=[$minX,$maxX] centerAnchor=$fullWidth body=[$bodyLeft,$bodyRight] pet=$size requestedPet=${widget.petSize} constraints=$constraints',
        );
      }
      _position = _normalized == null
          ? Offset(
              minX + range.width / 2,
              (range.height - widget.initialBottomGap).clamp(0, range.height),
            )
          : Offset(
              minX + _normalized!.dx * range.width,
              _normalized!.dy * range.height,
            );
      _schedule();
      final movement = widget.movement;
      final animation = _movementAnimationId;
      final phase = _phase;
      return Stack(
        children: [
          Positioned(
            left: _position.dx,
            top: widget.topInset + _position.dy,
            width: size.width,
            height: size.height,
            child: Transform.flip(
              flipX: _flipX,
              child: widget.builder(
                context,
                JellyVideoPetPlayback(
                  animationId: animation,
                  dragAnimationId:
                      _dragging && movement.dragAnimationId.isNotEmpty
                      ? movement.dragAnimationId
                      : null,
                  loop: !_turning,
                  frameRequest: _frameRequest,
                  movementInterrupt: _interruptToken,
                  onComplete: () {
                    if (!mounted) return;
                    if (phase != _phase) {
                      _log('turn complete REJECTED stalePhase=$phase phase=$_phase turning=$_turning');
                    } else if (!_turning) {
                      _log('turn complete REJECTED notTurning phase=$phase');
                    } else if (!_canWalk) {
                      _log('turn complete REJECTED blocked=[${_blocked.join(',')}]');
                    } else {
                      _log('turn complete phase=$phase');
                      setState(_startWalking);
                    }
                  },
                  onAnimationFrame: (frame) => _animationFrame(frame, phase),
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
                  onDragCancel: () => _dragEnd(cancelled: true),
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
    _frameRequest.dispose();
    _ticker.dispose();
    super.dispose();
  }
}
