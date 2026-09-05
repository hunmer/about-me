import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:live2d_flutter/live2d_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../live2d_online_model_page.dart';
import '../live2d_online_models.dart';
import 'jelly_live2d_crop_dialog.dart';
import 'jelly_live2d_crop_region.dart';
import 'jelly_speech_bubble.dart';

class JellyLive2D extends StatefulWidget {
  const JellyLive2D({super.key, this.onTap});

  /// 点击角色（命中或未命中可点击区域都会回调）时通知宿主，
  /// 用于衔接陪伴数值（情绪/好感度）等玩法
  final void Function(String? hitAreaId, String? hitAreaName)? onTap;

  @override
  State<JellyLive2D> createState() => _JellyLive2DState();
}

class _JellyLive2DState extends State<JellyLive2D> {
  /// 人物显示尺寸（逻辑像素，宽高一致），经 SharedPreferences 持久化
  static const double _defaultSize = 360;
  static const double _minSize = 200;
  static const double _maxSize = 560;
  static const double _sizeStep = 40;
  static const double _modelViewportAspectRatio = 0.5;
  static const String _sizePrefKey = 'jelly_live2d.size';
  static const String _cropPrefKeyPrefix = 'jelly_live2d.crop.';

  final Live2DViewController _controller = Live2DViewController();
  final ValueNotifier<double> _size = ValueNotifier<double>(_defaultSize);
  final GlobalKey _modelCaptureKey = GlobalKey();
  Live2DModelDefinition _selectedModel = _models.first;
  JellyLive2DCropRegion _cropRegion = const JellyLive2DCropRegion.full();
  bool _isSwitchingModel = true;

  /// 可点击区域（HitAreas）调试叠加层的开关状态，不持久化；
  /// 用 ValueNotifier 让已打开的控制面板能实时刷新
  final ValueNotifier<bool> _hitAreasVisible = ValueNotifier<bool>(false);

  /// 当前气泡台词；null 表示不显示。连续点击时替换内容并重置计时
  String? _bubbleMessage;
  Timer? _bubbleTimer;
  String? _lastBubbleMessage;

  /// 气泡展示时长
  static const Duration _bubbleDuration = Duration(seconds: 3);

  /// 随机台词池：命中头部 / 命中身体 / 点空（未命中任何区域）
  static const List<String> _headMessages = [
    '摸摸头～',
    '头发要被摸乱啦',
    '嘿嘿，最喜欢摸头了',
    '今天也要加油鸭',
  ];
  static const List<String> _bodyMessages = [
    '戳肚子会痒！',
    '干嘛戳我呀',
    '再戳就要生气啦',
    '呜哇！',
  ];
  static const List<String> _missMessages = [
    '咦？那边什么都没有哦',
    '叫我有什么事吗？',
    '我在这里呀～',
    '嗯？怎么啦',
  ];
  static final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // macOS 上平台视图会吃掉鼠标事件（WKWebView 默认弹 Reload 菜单），
    // 原生侧拦截后经 onContextMenu 回调转发到这里
    _controller.onContextMenu = _showControls;
    // 点击事件同样由原生侧经 onTap 转发（含 hit area 判定结果）
    _controller.onTap = _handleTap;
    _loadSavedSize();
    _loadSavedCropRegion(_selectedModel);
    _loadModel(_selectedModel);
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _size.dispose();
    _hitAreasVisible.dispose();
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

  String _cropPrefKey(Live2DModelDefinition model) {
    final identity = base64UrlEncode(
      utf8.encode('${model.modelDir}${model.modelFile}'),
    );
    return '$_cropPrefKeyPrefix$identity';
  }

  Future<void> _loadSavedCropRegion(Live2DModelDefinition model) async {
    final prefs = await SharedPreferences.getInstance();
    final region = JellyLive2DCropRegion.parse(
      prefs.getString(_cropPrefKey(model)),
    );
    if (!mounted || model != _selectedModel) return;
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
    } on Live2DException catch (e) {
      debugPrint('[JellyLive2D] setHitAreasVisible failed: ${e.message}');
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
    _playTapMotion(hitAreaId: hitAreaId, hitAreaName: hitAreaName);
    _showBubble(_pickBubbleMessage(hitAreaId, hitAreaName));
  }

  /// 按命中区域挑一条随机台词，避免和上一条重复
  String _pickBubbleMessage(String? hitAreaId, String? hitAreaName) {
    final area =
        (hitAreaName != null && hitAreaName.isNotEmpty)
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
  void _showBubble(String message) {
    _bubbleTimer?.cancel();
    setState(() => _bubbleMessage = message);
  }

  /// 台词逐字浮现完毕：从现在起再展示 [_bubbleDuration] 后收起
  void _onBubbleTyped() {
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(_bubbleDuration, () {
      if (mounted) {
        setState(() => _bubbleMessage = null);
      }
    });
  }

  /// 点击命中可点击区域后挑选动作。模型有语音时优先随机选择带
  /// Sound 的动作；同时优先匹配 Cubism 惯例的 Tap<区域> 分组。
  Future<void> _playTapMotion({String? hitAreaId, String? hitAreaName}) async {
    // Mao 的 HitArea Name 为空，用 Id（HitAreaHead → Head）补齐
    final area =
        (hitAreaName != null && hitAreaName.isNotEmpty)
            ? hitAreaName
            : hitAreaId?.replaceFirst('HitArea', '') ?? '';

    final areaGroup = area.isEmpty ? null : 'tap${area.toLowerCase()}';
    final exact =
        areaGroup == null
            ? const <Live2DMotionDefinition>[]
            : _selectedModel.motions
                .where((motion) => motion.group.toLowerCase() == areaGroup)
                .toList();
    final genericTap =
        _selectedModel.motions
            .where((motion) => motion.group.toLowerCase() == 'tap')
            .toList();
    final voiced =
        _selectedModel.motions.where((motion) => motion.hasSound).toList();

    List<Live2DMotionDefinition> candidates =
        exact.where((motion) => motion.hasSound).toList();
    if (candidates.isEmpty) {
      candidates = genericTap.where((motion) => motion.hasSound).toList();
    }
    if (candidates.isEmpty) candidates = voiced;
    if (candidates.isEmpty) candidates = exact;
    if (candidates.isEmpty) candidates = genericTap;
    if (candidates.isEmpty) {
      candidates =
          _selectedModel.motions.where((motion) => motion.group == '').toList();
    }
    if (candidates.isEmpty) {
      candidates =
          _selectedModel.motions
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
    } on Live2DException catch (e) {
      debugPrint('[JellyLive2D] tap motion failed: ${e.message}');
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
      await _controller.whenAttached;
      if (!mounted) return;
      if (_controller.value.isLoaded) {
        await _controller.unloadModel();
      }
      await _controller.loadModel(
        modelDir: model.modelDir,
        modelFileName: model.modelFile,
      );
    } on Live2DException {
      // The controller exposes the detailed error through Live2DViewState.
    } finally {
      if (mounted) setState(() => _isSwitchingModel = false);
    }
  }

  Future<void> _selectModel(Live2DModelDefinition model) async {
    if (model == _selectedModel ||
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

  Future<({Uint8List bytes, Size size})> _captureFullModel() async {
    if (!_controller.value.isLoaded || _isSwitchingModel) {
      throw StateError('模型尚未加载完成');
    }

    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _modelCaptureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('无法访问模型画面');

    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = rgba?.buffer.asUint8List();
      if (pixels == null || !_containsVisiblePixel(pixels)) {
        throw StateError('当前平台不支持捕获 Live2D 画面');
      }
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('模型画面编码失败');
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
        builder:
            (dialogContext) => DSDialog(
              title: '无法设置裁剪区域',
              message: error.toString().replaceFirst('Bad state: ', ''),
              confirmText: '知道了',
              onConfirm: () => Navigator.of(dialogContext).pop(),
            ),
      );
    }
  }

  String _loadStageLabel(String? stage) {
    return switch (stage) {
      'preparing' => '准备加载',
      'model-config' => '读取模型配置',
      'model-data' => '加载模型数据',
      'components' => '加载模型组件',
      'motions' => '加载动作与语音',
      'textures' => '加载模型纹理',
      'complete' => '加载完成',
      _ => '正在加载',
    };
  }

  String _loadErrorMessage(Live2DException error) {
    return error.message.split('\n').first.trim();
  }

  Future<void> _openOnlineModels(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final model = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<Live2DModelDefinition>(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const Live2DOnlineModelPage(),
        transitionsBuilder:
            (_, animation, _, child) => FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
      ),
    );
    if (model != null && mounted) await _selectModel(model);
  }

  void _showControls() {
    assert(() {
      debugPrint(
        '[JellyLive2D] open controls model=${_selectedModel.label} '
        'attached=${_controller.value.isAttached} '
        'loaded=${_controller.value.isLoaded}',
      );
      return true;
    }());
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
              Text(
                '切换模型',
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.sm),
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: [
                  for (final model in _models)
                    DSChip(
                      label: model.label,
                      selected: model == _selectedModel,
                      onSelected: (_) {
                        Navigator.of(sheetContext).pop();
                        _selectModel(model);
                      },
                    ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              DSListItem(
                title: '在线选择模型',
                subtitle: '从 Eikanya 模型仓库加载 Cubism 3/4 模型',
                leading: DsIcon(
                  DsIconKind.download,
                  size: 18,
                  color: theme.primary,
                ),
                trailing: DsIcon(
                  DsIconKind.chevronRight,
                  size: 18,
                  color: theme.textSub,
                ),
                onTap: () => _openOnlineModels(sheetContext),
              ),
              SizedBox(height: theme.spacing.xl),
              Text(
                '人物大小',
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.sm),
              ValueListenableBuilder<double>(
                valueListenable: _size,
                builder:
                    (context, size, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DSButton(
                                label: '缩小',
                                size: DSButtonSize.sm,
                                onPressed:
                                    size > _minSize
                                        ? () => _changeSize(-_sizeStep)
                                        : null,
                              ),
                            ),
                            SizedBox(width: theme.spacing.sm),
                            Expanded(
                              child: DSButton(
                                label: '放大',
                                size: DSButtonSize.sm,
                                onPressed:
                                    size < _maxSize
                                        ? () => _changeSize(_sizeStep)
                                        : null,
                              ),
                            ),
                            SizedBox(width: theme.spacing.sm),
                            Expanded(
                              child: DSButton(
                                label: '重置',
                                size: DSButtonSize.sm,
                                onPressed:
                                    size == _defaultSize ? null : _resetSize,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: theme.spacing.sm),
                        Text(
                          '当前 ${(size / _defaultSize * 100).round()}%'
                          '（${size.round()}px，自动保存）',
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
                '显示区域',
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.sm),
              DSListItem(
                title: '设置显示裁剪区域',
                subtitle: _cropRegion.isFull ? '当前显示完整模型' : '已应用自定义裁剪区域',
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
                onTap:
                    _controller.value.isLoaded && !_isSwitchingModel
                        ? () => _openCropEditor(sheetContext)
                        : null,
              ),
              SizedBox(height: theme.spacing.xl),
              Text(
                '可点击区域',
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.sm),
              ValueListenableBuilder<bool>(
                valueListenable: _hitAreasVisible,
                builder:
                    (context, visible, _) => DSChip(
                      label: visible ? '已开启' : '已关闭',
                      selected: visible,
                      onSelected: (_) => _toggleHitAreas(!visible),
                    ),
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                '开启后标出模型定义的可点击区域（红色框 + 名称），'
                '点击命中区域会触发随机动作',
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
              SizedBox(height: theme.spacing.xl),
              Text(
                '动作列表',
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.sm),
              if (_selectedModel.motions.isEmpty)
                Text(
                  '当前模型没有可用动作',
                  style: DsTypography.body.copyWith(color: theme.textSub),
                )
              else
                for (final motion in _selectedModel.motions) ...[
                  DSListItem(
                    title:
                        motion.hasSound ? '${motion.label}（语音）' : motion.label,
                    leading: DsIcon(
                      DsIconKind.play,
                      size: 18,
                      color: theme.primary,
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _controller.startMotion(
                        group: motion.group,
                        index: motion.index,
                      );
                    },
                  ),
                  SizedBox(height: theme.spacing.sm),
                ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return ValueListenableBuilder<double>(
      valueListenable: _size,
      builder:
          (context, size, _) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: _showControls,
              // 右键点在 Flutter 渲染的区域（如底部标签）时走这里；
              // 点在人物本体上由原生转发到 _controller.onContextMenu
              onSecondaryTapUp: (_) => _showControls(),
              child: Stack(
                fit: StackFit.expand,
                // 气泡要上浮到方框外（角色头顶上方），不能裁剪
                clipBehavior: Clip.none,
                children: [
                  AnimatedOpacity(
                    opacity:
                        _isSwitchingModel || _controller.value.lastError != null
                            ? 0
                            : 1,
                    duration: const Duration(milliseconds: 160),
                    child: OverflowBox(
                      alignment: Alignment.bottomCenter,
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Transform.translate(
                        // Windows 纹理视图随外层左上角移动：水平抵消一半
                        // 尺寸差以保持居中，垂直抵消完整尺寸差以固定脚底。
                        offset: Offset(
                          (size - _defaultSize) / 2,
                          size - _defaultSize,
                        ),
                        child: Transform.scale(
                          scale: size / _defaultSize,
                          alignment: Alignment.bottomCenter,
                          // 固定原生视口尺寸，缩放时不再重算模型矩阵；竖向
                          // 视口同时为全身模型保留足够的纵向空间。
                          child: SizedBox(
                            width: _defaultSize * _modelViewportAspectRatio,
                            height: _defaultSize,
                            child: ClipRect(
                              child: Transform.translate(
                                offset: _cropRegion.sourceTranslation(
                                  const Size(
                                    _defaultSize * _modelViewportAspectRatio,
                                    _defaultSize,
                                  ),
                                ),
                                child: Transform.scale(
                                  scale: _cropRegion.zoom,
                                  alignment: Alignment.topLeft,
                                  child: RepaintBoundary(
                                    key: _modelCaptureKey,
                                    child: Live2DView(controller: _controller),
                                  ),
                                ),
                              ),
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
                      return Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap:
                              error == null
                                  ? null
                                  : () => _loadModel(_selectedModel),
                          child: MouseRegion(
                            cursor:
                                error == null
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
                                          '模型加载失败',
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
                                          '点击重新加载',
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
                  // 点击触发的台词气泡：短暂显示在角色上方，几秒后淡出
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child:
                            _bubbleMessage == null
                                ? const SizedBox.shrink()
                                : FractionalTranslation(
                                  key: ValueKey(_bubbleMessage),
                                  translation: const Offset(0, -0.75),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 240,
                                      ),
                                      child: JellySpeechBubble(
                                        text: _bubbleMessage!,
                                        onTypingComplete: _onBubbleTyped,
                                      ),
                                    ),
                                  ),
                                ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(
                      child: ValueListenableBuilder<Live2DViewState>(
                        valueListenable: _controller,
                        builder: (context, state, child) {
                          if (state.isLoadingModel || state.lastError != null) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            constraints: const BoxConstraints(maxWidth: 260),
                            padding: EdgeInsets.symmetric(
                              horizontal: theme.spacing.md,
                              vertical: theme.spacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: theme.surface.withValues(alpha: 0.88),
                              borderRadius: theme.radii.pill,
                              boxShadow: theme.shadows.soft,
                            ),
                            child: Text(
                              _selectedModel.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsTypography.caption.copyWith(
                                color: theme.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
      Live2DMotionDefinition(group: 'Idle', index: 0, label: '待机'),
      Live2DMotionDefinition(group: '', index: 0, label: '动作 1'),
      Live2DMotionDefinition(group: '', index: 1, label: '动作 2'),
      Live2DMotionDefinition(group: '', index: 2, label: '动作 3'),
      Live2DMotionDefinition(group: '', index: 3, label: '特殊动作 1'),
      Live2DMotionDefinition(group: '', index: 4, label: '特殊动作 2'),
      Live2DMotionDefinition(group: '', index: 5, label: '特殊动作 3'),
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
      Live2DMotionDefinition(group: 'Idle', index: 0, label: '待机'),
      Live2DMotionDefinition(group: '', index: 0, label: '动作 1'),
      Live2DMotionDefinition(group: '', index: 1, label: '动作 2'),
    ],
  ),
];
