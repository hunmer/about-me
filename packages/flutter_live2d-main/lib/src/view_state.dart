part of '../flutter_live2d.dart';

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

/// Lifecycle of the underlying native view managed by a
/// [Live2DViewController].
///
/// The transition graph is:
///
/// ```
///   detached ──► attached ──► detached ──► attached ──► …
/// ```
///
/// A controller can be reattached to a freshly mounted [Live2DView]: when
/// that happens, [Live2DViewState.lifecycle] flips back to [attached] and
/// [Live2DViewController.whenAttached] resolves again.
enum Live2DLifecycle {
  /// No native view is attached. Either the controller was just created and
  /// the [Live2DView] hasn't mounted yet, or the widget was removed from the
  /// tree (in which case the native view has been torn down).
  ///
  /// In this state every command method on [Live2DViewController] throws a
  /// [Live2DException] with code `VIEW_NOT_ATTACHED`.
  detached,

  /// The native view is alive and ready for commands.
  attached,
}

// ---------------------------------------------------------------------------
// Loaded model
// ---------------------------------------------------------------------------

/// Identifies which model is currently loaded into a view, surfaced through
/// [Live2DViewState.loadedModel].
@immutable
class Live2DLoadedModel {
  /// Creates a snapshot of the loaded model's location.
  const Live2DLoadedModel({
    required this.modelDir,
    required this.modelFileName,
  });

  /// Directory the model was loaded from.
  ///
  /// An absolute filesystem path or remote HTTP(S) directory URL. Asset
  /// directories supplied to [Live2DViewController.loadModel] are extracted
  /// under the app's cache and that resolved path is stored here.
  final String modelDir;

  /// Name of the `.model3.json` entry file inside [modelDir].
  final String modelFileName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Live2DLoadedModel &&
          other.modelDir == modelDir &&
          other.modelFileName == modelFileName;

  @override
  int get hashCode => Object.hash(modelDir, modelFileName);

  @override
  String toString() => 'Live2DLoadedModel($modelFileName @ $modelDir)';
}

// ---------------------------------------------------------------------------
// View state
// ---------------------------------------------------------------------------

/// Sentinel used by [Live2DViewState.copyWith] so callers can distinguish
/// between "leave this field alone" and "explicitly set this field to null".
const Object _unset = Object();

/// Immutable snapshot of a [Live2DViewController]'s state.
///
/// The controller exposes itself as a `ValueListenable<Live2DViewState>`, so
/// every state mutation produces a new instance and notifies listeners.
/// Drive UI off of it with a [ValueListenableBuilder]:
///
/// ```dart
/// ValueListenableBuilder<Live2DViewState>(
///   valueListenable: controller,
///   builder: (_, state, _) {
///     if (state.isLoadingModel) return const CircularProgressIndicator();
///     if (state.isLoaded) return Text(state.loadedModel!.modelFileName);
///     return const SizedBox.shrink();
///   },
/// );
/// ```
@immutable
class Live2DViewState {
  /// Creates a state snapshot. Defaults match the state of a freshly
  /// constructed [Live2DViewController].
  const Live2DViewState({
    this.lifecycle = Live2DLifecycle.detached,
    this.isLoadingModel = false,
    this.modelLoadProgress = 0,
    this.modelLoadStage,
    this.loadedModel,
    this.isRenderingPaused = false,
    this.lastError,
    this.modelLoadError,
  });

  /// Whether the controller is bound to a live native view. See
  /// [Live2DLifecycle] for the state machine.
  final Live2DLifecycle lifecycle;

  /// `true` while a [Live2DViewController.loadModel] call is in flight.
  ///
  /// Resets to `false` once the call completes (either successfully or with
  /// an error).
  final bool isLoadingModel;

  /// Approximate model-loading progress in the range `0.0..1.0`.
  ///
  /// This is stage-based rather than byte-based because Cubism loads model
  /// components, motions, and textures through separate browser APIs.
  final double modelLoadProgress;

  /// Machine-readable name of the current loading stage, or `null` when no
  /// model load is in flight.
  final String? modelLoadStage;

  /// Currently loaded model, or `null` if no model is loaded.
  ///
  /// Cleared by a successful [Live2DViewController.unloadModel] call, by a
  /// failed [Live2DViewController.loadModel], and whenever the view enters
  /// [Live2DLifecycle.detached].
  final Live2DLoadedModel? loadedModel;

  /// Mirrors the last value passed to
  /// [Live2DViewController.setRenderingPaused]. Defaults to `false`.
  final bool isRenderingPaused;

  /// Last error encountered by any controller method. Cleared automatically
  /// on the next successful command. Use it to display the most recent
  /// failure in the UI.
  final Live2DException? lastError;

  /// Error of the most recent failed [Live2DViewController.loadModel] call,
  /// or `null` when the last load succeeded / none was attempted.
  ///
  /// Unlike [lastError] (which tracks the latest command error of any kind
  /// and is cleared by the next successful command), this survives other
  /// successful commands so the UI can keep offering a retry until the
  /// model actually loads. Cleared when a new load starts, when
  /// [loadModel] succeeds, on [Live2DViewController.unloadModel], and when
  /// the view detaches.
  final Live2DException? modelLoadError;

  /// Convenience: `true` iff [lifecycle] is [Live2DLifecycle.attached].
  bool get isAttached => lifecycle == Live2DLifecycle.attached;

  /// Convenience: `true` iff [loadedModel] is non-null.
  bool get isLoaded => loadedModel != null;

  /// Returns a copy of this state with the given fields replaced.
  ///
  /// Pass `null` for [loadedModel] or [lastError] to explicitly clear them;
  /// omit the parameter to keep the existing value.
  Live2DViewState copyWith({
    Live2DLifecycle? lifecycle,
    bool? isLoadingModel,
    double? modelLoadProgress,
    Object? modelLoadStage = _unset,
    Object? loadedModel = _unset,
    bool? isRenderingPaused,
    Object? lastError = _unset,
    Object? modelLoadError = _unset,
  }) {
    return Live2DViewState(
      lifecycle: lifecycle ?? this.lifecycle,
      isLoadingModel: isLoadingModel ?? this.isLoadingModel,
      modelLoadProgress: modelLoadProgress ?? this.modelLoadProgress,
      modelLoadStage: identical(modelLoadStage, _unset)
          ? this.modelLoadStage
          : modelLoadStage as String?,
      loadedModel: identical(loadedModel, _unset)
          ? this.loadedModel
          : loadedModel as Live2DLoadedModel?,
      isRenderingPaused: isRenderingPaused ?? this.isRenderingPaused,
      lastError: identical(lastError, _unset)
          ? this.lastError
          : lastError as Live2DException?,
      modelLoadError: identical(modelLoadError, _unset)
          ? this.modelLoadError
          : modelLoadError as Live2DException?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Live2DViewState &&
          other.lifecycle == lifecycle &&
          other.isLoadingModel == isLoadingModel &&
          other.modelLoadProgress == modelLoadProgress &&
          other.modelLoadStage == modelLoadStage &&
          other.loadedModel == loadedModel &&
          other.isRenderingPaused == isRenderingPaused &&
          other.lastError == lastError &&
          other.modelLoadError == modelLoadError;

  @override
  int get hashCode => Object.hash(
        lifecycle,
        isLoadingModel,
        modelLoadProgress,
        modelLoadStage,
        loadedModel,
        isRenderingPaused,
        lastError,
        modelLoadError,
      );

  @override
  String toString() => 'Live2DViewState('
      'lifecycle: $lifecycle, '
      'isLoadingModel: $isLoadingModel, '
      'modelLoadProgress: $modelLoadProgress, '
      'modelLoadStage: $modelLoadStage, '
      'loadedModel: $loadedModel, '
      'isRenderingPaused: $isRenderingPaused, '
      'lastError: $lastError, '
      'modelLoadError: $modelLoadError'
      ')';
}
