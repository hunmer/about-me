import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/llm_models.dart';
import 'package:aboutme/plugins/openai/controllers/model_controller.dart';
import 'package:aboutme/plugins/openai/widgets/provider_logo.dart';
import '../../../../core/services/toast_service.dart';

class ModelSearchScreen extends StatefulWidget {
  final String? initialModelId;
  final String? initialProvider;

  const ModelSearchScreen({
    super.key,
    this.initialModelId,
    this.initialProvider,
  });

  @override
  State<ModelSearchScreen> createState() => _ModelSearchScreenState();
}

class _ModelSearchScreenState extends State<ModelSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<LLMModelGroup> _modelGroups;
  late ModelController _modelController;
  String _searchQuery = '';
  bool _isLoading = true;
  LLMModel? _selectedModel;

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
      setState(() {
        _modelGroups = models;
        _tabController = TabController(
          length: _modelGroups.length,
          vsync: this,
        );
        _isLoading = false;
      });

      if (widget.initialModelId != null) {
        _findInitialModel();
      } else if (widget.initialProvider != null) {
        _findInitialProvider();
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('${'openai_loadModelsFailed'.tr}: $e');
      }
      setState(() {
        _modelGroups = [];
        _tabController = TabController(length: 1, vsync: this);
        _isLoading = false;
      });
    }
  }

  void _findInitialModel() {
    for (int i = 0; i < _modelGroups.length; i++) {
      final groupModels = _modelGroups[i].models;
      for (int j = 0; j < groupModels.length; j++) {
        if (groupModels[j].id == widget.initialModelId) {
          _selectedModel = groupModels[j];
          _tabController.animateTo(i);
          break;
        }
      }
      if (_selectedModel != null) break;
    }
  }

  void _findInitialProvider() {
    for (int i = 0; i < _modelGroups.length; i++) {
      if (_modelGroups[i].id == widget.initialProvider) {
        _tabController.animateTo(i);
        break;
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
              model.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              model.group.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('openai_searchModel'.tr),
        actions: [
          if (_selectedModel != null)
            // DS 按钮自带 DSThemeBridge 提供 AppTheme
            DSThemeBridge(
              child: Builder(
                builder: (context) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DSButton(
                      label: 'app_ok'.tr,
                      variant: DSButtonVariant.ghost,
                      size: DSButtonSize.sm,
                      onPressed: () {
                        Navigator.of(context).pop(_selectedModel);
                      },
                    ),
                  );
                },
              ),
            ),
        ],
        bottom:
            _isLoading
                ? null
                : PreferredSize(
                  preferredSize: const Size.fromHeight(96.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: DSInput.search(
                          hint: '搜索模型...',
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs:
                            _modelGroups
                                .map(
                                  (group) => Tab(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (ProviderLogo.hasLogo(group.id)) ...[
                                          ProviderLogo(id: group.id, size: 15),
                                          const SizedBox(width: 5),
                                        ],
                                        Text(group.name),
                                      ],
                                    ),
                                  ),
                                )
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
                    : TabBarView(
                      controller: _tabController,
                      children:
                          _modelGroups.map((group) {
                            final filteredModels = _getFilteredModels(
                              group.models,
                            );
                            return filteredModels.isEmpty
                                ? Center(child: Text('openai_noModelsFound'.tr))
                                : Builder(
                                  builder: (context) {
                                    final theme = DSThemeBridge.resolve(
                                      context,
                                    );
                                    return ListView.builder(
                                      itemCount: filteredModels.length,
                                      itemBuilder: (context, index) {
                                        final model = filteredModels[index];
                                        final isSelected =
                                            _selectedModel?.id == model.id;

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 4,
                                          ),
                                          child: GestureDetector(
                                            onLongPress: () {
                                              // 显示模型详情
                                              showDSDialog(
                                                context: context,
                                                theme: DSThemeBridge.resolve(
                                                  context,
                                                ),
                                                builder:
                                                    (
                                                      dialogContext,
                                                    ) => DSThemeBridge(
                                                      child: Builder(
                                                        builder:
                                                            (
                                                              dialogContext,
                                                            ) => DSDialog(
                                                              title: model.name,
                                                              message:
                                                                  '分组: ${model.group}',
                                                              confirmText:
                                                                  'openai_close'
                                                                      .tr,
                                                              onConfirm:
                                                                  () =>
                                                                      Navigator.of(
                                                                        dialogContext,
                                                                      ).pop(),
                                                            ),
                                                      ),
                                                    ),
                                              );
                                            },
                                            child: DSCard(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: theme.spacing.md,
                                                vertical: theme.spacing.sm,
                                              ),
                                              onTap: () {
                                                setState(() {
                                                  _selectedModel = model;
                                                });
                                              },
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          model.name,
                                                          style: DsTypography
                                                              .body
                                                              .copyWith(
                                                                color:
                                                                    theme.text,
                                                              ),
                                                        ),
                                                        Text(
                                                          model.group,
                                                          style: DsTypography
                                                              .caption
                                                              .copyWith(
                                                                color:
                                                                    theme
                                                                        .textSub,
                                                              ),
                                                        ),
                                                      ],
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
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                          }).toList(),
                    ),
      ),
      floatingActionButton:
          _selectedModel != null
              ? DSThemeBridge(
                child: Builder(
                  builder: (context) {
                    return DSFab(
                      icon: DsIconKind.check,
                      onPressed: () {
                        Navigator.of(context).pop(_selectedModel);
                      },
                    );
                  },
                ),
              )
              : null,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
