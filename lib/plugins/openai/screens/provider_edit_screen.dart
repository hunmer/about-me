import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/openai/models/service_provider.dart';
import 'package:aboutme/plugins/openai/models/llm_models.dart';
import 'package:aboutme/plugins/openai/models/api_format.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';
import 'model_search_screen.dart';

class ProviderEditScreen extends StatefulWidget {
  final ServiceProvider? provider;

  const ProviderEditScreen({super.key, this.provider});

  @override
  State<ProviderEditScreen> createState() => _ProviderEditScreenState();
}

class _ProviderEditScreenState extends State<ProviderEditScreen> {
  final _labelController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _defaultModelController = TextEditingController();
  final _apiKeyController = TextEditingController();

  // 用于添加/编辑 header
  final _headerKeyController = TextEditingController();
  final _headerValueController = TextEditingController();

  // 存储当前的 headers
  Map<String, String> _headers = {};

  // API 格式
  String _apiFormat = 'openai';

  /// DSInput 无内建 Form 校验，提交时手动校验（经 errorText 展示）
  String? _labelError;
  String? _baseUrlError;
  String? _apiKeyError;
  String? _presetError;

  /// 高级模式：完全自定义；常规模式：选预设 + 填 API Key，其余自动生成
  bool _isAdvanced = false;
  String? _selectedPresetId;

  static const String _apiKeyPlaceholder = 'YOUR_API_KEY';

  /// 常规模式可选的预设（剔除 baseUrl 含占位符、无法直接使用的预设，如 Azure）
  late final List<ServiceProvider> _presets = ProviderController()
      .getDefaultProviders()
      .where((p) => !p.baseUrl.contains('YOUR_'))
      .toList();

  ServiceProvider? get _selectedPreset {
    final id = _selectedPresetId;
    if (id == null) return null;
    for (final preset in _presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.provider != null) {
      _labelController.text = widget.provider!.label;
      _baseUrlController.text = widget.provider!.baseUrl;
      _headers = Map<String, String>.from(widget.provider!.headers);
      _defaultModelController.text = widget.provider!.defaultModel ?? '';
      _apiFormat = widget.provider!.apiFormat;
      // 检查 apiFormat 是否有效，如果无效则使用默认值
      if (!ApiFormat.values.any((f) => f.value == _apiFormat)) {
        _apiFormat = 'openai';
      }
      // 能匹配预设则进入常规模式并回填 API Key，否则视为自定义配置
      final preset = _matchPreset(_baseUrlController.text.trim(), _apiFormat);
      if (preset != null) {
        _selectedPresetId = preset.id;
        _apiKeyController.text = _extractApiKey(_headers, preset);
      } else {
        _isAdvanced = true;
      }
    }
  }

  /// 按 baseUrl + API 格式匹配预设
  ServiceProvider? _matchPreset(String baseUrl, String apiFormat) {
    for (final preset in _presets) {
      if (preset.baseUrl == baseUrl && preset.apiFormat == apiFormat) {
        return preset;
      }
    }
    return null;
  }

  /// 从已有 headers 中还原 API Key（Authorization: Bearer xx 只取 xx，其余取原值）
  String _extractApiKey(Map<String, String> headers, ServiceProvider preset) {
    for (final entry in preset.headers.entries) {
      if (!entry.value.contains(_apiKeyPlaceholder)) continue;
      final value = headers[entry.key];
      if (value == null) continue;
      if (value.startsWith('Bearer ')) return value.substring(7);
      return value;
    }
    return '';
  }

  /// 用真实 API Key 替换预设 headers 模板中的占位符
  Map<String, String> _buildPresetHeaders(
    ServiceProvider preset,
    String apiKey,
  ) {
    return preset.headers.map(
      (key, value) =>
          MapEntry(key, value.replaceAll(_apiKeyPlaceholder, apiKey)),
    );
  }

  void _onPresetChanged(String? presetId) {
    if (presetId == null) return;
    setState(() {
      _selectedPresetId = presetId;
      _presetError = null;
      _apiKeyError = null;
    });
  }

  void _onModeChanged(int index) {
    final toAdvanced = index == 1;
    if (toAdvanced == _isAdvanced) return;
    if (toAdvanced) {
      // 常规 -> 高级：把预设推导出的字段物化到表单，已填内容不丢失
      final preset = _selectedPreset;
      if (preset != null) {
        _labelController.text = preset.label;
        _baseUrlController.text = preset.baseUrl;
        _apiFormat = preset.apiFormat;
        _headers = _buildPresetHeaders(preset, _apiKeyController.text.trim());
        if (_defaultModelController.text.trim().isEmpty &&
            preset.defaultModel != null) {
          _defaultModelController.text = preset.defaultModel!;
        }
      }
      setState(() => _isAdvanced = true);
    } else {
      // 高级 -> 常规：按当前 baseUrl 匹配预设并尝试回填 API Key
      final preset = _matchPreset(_baseUrlController.text.trim(), _apiFormat);
      setState(() {
        _isAdvanced = false;
        _presetError = null;
        _apiKeyError = null;
        if (preset != null) {
          _selectedPresetId = preset.id;
          _apiKeyController.text = _extractApiKey(_headers, preset);
        }
      });
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _baseUrlController.dispose();
    _defaultModelController.dispose();
    _apiKeyController.dispose();
    _headerKeyController.dispose();
    _headerValueController.dispose();
    super.dispose();
  }

  void _addHeader() {
    final key = _headerKeyController.text.trim();
    final value = _headerValueController.text.trim();

    if (key.isEmpty) {
      return;
    }

    setState(() {
      _headers[key] = value;
      _headerKeyController.clear();
      _headerValueController.clear();
    });
  }

  void _removeHeader(String key) {
    setState(() {
      _headers.remove(key);
    });
  }

  void _editHeader(String key) {
    _headerKeyController.text = key;
    _headerValueController.text = _headers[key] ?? '';
    _removeHeader(key);
  }

  Future<void> _selectDefaultModel() async {
    final providerId = _matchProviderFromUrl(_baseUrlController.text.trim());
    final selectedModel = await NavigationHelper.push<LLMModel>(
      context,
      ModelSearchScreen(
        initialModelId: _defaultModelController.text,
        initialProvider: providerId,
      ),
    );

    if (selectedModel != null) {
      setState(() {
        _defaultModelController.text = selectedModel.id;
      });
    }
  }

  /// 根据 baseUrl 匹配对应的服务商 ID
  String? _matchProviderFromUrl(String baseUrl) {
    if (baseUrl.isEmpty) return null;

    final lowerUrl = baseUrl.toLowerCase();

    // 定义 URL 模式到服务商 ID 的映射
    final Map<String, String> urlPatterns = {
      // OpenAI
      'api.openai.com': 'openai',
      // DeepSeek
      'api.deepseek.com': 'deepseek',
      // Anthropic
      'api.anthropic.com': 'anthropic',
      // Google
      'generativelanguage.googleapis.com': 'google',
      // 智谱 AI
      'open.bigmodel.cn': 'zhipu',
      'bigmodel.cn': 'zhipu',
      // 阿里云通义千问
      'dashscope.aliyuncs.com': 'alibaba-qwen',
      // 月之暗面
      'api.moonshot.cn': 'moonshot',
      'moonshot.cn': 'moonshot',
      // 讯飞星火
      'spark-api.xf-yun.com': 'xfyun',
      'xfyun.cn': 'xfyun',
      // MiniMax
      'api.minimax.chat': 'minimax',
      'minimax.chat': 'minimax',
      // Perplexity
      'api.perplexity.ai': 'perplexity',
      'perplexity.ai': 'perplexity',
      // xAI
      'api.x.ai': 'xai',
      'x.ai': 'xai',
      // Mistral
      'api.mistral.ai': 'mistral',
      'mistral.ai': 'mistral',
      // Cohere
      'api.cohere.ai': 'cohere',
      'cohere.ai': 'cohere',
      // Qwen (通义)
      'qwen-api.cn': 'qwen',
    };

    // 尝试匹配 URL 中的关键词
    for (final entry in urlPatterns.entries) {
      if (lowerUrl.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  Future<void> _saveProvider() async {
    // DSInput 无内建 Form 校验，提交时手动校验
    String? labelError;
    String? baseUrlError;
    String? apiKeyError;
    String? presetError;
    final label = _labelController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    // 常规模式以预设为准推导全部字段，只校验预设与 API Key
    final preset = _isAdvanced ? null : _selectedPreset;
    if (!_isAdvanced) {
      if (preset == null) {
        presetError = 'openai_presetRequired'.tr;
      } else if (apiKey.isEmpty &&
          preset.headers.values.any((v) => v.contains(_apiKeyPlaceholder))) {
        apiKeyError = 'openai_apiKeyRequired'.tr;
      }
    } else {
      if (label.isEmpty) {
        labelError = 'openai_providerLabelError'.tr;
      }
      if (baseUrl.isEmpty) {
        baseUrlError = 'openai_pleaseEnterBaseUrl'.tr;
      } else if (!baseUrl.startsWith('http://') &&
          !baseUrl.startsWith('https://')) {
        baseUrlError = 'openai_baseUrlError'.tr;
      }
    }

    setState(() {
      _labelError = labelError;
      _baseUrlError = baseUrlError;
      _apiKeyError = apiKeyError;
      _presetError = presetError;
    });

    if (labelError != null ||
        baseUrlError != null ||
        apiKeyError != null ||
        presetError != null) {
      return;
    }

    final controller = ProviderController();

    final provider = ServiceProvider(
      id: widget.provider?.id ?? const Uuid().v4(),
      label: preset?.label ?? label,
      baseUrl: preset?.baseUrl ?? baseUrl,
      headers: preset != null ? _buildPresetHeaders(preset, apiKey) : _headers,
      defaultModel: _defaultModelController.text.trim().isEmpty
          ? null
          : _defaultModelController.text.trim(),
      apiFormat: preset?.apiFormat ?? _apiFormat,
    );

    if (widget.provider == null) {
      await controller.addProvider(provider);
    } else {
      await controller.updateProvider(provider);
    }
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  // 检查是否有未添加的 header 输入
  bool _hasUnsavedHeaderInput() {
    return _headerKeyController.text.trim().isNotEmpty ||
        _headerValueController.text.trim().isNotEmpty;
  }

  // 显示确认对话框
  Future<bool> _showUnsavedChangesDialog() async {
    final result = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (dialogContext) => DSDialog(
            title: 'openai_unsavedChangesTitle'.tr,
            message: 'openai_unsavedHeaderWarning'.tr,
            confirmText: 'openai_discard'.tr,
            cancelText: 'openai_cancel'.tr,
            onConfirm: () => Navigator.of(dialogContext).pop(true),
            onCancel: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold/AppBar 属结构性组件,刻意保留 Material
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, dynamic result) async {
              if (didPop) return;

              // 检查是否有未添加的 header 输入
              if (_hasUnsavedHeaderInput()) {
                final shouldPop = await _showUnsavedChangesDialog();
                if (shouldPop && context.mounted) {
                  Navigator.pop(context);
                }
              } else {
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  widget.provider == null
                      ? 'openai_addProvider'.tr
                      : 'openai_editProvider'.tr,
                ),
                actions: [
                  // DS 按钮自带 DSThemeBridge 提供 AppTheme
                  DSThemeBridge(
                    child: Builder(
                      builder: (context) {
                        final theme = DSThemeBridge.resolve(context);
                        return DSIconButton(
                          icon: DsIconKind.check,
                          size: 40,
                          color: theme.surfaceAlt,
                          iconColor: theme.textSub,
                          onPressed: _saveProvider,
                          tooltip: 'openai_saveTooltip'.tr,
                        );
                      },
                    ),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DSSegmentedControl(
                    options: [
                      'openai_modeRegular'.tr,
                      'openai_modeAdvanced'.tr,
                    ],
                    selected: _isAdvanced ? 1 : 0,
                    onChanged: _onModeChanged,
                  ),
                  const SizedBox(height: 8),
                  if (!_isAdvanced)
                    Text(
                      'openai_regularModeDesc'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_isAdvanced) ...[
                    DSInput(
                      controller: _labelController,
                      label: 'openai_serviceProvider'.tr,
                      hint: 'openai_pleaseSelectProvider'.tr,
                      errorText: _labelError,
                      onChanged: (_) {
                        if (_labelError != null) {
                          setState(() => _labelError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DSInput(
                      controller: _baseUrlController,
                      label: 'openai_baseUrl'.tr,
                      hint: 'openai_enterBaseUrl'.tr,
                      errorText: _baseUrlError,
                      onChanged: (_) {
                        if (_baseUrlError != null) {
                          setState(() => _baseUrlError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DSInput(
                            controller: _defaultModelController,
                            label: '默认模型',
                            hint: '选择此服务商的默认模型',
                          ),
                        ),
                        SizedBox(width: theme.spacing.sm),
                        DSIconButton(
                          icon: DsIconKind.search,
                          size: 40,
                          color: theme.surfaceAlt,
                          iconColor: theme.textSub,
                          onPressed: _selectDefaultModel,
                          tooltip: 'openai_searchModel'.tr,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DSSelect<String>(
                      value: _apiFormat,
                      hint: '选择 API 格式',
                      items: ApiFormat.values
                          .map(
                            (format) => DSSelectItem(
                              label: format.label,
                              value: format.value,
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _apiFormat = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Headers',
                          style: DsTypography.title.copyWith(color: theme.text),
                        ),
                        _HeaderQuickSelect(
                          onSelected: (headerKey) {
                            _headerKeyController.text = headerKey;
                            // 自动聚焦到 value 输入框
                            FocusScope.of(context).requestFocus(FocusNode());
                            // 延迟聚焦，确保文本已填充
                            Future.delayed(
                              const Duration(milliseconds: 100),
                              () {
                                // 这里可以添加聚焦逻辑
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 描边对齐 DSInput/DSSelect（textSub 淡墨线 + 1.6 线宽）
                    JellyBox(
                      radius: theme.radii.xl,
                      padding: const EdgeInsets.all(16),
                      strokeColor: theme.textSub.withValues(alpha: 0.45),
                      borderWidth: 1.6,
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DSInput(
                                  controller: _headerKeyController,
                                  label: 'openai_headerKey'.tr,
                                  hint: 'openai_enterHeaders'.tr,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DSInput(
                                  controller: _headerValueController,
                                  label: 'openai_headerValue'.tr,
                                  hint: 'openai_enterHeaders'.tr,
                                ),
                              ),
                              const SizedBox(width: 8),
                              DSIconButton(
                                icon: DsIconKind.plus,
                                size: 40,
                                color: theme.surfaceAlt,
                                iconColor: theme.textSub,
                                onPressed: _addHeader,
                                tooltip: 'openai_addHeader'.tr,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _headers.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'openai_noHeaders'.tr,
                                      style: DsTypography.caption.copyWith(
                                        color: theme.textSub,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _headers.length,
                                  itemBuilder: (context, index) {
                                    final key = _headers.keys.elementAt(index);
                                    final value = _headers[key]!;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  key,
                                                  style: DsTypography.body
                                                      .copyWith(
                                                        color: theme.text,
                                                      ),
                                                ),
                                                Text(
                                                  value,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: DsTypography.caption
                                                      .copyWith(
                                                        color: theme.textSub,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DSIconButton(
                                            icon: DsIconKind.edit,
                                            size: 36,
                                            color: theme.surfaceAlt,
                                            iconColor: theme.textSub,
                                            onPressed: () => _editHeader(key),
                                            tooltip: 'openai_editHeader'.tr,
                                          ),
                                          DSIconButton(
                                            icon: DsIconKind.trash,
                                            size: 36,
                                            color: theme.danger,
                                            iconColor: theme.onDanger,
                                            onPressed: () => _removeHeader(key),
                                            tooltip: 'openai_deleteHeader'.tr,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ] else ...[
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
                      onChanged: _onPresetChanged,
                    ),
                    if (_presetError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _presetError!,
                          style: DsTypography.caption.copyWith(
                            color: theme.danger,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    DSInput(
                      controller: _apiKeyController,
                      label: 'openai_apiKey'.tr,
                      hint: 'openai_apiKeyHint'.tr,
                      errorText: _apiKeyError,
                      onChanged: (_) {
                        if (_apiKeyError != null) {
                          setState(() => _apiKeyError = null);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 快捷选择常见 Header 类型的下拉选择器
class _HeaderQuickSelect extends StatefulWidget {
  final Function(String) onSelected;

  const _HeaderQuickSelect({required this.onSelected});

  @override
  State<_HeaderQuickSelect> createState() => _HeaderQuickSelectState();
}

class _HeaderQuickSelectState extends State<_HeaderQuickSelect> {
  String? _selectedValue;

  // 常见的 Header 类型
  static const Map<String, String> _commonHeaders = {
    'Authorization': 'Authorization',
    'x-api-key': 'x-api-key',
    'api-key': 'api-key',
    'Content-Type': 'Content-Type',
    'Accept': 'Accept',
    'User-Agent': 'User-Agent',
    'Bearer': 'Authorization: Bearer',
    'Custom': '',
  };

  @override
  Widget build(BuildContext context) {
    return DSSelect<String>(
      value: _selectedValue,
      hint: '快捷选择',
      width: 150,
      items: _commonHeaders.entries
          .map(
            (entry) => DSSelectItem(
              label: _getDisplayLabel(entry.key),
              value: entry.key,
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedValue = value;
          });
          widget.onSelected(_commonHeaders[value] ?? value);
          // 重置选择，方便下次使用
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _selectedValue = null;
              });
            }
          });
        }
      },
    );
  }

  String _getDisplayLabel(String key) {
    switch (key) {
      case 'Authorization':
        return 'Authorization';
      case 'x-api-key':
        return 'x-api-key';
      case 'api-key':
        return 'api-key';
      case 'Content-Type':
        return 'Content-Type';
      case 'Accept':
        return 'Accept';
      case 'User-Agent':
        return 'User-Agent';
      case 'Bearer':
        return 'Bearer Token';
      case 'Custom':
        return '自定义';
      default:
        return key;
    }
  }
}
