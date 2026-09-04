import 'dart:async';
import 'dart:math';

import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:live2d_flutter/live2d_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _sizePrefKey = 'jelly_live2d.size';

  final Live2DViewController _controller = Live2DViewController();
  final ValueNotifier<double> _size = ValueNotifier<double>(_defaultSize);
  _Live2DModel _selectedModel = _models.first;

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

  /// 点击命中可点击区域后挑选动作：
  /// 优先 Cubism 惯例的 Tap<区域> 分组（如 TapHead），没有则从默认分组
  /// 随机选一个；两者都没有（如 IceGirl）就不播放。
  Future<void> _playTapMotion({
    String? hitAreaId,
    String? hitAreaName,
  }) async {
    // Mao 的 HitArea Name 为空，用 Id（HitAreaHead → Head）补齐
    final area =
        (hitAreaName != null && hitAreaName.isNotEmpty)
            ? hitAreaName
            : hitAreaId?.replaceFirst('HitArea', '') ?? '';

    List<_Live2DMotion> candidates = const [];
    if (area.isNotEmpty) {
      final tapGroup = 'Tap${area[0].toUpperCase()}${area.substring(1)}';
      candidates =
          _selectedModel.motions.where((m) => m.group == tapGroup).toList();
    }
    if (candidates.isEmpty) {
      candidates =
          _selectedModel.motions.where((m) => m.group == '').toList();
    }
    if (candidates.isEmpty) return;

    final motion = candidates[Random().nextInt(candidates.length)];
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

  Future<void> _loadModel(_Live2DModel model) async {
    try {
      await _controller.whenAttached;
      if (!mounted) return;
      await _controller.loadModel(
        modelDir: model.assetFolder,
        modelFileName: model.modelFile,
      );
    } on Live2DException {
      // The controller exposes the detailed error through Live2DViewState.
    }
  }

  Future<void> _selectModel(_Live2DModel model) async {
    if (model == _selectedModel || _controller.value.isLoadingModel) return;
    setState(() => _selectedModel = model);
    await _loadModel(model);
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
            SizedBox(height: theme.spacing.xl),
            Text(
              '人物大小',
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
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ],
              ),
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
                    title: motion.label,
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
                  Live2DView(controller: _controller),
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
                          final error = state.lastError;
                          final label =
                              error == null
                                  ? _selectedModel.label
                                  : '加载失败：${error.message}';
                          return Container(
                            constraints: const BoxConstraints(maxWidth: 260),
                            padding: EdgeInsets.symmetric(
                              horizontal: theme.spacing.md,
                              vertical: theme.spacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (error == null
                                      ? theme.surface
                                      : theme.danger)
                                  .withValues(alpha: 0.88),
                              borderRadius: theme.radii.pill,
                              boxShadow: theme.shadows.soft,
                            ),
                            child: Text(
                              state.isLoadingModel
                                  ? '正在加载 ${_selectedModel.label}'
                                  : label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsTypography.caption.copyWith(
                                color:
                                    error == null
                                        ? theme.text
                                        : theme.onDanger,
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

class _Live2DModel {
  const _Live2DModel({
    required this.label,
    required this.assetFolder,
    required this.modelFile,
    required this.motions,
  });

  final String label;
  final String assetFolder;
  final String modelFile;
  final List<_Live2DMotion> motions;
}

class _Live2DMotion {
  const _Live2DMotion(this.group, this.index, this.label);

  final String group;
  final int index;
  final String label;
}

const List<_Live2DModel> _models = [
  _Live2DModel(
    label: 'Mao',
    assetFolder: 'assets/models/mao/',
    modelFile: 'mao_pro.model3.json',
    motions: [
      _Live2DMotion('Idle', 0, '待机'),
      _Live2DMotion('', 0, '动作 1'),
      _Live2DMotion('', 1, '动作 2'),
      _Live2DMotion('', 2, '动作 3'),
      _Live2DMotion('', 3, '特殊动作 1'),
      _Live2DMotion('', 4, '特殊动作 2'),
      _Live2DMotion('', 5, '特殊动作 3'),
    ],
  ),
  _Live2DModel(
    label: 'IceGirl',
    assetFolder: 'assets/models/icegirl/',
    modelFile: 'IceGirl.model3.json',
    motions: [],
  ),
  _Live2DModel(
    label: 'Ren',
    assetFolder: 'assets/models/ren/',
    modelFile: 'ren.model3.json',
    motions: [
      _Live2DMotion('Idle', 0, '待机'),
      _Live2DMotion('', 0, '动作 1'),
      _Live2DMotion('', 1, '动作 2'),
    ],
  ),
];
