import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/controllers/model_controller.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';
import 'package:aboutme/plugins/openai/models/llm_models.dart';
import 'package:aboutme/plugins/openai/models/service_provider.dart';

/// OpenAI 插件首次引导的配置步骤：厂商 / 模型 / API Key
///
/// 选择厂商后直接展示其模型列表供点选；模型库中无该厂商分组时
/// （如 Ollama 本地部署）回退为手动输入模型名。
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

  /// provider id 与模型分组 id 不一致时的映射
  static const Map<String, String> _providerGroupAlias = {
    'alibaba': 'alibaba-qwen',
    'glm-codingplan': 'zhipu',
    'minimax-codingplan': 'minimax',
  };

  final ModelController _modelData = ModelController();
  late final TextEditingController _apiKeyController = TextEditingController();
  // 模型库无该厂商分组时的手动输入
  late final TextEditingController _manualModelController =
      TextEditingController();

  List<LLMModelGroup> _modelGroups = [];
  bool _modelsLoaded = false;
  String? _selectedPresetId;
  List<LLMModel> _models = [];
  String? _selectedModelId;

  @override
  void initState() {
    super.initState();
    // 步骤页可能被 PageView 回收重建，已收集的选择/输入优先从 values 恢复
    final savedProviderId = widget.values['providerId'] as String?;
    final savedModel = widget.values['model'] as String? ?? '';
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
    _apiKeyController.text = (widget.values['apiKey'] as String?) ?? '';
    if (preset != null) {
      _selectPreset(preset, preferModelId: savedModel);
    }
    _loadModelGroups();
  }

  Future<void> _loadModelGroups() async {
    _modelGroups = await _modelData.getModels();
    if (!mounted) return;
    // 模型库就绪后重新解析当前厂商的模型列表
    final preset = _currentPreset;
    if (preset != null) {
      _selectPreset(preset, preferModelId: widget.values['model'] as String?);
    } else {
      setState(() => _modelsLoaded = true);
    }
  }

  ServiceProvider? get _currentPreset {
    final id = _selectedPresetId;
    if (id == null) return null;
    for (final preset in _presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  List<LLMModel> _resolveModels(String providerId) {
    final groupId = _providerGroupAlias[providerId] ?? providerId;
    for (final group in _modelGroups) {
      if (group.id == groupId) return group.models;
    }
    return const [];
  }

  /// 选择厂商并解析默认模型
  ///
  /// [preferModelId] 为状态恢复时保留的已选/已输入模型；
  /// 列表模式下默认选中优先级：prefer > 厂商默认模型 > 列表第一个
  void _selectPreset(ServiceProvider preset, {String? preferModelId}) {
    setState(() {
      _selectedPresetId = preset.id;
      widget.values['providerId'] = preset.id;
      _models = _resolveModels(preset.id);

      if (_modelsLoaded && _models.isNotEmpty) {
        final prefer = preferModelId?.isNotEmpty == true ? preferModelId : null;
        final presetDefault = preset.defaultModel;
        String? pick;
        for (final candidate in [prefer, presetDefault]) {
          if (candidate != null && _models.any((m) => m.id == candidate)) {
            pick = candidate;
            break;
          }
        }
        pick ??= _models.first.id;
        _selectedModelId = pick;
        widget.values['model'] = pick;
      } else {
        _selectedModelId = null;
        final fallback =
            (preferModelId?.isNotEmpty == true ? preferModelId : null) ??
            preset.defaultModel ??
            '';
        _manualModelController.text = fallback;
        widget.values['model'] = fallback;
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _manualModelController.dispose();
    super.dispose();
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
        if (!_modelsLoaded)
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.xl),
            child: const Center(child: DSLoadingDots()),
          )
        else if (_models.isNotEmpty) ...[
          Text(
            'openai_model'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          SizedBox(height: theme.spacing.sm),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _models.length,
              itemBuilder: (context, index) {
                final model = _models[index];
                final isSelected = model.id == _selectedModelId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: DSCard(
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.spacing.md,
                      vertical: theme.spacing.sm,
                    ),
                    onTap: () {
                      setState(() => _selectedModelId = model.id);
                      widget.values['model'] = model.id;
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            model.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ),
                        if (isSelected)
                          DsIcon(
                            DsIconKind.check,
                            size: 22,
                            color: theme.success,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ] else
          DSInput(
            controller: _manualModelController,
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
