import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';
import 'package:aboutme/plugins/openai/models/service_provider.dart';

/// OpenAI 插件首次引导的配置步骤：厂商 / 模型 / API Key
///
/// 收集结果写入共享 [values]（providerId / model / apiKey），
/// 由插件在引导完成时统一应用
class OnboardingProviderSetup extends StatefulWidget {
  const OnboardingProviderSetup({super.key, required this.values});

  final Map<String, dynamic> values;

  @override
  State<OnboardingProviderSetup> createState() =>
      _OnboardingProviderSetupState();
}

class _OnboardingProviderSetupState extends State<OnboardingProviderSetup> {
  /// 常规模式可选的预设（剔除 baseUrl 含占位符、无法直接使用的预设，如 Azure）
  late final List<ServiceProvider> _presets = ProviderController()
      .getDefaultProviders()
      .where((p) => !p.baseUrl.contains('YOUR_'))
      .toList();

  late final TextEditingController _modelController = TextEditingController();
  late final TextEditingController _apiKeyController = TextEditingController();

  String? _selectedPresetId;

  @override
  void initState() {
    super.initState();
    // 步骤页可能被 PageView 回收重建，已收集的选择/输入优先从 values 恢复
    final savedProviderId = widget.values['providerId'] as String?;
    ServiceProvider? preset;
    if (_presets.isNotEmpty) {
      preset = _presets.first;
      for (final p in _presets) {
        if (p.id == savedProviderId) {
          preset = p;
          break;
        }
      }
    }
    _selectedPresetId = preset?.id;
    if (preset != null) {
      widget.values['providerId'] = preset.id;
    }

    final savedModel = (widget.values['model'] as String?)?.trim() ?? '';
    _modelController.text = savedModel.isNotEmpty
        ? savedModel
        : (preset?.defaultModel ?? '');
    widget.values['model'] = _modelController.text;

    _apiKeyController.text = (widget.values['apiKey'] as String?) ?? '';
  }

  @override
  void dispose() {
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _selectPreset(ServiceProvider preset) {
    setState(() => _selectedPresetId = preset.id);
    widget.values['providerId'] = preset.id;
    // 模型预填该厂商默认模型，用户可自行修改
    _modelController.text = preset.defaultModel ?? '';
    widget.values['model'] = _modelController.text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DSSelect<String>(
          value: _selectedPresetId,
          hint: 'openai_pleaseSelectProvider'.tr,
          items: _presets
              .map(
                (preset) => DSSelectItem(
                  label: preset.label,
                  value: preset.id,
                ),
              )
              .toList(),
          onChanged: (value) {
            final preset = _presets.firstWhere((p) => p.id == value);
            _selectPreset(preset);
          },
        ),
        SizedBox(height: theme.spacing.lg),
        DSInput(
          controller: _modelController,
          label: 'openai_model'.tr,
          hint: 'openai_enterModel'.tr,
          onChanged: (value) => widget.values['model'] = value,
        ),
        SizedBox(height: theme.spacing.lg),
        DSInput(
          controller: _apiKeyController,
          label: 'openai_apiKey'.tr,
          hint: 'openai_apiKeyHint'.tr,
          onChanged: (value) => widget.values['apiKey'] = value,
        ),
      ],
    );
  }
}
