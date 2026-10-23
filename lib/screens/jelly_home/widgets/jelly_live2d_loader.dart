part of 'jelly_live2d.dart';

/// 模型加载功能：模型切换/重载、档案选择、动作播放请求、视线重置
extension _JellyLive2DLoader on _JellyLive2DState {
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

  void resetGaze() {
    unawaited(_resetGaze());
  }

  Future<void> _resetGaze() async {
    // flutter_live2d exposes parameter updates rather than a resetGaze command.
    await Future.wait([
      _controller.setParameter('ParamAngleX', 0),
      _controller.setParameter('ParamAngleY', 0),
      _controller.setParameter('ParamAngleZ', 0),
      _controller.setParameter('ParamEyeBallX', 0),
      _controller.setParameter('ParamEyeBallY', 0),
    ]);
  }

  /// 模型身份按目录 + 文件名判定（在线模型每次都会生成新实例，不能比较引用）
  bool _isSameModel(Live2DModelDefinition a, Live2DModelDefinition b) =>
      a.modelDir == b.modelDir && a.modelFile == b.modelFile;

  Future<void> _loadModel(Live2DModelDefinition model) async {
    if (!_routeVisible) return;
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
      if (!mounted || !_routeVisible) return;
      if (_controller.value.isLoaded) {
        await _controller.unloadModel();
      }
      await _controller.loadModel(
        modelDir: localModel.modelDir,
        modelFileName: localModel.modelFile,
      );
      if (!_routeVisible) await _unloadModel();
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
    // 立即刷新选中态：档案指向同一模型时 _selectModel 会跳过重载，
    // 不先 setState 的话资源条看起来毫无反应
    setState(() => plugin.selectedId = archive.id);
    eventManager.broadcast(
      Live2DPlugin.archiveSelectedEvent,
      EventArgs(Live2DPlugin.archiveSelectedEvent),
    );
    final model = modelDefinitionForArchive(archive);
    if (model != null) await _selectModel(model);
    // 落盘放在切换之后：持久化失败不应阻断本次模型切换
    try {
      await plugin.save();
    } catch (error) {
      debugPrint('[Live2D] save archives failed: $error');
    }
  }
}
