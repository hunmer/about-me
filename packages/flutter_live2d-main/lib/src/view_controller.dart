part of '../flutter_live2d.dart';

/// Controls a single [Live2DView]: loads / unloads models, plays motions and
/// expressions, mutates parameters, and tracks the live state of the view.
///
/// Pass the same instance to a [Live2DView] widget. Wait for the view to
/// attach via [whenAttached], then issue commands:
///
/// ```dart
/// final controller = Live2DViewController();
/// await controller.whenAttached;
/// await controller.loadModel(
///   modelDir: 'assets/models/ren/',
///   modelFileName: 'ren.model3.json',
/// );
/// await controller.startMotion(group: 'Idle');
/// ```
///
/// The controller is itself a `ValueListenable<Live2DViewState>` — pass it
/// to a [ValueListenableBuilder] to drive UI off of its state.
///
/// Always call [dispose] when the controller is no longer needed (typically
/// in your widget's `dispose`). After disposal, every method throws a
/// [Live2DException] with code `CONTROLLER_DISPOSED`.
class Live2DViewController extends ValueNotifier<Live2DViewState> {
  /// Creates a controller in [Live2DLifecycle.detached] state.
  Live2DViewController() : super(const Live2DViewState()) {
    _ensureContextMenuBridge();
  }

  /// Callback invoked when the user right-clicks / secondary-taps the view.
  ///
  /// Reported by the macOS embedding, where platform views consume the mouse
  /// event before Flutter's gesture arena (WKWebView would otherwise show
  /// its own "Reload" context menu). Use it to present an app-level menu,
  /// e.g. zoom controls for the character.
  void Function()? onContextMenu;

  /// Callback invoked when the user taps the view (primary button, barely
  /// any movement — drags are excluded).
  ///
  /// [hitAreaId] / [hitAreaName] identify the hit area (declared as
  /// `HitAreas` in the `.model3.json`) under the tap; both are `null` when
  /// the tap missed every area. [x] / [y] are view coordinates in
  /// `-1.0..1.0`. A miss is reported with both hit-area values set to `null`.
  void Function(String? hitAreaId, String? hitAreaName, double x, double y)?
      onTap;

  /// Attached controllers by native view id, used to route native-initiated
  /// events (see [_ensureContextMenuBridge]).
  static final Map<int, Live2DViewController> _attachedControllers = {};

  /// Whether the native→Dart `onContextMenu` handler has been installed for
  /// this isolate. Installed lazily (first controller created) so the binary
  /// messenger is guaranteed to exist.
  static bool _contextMenuBridgeInstalled = false;

  static void _ensureContextMenuBridge() {
    if (_contextMenuBridgeInstalled) return;
    _contextMenuBridgeInstalled = true;
    const MethodChannel('flutter_live2d').setMethodCallHandler((call) async {
      final args = call.arguments as Map<Object?, Object?>?;
      int? viewId(Object? value) => value is num ? value.toInt() : null;
      if (call.method == 'onContextMenu') {
        final id = viewId(args?['viewId']);
        if (id != null) {
          _attachedControllers[id]?._handleNativeContextMenu();
        }
      } else if (call.method == 'onTap') {
        final id = viewId(args?['viewId']);
        if (id != null) {
          _attachedControllers[id]?._handleNativeTap(
            args?['hitAreaId'] as String?,
            args?['hitAreaName'] as String?,
            (args?['x'] as num?)?.toDouble() ?? 0,
            (args?['y'] as num?)?.toDouble() ?? 0,
          );
        }
      } else if (call.method == 'onModelLoadProgress') {
        final id = viewId(args?['viewId']);
        if (id != null) {
          _attachedControllers[id]?._handleNativeLoadProgress(
            (args?['progress'] as num?)?.toDouble() ?? 0,
            args?['stage'] as String?,
          );
        }
      }
      return null;
    });
  }

  void _handleNativeContextMenu() {
    onContextMenu?.call();
  }

  void _handleNativeTap(
    String? hitAreaId,
    String? hitAreaName,
    double x,
    double y,
  ) {
    onTap?.call(hitAreaId, hitAreaName, x, y);
  }

  void _handleNativeLoadProgress(double progress, String? stage) {
    if (!value.isLoadingModel) return;
    value = value.copyWith(
      modelLoadProgress: progress.clamp(0.0, 1.0),
      modelLoadStage: stage,
    );
  }

  /// Native view id assigned by the platform after the [Live2DView] mounts.
  /// `null` when [Live2DLifecycle.detached].
  int? _viewId;

  /// `true` after [dispose] has been called. Subsequent calls fail fast.
  bool _isDisposed = false;

  /// Pending awaiters for the next [Live2DLifecycle.attached] transition.
  /// Recreated on demand so callers waiting after a detach can subscribe to
  /// the next attach.
  Completer<void>? _attachedCompleter;

  /// Future that completes the next time the view enters
  /// [Live2DLifecycle.attached].
  ///
  /// * If the view is already attached, returns a completed future.
  /// * If the controller is disposed, returns a future that errors with
  ///   [Live2DException] code `CONTROLLER_DISPOSED`.
  /// * Otherwise resolves once the [Live2DView] mounts and reports its
  ///   native id.
  ///
  /// Safe to await multiple times; each call either completes immediately
  /// (when already attached) or shares the same pending completer.
  Future<void> get whenAttached {
    if (_isDisposed) {
      return Future.error(
        Live2DException(
          'CONTROLLER_DISPOSED',
          'Controller has been disposed.',
        ),
      );
    }
    if (value.isAttached) return Future.value();
    return (_attachedCompleter ??= Completer<void>()).future;
  }

  // -------------------------------------------------------------------------
  // Internal lifecycle hooks (called from Live2DView's State).
  // -------------------------------------------------------------------------

  /// Called by [Live2DView] once the native view is created. Transitions
  /// the lifecycle to [Live2DLifecycle.attached] and unblocks any pending
  /// [whenAttached] awaiters.
  void _attach(int viewId) {
    if (_isDisposed) return;
    if (_viewId == viewId && value.isAttached) return;
    _attachedControllers[viewId] = this;
    _viewId = viewId;
    value = value.copyWith(
      lifecycle: Live2DLifecycle.attached,
      lastError: null,
    );
    final completer = _attachedCompleter;
    _attachedCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  /// Called by [Live2DView] when its widget is removed from the tree.
  /// Resets transient state and transitions back to
  /// [Live2DLifecycle.detached]. [Live2DViewState.lastError] is preserved
  /// so the UI can still surface the last failure.
  void _detach() {
    final previousId = _viewId;
    if (previousId == null) return;
    if (_attachedControllers[previousId] == this) {
      _attachedControllers.remove(previousId);
    }
    _viewId = null;
    value = value.copyWith(
      lifecycle: Live2DLifecycle.detached,
      isLoadingModel: false,
      modelLoadProgress: 0,
      modelLoadStage: null,
      loadedModel: null,
      isRenderingPaused: false,
      modelLoadError: null,
    );
  }

  /// Returns the native view id or throws the appropriate
  /// [Live2DException] when the controller is detached / disposed. Used to
  /// guard every command method.
  int get _id {
    if (_isDisposed) {
      throw Live2DException(
        'CONTROLLER_DISPOSED',
        'Controller has been disposed.',
      );
    }
    final id = _viewId;
    if (id == null) {
      throw Live2DException(
        'VIEW_NOT_ATTACHED',
        'Live2DViewController is not attached to a Live2DView yet. '
            'Await `controller.whenAttached` or wait for the view to mount.',
      );
    }
    return id;
  }

  // -------------------------------------------------------------------------
  // Commands
  // -------------------------------------------------------------------------

  /// Loads a Live2D model into the view.
  ///
  /// [modelDir] accepts either:
  ///   * an absolute filesystem directory (e.g. one returned from
  ///     `getApplicationDocumentsDirectory()`), or
  ///   * an asset directory declared in `pubspec.yaml` (e.g.
  ///     `assets/models/ren/`), or
  ///   * an HTTP(S) directory URL on platforms that support remote models.
  ///
  /// Asset directories are extracted lazily into the app's cache on first
  /// load and reused on subsequent calls within the same app launch. The
  /// resolved on-disk path becomes [Live2DLoadedModel.modelDir].
  ///
  /// [modelFileName] is the `.model3.json` file name inside [modelDir].
  ///
  /// Returns `true` when the model is loaded successfully; `false` when
  /// the native side rejected the model (in which case
  /// [Live2DViewState.lastError] is populated with code `LOAD_FAILED`).
  ///
  /// Throws [Live2DException] when the call cannot be dispatched at all
  /// (controller disposed, view not attached, missing assets, …).
  Future<bool> loadModel({
    required String modelDir,
    required String modelFileName,
  }) async {
    value = value.copyWith(
      isLoadingModel: true,
      modelLoadProgress: 0,
      modelLoadStage: 'preparing',
      lastError: null,
      modelLoadError: null,
    );
    try {
      final resolvedDir = await _resolveModelDir(modelDir);
      final ok = await _wrap(
        () => FlutterLive2dPlatform.instance.loadModel(
          viewId: _id,
          modelDir: resolvedDir,
          modelFileName: modelFileName,
        ),
      );
      final loadFailure = ok
          ? null
          : Live2DException(
              'LOAD_FAILED',
              'Native loadModel returned false for $modelFileName.',
            );
      value = value.copyWith(
        isLoadingModel: false,
        modelLoadProgress: ok ? 1 : value.modelLoadProgress,
        modelLoadStage: ok ? 'complete' : value.modelLoadStage,
        loadedModel: ok
            ? Live2DLoadedModel(
                modelDir: resolvedDir,
                modelFileName: modelFileName,
              )
            : null,
        lastError: loadFailure,
        modelLoadError: loadFailure,
      );
      return ok;
    } catch (error) {
      debugPrint(
        '[FlutterLive2D][Dart][view:${_viewId ?? "detached"}] '
        'loadModel failed: $error',
      );
      value = value.copyWith(
        isLoadingModel: false,
        loadedModel: null,
        modelLoadError: error is Live2DException
            ? error
            : Live2DException('LOAD_FAILED', error.toString()),
      );
      rethrow;
    }
  }

  /// Unloads the currently loaded model and frees its native resources
  /// (textures, motion data, expression data).
  ///
  /// Safe to call when no model is loaded — it is a no-op on the native
  /// side. After completion [Live2DViewState.loadedModel] is `null`.
  Future<void> unloadModel() async {
    await _wrap(
      () => FlutterLive2dPlatform.instance.unloadModel(viewId: _id),
    );
    value = value.copyWith(
      loadedModel: null,
      modelLoadProgress: 0,
      modelLoadStage: null,
      lastError: null,
      modelLoadError: null,
    );
  }

  /// Pauses or resumes the GL render loop for this view.
  ///
  /// Useful to save battery when the view is offscreen but you don't want
  /// to tear it down entirely. The native model state is preserved while
  /// paused.
  Future<void> setRenderingPaused(bool paused) async {
    await _wrap(
      () => FlutterLive2dPlatform.instance.setRenderingPaused(
        viewId: _id,
        paused: paused,
      ),
    );
    if (value.isRenderingPaused != paused) {
      value = value.copyWith(isRenderingPaused: paused);
    }
  }

  /// Starts a motion.
  ///
  /// [group] is the motion group name from the model definition. Pass an
  /// empty string for the default / unnamed group.
  ///
  /// [index] picks a specific motion within that group.
  ///
  /// [priority] follows Live2D Cubism conventions:
  /// `0=none`, `1=idle`, `2=normal`, `3=force`. Higher priority preempts
  /// lower priority motions; `force` always plays.
  Future<void> startMotion({
    required String group,
    int index = 0,
    int priority = 2,
  }) =>
      _wrap(
        () => FlutterLive2dPlatform.instance.startMotion(
          viewId: _id,
          group: group,
          index: index,
          priority: priority,
        ),
      );

  /// Switches the active expression by [index] (0-based, into the model's
  /// expression list).
  Future<void> setExpression(int index) => _wrap(
        () => FlutterLive2dPlatform.instance.setExpression(
          viewId: _id,
          index: index,
        ),
      );

  /// Sets a single model parameter to [value].
  ///
  /// [parameterId] follows Cubism convention, e.g. `"ParamAngleX"`,
  /// `"ParamMouthOpenY"`. The valid range is defined by the model.
  Future<void> setParameter(String parameterId, double value) => _wrap(
        () => FlutterLive2dPlatform.instance.setParameter(
          viewId: _id,
          parameterId: parameterId,
          value: value,
        ),
      );

  /// Feeds a normalized pointer position into the model's native drag input.
  /// This drives the model-authored look and physics chain like mouse hover.
  Future<void> setDragging(double x, double y) => _wrap(
        () => FlutterLive2dPlatform.instance.setDragging(
          viewId: _id,
          x: x.clamp(-1.0, 1.0).toDouble(),
          y: y.clamp(-1.0, 1.0).toDouble(),
        ),
      );

  /// Sets the motion playback speed multiplier.
  ///
  /// `1.0` = normal speed (default), `2.0` = double speed, `0.5` = half
  /// speed. `0.0` effectively freezes the motion (physics and eye-blink
  /// keep running at normal rate).
  ///
  /// The speed is applied to the current and all future motions until
  /// changed again.
  Future<void> setMotionSpeed(double speed) => _wrap(
        () => FlutterLive2dPlatform.instance.setMotionSpeed(
          viewId: _id,
          speed: speed,
        ),
      );

  /// Toggles a debug overlay visualizing the model's hit areas (the
  /// clickable regions declared as `HitAreas` in the `.model3.json`).
  ///
  /// While enabled, translucent red rectangles with name labels follow the
  /// model every frame. Useful to see where taps will land and to verify a
  /// model's hit-area meshes are set up correctly.
  Future<void> setHitAreasVisible(bool visible) => _wrap(
        () => FlutterLive2dPlatform.instance.setHitAreasVisible(
          viewId: _id,
          visible: visible,
        ),
      );

  /// Toggles whether the native view participates in pointer hit testing.
  ///
  /// While [enabled] is `true` (the platform default) the native view
  /// consumes pointer events over its bounds. Pass `false` to let events
  /// fall through to the Flutter layers behind the view — used e.g. by
  /// editor overlays that must receive gestures on top of the model, or by
  /// floating pets whose interaction is driven entirely from Flutter.
  ///
  /// Platforms that cannot change native hit testing at runtime throw a
  /// [Live2DException]; callers should catch it and degrade gracefully.
  Future<void> setInteractive(bool enabled) => _wrap(
        () => FlutterLive2dPlatform.instance.setInteractive(
          viewId: _id,
          enabled: enabled,
        ),
      );

  Future<void> resetGaze() => _wrap(
        () => FlutterLive2dPlatform.instance.resetGaze(viewId: _id),
      );

  // -------------------------------------------------------------------------
  // Disposal
  // -------------------------------------------------------------------------

  /// Disposes the controller's listeners and rejects any in-flight
  /// [whenAttached] awaiters with code `CONTROLLER_DISPOSED`.
  ///
  /// Always call this when the controller is no longer needed. After
  /// disposal every command method throws [Live2DException] with code
  /// `CONTROLLER_DISPOSED`.
  ///
  /// This does **not** tear down the native view: the [Live2DView] widget
  /// is responsible for that, and it does so when removed from the widget
  /// tree.
  @override
  void dispose() {
    _isDisposed = true;
    final currentId = _viewId;
    if (currentId != null && _attachedControllers[currentId] == this) {
      _attachedControllers.remove(currentId);
    }
    final completer = _attachedCompleter;
    _attachedCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        Live2DException(
          'CONTROLLER_DISPOSED',
          'Controller was disposed before attaching.',
        ),
      );
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  /// Wraps a platform-channel call so every error path is normalized into a
  /// [Live2DException] and recorded in [Live2DViewState.lastError]. On
  /// success, clears [Live2DViewState.lastError] from the previous failed
  /// call.
  Future<T> _wrap<T>(Future<T> Function() body) async {
    try {
      final result = await body();
      if (value.lastError != null) {
        value = value.copyWith(lastError: null);
      }
      return result;
    } on Live2DException catch (e) {
      value = value.copyWith(lastError: e);
      rethrow;
    } on PlatformException catch (e) {
      final mapped = Live2DException(
        e.code,
        e.message ?? 'Native error',
        details: e.details,
      );
      value = value.copyWith(lastError: mapped);
      throw mapped;
    } catch (e) {
      final mapped = Live2DException('UNKNOWN', e.toString());
      value = value.copyWith(lastError: mapped);
      throw mapped;
    }
  }
}
