part of 'jelly_live2d.dart';

/// 仅在模型确实加载失败且没有正在加载的请求时允许点击重试。
bool shouldRetryJellyLive2DLoad({
  required Live2DViewState state,
  required bool switching,
}) => !switching && !state.isLoaded && !state.isLoadingModel &&
    state.modelLoadError != null;

/// 点击交互功能：原生转发点击的命中判定分发、点击动作挑选、
/// 可点击区域（HitAreas）调试叠加层
extension _JellyLive2DTap on _JellyLive2DState {
  /// 切换可点击区域（HitAreas）红色叠加层；模型未加载或平台不支持时忽略
  Future<void> _toggleHitAreas(bool visible) async {
    _hitAreasVisible.value = visible;
    try {
      await _controller.setHitAreasVisible(visible);
    } on Live2DException {
      // 平台不支持时静默忽略
    }
  }

  void _triggerTapSpring() {
    if (_selectedModel.motions.isEmpty) {
      _tapSpringController.forward(from: 0);
    }
  }

  /// 点击时短暂推动视线；桌面鼠标点击和移动端触屏点击都由原生视图转发到这里。
  void _triggerTapGaze(double x, double y) {
    _tapGazeResetTimer?.cancel();
    unawaited(() async {
      try {
        await _setGaze(x, y);
      } on Live2DException catch (error) {
        debugPrint('[Live2D][Gaze] tap failed: $error');
        return;
      }
    }());
    _tapGazeResetTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || !_controller.value.isLoaded) return;
      unawaited(_resetTapGaze());
    });
  }

  Future<void> _resetTapGaze() async {
    try {
      await _setGaze(0, 0);
    } on Live2DException catch (error) {
      debugPrint('[Live2D][Gaze] tap reset failed: $error');
    }
  }

  /// 点击角色：先通知宿主（陪伴数值互动），再播放动作 + 随机台词气泡
  void _handleTap(String? hitAreaId, String? hitAreaName, double x, double y) {
    if (_isSwitchingModel) return;
    final state = _controller.value;
    if (!state.isLoaded) {
      if (shouldRetryJellyLive2DLoad(state: state, switching: _isSwitchingModel)) {
        unawaited(_loadModel(_selectedModel, cause: 'tap-retry'));
      }
      return;
    }
    _triggerTapSpring();
    _triggerTapGaze(x, y);
    widget.onTap?.call(hitAreaId, hitAreaName);
    final archive = Live2DPlugin.instance.selected;
    final point = normalizeJellyLive2DViewPoint(x, y);
    final region =
        archive?.tapRegionAt(point.x, point.y) ??
        archive?.tapRegionForHitArea(hitAreaId, hitAreaName);
    final hasNativeHit = hasJellyLive2DHitArea(hitAreaId, hitAreaName);
    if (!hasNativeHit && region == null) return;
    if (hasNativeHit) {
      _playTapMotion(hitAreaId: hitAreaId, hitAreaName: hitAreaName);
    }
    _showBubble(_pickTapRegionMessage(region, hitAreaId, hitAreaName));
  }

  String _pickTapRegionMessage(
    Live2DTapRegion? region,
    String? hitAreaId,
    String? hitAreaName,
  ) {
    final archive = Live2DPlugin.instance.selected;
    final messages = archive?.tapMessagesEnabled == true
        ? region?.effectiveMessages ?? const <String>[]
        : const <String>[];
    if (messages.isEmpty) return _pickBubbleMessage(hitAreaId, hitAreaName);
    var index = _random.nextInt(messages.length);
    if (messages[index] == _lastBubbleMessage && messages.length > 1) {
      index = (index + 1) % messages.length;
    }
    _lastBubbleMessage = messages[index];
    return messages[index];
  }

  /// 视频桌宠：按点击命中的区域从 manifest 台词池随机挑一条；
  /// 区域无台词或未配置返回 null（消费端走旧固定部位回退）。
  /// 与 [_pickTapRegionMessage] 相互独立：视频侧不受 tapMessagesEnabled
  /// 开关约束（精灵图存档无该开关，台词写在 manifest.region.messages）。
  String? _pickVideoRegionMessage(String? regionId, String? regionName) {
    final manifest = Live2DPlugin.instance.selected?.videoManifest;
    if (manifest == null) return null;
    if ((regionId == null || regionId.isEmpty) &&
        (regionName == null || regionName.trim().isEmpty)) {
      return null;
    }
    final messages = manifest
        .regionFor(regionId, regionName)
        ?.effectiveMessages;
    if (messages == null || messages.isEmpty) return null;
    var index = _random.nextInt(messages.length);
    if (messages[index] == _lastBubbleMessage && messages.length > 1) {
      index = (index + 1) % messages.length;
    }
    _lastBubbleMessage = messages[index];
    return messages[index];
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
}
