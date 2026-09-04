import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/llm_models.dart';
import 'package:aboutme/plugins/openai/controllers/model_controller.dart';
import 'package:aboutme/core/services/toast_service.dart';

class ModelListScreen extends StatefulWidget {
  const ModelListScreen({super.key});

  @override
  State<ModelListScreen> createState() => _ModelListScreenState();
}

class _ModelListScreenState extends State<ModelListScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  late List<LLMModelGroup> _modelGroups;
  late ModelController _modelController;
  final Map<String, String> _defaultModels = {};
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _modelController = ModelController();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final models = await _modelController.getModels();
      // 加载每个分组的默认模型
      for (final group in models) {
        final defaultModel = await _modelController.getDefaultModel(group.id);
        if (defaultModel != null) {
          _defaultModels[group.id] = defaultModel;
        }
      }
      if (mounted) {
        setState(() {
          _modelGroups = models;
          _tabController?.dispose(); // 在创建新的之前释放旧的
          _tabController = TabController(
            length: _modelGroups.length,
            vsync: this,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('${'openai_loadModelsFailed'.tr}: $e');
        setState(() {
          _modelGroups = [];
          _tabController?.dispose(); // 在创建新的之前释放旧的
          _tabController = TabController(length: 1, vsync: this);
          _isLoading = false;
        });
      }
    }
  }

  String? _getDefaultModelForGroup(String groupId) {
    return _defaultModels[groupId];
  }

  Future<void> _setDefaultModel(String groupId, String modelId) async {
    try {
      await _modelController.setDefaultModel(groupId, modelId);
      setState(() {
        _defaultModels[groupId] = modelId;
      });
      if (mounted) {
        toastService.showToast('已设置默认模型: $modelId');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('设置默认模型失败: $e');
      }
    }
  }

  List<LLMModel> _getFilteredModels(List<LLMModel> models) {
    if (_searchQuery.isEmpty) {
      return models;
    }
    return models
        .where(
          (model) =>
              model.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold/AppBar/TabBar/TabBarView/TabController 属结构性组件,刻意保留 Material
    return DSThemeBridge(
      child: Scaffold(
        appBar: AppBar(
          title: Text('openai_modelManagement'.tr),
          actions: [
            // DS 按钮自带 DSThemeBridge 提供 AppTheme
            DSThemeBridge(
              child: Builder(
                builder: (context) {
                  final theme = DSThemeBridge.resolve(context);
                  return DSIconButton(
                    icon: DsIconKind.plus,
                    size: 40,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    onPressed: _addNewModel,
                  );
                },
              ),
            ),
          ],
          bottom:
              _isLoading
                  ? null
                  : PreferredSize(
                    preferredSize: const Size.fromHeight(
                      104.0,
                    ), // 增加高度，为搜索框和TabBar提供足够空间
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: DSInput.search(
                            hint: 'openai_searchModel'.tr,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                        ),
                        if (_tabController != null)
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabs:
                                _modelGroups
                                    .map((group) => Tab(text: group.name))
                                    .toList(),
                          ),
                      ],
                    ),
                  ),
        ),
        body: Builder(
          builder:
              (context) =>
                  _isLoading
                      ? const Center(child: DSLoadingDots())
                      : _tabController == null
                      ? Center(child: Text('openai_cannotLoadModels'.tr))
                      : TabBarView(
                        controller: _tabController,
                        children:
                            _modelGroups.map((group) {
                              final filteredModels = _getFilteredModels(
                                group.models,
                              );
                              return filteredModels.isEmpty
                                  ? Center(
                                    child: Text('openai_noModelsFound'.tr),
                                  )
                                  : Builder(
                                    builder: (context) {
                                      final theme = DSThemeBridge.resolve(
                                        context,
                                      );
                                      return ListView.builder(
                                        itemCount: filteredModels.length,
                                        itemBuilder: (context, index) {
                                          final model = filteredModels[index];
                                          final isDefault =
                                              _getDefaultModelForGroup(
                                                group.id,
                                              ) ==
                                              model.id;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 4,
                                            ),
                                            child: DSCard(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: theme.spacing.md,
                                                vertical: theme.spacing.xs,
                                              ),
                                              onTap: () => _editModel(model),
                                              child: Row(
                                                children: [
                                                  DSIconButton(
                                                    icon: DsIconKind.star,
                                                    size: 38,
                                                    color:
                                                        isDefault
                                                            ? theme.warning
                                                            : theme.surfaceAlt,
                                                    iconColor:
                                                        isDefault
                                                            ? theme.onWarning
                                                            : theme.textSub,
                                                    onPressed:
                                                        () => _setDefaultModel(
                                                          group.id,
                                                          model.id,
                                                        ),
                                                    tooltip: '设为默认模型',
                                                  ),
                                                  SizedBox(
                                                    width: theme.spacing.sm,
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      model.name,
                                                      style: DsTypography.body
                                                          .copyWith(
                                                            color: theme.text,
                                                          ),
                                                    ),
                                                  ),
                                                  DSIconButton(
                                                    icon: DsIconKind.trash,
                                                    size: 38,
                                                    color: theme.danger,
                                                    iconColor: theme.onDanger,
                                                    onPressed:
                                                        () =>
                                                            _deleteModel(model),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                            }).toList(),
                      ),
        ),
      ),
    );
  }

  Future<void> _addNewModel() async {
    final result = await showDSDialog<Map<String, dynamic>>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) =>
              _ModelEditDialog(groups: _modelGroups.map((g) => g.id).toList()),
    );

    if (result != null) {
      try {
        final newModel = LLMModel(
          id: result['id'] as String,
          name: result['name'] as String,
          group: result['group'] as String,
        );

        await _modelController.addModel(newModel);
        await _loadModels();
      } catch (e) {
        if (mounted) {
          toastService.showToast('${'openai_addModelFailed'.tr}: $e');
        }
      }
    }
  }

  Future<void> _editModel(LLMModel model) async {
    final result = await showDSDialog<Map<String, dynamic>>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => _ModelEditDialog(
            model: model,
            groups: _modelGroups.map((g) => g.id).toList(),
          ),
    );

    if (result != null) {
      try {
        final updatedModel = LLMModel(
          id: model.id,
          name: result['name'] as String,
          group: result['group'] as String,
        );

        await _modelController.updateModel(updatedModel);
        await _loadModels();
      } catch (e) {
        if (mounted) {
          toastService.showToast('${'openai_updateModelFailed'.tr}: $e');
        }
      }
    }
  }

  Future<void> _deleteModel(LLMModel model) async {
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (dialogContext) => DSDialog(
                    title: 'openai_confirmDelete'.tr,
                    message: 'openai_confirmDeleteModel'.trParams({
                      'modelName': model.name,
                    }),
                    confirmText: 'openai_delete'.tr,
                    cancelText: 'openai_cancel'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onConfirm: () => Navigator.of(dialogContext).pop(true),
                    onCancel: () => Navigator.of(dialogContext).pop(false),
                  ),
            ),
          ),
    );

    if (confirm == true) {
      try {
        await _modelController.deleteModel(model.id);
        await _loadModels();
      } catch (e) {
        if (mounted) {
          toastService.showToast('${'openai_deleteModelFailed'.tr}: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}

class _ModelEditDialog extends StatefulWidget {
  final LLMModel? model;
  final List<String> groups;

  const _ModelEditDialog({this.model, required this.groups});

  @override
  State<_ModelEditDialog> createState() => _ModelEditDialogState();
}

class _ModelEditDialogState extends State<_ModelEditDialog> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  late String _selectedGroup;

  /// DSInput 无内建 Form 校验，提交时手动校验（经 errorText 展示）
  String? _idError;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    if (widget.model != null) {
      _idController.text = widget.model!.id;
      _nameController.text = widget.model!.name;
      _selectedGroup = widget.model!.group;
    } else {
      _selectedGroup = widget.groups.isNotEmpty ? widget.groups.first : '';
    }
  }

  void _submit() {
    var idError = '';
    var nameError = '';
    if (widget.model == null && _idController.text.isEmpty) {
      idError = 'openai_pleaseEnterModelId'.tr;
    }
    if (_nameController.text.isEmpty) {
      nameError = 'openai_pleaseEnterModelName'.tr;
    }

    setState(() {
      _idError = idError.isEmpty ? null : idError;
      _nameError = nameError.isEmpty ? null : nameError;
    });

    if (idError.isNotEmpty || nameError.isNotEmpty) return;

    Navigator.of(context).pop({
      'id': widget.model?.id ?? _idController.text,
      'name': _nameController.text,
      'group': _selectedGroup,
    });
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

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
