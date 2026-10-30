part of 'jelly_live2d.dart';

/// 模型加载功能：模型切换/重载、档案选择、动作播放请求、视线重置
const _appearanceDuration = Duration(seconds: 8);

extension _JellyLive2DLoader on _JellyLive2DState {
  void _scheduleAppearanceReset() {
    _appearanceResetTimer?.cancel();
    _appearanceResetTimer = Timer(_appearanceDuration, () async {
      if (!mounted || !_controller.value.isLoaded || _isSwitchingModel) return;
      _jevMotionActive = false;
      _syncVoiceGaze();
      debugPrint('[Live2D] 表情/动作展示结束，原地恢复 Idle');
      try {
        // 保留当前模型、纹理和视图，只切回待机动作，避免整模型重载。
        await _controller.startMotion(group: 'Idle', index: 0, priority: 1);
      } on Live2DException catch (error) {
        debugPrint('[Live2D] 原地恢复 Idle 失败: $error');
      }
    });
  }

  /// 回复完成后的反应动画入口：Jev 开启时让位给决策链路
  /// （_scheduleJevReply → _applyJevReply），由决策失败/未命中时回退随机；
  /// 未开启 Jev 时立即随机播放。
  Future<void> _playReaction() async {
    if (Live2DPlugin.instance.selected?.jevEnabled == true) {
      debugPrint('[Live2D][Jev] JEV 已开启，等待决策结果后再播放反应动画');
      return;
    }
    await _playRandomMotion();
  }

  /// 随机播放一个反应动作：视频档案随机点播动画，Live2D 随机非 Idle 动作。
  Future<void> _playRandomMotion() async {
    if (_isVideo) {
      final animations = _videoManifest?.animations ?? const [];
      if (animations.isNotEmpty) {
        _requestVideoAnimation(
          animations[_random.nextInt(animations.length)].id,
        );
      }
      return;
    }
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
    if (_isVideo) return;
    await _controller.setDragging(0, 0);
  }

  /// 模型身份按目录 + 文件名判定（在线模型每次都会生成新实例，不能比较引用）
  bool _isSameModel(Live2DModelDefinition a, Live2DModelDefinition b) =>
      a.displayMode == b.displayMode &&
      a.modelDir == b.modelDir &&
      a.modelFile == b.modelFile &&
      (!a.isVideo ||
          (jsonEncode(a.videoManifest?.toJson()) ==
                  jsonEncode(b.videoManifest?.toJson()) &&
              mapEquals(a.videoResolvedSources, b.videoResolvedSources)));

  Future<void> _loadModel(Live2DModelDefinition model) async {
    if (!_routeVisible) return;
    final generation = ++_modelLoadGeneration;
    if (model.isVideo) {
      if (mounted) {
        setState(() {
          _isSwitchingModel = true;
          _videoLoadError = null;
          _bubbleMessage = null;
          _videoManifest = null;
        });
      }
      try {
        await _unloadModel();
        final manifest =
            model.videoManifest ??
            (await VideoPetImportService().loadDefault()).manifest;
        final package = await const VideoPetImportService().prepareForPlayback(
          manifest,
          baseUri: model.modelDir,
          resolvedSources: model.videoResolvedSources,
        );
        if (!mounted || generation != _modelLoadGeneration) return;
        debugPrint(
          '[Live2D][Video] 模型=${manifest.id} '
          '行走=${package.manifest.movement.enabled} '
          '左=${package.manifest.movement.leftAnimationId} '
          '右=${package.manifest.movement.rightAnimationId}',
        );
        setState(() {
          _videoManifest = package.manifest;
          _videoBaseUri = package.baseUri;
          _videoResolvedSources = package.resolvedSources;
          _isSwitchingModel = false;
        });
        _notifyAppearanceAvailabilityChanged();
      } catch (error) {
        if (mounted && generation == _modelLoadGeneration) {
          setState(() {
            _videoLoadError = error.toString();
            _isSwitchingModel = false;
          });
        }
      }
      return;
    }
    _videoManifest = null;
    debugPrint('[Live2D][Load] 请求加载模型: ${model.modelDir}/${model.modelFile}');
    if (mounted) {
      _bubbleTimer?.cancel();
      setState(() {
        _isSwitchingModel = true;
        _bubbleMessage = null;
      });
    }
    try {
      final localModel = await Live2DOnlineCatalog.cacheDefinition(model);
      if (!mounted || generation != _modelLoadGeneration) return;
      await _controller.whenAttached;
      if (!mounted || !_routeVisible || generation != _modelLoadGeneration) {
        return;
      }
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
      if (mounted && generation == _modelLoadGeneration) {
        setState(() => _isSwitchingModel = false);
      }
    }
  }

  Future<void> _selectModel(Live2DModelDefinition model) async {
    if (_isSameModel(model, _selectedModel)) {
      return;
    }
    setState(() {
      _selectedModel = model;
      _cropRegion = const JellyLive2DCropRegion.full();
    });
    _notifyAppearanceAvailabilityChanged();
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

  void _handleExpressionRequest() {
    final expression = widget.expressionRequest?.value;
    if (expression == null) return;
    if (_isSwitchingModel || !_controller.value.isLoaded) return;
    unawaited(_setExpression(expression));
  }

  Future<void> _setExpression(Live2DExpressionDefinition expression) async {
    try {
      await _controller.setExpression(expression.index);
    } on Live2DException {
      // 表情播放失败时保持当前模型状态。
    }
  }

  void _onViewStateChanged() {
    final loaded = _controller.value.isLoaded;
    if (loaded && !_wasModelLoaded) {
      _voiceLoadGeneration++;
      debugPrint(
        '[Live2D][Voice] 模型已加载，补应用最新口型帧 '
        '(version=$_voiceFrameVersion)',
      );
      _queueVoiceParameter(_lastVoiceFrame, _voiceFrameVersion);
      _syncVoiceGaze();
    }
    _wasModelLoaded = loaded;

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
      _scheduleAppearanceReset();
    } on Live2DException {
      // 动作播放失败时保持当前动作，不打断交互
    }
  }

  Future<void> _applyJevReply(String reply) async {
    final archive = Live2DPlugin.instance.selected;
    if (archive?.jevEnabled != true) {
      debugPrint('[Live2D][Jev] 当前档案未开启 JEV，跳过自动表情动作');
      return;
    }
    if (reply.trim().isEmpty) {
      debugPrint('[Live2D][Jev] 回复为空，跳过自动表情动作');
      return;
    }
    if (_isVideo) {
      // 视频桌宠：候选 = 编辑器中启用的动画，命中后一次性播放。
      final candidates =
          _selectedModel.videoManifest?.animations
              .where((item) => item.enabled)
              .toList() ??
          const [];
      if (candidates.isEmpty) {
        debugPrint('[Live2D][Jev] 视频档案没有启用中的动作，跳过决策');
        return;
      }
      final result = await Live2DPlugin.instance.decideAppearance(
        reply,
        model: _selectedModel,
        videoAnimations: candidates
            .map((item) => item.name.isEmpty ? item.id : item.name)
            .toList(),
      );
      final choice = result['motion'];
      if (choice == null) {
        debugPrint('[Live2D][Jev] 决策未返回动作，回退随机动画');
        await _playRandomMotion();
        return;
      }
      final match = candidates
          .where((item) => item.name == choice || item.id == choice)
          .firstOrNull;
      if (match == null) {
        debugPrint('[Live2D][Jev] 决策结果 $choice 不在候选动画中，回退随机动画');
        await _playRandomMotion();
        return;
      }
      debugPrint('[Live2D][Jev] 播放视频动画: ${match.id}');
      _requestVideoAnimation(match.id);
      return;
    }
    _jevMotionActive = false;
    _syncVoiceGaze();
    debugPrint('[Live2D][Jev] 收到完整回复，准备选择表情动作');
    final result = await Live2DPlugin.instance.decideAppearance(
      reply,
      model: _selectedModel,
    );
    final expression = _selectedModel.expressions
        .where((item) => item.label == result['expression'])
        .firstOrNull;
    if (expression != null) {
      debugPrint(
        '[Live2D][Jev] 执行表达式: ${expression.label} (#${expression.index})',
      );
      try {
        await _controller.setExpression(expression.index);
      } on Live2DException catch (error) {
        debugPrint('[Live2D][Jev] 表达式执行失败: $error');
      }
      _scheduleAppearanceReset();
    } else {
      debugPrint('[Live2D][Jev] 未选择表达式');
    }
    final motion = _selectedModel.motions
        .where((item) => item.label == result['motion'])
        .firstOrNull;
    if (motion != null) {
      _jevMotionActive = true;
      _syncVoiceGaze();
      debugPrint(
        '[Live2D][Jev] 执行动作: ${motion.label} (${motion.group}#${motion.index})',
      );
      await _startMotion(motion);
      _scheduleAppearanceReset();
    } else {
      debugPrint('[Live2D][Jev] 未选择动作，回退随机动作');
      _syncVoiceGaze();
      await _playRandomMotion();
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
    final model = modelDefinitionForArchive(
      archive,
      importedModels: plugin.importedModels,
    );
    if (model != null) await _selectModel(model);
    // 落盘放在切换之后：持久化失败不应阻断本次模型切换
    try {
      await plugin.save();
    } catch (error) {
      debugPrint('[Live2D] save archives failed: $error');
    }
  }
}
