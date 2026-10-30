// 视频桌宠编辑器：布局与预览（窄屏 body/预览区/工具区/动画列表面板）及区域高亮画笔、数值输入组件。
part of 'video_pet_editor_screen.dart';

extension _VideoPetEditorLayout on _VideoPetEditorScreenState {
  Widget _buildNarrowBody(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildPreview(),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) => setState(() {
            _narrowToolsHeight = (_narrowToolsHeight - details.delta.dy).clamp(
              140.0,
              MediaQuery.sizeOf(context).height * .8,
            );
          }),
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeRow,
            child: SizedBox(
              key: const ValueKey('videoPetNarrowDivider'),
              height: 16,
              width: double.infinity,
              child: Center(
                child: Container(
                  width: 56,
                  height: 4,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    fillColor: theme.surfaceAlt,
                    strokeWidth: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: _narrowToolsHeight, child: _buildNarrowToolsPanel()),
      ],
    );
  }

  Widget _buildPreviewAndAnimationPanel() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildPreview(),
          ),
        ),
        SizedBox(height: 220, child: _buildAnimationPanel()),
      ],
    );
  }

  Widget _buildPreview() {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      // 大容器手绘档（design.md §9.1）：纸底 + 墨线框替代 Material Card。
      decoration: dsSketchDecoration(theme: theme, fillColor: theme.surface),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isTestMode
                              ? _text('videoPet_testPreview', '测试预览')
                              : _text('videoPet_editPreview', '编辑预览'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      // DSSegmentedControl 需有界宽度（内部按 maxWidth 均分选项）。
                      SizedBox(
                        width: 150,
                        child: DSSegmentedControl(
                          options: [
                            _text('videoPet_edit', '编辑'),
                            _text('videoPet_test', '测试'),
                          ],
                          selected: _isTestMode ? 1 : 0,
                          onChanged: (index) =>
                              setState(() => _isTestMode = index == 1),
                        ),
                      ),
                      if (_isTestMode) ...[
                        ValueListenableBuilder<bool>(
                          valueListenable: _walkEnabled,
                          builder: (context, walkEnabled, _) => DSButton(
                            label: walkEnabled
                                ? _text('videoPet_walkOn', '走动 开')
                                : _text('videoPet_walkOff', '走动 关'),
                            size: DSButtonSize.sm,
                            onPressed: () =>
                                _walkEnabled.value = !_walkEnabled.value,
                          ),
                        ),
                        SizedBox(width: 8),
                        DSButton(
                          label: _text('videoPet_resetPosition', '复位'),
                          size: DSButtonSize.sm,
                          onPressed: () =>
                              _stageKey.currentState?.resetPosition(),
                        ),
                        SizedBox(width: 8),
                        DSButton(
                          label: _text('videoPet_walkNow', '立即走动'),
                          size: DSButtonSize.sm,
                          onPressed: () => _stageKey.currentState?.walkNow(),
                        ),
                        SizedBox(width: 8),
                      ],
                      DSIconButton(
                        icon: _isPaused ? DsIconKind.play : DsIconKind.pause,
                        size: 34,
                        color: DSThemeBridge.resolve(context).surfaceAlt,
                        iconColor: DSThemeBridge.resolve(context).textSub,
                        tooltip: _isPaused
                            ? _text('videoPet_resume', '继续')
                            : _text('videoPet_pause', '暂停'),
                        onPressed: () => setState(() => _isPaused = !_isPaused),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Center(
                        child: AspectRatio(
                          aspectRatio: _draft.canvasWidth / _draft.canvasHeight,
                          child: Stack(
                            children: [
                              if (_isTestMode)
                                Positioned.fill(
                                  child: JellyVideoPetStage(
                                    key: _stageKey,
                                    modelId: 'editor:${_draft.id}',
                                    movement: _draft.movement,
                                    animations: _draft.animations,
                                    enabled: _walkEnabled,
                                    petSize: Size(
                                      _draft.canvasWidth,
                                      _draft.canvasHeight,
                                    ),
                                    builder: (context, playback) =>
                                        VideoPetPlayer(
                                          manifest: _draft,
                                          baseUri: widget.baseUri,
                                          resolvedSources:
                                              widget.resolvedSources,
                                          active: true,
                                          paused: _isPaused,
                                          animationRequest: _animationRequest,
                                          frameAnimationRequest:
                                              playback.frameRequest,
                                          interactive: true,
                                          showRegions: _showRegions,
                                          onInteraction: (regionId,
                                              animationId) {
                                            setState(() {
                                              _selectedRegionId = regionId;
                                              _lastHitRegion = regionId;
                                              _lastActionAnimation =
                                                  animationId;
                                            });
                                          },
                                          onTap: (regionId, regionName) {
                                            setState(
                                              () => _lastHitRegion =
                                                  regionName ?? regionId,
                                            );
                                          },
                                          movementAnimationId:
                                              playback.animationId,
                                          dragAnimationId:
                                              playback.dragAnimationId,
                                          movementLoop: playback.loop,
                                          onMovementComplete:
                                              playback.onComplete,
                                          onAnimationFrame:
                                              playback.onAnimationFrame,
                                          onPlaybackBusyChanged:
                                              playback.onBusyChanged,
                                          onDragStart: playback.onDragStart,
                                          onDragUpdate: playback.onDragUpdate,
                                          onDragEnd: playback.onDragEnd,
                                          onDragCancel: playback.onDragCancel,
                                        ),
                                  ),
                                )
                              else
                                Positioned.fill(
                                  child: VideoPetPlayer(
                                    manifest: _draft,
                                    baseUri: widget.baseUri,
                                    resolvedSources: widget.resolvedSources,
                                    active: true,
                                    paused: _isPaused,
                                    animationRequest: _animationRequest,
                                    interactive: false,
                                    onEditPointer: (type, x, y) => _onEditPointer(type, x, y),
                                    showRegions: _showRegions,
                                    onInteraction: (regionId, animationId) {
                                      setState(() {
                                        _selectedRegionId = regionId;
                                        _lastHitRegion = regionId;
                                        _lastActionAnimation = animationId;
                                      });
                                    },
                                    onTap: (regionId, regionName) {
                                      setState(
                                        () => _lastHitRegion =
                                            regionName ?? regionId,
                                      );
                                    },
                                  ),
                                ),
                              if (!_isTestMode &&
                                  (_isAddingRegion ||
                                      _gestureMode != _RegionGestureMode.none))
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _RegionPainter(
                                        regions: _draft.regions,
                                        selectedId: _selectedRegionId,
                                        draftRect: _gestureRect,
                                        showLabels: true,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            _buildPreviewStatus(),
          ],
        ),
      ),
    );
  }

  /// 宠物当前状态角标：展示在**预览面板**左下角（不随宠物画布比例收缩）。
  Widget _buildPreviewStatus() {
    final dsTheme = DSThemeBridge.resolve(context);
    return Positioned(
      key: const ValueKey('videoPetPreviewStatus'),
      left: 12,
      bottom: 12,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dsTheme.ink.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              _isTestMode
                  ? '${_text('videoPet_hit', '命中')}: ${_lastHitRegion ?? '-'}  ${_text('videoPet_action', '动作')}: ${_lastActionAnimation ?? '-'}'
                  : _text('videoPet_editHint', '拖动区域移动，拖动右下角调整大小'),
              style: TextStyle(color: dsTheme.paper, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }

  /// 窄屏底部工具区：区域 / 动画 / 动作预设 / 动作编辑四个 Tab，
  /// 保持在树内实时刷新。
  Widget _buildNarrowToolsPanel() {
    final theme = DSThemeBridge.resolve(context);
    Widget configPanel(Widget child) => Material(
      color: theme.surfaceAlt,
      child: ListView(padding: const EdgeInsets.all(12), children: [child]),
    );
    return Material(
      color: theme.surfaceAlt,
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            TabBar(
              tabAlignment: TabAlignment.start,
              isScrollable: true,
              tabs: [
                Tab(text: _text('videoPet_regions', '区域')),
                Tab(
                  key: const ValueKey('videoPetNarrowAnimationTab'),
                  text: _text('videoPet_animations', '动画'),
                ),
                Tab(
                  key: const ValueKey('videoPetNarrowConfigTab'),
                  text: _text('videoPet_presets', '动作预设'),
                ),
                Tab(
                  key: const ValueKey('videoPetNarrowActionTab'),
                  text: _text('videoPet_actionEdit', '动作编辑'),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildRegionPanel(),
                  _buildAnimationPanel(),
                  configPanel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildPresetSections(),
                    ),
                  ),
                  configPanel(_buildAnimationResourceEditor()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildAnimationPanel() {
    return Material(
      color: DSThemeBridge.resolve(context).surfaceAlt,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _text('videoPet_animations', '动画'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DSInput.search(
                    controller: _searchController,
                    hint: _text('videoPet_searchAnimation', '搜索动画'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 分类过滤：手绘 DSChip 横向单行滚动。
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final category in _categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: DSChip(
                        label: category == 'all'
                            ? _text('videoPet_all', '全部')
                            : category,
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 单行动画列表：点按选中播放，右侧 switch 控制是否参与 Jev 决策。
            Expanded(
              child: ListView.builder(
                itemCount: _visibleAnimations.length,
                itemBuilder: (context, index) {
                  final animation = _visibleAnimations[index];
                  final theme = DSThemeBridge.resolve(context);
                  final selected = _selectedAnimationId == animation.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      decoration: dsSketchDecoration(
                        theme: theme,
                        fillColor: selected ? theme.hatch : theme.surface,
                        radius: const BorderRadius.all(Radius.circular(10)),
                      ),
                      child: InkWell(
                        onTap: () => _requestAnimation(animation.id),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              DsIcon(
                                selected
                                    ? DsIconKind.play
                                    : DsIconKind.animation,
                                size: 18,
                                color: theme.text,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  animation.name.isEmpty
                                      ? animation.id
                                      : animation.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (animation.category.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    animation.category,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                              DSSwitch(
                                value: animation.enabled,
                                onChanged: (value) => _updateAnimation(
                                  animation.copyWith(enabled: value),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DsNumberField extends StatefulWidget {
  const _DsNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_DsNumberField> createState() => _DsNumberFieldState();
}

class _DsNumberFieldState extends State<_DsNumberField> {
  late final _controller = TextEditingController(
    text: widget.value.toStringAsFixed(3),
  );

  @override
  void didUpdateWidget(covariant _DsNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部 clamp / 联动改变值且当前输入不可解析为该值时同步文本。
    if (widget.value != oldWidget.value &&
        double.tryParse(_controller.text) != widget.value) {
      _controller.text = widget.value.toStringAsFixed(3);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        DSInput(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          onChanged: (text) {
            final parsed = double.tryParse(text);
            if (parsed != null) widget.onChanged(parsed);
          },
        ),
      ],
    );
  }
}

class _RegionPainter extends CustomPainter {
  const _RegionPainter({
    required this.regions,
    required this.selectedId,
    required this.draftRect,
    required this.showLabels,
  });

  final List<VideoPetRegion> regions;
  final String? selectedId;
  final Rect? draftRect;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    for (final region in regions) {
      final rect = Rect.fromLTWH(
        region.x * size.width,
        region.y * size.height,
        region.width * size.width,
        region.height * size.height,
      );
      final selected = region.id == selectedId;
      final color = selected ? Colors.amber : Colors.lightBlueAccent;
      canvas.drawRect(
        rect,
        Paint()..color = color.withOpacity(selected ? .16 : .08),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.5 : 1.2,
      );
      if (showLabels && rect.width > 35 && rect.height > 18) {
        final painter = TextPainter(
          text: TextSpan(
            text: region.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              backgroundColor: Colors.black54,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: rect.width);
        painter.paint(canvas, rect.topLeft + const Offset(3, 3));
      }
    }
    if (draftRect != null) {
      final rect = Rect.fromLTRB(
        draftRect!.left * size.width,
        draftRect!.top * size.height,
        draftRect!.right * size.width,
        draftRect!.bottom * size.height,
      );
      canvas.drawRect(rect, Paint()..color = Colors.amber.withOpacity(.2));
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RegionPainter oldDelegate) =>
      oldDelegate.regions != regions ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.draftRect != draftRect ||
      oldDelegate.showLabels != showLabels;
}
