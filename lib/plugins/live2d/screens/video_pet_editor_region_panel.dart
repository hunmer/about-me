// 视频桌宠编辑器：区域与绑定（全局/区域级 hover、click）更新及区域列表面板。
part of 'video_pet_editor_screen.dart';

extension _VideoPetEditorRegionOps on _VideoPetEditorScreenState {
  void _updateGlobalBinding({VideoPetBinding? hover, VideoPetBinding? click}) {
    _setDraft(_draft.copyWith(hover: hover, click: click));
  }

  Widget _buildGlobalBindingEditor(
    String title,
    VideoPetBinding binding,
    ValueChanged<VideoPetBinding> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          _text('videoPet_strategy', '播放策略'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        DSSelect<String>(
          value: binding.strategy,
          items: const [
            DSSelectItem(value: 'random', label: 'random'),
            DSSelectItem(value: 'sequence', label: 'sequence'),
          ],
          onChanged: (value) =>
              onChanged(_withBinding(binding, strategy: value)),
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
          values: binding.animationIds,
          hint: _text('videoPet_selectAnimations', '选择动画'),
          onChanged: (ids) =>
              onChanged(_withBinding(binding, animationIds: ids)),
        ),
      ],
    );
  }

  void _updateSelectedRegion({
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    bool? enabled,
    int? priority,
    List<String>? messages,
    Object? hover = _unchanged,
    Object? click = _unchanged,
  }) {
    final selected = _selectedRegion;
    if (selected == null) return;
    var updated = selected.copyWith(
      name: name,
      x: x,
      y: y,
      width: width,
      height: height,
      enabled: enabled,
      priority: priority,
      messages: messages,
    );
    if (!identical(hover, _unchanged)) {
      updated = updated.copyWith(hover: hover as VideoPetBinding?);
    }
    if (!identical(click, _unchanged)) {
      updated = updated.copyWith(click: click as VideoPetBinding?);
    }
    _setDraft(
      _draft.copyWith(
        regions: [
          for (final region in _draft.regions)
            region.id == selected.id ? updated : region,
        ],
      ),
    );
  }

  void _updateRegionClick(String regionId, VideoPetBinding? binding) {
    _setDraft(
      _draft.copyWith(
        regions: [
          for (final region in _draft.regions)
            if (region.id == regionId)
              region.copyWith(click: binding)
            else
              region,
        ],
      ),
    );
  }

  /// 测试模式点击：按草稿区域的台词随机挑一条即时提示（未配置台词
  /// 或未命中区域给出明确反馈）；点击动画由播放器照常处理。
  void _handleTestTap(String? regionId, String? regionName) {
    setState(() => _lastHitRegion = regionName ?? regionId);
    final region = _draft.regionFor(regionId, regionName);
    if (region == null) {
      _showMessage(videoPetText('未命中区域', 'No region hit'));
      return;
    }
    final messages = region.effectiveMessages;
    if (messages.isEmpty) {
      _showMessage(
        videoPetText(
          '「${region.name}」未配置台词',
          '"${region.name}" has no messages yet',
        ),
      );
      return;
    }
    final message = messages[_messageRandom.nextInt(messages.length)];
    _showMessage(videoPetText('台词 · $message', 'Message · $message'));
  }

  /// 选中区域的点击台词编辑：每行一条，运行时随机挑一条（空白行忽略）。
  /// key 绑定区域 id：切换选中区域时重建输入框，内容不串区。
  Widget _buildRegionMessagesEditor(VideoPetRegion region) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _text('videoPet_regionMessages', '点击台词（每行一条，随机挑选）'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          TextFormField(
            key: ValueKey('videoPetRegionMessages_${region.id}'),
            initialValue: region.messages.join('\n'),
            minLines: 2,
            maxLines: 5,
            style: Theme.of(context).textTheme.bodySmall,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) =>
                _updateSelectedRegion(messages: value.split('\n')),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionClickEditor(VideoPetRegion region) {
    final inherited = region.click == null;
    final binding = region.click ?? _draft.click;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_text('videoPet_click', 'Click 动画')} · '
                  '${inherited ? _text('videoPet_inheritGlobal', '继承全局') : _text('videoPet_regionClickActions', '区域动作')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (!inherited)
                TextButton.icon(
                  onPressed: () => _updateRegionClick(region.id, null),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(_text('videoPet_inheritGlobal', '继承全局')),
                ),
            ],
          ),
          DSMultiCombobox<String>(
            key: ValueKey('videoPetRegionClick_${region.id}'),
            items: [
              for (final animation in _draft.animations)
                DSSelectItem(
                  value: animation.id,
                  label: animation.name.isEmpty ? animation.id : animation.name,
                ),
            ],
            values: binding.animationIds,
            hint: _text('videoPet_selectAnimations', '选择动画'),
            onChanged: (ids) => _updateRegionClick(
              region.id,
              binding.copyWith(animationIds: ids),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  _text('videoPet_strategy', '播放策略'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SizedBox(
                width: 130,
                child: DSSelect<String>(
                  value: binding.strategy,
                  items: const [
                    DSSelectItem(value: 'random', label: 'random'),
                    DSSelectItem(value: 'sequence', label: 'sequence'),
                  ],
                  onChanged: (value) => _updateRegionClick(
                    region.id,
                    binding.copyWith(strategy: value),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionPanel() {
    final panel = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _text('videoPet_regions', '区域'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              DSIconButton(
                icon: _isAddingRegion ? DsIconKind.close : DsIconKind.grid,
                size: 36,
                color: DSThemeBridge.resolve(context).surfaceAlt,
                iconColor: DSThemeBridge.resolve(context).textSub,
                tooltip: _text('videoPet_addRegion', '框选新增区域'),
                onPressed: () =>
                    setState(() => _isAddingRegion = !_isAddingRegion),
              ),
              DSIconButton(
                icon: DsIconKind.trash,
                size: 36,
                color: DSThemeBridge.resolve(context).surfaceAlt,
                iconColor: DSThemeBridge.resolve(context).textSub,
                tooltip: _text('videoPet_deleteRegion', '删除区域'),
                onPressed: () => _deleteRegion(),
              ),
            ],
          ),
          if (_isAddingRegion)
            Text(
              _text('videoPet_drawHint', '在预览中拖动框选区域'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.vertical,
              itemCount: _draft.regions.length,
              itemBuilder: (context, index) {
                final region = _draft.regions[index];
                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      selected: region.id == _selectedRegionId,
                      leading: CircleAvatar(
                        radius: 12,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        region.name.isEmpty ? region.id : region.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${region.priority} · ${region.enabled ? _text('videoPet_enabled', '启用') : _text('videoPet_disabled', '停用')}',
                      ),
                      trailing: DSIconButton(
                        icon: region.enabled
                            ? DsIconKind.eye
                            : DsIconKind.eyeOff,
                        size: 32,
                        color: DSThemeBridge.resolve(context).surfaceAlt,
                        iconColor: region.enabled
                            ? DSThemeBridge.resolve(context).text
                            : DSThemeBridge.resolve(context).textSub,
                        tooltip: region.enabled
                            ? _text('videoPet_disableRegion', '停用区域')
                            : _text('videoPet_enableRegion', '启用区域'),
                        // 点击眼睛直接切换该区域启用状态（并选中该区域）。
                        onPressed: () {
                          _selectedRegionId = region.id;
                          _updateSelectedRegion(enabled: !region.enabled);
                        },
                      ),
                      onTap: () =>
                          setState(() => _selectedRegionId = region.id),
                    ),
                    if (!_draft.globalClickEnabled)
                      _buildRegionClickEditor(region),
                    // 台词编辑只挂在选中区域下，避免列表每项都展开输入框
                    if (region.id == _selectedRegionId)
                      _buildRegionMessagesEditor(region),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
    return Material(
      color: DSThemeBridge.resolve(context).surface,
      child: panel,
    );
  }
}
