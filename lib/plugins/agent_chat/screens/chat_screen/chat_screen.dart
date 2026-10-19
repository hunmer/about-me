import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/widgets/agent_list_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/plugins/tts/widgets/tts_settings_dialog.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/agent_chat/services/conversation_service.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_detail_service.dart';
import 'package:aboutme/plugins/agent_chat/services/suggested_questions_service.dart';
import 'package:aboutme/plugins/agent_chat/services/voice_call/voice_call_manager.dart';
import 'package:aboutme/plugins/agent_chat/models/voice_call_config.dart'
    show VoiceCallConfig, TTSConfig;
import 'package:aboutme/plugins/agent_chat/services/voice_call/voice_call_config_dialog.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/voice_call_screen.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/tencent_asr_service.dart';
import 'package:aboutme/core/services/speech_recognition_config_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/services/agent_file_space_service.dart';
import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'components/message_bubble.dart';
import 'components/message_input.dart';
import 'components/save_tool_dialog.dart';
import 'components/markdown_content.dart';
import 'components/tool_detail_dialog.dart';
import 'package:aboutme/plugins/agent_chat/screens/tool_management_screen/tool_management_screen.dart';
import 'package:aboutme/plugins/moments/screens/moments_home_screen.dart';
import 'package:aboutme/plugins/agent_chat/screens/tool_template_screen/tool_template_screen.dart';
// 复用 chat 插件的通用聊天壳与消息列表
import 'package:aboutme/plugins/chat/models/message.dart'
    show Message, MessageType;
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/chat_screen_scaffold.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_list.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_bubble/index.dart'
    as chat_bubble;
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/file_management_screen.dart';
import 'package:aboutme/widgets/message_input/message_input.dart'
    show MessageInputQuickAction;
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

part 'chat_screen_tts_voice.dart';
part 'chat_screen_suggestions.dart';
part 'chat_screen_topbar.dart';
part 'chat_screen_message_list.dart';
part 'chat_screen_dialogs.dart';
part 'chat_screen_search_filter.dart';

/// 聊天界面
class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final StorageManager storage;
  final ConversationService? conversationService;
  final Map<String, dynamic> Function()? getSettings; // 获取插件设置的回调
  final String? initialMessage; // 初始消息文本（预填充到输入框）
  final List<File>? initialFiles; // 初始附件文件（预添加到消息）
  final bool autoSend; // 是否自动发送 initialMessage
  final List<String>? initialPrompts; // 初始开场白列表（优先于猜你想问，如路由上下文快捷提问）
  final String? initialContext; // 初始路由上下文（随首条用户消息注入，携带 channelId 等参数）

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.storage,
    this.conversationService,
    this.getSettings,
    this.initialMessage,
    this.initialFiles,
    this.autoSend = false,
    this.initialPrompts,
    this.initialContext,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _controller;
  late final ToolTemplateService _templateService;

  /// 通用消息列表使用的滚动控制器（reverse 列表，起始位置即底部）
  final AutoScrollController _scrollController = AutoScrollController();

  /// 通用消息列表所需的多选集合（agent 场景不启用多选，保持空集合）
  final ValueNotifier<Set<String>> _selectedMessageIds = ValueNotifier(
    <String>{},
  );

  /// 是否处于多选模式（批量复制/删除）
  bool _isMultiSelectMode = false;

  /// 本地用户与 AI 占位用户（仅用于通用 Message 模型的对齐与分组）
  static const User _localUser = User(
    id: 'agent_chat_local_user',
    username: '我',
  );

  bool _uiHandlersRegistered = false;
  bool _autoReadEnabled = false; // 自动朗读开关
  String? _selectedTTSServiceId; // 选择的TTS服务ID
  String? _lastReadMessageId; // 上次朗读的消息ID
  String? _lastVoiceCallMessageId; // 上次发送到语音通话的消息ID（防止重复处理）

  // Agent 选择状态 - 由 ChatScreen 自己管理
  AIAgent? _currentAgent;
  List<AIAgent>? _agentChain; // 使用 AIAgent 列表而不是 AgentChainNode
  bool _isChainMode = false;

  // 猜你想问相关
  List<String> _suggestedQuestions = [];
  bool _isLoadingSuggestions = false;
  final SuggestedQuestionsService _suggestionsService =
      SuggestedQuestionsService();

  // 搜索和过滤状态（复用 chat 壳的搜索/过滤栏）
  String _searchQuery = '';
  final MultiFilterState _filterState = MultiFilterState();
  List<ChatMessage> _filteredMessages = [];

  // 语音通话相关
  VoiceCallManager? _voiceCallManager;
  VoiceCallConfig _voiceCallConfig = const VoiceCallConfig();
  final StreamController<String> _aiMessageStreamController =
      StreamController<String>.broadcast();

  @override
  void initState() {
    super.initState();
    debugPrint(
      '🎬 ChatScreen initState: conversationId=${widget.conversation.id}, agentId=${widget.conversation.agentId}',
    );

    // 在第一帧渲染后注册 UI 处理器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_uiHandlersRegistered && mounted) {
        JSBridgeManager.instance.registerUIHandlers(context);
        _uiHandlersRegistered = true;
        debugPrint('✓ ChatScreen: UI 处理器已注册');
      }
    });

    _initializeController();
    _loadSuggestedQuestions();
    _loadChatSettings(); // 加载聊天设置（TTS、语音通话配置）
    _initializeVoiceCall();
  }

  /// 加载聊天设置（从会话配置中加载）
  void _loadChatSettings() {
    // 从 ConversationService 获取最新的会话对象（而非 widget.conversation）
    final latestConversation = _controller.conversationService.getConversation(
      widget.conversation.id,
    );

    // 从会话中加载 TTS 配置
    final ttsConfig = latestConversation?.ttsConfig;
    if (ttsConfig != null) {
      _autoReadEnabled = ttsConfig.enabled;
      _selectedTTSServiceId = ttsConfig.serviceId;
    }

    // 从会话中加载语音通话配置
    final voiceCallConfig = latestConversation?.voiceCallConfig;
    if (voiceCallConfig != null) {
      _voiceCallConfig = voiceCallConfig;
    }

    debugPrint(
      '📖 已加载会话设置: autoReadEnabled=$_autoReadEnabled, voiceCallConfig=${voiceCallConfig != null}',
    );
  }

  /// 保存聊天设置（保存到会话配置）
  Future<void> _saveChatSettings() async {
    try {
      // 更新会话配置
      final updatedConversation = widget.conversation.copyWith(
        ttsConfig: TTSConfig(
          enabled: _autoReadEnabled,
          serviceId: _selectedTTSServiceId,
        ),
        voiceCallConfig: _voiceCallConfig,
      );

      // 保存会话
      await _controller.conversationService.updateConversation(
        updatedConversation,
      );
      debugPrint('💾 已保存会话设置到 conversation');
    } catch (e) {
      debugPrint('❌ 保存会话设置失败: $e');
    }
  }

  Future<void> _initializeController() async {
    // 初始化工具模板服务
    _templateService = ToolTemplateService(widget.storage);

    _controller = ChatController(
      conversation: widget.conversation,
      messageService: MessageService(storage: widget.storage),
      conversationService:
          widget.conversationService ??
          ConversationService(storage: widget.storage),
      messageDetailService: MessageDetailService(storage: widget.storage),
      templateService: _templateService,
      getSettings: widget.getSettings,
    );

    debugPrint('🚀 开始初始化ChatController');
    await _controller.initialize();
    debugPrint(
      '✅ ChatController初始化完成, currentAgent=${_controller.currentAgent?.name}',
    );

    // 如果提供了初始消息，设置到输入框
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _controller.setInputText(widget.initialMessage!);
      debugPrint('✅ 已设置初始消息到输入框: ${widget.initialMessage}');
    }

    // 如果提供了初始路由上下文，随首条用户消息注入
    if (widget.initialContext != null && widget.initialContext!.isNotEmpty) {
      _controller.setPendingRouteContext(widget.initialContext);
      debugPrint('✅ 已设置初始路由上下文: ${widget.initialContext}');
    }

    // 如果提供了初始文件，设置到 controller
    if (widget.initialFiles != null && widget.initialFiles!.isNotEmpty) {
      _controller.setInitialFiles(widget.initialFiles!);
      debugPrint('✅ 已设置 ${widget.initialFiles!.length} 个初始文件');
    }

    // 从 controller 同步初始 agent 状态到本地
    _syncAgentStateFromController();

    // 初始化完成后在下一帧添加监听器，避免在build期间触发setState
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.addListener(_onControllerChanged);
          _controller.messageService.addListener(_onControllerChanged);

          // 触发一次更新以显示初始化后的数据
          setState(() {});

          // 如果需要自动发送消息
          if (widget.autoSend &&
              widget.initialMessage != null &&
              widget.initialMessage!.isNotEmpty) {
            debugPrint('🚀 自动发送 Shortcuts 消息: ${widget.initialMessage}');
            // 延迟一帧确保 UI 完全初始化后再发送
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _controller.sendMessage().catchError((e) {
                  debugPrint('❌ 自动发送消息失败: $e');
                });
              }
            });
          }
        }
      });
    }
  }

  /// 从 controller 同步 agent 状态到本地
  void _syncAgentStateFromController() {
    _isChainMode = _controller.isChainMode;
    _currentAgent = _controller.currentAgent;
    _agentChain = _controller.agentChain;
  }

  void _onControllerChanged() {
    if (mounted) {
      // 使用 addPostFrameCallback 避免在构建过程中调用 setState
      // 消息列表为 reverse 布局，停留在底部时新消息自动可见，无需手动滚动
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });

      // 检查是否有新的AI消息完成，如果开启了自动朗读则进行朗读
      if (_autoReadEnabled) {
        _checkAndReadNewAIMessage();
      }

      // 检查是否需要发送AI消息到语音通话管理器
      _checkAndSendAIMessageToVoiceCall();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 复用 chat 插件的通用聊天壳：SuperCupertino 导航 + 背景支持 + body 插槽
    return ChatScreenScaffold(
      title: _buildAgentTitle(),
      largeTitle: widget.conversation.title,
      enableSearchBar: true,
      searchPlaceholder: '搜索消息内容...',
      onSearchChanged: _handleSearchChanged,
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      onMultiFilterChanged: _handleFilterChanged,
      actions: _buildAgentActions(),
      body: _buildAgentBody(),
    );
  }

  /// 主体内容：工具栏/猜你想问 + 消息列表 + 输入框
  Widget _buildAgentBody() {
    if (_controller.isLoading) {
      return const Center(child: DSThemeBridge(child: DSLoadingDots()));
    }

    return Column(
      children: [
        // 已选工具列表
        if (_controller.selectedTools.isNotEmpty) _buildSelectedToolsBar(),

        // 猜你想问区域
        if (_suggestedQuestions.isNotEmpty && _controller.messages.isEmpty)
          _buildSuggestedQuestionsBar(),

        // 消息列表
        Expanded(
          child: _controller.messages.isEmpty
              ? _buildEmptyState()
              : _buildAgentMessageList(),
        ),

        // 输入框
        MessageInput(
          controller: _controller,
          extraQuickActions: _buildExtraQuickActions(),
        ),
      ],
    );
  }

  /// 输入框顶部工具栏的附加动作（由顶栏迁移而来）
  List<MessageInputQuickAction> _buildExtraQuickActions() {
    return [
      MessageInputQuickAction(
        icon: DsIconKind.clipboard,
        tooltip: '工具模板',
        onPressed: _openToolTemplateManagement,
      ),
      MessageInputQuickAction(
        icon: DsIconKind.gear,
        tooltip: 'agent_chat_toolManagement'.tr,
        onPressed: _openToolManagement,
      ),
      MessageInputQuickAction(
        icon: DsIconKind.image,
        tooltip: '朋友圈',
        onPressed: _openMoments,
      ),
      MessageInputQuickAction(
        icon: DsIconKind.folder,
        tooltip: '文件管理',
        onPressed: () async {
          final directory = await AgentFileSpaceService.instance
              .directoryForChannel(widget.conversation.id);
          if (!mounted) return;
          NavigationHelper.push(
            context,
            FileManagementScreen(
              rootDirectory: directory,
              title: '${widget.conversation.title} 文件',
            ),
          );
        },
      ),
    ];
  }

  @override
  void dispose() {
    debugPrint('[ChatScreen] dispose 开始');
    _filterState.dispose();
    _selectedMessageIds.dispose();
    _voiceCallManager?.dispose();
    _aiMessageStreamController.close();
    _controller.removeListener(_onControllerChanged);
    _controller.messageService.removeListener(_onControllerChanged);
    _controller.dispose();
    debugPrint('[ChatScreen] controller 已释放，继续 dispose');
    _scrollController.dispose();
    super.dispose();
    debugPrint('[ChatScreen] dispose 完成');
  }
}

/// 顶栏气泡菜单行
/// 语音通话前台服务任务处理器
/// 新消息气泡入场动画：淡入 + 轻微上移/缩放。
/// 仅对"5 秒内到达"的新消息播放，历史消息滚动回看时不重播。
