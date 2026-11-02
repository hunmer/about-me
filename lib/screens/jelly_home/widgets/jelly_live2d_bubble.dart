part of 'jelly_live2d.dart';

const String _bubbleOffsetXPrefKey = 'jelly_live2d.bubbleOffsetX';
const String _bubbleOffsetYPrefKey = 'jelly_live2d.bubbleOffsetY';
const String _bubbleShapePrefKey = 'jelly_live2d.bubbleShape';

/// 气泡展示时长
const Duration _minimumBubbleDuration = Duration(seconds: 6);
const Duration _maximumBubbleDuration = Duration(seconds: 30);

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
/// 气泡资源条（位置调整；气泡本身为 design_system 手绘样式，
/// 图片气泡素材选择/上传/文字区域编辑已移除）
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

  Future<void> _loadSavedBubbleShape() async {
    final revision = _bubbleShapePreferenceRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || revision != _bubbleShapePreferenceRevision) return;
      final savedName = prefs.getString(_bubbleShapePrefKey);
      final shape = DsSpeechBubbleShape.values.firstWhere(
        (candidate) => candidate.name == savedName,
        orElse: () => DsSpeechBubbleShape.capsule,
      );
      if (_bubbleShape != shape) setState(() => _bubbleShape = shape);
    } catch (error) {
      debugPrint('[Live2D] Failed to load bubble shape: $error');
    }
  }

  void _selectBubbleShape(DsSpeechBubbleShape shape) {
    _bubbleShapePreferenceRevision++;
    if (_bubbleShape != shape) setState(() => _bubbleShape = shape);
    _bubbleShapeSaveQueue = _bubbleShapeSaveQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_bubbleShapePrefKey, shape.name);
      } catch (error) {
        debugPrint('[Live2D] Failed to save bubble shape: $error');
      }
    });
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
    _bubbleResumeTimer?.cancel();
    _bubbleTypingComplete = false;
    setState(() {
      _bubbleMessage = message;
      _bubbleStreaming = streaming;
    });
  }

  bool get _bubbleWaitingForSpeech =>
      _bubbleMessage != null &&
      _bubbleMessage == widget.message &&
      Live2DPlugin.instance.speakingReply.value == _bubbleMessage;

  void _handleBubbleSpeechChanged() {
    if (!mounted || _bubbleMessage == null) return;
    if (_bubbleWaitingForSpeech) {
      _bubbleTimer?.cancel();
    } else if (_bubbleTypingComplete) {
      _onBubbleTyped();
    }
  }

  /// 打字和对应语音均结束后，再按原有阅读时长收起。
  void _onBubbleTyped() {
    _bubbleTimer?.cancel();
    if (_bubbleStreaming || _bubbleMessage == null) return;
    _bubbleTypingComplete = true;
    if (_bubbleWaitingForSpeech) return;
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

    // 精灵图模式：气泡不需要自定义位置——固定在视频上方居中、
    // 与视频实际显示矩形同宽、高度随内容自然伸缩；忽略保存的
    // bubbleOffsetX/Y（Live2D 模式仍用自定义位置，偏好不动）。
    if (_isVideo) {
      return _buildVideoBubbleAbove(
        width: width,
        height: height,
        topInset: topInset,
        message: message,
      );
    }

    const margin = 12.0;
    const maxBubbleWidth = 360.0;
    final availableWidth = math.max(0.0, width - margin * 2);
    final contentWidth = math.min(availableWidth, maxBubbleWidth);
    if (contentWidth <= 0 || height <= 0) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      top: 0,
      width: width,
      height: height + topInset,
      child: CustomSingleChildLayout(
        delegate: _Live2DBubblePositionDelegate(
          margin: margin,
          offsetX: _bubbleOffsetX,
          offsetY: _bubbleOffsetY,
          topInset: topInset,
          maxBubbleWidth: contentWidth,
        ),
        child: AppTheme(
          data: AppTheme.of(context),
          child: JellySpeechBubble(
            key: const ValueKey('live2d-speech-bubble'),
            text: message,
            modelName: _selectedModel.label,
            shape: _bubbleShape,
            streaming: _bubbleStreaming,
            typingInterval: widget.typingInterval,
            onUserInteract: previewing ? null : _pauseBubbleHide,
            onTypingComplete: previewing ? null : _onBubbleTyped,
          ),
        ),
      ),
    );
  }

  /// 精灵图（视频桌宠）气泡：固定在**当前**视频上方居中、与视频同宽。
  ///
  /// 优先消费舞台（JellyVideoPetStage.geometry → `_videoPetRect`）
  /// 上报的当前显示矩形——宠物被拖拽/走动/缩放后气泡实时跟随；
  /// 舞台尚未完成首次布局（null）时回退 [jellyVideoPetDefaultRect]
  /// 镜像公式（默认落点）。气泡盒由 [jellyVideoBubbleBoxAboveVideo]
  /// 给出（盒底贴视频顶 - gap），[JellyVideoBubbleAboveDelegate] 让
  /// 气泡在盒内底部对齐、高度随内容自然伸缩。四形状（_bubbleShape）
  /// 与文字安全内边距保留。
  Widget _buildVideoBubbleAbove({
    required double width,
    required double height,
    required double topInset,
    required String message,
  }) {
    final manifest = _videoManifest;
    if (manifest == null || width <= 0 || height <= 0) {
      return const SizedBox.shrink();
    }
    // 舞台垂直预算的底边预留（与 build 内 modelBottomInset 同式）
    final bottomInset = computeJellyLive2DModelBottomInset(
      layoutHeight: height + topInset,
      navigationPadding: MediaQuery.paddingOf(context).bottom,
      fitContainer: widget.fitContainer,
    );
    // 兜底锚点：舞台还没上报（首次布局前）时的默认落点。
    final fallbackRect = jellyVideoPetDefaultRect(
      layoutWidth: width,
      layoutHeight: height + topInset,
      topInset: topInset,
      bottomInset: bottomInset,
      petWidth: _size.value,
      canvasAspectRatio: manifest.canvasHeight / manifest.canvasWidth,
      bodySpan: jellyVideoPetBodySpan(manifest.regions),
    );
    // 跟随舞台当前矩形（拖拽/走动/缩放实时刷新）。
    return ValueListenableBuilder<Rect?>(
      valueListenable: _videoPetRect,
      builder: (context, liveRect, _) {
        final videoRect = liveRect ?? fallbackRect;
        final box = jellyVideoBubbleBoxAboveVideo(
          containerWidth: width,
          containerTop: topInset,
          videoRect: videoRect,
        );
        if (box.width <= 0 || box.height <= 0) return const SizedBox.shrink();
        return Positioned(
          left: box.left,
          top: box.top,
          width: box.width,
          height: box.height,
          child: CustomSingleChildLayout(
            delegate: const JellyVideoBubbleAboveDelegate(),
            child: AppTheme(
              data: AppTheme.of(context),
              child: JellySpeechBubble(
                key: const ValueKey('live2d-speech-bubble'),
                text: message,
                modelName: _selectedModel.label,
                shape: _bubbleShape,
                streaming: _bubbleStreaming,
                typingInterval: widget.typingInterval,
                onUserInteract: _pauseBubbleHide,
                onTypingComplete: _onBubbleTyped,
              ),
            ),
          ),
        );
      },
    );
  }

  void _pauseBubbleHide() {
    if (_bubbleMessage == null) return;
    _bubbleTimer?.cancel();
    _bubbleResumeTimer?.cancel();
    _bubbleResumeTimer = Timer(const Duration(seconds: 2), _onBubbleTyped);
  }

  /// radial 底栏气泡面板：展示可即时应用的轮廓预览。
  ///
  /// 位置设置仅 Live2D 模式提供（精灵图气泡固定在视频上方居中，
  /// 不支持/不需要自定义偏移）。
  Widget _buildBubbleStrip(AppThemeData theme) {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          Expanded(
            child: JellyBubbleStylePicker(
              selectedShape: _bubbleShape,
              onSelected: _selectBubbleShape,
            ),
          ),
          if (!_isVideo) ...[
            SizedBox(width: theme.spacing.sm),
            _bubblePositionButton(theme),
          ],
        ],
      ),
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
}

class _Live2DBubblePositionDelegate extends SingleChildLayoutDelegate {
  const _Live2DBubblePositionDelegate({
    required this.margin,
    required this.offsetX,
    required this.offsetY,
    required this.topInset,
    required this.maxBubbleWidth,
  });

  final double margin;
  final double offsetX;
  final double offsetY;
  final double topInset;
  final double maxBubbleWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final availableHeight = math.max(0.0, constraints.maxHeight - topInset);
    return BoxConstraints(
      maxWidth: math.min(
        maxBubbleWidth,
        math.max(0.0, constraints.maxWidth - margin * 2),
      ),
      maxHeight: availableHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final availableHeight = math.max(0.0, size.height - topInset);
    final maxLeft = math.max(margin, size.width - margin - childSize.width);
    final maxTop = math.max(topInset, size.height - childSize.height);
    final left = ((size.width - childSize.width) / 2 + size.width * offsetX)
        .clamp(margin, maxLeft)
        .toDouble();
    final top =
        (topInset +
                (availableHeight - childSize.height) / 2 +
                availableHeight * offsetY)
            .clamp(topInset, maxTop)
            .toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _Live2DBubblePositionDelegate oldDelegate) =>
      margin != oldDelegate.margin ||
      offsetX != oldDelegate.offsetX ||
      offsetY != oldDelegate.offsetY ||
      topInset != oldDelegate.topInset ||
      maxBubbleWidth != oldDelegate.maxBubbleWidth;
}
