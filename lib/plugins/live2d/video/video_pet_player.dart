import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spritesheet_animation/flutter_spritesheet_animation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'video_pet_import.dart';
import 'video_pet_import_stub.dart'
    if (dart.library.io) 'video_pet_import_io.dart'
    as platform;
import 'video_pet_manifest.dart';
import 'video_pet_player_state.dart';

export 'video_pet_player_state.dart';

const kDefaultVideoPetAssetBase = 'assets/live2d/video/dsh_pet/';

/// 读取视频宠物精灵图图片字节（data / file / http(s) / blob / asset 五类来源）。
/// 播放器与编辑器（分帧选择）共用。
Future<Uint8List> readVideoPetImageBytes(Uri uri) async {
  if (uri.scheme == 'data') return uri.data!.contentAsBytes();
  if (uri.scheme == 'file') {
    final bytes = await platform.readFile(uri);
    if (bytes == null) throw StateError('找不到图片：$uri');
    return bytes;
  }
  if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'blob') {
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError('图片 HTTP ${response.statusCode}');
    }
    return response.bodyBytes;
  }
  if (uri.hasScheme) throw FormatException('不支持的图片来源：$uri');
  final data = await rootBundle.load(Uri.decodeFull(uri.toString()));
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

class VideoPetPlayer extends StatefulWidget {
  const VideoPetPlayer({
    super.key,
    required this.manifest,
    required this.baseUri,
    this.active = true,
    this.paused = false,
    this.animationRequest,
    this.frameAnimationRequest,
    this.movementAnimationId,
    this.dragAnimationId,
    this.movementLoop = true,
    this.movementInterrupt = 0,
    this.onMovementComplete,
    this.onAnimationFrame,
    this.onPlaybackBusyChanged,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
    this.onTap,
    this.onInteraction,
    this.interactive = true,
    this.showRegions = false,
    this.resolvedSources = const {},
    this.onContextMenu,
    this.onEditPointer,
  });
  final VideoPetManifest manifest;
  final String baseUri;
  final bool active;
  final bool paused;
  final ValueListenable<String?>? animationRequest;

  /// 一次性点播（如撞墙动画）：可带帧区间；nonce 变化才触发。
  final ValueListenable<VideoPetManualAnimation?>? frameAnimationRequest;
  final String? movementAnimationId;
  final String? dragAnimationId;
  final bool movementLoop;

  /// 走动打断令牌：变化时强制打断当前一次性/悬停动画，
  /// 让 movement 动画立即上场（用于“向左/向右走动”按钮）。
  final int movementInterrupt;
  final VoidCallback? onMovementComplete;
  final ValueChanged<VideoPetAnimationFrame>? onAnimationFrame;
  final ValueChanged<bool>? onPlaybackBusyChanged;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;
  final GestureDragCancelCallback? onDragCancel;
  final void Function(String? regionId, String? regionName)? onTap;
  final void Function(String? regionId, String? animationId)? onInteraction;
  final bool interactive;
  final bool showRegions;
  final Map<String, String> resolvedSources;
  final VoidCallback? onContextMenu;
  final void Function(String type, double x, double y)? onEditPointer;

  @override
  State<VideoPetPlayer> createState() => _VideoPetPlayerState();
}

class _VideoPetPlayerState extends State<VideoPetPlayer>
    with WidgetsBindingObserver {
  late VideoPetPlaybackState _playback;
  VideoPetPackage? _package;
  VideoPetPlaybackRequest? _request;
  MemoryImage? _image;
  String? _error;
  bool _background = false;
  bool _inactive = false;
  bool _pointerInside = false;
  String? _hoverRegion;
  int _epoch = 0;
  int _packageEpoch = 0;
  bool _reportedBusy = false;
  String? _reportedBusyReasons;
  bool _busyNotificationScheduled = false;
  int _lastFrameNonce = 0;

  void _notifyBusy() {
    if (_busyNotificationScheduled) return;
    _busyNotificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _busyNotificationScheduled = false;
      if (!mounted) return;
      final busy = _playback.busy;
      final reasons = _playback.busyReasons.join(',');
      if (_reportedBusyReasons != reasons) {
        _reportedBusyReasons = reasons;
        debugPrint(
          '[VideoPetPlayer] model=${widget.manifest.id} busy=$busy reasons=[$reasons]',
        );
      }
      if (busy == _reportedBusy) return;
      _reportedBusy = busy;
      widget.onPlaybackBusyChanged?.call(busy);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _complete(VideoPetPlaybackRequest request) {
    // A decoded, currently displayed surface is the only completion source.
    final accepted = !_released && identical(_request, request);
    debugPrint(
      '[VideoPetPlayer] complete animation=${request.animationId} generation=${request.generation} current=${_playback.generation} accepted=$accepted',
    );
    if (!accepted) return;
    final next = _playback.ended(request.generation);
    if (next == null) return;
    unawaited(_present(next));
    if (request.kind == VideoPetPlaybackKind.movement && !request.loop) {
      widget.onMovementComplete?.call();
    }
  }

  bool get _released => !widget.active || _background;
  bool get _playing => !_released && !widget.paused && !_inactive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _background =
        state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    _playback = VideoPetPlaybackState(widget.manifest);
    widget.animationRequest?.addListener(_manual);
    widget.frameAnimationRequest?.addListener(_frameAnimation);
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    final epoch = ++_packageEpoch;
    debugPrint(
      '[VideoPetPlayer] prepare start model=${widget.manifest.id} epoch=$epoch',
    );
    _release();
    _package = null;
    try {
      final package = await const VideoPetImportService().prepareForPlayback(
        widget.manifest,
        baseUri: widget.baseUri,
        resolvedSources: widget.resolvedSources,
      );
      if (!mounted || epoch != _packageEpoch) return;
      _package = package;
      _playback = VideoPetPlaybackState(package.manifest);
      _playback.setLifecycle(
        active: !_released,
        paused: widget.paused || _inactive,
      );
      _playback.setMovement(
        widget.movementAnimationId,
        loop: widget.movementLoop,
      );
      final id = widget.animationRequest?.value;
      if (id != null) _playback.playManual(id);
      _playback.setDrag(widget.dragAnimationId);
      debugPrint(
        '[VideoPetPlayer] prepare success model=${widget.manifest.id} epoch=$epoch',
      );
      await _present(_playback.current);
    } catch (error) {
      if (!mounted || epoch != _packageEpoch) return;
      debugPrint(
        '[VideoPetPlayer] load failed model=${widget.manifest.id} generation=${_playback.generation} error=$error',
      );
      setState(() => _error = '精灵图资源加载失败：$error');
    }
  }

  @override
  void didUpdateWidget(covariant VideoPetPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationRequest != widget.animationRequest) {
      oldWidget.animationRequest?.removeListener(_manual);
      widget.animationRequest?.addListener(_manual);
    }
    if (oldWidget.frameAnimationRequest != widget.frameAnimationRequest) {
      oldWidget.frameAnimationRequest?.removeListener(_frameAnimation);
      widget.frameAnimationRequest?.addListener(_frameAnimation);
    }
    if (oldWidget.manifest != widget.manifest ||
        oldWidget.baseUri != widget.baseUri ||
        !mapEquals(oldWidget.resolvedSources, widget.resolvedSources)) {
      _pointerInside = false;
      _hoverRegion = null;
      unawaited(_prepare());
      return;
    }
    final interactionChanged = oldWidget.interactive && !widget.interactive;
    if (interactionChanged) {
      _playback.setHover(null);
      _pointerInside = false;
      _hoverRegion = null;
    }
    final movementChanged =
        oldWidget.movementAnimationId != widget.movementAnimationId ||
        oldWidget.movementLoop != widget.movementLoop;
    final interruptChanged =
        oldWidget.movementInterrupt != widget.movementInterrupt;
    if (movementChanged || interruptChanged) {
      _playback.setMovement(
        widget.movementAnimationId,
        loop: widget.movementLoop,
        interrupt: interruptChanged,
      );
    }
    final dragChanged = oldWidget.dragAnimationId != widget.dragAnimationId;
    if (dragChanged) _playback.setDrag(widget.dragAnimationId);
    if (oldWidget.active != widget.active ||
        oldWidget.paused != widget.paused) {
      _lifecycle();
    } else if (interactionChanged ||
        movementChanged ||
        dragChanged ||
        interruptChanged) {
      unawaited(_present(_playback.current));
    }
    if (oldWidget.animationRequest != widget.animationRequest) _manual();
    if (oldWidget.frameAnimationRequest != widget.frameAnimationRequest) {
      _lastFrameNonce = 0;
      _frameAnimation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background =
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    _inactive = state != AppLifecycleState.resumed;
    _lifecycle();
  }

  void _lifecycle() {
    _playback.setLifecycle(
      active: !_released,
      paused: widget.paused || _inactive,
    );
    _notifyBusy();
    if (_released) {
      _release();
      if (mounted) setState(() {});
    } else {
      unawaited(_present(_playback.current));
    }
  }

  void _manual() {
    if (_package == null) return;
    unawaited(_present(_playback.playManual(widget.animationRequest?.value)));
  }

  /// 撞墙 / AB 循环等点播：nonce 去重，同一 nonce 只处理一次。
  void _frameAnimation() {
    if (_package == null) return;
    final request = widget.frameAnimationRequest?.value;
    if (request == null) {
      // 外部清空 = 取消循环点播，恢复常规播放。
      if (_playback.current?.kind == VideoPetPlaybackKind.manual) {
        unawaited(_present(_playback.playManual(null)));
      }
      return;
    }
    if (request.nonce != 0 && request.nonce == _lastFrameNonce) return;
    _lastFrameNonce = request.nonce;
    unawaited(
      _present(
        _playback.playManual(
          request.animationId,
          startFrame: request.startFrame,
          endFrame: request.endFrame,
          loop: request.loop,
        ),
      ),
    );
  }

  void _release() {
    _epoch++;
    final image = _image;
    _image = null;
    _request = null;
    if (image != null) unawaited(image.evict());
  }

  Future<Uint8List> _readImage(Uri uri) => readVideoPetImageBytes(uri);

  Future<void> _present(VideoPetPlaybackRequest? request) async {
    _notifyBusy();
    final package = _package;
    if (request == null || package == null || _released) return;
    if (_request?.generation == request.generation && _image != null) {
      setState(() {});
      return;
    }
    final epoch = ++_epoch;
    debugPrint(
      '[VideoPetPlayer] load start animation=${request.animationId} kind=${request.kind.name} generation=${request.generation} epoch=$epoch',
    );
    MemoryImage? image;
    try {
      final animation = package.manifest.animation(request.animationId)!;
      final source = animation.imageSource;
      if (animation.spritesheet == null || source == null) {
        throw StateError('动作 ${animation.name} 缺少精灵图，请转换资源包');
      }
      image = MemoryImage(
        await _readImage(Uri.parse(package.resolveSource(source))),
      );
      if (!mounted || epoch != _epoch || _released) return;
      Object? decodeError;
      await precacheImage(
        image,
        context,
        onError: (error, stack) => decodeError = error,
      );
      if (decodeError != null) throw decodeError!;
      if (!mounted || epoch != _epoch || _released) {
        unawaited(image.evict());
        return;
      }
      debugPrint(
        '[VideoPetPlayer] load success animation=${request.animationId} generation=${request.generation} epoch=$epoch',
      );
      final previous = _image;
      setState(() {
        _image = image;
        _request = request;
        _error = null;
      });
      if (previous != null) unawaited(previous.evict());
    } catch (error) {
      if (image != null) unawaited(image.evict());
      if (!mounted || epoch != _epoch || _released) return;
      debugPrint(
        '[VideoPetPlayer] load failed model=${widget.manifest.id} generation=${_playback.generation} error=$error',
      );
      setState(() => _error = '精灵图加载失败，点击重试\n$error');
    }
  }

  ({double x, double y})? _point(Offset position, Size size) =>
      videoPetContainPoint(
        x: position.dx,
        y: position.dy,
        width: size.width,
        height: size.height,
        canvasWidth: widget.manifest.canvasWidth,
        canvasHeight: widget.manifest.canvasHeight,
      );

  void _pointer(String type, Offset position, Size size) {
    final point = _point(position, size);
    if (point != null) {
      widget.onEditPointer?.call(type, point.x, point.y);
    } else if (type == 'pointerup' || type == 'pointercancel') {
      widget.onEditPointer?.call(type, 0, 0);
    }
    if (type == 'pointermove' || type == 'hover') _hover(point);
  }

  void _hover(({double x, double y})? point) {
    if (!widget.interactive || !_playing || _package == null) return;
    final manifest = _package!.manifest;
    final region = point == null ? null : manifest.hitTest(point.x, point.y);
    if ((point != null) == _pointerInside && region?.id == _hoverRegion) return;
    _pointerInside = point != null;
    _hoverRegion = region?.id;
    // Keep region hit tracking for pointer/editor behavior without scheduling
    // playback or marking the player busy on hover.
  }

  void _tap(Offset position, Size size) {
    if (!widget.interactive || !_playing || _package == null) return;
    final point = _point(position, size);
    if (point == null) return;
    final manifest = _package!.manifest;
    final region = manifest.hitTest(point.x, point.y);
    widget.onTap?.call(region?.id, region?.name);
    final binding = region?.click ?? manifest.click;
    if (binding.animationIds.isEmpty) return;
    final request = _playback.playClick(binding);
    widget.onInteraction?.call(region?.id, request?.animationId);
    unawaited(_present(request));
  }

  @override
  Widget build(BuildContext context) {
    if (_released) return const SizedBox.expand();
    final request = _request;
    final sheet = request == null
        ? null
        : _package?.manifest.animation(request.animationId)?.spritesheet;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return MouseRegion(
          onHover: (event) => _pointer('hover', event.localPosition, size),
          onExit: (_) => _hover(null),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) =>
                _pointer('pointerdown', event.localPosition, size),
            onPointerMove: (event) =>
                _pointer('pointermove', event.localPosition, size),
            onPointerUp: (event) =>
                _pointer('pointerup', event.localPosition, size),
            onPointerCancel: (event) =>
                _pointer('pointercancel', event.localPosition, size),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _tap(details.localPosition, size),
              onPanStart: widget.onDragStart,
              onPanUpdate: widget.onDragUpdate,
              onPanEnd: widget.onDragEnd,
              onPanCancel: widget.onDragCancel,
              onSecondaryTapUp: (_) => widget.onContextMenu?.call(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_error == null &&
                      _image != null &&
                      request != null &&
                      sheet != null)
                    // key 含 generation，动画请求变化时重建精灵面。
                    _SpriteSurface(
                      key: ValueKey((_image, request.generation)),
                      image: _image!,
                      sheet: sheet,
                      playing: _playing,
                      loop: request.loop,
                      startFrame: request.startFrame,
                      endFrame: request.endFrame,
                      onComplete: () => _complete(request),
                      onFrame: (frame) {
                        if (!mounted ||
                            !_playing ||
                            _error != null ||
                            !identical(_request, request) ||
                            request.generation != _playback.generation) {
                          return;
                        }
                        widget.onAnimationFrame?.call(
                          VideoPetAnimationFrame(
                            animationId: request.animationId,
                            currentFrame: frame,
                            generation: request.generation,
                          ),
                        );
                      },
                    ),
                  if (widget.showRegions)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _RegionPainter(widget.manifest),
                      ),
                    ),
                  if (_error != null)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          if (_package == null) {
                            unawaited(_prepare());
                          } else {
                            unawaited(_present(_playback.retry()));
                          }
                        },
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _packageEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    widget.animationRequest?.removeListener(_manual);
    widget.frameAnimationRequest?.removeListener(_frameAnimation);
    _release();
    super.dispose();
  }
}

class _SpriteSurface extends StatefulWidget {
  const _SpriteSurface({
    super.key,
    required this.image,
    required this.sheet,
    required this.playing,
    required this.loop,
    required this.onComplete,
    required this.onFrame,
    this.startFrame,
    this.endFrame,
  });
  final ImageProvider image;
  final VideoPetSpritesheet sheet;
  final bool playing;
  final bool loop;

  /// 帧区间（闭区间）；null = 整段。endFrame 到达即视为播放完成。
  final int? startFrame;
  final int? endFrame;
  final VoidCallback onComplete;
  final ValueChanged<int> onFrame;
  @override
  State<_SpriteSurface> createState() => _SpriteSurfaceState();
}

class _SpriteSurfaceState extends State<_SpriteSurface> {
  int _frameEpoch = 0;
  bool _rangeCompleted = false;

  void _frameAdvanced(int frame) {
    if (!widget.playing || !_controller.isPlaying) return;
    // 帧区间播放：到达 endFrame 即完成。循环请求（AB 播放）回到
    // startFrame 继续循环；一次性请求（撞墙等）暂停并提前完成。
    final end = widget.endFrame;
    if (end != null && frame >= end) {
      if (_rangeCompleted) return;
      if (widget.loop) {
        _controller.goToFrame(widget.startFrame ?? 0);
        return;
      }
      _rangeCompleted = true;
      _controller.pause();
      widget.onComplete();
      return;
    }
    // onFrame fires for every step, including skipped frames and each wrap.
    // Capture currentFrame now; reading it after paint would lose those steps.
    final captured = frame;
    final epoch = _frameEpoch;
    final deliver = widget.onFrame;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.playing && epoch == _frameEpoch) deliver(captured);
    });
  }

  late final SpriteAnimationController _controller = SpriteAnimationController(
    fps: widget.sheet.fps,
    loop: widget.loop,
    autoPlay: false,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 帧区间播放：从 startFrame 起播（goToFrame 在 play 之前，静默生效）。
      final start = widget.startFrame;
      if (start != null && start > 0) _controller.goToFrame(start);
      if (widget.playing) _controller.play();
    });
  }

  @override
  void didUpdateWidget(covariant _SpriteSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) {
      _frameEpoch++;
      if (widget.playing) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SpriteAnimation.grid(
      image: widget.image,
      columns: widget.sheet.columns,
      rows: widget.sheet.rows,
      frameCount: widget.sheet.frameCount,
      controller: _controller,
      fps: widget.sheet.fps,
      loop: widget.loop,
      autoPlay: false,
      onFrame: _frameAdvanced,
      onComplete: widget.onComplete,
      fit: BoxFit.contain,
    ),
  );
  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }
}

class _RegionPainter extends CustomPainter {
  const _RegionPainter(this.manifest);
  final VideoPetManifest manifest;
  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        (size.width / manifest.canvasWidth <
            size.height / manifest.canvasHeight)
        ? size.width / manifest.canvasWidth
        : size.height / manifest.canvasHeight;
    final w = manifest.canvasWidth * scale, h = manifest.canvasHeight * scale;
    final left = (size.width - w) / 2, top = (size.height - h) / 2;
    final paint = Paint()
      ..color = const Color(0xAA34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in manifest.regions.where((r) => r.enabled)) {
      canvas.drawRect(
        Rect.fromLTWH(left + r.x * w, top + r.y * h, r.width * w, r.height * h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RegionPainter oldDelegate) =>
      oldDelegate.manifest != manifest;
}
