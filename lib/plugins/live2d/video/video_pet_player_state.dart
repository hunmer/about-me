import 'dart:math';

import 'video_pet_manifest.dart';

enum VideoPetPlaybackKind { idle, movement, hover, click, manual, drag }

/// One actual controller advancement; initial display and pause emit nothing.
class VideoPetAnimationFrame {
  const VideoPetAnimationFrame({
    required this.animationId,
    required this.currentFrame,
    required this.generation,
  });
  final String animationId;
  final int currentFrame;
  final int generation;
}

class VideoPetPlaybackRequest {
  const VideoPetPlaybackRequest({
    required this.animationId,
    required this.kind,
    required this.generation,
    required this.loop,
  });
  final String animationId;
  final VideoPetPlaybackKind kind;
  final int generation;
  final bool loop;
}

/// Pure Dart scheduler. Every actual playback replacement gets a new generation.
class VideoPetPlaybackState {
  VideoPetPlaybackState(this.manifest, {Random? random})
    : _random = random ?? Random();
  final VideoPetManifest manifest;
  final Random _random;
  final Map<String, int> _sequences = {};
  int _generation = 0;
  String? _onceId;
  VideoPetPlaybackKind _onceKind = VideoPetPlaybackKind.click;
  String? _hoverId;
  String? _dragId;
  String? _movementId;
  bool _movementLoop = true;
  bool _movementCompleted = false;
  bool _active = true;
  bool _paused = false;

  int get generation => _generation;
  bool get playing => _active && !_paused;
  List<String> get busyReasons => [
    if (_dragId != null) 'drag',
    if (_onceId != null) _onceKind.name,
    if (_hoverId != null) 'hover',
  ];
  bool get busy => _onceId != null || _hoverId != null;
  String? get _pendingMovementId => _movementCompleted ? null : _movementId;
  String get activeAnimationId =>
      _dragId ??
      _onceId ??
      _hoverId ??
      _pendingMovementId ??
      manifest.idleAnimationId;
  VideoPetPlaybackRequest? get current {
    if (manifest.animation(activeAnimationId) == null) return null;
    return VideoPetPlaybackRequest(
      animationId: activeAnimationId,
      kind: _dragId != null
          ? VideoPetPlaybackKind.drag
          : _onceId != null
          ? _onceKind
          : _hoverId != null
          ? VideoPetPlaybackKind.hover
          : _pendingMovementId != null
          ? VideoPetPlaybackKind.movement
          : VideoPetPlaybackKind.idle,
      generation: _generation,
      loop:
          _dragId != null ||
          (_onceId == null &&
              (_hoverId != null ||
                  _pendingMovementId == null ||
                  _movementLoop)),
    );
  }

  VideoPetPlaybackRequest? setLifecycle({bool? active, bool? paused}) {
    _active = active ?? _active;
    _paused = paused ?? _paused;
    return current; // Pause/resume freezes the same generation and frame.
  }

  VideoPetPlaybackRequest? setDrag(String? animationId) {
    final id = _valid(animationId);
    if (id == _dragId) return current;
    _dragId = id;
    return _bump();
  }

  VideoPetPlaybackRequest? setHover(String? animationId) {
    final id = _valid(animationId);
    if (id == _hoverId) return current;
    _hoverId = id;
    return _dragId != null || _onceId != null ? current : _bump();
  }

  VideoPetPlaybackRequest? playHover(VideoPetBinding binding) =>
      setHover(_pick(binding, 'hover'));

  VideoPetPlaybackRequest? playClick(VideoPetBinding binding) {
    final id = _pick(binding, 'click');
    if (id == null) return current;
    _onceId = id;
    _onceKind = VideoPetPlaybackKind.click;
    return _dragId != null ? current : _bump();
  }

  VideoPetPlaybackRequest? playManual(String? animationId) {
    if (animationId == null) {
      if (_onceId == null) return current;
      _onceId = null;
      return _dragId != null ? current : _bump();
    }
    final id = _valid(animationId);
    if (id == null) return current;
    _onceId = id;
    _onceKind = VideoPetPlaybackKind.manual;
    return _dragId != null ? current : _bump();
  }

  VideoPetPlaybackRequest? setMovement(
    String? animationId, {
    bool loop = true,
  }) {
    final id = _valid(animationId);
    if (id == _movementId && loop == _movementLoop) return current;
    _movementId = id;
    _movementLoop = loop;
    _movementCompleted = false;
    return _dragId != null || busy ? current : _bump();
  }

  VideoPetPlaybackRequest? ended(int generation) {
    if (!playing || generation != _generation || _dragId != null) return null;
    if (_onceId != null) {
      _onceId = null;
    } else if (_hoverId == null &&
        _pendingMovementId != null &&
        !_movementLoop) {
      _movementCompleted = true;
    } else {
      return null;
    }
    return _bump();
  }

  VideoPetPlaybackRequest? retry() => _bump();

  VideoPetPlaybackRequest? _bump() {
    _generation++;
    return current;
  }

  String? _valid(String? id) =>
      id != null && manifest.animation(id) != null ? id : null;
  String? _pick(VideoPetBinding binding, String kind) {
    final ids = binding.animationIds.where((id) => _valid(id) != null).toList();
    if (ids.isEmpty) return null;
    if (binding.strategy == 'sequence') {
      final key = '$kind:${ids.join('\u0000')}';
      final index = _sequences[key] ?? 0;
      _sequences[key] = index + 1;
      return ids[index % ids.length];
    }
    return ids[_random.nextInt(ids.length)];
  }
}

/// Normalized contain coordinates. Letterbox space has no hit target.
({double x, double y})? videoPetContainPoint({
  required double x,
  required double y,
  required double width,
  required double height,
  required double canvasWidth,
  required double canvasHeight,
}) {
  if (![
        x,
        y,
        width,
        height,
        canvasWidth,
        canvasHeight,
      ].every((v) => v.isFinite) ||
      width <= 0 ||
      height <= 0 ||
      canvasWidth <= 0 ||
      canvasHeight <= 0) {
    return null;
  }
  final scale = min(width / canvasWidth, height / canvasHeight);
  final w = canvasWidth * scale, h = canvasHeight * scale;
  final px = (x - (width - w) / 2) / w, py = (y - (height - h) / 2) / h;
  return px < 0 || px > 1 || py < 0 || py > 1 ? null : (x: px, y: py);
}
