// 视频桌宠编辑器：动作预设面板（随机移动/撞墙动画/Idle/全局与区域 Hover、Click 绑定编辑）。
part of 'video_pet_editor_screen.dart';

extension _VideoPetEditorPresetPanel on _VideoPetEditorScreenState {
  Widget _buildMovementEditor() {
    final movement = _draft.movement;
    final movementAnimations = _draft.animations;
    final turnAnimations = _draft.animations;
    final movementItems = <DSSelectItem<String>>[
      DSSelectItem(value: '', label: _text('videoPet_notSet', '不设置')),
      for (final animation in movementAnimations)
        DSSelectItem(
          value: animation.id,
          label: animation.name.isEmpty ? animation.id : animation.name,
        ),
    ];
    final turnItems = <DSSelectItem<String>>[
      DSSelectItem(value: '', label: _text('videoPet_notSet', '不设置')),
      for (final animation in turnAnimations)
        DSSelectItem(
          value: animation.id,
          label: animation.name.isEmpty ? animation.id : animation.name,
        ),
    ];
    void update(VideoPetMovement next) =>
        _setDraft(_draft.copyWith(movement: next));
    Widget selector(
      String label,
      String value,
      List<DSSelectItem<String>> items,
      ValueChanged<String> onChanged,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _presetLabelRow(label, value),
          const SizedBox(height: 4),
          // 可搜索下拉（design_system combobox）：动画多时可直接搜索。
          DSCombobox<String>(
            items: items,
            value: items.any((item) => item.value == value) ? value : null,
            hint: _text('videoPet_notSet', '不设置'),
            onChanged: onChanged,
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _text('videoPet_movement', '随机移动'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        selector(
          _text('videoPet_moveLeft', '向左移动'),
          movement.leftAnimationId,
          movementItems,
          (id) => update(movement.copyWith(leftAnimationId: id)),
        ),
        selector(
          _text('videoPet_moveRight', '向右移动'),
          movement.rightAnimationId,
          movementItems,
          (id) => update(movement.copyWith(rightAnimationId: id)),
        ),
        selector(
          _text('videoPet_turnLeft', '向左转向'),
          movement.turnLeftAnimationId,
          turnItems,
          (id) => update(movement.copyWith(turnLeftAnimationId: id)),
        ),
        selector(
          _text('videoPet_turnRight', '向右转向'),
          movement.turnRightAnimationId,
          turnItems,
          (id) => update(movement.copyWith(turnRightAnimationId: id)),
        ),
        selector(
          _text('videoPet_drag', '拖拽悬空'),
          movement.dragAnimationId,
          movementItems,
          (id) => update(movement.copyWith(dragAnimationId: id)),
        ),
        selector(
          _text('videoPet_wallBump', '撞墙动画'),
          movement.wallBumpAnimationId,
          movementItems,
          (id) => update(
            // 换动画时清掉旧帧区间，避免区间对不上新动画。
            movement.copyWith(
              wallBumpAnimationId: id,
              wallBumpStartFrame: null,
              wallBumpEndFrame: null,
            ),
          ),
        ),
        if (movement.wallBumpEnabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const ValueKey('videoPetWallBumpRange'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () async {
                      final animation = _draft.animations.firstWhereOrNull(
                        (item) => item.id == movement.wallBumpAnimationId,
                      );
                      final sheet = animation?.spritesheet;
                      final source = animation?.imageSource;
                      final resolved = source == null
                          ? null
                          : (widget.resolvedSources[Uri.parse(
                                  widget.baseUri,
                                ).resolve(source).toString()] ??
                              Uri.parse(
                                widget.baseUri,
                              ).resolve(source).toString());
                      final range = await VideoPetAnimationResourceEditor
                          .showVideoPetFrameRangeSheet(
                            context,
                            title: _text('videoPet_wallBump', '撞墙动画'),
                            sheet: sheet,
                            imageUri: resolved,
                            initialStart: movement.wallBumpStartFrame,
                            initialEnd: movement.wallBumpEndFrame,
                          );
                      if (range == null) return;
                      update(
                        movement.copyWith(
                          wallBumpStartFrame: range.start,
                          wallBumpEndFrame: range.end,
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.play_arrow,
                          size: 16,
                          color: Theme.of(context).textTheme.bodySmall!.color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          movement.wallBumpStartFrame == null ||
                                  movement.wallBumpEndFrame == null
                              ? '${_text('videoPet_frameRange', '帧区间')}：${_text('videoPet_fullRange', '整段')}'
                              : '${_text('videoPet_frameRange', '帧区间')}：${movement.wallBumpStartFrame}–${movement.wallBumpEndFrame}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                DSButton(
                  label: _text('videoPet_clearRange', '清除'),
                  variant: DSButtonVariant.ghost,
                  size: DSButtonSize.sm,
                  onPressed: () => update(
                    movement.copyWith(
                      wallBumpStartFrame: null,
                      wallBumpEndFrame: null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _numberField(
          _text('videoPet_moveSpeed', '移动速度（像素/秒）'),
          movement.speed,
          (value) => update(movement.copyWith(speed: value.clamp(.1, 10000))),
        ),
        _numberField(
          _text('videoPet_minIdle', '最短等待（秒）'),
          movement.minIdleSeconds,
          (value) => update(
            movement.copyWith(
              minIdleSeconds: value.clamp(0, movement.maxIdleSeconds),
            ),
          ),
        ),
        _numberField(
          _text('videoPet_maxIdle', '最长等待（秒）'),
          movement.maxIdleSeconds,
          (value) => update(
            movement.copyWith(
              maxIdleSeconds: value.clamp(movement.minIdleSeconds, 86400),
            ),
          ),
        ),
        Text(
          _text(
            'videoPet_movementHint',
            '在动画 JSON 中通过 facing 设置原始朝向（left/right），行走时按位移方向自动翻转。',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// 当前点播选中动画的 facing / moving 资源编辑区；
  /// 未选中动画时只给提示，不隐式修改任何动画。
  Widget _buildAnimationResourceEditor() {
    final selected = _selectedAnimation;
    if (selected == null) {
      return Text(
        _text('videoPet_animationResourceHint', '选择上方动画以编辑朝向与分段移动'),
        key: const ValueKey('videoPetAnimationResourceHint'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '动作资源：${selected.name.isEmpty ? selected.id : selected.name}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        VideoPetAnimationResourceEditor(
          key: ValueKey('animationResource-${selected.id}'),
          animation: selected,
          onChanged: _updateAnimation,
          onPreviewSegment: (start, end) =>
              _previewSegmentLoop(selected.id, start, end),
          baseUri: widget.baseUri,
          resolvedSources: widget.resolvedSources,
        ),
      ],
    );
  }

  Widget _buildBindingPanel() {
    final selected = _selectedRegion;
    if (selected == null) {
      return Material(
        color: DSThemeBridge.resolve(context).surfaceAlt,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ..._buildPresetSections(),
            const Divider(height: 22),
            _buildAnimationResourceEditor(),
          ],
        ),
      );
    }
    return Material(
      color: DSThemeBridge.resolve(context).surfaceAlt,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ..._buildPresetSections(),
          const Divider(height: 22),
          _buildAnimationResourceEditor(),
          const Divider(height: 22),
          Text(
            _text('videoPet_regionProperties', '区域属性'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: selected.name,
            decoration: InputDecoration(
              labelText: _text('videoPet_name', '名称'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => _updateSelectedRegion(name: value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(_text('videoPet_enabled', '启用'))),
              DSSwitch(
                value: selected.enabled,
                onChanged: (value) => _updateSelectedRegion(enabled: value),
              ),
            ],
          ),
          _numberField(
            _text('videoPet_priority', '优先级'),
            selected.priority.toDouble(),
            (value) => _updateSelectedRegion(priority: value.round()),
          ),
          const Divider(height: 22),
          Text(
            _text('videoPet_geometry', '位置与尺寸'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _numberField(
            'X',
            selected.x,
            (value) => _updateSelectedRegion(x: value.clamp(0, 1)),
          ),
          _numberField(
            'Y',
            selected.y,
            (value) => _updateSelectedRegion(y: value.clamp(0, 1)),
          ),
          _numberField(
            _text('videoPet_width', '宽度'),
            selected.width,
            (value) => _updateSelectedRegion(width: value.clamp(.01, 1)),
          ),
          _numberField(
            _text('videoPet_height', '高度'),
            selected.height,
            (value) => _updateSelectedRegion(height: value.clamp(.01, 1)),
          ),
          const Divider(height: 22),
          _buildBindingEditor(
            _text('videoPet_hover', 'Hover 动画'),
            selected.hover,
            _draft.hover,
            (binding) => _updateSelectedRegion(hover: binding),
          ),
          const Divider(height: 22),
          _buildBindingEditor(
            _text('videoPet_click', 'Click 动画'),
            selected.click,
            _draft.click,
            (binding) => _updateSelectedRegion(click: binding),
          ),
          const Divider(height: 22),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text('videoPet_showRegions', '显示区域')),
            trailing: DSSwitch(
              value: _showRegions,
              onChanged: (value) => setState(() => _showRegions = value),
            ),
          ),
        ],
      ),
    );
  }

  /// Idle 动画选择器（空闲时循环播放的动画）
  /// 预设行标题：下拉已选中动画时右侧显示编辑图标，
  /// 点击播放该动画并跳转「动作编辑」（窄屏 Tab；宽屏右侧面板本就可见）。
  Widget _presetLabelRow(String label, String? selectedId) {
    final labelWidget = Text(
      label,
      style: Theme.of(context).textTheme.bodySmall,
    );
    if (selectedId == null || selectedId.isEmpty) return labelWidget;
    return Row(
      children: [
        Expanded(child: labelWidget),
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: _text('videoPet_actionEdit', '动作编辑'),
            icon: const Icon(Icons.edit_outlined, size: 14),
            onPressed: () {
              _requestAnimation(selectedId);
              // 窄屏下跳转「动作编辑」tab（宽屏右侧面板本就可见）。
              _narrowTabs.animateTo(3);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIdleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _presetLabelRow(
          _text('videoPet_idleAnimation', 'Idle 动画'),
          _draft.idleAnimationId,
        ),
        const SizedBox(height: 4),
        DSCombobox<String>(
          value:
              _draft.animations.any(
                (animation) => animation.id == _draft.idleAnimationId,
              )
              ? _draft.idleAnimationId
              : null,
          items: [
            for (final animation in _draft.animations)
              DSSelectItem(
                value: animation.id,
                label: animation.name.isEmpty ? animation.id : animation.name,
              ),
          ],
          hint: _text('videoPet_selectAnimations', '选择动画'),
          onChanged: (id) => _setDraft(_draft.copyWith(idleAnimationId: id)),
        ),
      ],
    );
  }

  /// 「动作预设」分区：Idle / 全局 Hover / 全局 Click 绑定 + 随机移动。
  List<Widget> _buildPresetSections() => [
    Text(
      _text('videoPet_presets', '动作预设'),
      style: Theme.of(context).textTheme.titleMedium,
    ),
    const SizedBox(height: 10),
    _buildIdleSelector(),
    const SizedBox(height: 12),
    _buildGlobalBindingEditor(
      _text('videoPet_globalHover', '全局 Hover'),
      _draft.hover,
      (binding) => _updateGlobalBinding(hover: binding),
    ),
    const SizedBox(height: 8),
    _buildGlobalBindingEditor(
      _text('videoPet_globalClick', '全局 Click'),
      _draft.click,
      (binding) => _updateGlobalBinding(click: binding),
    ),
    const Divider(height: 22),
    _buildMovementEditor(),
  ];

  Widget _numberField(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _DsNumberField(label: label, value: value, onChanged: onChanged),
    );
  }

  Widget _buildBindingEditor(
    String title,
    VideoPetBinding? binding,
    VideoPetBinding globalBinding,
    ValueChanged<Object?> onChanged,
  ) {
    final inherited = binding == null;
    final current = binding ?? globalBinding;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        Row(
          children: [
            Expanded(child: Text(_text('videoPet_inheritGlobal', '继承全局'))),
            DSSwitch(
              value: inherited,
              onChanged: (value) => onChanged(value ? null : current),
            ),
          ],
        ),
        if (!inherited) ...[
          const SizedBox(height: 4),
          Text(
            _text('videoPet_strategy', '播放策略'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          DSSelect<String>(
            value: current.strategy,
            items: const [
              DSSelectItem(value: 'random', label: 'random'),
              DSSelectItem(value: 'sequence', label: 'sequence'),
            ],
            onChanged: (value) =>
                onChanged(_withBinding(current, strategy: value)),
          ),
          const SizedBox(height: 6),
          Text(
            _text('videoPet_multiSelect', '可多选动画；清空即禁用'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          // 多选动画绑定：可搜索多选下拉（design_system combobox）。
          DSMultiCombobox<String>(
            items: [
              for (final animation in _draft.animations)
                DSSelectItem(
                  value: animation.id,
                  label: animation.name.isEmpty ? animation.id : animation.name,
                ),
            ],
            values: current.animationIds,
            hint: _text('videoPet_selectAnimations', '选择动画'),
            onChanged: (ids) =>
                onChanged(_withBinding(current, animationIds: ids)),
          ),
        ],
      ],
    );
  }
}
