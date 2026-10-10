part of 'jelly_live2d.dart';

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
