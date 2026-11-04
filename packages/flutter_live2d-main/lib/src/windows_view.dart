part of '../flutter_live2d.dart';

const MethodChannel _windowsLive2DChannel = MethodChannel('flutter_live2d');

class _WindowsLive2DView extends StatefulWidget {
  const _WindowsLive2DView({
    required this.onPlatformViewCreated,
    required this.controller,
  });

  final ValueChanged<int> onPlatformViewCreated;
  final Live2DViewController? controller;

  @override
  State<_WindowsLive2DView> createState() => _WindowsLive2DViewState();
}

class _WindowsLive2DViewState extends State<_WindowsLive2DView> {
  int? _viewId;
  int? _textureId;
  int _pixelWidth = 0;
  int _pixelHeight = 0;
  int? _pendingWidth;
  int? _pendingHeight;
  bool _resizeScheduled = false;
  bool _creationStarted = false;
  Object? _error;
  Offset? _pointerDownPosition;
  bool _pointerDownIsPrimary = false;

  @override
  void dispose() {
    final viewId = _viewId;
    if (viewId != null) {
      unawaited(
        _windowsLive2DChannel.invokeMethod<void>('disposeView', {
          'viewId': viewId,
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 1.0;
        final logicalHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 1.0;
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final width =
            (logicalWidth * devicePixelRatio).round().clamp(1, 4096).toInt();
        final height =
            (logicalHeight * devicePixelRatio).round().clamp(1, 4096).toInt();

        _ensureView(width, height);

        if (_error != null) {
          return Center(child: Text('Live2D Windows error: $_error'));
        }

        final textureId = _textureId;
        if (textureId == null) return const SizedBox.expand();

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            _pointerDownIsPrimary = event.kind != PointerDeviceKind.mouse ||
                (event.buttons & kPrimaryMouseButton) != 0;
            _pointerDownPosition =
                _pointerDownIsPrimary ? event.localPosition : null;
            _updatePointer(event);
          },
          // Keep the model's gaze under the desktop cursor even when the
          // primary button is not pressed.
          onPointerHover: _updatePointer,
          onPointerMove: _updatePointer,
          onPointerUp: _handlePointerUp,
          onPointerCancel: (_) {
            _pointerDownPosition = null;
            _pointerDownIsPrimary = false;
            _resetPointer();
          },
          child: Texture(textureId: textureId),
        );
      },
    );
  }

  void _ensureView(int width, int height) {
    final viewId = _viewId;
    if (viewId == null) {
      if (_creationStarted) {
        _pendingWidth = width;
        _pendingHeight = height;
        return;
      }
      _creationStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_createView(width, height));
      });
      return;
    }

    if (_pixelWidth == width && _pixelHeight == height) return;
    _pendingWidth = width;
    _pendingHeight = height;
    _scheduleResize(viewId);
  }

  Future<void> _createView(int width, int height) async {
    try {
      final result = await _windowsLive2DChannel
          .invokeMapMethod<String, Object?>('createView', {
        'width': width,
        'height': height,
      });
      final viewId = result?['viewId'] as int?;
      final textureId = result?['textureId'] as int?;
      if (viewId == null || textureId == null) {
        throw const FormatException('Invalid createView response.');
      }
      if (!mounted) {
        await _windowsLive2DChannel.invokeMethod<void>('disposeView', {
          'viewId': viewId,
        });
        return;
      }
      _viewId = viewId;
      _textureId = textureId;
      _pixelWidth = width;
      _pixelHeight = height;
      // The window may have been resized while the native texture was being
      // created. Keep the latest layout size queued for the next frame.
      final pendingWidth = _pendingWidth;
      final pendingHeight = _pendingHeight;
      if (pendingWidth != null &&
          pendingHeight != null &&
          (pendingWidth != width || pendingHeight != height)) {
        _scheduleResize(viewId);
      }
      widget.onPlatformViewCreated(viewId);
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _scheduleResize(int viewId) {
    if (_resizeScheduled) return;
    _resizeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        while (mounted && _viewId == viewId) {
          final nextWidth = _pendingWidth;
          final nextHeight = _pendingHeight;
          _pendingWidth = null;
          _pendingHeight = null;
          if (nextWidth == null || nextHeight == null) break;
          if (_pixelWidth == nextWidth && _pixelHeight == nextHeight) continue;

          await _windowsLive2DChannel.invokeMethod<void>('resizeView', {
            'viewId': viewId,
            'width': nextWidth,
            'height': nextHeight,
          });
          if (!mounted || _viewId != viewId) return;
          _pixelWidth = nextWidth;
          _pixelHeight = nextHeight;
          debugPrint(
            '[Live2DWindowsResize] view=$viewId '
            'texture=${nextWidth}x$nextHeight',
          );
        }
      } catch (error) {
        _handleAsyncError(error);
      } finally {
        _resizeScheduled = false;
        if (mounted &&
            _viewId == viewId &&
            _pendingWidth != null &&
            _pendingHeight != null) {
          _scheduleResize(viewId);
        }
      }
    });
  }

  void _updatePointer(PointerEvent event) {
    final viewId = _viewId;
    final size = context.size;
    if (viewId == null || size == null || size.isEmpty) return;
    final x = 2.0 * event.localPosition.dx / size.width - 1.0;
    final y = -(2.0 * event.localPosition.dy / size.height - 1.0);
    unawaited(
      _windowsLive2DChannel.invokeMethod<void>('setDragging', {
        'viewId': viewId,
        'x': x.clamp(-1.0, 1.0),
        'y': y.clamp(-1.0, 1.0),
      }),
    );
  }

  void _resetPointer() {
    final viewId = _viewId;
    if (viewId == null) return;
    unawaited(
      _windowsLive2DChannel.invokeMethod<void>('setDragging', {
        'viewId': viewId,
        'x': 0.0,
        'y': 0.0,
      }),
    );
  }

  Future<void> _handlePointerUp(PointerUpEvent event) async {
    final downPosition = _pointerDownPosition;
    final isPrimaryTap = _pointerDownIsPrimary;
    _pointerDownPosition = null;
    _pointerDownIsPrimary = false;
    if (event.kind != PointerDeviceKind.mouse) {
      _resetPointer();
    }
    final viewId = _viewId;
    final size = context.size;
    if (!isPrimaryTap ||
        viewId == null ||
        size == null ||
        size.isEmpty ||
        downPosition == null ||
        (event.localPosition - downPosition).distance > 8) {
      return;
    }
    final x = 2.0 * event.localPosition.dx / size.width - 1.0;
    final y = -(2.0 * event.localPosition.dy / size.height - 1.0);
    try {
      final hit = await _windowsLive2DChannel
          .invokeMapMethod<String, Object?>('hitTest', {
        'viewId': viewId,
        'x': x.clamp(-1.0, 1.0),
        'y': y.clamp(-1.0, 1.0),
      });
      final hitAreaId = hit?['hitAreaId'] as String?;
      if (!mounted || hitAreaId == null) return;
      widget.controller?._handleNativeTap(
        hitAreaId,
        hit?['hitAreaName'] as String?,
        x,
        y,
      );
    } catch (error) {
      debugPrint('[FlutterLive2D][Windows] hitTest failed: $error');
    }
  }

  dynamic _handleAsyncError(Object error) {
    if (mounted) setState(() => _error = error);
  }
}
