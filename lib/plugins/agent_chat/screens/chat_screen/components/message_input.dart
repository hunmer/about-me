import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_command.dart';
import 'package:aboutme/plugins/agent_chat/models/saved_tool_template.dart';
import 'package:aboutme/utils/file_picker_helper.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/tencent_asr_service.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/voice_recognition_helper.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';
import 'package:aboutme/plugins/openai/services/agentlib_resource_service.dart';
import 'package:agentlib/agent_slots.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'suggested_questions_dialog.dart';
import 'command_selector.dart';
import 'tool_template_selector.dart';
import 'package:aboutme/plugins/agent_chat/widgets/press_to_record_button.dart';
import '../../../../../../core/services/toast_service.dart';
import 'agent_chat_text_input.dart';

/// 消息输入框组件
class MessageInput extends StatefulWidget {
  final ChatController controller;

  /// 是否显示顶部快捷入口行（Agent 编辑 / Skills / MCP）；
  /// 关闭后输入框高度更紧凑（如 Live2D 悬浮输入条）
  final bool showQuickActions;

  const MessageInput({
    super.key,
    required this.controller,
    this.showQuickActions = true,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // 命令模式状态
  bool _isCommandMode = false;
  List<ChatCommand> _filteredCommands = [];

  // 工具模板搜索状态
  bool _isSearchingTools = false;
  List<SavedToolTemplate> _searchResults = [];
  bool _isLoadingToolResults = false;
  String? _toolSearchKeyword;
  List<SavedToolTemplate> _commandToolResults = [];
  bool _isLoadingCommandToolResults = false;
  String? _commandToolQuery;

  // 语音识别服务
  TencentASRService? _recognitionService;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.controller.inputText;
    _textController.addListener(_onTextChanged);
    widget.controller.addListener(_onControllerChanged);
    debugPrint('[ChatClear] initState controller=#${identityHashCode(widget.controller)}');
    _initializeVoiceRecognition();
  }

  @override
  void didUpdateWidget(covariant MessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      debugPrint(
        '[ChatClear] controller replaced: #${identityHashCode(oldWidget.controller)} -> #${identityHashCode(widget.controller)}',
      );
      // controller 实例变化时重新挂监听，否则清空通知会发到旧实例上
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _textController.text = widget.controller.inputText;
    }
  }

  @override
  void dispose() {
    debugPrint('[ChatClear] dispose controller=#${identityHashCode(widget.controller)}');
    _textController.removeListener(_onTextChanged);
    widget.controller.removeListener(_onControllerChanged);
    _textController.dispose();
    _focusNode.dispose();
    _recognitionService?.dispose();
    super.dispose();
  }

  /// 初始化语音识别服务
  Future<void> _initializeVoiceRecognition() async {
    if (!mounted) return;

    try {
      // 使用 VoiceRecognitionHelper 创建服务（不显示错误提示）
      final service = await VoiceRecognitionHelper.createServiceSilently(
        context,
      );

      if (service != null && mounted) {
        setState(() {
          _recognitionService = service;
        });
      }
    } catch (e) {
      debugPrint('初始化语音识别服务失败: $e');
    }
  }

  void _onTextChanged() {
    final text = _textController.text;
    widget.controller.setInputText(text);

    final bool isPotentialCommand =
        text.startsWith('/') && !text.contains('\n');
    final (commandType, argument) = isPotentialCommand
        ? ChatCommand.parseInput(text)
        : (null, null);

    // 检测命令模式
    setState(() {
      if (isPotentialCommand) {
        _isCommandMode = true;
        _filteredCommands = ChatCommand.filterCommands(text);
      } else {
        _isCommandMode = false;
        _filteredCommands = [];
      }
    });

    _handleCommandInputChange(
      isPotentialCommand ? commandType : null,
      argument,
    );
  }

  void _handleCommandInputChange(
    ChatCommandType? commandType,
    String? argument,
  ) {
    if (_isCommandMode && commandType == ChatCommandType.tools) {
      final keyword = argument?.trim() ?? '';
      if (keyword.isEmpty) {
        if (_commandToolResults.isNotEmpty ||
            _isLoadingCommandToolResults ||
            _commandToolQuery != null) {
          setState(() {
            _commandToolResults = [];
            _isLoadingCommandToolResults = false;
            _commandToolQuery = null;
          });
        }
        return;
      }

      _searchToolTemplatesForCommand(keyword);
      return;
    }

    if (_commandToolResults.isNotEmpty ||
        _isLoadingCommandToolResults ||
        _commandToolQuery != null) {
      setState(() {
        _commandToolResults = [];
        _isLoadingCommandToolResults = false;
        _commandToolQuery = null;
      });
    }
  }

  void _searchToolTemplatesForCommand(String keyword) {
    if (widget.controller.templateService == null) {
      return;
    }

    if (_commandToolQuery == keyword && _isLoadingCommandToolResults) {
      return;
    }

    setState(() {
      _isLoadingCommandToolResults = true;
      _commandToolResults = [];
      _commandToolQuery = keyword;
    });

    widget.controller
        .fetchToolTemplates(keyword: keyword)
        .then((results) {
          if (!mounted || _commandToolQuery != keyword) return;
          setState(() {
            _commandToolResults = results;
            _isLoadingCommandToolResults = false;
          });
        })
        .catchError((error) {
          if (!mounted || _commandToolQuery != keyword) return;
          setState(() {
            _commandToolResults = [];
            _isLoadingCommandToolResults = false;
          });
        });
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});

      // 同步输入框文本
      if (_textController.text != widget.controller.inputText) {
        debugPrint(
          '[ChatClear] sync text: field="${_textController.text}" -> model="${widget.controller.inputText}"',
        );
        _textController.text = widget.controller.inputText;
        _textController.selection = TextSelection.collapsed(
          offset: _textController.text.length,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: theme.radii.xl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 工具模板搜索结果
            if (_isSearchingTools) _buildToolTemplateSearchArea(),

            // 命令选择器
            if (_isCommandMode && _filteredCommands.isNotEmpty)
              CommandSelector(
                commands: _filteredCommands,
                onCommandSelected: _handleCommandSelected,
              ),

            if (!_isSearchingTools &&
                _isCommandMode &&
                (_commandToolQuery?.isNotEmpty ?? false))
              _buildToolCommandSearchResults(),

            // 当前状态显示区域（工具模板和文件）
            if (!_isSearchingTools &&
                (widget.controller.selectedToolTemplate != null ||
                    widget.controller.selectedFiles.isNotEmpty))
              _buildCurrentStatus(),

            // 快捷入口：Agent 编辑与 Skills 选择（紧凑模式下隐藏）
            if (widget.showQuickActions)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Pressable(
                      onPressed: widget.controller.currentAgent != null
                          ? _openAgentEdit
                          : null,
                      semanticLabel: '编辑Agent',
                      builder: (context, states) => DsIcon(
                        DsIconKind.bot,
                        size: 20,
                        color: widget.controller.currentAgent != null
                            ? theme.primaryText
                            : theme.textSub.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Pressable(
                      onPressed: () => _showResourceMenu(skills: true),
                      semanticLabel: '选择Skill',
                      builder: (context, states) => DsIcon(
                        DsIconKind.book,
                        size: 20,
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Pressable(
                      onPressed: () => _showResourceMenu(skills: false),
                      semanticLabel: '选择MCP',
                      builder: (context, states) => DsIcon(
                        DsIconKind.block,
                        size: 20,
                        color: theme.primaryText,
                      ),
                    ),
                  ],
                ),
              ),

            // 输入框区域
            Padding(
              padding: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 附件按钮
                    Pressable(
                      onPressed: _showAttachmentMenu,
                      semanticLabel: '添加附件',
                      builder: (context, states) => SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: DsIcon(
                            DsIconKind.copy,
                            size: 22,
                            color: theme.textSub,
                          ),
                        ),
                      ),
                    ),

                    // 输入框
                    Expanded(
                      child: AgentChatTextInput(
                        controller: _textController,
                        focusNode: _focusNode,
                        onSubmitted: (_) {
                          if (_canSendMessage()) {
                            _sendMessage();
                          }
                        },
                        enabled: widget.controller.currentAgent != null,
                        backgroundColor: Colors.transparent,
                        hintText: widget.controller.currentAgent != null
                            ? '输入消息...'
                            : '请先选择Agent...',
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Token统计
                              if (widget.controller.inputText.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    '~${widget.controller.inputTokenCount}',
                                    style: DsTypography.caption.copyWith(
                                      color: theme.textSub,
                                    ),
                                  ),
                                ),
                              // "你可以问"按钮
                              if (widget.controller.currentAgent != null)
                                Pressable(
                                  onPressed: _showSuggestedQuestions,
                                  semanticLabel: '你可以问',
                                  builder: (context, states) => Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: DsIcon(
                                      DsIconKind.star,
                                      size: 20,
                                      color: theme.warning,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 语音按钮（长按录音）
                    if (_recognitionService != null)
                      PressToRecordButton(
                        textController: _textController,
                        recognitionService: _recognitionService!,
                        enabled: widget.controller.currentAgent != null,
                        tooltip: '长按录音',
                        onRecognitionComplete: (text) {
                          // 聚焦到输入框
                          _focusNode.requestFocus();
                        },
                        onError: (error) {
                          if (mounted) {
                            toastService.showToast('语音识别失败: $error');
                          }
                        },
                      )
                    else
                      Pressable(
                        onPressed: widget.controller.currentAgent != null
                            ? _showVoiceInputDialog
                            : null,
                        semanticLabel: '语音输入（未配置）',
                        builder: (context, states) => SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: DsIcon(
                              DsIconKind.mic,
                              size: 22,
                              color: theme.textSub,
                            ),
                          ),
                        ),
                      ),

                    // 发送/取消按钮
                    DSIconButton(
                      icon: widget.controller.isSending
                          ? DsIconKind
                                .close // 显示取消图标
                          : DsIconKind.send,
                      size: 44,
                      color: widget.controller.isSending
                          ? theme
                                .danger // 发送中显示红色
                          : theme.primary,
                      onPressed: widget.controller.isSending
                          ? () => widget.controller
                                .cancelSending() // 取消发送
                          : (_canSendMessage() ? _sendMessage : null),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建当前状态显示
  Widget _buildCurrentStatus() {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: theme.textSub.withValues(alpha: 0.25)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 工具模板
          if (widget.controller.selectedToolTemplate != null) ...[
            Row(
              children: [
                DsIcon(DsIconKind.gear, size: 16, color: theme.warning),
                const SizedBox(width: 6),
                Text(
                  '使用工具模板',
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildToolTemplateChip(widget.controller.selectedToolTemplate!),
          ],

          // 分隔
          if (widget.controller.selectedToolTemplate != null &&
              widget.controller.selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: theme.textSub.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
          ],

          // 文件
          if (widget.controller.selectedFiles.isNotEmpty) ...[
            Row(
              children: [
                DsIcon(DsIconKind.copy, size: 16, color: theme.primaryText),
                const SizedBox(width: 6),
                Text(
                  '已选择 ${widget.controller.selectedFiles.length} 个文件',
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.controller.selectedFiles.asMap().entries.map((
                entry,
              ) {
                final index = entry.key;
                final file = entry.value;
                return _buildFileChip(file, index);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建工具模板芯片
  Widget _buildToolTemplateChip(SavedToolTemplate template) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.warning.mixWhite(0.9),
        borderRadius: theme.radii.sm,
        border: Border.all(color: theme.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(DsIconKind.gear, size: 18, color: theme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: DsTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${template.steps.length} 个步骤',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onPressed: () => widget.controller.clearSelectedToolTemplate(),
            semanticLabel: '移除工具模板',
            builder: (context, states) => Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: theme.warning.withValues(alpha: 0.6)),
              ),
              child: DsIcon(DsIconKind.close, size: 14, color: theme.warning),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建文件芯片
  Widget _buildFileChip(File file, int index) {
    final theme = DSThemeBridge.resolve(context);
    final isImage = FilePickerHelper.isImageFile(file);
    final fileName = FilePickerHelper.getFileName(file);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.radii.sm,
        border: Border.all(color: theme.textSub.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 文件扩展名图标映射（含配色）刻意保留 Material
          if (isImage)
            DsIcon(DsIconKind.image, size: 18, color: theme.primaryText)
          else
            Icon(
              FilePickerHelper.getFileIcon(file),
              size: 18,
              color: theme.primaryText,
            ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              fileName,
              style: DsTypography.caption.copyWith(color: theme.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Pressable(
            onPressed: () => widget.controller.removeFile(index),
            semanticLabel: '移除文件',
            builder: (context, states) =>
                DsIcon(DsIconKind.close, size: 16, color: theme.textSub),
          ),
        ],
      ),
    );
  }

  /// 显示附件菜单
  void _showAttachmentMenu() {
    SmoothBottomSheet.show(
      context: context,
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DSListItem(
                  leading: DsIcon(
                    DsIconKind.image,
                    size: 22,
                    color: DSThemeBridge.resolve(context).primaryText,
                  ),
                  title: 'agent_chat_image'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    widget.controller.pickImages();
                  },
                ),
                DSListItem(
                  leading: DsIcon(
                    DsIconKind.book,
                    size: 22,
                    color: DSThemeBridge.resolve(context).primaryText,
                  ),
                  title: 'agent_chat_document'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    widget.controller.pickDocuments();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 打开当前 Agent 编辑页
  void _openAgentEdit() {
    final AIAgent? agent = widget.controller.currentAgent;
    if (agent == null) return;
    NavigationHelper.push(context, AgentEditScreen(agent: agent));
  }

  /// 显示 Skills/MCP 选择菜单
  void _showResourceMenu({required bool skills}) {
    // 合并全局与当前 Agent 的同类资源，按 id 去重
    final resources = <String, AgentResourceItem>{};
    for (final item in [
      ...skills
          ? AgentLibResourceService.globalSlots.skills
          : AgentLibResourceService.globalSlots.mcpServers,
      ...?skills
          ? widget.controller.currentAgent?.resourceSlots.skills
          : widget.controller.currentAgent?.resourceSlots.mcpServers,
    ]) {
      resources[item.id] = item;
    }
    final items = resources.values.where((item) => item.enabled).toList();
    final label = skills ? 'Skill' : 'MCP';

    SmoothBottomSheet.show(
      context: context,
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SafeArea(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '暂无可用的 $label，可先在 Agent 编辑页添加',
                          style: DsTypography.body.copyWith(
                            color: DSThemeBridge.resolve(context).textSub,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return DSListItem(
                          leading: DsIcon(
                            skills ? DsIconKind.book : DsIconKind.block,
                            size: 22,
                            color: DSThemeBridge.resolve(context).primaryText,
                          ),
                          title: item.displayName,
                          subtitle: item.tags.isEmpty
                              ? null
                              : item.tags.join(' · '),
                          onTap: () {
                            Navigator.pop(context);
                            _insertResourceText(item, skills);
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// 在输入框插入 use [xxx] skill / mcp
  void _insertResourceText(AgentResourceItem item, bool skills) {
    final insert = 'use [${item.displayName}] ${skills ? 'skill' : 'mcp'}';
    final current = _textController.text;
    final newText = current.isEmpty ? insert : '$current\n$insert';
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(offset: newText.length);
    widget.controller.setInputText(newText);
    _focusNode.requestFocus();
  }

  /// 显示预设问题对话框
  Future<void> _showSuggestedQuestions() async {
    final plugin = AgentChatPlugin.instance;
    final selectedQuestion = await showSuggestedQuestionsDialog(
      context,
      plugin.storage,
    );

    if (selectedQuestion != null && mounted) {
      // 将选中的问题填充到输入框
      _textController.text = selectedQuestion;
      widget.controller.setInputText(selectedQuestion);

      // 聚焦到输入框
      _focusNode.requestFocus();
    }
  }

  /// 显示语音输入对话框
  Future<void> _showVoiceInputDialog() async {
    if (!mounted) return;

    await VoiceRecognitionHelper.showVoiceInputDialog(
      context: context,
      onComplete: (text) {
        // 将识别的文本填充到输入框
        _textController.text = text;
        widget.controller.setInputText(text);

        // 聚焦到输入框
        _focusNode.requestFocus();
      },
    );
  }

  /// 构建工具模板搜索区域
  Widget _buildToolTemplateSearchArea() {
    final theme = DSThemeBridge.resolve(context);
    if (_isLoadingToolResults) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border(
            top: BorderSide(color: theme.textSub.withValues(alpha: 0.3)),
            bottom: BorderSide(color: theme.textSub.withValues(alpha: 0.3)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            DSLoadingDots(size: 7),
            const SizedBox(width: 12),
            Text(
              'agent_chat_loadingToolTemplates'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && (_toolSearchKeyword?.isNotEmpty ?? false)) {
      return _buildToolSearchEmptyState();
    }

    return ToolTemplateSelector(
      templates: _searchResults,
      onTemplateSelected: _handleTemplateSelected,
      onCancel: () {
        setState(() {
          _isSearchingTools = false;
          _isLoadingToolResults = false;
          _searchResults = [];
          _toolSearchKeyword = null;
        });
      },
    );
  }

  Widget _buildToolCommandSearchResults() {
    final theme = DSThemeBridge.resolve(context);
    final keyword = _commandToolQuery ?? '';

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(
          top: BorderSide(color: theme.textSub.withValues(alpha: 0.3)),
          bottom: BorderSide(color: theme.textSub.withValues(alpha: 0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                DsIcon(DsIconKind.search, size: 18, color: theme.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '匹配的工具模板：$keyword',
                    style: DsTypography.caption.copyWith(
                      color: theme.textSub,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isLoadingCommandToolResults)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: DSLoadingDots(size: 5),
                  ),
              ],
            ),
          ),
          if (_isLoadingCommandToolResults)
            const SizedBox(height: 12)
          else if (_commandToolResults.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                '找不到 "$keyword"，按 Enter 继续搜索',
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _commandToolResults.length > 5
                  ? 5
                  : _commandToolResults.length,
              itemBuilder: (context, index) {
                final template = _commandToolResults[index];
                return _buildToolCommandResultItem(template);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildToolCommandResultItem(SavedToolTemplate template) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: () => _applyToolCommandTemplate(template),
      builder: (context, states) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            DsIcon(DsIconKind.gear, size: 20, color: theme.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: DsTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                    ),
                  ),
                  if (template.description != null &&
                      template.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      template.description!,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            DsIcon(DsIconKind.chevronRight, size: 16, color: theme.textSub),
          ],
        ),
      ),
    );
  }

  void _applyToolCommandTemplate(SavedToolTemplate template) {
    final newInput = '/tools ${template.name}';
    _textController.text = newInput;
    _textController.selection = TextSelection.collapsed(
      offset: newInput.length,
    );
    widget.controller.setInputText(newInput);

    setState(() {
      _commandToolResults = [];
      _isLoadingCommandToolResults = false;
      _commandToolQuery = template.name;
    });
  }

  Widget _buildToolSearchEmptyState() {
    final theme = DSThemeBridge.resolve(context);
    final keyword = _toolSearchKeyword ?? '';
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(
          top: BorderSide(color: theme.textSub.withValues(alpha: 0.3)),
          bottom: BorderSide(color: theme.textSub.withValues(alpha: 0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                DsIcon(DsIconKind.search, size: 20, color: theme.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '找不到 $keyword',
                    style: DsTypography.caption.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Pressable(
                  onPressed: () {
                    setState(() {
                      _isSearchingTools = false;
                      _isLoadingToolResults = false;
                      _searchResults = [];
                      _toolSearchKeyword = null;
                    });
                  },
                  semanticLabel: '取消',
                  builder: (context, states) => SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: DsIcon(
                        DsIconKind.close,
                        size: 20,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              '没有找到匹配的工具模板，请尝试其他关键词。',
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ),
        ],
      ),
    );
  }

  /// 处理命令选择
  void _handleCommandSelected(ChatCommand command) {
    switch (command.type) {
      case ChatCommandType.files:
        _executeFilesCommand();
        break;
      case ChatCommandType.tools:
        // 如果需要参数，填充命令模板
        if (command.requiresArgument) {
          _textController.text = '/${command.command} ';
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
          _focusNode.requestFocus();
        } else {
          _executeToolsCommand(null);
        }
        break;
    }
  }

  /// 执行 /files 命令
  void _executeFilesCommand() {
    // 清空输入框
    _textController.clear();
    widget.controller.setInputText('');

    // 显示附件菜单
    _showAttachmentMenu();
  }

  /// 执行 /tools 命令
  void _executeToolsCommand(String? searchQuery) {
    // 清空输入框
    _textController.clear();
    widget.controller.setInputText('');

    final keyword = searchQuery?.trim();
    final normalizedKeyword = (keyword == null || keyword.isEmpty)
        ? null
        : keyword;

    setState(() {
      _isSearchingTools = true;
      _isLoadingToolResults = true;
      _searchResults = [];
      _toolSearchKeyword = normalizedKeyword;
    });

    widget.controller
        .fetchToolTemplates(keyword: normalizedKeyword)
        .then((results) {
          if (!mounted) return;
          setState(() {
            _searchResults = results;
            _isLoadingToolResults = false;
          });
        })
        .catchError((error) {
          if (!mounted) return;
          setState(() {
            _isLoadingToolResults = false;
            _searchResults = [];
          });
          toastService.showToast('加载工具模板失败: $error');
        });
  }

  /// 处理模板选择
  void _handleTemplateSelected(SavedToolTemplate template) {
    // 选中模板
    widget.controller.setSelectedToolTemplate(template);

    // 关闭搜索
    setState(() {
      _isSearchingTools = false;
      _searchResults = [];
      _toolSearchKeyword = null;
    });

    // 聚焦输入框
    _focusNode.requestFocus();
  }

  /// 检查是否可以发送消息
  bool _canSendMessage() {
    // Agent 必须已选择
    if (widget.controller.currentAgent == null) return false;

    // 如果有选中的工具模板，即使输入框为空也可以发送
    if (widget.controller.selectedToolTemplate != null) return true;

    // 如果有选中的文件，即使输入框为空也可以发送
    if (widget.controller.selectedFiles.isNotEmpty) return true;

    // 否则，输入框不能为空
    return widget.controller.inputText.trim().isNotEmpty;
  }

  /// 发送消息
  Future<void> _sendMessage() async {
    // 先结束输入法组合状态（如拼音未上屏）：组合中的文本仍属于
    // inputText 会正常发出，但不提前清除 composing 标记的话，
    // 发送后清空输入框会被输入法把组合文本重新提交回来
    if (_textController.value.composing != TextRange.empty) {
      _textController.value = _textController.value.copyWith(
        composing: TextRange.empty,
      );
    }

    final text = widget.controller.inputText.trim();
    debugPrint(
      '[ChatClear] _sendMessage: field="${_textController.text}" model="${widget.controller.inputText}" controller=#${identityHashCode(widget.controller)}',
    );

    // 如果文本为空且没有工具模板和文件，则不能发送
    if (text.isEmpty &&
        widget.controller.selectedToolTemplate == null &&
        widget.controller.selectedFiles.isEmpty) {
      return;
    }

    // 检查是否是命令
    if (text.startsWith('/')) {
      final (commandType, argument) = ChatCommand.parseInput(text);

      if (commandType != null) {
        // 执行命令
        switch (commandType) {
          case ChatCommandType.files:
            _executeFilesCommand();
            return;
          case ChatCommandType.tools:
            _executeToolsCommand(argument);
            return;
        }
      } else {
        // 无效命令
        if (mounted) {
          toastService.showToast('无效的命令');
        }
        return;
      }
    }

    // 正常发送消息
    try {
      await widget.controller.sendMessage();
      _focusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        toastService.showToast('发送失败: $e');
      }
    }
  }
}
