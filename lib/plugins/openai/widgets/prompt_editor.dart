import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';

class PromptEditor extends StatefulWidget {
  final List<Prompt> prompts;
  final Function(List<Prompt>) onPromptsChanged;
  final bool separateSystemPrompt; // 是否分离 System Prompt 编辑
  final TextEditingController? systemPromptController; // System Prompt 控制器
  final VoidCallback? onAddMessage; // 添加消息回调

  const PromptEditor({
    super.key,
    required this.prompts,
    required this.onPromptsChanged,
    this.separateSystemPrompt = false,
    this.systemPromptController,
    this.onAddMessage,
  });

  @override
  State<PromptEditor> createState() => _PromptEditorState();
}

class _PromptEditorState extends State<PromptEditor> {
  late List<Prompt> _prompts;

  /// 与 [_prompts] 逐位对应的内容输入控制器（DSInput 无 initialValue）
  final List<TextEditingController> _contentControllers = [];

  @override
  void initState() {
    super.initState();
    _prompts = List.from(widget.prompts);
    _contentControllers.addAll(
      _prompts.map((p) => TextEditingController(text: p.content)),
    );
  }

  @override
  void dispose() {
    for (final controller in _contentControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addPrompt() {
    setState(() {
      _prompts.add(Prompt(type: 'user', content: ''));
      _contentControllers.add(TextEditingController());
      widget.onPromptsChanged(_prompts);
      // 通知外部添加了新消息
      widget.onAddMessage?.call();
    });
  }

  void _removePrompt(int index) {
    setState(() {
      _prompts.removeAt(index);
      _contentControllers.removeAt(index).dispose();
      widget.onPromptsChanged(_prompts);
    });
  }

  void _updatePromptType(int index, String type) {
    setState(() {
      _prompts[index] = Prompt(type: type, content: _prompts[index].content);
      widget.onPromptsChanged(_prompts);
    });
  }

  void _updatePromptContent(int index, String content) {
    setState(() {
      _prompts[index] = Prompt(type: _prompts[index].type, content: content);
      widget.onPromptsChanged(_prompts);
    });
  }

  /// 获取过滤后的消息列表（排除 system 类型）
  List<Prompt> get _filteredMessages {
    return _prompts.where((p) => p.type != 'system').toList();
  }

  /// 删除按钮（行内小型自绘按钮）
  Widget _buildDeleteButton(VoidCallback onPressed, AppThemeData theme) {
    return Pressable(
      onPressed: onPressed,
      semanticLabel: '删除消息',
      builder: (context, states) => Padding(
        padding: const EdgeInsets.all(8),
        child: DsIcon(DsIconKind.trash, size: 20, color: theme.danger),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 可能嵌在共享表单(Material)中,自带主题桥保证 DS 组件可用
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          // 如果是分离模式，使用新的布局
          if (widget.separateSystemPrompt) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // System Prompt 单独显示
                  DSInput(
                    controller: widget.systemPromptController,
                    label: 'openai_systemPrompt'.tr,
                    minLines: 4,
                    maxLines: 4,
                    onChanged: (value) {
                      // 找到或创建 system prompt
                      final systemIndex = _prompts.indexWhere(
                        (p) => p.type == 'system',
                      );
                      if (systemIndex >= 0) {
                        _updatePromptContent(systemIndex, value);
                      } else if (value.isNotEmpty) {
                        setState(() {
                          _prompts.insert(
                            0,
                            Prompt(type: 'system', content: value),
                          );
                          _contentControllers.insert(
                            0,
                            TextEditingController(text: value),
                          );
                          widget.onPromptsChanged(_prompts);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // 预设消息
                  Row(
                    children: [
                      const Spacer(),
                      DSButton(
                        label: '添加',
                        icon: DsIconKind.plus,
                        size: DSButtonSize.sm,
                        onPressed: widget.onAddMessage ?? _addPrompt,
                      ),
                    ],
                  ),
                  // 预设消息列表（自适应高度）
                  if (_filteredMessages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._filteredMessages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final originalIndex = _prompts.indexOf(
                        _filteredMessages[index],
                      );
                      final prompt = _filteredMessages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DSCard(
                          color: DsColors.transparent,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: DSSelect<String>(
                                      value: prompt.type,
                                      items: const [
                                        DSSelectItem(
                                          value: 'user',
                                          label: 'User',
                                        ),
                                        DSSelectItem(
                                          value: 'assistant',
                                          label: 'Assistant',
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          _updatePromptType(
                                            originalIndex,
                                            value,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildDeleteButton(
                                    () => _removePrompt(originalIndex),
                                    theme,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 80,
                                  maxHeight: 160,
                                ),
                                child: DSInput(
                                  controller:
                                      _contentControllers[originalIndex],
                                  maxLines: null,
                                  onChanged: (value) => _updatePromptContent(
                                    originalIndex,
                                    value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          }

          // 传统模式：所有提示混合显示
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._prompts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final prompt = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: DSCard(
                      color: DsColors.transparent,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DSSelect<String>(
                                  value: prompt.type,
                                  items: [
                                    DSSelectItem(
                                      value: 'system',
                                      label: 'openai_systemRole'.tr,
                                    ),
                                    DSSelectItem(
                                      value: 'user',
                                      label: 'openai_userRole'.tr,
                                    ),
                                    DSSelectItem(
                                      value: 'assistant',
                                      label: 'openai_assistantRole'.tr,
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      _updatePromptType(index, value);
                                    }
                                  },
                                ),
                              ),
                              if (_prompts.length > 1)
                                _buildDeleteButton(
                                  () => _removePrompt(index),
                                  theme,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 120,
                              maxHeight: 200,
                            ),
                            child: DSInput(
                              controller: _contentControllers[index],
                              label: 'openai_contentLabel'.tr,
                              maxLines: null,
                              onChanged: (value) =>
                                  _updatePromptContent(index, value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                DSButton(
                  label: 'openai_addPrompt'.tr,
                  icon: DsIconKind.plus,
                  variant: DSButtonVariant.outline,
                  onPressed: _addPrompt,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
