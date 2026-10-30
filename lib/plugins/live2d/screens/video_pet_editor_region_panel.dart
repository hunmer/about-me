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
                return ListTile(
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
                    icon: region.enabled ? DsIconKind.eye : DsIconKind.eyeOff,
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
                  onTap: () => setState(() => _selectedRegionId = region.id),
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
