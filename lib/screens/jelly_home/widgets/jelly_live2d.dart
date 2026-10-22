import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
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

final Random _random = Random();

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
    this.fill = false,
    this.fitContainer = false,
    this.topInset = 0,
    this.panel,
    this.statusPanel,
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

  /// 底部资源面板开关（由底部导航子栏图标驱动）：
  /// 值非空时在底部导航上方展示水平可滚动的资源列表
  final ValueListenable<JellyLive2dPanel?>? panel;

  /// 宿主提供的状态面板，与其他资源共用底部资源条展示。
  final Widget? statusPanel;

  @override
  State<JellyLive2D> createState() => _JellyLive2DState();
}

class _JellyLive2DState extends State<JellyLive2D> {
  final Live2DViewController _controller = Live2DViewController();
  final ValueNotifier<double> _size = ValueNotifier<double>(_defaultSize);
  final GlobalKey _modelCaptureKey = GlobalKey();
  late Live2DModelDefinition _selectedModel =
      widget.initialModel ?? availableJellyLive2DModels.first;
  JellyLive2DCropRegion _cropRegion = const JellyLive2DCropRegion.full();
  bool _isSwitchingModel = true;
  Live2DMotionDefinition? _pendingMotion;

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
  String? _lastBubbleMessage;

  @override
  void didUpdateWidget(covariant JellyLive2D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != null && widget.message != oldWidget.message) {
      _showBubble(widget.message!, streaming: widget.streaming);
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
  }

  @override
  void initState() {
    super.initState();
    // macOS 上平台视图会吃掉鼠标事件（WKWebView 默认弹 Reload 菜单），
    // 原生侧拦截后经 onContextMenu 回调转发到这里
    _controller.onContextMenu = _showControls;
    // 点击事件同样由原生侧经 onTap 转发（含 hit area 判定结果）
    _controller.onTap = _handleTap;
    _controller.addListener(_onViewStateChanged);
    widget.motionRequest?.addListener(_handleMotionRequest);
    _loadSavedCropRegion(_selectedModel);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _loadSavedSize();
    await _loadSavedBubblePosition();
    if (!mounted) return;
    // Wait until the first finite layout is committed. The native view must
    // not be loaded against the temporary constraints from the first build.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    // The home screen's bottom navigation reports its final safe area one or
    // two frames after the first layout. Give that resize time to settle
    // before creating the native viewport.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _loadModel(_selectedModel);
  }

  @override
  void dispose() {
    widget.motionRequest?.removeListener(_handleMotionRequest);
    _controller.removeListener(_onViewStateChanged);
    _bubbleTimer?.cancel();
    _bubbleResumeTimer?.cancel();
    _size.dispose();
    _hitAreasVisible.dispose();
    _borderVisible.dispose();
    _controller.dispose();
    super.dispose();
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
            modelViewportAspectRatio: _modelViewportAspectRatio,
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
          // 360px viewport blurs mobile rendering and can leave platform-view
          // bounds and hit-test coordinates out of sync with the model.
          final viewportLayout = computeJellyLive2DViewportLayout(
            displaySize: displaySize,
            baseViewportHeight: _defaultSize,
            useResizableViewport:
                !kIsWeb &&
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
                                defaultTargetPlatform == TargetPlatform.android
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
                                    builder: (context, visible, _) => visible
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
                          height: max(0.0, layoutHeight - modelBottomInset),
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
                                          style: DsTypography.caption.copyWith(
                                            color: theme.textSub,
                                          ),
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
                                          style: DsTypography.caption.copyWith(
                                            color: theme.textSub,
                                          ),
                                        ),
                                        SizedBox(height: theme.spacing.md),
                                        Text(
                                          'screens_jellyLive2dTapToReload'.tr,
                                          style: DsTypography.caption.copyWith(
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
                      height: max(0.0, layoutHeight - widget.topInset),
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
