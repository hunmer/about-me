part of 'tts_plugin.dart';

// ============ 数据选择器注册 ============

/// 注册数据选择器
///
/// TTS 服务选择器：在其他插件中选择 TTS 服务进行朗读
void _registerDataSelectors() {
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'tts.service',
      pluginId: TTSPlugin.instance.id,
      name: '选择TTS服务',
      description: '选择一个TTS服务用于朗读',
      icon: TTSPlugin.instance.icon,
      color: TTSPlugin.instance.color,
      searchable: false,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'service',
          title: '选择TTS服务',
          viewType: SelectorViewType.list,
          isFinalStep: true,
          dataLoader: (_) async {
            final services = await TTSPlugin.instance.managerService
                .getAllServices();
            return services
                .map((s) {
                  final status = [
                    s.type.name,
                    if (s.isDefault) '默认',
                    if (!s.isEnabled) '已禁用',
                  ].join(' · ');
                  return SelectableItem(
                    id: s.id,
                    title: s.name,
                    subtitle: status,
                    icon: s.isEnabled
                        ? Icons.record_voice_over
                        : Icons.voice_over_off,
                    rawData: s,
                  );
                })
                .toList();
          },
        ),
      ],
    ),
  );
}
