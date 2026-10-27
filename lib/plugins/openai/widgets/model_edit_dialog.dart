import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/llm_models.dart';

/// 模型新增/编辑对话框；pop 返回编辑后的 [LLMModel]，取消返回 null
class ModelEditDialog extends StatefulWidget {
  final LLMModel? model;
  final List<String> groups;

  const ModelEditDialog({super.key, this.model, required this.groups});

  @override
  State<ModelEditDialog> createState() => _ModelEditDialogState();
}

class _ModelEditDialogState extends State<ModelEditDialog> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _contextLimitController = TextEditingController();
  final _maxOutputController = TextEditingController();
  late String _selectedGroup;
  late bool? _supportsVision;
  late bool? _supportsReasoning;

  /// DSInput 无内建 Form 校验，提交时手动校验（经 errorText 展示）
  String? _idError;
  String? _nameError;
  String? _contextLimitError;
  String? _maxOutputError;

  @override
  void initState() {
    super.initState();
    if (widget.model != null) {
      _idController.text = widget.model!.id;
      _nameController.text = widget.model!.name;
      _selectedGroup = widget.model!.group;
      _supportsVision = widget.model!.supportsVision;
      _supportsReasoning = widget.model!.supportsReasoning;
      _contextLimitController.text =
          widget.model!.contextLimit?.toString() ?? '';
      _maxOutputController.text = widget.model!.maxOutput?.toString() ?? '';
    } else {
      _selectedGroup = widget.groups.isNotEmpty ? widget.groups.first : '';
      _supportsVision = null;
      _supportsReasoning = null;
    }
  }

  /// 留空表示未设置；填了必须是合法正整数
  String? _validateLimit(String text) =>
      text.isEmpty || int.tryParse(text) != null
      ? null
      : 'openai_pleaseEnterValidNumber'.tr;

  void _submit() {
    final idError =
        widget.model == null && _idController.text.isEmpty
        ? 'openai_pleaseEnterModelId'.tr
        : '';
    final nameError =
        _nameController.text.isEmpty ? 'openai_pleaseEnterModelName'.tr : '';
    final contextLimitError = _validateLimit(_contextLimitController.text);
    final maxOutputError = _validateLimit(_maxOutputController.text);

    setState(() {
      _idError = idError.isEmpty ? null : idError;
      _nameError = nameError.isEmpty ? null : nameError;
      _contextLimitError = contextLimitError;
      _maxOutputError = maxOutputError;
    });

    if (idError.isNotEmpty ||
        nameError.isNotEmpty ||
        contextLimitError != null ||
        maxOutputError != null) {
      return;
    }

    Navigator.of(context).pop(
      LLMModel(
        id: widget.model?.id ?? _idController.text,
        name: _nameController.text,
        group: _selectedGroup,
        supportsVision: _supportsVision,
        supportsReasoning: _supportsReasoning,
        contextLimit: int.tryParse(_contextLimitController.text),
        maxOutput: int.tryParse(_maxOutputController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.model == null
                        ? 'openai_addModel'.tr
                        : 'openai_editModel'.tr,
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.lg),
                  if (widget.model == null)
                    DSInput(
                      controller: _idController,
                      label: 'openai_modelId'.tr,
                      hint: 'openai_modelIdExample'.tr,
                      errorText: _idError,
                      onChanged: (_) {
                        if (_idError != null) {
                          setState(() => _idError = null);
                        }
                      },
                    ),
                  if (widget.model == null) SizedBox(height: theme.spacing.md),
                  DSInput(
                    controller: _nameController,
                    label: 'openai_modelName'.tr,
                    hint: 'openai_modelNameExample'.tr,
                    errorText: _nameError,
                    onChanged: (_) {
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                  SizedBox(height: theme.spacing.md),
                  DSSelect<String>(
                    value: _selectedGroup,
                    items:
                        widget.groups
                            .map(
                              (group) =>
                                  DSSelectItem(label: group, value: group),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedGroup = value;
                        });
                      }
                    },
                  ),
                  SizedBox(height: theme.spacing.lg),
                  _buildCapabilitySection(theme),
                  SizedBox(height: theme.spacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          label: 'openai_cancel'.tr,
                          variant: DSButtonVariant.outline,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(width: theme.spacing.md),
                      Expanded(
                        child: DSButton(
                          label: 'openai_save'.tr,
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 能力设置区：多模态 / 思考（三态选择），输入 / 输出长度限制（留空未设置）
  Widget _buildCapabilitySection(AppThemeData theme) {
    Widget sectionLabel(String text) => Text(
      text,
      style: DsTypography.caption.copyWith(color: theme.textSub),
    );
    Widget triStateSelect({
      required String label,
      required bool? value,
      required ValueChanged<bool?> onChanged,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionLabel(label),
        SizedBox(height: theme.spacing.xs),
        DSSelect<bool?>(
          value: value,
          items: [
            DSSelectItem(label: 'openai_capUnset'.tr, value: null),
            DSSelectItem(label: 'openai_capYes'.tr, value: true),
            DSSelectItem(label: 'openai_capNo'.tr, value: false),
          ],
          onChanged: onChanged,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionLabel('openai_modelCapabilities'.tr),
        SizedBox(height: theme.spacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: triStateSelect(
                label: 'openai_supportsVision'.tr,
                value: _supportsVision,
                onChanged: (v) => setState(() => _supportsVision = v),
              ),
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: triStateSelect(
                label: 'openai_supportsReasoning'.tr,
                value: _supportsReasoning,
                onChanged: (v) => setState(() => _supportsReasoning = v),
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DSInput(
                controller: _contextLimitController,
                label: 'openai_contextLimit'.tr,
                hint: 'openai_limitHint'.tr,
                keyboardType: TextInputType.number,
                errorText: _contextLimitError,
                onChanged: (_) {
                  if (_contextLimitError != null) {
                    setState(() => _contextLimitError = null);
                  }
                },
              ),
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: DSInput(
                controller: _maxOutputController,
                label: 'openai_maxOutput'.tr,
                hint: 'openai_limitHint'.tr,
                keyboardType: TextInputType.number,
                errorText: _maxOutputError,
                onChanged: (_) {
                  if (_maxOutputError != null) {
                    setState(() => _maxOutputError = null);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _contextLimitController.dispose();
    _maxOutputController.dispose();
    super.dispose();
  }
}

/// 远端模型来源选择对话框：勾选要导入的 provider；pop 返回选中的分组
class ProviderPickDialog extends StatefulWidget {
  final List<LLMModelGroup> remoteGroups;
  final Set<String> existingGroupIds;

  const ProviderPickDialog({
    super.key,
    required this.remoteGroups,
    required this.existingGroupIds,
  });

  @override
  State<ProviderPickDialog> createState() => _ProviderPickDialogState();
}

class _ProviderPickDialogState extends State<ProviderPickDialog> {
  String _query = '';
  late final List<LLMModelGroup> _sorted;
  late final Set<int> _selected;

  @override
  void initState() {
    super.initState();
    // 与本地已有组匹配的来源排前面并默认勾选
    final matched = <LLMModelGroup>[];
    final rest = <LLMModelGroup>[];
    for (final group in widget.remoteGroups) {
      (widget.existingGroupIds.contains(group.id) ? matched : rest).add(group);
    }
    int byName(LLMModelGroup a, LLMModelGroup b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    _sorted = [...matched..sort(byName), ...rest..sort(byName)];
    _selected = {
      for (var i = 0; i < matched.length; i++)
        _sorted.indexOf(matched[i]),
    };
  }

  void _toggle(int index) {
    setState(() {
      if (!_selected.remove(index)) {
        _selected.add(index);
      }
    });
  }

  void _submit() {
    final chosen = [
      for (var i = 0; i < _sorted.length; i++)
        if (_selected.contains(i)) _sorted[i],
    ];
    Navigator.of(context).pop(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final query = _query.toLowerCase();
          final filtered = [
            for (var i = 0; i < _sorted.length; i++)
              if (query.isEmpty ||
                  _sorted[i].name.toLowerCase().contains(query) ||
                  _sorted[i].id.toLowerCase().contains(query))
                i,
          ];
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'openai_selectProviders'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.md),
                DSInput.search(
                  hint: 'openai_searchModel'.tr,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                ),
                SizedBox(height: theme.spacing.sm),
                Flexible(
                  child: filtered.isEmpty
                      ? Center(child: Text('openai_noModelsFound'.tr))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final i = filtered[index];
                            final group = _sorted[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: DSCard(
                                padding: EdgeInsets.symmetric(
                                  horizontal: theme.spacing.sm,
                                  vertical: theme.spacing.xs,
                                ),
                                onTap: () => _toggle(i),
                                child: Row(
                                  children: [
                                    DSCheckbox(
                                      value: _selected.contains(i),
                                      onChanged: (_) => _toggle(i),
                                    ),
                                    SizedBox(width: theme.spacing.sm),
                                    Expanded(
                                      child: Text(
                                        group.name,
                                        style: DsTypography.body.copyWith(
                                          color: theme.text,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${group.models.length}',
                                      style: DsTypography.body.copyWith(
                                        color: theme.textSub,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SizedBox(height: theme.spacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DSButton(
                        label: 'openai_cancel'.tr,
                        variant: DSButtonVariant.outline,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: DSButton(
                        label: 'openai_import'.tr,
                        onPressed: _selected.isEmpty ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
