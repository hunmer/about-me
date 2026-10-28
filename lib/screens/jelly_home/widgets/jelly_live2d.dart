import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/live2d_voice_analyzer.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_player.dart';
import 'package:aboutme/plugins/live2d/screens/live2d_archive_form_screen.dart';
import 'package:aboutme/plugins/live2d/screens/live2d_main_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:live2d_flutter/live2d_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

import '../live2d_online_models.dart';
import 'bubble_region_editor.dart';
import 'jelly_configurable_image.dart';
import 'jelly_live2d_crop_dialog.dart';
import 'jelly_live2d_crop_region.dart';
import 'jelly_live2d_interaction.dart';
import 'jelly_live2d_layout.dart';
import 'jelly_live2d_models.dart';
import 'jelly_live2d_panel.dart';
import 'jelly_speech_bubble.dart';

export 'jelly_live2d_models.dart';

part 'jelly_live2d_background.dart';
part 'jelly_live2d_bubble.dart';
part 'jelly_live2d_controls.dart';
part 'jelly_live2d_crop.dart';
part 'jelly_live2d_loader.dart';
part 'jelly_live2d_resource_strip.dart';
part 'jelly_live2d_tap.dart';

/// 人物显示尺寸（逻辑像素，宽高一致），经 SharedPreferences 持久化
const double _defaultSize = 360;
const double _minSize = 200;
const double _maxSize = 560;
const double _sizeStep = 40;
const double _modelViewportAspectRatio = 0.5;
const double _fillBottomReserve = 92;
// The floating-action radial dock paints 28px above its cropped layout
// bounds via OverflowBox/Transform.translate.
const double _radialDockOverflowTop = 28;

final math.Random _random = math.Random();

class JellyLive2D extends StatefulWidget {
  const JellyLive2D({
    super.key,
    this.onTap,
    this.message,
    this.initialModel,
    this.reaction,
    this.streaming = false,
    this.typingInterval = const Duration(milliseconds: 70),
    this.motionRequest,
    this.expressionRequest,
    this.videoAnimationRequest,
    this.fill = false,
    this.fitContainer = false,
    this.topInset = 0,
    this.panel,
    this.statusPanel,
    this.onAppearanceAvailabilityChanged,
  });

  /// 点击角色（命中或未命中可点击区域都会回调）时通知宿主，
  /// 用于衔接陪伴数值（情绪/好感度）等玩法
  final void Function(String? hitAreaId, String? hitAreaName)? onTap;
  final String? message;
  final Live2DModelDefinition? initialModel;
  final int? reaction;
  final bool streaming;
  final Duration typingInterval;

  /// 全屏模式：显示尺寸按父级可用高度自适应（约 70% 高度，
  /// 夹在 [_minSize, _maxSize] 调节范围内），跟随窗口大小变化；
  /// 关闭时使用保存的固定尺寸
  final bool fill;

  /// When enabled, the Live2D viewport fills the usable height of its parent
  /// container above the bottom navigation area. The parent should provide
  /// finite constraints.
  final bool fitContainer;

  /// 顶部预留高度（如状态面板）：背景图仍铺满整个容器，
  /// 仅角色视口的可用高度扣除该值
  final double topInset;

  /// 外部（如 Live2D 设置页的动作列表）请求播放动作的通道；
  /// 模型未就绪时挂起，加载完成后自动播放
  final ValueListenable<Live2DMotionDefinition?>? motionRequest;

  /// 外部请求切换表达式（表情、皮肤、饰品）。
  final ValueListenable<Live2DExpressionDefinition?>? expressionRequest;
  final ValueListenable<String?>? videoAnimationRequest;

  /// 底部资源面板开关（由底部导航子栏图标驱动）：
  /// 值非空时在底部导航上方展示水平可滚动的资源列表
  final ValueListenable<JellyLive2dPanel?>? panel;

  /// 宿主提供的状态面板，与其他资源共用底部资源条展示。
  final Widget? statusPanel;

  /// 当前模型是否存在动画或表情，用于控制资源入口显隐。
  final ValueChanged<bool>? onAppearanceAvailabilityChanged;

  @override
  State<JellyLive2D> createState() => _JellyLive2DState();
}

class _JellyLive2DState extends State<JellyLive2D>
    with RouteAware, SingleTickerProviderStateMixin {
  final Live2DViewController _controller = Live2DViewController();
  late final ValueNotifier<Live2DVoiceFrame?> _voiceFrame =
      Live2DPlugin.instance.voiceFrame;
  final ValueNotifier<double> _size = ValueNotifier<double>(_defaultSize);
  final GlobalKey _modelCaptureKey = GlobalKey();
  late final AnimationController _tapSpringController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _tapSpringScale = Tween<double>(begin: 1, end: 1)
      .animate(
        CurvedAnimation(parent: _tapSpringController, curve: Curves.elasticOut),
      );
  late Live2DModelDefinition _selectedModel =
      widget.initialModel ?? availableJellyLive2DModels.first;
  JellyLive2DCropRegion _cropRegion = const JellyLive2DCropRegion.full();
  bool _isSwitchingModel = true;
  final ValueNotifier<String?> _videoAnimationRequest = ValueNotifier(null);
  VideoPetManifest? _videoManifest;
  String? _videoLoadError;
  int _modelLoadGeneration = 0;

  bool get _isVideo => _selectedModel.isVideo;

  void _requestVideoAnimation(String id) {
    _videoAnimationRequest.value = null;
    _videoAnimationRequest.value = id;
  }

  void _handleExternalVideoRequest() {
    final id = widget.videoAnimationRequest?.value;
    if (id != null) _requestVideoAnimation(id);
  }

  void _handleVideoTap(String? id, String? name) {
    widget.onTap?.call(id, name);
    _showBubble(_pickBubbleMessage(id, name));
  }

  bool _routeVisible = true;
  Future<void>? _routeUnload;
  Live2DMotionDefinition? _pendingMotion;
  Live2DVoiceFrame? _lastVoiceFrame;
  Future<void> _voiceParameterQueue = Future<void>.value();
  int _voiceFrameVersion = 0;
  int _voiceLoadGeneration = 0;
  int _lastAppliedVoiceVersion = -1;
  int _lastAppliedVoiceLoadGeneration = -1;
  bool _wasModelLoaded = false;
  Timer? _voiceGazeTimer;
  Timer? _tapGazeResetTimer;
  bool _jevMotionActive = false;
  double _voiceGazeXValue = 0;
  double _voiceGazeYValue = 0;
  double _voiceGazeLastSentX = 0;
  double _voiceGazeLastSentY = 0;
  double _voiceGazeTargetX = 0;
  double _voiceGazeTargetY = 0;
  double _voiceGazeTargetRemaining = 0;
  DateTime? _voiceGazeLastTick;
  bool _voiceGazeUpdateInFlight = false;
  double? _pendingVoiceGazeX;
  double? _pendingVoiceGazeY;

  /// 可点击区域（HitAreas）调试叠加层的开关状态，不持久化；
  /// 用 ValueNotifier 让已打开的控制面板能实时刷新
  final ValueNotifier<bool> _hitAreasVisible = ValueNotifier<bool>(false);

  /// Live2D 实际显示视口的边框开关，仅用于界面调试，不持久化
  final ValueNotifier<bool> _borderVisible = ValueNotifier<bool>(false);

  /// 当前生效的显示尺寸（fill 模式下按视口高度自适应），
  /// 气泡宽度等布局按它计算
  double _displaySize = _defaultSize;
  double _bubbleOffsetX = 0;
  double _bubbleOffsetY = 0;

  bool get _hasAppearanceResources => _isVideo
      ? (_videoManifest ?? _selectedModel.videoManifest)
                ?.animations
                .isNotEmpty ==
            true
      : _selectedModel.motions.isNotEmpty ||
            _selectedModel.expressions.isNotEmpty;

  /// 当前小屋背景图；null 表示不显示，经 Live2DPlugin 设置持久化
  String? _backgroundAsset = Live2DPlugin.instance.backgroundAsset;
  double _backgroundBlur = Live2DPlugin.instance.backgroundBlur;
  double _backgroundOpacity = Live2DPlugin.instance.backgroundOpacity;

  /// 当前气泡台词；null 表示不显示。连续点击时替换内容并重置计时
  String? _bubbleMessage;
  bool _bubblePositionPreview = false;
  bool _bubbleStreaming = false;
  Timer? _bubbleTimer;
  Timer? _bubbleResumeTimer;
  Timer? _jevReplyTimer;
  Timer? _appearanceResetTimer;
  String? _lastBubbleMessage;
  String? _lastJevReply;

  @override
  void didUpdateWidget(covariant JellyLive2D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != null && widget.message != oldWidget.message) {
      _showBubble(widget.message!, streaming: widget.streaming);
      _scheduleJevReply(widget.message!, widget.streaming);
    }
    if (widget.reaction != null && widget.reaction != oldWidget.reaction) {
      _playReaction();
    }
    // 宿主传入的模型（来自存档）变化后重新加载
    final nextModel = widget.initialModel;
    if (nextModel != null && !_isSameModel(nextModel, _selectedModel)) {
      _selectModel(nextModel);
    }
    if (widget.motionRequest != oldWidget.motionRequest) {
      oldWidget.motionRequest?.removeListener(_handleMotionRequest);
      widget.motionRequest?.addListener(_handleMotionRequest);
    }
    if (widget.videoAnimationRequest != oldWidget.videoAnimationRequest) {
      oldWidget.videoAnimationRequest?.removeListener(
        _handleExternalVideoRequest,
      );
      widget.videoAnimationRequest?.addListener(_handleExternalVideoRequest);
    }
    if (widget.expressionRequest != oldWidget.expressionRequest) {
      oldWidget.expressionRequest?.removeListener(_handleExpressionRequest);
      widget.expressionRequest?.addListener(_handleExpressionRequest);
    }
  }

  @override
  void initState() {
    super.initState();
    _notifyAppearanceAvailabilityChanged();
    // macOS 上平台视图会吃掉鼠标事件（WKWebView 默认弹 Reload 菜单），
    // 原生侧拦截后经 onContextMenu 回调转发到这里
    _controller.onContextMenu = _showControls;
    // 点击事件同样由原生侧经 onTap 转发（含 hit area 判定结果）
    _controller.onTap = _handleTap;
    _controller.addListener(_onViewStateChanged);
    _voiceFrame.addListener(_handleVoiceFrame);
    widget.motionRequest?.addListener(_handleMotionRequest);
    widget.videoAnimationRequest?.addListener(_handleExternalVideoRequest);
    widget.expressionRequest?.addListener(_handleExpressionRequest);
    _loadSavedCropRegion(_selectedModel);
    unawaited(_initialize());
  }

  void _notifyAppearanceAvailabilityChanged() {
    final callback = widget.onAppearanceAvailabilityChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(_hasAppearanceResources);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      RouteHistoryManager.instance.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    debugPrint('[Live2D][Route] 页面被覆盖，准备卸载模型');
    setState(() => _routeVisible = false);
    _routeUnload = _unloadModel();
  }

  @override
  void didPopNext() {
    debugPrint('[Live2D][Route] 返回页面，准备恢复模型');
    setState(() => _routeVisible = true);
    unawaited(_restoreModel());
  }

  Future<void> _restoreModel() async {
    await _routeUnload;
    if (!mounted || !_routeVisible) return;
    if (_isVideo) {
      if (_videoManifest == null) await _loadModel(_selectedModel);
      return;
    }
    if (!_controller.value.isLoaded && !_controller.value.isLoadingModel) {
      await _loadModel(_selectedModel);
    }
  }

  Future<void> _unloadModel() async {
    if (!_controller.value.isLoaded) return;
    try {
      await _controller.unloadModel();
    } on Live2DException {
      // 路由离开时释放失败不应阻断页面导航。
    }
  }

  Future<void> _initialize() async {
    await _loadSavedSize();
    await _loadSavedBubblePosition();
    if (!mounted || !_routeVisible) return;
    // Wait until the first finite layout is committed. The native view must
    // not be loaded against the temporary constraints from the first build.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_routeVisible) return;
    // The home screen's bottom navigation reports its final safe area one or
    // two frames after the first layout. Give that resize time to settle
    // before creating the native viewport.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || !_routeVisible) return;
    await _loadModel(_selectedModel);
  }

  @override
  void dispose() {
    RouteHistoryManager.instance.unsubscribe(this);
    widget.motionRequest?.removeListener(_handleMotionRequest);
    widget.videoAnimationRequest?.removeListener(_handleExternalVideoRequest);
    _videoAnimationRequest.dispose();
    widget.expressionRequest?.removeListener(_handleExpressionRequest);
    _controller.removeListener(_onViewStateChanged);
    _voiceFrame.removeListener(_handleVoiceFrame);
    _bubbleTimer?.cancel();
    _bubbleResumeTimer?.cancel();
    _jevReplyTimer?.cancel();
    _appearanceResetTimer?.cancel();
    _voiceGazeTimer?.cancel();
    _tapGazeResetTimer?.cancel();
    _tapSpringController.dispose();
    _size.dispose();
    _hitAreasVisible.dispose();
    _borderVisible.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleVoiceFrame() {
    _lastVoiceFrame = _voiceFrame.value;
    final version = ++_voiceFrameVersion;
    _queueVoiceParameter(_lastVoiceFrame, version);
    _syncVoiceGaze();
  }

  void _syncVoiceGaze() {
    final frame = _voiceFrame.value;
    if (!mounted ||
        !_controller.value.isLoaded ||
        _jevMotionActive ||
        frame == null ||
        frame.mouthOpenY < 0.02) {
      _stopVoiceGaze(
        resetParameter:
            !_jevMotionActive && (frame == null || frame.mouthOpenY < 0.02),
      );
      return;
    }
    if (_voiceGazeTimer != null) return;
    // Pick a new cursor-like target at irregular intervals and ease toward it.
    // This avoids the visibly repetitive left-right path of a sine wave.
    _voiceGazeTargetX = _random.nextDouble() * 1.4 - 0.7;
    _voiceGazeTargetY = _random.nextDouble() * 0.7 - 0.35;
    _voiceGazeTargetRemaining = 0.7 + _random.nextDouble() * 0.9;
    _voiceGazeLastTick = DateTime.now();
    _voiceGazeTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final currentFrame = _voiceFrame.value;
      if (!mounted ||
          !_controller.value.isLoaded ||
          _jevMotionActive ||
          currentFrame == null ||
          currentFrame.mouthOpenY < 0.02) {
        _stopVoiceGaze(resetParameter: !_jevMotionActive);
        return;
      }
      final now = DateTime.now();
      final previous = _voiceGazeLastTick ?? now;
      final dt = (now.difference(previous).inMicroseconds / 1000000)
          .clamp(0.0, 0.1)
          .toDouble();
      _voiceGazeLastTick = now;
      if (dt <= 0) return;
      _voiceGazeTargetRemaining -= dt;
      if (_voiceGazeTargetRemaining <= 0) {
        _voiceGazeTargetX = _random.nextDouble() * 1.4 - 0.7;
        _voiceGazeTargetY = _random.nextDouble() * 0.7 - 0.35;
        _voiceGazeTargetRemaining = 0.7 + _random.nextDouble() * 0.9;
      }
      final smoothing = (dt * 3.8).clamp(0.0, 1.0).toDouble();
      _voiceGazeXValue += (_voiceGazeTargetX - _voiceGazeXValue) * smoothing;
      _voiceGazeYValue += (_voiceGazeTargetY - _voiceGazeYValue) * smoothing;
      if ((_voiceGazeXValue - _voiceGazeLastSentX).abs() < 0.015 &&
          (_voiceGazeYValue - _voiceGazeLastSentY).abs() < 0.015) {
        return;
      }
      if (_voiceGazeUpdateInFlight) return;
      _voiceGazeLastSentX = _voiceGazeXValue;
      _voiceGazeLastSentY = _voiceGazeYValue;
      unawaited(_sendVoiceGazeParameters(_voiceGazeXValue, _voiceGazeYValue));
    });
  }

  Future<void> _sendVoiceGazeParameters(double x, double y) async {
    if (!mounted || !_controller.value.isLoaded) {
      return;
    }
    if (_voiceGazeUpdateInFlight) {
      _pendingVoiceGazeX = x;
      _pendingVoiceGazeY = y;
      return;
    }
    _voiceGazeUpdateInFlight = true;
    try {
      // Use Cubism's native drag input so the model's own look and physics
      // chain reproduces the same response as hovering the mouse over it.
      await _controller.setDragging(x, y);
    } catch (error) {
      debugPrint('[Live2D][Voice] gaze update failed: $error');
    } finally {
      _voiceGazeUpdateInFlight = false;
      final pendingX = _pendingVoiceGazeX;
      final pendingY = _pendingVoiceGazeY;
      _pendingVoiceGazeX = null;
      _pendingVoiceGazeY = null;
      if (pendingX != null && pendingY != null) {
        unawaited(_sendVoiceGazeParameters(pendingX, pendingY));
      }
    }
  }

  void _stopVoiceGaze({required bool resetParameter}) {
    _voiceGazeTimer?.cancel();
    _voiceGazeTimer = null;
    _voiceGazeLastTick = null;
    if (!resetParameter || !_controller.value.isLoaded) return;
    _voiceGazeXValue = 0;
    _voiceGazeYValue = 0;
    _voiceGazeLastSentX = 0;
    _voiceGazeLastSentY = 0;
    _voiceGazeTargetX = 0;
    _voiceGazeTargetY = 0;
    _voiceGazeTargetRemaining = 0;
    _pendingVoiceGazeX = 0;
    _pendingVoiceGazeY = 0;
    unawaited(_sendVoiceGazeParameters(0, 0));
  }

  void _queueVoiceParameter(Live2DVoiceFrame? frame, int version) {
    final loadGeneration = _voiceLoadGeneration;
    _voiceParameterQueue = _voiceParameterQueue.then((_) async {
      if (!mounted ||
          !_controller.value.isLoaded ||
          loadGeneration != _voiceLoadGeneration) {
        return;
      }
      // 音频帧可能在模型加载期间快速到达，只应用队列中最新的一帧。
      if (version != _voiceFrameVersion) return;
      if (version == _lastAppliedVoiceVersion &&
          loadGeneration == _lastAppliedVoiceLoadGeneration) {
        return;
      }
      final value = frame?.mouthOpenY ?? 0;
      try {
        await _controller.setParameter('ParamMouthOpenY', value);
        _lastAppliedVoiceVersion = version;
        _lastAppliedVoiceLoadGeneration = loadGeneration;
        debugPrint(
          '[Live2D][Voice] ParamMouthOpenY=$value '
          '(version=$version, load=$loadGeneration)',
        );
      } catch (error) {
        debugPrint('[Live2D][Voice] set ParamMouthOpenY failed: $error');
      }
    });
    unawaited(_voiceParameterQueue);
  }

  /// 流式回复会多次更新 message；等待内容稳定后只触发一次 JEV。
  void _scheduleJevReply(String reply, bool streaming) {
    _jevReplyTimer?.cancel();
    if (streaming || reply.trim().isEmpty || reply == _lastJevReply) return;
    _jevReplyTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || _bubbleStreaming) return;
      _lastJevReply = reply;
      unawaited(_applyJevReply(reply));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return ValueListenableBuilder<double>(
      valueListenable: _size,
      builder: (context, size, _) => LayoutBuilder(
        builder: (context, constraints) {
          final containerWidth = constraints.maxWidth;
          final containerHeight = constraints.maxHeight;
          final fitHeight = widget.fitContainer && containerHeight.isFinite
              ? containerHeight
              : null;
          final fitWidth = widget.fitContainer && containerWidth.isFinite
              ? containerWidth
              : null;
          // Scaffold.extendBody exposes the complete radial bar footprint as
          // the bottom media padding (runtime value is 129px on macOS).
          final navigationPadding = MediaQuery.paddingOf(context).bottom;
          final bottomReserve = navigationPadding + _radialDockOverflowTop;
          final displaySize = computeJellyLive2DDisplaySize(
            savedSize: size,
            containerWidth: containerWidth,
            // 角色可用高度扣除顶部预留（状态面板），背景图仍铺满容器
            containerHeight: containerHeight - widget.topInset,
            bottomReserve: bottomReserve,
            fill: widget.fill,
            fitContainer: widget.fitContainer,
            modelViewportAspectRatio: _isVideo && _videoManifest != null
                ? _videoManifest!.canvasWidth / _videoManifest!.canvasHeight
                : _modelViewportAspectRatio,
            fillBottomReserve: _fillBottomReserve,
            minSize: _minSize,
            maxSize: _maxSize,
          );
          final layoutWidth = fitWidth ?? displaySize;
          final layoutHeight = fitHeight ?? displaySize;
          final modelBottomInset = computeJellyLive2DModelBottomInset(
            layoutHeight: layoutHeight,
            navigationPadding: navigationPadding,
            fitContainer: fitHeight != null,
          );
          // Resize supported native views to the painted size. Scaling a fixed
          // 360px viewport blurs desktop rendering and can leave platform-view
          // bounds and hit-test coordinates out of sync with the model.
          final viewportLayout = computeJellyLive2DViewportLayout(
            displaySize: displaySize,
            baseViewportHeight: _defaultSize,
            useResizableViewport:
                kIsWeb ||
                (defaultTargetPlatform == TargetPlatform.windows ||
                    defaultTargetPlatform == TargetPlatform.macOS ||
                    defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.android),
          );
          final viewportSize = Size(
            viewportLayout.viewportHeight * _modelViewportAspectRatio,
            viewportLayout.viewportHeight,
          );
          final modelScale = viewportLayout.scale;
          _displaySize = displaySize;
          return MouseRegion(
            onExit: (_) => resetGaze(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: layoutWidth,
              height: layoutHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: _showControls,
                // 右键点在 Flutter 渲染的区域（如底部标签）时走这里；
                // 点在人物本体上由原生转发到 _controller.onContextMenu
                onSecondaryTapUp: (_) => _showControls(),
                child: Stack(
                  fit: StackFit.expand,
                  // Crop selection can extend beyond the model's layout bounds.
                  clipBehavior: Clip.none,
                  children: [
                    if (_backgroundAsset != null)
                      Positioned.fill(
                        child: Opacity(
                          opacity: _backgroundOpacity.clamp(0.0, 1.0),
                          child: _backgroundBlur > 0
                              ? ImageFiltered(
                                  imageFilter: ui.ImageFilter.blur(
                                    sigmaX: _backgroundBlur,
                                    sigmaY: _backgroundBlur,
                                    tileMode: ui.TileMode.decal,
                                  ),
                                  child: JellyConfigurableImage(
                                    path: _backgroundAsset!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : JellyConfigurableImage(
                                  path: _backgroundAsset!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    if (_isVideo)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: modelBottomInset,
                        height: displaySize,
                        child: _videoManifest == null
                            ? Center(
                                child: _videoLoadError == null
                                    ? const CircularProgressIndicator()
                                    : TextButton(
                                        onPressed: () =>
                                            _loadModel(_selectedModel),
                                        child: Text(_videoLoadError!),
                                      ),
                              )
                            : VideoPetPlayer(
                                key: ValueKey(
                                  '${_selectedModel.modelDir}:${jsonEncode(_videoManifest!.toJson())}',
                                ),
                                manifest: _videoManifest!,
                                baseUri: _selectedModel.modelDir,
                                resolvedSources:
                                    _selectedModel.videoResolvedSources,
                                active: _routeVisible,
                                animationRequest: _videoAnimationRequest,
                                onTap: _handleVideoTap,
                                onContextMenu: _showControls,
                              ),
                      )
                    else
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: modelBottomInset,
                        height: displaySize,
                        child: AnimatedOpacity(
                          // Android hybrid composition needs a painted view to
                          // attach its TextureView surface and finish loading.
                          opacity:
                              !kIsWeb &&
                                  defaultTargetPlatform ==
                                      TargetPlatform.android
                              ? 1
                              : _isSwitchingModel ||
                                    _controller.value.lastError != null
                              ? 0
                              : 1,
                          duration: const Duration(milliseconds: 160),
                          child: OverflowBox(
                            alignment: Alignment.bottomCenter,
                            minWidth: 0,
                            minHeight: 0,
                            maxWidth: double.infinity,
                            maxHeight: double.infinity,
                            child: Transform.scale(
                              scale: modelScale,
                              alignment: Alignment.bottomCenter,
                              child: AnimatedBuilder(
                                animation: _tapSpringScale,
                                builder: (context, child) => Transform.scale(
                                  scale: _tapSpringScale.value,
                                  alignment: Alignment.bottomCenter,
                                  child: child,
                                ),
                                child: SizedBox(
                                  width: viewportSize.width,
                                  height: viewportSize.height,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRect(
                                        child: Transform.translate(
                                          offset: _cropRegion.sourceTranslation(
                                            viewportSize,
                                          ),
                                          child: Transform.scale(
                                            scale: _cropRegion.zoom,
                                            alignment: Alignment.topLeft,
                                            child: RepaintBoundary(
                                              key: _modelCaptureKey,
                                              child: Live2DView(
                                                controller: _controller,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      ValueListenableBuilder<bool>(
                                        valueListenable: _borderVisible,
                                        builder: (context, visible, _) =>
                                            visible
                                            ? IgnorePointer(
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: theme.danger,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!_isVideo)
                      ValueListenableBuilder<Live2DViewState>(
                        valueListenable: _controller,
                        builder: (context, state, _) {
                          final error = state.lastError;
                          final showPlaceholder =
                              _isSwitchingModel || error != null;
                          if (!showPlaceholder) return const SizedBox.shrink();

                          final progress = state.modelLoadProgress.clamp(
                            0.0,
                            1.0,
                          );
                          final percent = (progress * 100).round();
                          return Positioned(
                            left: 0,
                            right: 0,
                            bottom: modelBottomInset,
                            height: math.max(
                              0.0,
                              layoutHeight - modelBottomInset,
                            ),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: error == null
                                  ? null
                                  : () => _loadModel(_selectedModel),
                              child: MouseRegion(
                                cursor: error == null
                                    ? MouseCursor.defer
                                    : SystemMouseCursors.click,
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 250,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (error == null) ...[
                                          const DSLoadingDots(size: 10),
                                          SizedBox(height: theme.spacing.md),
                                          Text(
                                            '${_loadStageLabel(state.modelLoadStage)} '
                                            '$percent%',
                                            textAlign: TextAlign.center,
                                            style: DsTypography.body.copyWith(
                                              color: theme.text,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(height: theme.spacing.sm),
                                          DSLinearProgress(
                                            value: progress,
                                            height: 8,
                                          ),
                                          SizedBox(height: theme.spacing.sm),
                                          Text(
                                            _selectedModel.label,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: DsTypography.caption
                                                .copyWith(color: theme.textSub),
                                          ),
                                        ] else ...[
                                          DsIcon(
                                            DsIconKind.refresh,
                                            size: 30,
                                            color: theme.danger,
                                          ),
                                          SizedBox(height: theme.spacing.md),
                                          Text(
                                            'screens_jellyLive2dLoadFailed'.tr,
                                            textAlign: TextAlign.center,
                                            style: DsTypography.body.copyWith(
                                              color: theme.danger,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(height: theme.spacing.sm),
                                          Text(
                                            _loadErrorMessage(error),
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: DsTypography.caption
                                                .copyWith(color: theme.textSub),
                                          ),
                                          SizedBox(height: theme.spacing.md),
                                          Text(
                                            'screens_jellyLive2dTapToReload'.tr,
                                            style: DsTypography.caption
                                                .copyWith(
                                                  color: theme.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    _buildBubbleInContainer(
                      width: layoutWidth,
                      height: math.max(0.0, layoutHeight - widget.topInset),
                      topInset: widget.topInset,
                    ),
                    // 子栏图标驱动的资源条：悬浮在底部导航（含其向上溢出的
                    // 弧顶绘制区）之上
                    if (widget.panel != null)
                      ValueListenableBuilder<JellyLive2dPanel?>(
                        valueListenable: widget.panel!,
                        builder: (context, activePanel, _) {
                          if (activePanel == null) {
                            return const SizedBox.shrink();
                          }
                          return Positioned(
                            left: theme.spacing.lg,
                            right: theme.spacing.lg,
                            bottom:
                                navigationPadding +
                                _radialDockOverflowTop +
                                theme.spacing.xs,
                            child: _buildResourceStrip(activePanel),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
