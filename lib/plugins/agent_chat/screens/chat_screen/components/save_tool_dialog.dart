import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/saved_tool_template.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 保存/编辑工具对话框
///
/// 用于输入工具模板名称和描述，支持创建和编辑两种模式
class SaveToolDialog extends StatefulWidget {
  final ChatMessage? message;
  final ToolTemplateService templateService;
  final List<Map<String, String>> declaredTools;
  final SavedToolTemplate? editingTemplate;

  const SaveToolDialog({
    super.key,
    this.message,
    required this.templateService,
    this.declaredTools = const [],
    this.editingTemplate,
  });

  /// 是否为编辑模式
  bool get isEditMode => editingTemplate != null;

  @override
  State<SaveToolDialog> createState() => _SaveToolDialogState();
}

class _SaveToolDialogState extends State<SaveToolDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _isSaving = false;
  String? _errorMessage;
  String? _nameError;
  final List<String> _tags = [];
  final List<ToolCallStep> _steps = [];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });

    // 如果是编辑模式，回显数据
    if (widget.isEditMode) {
      final template = widget.editingTemplate!;
      _nameController.text = template.name;
      _descriptionController.text = template.description ?? '';
      _tags.addAll(template.tags);
      // 深拷贝步骤
      _steps.addAll(
        template.steps.map(
          (s) => ToolCallStep(
            method: s.method,
            title: s.title,
            desc: s.desc,
            data: s.data,
          ),
        ),
      );
    } else if (widget.message?.toolCall?.steps != null) {
      // 创建模式：从消息中获取步骤
      _steps.addAll(
        widget.message!.toolCall!.steps.map(
          (s) => ToolCallStep(
            method: s.method,
            title: s.title,
            desc: s.desc,
            data: s.data,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return JellyBox(
      radius: theme.radii.xxl,
      width: 560,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题 + DSTabs（design_system/components/tabs.dart）
          Row(
            children: [
              DsIcon(
                widget.isEditMode ? DsIconKind.edit : DsIconKind.download,
                color: theme.primaryText,
              ),
              const SizedBox(width: 8),
              Text(
                widget.isEditMode
                    ? 'agent_chat_editToolTemplate'.tr
                    : 'agent_chat_saveTool'.tr,
                style: DsTypography.title.copyWith(color: theme.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // DSTabs 挂内容页后支持左右滑动切换（design_system/components/tabs.dart）
          DSTabs(
            labels: [
              'agent_chat_basicInfo'.tr,
              'agent_chat_executionSteps'.tr,
            ],
            selected: _selectedTab,
            onChanged: (index) => setState(() => _selectedTab = index),
            contentHeight: 500,
            children: [_buildBasicInfoTab(), _buildStepsTab()],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DSButton(
                  label: 'agent_chat_cancel'.tr,
                  variant: DSButtonVariant.outline,
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DSButton(
                  label: 'agent_chat_save'.tr,
                  onPressed: _isSaving ? null : _saveTool,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建基础信息 Tab
  Widget _buildBasicInfoTab() {
    final theme = DSThemeBridge.resolve(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名称输入（手绘输入框，design.md §9.1）
          DSInput(
            controller: _nameController,
            focusNode: _nameFocus,
            label: 'agent_chat_toolNameLabel'.tr,
            hint: 'agent_chat_toolNameHint'.tr,
            errorText: _nameError,
            maxLength: 50,
            prefix: DsIcon(DsIconKind.tag, size: 20, color: theme.textSub),
            onChanged: (_) {
              if (_nameError != null) {
                setState(() {
                  _nameError = null;
                });
              }
            },
          ),

          const SizedBox(height: 16),

          // 描述输入
          DSInput(
            controller: _descriptionController,
            label: 'agent_chat_descriptionOptional'.tr,
            hint: 'agent_chat_descriptionHint'.tr,
            maxLength: 200,
            maxLines: 3,
            prefix: DsIcon(DsIconKind.book, size: 20, color: theme.textSub),
          ),

          // 声明的工具(如果有)
          if (_getDeclaredTools().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'agent_chat_declaredToolsCount'.trParams({
                'count': '${_getDeclaredTools().length}',
              }),
              style: DsTypography.body.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.text,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _getDeclaredTools()
                        .where((tool) {
                          final name = tool['name'] ?? tool['id'] ?? '';
                          return name.trim().isNotEmpty;
                        })
                        .map((tool) {
                          return DSChip(
                            icon: DsIconKind.gear,
                            label: tool['name'] ?? tool['id'] ?? '',
                          );
                        })
                        .toList(),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 标签输入
          Text(
            'agent_chat_tagsOptional'.tr,
            style: DsTypography.body.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.text,
            ),
          ),
          const SizedBox(height: 8),
          DSInput(
            controller: _tagController,
            hint: 'agent_chat_tagInputHint'.tr,
            prefix: DsIcon(DsIconKind.tag, size: 20, color: theme.textSub),
            suffix: Pressable(
              onPressed: _addTag,
              semanticLabel: 'agent_chat_addTag'.tr,
              builder:
                  (context, states) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: DsIcon(
                      DsIconKind.plus,
                      size: 20,
                      color: theme.primaryText,
                    ),
                  ),
            ),
            onSubmitted: (_) => _addTag(),
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _tags.map((tag) {
                    return DSChip(
                      label: tag,
                      onDeleted: () {
                        setState(() {
                          _tags.remove(tag);
                        });
                      },
                    );
                  }).toList(),
            ),
          ],

          // 错误信息（危险态手绘容器，design.md §9.1）
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.danger.mixWhite(0.92),
                stroke: theme.danger.withValues(alpha: 0.5),
                radius: theme.radii.sm,
              ),
              child: Row(
                children: [
                  DsIcon(DsIconKind.close, size: 16, color: theme.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: DsTypography.caption.copyWith(color: theme.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建执行步骤 Tab
  Widget _buildStepsTab() {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      children: [
        // 步骤标题和添加按钮
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'agent_chat_stepCountLabel'.trParams({
                  'count': '${_steps.length}',
                }),
                style: DsTypography.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.text,
                ),
              ),
              Pressable(
                onPressed: _addStep,
                semanticLabel: 'agent_chat_addStep'.tr,
                builder:
                    (context, states) => DsIcon(
                      DsIconKind.plus,
                      size: 24,
                      color: theme.primaryText,
                    ),
              ),
            ],
          ),
        ),

        // 步骤列表
        Expanded(
          child:
              _steps.isEmpty
                  ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.surfaceAlt,
                      stroke: theme.textSub.withValues(alpha: 0.3),
                      radius: theme.radii.sm,
                    ),
                    child: Center(
                      child: Text(
                        'agent_chat_noStepsHint'.tr,
                        style: DsTypography.body.copyWith(color: theme.textSub),
                      ),
                    ),
                  )
                  : ReorderableListView.builder(
                    itemCount: _steps.length,
                    onReorder: _onReorderSteps,
                    itemBuilder: (context, index) {
                      return _buildStepEditor(index);
                    },
                  ),
        ),
      ],
    );
  }

  /// 获取声明的工具列表
  List<Map<String, String>> _getDeclaredTools() {
    if (widget.isEditMode) {
      return widget.editingTemplate!.declaredTools;
    }
    return widget.declaredTools;
  }

  /// 添加标签
  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  /// 添加步骤
  void _addStep() {
    setState(() {
      _steps.add(ToolCallStep(method: 'run_js', title: '', desc: '', data: ''));
    });
  }

  /// 删除步骤
  void _deleteStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  /// 重新排序步骤
  void _onReorderSteps(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final step = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, step);
    });
  }

  /// 更新步骤
  void _updateStep(int index, {String? title, String? desc, String? data}) {
    setState(() {
      _steps[index] = ToolCallStep(
        method: _steps[index].method,
        title: title ?? _steps[index].title,
        desc: desc ?? _steps[index].desc,
        data: data ?? _steps[index].data,
      );
    });
  }

  /// 构建步骤编辑器
  Widget _buildStepEditor(int index) {
    final step = _steps[index];
    final theme = DSThemeBridge.resolve(context);

    // ExpansionTile/ReorderableDragStartListener 结构性组件刻意保留 Material
    return Container(
      key: ValueKey(index),
      margin: const EdgeInsets.only(bottom: 8),
      // 手绘卡片容器（design.md §9.1）
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: theme.radii.md,
      ),
      child: ExpansionTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: DsIcon(DsIconKind.drag, color: theme.textSub),
        ),
        title: Text(
          step.title.isNotEmpty
              ? step.title
              : 'agent_chat_stepIndex'.trParams({'index': '${index + 1}'}),
          style: DsTypography.body.copyWith(color: theme.text),
        ),
        subtitle:
            step.desc.isNotEmpty
                ? Text(
                  step.desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                )
                : null,
        trailing: Pressable(
          onPressed: () => _deleteStep(index),
          semanticLabel: 'agent_chat_deleteStep'.tr,
          builder:
              (context, states) =>
                  DsIcon(DsIconKind.trash, size: 20, color: theme.danger),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题输入
                DSInput(
                  controller: TextEditingController(text: step.title),
                  label: 'agent_chat_stepTitle'.tr,
                  onChanged: (value) => _updateStep(index, title: value),
                ),
                const SizedBox(height: 12),

                // 描述输入
                DSInput(
                  controller: TextEditingController(text: step.desc),
                  label: 'agent_chat_stepDesc'.tr,
                  onChanged: (value) => _updateStep(index, desc: value),
                ),
                const SizedBox(height: 12),

                // 代码输入
                DSInput(
                  controller: TextEditingController(text: step.data),
                  label: 'agent_chat_stepCode'.tr,
                  hint: 'agent_chat_stepCodeHint'.tr,
                  maxLines: 8,
                  onChanged: (value) => _updateStep(index, data: value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 保存或更新工具
  Future<void> _saveTool() async {
    setState(() {
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    // 名称校验（编辑模式下允许保留原名称）
    if (name.isEmpty) {
      setState(() {
        _nameError = 'agent_chat_toolNameRequired'.tr;
      });
      return;
    }
    final keepOriginalName =
        widget.isEditMode && name == widget.editingTemplate!.name;
    if (!keepOriginalName &&
        widget.templateService.templates.any((t) => t.name == name)) {
      setState(() {
        _nameError = 'agent_chat_toolNameExists'.tr;
      });
      return;
    }

    // 步骤校验
    if (_steps.isEmpty) {
      setState(() {
        _errorMessage = 'agent_chat_needOneStep'.tr;
      });
      return;
    }
    for (var i = 0; i < _steps.length; i++) {
      if (_steps[i].data.trim().isEmpty) {
        setState(() {
          _errorMessage = 'agent_chat_stepCodeRequired'.trParams({
            'index': '${i + 1}',
          });
        });
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isEditMode) {
        // 编辑模式：更新现有模板
        final template = widget.editingTemplate!;
        final updatedTemplate = template.copyWith(
          name: name,
          description: description.isEmpty ? null : description,
          tags: _tags,
          steps: _steps,
        );

        await widget.templateService.updateTemplate(updatedTemplate);

        if (mounted) {
          Navigator.pop(context, true);
          toastService.showToast(
            'agent_chat_templateUpdated'.trParams({'name': name}),
          );
        }
      } else {
        // 创建模式：新建模板
        await widget.templateService.createTemplate(
          name: name,
          description: description.isEmpty ? null : description,
          steps: _steps,
          declaredTools: _getDeclaredTools(),
          tags: _tags,
        );

        if (mounted) {
          Navigator.pop(context, true);
          toastService.showToast(
            'agent_chat_toolSaved'.trParams({'name': name}),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
    }
  }
}

/// 显示保存工具对话框
Future<bool?> showSaveToolDialog(
  BuildContext context,
  ChatMessage message,
  ToolTemplateService templateService, {
  List<Map<String, String>> declaredTools = const [],
}) {
  return showDSDialog<bool>(
    context: context,
    theme: DSThemeBridge.resolve(context),
    builder:
        (context) => DSThemeBridge(
          child: Builder(
            builder:
                (context) => SaveToolDialog(
                  message: message,
                  templateService: templateService,
                  declaredTools: declaredTools,
                ),
          ),
        ),
  );
}

/// 显示编辑工具模板对话框
Future<bool?> showEditToolDialog(
  BuildContext context,
  SavedToolTemplate template,
  ToolTemplateService templateService,
) {
  return showDSDialog<bool>(
    context: context,
    theme: DSThemeBridge.resolve(context),
    builder:
        (context) => DSThemeBridge(
          child: Builder(
            builder:
                (context) => SaveToolDialog(
                  templateService: templateService,
                  editingTemplate: template,
                ),
          ),
        ),
  );
}
