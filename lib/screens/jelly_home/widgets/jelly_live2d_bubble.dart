part of 'jelly_live2d.dart';

/// 内置聊天气泡素材
const List<String> _bubbleAssets = [
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

const String _bubbleOffsetXPrefKey = 'jelly_live2d.bubbleOffsetX';
const String _bubbleOffsetYPrefKey = 'jelly_live2d.bubbleOffsetY';

/// 气泡展示时长
const Duration _minimumBubbleDuration = Duration(seconds: 6);
const Duration _maximumBubbleDuration = Duration(seconds: 30);

/// 气泡最小显示尺寸（逻辑像素）：320×100 的 1.3 倍
const double _bubbleMinWidth = 416.0;
const double _bubbleMinHeight = 130.0;

/// 随机台词池：命中头部 / 命中身体 / 点空（未命中任何区域）。
/// 翻译需运行时解析，用 getter 每次取当前语言
List<String> get _headMessages => [
  'screens_jellyLive2dTapHead1'.tr,
  'screens_jellyLive2dTapHead2'.tr,
  'screens_jellyLive2dTapHead3'.tr,
  'screens_jellyLive2dTapHead4'.tr,
];
List<String> get _bodyMessages => [
  'screens_jellyLive2dPokeBody1'.tr,
  'screens_jellyLive2dPokeBody2'.tr,
  'screens_jellyLive2dPokeBody3'.tr,
  'screens_jellyLive2dPokeBody4'.tr,
];
List<String> get _missMessages => [
  'screens_jellyLive2dMiss1'.tr,
  'screens_jellyLive2dMiss2'.tr,
  'screens_jellyLive2dMiss3'.tr,
  'screens_jellyLive2dMiss4'.tr,
];

/// 气泡功能：台词挑选、展示计时、气泡布局与位置设置、
/// 气泡资源条（选择/上传/文字区域编辑）
extension _JellyLive2DBubble on _JellyLive2DState {
  Future<void> _loadSavedBubblePosition() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bubbleOffsetX = (prefs.getDouble(_bubbleOffsetXPrefKey) ?? 0)
          .clamp(-0.45, 0.45)
          .toDouble();
      _bubbleOffsetY = (prefs.getDouble(_bubbleOffsetYPrefKey) ?? 0)
          .clamp(-0.45, 0.45)
          .toDouble();
    });
  }

  Future<void> _saveBubblePosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_bubbleOffsetXPrefKey, _bubbleOffsetX);
    await prefs.setDouble(_bubbleOffsetYPrefKey, _bubbleOffsetY);
  }

  /// 按命中区域挑一条随机台词，避免和上一条重复。
  /// 当前档案开启自定义台词时优先取该部位配置，未配置的部位回退内置文案
  /// 根据命中区域解析部位 ID（head/body/miss 等）
  String _tapPartId(String? hitAreaId, String? hitAreaName) {
    final area = (hitAreaName != null && hitAreaName.isNotEmpty)
        ? hitAreaName
        : hitAreaId?.replaceFirst('HitArea', '') ?? '';
    final lower = area.toLowerCase();
    if (area.isEmpty) return 'miss';
    return live2DTapParts
            .where(
              (part) => part.keywords.any(
                (keyword) => lower.contains(keyword.toLowerCase()),
              ),
            )
            .map((part) => part.id)
            .firstOrNull ??
        'body';
  }

  /// 当前档案是否为该部位配置了自定义点击台词
  bool _hasCustomTapMessage(String partId) {
    final archive = Live2DPlugin.instance.selected;
    return archive != null &&
        archive.tapMessagesEnabled &&
        archive.tapMessageList(partId).isNotEmpty;
  }

  String _pickBubbleMessage(String? hitAreaId, String? hitAreaName) {
    final partId = _tapPartId(hitAreaId, hitAreaName);
    final archive = Live2DPlugin.instance.selected;
    final custom = archive != null && archive.tapMessagesEnabled
        ? archive.tapMessageList(partId)
        : const <String>[];
    final List<String> pool = custom.isNotEmpty
        ? custom
        : switch (partId) {
            'head' => _headMessages,
            'miss' => _missMessages,
            _ => _bodyMessages,
          };
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
    double topInset = 0,
  }) {
    final previewing = _bubblePositionPreview;
    final message = _bubbleMessage ?? (previewing ? '气泡预览' : null);
    if (message == null) return const SizedBox.shrink();
    const margin = 12.0;
    const bubbleBaseWidth = 288.0;
    const bubbleBaseHeight = 150.0;
    final availableWidth = math.max(0.0, width - margin * 2);
    final availableHeight = math.max(0.0, height);
    // 基础宽度只由容器决定（不随模型显示尺寸变化），
    // 保证 live2d 与 video-pet 两模式气泡同大小
    final baseWidth = math.min(
      availableWidth,
      availableHeight * bubbleBaseWidth / bubbleBaseHeight,
    );
    if (baseWidth <= 0) return const SizedBox.shrink();
    // 任一维不足最小尺寸时，整体锁定为最小宽高
    final baseScale = baseWidth / bubbleBaseWidth;
    final scaledHeight = bubbleBaseHeight * baseScale;
    final atMinimum =
        baseWidth < _bubbleMinWidth || scaledHeight < _bubbleMinHeight;
    final bubbleWidth = atMinimum ? _bubbleMinWidth : baseWidth;
    final bubbleHeight = atMinimum ? _bubbleMinHeight : scaledHeight;
    final top =
        ((height - bubbleHeight) / 2 + height * _bubbleOffsetY)
            .clamp(0.0, math.max(0.0, height - bubbleHeight))
            .toDouble() +
        topInset;
    // 最小宽度可能超出可用宽度，上限兜底避免 clamp 区间倒置
    final left = (((width - bubbleWidth) / 2 + width * _bubbleOffsetX).clamp(
          margin,
          math.max(margin, width - margin - bubbleWidth),
        ))
        .toDouble();

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
          onUserInteract: previewing ? null : _pauseBubbleHide,
          onTypingComplete: previewing ? null : _onBubbleTyped,
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

  Widget _buildBubbleStrip(AppThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
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
          ),
        ),
        SizedBox(width: theme.spacing.md),
        Container(width: 1, height: 36, color: theme.stroke),
        SizedBox(width: theme.spacing.md),
        _bubblePositionButton(theme),
      ],
    );
  }

  Widget _bubblePositionButton(AppThemeData theme) {
    return GestureDetector(
      onTap: _openBubblePositionSettings,
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

  Future<void> _openBubblePositionSettings() async {
    setState(() => _bubblePositionPreview = true);
    try {
      await SmoothBottomSheet.showWithTitle<void>(
        context: context,
        title: '气泡位置',
        minHeight: MediaQuery.sizeOf(context).height * 0.3,
        child: Builder(
          builder: (sheetContext) {
            final theme = AppTheme.of(sheetContext);
            return StatefulBuilder(
              builder: (context, setSheetState) => Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.spacing.xl,
                  theme.spacing.md,
                  theme.spacing.xl,
                  theme.spacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '水平位置',
                      style: DsTypography.label.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    DSSlider(
                      value: ((_bubbleOffsetX + 0.45) / 0.9).clamp(0.0, 1.0),
                      onChanged: (value) {
                        setState(() => _bubbleOffsetX = value * 0.9 - 0.45);
                        setSheetState(() {});
                      },
                      onChangeEnd: (_) => _saveBubblePosition(),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    Text(
                      '垂直位置',
                      style: DsTypography.label.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    DSSlider(
                      value: ((_bubbleOffsetY + 0.45) / 0.9).clamp(0.0, 1.0),
                      onChanged: (value) {
                        setState(() => _bubbleOffsetY = value * 0.9 - 0.45);
                        setSheetState(() {});
                      },
                      onChangeEnd: (_) => _saveBubblePosition(),
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSButton(
                      label: '恢复居中',
                      size: DSButtonSize.sm,
                      onPressed: () {
                        setState(() {
                          _bubbleOffsetX = 0;
                          _bubbleOffsetY = 0;
                        });
                        setSheetState(() {});
                        unawaited(_saveBubblePosition());
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _bubblePositionPreview = false);
    }
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

  Future<void> _uploadCustomBubble(BuildContext context) async {
    final result = await ImagePickerDialog.show<Map<String, dynamic>>(context);
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
}
