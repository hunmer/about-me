import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/services/file_service.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:get/get.dart';
import 'message_input_types.dart';
import 'message_input_state.dart';
import 'package:aboutme/plugins/openai/widgets/agent_list_drawer.dart';
import 'widgets/metadata_display.dart';
import 'package:aboutme/widgets/message_input/message_input.dart' as common;
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/message_input_actions_drawer.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/message_input_actions_builder.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/handlers/emoji_handler.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/handlers/image_handler.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/handlers/local_video_handler.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/tencent_asr_service.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/voice_recognition_helper.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final OnSendMessage onSendMessage;
  final Function(String) onSaveDraft;
  final Message? replyTo;
  final FocusNode? focusNode;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSendMessage,
    required this.onSaveDraft,
    this.replyTo,
    this.focusNode,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  late FocusNode _focusNode;

  /// MessageInputState 构造占位用（键盘监听已移入公共组件）
  final FocusNode _stateKeyboardListenerFocusNode = FocusNode();
  List<Map<String, String>> selectedAgents = [];
  bool showAgentList = false;

  /// 待发送文件列表（多选图片/视频等逐个追加）
  final List<Map<String, dynamic>> selectedFiles = [];
  int contextRange = 10; // 默认上下文范围为10

  late MessageInputState _messageInputState;

  // 语音识别服务
  TencentASRService? _recognitionService;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();

    // 加载频道的元数据
    _loadChannelMetadata();

    _updateMessageInputState();

    widget.controller.addListener(_onTextChanged);

    // 初始化语音识别服务
    _initializeVoiceRecognition();
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

  // 加载频道元数据
  void _loadChannelMetadata() {
    if (ChatPlugin.instance.channelService.currentChannel != null) {
      final currentChannel = ChatPlugin.instance.channelService.currentChannel!;
      final metadata = currentChannel.metadata;

      if (metadata != null) {
        // 加载保存的智能体列表
        final savedAgents = metadata['selectedAgents'] as List<dynamic>?;
        if (savedAgents != null) {
          selectedAgents = savedAgents
              .map((agent) => Map<String, String>.from(agent))
              .toList();
        }

        // 加载保存的上下文范围
        final savedContextRange = metadata['contextRange'] as int?;
        if (savedContextRange != null) {
          contextRange = savedContextRange;
        }
      }
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _stateKeyboardListenerFocusNode.dispose();
    widget.controller.removeListener(_onTextChanged);
    _recognitionService?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.onSaveDraft(widget.controller.text);
    if (widget.controller.text.endsWith('@')) {
      setState(() {
        showAgentList = true;
      });
      _showAgentListDrawer();
    }
  }

  void _showAgentListDrawer() {
    SmoothBottomSheet.show(
      context: context,
      builder: (context) => AgentListDrawer(
        selectedAgents: selectedAgents,
        onAgentSelected: _handleAgentSelected,
        textController: widget.controller,
      ),
    );
  }

  void _handleAgentSelected(List<Map<String, String>> agents) {
    setState(() {
      selectedAgents = agents;
      showAgentList = false;
      _updateMessageInputState();
    });

    // 保存选择的智能体到频道元数据
    if (ChatPlugin.instance.channelService.currentChannel != null) {
      final channelId = ChatPlugin.instance.channelService.currentChannel!.id;
      ChatPlugin.instance.channelService.updateChannelMetadata(channelId, {
        'selectedAgents': agents,
      });
    }
  }

  void _handleContextRangeChange(int newRange) {
    setState(() {
      contextRange = newRange;
      _updateMessageInputState();
    });

    // 保存上下文范围到频道元数据
    if (ChatPlugin.instance.channelService.currentChannel != null) {
      final channelId = ChatPlugin.instance.channelService.currentChannel!.id;
      ChatPlugin.instance.channelService.updateChannelMetadata(channelId, {
        'contextRange': newRange,
      });
    }
  }

  void _handleFileSelected(Map<String, dynamic> file) {
    setState(() {
      selectedFiles.add(file);
      _updateMessageInputState();
    });
  }

  void _updateMessageInputState() {
    _messageInputState = MessageInputState(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardListenerFocusNode: _stateKeyboardListenerFocusNode,
      selectedAgents: selectedAgents,
      selectedFiles: selectedFiles,
      showAgentList: showAgentList,
      replyTo: widget.replyTo,
      metadata: {
        if (selectedAgents.isNotEmpty) 'contextCount': contextRange,
        if (selectedAgents.isNotEmpty) 'agents': selectedAgents,
      },
      onSaveDraft: widget.onSaveDraft,
      onSendMessage: widget.onSendMessage,
      onClearFile: _removeAllFiles,
    );
  }

  void _removeAgent(String agentId) {
    setState(() {
      selectedAgents.removeWhere((agent) => agent['id'] == agentId);
      _updateMessageInputState();
    });

    // 更新频道元数据中的智能体列表
    if (ChatPlugin.instance.channelService.currentChannel != null) {
      final channelId = ChatPlugin.instance.channelService.currentChannel!.id;

      // 如果移除后没有选中的智能体，则清空元数据中的智能体列表和上下文范围
      if (selectedAgents.isEmpty) {
        ChatPlugin.instance.channelService.updateChannelMetadata(channelId, {
          'selectedAgents': [],
          'contextRange': null,
        });
      } else {
        // 否则只更新智能体列表
        ChatPlugin.instance.channelService.updateChannelMetadata(channelId, {
          'selectedAgents': selectedAgents,
        });
      }
    }
  }

  /// 移除指定下标的待发送文件
  void _removeFileAt(int index) {
    setState(() {
      if (index >= 0 && index < selectedFiles.length) {
        selectedFiles.removeAt(index);
      }
      _updateMessageInputState();
    });
  }

  void _removeAllFiles() {
    setState(() {
      selectedFiles.clear();
      _updateMessageInputState();
    });
  }

  void _handleSendMessage() {
    // 使用最新的状态创建一个新的 MessageInputState 实例
    _updateMessageInputState();
    _messageInputState.sendMessage();

    // 发送后更新UI状态
    if (selectedFiles.isNotEmpty) {
      setState(() {
        selectedFiles.clear();
        _updateMessageInputState();
      });
    }
  }

  /// 显示语音输入对话框
  Future<void> _showVoiceInputDialog() async {
    if (!mounted) return;

    await VoiceRecognitionHelper.showVoiceInputDialog(
      context: context,
      onComplete: (text) {
        // 将识别的文本填充到输入框
        widget.controller.text = text;
        widget.onSaveDraft(text);

        // 聚焦到输入框
        _focusNode.requestFocus();
      },
    );
  }

  /// 打开表情选择器
  void _showEmojiPicker() {
    handleEmojiSelection(
      context: context,
      fileService: FileService(),
      onFileSelected: _handleFileSelected,
      textController: widget.controller,
    );
  }

  /// 顶部图标工具栏快捷动作：常用上传固定在此（底部抽屉动作的快捷方式）
  List<common.MessageInputQuickAction> _buildQuickActions() {
    final fileService = FileService();
    return [
      common.MessageInputQuickAction(
        icon: DsIconKind.image,
        tooltip: 'chat_photo'.tr,
        onPressed: () => handleImageSelection(
          context: context,
          fileService: fileService,
          onFileSelected: _handleFileSelected,
          fromCamera: false,
        ),
        onLongPress: () => handleImageSelection(
          context: context,
          fileService: fileService,
          onFileSelected: _handleFileSelected,
          fromCamera: false,
          multiple: true,
        ),
      ),
      common.MessageInputQuickAction(
        icon: DsIconKind.video,
        tooltip: 'chat_video'.tr,
        onPressed: () => handleLocalVideoSelection(
          context: context,
          fileService: fileService,
          onFileSelected: _handleFileSelected,
        ),
        onLongPress: () => handleLocalVideoSelection(
          context: context,
          fileService: fileService,
          onFileSelected: _handleFileSelected,
          multiple: true,
        ),
      ),
    ];
  }

  /// "+"按钮：打开完整的底部抽屉动作列表
  void _showActionsDrawer() {
    SmoothBottomSheet.show(
      context: context,
      builder: (context) => MessageInputActionsDrawer(
        actions: MessageInputActionsBuilder.getDefaultActions(
          context,
          onFileSelected: _handleFileSelected,
          onSendMessage: widget.onSendMessage,
          textController: widget.controller,
        ),
        onFileSelected: _handleFileSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return common.MessageInput(
      controller: widget.controller,
      focusNode: _focusNode,
      hintText: 'chat_enterMessage'.tr,
      onChanged: (text) => widget.onSaveDraft(text),
      quickActions: _buildQuickActions(),
      onOpenActionsDrawer: _showActionsDrawer,
      header: MetadataDisplay(
        selectedFiles: selectedFiles,
        selectedAgents: selectedAgents,
        onShowAgentListDrawer: _showAgentListDrawer,
        onFileRemoveAt: _removeFileAt,
        onAgentRemove: _removeAgent,
        contextRange: contextRange,
        onContextRangeChange: _handleContextRangeChange,
      ),
      inputSuffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InlineIconAction(
            icon: DsIconKind.mood,
            color: theme.textSub,
            onPressed: _showEmojiPicker,
            tooltip: '表情',
          ),
          if (_recognitionService != null)
            _InlineIconAction(
              icon: DsIconKind.mic,
              color: theme.textSub,
              onPressed: _showVoiceInputDialog,
              tooltip: '语音输入',
            )
          else
            _InlineIconAction(
              icon: DsIconKind.mic,
              color: theme.textSub,
              tooltip: '语音输入（未配置）',
            ),
        ],
      ),
      onSend: _handleSendMessage,
      onKeyEvent: (event) => _messageInputState.handleKeyPress(event),
    );
  }
}

/// 输入框内嵌的无边框小图标按钮（表情/语音）
class _InlineIconAction extends StatelessWidget {
  const _InlineIconAction({
    required this.icon,
    required this.color,
    this.onPressed,
    this.tooltip,
  });

  final DsIconKind icon;
  final Color color;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Pressable(
      onPressed: onPressed,
      semanticLabel: tooltip,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed && !disabled ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: DsIcon(
              icon,
              size: 18,
              color: disabled ? color.withValues(alpha: 0.4) : color,
            ),
          ),
        );
      },
    );
  }
}
