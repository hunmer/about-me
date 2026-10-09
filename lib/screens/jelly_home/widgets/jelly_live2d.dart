import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:live2d_flutter/live2d_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';

import '../live2d_online_models.dart';
import 'jelly_live2d_crop_dialog.dart';
import 'jelly_live2d_crop_region.dart';
import 'jelly_live2d_interaction.dart';
import 'jelly_live2d_layout.dart';
import 'jelly_speech_bubble.dart';
import 'bubble_region_editor.dart';
import 'jelly_configurable_image.dart';
import 'jelly_live2d_panel.dart';
import 'jelly_status_panel_settings.dart';

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
    this.panel,
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

  /// 外部（如 Live2D 设置页的动作列表）请求播放动作的通道；
  /// 模型未就绪时挂起，加载完成后自动播放
  final ValueListenable<Live2DMotionDefinition?>? motionRequest;

  /// 底部资源面板开关（由底部导航子栏图标驱动）：
  /// 值非空时在底部导航上方展示水平可滚动的资源列表
  final ValueListenable<JellyLive2dPanel?>? panel;

  @override
  State<JellyLive2D> createState() => _JellyLive2DState();
}

class _JellyLive2DState extends State<JellyLive2D> {
  static const _bubbleAssets = <String>[
    'assets/bubbles/可拉伸兔子聊天气泡素材.webp',
    'assets/bubbles/小猫聊天气泡.webp',
    'assets/bubbles/月亮晚安气泡.webp',
    'assets/bubbles/星星聊天气泡.webp',
    'assets/bubbles/小恐龙侧边气泡.webp',
    'assets/bubbles/樱桃回形针气泡.webp',
    'assets/bubbles/甜点蛋糕气泡.webp',
    'assets/bubbles/游戏机像素气泡.webp',
    'assets/bubbles/小熊聊天气泡.webp',
    'assets/bubbles/甜酷翅膀深色气泡.webp',
    'assets/bubbles/彩虹渐变气泡.webp',
    'assets/bubbles/奶茶杯气泡.webp',
    'assets/bubbles/云朵天使气泡.webp',
  ];

  /// 小屋内置背景图（assets/live2d_backgrounds/），null 表示无背景
  static const List<String> _backgroundAssets = [
    'assets/live2d_backgrounds/Live2D背景·冬日窗边.jpg',
    'assets/live2d_backgrounds/Live2D背景·放学教室.jpg',
    'assets/live2d_backgrounds/Live2D背景·海底珊瑚(深蓝冷调).jpg',
    'assets/live2d_backgrounds/Live2D背景·极简厨房(灰白冷调).jpg',
    'assets/live2d_backgrounds/Live2D背景·秋日银杏(金橙冷天).jpg',
    'assets/live2d_backgrounds/Live2D背景·森林露营(森绿冷调).jpg',
    'assets/live2d_backgrounds/Live2D背景·深夜办公室.jpg',
    'assets/live2d_backgrounds/Live2D背景·天台星空(雾紫靛蓝).jpg',
    'assets/live2d_backgrounds/Live2D背景·图书馆(冷灰绿).jpg',
    'assets/live2d_backgrounds/Live2D背景·卧室清晨.jpg',
    'assets/live2d_backgrounds/Live2D背景·夏日海边(冷蓝).jpg',
    'assets/live2d_backgrounds/Live2D背景·雪夜温泉(青灰冷调).jpg',
    'assets/live2d_backgrounds/Live2D背景·樱花长椅(樱粉雾白).jpg',
    'assets/live2d_backgrounds/Live2D背景·雨后街角.jpg',
    'assets/live2d_backgrounds/图片节点 1.jpg',
  ];

  /// 人物显示尺寸（逻辑像素，宽高一致），经 SharedPreferences 持久化
  static const double _defaultSize = 360;
  static const double _minSize = 200;
  static const double _maxSize = 560;
  static const double _sizeStep = 40;
  static const double _modelViewportAspectRatio = 0.5;
  static const double _fillBottomReserve = 92;
  // The floating-action radial dock paints 28px above its cropped layout
  // bounds via OverflowBox/Transform.translate.
  static const double _radialDockOverflowTop = 28;
  static const String _sizePrefKey = 'jelly_live2d.size';
  static const String _cropPrefKeyPrefix = 'jelly_live2d.crop.';

  final Live2DViewController _controller = Live2DViewController();
  final ValueNotifier<double> _size = ValueNotifier<double>(_defaultSize);
  final GlobalKey _modelCaptureKey = GlobalKey();
  late Live2DModelDefinition _selectedModel =
      widget.initialModel ?? _models.first;
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
  double _modelBottomInset = 0;

  /// 当前小屋背景图；null 表示不显示，经 Live2DPlugin 设置持久化
  String? _backgroundAsset = Live2DPlugin.instance.backgroundAsset;
  double _backgroundBlur = Live2DPlugin.instance.backgroundBlur;
  double _backgroundOpacity = Live2DPlugin.instance.backgroundOpacity;

  /// 背景模糊上限（滑杆 0~1 映射到 sigma 0~20）
  static const double _backgroundBlurMax = 20;

  /// 当前气泡台词；null 表示不显示。连续点击时替换内容并重置计时
  String? _bubbleMessage;
  bool _bubbleStreaming = false;
  Timer? _bubbleTimer;
  Timer? _bubbleResumeTimer;
  String? _lastBubbleMessage;

  /// 气泡展示时长
  static const Duration _minimumBubbleDuration = Duration(seconds: 6);
  static const Duration _maximumBubbleDuration = Duration(seconds: 30);

  /// 随机台词池：命中头部 / 命中身体 / 点空（未命中任何区域）。
  /// 翻译需运行时解析，用 getter 每次取当前语言
  static List<String> get _headMessages => [
    'screens_jellyLive2dTapHead1'.tr,
    'screens_jellyLive2dTapHead2'.tr,
    'screens_jellyLive2dTapHead3'.tr,
    'screens_jellyLive2dTapHead4'.tr,
  ];
  static List<String> get _bodyMessages => [
    'screens_jellyLive2dPokeBody1'.tr,
    'screens_jellyLive2dPokeBody2'.tr,
    'screens_jellyLive2dPokeBody3'.tr,
    'screens_jellyLive2dPokeBody4'.tr,
  ];
  static List<String> get _missMessages => [
    'screens_jellyLive2dMiss1'.tr,
    'screens_jellyLive2dMiss2'.tr,
    'screens_jellyLive2dMiss3'.tr,
    'screens_jellyLive2dMiss4'.tr,
  ];
  static final Random _random = Random();

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

  Future<void> _playReaction() async {
    if (_isSwitchingModel || !_controller.value.isLoaded) return;
    final candidates = _selectedModel.motions
        .where((motion) => motion.group.toLowerCase() != 'idle')
        .toList();
    if (candidates.isEmpty) return;
    final motion = candidates[_random.nextInt(candidates.length)];
    try {
      await _controller.startMotion(group: motion.group, index: motion.index);
    } on Live2DException {
      // 动作播放失败时保持当前动作，不打断交互
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

  Future<void> _loadSavedSize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_sizePrefKey);
    if (saved != null && saved >= _minSize && saved <= _maxSize) {
      _size.value = saved;
    }
  }

  Future<void> _changeSize(double delta) async {
    final next = (_size.value + delta).clamp(_minSize, _maxSize);
    if (next == _size.value) return;
    _size.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sizePrefKey, next);
  }

  Future<void> _resetSize() async {
    if (_size.value == _defaultSize) return;
    _size.value = _defaultSize;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sizePrefKey, _defaultSize);
  }

  /// 切换小屋背景图；null 表示关闭背景，选择后立即生效并持久化
  Future<void> _selectBackground(String? asset) async {
    if (asset == _backgroundAsset) return;
    setState(() => _backgroundAsset = asset);
    await Live2DPlugin.instance.setBackgroundAsset(asset);
  }

  /// 上传自定义背景图：保存到应用目录、加入自定义列表并立即选用
  Future<void> _uploadCustomBackground(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          const ImagePickerDialog(saveDirectory: 'live2d/backgrounds'),
    );
    final asset = result?['url'] as String?;
    if (asset == null || asset.isEmpty) return;
    await Live2DPlugin.instance.addCustomBackgroundAsset(asset);
    if (!mounted) return;
    setState(() => _backgroundAsset = asset);
  }

  /// 滑杆拖动中实时预览：setState 刷新页面背景，setSheetState 刷新
  /// 设置弹出层内的滑杆
  void _previewBackground(VoidCallback apply, [StateSetter? setSheetState]) {
    setState(apply);
    setSheetState?.call(() {});
  }

  String _cropPrefKey(Live2DModelDefinition model) {
    final identity = base64UrlEncode(
      utf8.encode('${model.modelDir}${model.modelFile}'),
    );
    return '$_cropPrefKeyPrefix$identity';
  }

  /// 模型身份按目录 + 文件名判定（在线模型每次都会生成新实例，不能比较引用）
  bool _isSameModel(Live2DModelDefinition a, Live2DModelDefinition b) =>
      a.modelDir == b.modelDir && a.modelFile == b.modelFile;

  Future<void> _loadSavedCropRegion(Live2DModelDefinition model) async {
    final prefs = await SharedPreferences.getInstance();
    final region = JellyLive2DCropRegion.parse(
      prefs.getString(_cropPrefKey(model)),
    );
    if (!mounted || _isSameModel(model, _selectedModel)) return;
    setState(() => _cropRegion = region);
  }

  Future<void> _saveCropRegion(JellyLive2DCropRegion region) async {
    setState(() => _cropRegion = region);
    final prefs = await SharedPreferences.getInstance();
    final key = _cropPrefKey(_selectedModel);
    if (region.isFull) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, region.encode());
    }
  }

  /// 切换可点击区域（HitAreas）红色叠加层；模型未加载或平台不支持时忽略
  Future<void> _toggleHitAreas(bool visible) async {
    _hitAreasVisible.value = visible;
    try {
      await _controller.setHitAreasVisible(visible);
    } on Live2DException {
      // 平台不支持时静默忽略
    }
  }

  /// 点击角色：先通知宿主（陪伴数值互动），再播放动作 + 随机台词气泡
  void _handleTap(String? hitAreaId, String? hitAreaName, double x, double y) {
    if (_isSwitchingModel) return;
    if (_controller.value.lastError != null) {
      unawaited(_loadModel(_selectedModel));
      return;
    }
    if (!_controller.value.isLoaded) return;
    widget.onTap?.call(hitAreaId, hitAreaName);
    if (!hasJellyLive2DHitArea(hitAreaId, hitAreaName)) {
      return;
    }
    _playTapMotion(hitAreaId: hitAreaId, hitAreaName: hitAreaName);
    _showBubble(_pickBubbleMessage(hitAreaId, hitAreaName));
  }

  /// 按命中区域挑一条随机台词，避免和上一条重复
  String _pickBubbleMessage(String? hitAreaId, String? hitAreaName) {
    final area = (hitAreaName != null && hitAreaName.isNotEmpty)
        ? hitAreaName
        : hitAreaId?.replaceFirst('HitArea', '') ?? '';
    final lower = area.toLowerCase();
    final List<String> pool;
    if (lower.contains('head') || area.contains('头')) {
      pool = _headMessages;
    } else if (lower.contains('body') || area.contains('身')) {
      pool = _bodyMessages;
    } else if (area.isNotEmpty) {
      pool = _bodyMessages;
    } else {
      pool = _missMessages;
    }
    var index = _random.nextInt(pool.length);
    if (pool[index] == _lastBubbleMessage && pool.length > 1) {
      index = (index + 1) % pool.length;
    }
    _lastBubbleMessage = pool[index];
    return pool[index];
  }

  /// 展示气泡；消失计时从打字效果完成后才算（见 [_onBubbleTyped]），
  /// 连续点击时直接换台词重新打字
  void _showBubble(String message, {bool streaming = false}) {
    _bubbleTimer?.cancel();
    setState(() {
      _bubbleMessage = message;
      _bubbleStreaming = streaming;
    });
  }

  /// 台词逐字浮现完毕：从现在起再展示 [_bubbleDuration] 后收起
  void _onBubbleTyped() {
    _bubbleTimer?.cancel();
    final length = _bubbleMessage?.runes.length ?? 0;
    final seconds = (6 + (length ~/ 80) * 4).clamp(
      _minimumBubbleDuration.inSeconds,
      _maximumBubbleDuration.inSeconds,
    );
    _bubbleTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) {
        setState(() => _bubbleMessage = null);
      }
    });
  }

  Widget _buildBubbleInContainer({
    required double width,
    required double height,
  }) {
    final message = _bubbleMessage;
    if (message == null) return const SizedBox.shrink();
    const margin = 12.0;
    const gap = 8.0;
    const bubbleBaseWidth = 288.0;
    const bubbleBaseHeight = 150.0;
    final availableWidth = max(0.0, width - margin * 2);
    final availableHeight = max(0.0, height);
    final bubbleWidth = min(
      min(_displaySize * 0.8, availableWidth),
      availableHeight * bubbleBaseWidth / bubbleBaseHeight,
    );
    if (bubbleWidth <= 0) return const SizedBox.shrink();
    final bubbleScale = bubbleWidth / bubbleBaseWidth;
    final bubbleHeight = bubbleBaseHeight * bubbleScale;
    // The model is bottom-aligned in the container. Keep the bubble anchored
    // to the model viewport's top even when that point is above the container
    // (regular mode uses a viewport as tall as the container).
    final modelTop = height - _modelBottomInset - _displaySize;
    final top = modelTop - gap - bubbleHeight;
    final left = ((width - bubbleWidth) / 2).clamp(
      margin,
      width - margin - bubbleWidth,
    );

    return Positioned(
      left: left,
      top: top,
      width: bubbleWidth,
      height: bubbleHeight,
      child: AppTheme(
        data: AppTheme.of(context),
        child: JellySpeechBubble(
          key: const ValueKey('live2d-speech-bubble'),
          text: message,
          modelName: _selectedModel.label,
          bubbleAsset: Live2DPlugin.instance.bubbleAsset,
          customRegions: BubbleTextRegions.fromSettings(
            Live2DPlugin.instance.bubbleAsset,
            Live2DPlugin.instance.bubbleRegions,
          ),
          streaming: _bubbleStreaming,
          typingInterval: widget.typingInterval,
          onUserInteract: _pauseBubbleHide,
          onTypingComplete: _onBubbleTyped,
        ),
      ),
    );
  }

  void _pauseBubbleHide() {
    if (_bubbleMessage == null) return;
    _bubbleTimer?.cancel();
    _bubbleResumeTimer?.cancel();
    _bubbleResumeTimer = Timer(const Duration(seconds: 2), _onBubbleTyped);
  }

  /// 点击命中可点击区域后挑选动作。模型有语音时优先随机选择带
  /// Sound 的动作；同时优先匹配 Cubism 惯例的 Tap<区域> 分组。
  Future<void> _playTapMotion({String? hitAreaId, String? hitAreaName}) async {
    // Mao 的 HitArea Name 为空，用 Id（HitAreaHead → Head）补齐
    final area = (hitAreaName != null && hitAreaName.isNotEmpty)
        ? hitAreaName
        : hitAreaId?.replaceFirst('HitArea', '') ?? '';

    final areaGroup = area.isEmpty ? null : 'tap${area.toLowerCase()}';
    final exact = areaGroup == null
        ? const <Live2DMotionDefinition>[]
        : _selectedModel.motions
              .where((motion) => motion.group.toLowerCase() == areaGroup)
              .toList();
    final genericTap = _selectedModel.motions
        .where((motion) => motion.group.toLowerCase() == 'tap')
        .toList();
    final voiced = _selectedModel.motions
        .where((motion) => motion.hasSound)
        .toList();

    List<Live2DMotionDefinition> candidates = exact
        .where((motion) => motion.hasSound)
        .toList();
    if (candidates.isEmpty) {
      candidates = genericTap.where((motion) => motion.hasSound).toList();
    }
    if (candidates.isEmpty) candidates = voiced;
    if (candidates.isEmpty) candidates = exact;
    if (candidates.isEmpty) candidates = genericTap;
    if (candidates.isEmpty) {
      candidates = _selectedModel.motions
          .where((motion) => motion.group == '')
          .toList();
    }
    if (candidates.isEmpty) {
      candidates = _selectedModel.motions
          .where((motion) => motion.group.toLowerCase() != 'idle')
          .toList();
    }
    if (candidates.isEmpty) return;

    final motion = candidates[_random.nextInt(candidates.length)];
    try {
      // priority 3 = force，确保盖过 Idle 让动作明显可见
      await _controller.startMotion(
        group: motion.group,
        index: motion.index,
        priority: 3,
      );
    } on Live2DException {
      // 动作播放失败时保持当前动作，不打断交互
    }
  }

  Future<void> _loadModel(Live2DModelDefinition model) async {
    if (mounted) {
      _bubbleTimer?.cancel();
      setState(() {
        _isSwitchingModel = true;
        _bubbleMessage = null;
      });
    }
    try {
      final localModel = await Live2DOnlineCatalog.cacheDefinition(model);
      await _controller.whenAttached;
      if (!mounted) return;
      if (_controller.value.isLoaded) {
        await _controller.unloadModel();
      }
      await _controller.loadModel(
        modelDir: localModel.modelDir,
        modelFileName: localModel.modelFile,
      );
    } on Live2DException {
      // The controller exposes the detailed error through Live2DViewState.
    } finally {
      if (mounted) setState(() => _isSwitchingModel = false);
    }
  }

  Future<void> _selectModel(Live2DModelDefinition model) async {
    if (_isSameModel(model, _selectedModel) ||
        _isSwitchingModel ||
        _controller.value.isLoadingModel) {
      return;
    }
    setState(() {
      _selectedModel = model;
      _cropRegion = const JellyLive2DCropRegion.full();
    });
    await _loadSavedCropRegion(model);
    await _loadModel(model);
  }

  /// 外部动作请求：模型未就绪时挂起，由 [_onViewStateChanged] 在加载完成后播放
  void _handleMotionRequest() {
    final motion = widget.motionRequest?.value;
    if (motion == null) return;
    if (_isSwitchingModel || !_controller.value.isLoaded) {
      _pendingMotion = motion;
      return;
    }
    _startMotion(motion);
  }

  void _onViewStateChanged() {
    final pending = _pendingMotion;
    if (pending == null) return;
    if (_controller.value.lastError != null) {
      _pendingMotion = null;
    } else if (!_isSwitchingModel && _controller.value.isLoaded) {
      _pendingMotion = null;
      _startMotion(pending);
    }
  }

  Future<void> _startMotion(Live2DMotionDefinition motion) async {
    try {
      await _controller.startMotion(
        group: motion.group,
        index: motion.index,
        priority: 3,
      );
    } on Live2DException {
      // 动作播放失败时保持当前动作，不打断交互
    }
  }

  Future<({Uint8List bytes, Size size})> _captureFullModel() async {
    if (!_controller.value.isLoaded || _isSwitchingModel) {
      throw StateError('screens_jellyLive2dModelNotLoaded'.tr);
    }

    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _modelCaptureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('screens_jellyLive2dCaptureUnavailable'.tr);
    }

    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = rgba?.buffer.asUint8List();
      if (pixels == null || !_containsVisiblePixel(pixels)) {
        throw StateError('screens_jellyLive2dCaptureUnsupported'.tr);
      }
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw StateError('screens_jellyLive2dCaptureEncodeFailed'.tr);
      }
      return (
        bytes: png.buffer.asUint8List(),
        size: Size(image.width.toDouble(), image.height.toDouble()),
      );
    } finally {
      image.dispose();
    }
  }

  bool _containsVisiblePixel(Uint8List rgba) {
    const pixelStride = 4;
    const sampleStride = pixelStride * 16;
    for (var i = 3; i < rgba.length; i += sampleStride) {
      if (rgba[i] > 8) return true;
    }
    return false;
  }

  Future<void> _openCropEditor(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final capture = await _captureFullModel();
      if (!mounted) return;
      final region = await showJellyLive2DCropDialog(
        context: context,
        image: capture.bytes,
        imageSize: capture.size,
        initialRegion: _cropRegion,
      );
      if (region != null && mounted) await _saveCropRegion(region);
    } catch (error) {
      if (!mounted) return;
      await showDSDialog<void>(
        context: context,
        builder: (dialogContext) => DSDialog(
          title: 'screens_jellyLive2dCropErrorTitle'.tr,
          message: error.toString().replaceFirst('Bad state: ', ''),
          confirmText: 'screens_jellyLive2dGotIt'.tr,
          onConfirm: () => Navigator.of(dialogContext).pop(),
        ),
      );
    }
  }

  String _loadStageLabel(String? stage) {
    return switch (stage) {
      'preparing' => 'screens_jellyLive2dLoadStagePreparing'.tr,
      'model-config' => 'screens_jellyLive2dLoadStageModelConfig'.tr,
      'model-data' => 'screens_jellyLive2dLoadStageModelData'.tr,
      'components' => 'screens_jellyLive2dLoadStageComponents'.tr,
      'motions' => 'screens_jellyLive2dLoadStageMotions'.tr,
      'textures' => 'screens_jellyLive2dLoadStageTextures'.tr,
      'complete' => 'screens_jellyLive2dLoadStageComplete'.tr,
      _ => 'screens_jellyLive2dLoadStageLoading'.tr,
    };
  }

  String _loadErrorMessage(Live2DException error) {
    return error.message.split('\n').first.trim();
  }

  /// 把选中档案持久化为默认显示，并立即切换到该档案的模型
  Future<void> _selectArchive(Live2DArchive archive) async {
    final plugin = Live2DPlugin.instance;
    if (archive.id == plugin.selectedId) return;
    plugin.selectedId = archive.id;
    await plugin.save();
    final model = modelDefinitionForArchive(archive);
    if (model != null) await _selectModel(model);
  }

  Future<void> _uploadCustomBubble(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const ImagePickerDialog(saveDirectory: 'live2d/bubbles'),
    );
    final asset = result?['url'] as String?;
    if (asset == null || asset.isEmpty) return;
    await Live2DPlugin.instance.addCustomBubbleAsset(asset);
    if (!context.mounted) return;
    final regions = await showBubbleRegionEditor(
      context: context,
      asset: asset,
      initial: BubbleTextRegions.forAsset(asset),
    );
    if (regions != null) {
      await _applyBubbleRegions(asset, regions);
    }
    if (mounted) setState(() {});
  }

  void _showControls() {
    showDSBottomSheet<void>(
      context: context,
      title: 'Live2D',
      builder: (sheetContext) {
        final theme = AppTheme.of(sheetContext);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            theme.spacing.xl,
            0,
            theme.spacing.xl,
            theme.spacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (sheetContext, setSheetState) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'screens_jellyLive2dArchives'.tr,
                      style: DsTypography.heading.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    if (Live2DPlugin.instance.archives.isEmpty)
                      Text(
                        'screens_jellyLive2dNoArchives'.tr,
                        style: DsTypography.body.copyWith(color: theme.textSub),
                      )
                    else
                      Wrap(
                        spacing: theme.spacing.sm,
                        runSpacing: theme.spacing.sm,
                        children: [
                          for (final archive in Live2DPlugin.instance.archives)
                            DSChip(
                              label: archive.name,
                              selected:
                                  archive.id ==
                                  Live2DPlugin.instance.selectedId,
                              onSelected: (_) {
                                setSheetState(() {});
                                _selectArchive(archive);
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(height: theme.spacing.xl),
              Text(
                'screens_jellyLive2dCharacterSize'.tr,
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.sm),
              ValueListenableBuilder<double>(
                valueListenable: _size,
                builder: (context, size, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: 'screens_jellyLive2dShrink'.tr,
                            size: DSButtonSize.sm,
                            onPressed: size > _minSize
                                ? () => _changeSize(-_sizeStep)
                                : null,
                          ),
                        ),
                        SizedBox(width: theme.spacing.sm),
                        Expanded(
                          child: DSButton(
                            label: 'screens_jellyLive2dEnlarge'.tr,
                            size: DSButtonSize.sm,
                            onPressed: size < _maxSize
                                ? () => _changeSize(_sizeStep)
                                : null,
                          ),
                        ),
                        SizedBox(width: theme.spacing.sm),
                        Expanded(
                          child: DSButton(
                            label: 'screens_jellyLive2dReset'.tr,
                            size: DSButtonSize.sm,
                            onPressed: size == _defaultSize ? null : _resetSize,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: theme.spacing.sm),
                    Text(
                      'screens_jellyLive2dCurrentSize'.trParams({
                        'percent': (size / _defaultSize * 100)
                            .round()
                            .toString(),
                        'size': size.round().toString(),
                      }),
                      textAlign: TextAlign.center,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: theme.spacing.xl),
              Text(
                'screens_jellyLive2dDisplayArea'.tr,
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.sm),
              DSListItem(
                title: 'screens_jellyLive2dSetCropRegion'.tr,
                subtitle: _cropRegion.isFull
                    ? 'screens_jellyLive2dCropFullModel'.tr
                    : 'screens_jellyLive2dCropApplied'.tr,
                leading: DsIcon(
                  DsIconKind.image,
                  size: 18,
                  color: theme.primary,
                ),
                trailing: DsIcon(
                  DsIconKind.chevronRight,
                  size: 18,
                  color: theme.textSub,
                ),
                onTap: _controller.value.isLoaded && !_isSwitchingModel
                    ? () => _openCropEditor(sheetContext)
                    : null,
              ),
              SizedBox(height: theme.spacing.sm),
              ValueListenableBuilder<bool>(
                valueListenable: _borderVisible,
                builder: (context, visible, _) => DSListItem(
                  title: 'screens_jellyLive2dShowBorder'.tr,
                  subtitle: 'screens_jellyLive2dShowBorderDesc'.tr,
                  leading: DsIcon(
                    DsIconKind.image,
                    size: 18,
                    color: theme.primary,
                  ),
                  trailing: DSSwitch(
                    value: visible,
                    semanticLabel: 'screens_jellyLive2dShowBorderSemantic'.tr,
                    onChanged: (value) => _borderVisible.value = value,
                  ),
                ),
              ),
              SizedBox(height: theme.spacing.xl),
              Text(
                'screens_jellyLive2dHitAreas'.tr,
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.sm),
              ValueListenableBuilder<bool>(
                valueListenable: _hitAreasVisible,
                builder: (context, visible, _) => DSChip(
                  label: visible
                      ? 'screens_jellyLive2dEnabled'.tr
                      : 'screens_jellyLive2dDisabled'.tr,
                  selected: visible,
                  onSelected: (_) => _toggleHitAreas(!visible),
                ),
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                'screens_jellyLive2dHitAreasDesc'.tr,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 底部资源条：导航栏子栏图标点开后，在底部导航上方水平滚动展示资源；
  /// 点击缩略图切换，角标按钮进入对应编辑器
  Widget _buildResourceStrip(JellyLive2dPanel panel) {
    final theme = AppTheme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.92),
        borderRadius: theme.radii.lg,
        border: Border.all(color: theme.stroke),
        boxShadow: theme.shadows.soft,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: switch (panel) {
          JellyLive2dPanel.bubble => _buildBubbleStrip(theme),
          JellyLive2dPanel.background => _buildBackgroundStrip(theme),
          JellyLive2dPanel.statusPanel => _buildStatusPanelStrip(theme),
        },
      ),
    );
  }

  Widget _buildBubbleStrip(AppThemeData theme) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final asset in [
            ..._bubbleAssets,
            ...Live2DPlugin.instance.customBubbleAssets,
          ])
            Padding(
              padding: EdgeInsets.only(right: theme.spacing.sm),
              child: _bubbleTile(theme, asset),
            ),
          _addTile(
            theme,
            width: 72,
            height: 48,
            iconSize: 22,
            onTap: () => _uploadCustomBubble(context),
          ),
        ],
      ),
    );
  }

  Widget _bubbleTile(AppThemeData theme, String asset) {
    return GestureDetector(
      onTap: () async {
        await Live2DPlugin.instance.setBubbleAsset(asset);
        if (mounted) setState(() {});
      },
      child: Container(
        width: 72,
        height: 48,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(
            color: asset == Live2DPlugin.instance.bubbleAsset
                ? theme.primary
                : theme.surface.withValues(alpha: 0),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            JellyConfigurableImage(path: asset, fit: BoxFit.contain),
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _editBubbleRegions(asset),
                child: DsIcon(DsIconKind.image, size: 16, color: theme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBubbleRegions(String asset) async {
    final regions = await showBubbleRegionEditor(
      context: context,
      asset: asset,
      initial: BubbleTextRegions.fromSettings(
        asset,
        Live2DPlugin.instance.bubbleRegions,
      ),
    );
    if (regions == null) return;
    await _applyBubbleRegions(asset, regions);
  }

  Future<void> _applyBubbleRegions(
    String asset,
    BubbleTextRegions regions,
  ) async {
    await Live2DPlugin.instance.setBubbleRegions(asset, {
      'nameLeft': regions.modelName.left,
      'nameTop': regions.modelName.top,
      'nameRight': regions.modelName.right,
      'nameBottom': regions.modelName.bottom,
      'messageLeft': regions.message.left,
      'messageTop': regions.message.top,
      'messageRight': regions.message.right,
      'messageBottom': regions.message.bottom,
    });
    if (mounted) setState(() {});
  }

  Widget _buildBackgroundStrip(AppThemeData theme) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: theme.spacing.sm),
                  child: GestureDetector(
                    onTap: () => _selectBackground(null),
                    child: Container(
                      width: 72,
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _backgroundAsset == null
                              ? theme.primary
                              : theme.stroke,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: DsIcon(
                          DsIconKind.block,
                          size: 20,
                          color: theme.textSub,
                        ),
                      ),
                    ),
                  ),
                ),
                for (final asset in [
                  ..._backgroundAssets,
                  ...Live2DPlugin.instance.customBackgroundAssets,
                ])
                  Padding(
                    padding: EdgeInsets.only(right: theme.spacing.sm),
                    child: GestureDetector(
                      onTap: () => _selectBackground(asset),
                      child: Container(
                        width: 72,
                        height: 48,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: asset == _backgroundAsset
                                ? theme.primary
                                : theme.surface.withValues(alpha: 0),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: JellyConfigurableImage(
                          path: asset,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                _addTile(
                  theme,
                  width: 72,
                  height: 48,
                  iconSize: 22,
                  onTap: () => _uploadCustomBackground(context),
                ),
              ],
            ),
          ),
          // 背景生效时尾随固定的调节按钮：点击弹出模糊/不透明度设置层
          if (_backgroundAsset != null) ...[
            SizedBox(width: theme.spacing.md),
            Container(width: 1, height: 36, color: theme.stroke),
            SizedBox(width: theme.spacing.md),
            _backgroundSettingsButton(theme),
          ],
        ],
      ),
    );
  }

  /// 背景调节按钮：点击弹出模糊 / 不透明度设置层
  Widget _backgroundSettingsButton(AppThemeData theme) {
    return GestureDetector(
      onTap: _openBackgroundSettings,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.surfaceAlt,
          border: Border.all(color: theme.stroke),
        ),
        child: Center(
          child: DsIcon(DsIconKind.tune, size: 18, color: theme.primary),
        ),
      ),
    );
  }

  /// 背景调节弹出层：滑杆拖动实时预览，松手持久化
  Future<void> _openBackgroundSettings() {
    return showDSBottomSheet<void>(
      context: context,
      title: '背景设置',
      builder: (sheetContext) {
        final theme = AppTheme.of(sheetContext);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            theme.spacing.xl,
            0,
            theme.spacing.xl,
            theme.spacing.md,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '背景模糊',
                  style: DsTypography.label.copyWith(color: theme.text),
                ),
                DSSlider(
                  value: (_backgroundBlur / _backgroundBlurMax).clamp(
                    0.0,
                    1.0,
                  ),
                  onChanged: (ratio) => _previewBackground(
                    () => _backgroundBlur = ratio * _backgroundBlurMax,
                    setSheetState,
                  ),
                  onChangeEnd: (ratio) => Live2DPlugin.instance
                      .setBackgroundBlur(ratio * _backgroundBlurMax),
                ),
                SizedBox(height: theme.spacing.sm),
                Text(
                  '背景不透明度',
                  style: DsTypography.label.copyWith(color: theme.text),
                ),
                DSSlider(
                  value: _backgroundOpacity.clamp(0.0, 1.0),
                  onChanged: (ratio) => _previewBackground(
                    () => _backgroundOpacity = ratio,
                    setSheetState,
                  ),
                  onChangeEnd: (ratio) =>
                      Live2DPlugin.instance.setBackgroundOpacity(ratio),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusPanelStrip(AppThemeData theme) {
    unawaited(JellyStatusPanelSettings.instance.load());
    final settings = JellyStatusPanelSettings.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => SizedBox(
        height: 104,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final style in settings.styles)
              Padding(
                padding: EdgeInsets.only(right: theme.spacing.sm),
                child: _statusPanelTile(theme, settings, style),
              ),
            _addTile(
              theme,
              width: 132,
              height: 104,
              iconSize: 24,
              onTap: () => settings.upload(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPanelTile(
    AppThemeData theme,
    JellyStatusPanelSettings settings,
    JellyStatusPanelStyle style,
  ) {
    return GestureDetector(
      onTap: () => settings.selectStyle(style.id),
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
            color: style.id == settings.selectedStyle.id
                ? theme.primary
                : theme.stroke,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  JellyConfigurableImage(
                    path: style.asset,
                    fit: BoxFit.contain,
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        await settings.selectStyle(style.id);
                        if (mounted) await settings.edit(context);
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.surface.withValues(alpha: 0.9),
                        ),
                        child: Center(
                          child: DsIcon(
                            DsIconKind.edit,
                            size: 14,
                            color: theme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 2),
            Text(
              style.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.label.copyWith(color: theme.text),
            ),
          ],
        ),
      ),
    );
  }

  /// 资源条尾部的“添加自定义资源”占位块
  Widget _addTile(
    AppThemeData theme, {
    required double width,
    required double height,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: theme.stroke),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: DsIcon(DsIconKind.plus, size: iconSize, color: theme.primary),
        ),
      ),
    );
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
            containerHeight: containerHeight,
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
          // Windows uses a Flutter Texture and can re-render the model at the
          // target size. Other platforms retain the established fixed native
          // viewport plus composited scaling behavior.
          final viewportLayout = computeJellyLive2DViewportLayout(
            displaySize: displaySize,
            baseViewportHeight: _defaultSize,
            useResizableViewport:
                !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
          );
          final viewportSize = Size(
            viewportLayout.viewportHeight * _modelViewportAspectRatio,
            viewportLayout.viewportHeight,
          );
          final modelScale = viewportLayout.scale;
          _displaySize = displaySize;
          _modelBottomInset = modelBottomInset;
          return AnimatedContainer(
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
                      opacity:
                          _isSwitchingModel ||
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

                      final progress = state.modelLoadProgress.clamp(0.0, 1.0);
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
                            child: ColoredBox(
                              color: theme.background.withValues(alpha: 0.96),
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
                        ),
                      );
                    },
                  ),
                  _buildBubbleInContainer(
                    width: layoutWidth,
                    height: layoutHeight,
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
          );
        },
      ),
    );
  }
}

const List<Live2DModelDefinition> _models = [
  Live2DModelDefinition(
    label: 'Mao',
    modelDir: 'assets/models/mao/',
    modelFile: 'mao_pro.model3.json',
    motions: [
      // label 存翻译 key，显示处需 .tr 解析
      Live2DMotionDefinition(
        group: 'Idle',
        index: 0,
        label: 'screens_jellyLive2dMotionIdle',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 0,
        label: 'screens_jellyLive2dMotion1',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 1,
        label: 'screens_jellyLive2dMotion2',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 2,
        label: 'screens_jellyLive2dMotion3',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 3,
        label: 'screens_jellyLive2dSpecialMotion1',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 4,
        label: 'screens_jellyLive2dSpecialMotion2',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 5,
        label: 'screens_jellyLive2dSpecialMotion3',
      ),
    ],
  ),
  Live2DModelDefinition(
    label: 'IceGirl',
    modelDir: 'assets/models/icegirl/',
    modelFile: 'IceGirl.model3.json',
    motions: [],
  ),
  Live2DModelDefinition(
    label: 'Ren',
    modelDir: 'assets/models/ren/',
    modelFile: 'ren.model3.json',
    motions: [
      Live2DMotionDefinition(
        group: 'Idle',
        index: 0,
        label: 'screens_jellyLive2dMotionIdle',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 0,
        label: 'screens_jellyLive2dMotion1',
      ),
      Live2DMotionDefinition(
        group: '',
        index: 1,
        label: 'screens_jellyLive2dMotion2',
      ),
    ],
  ),
];

List<Live2DModelDefinition> get availableJellyLive2DModels =>
    List.unmodifiable(_models);

/// 把 Live2D 存档转换为视图层模型定义（小屋页签与设置页共用）：
/// 优先匹配内置模型（带动作列表），否则按存档路径构造在线模型定义
Live2DModelDefinition? modelDefinitionForArchive(Live2DArchive? value) {
  if (value == null || value.modelLabel.isEmpty) return null;
  return availableJellyLive2DModels
          .where((model) => model.label == value.modelLabel)
          .firstOrNull ??
      Live2DModelDefinition(
        label: value.modelLabel,
        modelDir: value.modelDir,
        modelFile: value.modelFile,
        motions: const [],
        isOnline: value.modelDir.startsWith('http'),
      );
}
