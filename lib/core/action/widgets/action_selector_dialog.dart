/// 动作选择对话框
/// 用于选择和配置动作
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/action/action_manager.dart';
import 'package:aboutme/core/action/models/action_definition.dart';
import 'package:aboutme/core/action/models/action_instance.dart';
import 'package:aboutme/core/action/models/action_group.dart';
import 'package:aboutme/core/floating_ball/models/floating_ball_gesture.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'action_config_form.dart';
import 'action_group_editor.dart';
import 'package:get/get.dart';

/// 对话框结果
class ActionSelectorResult {
  final ActionInstance? singleAction;
  final ActionGroup? actionGroup;
  final ActionDefinition? selectedDefinition;
  final Map<String, dynamic>? formData;

  const ActionSelectorResult({
    this.singleAction,
    this.actionGroup,
    this.selectedDefinition,
    this.formData,
  });

  bool get isGroup => actionGroup != null;
  bool get isSingleAction => singleAction != null;
  bool get isEmpty => singleAction == null && actionGroup == null;
}

/// 动作选择器选项卡
enum ActionSelectorTab {
  single,    // 单动作
  group,     // 动作组
  custom,    // 自定义动作
}

/// 动作选择对话框（手绘风）
class ActionSelectorDialog extends StatefulWidget {
  final FloatingBallGesture? gesture;
  final ActionSelectorResult? initialValue;
  final bool showGroupEditor;

  const ActionSelectorDialog({
    super.key,
    this.gesture,
    this.initialValue,
    this.showGroupEditor = true,
  });

  /// 统一弹窗入口：走 showDSDialog 获得手绘入场与遮罩
  static Future<ActionSelectorResult?> show(
    BuildContext context, {
    FloatingBallGesture? gesture,
    ActionSelectorResult? initialValue,
    bool showGroupEditor = true,
  }) {
    return showDSDialog<ActionSelectorResult>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => ActionSelectorDialog(
        gesture: gesture,
        initialValue: initialValue,
        showGroupEditor: showGroupEditor,
      ),
    );
  }

  @override
  State<ActionSelectorDialog> createState() => _ActionSelectorDialogState();
}

class _ActionSelectorDialogState extends State<ActionSelectorDialog> {
  // 搜索控制器
  final TextEditingController _searchController = TextEditingController();

  // 当前选中的 Tab
  ActionSelectorTab _currentTab = ActionSelectorTab.single;

  // 搜索关键词
  String _searchQuery = '';

  // 动作定义列表
  List<ActionDefinition> _allActions = [];
  List<ActionDefinition> _filteredActions = [];

  // 动作组列表
  List<ActionGroup> _allGroups = [];
  List<ActionGroup> _filteredGroups = [];

  // 自定义动作实例列表
  List<ActionInstance> _allCustomActions = [];
  List<ActionInstance> _filteredCustomActions = [];

  // 选中的动作
  ActionDefinition? _selectedDefinition;
  ActionGroup? _selectedGroup;
  ActionInstance? _selectedCustomAction;

  // 表单数据
  Map<String, dynamic> _formData = {};

  // 初始表单数据（用于恢复已有配置）
  Map<String, dynamic>? _initialFormData;

  @override
  void initState() {
    super.initState();

    // 加载数据
    _loadActions();

    // 初始化搜索
    _filterActions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadActions() {
    final actionManager = ActionManager();

    setState(() {
      _allActions = actionManager.allActions;
      _allGroups = actionManager.actionGroups;
      _allCustomActions = actionManager.customActions;
    });

    // 如果有初始值，在动作加载完成后设置
    _setInitialFromWidget();
  }

  void _setInitialFromWidget() {
    final initial = widget.initialValue;
    if (initial == null) return;

    if (initial.singleAction != null) {
      // 根据 actionId 找到对应的 ActionDefinition
      try {
        final actionDef = _allActions.firstWhere(
          (action) => action.id == initial.singleAction!.actionId,
        );

        setState(() {
          _selectedDefinition = actionDef;
          _initialFormData = initial.singleAction?.data ?? {};
          _currentTab = ActionSelectorTab.single;
          // 恢复表单数据
          _formData = Map<String, dynamic>.from(_initialFormData ?? {});
        });
      } catch (e) {
        print('Warning: Action not found: ${initial.singleAction?.actionId}');
      }
    } else if (initial.actionGroup != null) {
      // 异步检查动作组是否存在
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final groupExists = _allGroups.any((g) => g.id == initial.actionGroup!.id);
        if (groupExists) {
          setState(() {
            _selectedGroup = initial.actionGroup;
            _currentTab = ActionSelectorTab.group;
          });
        } else {
          print('Warning: Action group not found: ${initial.actionGroup!.id}');
        }
      });
    }
  }

  void _filterActions() {
    final query = _searchQuery.toLowerCase();

    if (query.isEmpty) {
      _filteredActions = List.from(_allActions);
      _filteredGroups = List.from(_allGroups);
      _filteredCustomActions = List.from(_allCustomActions);
    } else {
      _filteredActions = _allActions
          .where((action) =>
              action.title.toLowerCase().contains(query) ||
              action.description?.toLowerCase().contains(query) == true)
          .toList();

      _filteredGroups = _allGroups
          .where((group) =>
              group.title.toLowerCase().contains(query) ||
              group.description?.toLowerCase().contains(query) == true)
          .toList();

      _filteredCustomActions = _allCustomActions
          .where((action) =>
              action.displayTitle.toLowerCase().contains(query) ||
              action.displayDescription?.toLowerCase().contains(query) == true)
          .toList();
    }

    setState(() {});
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterActions();
    });
  }

  void _onSelectDefinition(ActionDefinition definition) {
    setState(() {
      _selectedDefinition = definition;
      _selectedGroup = null;
      _selectedCustomAction = null;

      // 如果选择的不是初始动作，清空表单数据
      if (_initialFormData == null ||
          _initialFormData!.isEmpty ||
          _selectedDefinition?.id != definition.id) {
        _formData = {};
      }
    });
  }

  void _onSelectGroup(ActionGroup group) {
    setState(() {
      _selectedGroup = group;
      _selectedDefinition = null;
      _selectedCustomAction = null;
    });
  }

  void _onSelectCustomAction(ActionInstance action) {
    setState(() {
      _selectedCustomAction = action;
      _selectedDefinition = null;
      _selectedGroup = null;
    });
  }

  void _onFormDataChanged(Map<String, dynamic> data) {
    setState(() {
      _formData = data;
    });
  }

  Future<void> _onCreateGroup() async {
    final result = await ActionGroupEditor.show(context);

    if (result != null) {
      // 保存动作组到 ActionManager
      await ActionManager().saveActionGroup(result);

      setState(() {
        _allGroups.add(result);
        _selectedGroup = result;
      });

      _filterActions();
    }
  }

  void _onConfirm() {
    if (_currentTab == ActionSelectorTab.single) {
      if (_selectedDefinition != null) {
        Navigator.pop(
          context,
          ActionSelectorResult(
            singleAction: ActionInstance.create(
              actionId: _selectedDefinition!.id,
              data: _formData,
            ),
            selectedDefinition: _selectedDefinition,
            formData: _formData,
          ),
        );
      }
    } else if (_currentTab == ActionSelectorTab.group) {
      if (_selectedGroup != null) {
        Navigator.pop(
          context,
          ActionSelectorResult(
            actionGroup: _selectedGroup,
          ),
        );
      }
    } else if (_currentTab == ActionSelectorTab.custom) {
      if (_selectedCustomAction != null) {
        Navigator.pop(
          context,
          ActionSelectorResult(
            singleAction: _selectedCustomAction,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final hasInitialValue =
        widget.initialValue != null && !widget.initialValue!.isEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      // 大容器走手绘面板：纸底 + 淡排线 + 墨线框
      // （showDSDialog 外层已包 WiredDraw，这里消费描画进度做墨线入场）
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.xxl,
        padding: EdgeInsets.all(theme.spacing.lg),
        progress: WiredDrawTransition.progressOf(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildTitleRow(theme),

            SizedBox(height: theme.spacing.md),

            // 搜索框
            DSInput.search(
              controller: _searchController,
              hint: 'core_searchActions'.tr,
              onChanged: _onSearchChanged,
            ),

            SizedBox(height: theme.spacing.md),

            // Tab 栏
            DSTabs(
              labels: [
                'core_singleAction'.tr,
                'core_actionGroup'.tr,
                'core_customAction'.tr,
              ],
              selected: _currentTab.index,
              onChanged: (index) {
                setState(() {
                  _currentTab = ActionSelectorTab.values[index];
                  _filterActions();
                });
              },
            ),

            SizedBox(height: theme.spacing.md),

            // 内容区域
            Expanded(
              child: IndexedStack(
                index: _currentTab.index,
                children: [
                  _buildSingleActionTab(),
                  _buildGroupTab(),
                  _buildCustomTab(),
                ],
              ),
            ),

            SizedBox(height: theme.spacing.md),

            // 底部按钮
            Row(
              children: [
                // 左侧：清除按钮
                if (hasInitialValue)
                  DSButton(
                    label: 'core_clearSettings'.tr,
                    variant: DSButtonVariant.outline,
                    icon: DsIconKind.block,
                    onPressed: () {
                      Navigator.pop(
                        context,
                        const ActionSelectorResult(), // 返回空的结果
                      );
                    },
                  )
                else
                  const Spacer(),

                // 右侧：取消和确认按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DSButton(
                      label: 'app_cancel'.tr,
                      variant: DSButtonVariant.ghost,
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: theme.spacing.sm),
                    DSButton(
                      label: 'app_confirm'.tr,
                      onPressed: _onConfirm,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow(AppThemeData theme) {
    return Row(
      children: [
        DsIcon(DsIconKind.sparkle, color: theme.primary),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            'core_selectAction'.tr,
            style: DsTypography.title.copyWith(color: theme.text),
          ),
        ),
        DSIconButton(
          icon: DsIconKind.close,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  /// 空状态占位
  Widget _buildEmptyState(String emoji, String title) {
    return Center(
      child: DSEmptyState(emoji: emoji, title: title),
    );
  }

  /// 选中指示（单选圆点；卡片整体与圆点都可点击选中）
  Widget _buildSelectIndicator({
    required String? value,
    required String? groupValue,
    required VoidCallback onSelect,
  }) {
    return DSRadio<String?>(
      value: value,
      groupValue: groupValue,
      onChanged: (_) => onSelect(),
    );
  }

  Widget _buildSingleActionTab() {
    final theme = AppTheme.of(context);

    return Column(
      children: [
        // 动作列表
        Expanded(
          child: _filteredActions.isEmpty
              ? _buildEmptyState('⚡', 'core_noActionsFound'.tr)
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _filteredActions.length,
                  itemBuilder: (context, index) {
                    final action = _filteredActions[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DSListItemCard(
                        title: action.title,
                        subtitle:
                            action.description ?? 'core_noDescription'.tr,
                        leading: Icon(action.icon ?? Icons.help_outline),
                        iconColor: theme.primary,
                        trailing: _buildSelectIndicator(
                          value: action.id,
                          groupValue: _selectedDefinition?.id,
                          onSelect: () => _onSelectDefinition(action),
                        ),
                        onTap: () => _onSelectDefinition(action),
                      ),
                    );
                  },
                ),
        ),

        // 配置表单（选择了动作且需要额外配置时才展示）
        if (_selectedDefinition?.form?.fields.isNotEmpty == true) ...[
          SizedBox(height: theme.spacing.md),
          Container(
            height: 1,
            color: theme.textSub.withValues(alpha: 0.25),
          ),
          SizedBox(height: theme.spacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'core_actionConfig'.tr,
                    style:
                        DsTypography.heading.copyWith(color: theme.text),
                  ),
                  const SizedBox(height: 8),
                  ActionConfigForm(
                    actionDefinition: _selectedDefinition!,
                    initialData: _initialFormData,
                    onChanged: _onFormDataChanged,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGroupTab() {
    final theme = AppTheme.of(context);

    return Column(
      children: [
        // 动作组列表
        Expanded(
          child: _filteredGroups.isEmpty
              ? _buildEmptyState('🗂️', 'core_noActionGroups'.tr)
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _filteredGroups.length,
                  itemBuilder: (context, index) {
                    final group = _filteredGroups[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DSListItemCard(
                        title: group.title,
                        subtitle: 'core_actionsCount'.trParams({
                          'count': group.actionCount.toString(),
                        }),
                        leading:
                            Icon(group.displayIcon ?? Icons.folder_outlined),
                        iconColor: group.displayColor ?? theme.secondary,
                        trailing: _buildSelectIndicator(
                          value: group.id,
                          groupValue: _selectedGroup?.id,
                          onSelect: () => _onSelectGroup(group),
                        ),
                        onTap: () => _onSelectGroup(group),
                      ),
                    );
                  },
                ),
        ),

        // 创建组按钮
        if (widget.showGroupEditor) ...[
          SizedBox(height: theme.spacing.md),
          DSButton(
            label: 'core_createActionGroup'.tr,
            variant: DSButtonVariant.secondary,
            icon: DsIconKind.plus,
            expand: true,
            onPressed: _onCreateGroup,
          ),
        ],
      ],
    );
  }

  Widget _buildCustomTab() {
    final theme = AppTheme.of(context);

    return _filteredCustomActions.isEmpty
        ? _buildEmptyState('✨', 'core_noCustomActions'.tr)
        : ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _filteredCustomActions.length,
            itemBuilder: (context, index) {
              final action = _filteredCustomActions[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DSListItemCard(
                  title: action.displayTitle,
                  subtitle: action.displayDescription ?? action.actionId,
                  leading: Icon(action.displayIcon ?? Icons.star),
                  iconColor: theme.secondary,
                  trailing: _buildSelectIndicator(
                    value: action.id,
                    groupValue: _selectedCustomAction?.id,
                    onSelect: () => _onSelectCustomAction(action),
                  ),
                  onTap: () => _onSelectCustomAction(action),
                ),
              );
            },
          );
  }
}
