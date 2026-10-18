import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';
import 'package:aboutme/plugins/openai/models/api_format.dart';
import 'package:aboutme/plugins/openai/models/llm_models.dart';
import 'package:aboutme/plugins/openai/models/service_provider.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'model_search_screen.dart';

/// 默认识图模型的简洁配置表单（agent_edit_screen 的裁剪版）：
/// 服务商 / API 格式 / BaseUrl / Headers / 模型。
/// 结果写入 settings['multimodalModelConfig']，read_image 在当前模型
/// 不支持视觉输入时用它发起独立的多模态请求
class MultimodalModelSetupScreen extends StatefulWidget {
  const MultimodalModelSetupScreen({super.key});

  @override
  State<MultimodalModelSetupScreen> createState() =>
      _MultimodalModelSetupScreenState();
}

class _MultimodalModelSetupScreenState
    extends State<MultimodalModelSetupScreen> {
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _headersController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  List<ServiceProvider> _providers = [];
  String? _selectedProviderId;
  String _apiFormat = 'openai';

  @override
  void initState() {
    super.initState();
    _restoreConfig();
    _loadProviders();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _headersController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _restoreConfig() {
    final config =
        OpenAIPlugin.instance.settings['multimodalModelConfig']
            as Map<String, dynamic>?;
    if (config == null) {
      // 旧版仅有模型名配置时带出模型，其余待选厂商后预填
      _modelController.text =
          (OpenAIPlugin.instance.settings['defaultMultimodalModel'] as String?)
              ?.trim() ??
          '';
      return;
    }
    _selectedProviderId =
        (config['providerId'] as String?)?.trim().isNotEmpty == true
            ? config['providerId'] as String
            : null;
    _apiFormat = (config['apiFormat'] as String?) ?? 'openai';
    _baseUrlController.text = (config['baseUrl'] as String?) ?? '';
    _headersController.text = _formatHeaders(
      config['headers'] is Map
          ? Map<String, String>.from(config['headers'] as Map)
          : <String, String>{},
    );
    _modelController.text = (config['model'] as String?) ?? '';
  }

  Future<void> _loadProviders() async {
    try {
      _providers = await ProviderController().getProviders();
      if (!mounted) return;
      final savedValid =
          _selectedProviderId != null &&
          _providers.any((p) => p.id == _selectedProviderId);
      if (_providers.isNotEmpty && !savedValid) {
        // 未配置过：默认用引导配置的厂商并预填连接配置
        final defaultId =
            OpenAIPlugin.instance.settings['defaultProviderId'] as String?;
        final provider = _providers.firstWhere(
          (p) => p.id == defaultId,
          orElse: () => _providers.first,
        );
        _selectedProviderId = provider.id;
        _applyProvider(provider);
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ToastService.instance.showToast('加载厂商失败: $e');
      }
    }
  }

  /// 切换厂商时预填连接配置；已选模型不覆盖
  void _applyProvider(ServiceProvider provider) {
    _baseUrlController.text = provider.baseUrl;
    _headersController.text = _formatHeaders(provider.headers);
    _apiFormat = provider.apiFormat;
    final defaultModel = provider.defaultModel;
    if (_modelController.text.trim().isEmpty &&
        defaultModel != null &&
        defaultModel.isNotEmpty) {
      _modelController.text = defaultModel;
    }
  }

  String _formatHeaders(Map<String, String> headers) =>
      headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');

  Map<String, String> _parseHeaders(String text) {
    final result = <String, String>{};
    for (var line in text.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;
      final index = line.indexOf(':');
      if (index > 0) {
        result[line.substring(0, index).trim()] =
            line.substring(index + 1).trim();
      }
    }
    return result;
  }

  Future<void> _selectModel() async {
    final selected = await NavigationHelper.push<LLMModel>(
      context,
      ModelSearchScreen(
        initialModelId: _modelController.text.trim(),
        initialProvider: _selectedProviderId,
        visionOnly: true,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _modelController.text = selected.id);
    }
  }

  Future<void> _save() async {
    final model = _modelController.text.trim();
    if (model.isEmpty) {
      ToastService.instance.showToast('请先选择识图模型');
      return;
    }
    await OpenAIPlugin.instance.updateSettings({
      'multimodalModelConfig': {
        'providerId': _selectedProviderId ?? '',
        'apiFormat': _apiFormat,
        'baseUrl': _baseUrlController.text.trim(),
        'headers': _parseHeaders(_headersController.text),
        'model': model,
      },
      // 兼容旧版只读模型名的逻辑
      'defaultMultimodalModel': model,
    });
    if (mounted) {
      ToastService.instance.showToast('保存成功');
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Scaffold(
        appBar: AppBar(title: const Text('识图模型配置')),
        body: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return ListView(
              padding: EdgeInsets.all(theme.spacing.lg),
              children: [
                DSSelect<String>(
                  value: _selectedProviderId,
                  hint: 'openai_pleaseSelectProvider'.tr,
                  items: _providers
                      .map((p) => DSSelectItem(label: p.label, value: p.id))
                      .toList(),
                  onChanged: (value) {
                    for (final provider in _providers) {
                      if (provider.id == value) {
                        setState(() {
                          _selectedProviderId = value;
                          _applyProvider(provider);
                        });
                        break;
                      }
                    }
                  },
                ),
                SizedBox(height: theme.spacing.lg),
                DSSelect<String>(
                  value: _apiFormat,
                  hint: 'API 格式',
                  items: ApiFormat.values
                      .map(
                        (format) => DSSelectItem(
                          label: format.label,
                          value: format.value,
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _apiFormat = value),
                ),
                SizedBox(height: theme.spacing.lg),
                DSInput(
                  controller: _baseUrlController,
                  label: 'openai_baseUrl'.tr,
                  hint: 'openai_enterBaseUrl'.tr,
                ),
                SizedBox(height: theme.spacing.lg),
                DSListItem(
                  leading: DsIcon(
                    DsIconKind.bot,
                    size: 22,
                    color: theme.primary,
                  ),
                  title: 'openai_model'.tr,
                  subtitle:
                      _modelController.text.trim().isEmpty
                          ? '请选择支持视觉能力的模型'
                          : _modelController.text.trim(),
                  showChevron: true,
                  onTap: _selectModel,
                ),
                SizedBox(height: theme.spacing.lg),
                DSInput(
                  controller: _headersController,
                  label: 'openai_headers'.tr,
                  hint: 'openai_enterHeaders'.tr,
                  maxLines: 3,
                ),
                SizedBox(height: theme.spacing.xl),
                DSButton(
                  label: 'openai_save'.tr,
                  expand: true,
                  onPressed: _save,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
