import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/llm_models.dart';
import 'package:aboutme/plugins/openai/controllers/model_controller.dart';
import 'package:aboutme/plugins/openai/widgets/model_edit_dialog.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';

class ModelListScreen extends StatefulWidget {
  const ModelListScreen({super.key});

  @override
  State<ModelListScreen> createState() => _ModelListScreenState();
}

class _ModelListScreenState extends State<ModelListScreen> {
  List<LLMModelGroup> _modelGroups = [];
  late ModelController _modelController;
  final Map<String, String> _defaultModels = {};
  final Map<String, dynamic> _multiFilters = {};
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isFetching = false;

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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('${'openai_loadModelsFailed'.tr}: $e');
        setState(() {
          _modelGroups = [];
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
        toastService.showToast(
          'openai_defaultModelSet'.trParams({'model': modelId}),
        );
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('${'openai_setDefaultModelFailed'.tr}: $e');
      }
    }
  }

  /// 当前选中分组下的可见模型：分组过滤 → 搜索过滤
  List<LLMModel> get _visibleModels {
    final selectedGroup = _multiFilters['group'] as String?;
    final models = switch (selectedGroup) {
      null || 'all' => [for (final g in _modelGroups) ...g.models],
      final id => [
        for (final g in _modelGroups)
          if (g.id == id) ...g.models,
      ],
    };
    if (_searchQuery.isEmpty) return models;
    final query = _searchQuery.toLowerCase();
    return models
        .where((model) => model.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text('openai_modelManagement'.tr),
      enableLargeTitle: false,
      actions: [_buildRefreshButton(), _buildAddButton()],
      // ===== 搜索 =====
      enableSearchBar: true,
      searchPlaceholder: 'openai_searchModel'.tr,
      onSearchChanged: (query) => setState(() => _searchQuery = query),
      // ===== 分组过滤栏（替代原 TabBar）=====
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      onMultiFilterChanged: _handleFilterChanged,
      body: _buildBody(),
    );
  }

  Widget _buildRefreshButton() {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return DSIconButton(
          icon: DsIconKind.refresh,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: _isFetching ? null : _fetchAndImportModels,
          tooltip: 'openai_fetchLatestModels'.tr,
        );
      },
    );
  }

  Widget _buildAddButton() {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return DSIconButton(
          icon: DsIconKind.plus,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: _addNewModel,
        );
      },
    );
  }

  /// 多条件过滤项：分组切换（单选）
  List<FilterItem> _buildFilterItems() {
    final groupOptions = {for (final g in _modelGroups) g.id: g.name};
    return [
      FilterItem(
        id: 'group',
        title: 'openai_groupFilterTitle'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildSingleChoiceFilter(
            context: context,
            currentValue: currentValue,
            // 单选完成即返回第一层
            onChanged: (value) => onChanged(value, done: true),
            options: groupOptions,
            allItemsKey: 'all',
            allItemsLabel: 'openai_allGroups'.tr,
          );
        },
        getBadge:
            (value) => FilterBuilders.singleChoiceBadge(value, groupOptions),
      ),
    ];
  }

  void _handleFilterChanged(Map<String, dynamic> values) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _multiFilters
            ..clear()
            ..addAll(values);
        });
      }
    });
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: DSLoadingDots());
    if (_modelGroups.isEmpty) {
      return Center(child: Text('openai_cannotLoadModels'.tr));
    }
    final models = _visibleModels;
    if (models.isEmpty) {
      return Center(child: Text('openai_noModelsFound'.tr));
    }
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        // 模型 → 所属分组（"全部"视图下星标仍按组判断默认模型）
        final groupOf = {
          for (final g in _modelGroups) for (final m in g.models) m.id: g.id,
        };
        // 手绘便签列表：倾斜姿态由 model.id 确定性生成
        return HandDrawnListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          tiltKeyOf: (index) => models[index].id,
          itemCount: models.length,
          itemBuilder: (context, index) {
            final model = models[index];
            final groupId = groupOf[model.id] ?? '';
            final isDefault = _getDefaultModelForGroup(groupId) == model.id;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      color: isDefault ? theme.warning : theme.surfaceAlt,
                      iconColor: isDefault ? theme.onWarning : theme.textSub,
                      onPressed: () => _setDefaultModel(groupId, model.id),
                      tooltip: 'openai_setDefaultModelTooltip'.tr,
                    ),
                    SizedBox(width: theme.spacing.sm),
                    Expanded(
                      child: Text(
                        model.name,
                        style: DsTypography.body.copyWith(color: theme.text),
                      ),
                    ),
                    DSIconButton(
                      icon: DsIconKind.trash,
                      size: 38,
                      color: theme.danger,
                      iconColor: theme.onDanger,
                      onPressed: () => _deleteModel(model),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 从 models.dev 拉取最新模型列表，选择来源后合并进本地
  Future<void> _fetchAndImportModels() async {
    if (_isFetching) return;
    setState(() {
      _isFetching = true;
    });

    try {
      toastService.showToast('openai_fetchingModels'.tr);
      final remoteGroups = await _modelController.fetchRemoteModelGroups();
      if (!mounted) return;

      final chosen = await showDSDialog<List<LLMModelGroup>>(
        context: context,
        theme: DSThemeBridge.resolve(context),
        builder:
            (context) => ProviderPickDialog(
              remoteGroups: remoteGroups,
              existingGroupIds: _modelGroups.map((g) => g.id).toSet(),
            ),
      );
      if (chosen == null || chosen.isEmpty) return;

      final result = await _modelController.mergeModelGroups(chosen);
      if (!mounted) return;
      toastService.showToast(
        'openai_syncResult'.trParams({
          'groups': '${result.addedGroups}',
          'models': '${result.addedModels}',
        }),
      );
      await _loadModels();
    } catch (e) {
      if (mounted) {
        toastService.showToast('${'openai_fetchModelsFailed'.tr}: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  Future<void> _addNewModel() async {
    final result = await showDSDialog<LLMModel>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) =>
              ModelEditDialog(groups: _modelGroups.map((g) => g.id).toList()),
    );

    if (result != null) {
      try {
        await _modelController.addModel(result);
        await _loadModels();
      } catch (e) {
        if (mounted) {
          toastService.showToast('${'openai_addModelFailed'.tr}: $e');
        }
      }
    }
  }

  Future<void> _editModel(LLMModel model) async {
    final result = await showDSDialog<LLMModel>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => ModelEditDialog(
            model: model,
            groups: _modelGroups.map((g) => g.id).toList(),
          ),
    );

    if (result != null) {
      try {
        await _modelController.updateModel(result);
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
}

