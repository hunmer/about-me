
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/services/file_service.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:get/get.dart';
import 'message_input_types.dart';
import 'message_input_state.dart';
import 'package:aboutme/plugins/openai/widgets/agent_list_drawer.dart';
import '../auto_reply_settings_sheet.dart';
import 'widgets/metadata_display.dart';
import 'package:aboutme/widgets/message_input/message_input.dart' as common;
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/message_input_actions_drawer.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/message_input_actions_builder.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/handlers/emoji_handler.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/tencent_asr_service.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/voice_recognition_helper.dart';
import 'package:aboutme/plugins/agent_chat/widgets/press_to_record_button.dart';
import 'package:aboutme/screens/settings_screen/widgets/speech_recognition_settings_dialog.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

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

  /// 快捷工具栏常驻动作 id（持久化，勾选入口见动作抽屉 header）

  static const Set<String> _defaultQuickActionIds = {'photo', 'video'};
  Set<String> _quickActionIds = _defaultQuickActionIds;

  Future<void> _loadQuickActionIds() async {
    try {
      final response = await AboutmeDataService.instance.get('chat', 'getQuickActions');
      if (response['success'] != true) throw StateError(response['error'].toString());
      final list = response['data'];
      if (list is List && list.every((e) => e is String)) {
        if (mounted) setState(() => _quickActionIds = {...list.cast<String>()});
      }
    } catch (_) {
      // 无配置或解析失败时保持默认集合
    }
  }

  void _setQuickActionIds(Set<String> ids) async {
    final response = await AboutmeDataService.instance.call('chat', 'updateQuickActions', {'ids': ids.toList()});
    if (response['success'] != true) { debugPrint('[Chat] 保存快捷动作失败: ${response['error']}'); return; }
    if (mounted) setState(() => _quickActionIds = ids);
  }

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

    _loadQuickActionIds();
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

  void _handleFileSelected(Map<String, dynamic> file) {
    setState(() {
      selectedFiles.add(file);
      _updateMessageInputState();
    });
  }

  /// 智能体统一入口：打开自动回复设置弹层（与频道菜单共用）
  Future<void> _openAutoReplySettings() async {
    final channel = ChatPlugin.instance.channelService.currentChannel;
    if (channel == null) return;
    await showAutoReplySettingsSheet(context: context, channelId: channel.id);
    if (mounted) setState(() {}); // 刷新入口文案
  }

  /// 智能体统一入口的显示文案（空串 = 不显示）：
  /// 自动回复已开启显示 agent 名，否则显示 @ 选择的智能体名称
  String _agentsEntryLabel() {
    final channel = ChatPlugin.instance.channelService.currentChannel;
    final cfg = channel == null ? <String, dynamic>{} : readAutoReplyConfig(channel);
    final agent = cfg['enabled'] == true ? autoReplyAgentOf(cfg) : null;
    if (agent != null) return '自动回复：${agent['name']}';
    if (selectedAgents.isNotEmpty) {
      final names = selectedAgents
          .map((a) => a['name'] ?? '')
          .where((n) => n.isNotEmpty)
          .join('、');
      return '@ $names';
    }
    return '';
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

  /// 长按打开语音输入对话框（整段 ASR 识别，结果写入输入框）
  Future<void> _showVoiceInputDialog() async {
    if (!mounted) return;

    await VoiceRecognitionHelper.showVoiceInputDialog(
      context: context,
      autoStartRecording: true,
      onComplete: (text) {
        widget.controller.text = text;
        widget.onSaveDraft(text);
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

  /// 顶部图标工具栏快捷动作：抽屉动作按持久化配置过滤（勾选入口在抽屉 header）
  List<common.MessageInputQuickAction> _buildQuickActions() {
    return [
      for (final action in MessageInputActionsBuilder.getDefaultActions(
        context,
        onFileSelected: _handleFileSelected,
        onSendMessage: widget.onSendMessage,
        textController: widget.controller,
      ))
        if (_quickActionIds.contains(action.id))
          common.MessageInputQuickAction(
            icon: action.icon,
            tooltip: action.title,
            onPressed: action.onTap,
            onLongPress: action.onLongPress,
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
        quickActionIds: _quickActionIds,
        onQuickActionIdsChanged: _setQuickActionIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return common.MessageInput(
      controller: widget.controller,
      focusNode: _focusNode,
      hintText: 'chat_enterMessage'.tr,
      onChanged: (text) => widget.onSaveDraft(text),
      quickActions: _buildQuickActions(),
      // 工具栏右组：表情（语音入口移至输入框内嵌后缀，与 agent_chat 对齐）
      trailingQuickActions: [
        common.MessageInputQuickAction(
          icon: DsIconKind.mood,
          tooltip: '表情',
          onPressed: _showEmojiPicker,
        ),
      ],
      // 录音：点击开始/停止，识别结果实时写入输入框；
      // 长按打开语音输入对话框（整段识别）；未配置时点击打开配置
      inputSuffix: _recognitionService != null
          ? PressToRecordButton(
              textController: widget.controller,
              recognitionService: _recognitionService!,
              size: 20,
              tooltip: '录音',
              onRecognitionComplete: (_) => _focusNode.requestFocus(),
              onError: (error) {
                if (mounted) toastService.showToast('语音识别失败: $error');
              },
              onLongPress: _showVoiceInputDialog,
            )
          : _InlineIconAction(
              icon: DsIconKind.mic,
              color: DSThemeBridge.resolve(context).textSub,
              onPressed: () => SpeechRecognitionSettingsDialog.show(context),
              tooltip: '语音输入（未配置，点击配置）',
            ),
      onOpenActionsDrawer: _showActionsDrawer,
      header: MetadataDisplay(
        selectedFiles: selectedFiles,
        agentsEntryLabel: _agentsEntryLabel(),
        onAgentsEntryTap: _openAutoReplySettings,
        onFileRemoveAt: _removeFileAt,
      ),
      onSend: _handleSendMessage,
      onKeyEvent: (event) => _messageInputState.handleKeyPress(event),
    );
  }
}

/// 输入框内嵌的无边框小图标按钮（语音未配置时的回退入口）
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
