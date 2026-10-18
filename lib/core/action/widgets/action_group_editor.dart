/// 动作组编辑器
/// 用于创建和编辑动作组
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/action/models/action_instance.dart';
import 'package:aboutme/core/action/models/action_group.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'action_selector_dialog.dart';
import 'package:get/get.dart';

/// 动作组编辑器（手绘风）
class ActionGroupEditor extends StatefulWidget {
  final ActionGroup? group;

  const ActionGroupEditor({
    super.key,
    this.group,
  });

  /// 统一弹窗入口：走 showDSDialog 获得手绘入场与遮罩
  static Future<ActionGroup?> show(BuildContext context, {ActionGroup? group}) {
    return showDSDialog<ActionGroup>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => ActionGroupEditor(group: group),
    );
  }

  @override
  State<ActionGroupEditor> createState() => _ActionGroupEditorState();
}

class _ActionGroupEditorState extends State<ActionGroupEditor> {
  // 标题和描述控制器
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // 优先级输入
  late final TextEditingController _priorityController;

  // 操作符
  GroupOperator _operator = GroupOperator.sequence;

  // 执行模式
  GroupExecutionMode _executionMode = GroupExecutionMode.all;

  // 动作列表
  final List<ActionInstance> _actions = [];

  // 优先级
  int _priority = 0;

  @override
  void initState() {
    super.initState();

    if (widget.group != null) {
      final group = widget.group!;
      _titleController.text = group.title;
      _descriptionController.text = group.description ?? '';
      _operator = group.operator;
      _executionMode = group.executionMode;
      _actions.addAll(group.actions);
      _priority = group.priority;
    }
    _priorityController = TextEditingController(text: _priority.toString());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  void _onAddAction() async {
    final result = await ActionSelectorDialog.show(
      context,
      showGroupEditor: false,
    );

    if (result != null && result.singleAction != null) {
      setState(() {
        _actions.add(result.singleAction!);
      });
    }
  }

  void _onEditAction(int index) async {
    final action = _actions[index];
    final result = await ActionSelectorDialog.show(
      context,
      showGroupEditor: false,
      initialValue: ActionSelectorResult(
        singleAction: action,
      ),
    );

    if (result != null && result.singleAction != null) {
      setState(() {
        _actions[index] = result.singleAction!;
      });
    }
  }

  void _onRemoveAction(int index) {
    setState(() {
      _actions.removeAt(index);
    });
  }

  void _onMoveUp(int index) {
    if (index > 0) {
      setState(() {
        final temp = _actions[index - 1];
        _actions[index - 1] = _actions[index];
        _actions[index] = temp;
      });
    }
  }

  void _onMoveDown(int index) {
    if (index < _actions.length - 1) {
      setState(() {
        final temp = _actions[index + 1];
        _actions[index + 1] = _actions[index];
        _actions[index] = temp;
      });
    }
  }

  Future<void> _onSave() async {
    if (_titleController.text.trim().isEmpty) {
      Toast.show('core_pleaseEnterGroupTitle'.tr);
      return;
    }

    if (_actions.isEmpty) {
      Toast.show('core_pleaseAddAtLeastOneAction'.tr);
      return;
    }

    final groupId = widget.group?.id ?? 'group_${DateTime.now().millisecondsSinceEpoch}';

    final group = ActionGroup(
      id: groupId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      operator: _operator,
      executionMode: _executionMode,
      actions: List.from(_actions),
      priority: _priority,
    );

    Navigator.pop(context, group);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 440,
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
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

            SizedBox(height: theme.spacing.sm),

            // 表单内容
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 基本信息
                    _buildSectionTitle(theme, 'core_basicInfo'.tr),
                    SizedBox(height: theme.spacing.sm),
                    DSInput(
                      controller: _titleController,
                      label: 'core_groupTitle'.tr,
                      hint: 'core_enterActionGroupTitle'.tr,
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSInput(
                      controller: _descriptionController,
                      label: 'core_groupDescription'.tr,
                      hint: 'core_enterActionGroupDescription'.tr,
                      maxLines: 3,
                    ),

                    SizedBox(height: theme.spacing.xl),

                    // 执行配置
                    _buildSectionTitle(theme, 'core_executionConfig'.tr),
                    SizedBox(height: theme.spacing.sm),
                    _buildLabel(theme, 'core_operator'.tr),
                    const SizedBox(height: 4),
                    DSSelect<GroupOperator>(
                      value: _operator,
                      hint: 'core_selectExecutionMethod'.tr,
                      items: [
                        DSSelectItem(
                          value: GroupOperator.sequence,
                          label: 'core_sequentialExecution'.tr,
                        ),
                        DSSelectItem(
                          value: GroupOperator.parallel,
                          label: 'core_parallelExecution'.tr,
                        ),
                        DSSelectItem(
                          value: GroupOperator.condition,
                          label: 'core_conditionalExecution'.tr,
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _operator = value),
                    ),
                    SizedBox(height: theme.spacing.md),
                    _buildLabel(theme, 'core_executionMode'.tr),
                    const SizedBox(height: 4),
                    DSSelect<GroupExecutionMode>(
                      value: _executionMode,
                      hint: 'core_selectExecutionMode'.tr,
                      items: [
                        DSSelectItem(
                          value: GroupExecutionMode.all,
                          label: 'core_executeAllActions'.tr,
                        ),
                        DSSelectItem(
                          value: GroupExecutionMode.any,
                          label: 'core_executeAnyAction'.tr,
                        ),
                        DSSelectItem(
                          value: GroupExecutionMode.first,
                          label: 'core_executeFirstOnly'.tr,
                        ),
                        DSSelectItem(
                          value: GroupExecutionMode.last,
                          label: 'core_executeLastOnly'.tr,
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _executionMode = value),
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSInput(
                      controller: _priorityController,
                      label: 'core_priority'.tr,
                      hint: 'core_priorityDescription'.tr,
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          _priority = int.tryParse(value) ?? 0,
                    ),

                    SizedBox(height: theme.spacing.xl),

                    // 动作列表
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildSectionTitle(
                            theme,
                            'core_actionList'.tr,
                          ),
                        ),
                        DSButton(
                          label: 'core_addAction'.tr,
                          variant: DSButtonVariant.secondary,
                          size: DSButtonSize.sm,
                          icon: DsIconKind.plus,
                          onPressed: _onAddAction,
                        ),
                      ],
                    ),
                    SizedBox(height: theme.spacing.md),
                    _buildActionList(theme),
                  ],
                ),
              ),
            ),

            SizedBox(height: theme.spacing.md),

            // 底部按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DSButton(
                  label: 'core_cancel'.tr,
                  variant: DSButtonVariant.ghost,
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: theme.spacing.sm),
                DSButton(
                  label: 'core_save'.tr,
                  icon: DsIconKind.check,
                  onPressed: _onSave,
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
        DsIcon(DsIconKind.folder, color: theme.primary),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            widget.group != null
                ? 'core_editActionGroup'.tr
                : 'core_createActionGroupTitle'.tr,
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

  Widget _buildSectionTitle(AppThemeData theme, String text) {
    return Text(
      text,
      style: DsTypography.heading.copyWith(color: theme.text),
    );
  }

  Widget _buildLabel(AppThemeData theme, String text) {
    return Text(
      text,
      style: DsTypography.caption.copyWith(color: theme.textSub),
    );
  }

  Widget _buildActionList(AppThemeData theme) {
    if (_actions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(theme.spacing.lg),
        decoration: dsSketchDecoration(theme: theme, radius: theme.radii.lg),
        child: Center(
          child: Text(
            'core_noActionsAdded'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < _actions.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildActionItem(theme, index),
          ),
      ],
    );
  }

  Widget _buildActionItem(AppThemeData theme, int index) {
    final action = _actions[index];

    return DSListItemCard(
      title: action.displayTitle,
      subtitle: action.displayDescription ?? action.actionId,
      leading: Icon(action.displayIcon ?? Icons.code),
      iconColor: theme.primary,
      trailing: _buildItemMenu(theme, index),
      onTap: () => _onEditAction(index),
    );
  }

  /// 条目操作菜单（编辑/上移/下移/删除）
  Widget _buildItemMenu(AppThemeData theme, int index) {
    return DSPopover(
      width: 150,
      contentBuilder: (popoverContext, close) {
        final popoverTheme = DSThemeBridge.resolve(popoverContext);

        Widget menuRow(String label, DsIconKind icon, VoidCallback onTap,
            {Color? color}) {
          return Pressable(
            onPressed: () {
              close();
              onTap();
            },
            builder: (context, states) {
              final pressed = states.contains(WidgetState.pressed);
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: popoverTheme.spacing.md,
                  vertical: popoverTheme.spacing.sm,
                ),
                color: pressed
                    ? popoverTheme.surfaceAlt.withValues(alpha: 0.7)
                    : null,
                child: Row(
                  children: [
                    DsIcon(
                      icon,
                      size: 18,
                      color: color ?? popoverTheme.text,
                    ),
                    SizedBox(width: popoverTheme.spacing.sm),
                    Text(
                      label,
                      style: DsTypography.body.copyWith(
                        color: color ?? popoverTheme.text,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            menuRow('core_edit'.tr, DsIconKind.edit, () => _onEditAction(index)),
            if (index > 0)
              menuRow(
                'core_moveUp'.tr,
                DsIconKind.chevronUp,
                () => _onMoveUp(index),
              ),
            if (index < _actions.length - 1)
              menuRow(
                'core_moveDown'.tr,
                DsIconKind.chevronDown,
                () => _onMoveDown(index),
              ),
            menuRow(
              'core_delete'.tr,
              DsIconKind.trash,
              () => _onRemoveAction(index),
              color: popoverTheme.danger,
            ),
          ],
        );
      },
      child: DSIconButton(
        icon: DsIconKind.more,
        size: 34,
        color: theme.surfaceAlt,
        iconColor: theme.textSub,
      ),
    );
  }
}
