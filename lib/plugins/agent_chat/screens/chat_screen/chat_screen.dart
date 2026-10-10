import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/plugins/tts/widgets/tts_settings_dialog.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
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
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/models/llm_models.dart';
import 'package:aboutme/plugins/openai/widgets/agent_list_drawer.dart';
import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'components/message_bubble.dart';
import 'components/message_input.dart';
import 'components/save_tool_dialog.dart';
import 'components/agent_chain_config_dialog.dart';
import 'components/markdown_content.dart';
import 'components/tool_detail_dialog.dart';
import 'package:aboutme/plugins/agent_chat/screens/tool_management_screen/tool_management_screen.dart';
import 'package:aboutme/plugins/openai/moments/screens/moments_screen.dart';
import 'package:aboutme/plugins/agent_chat/screens/tool_template_screen/tool_template_screen.dart';
// 复用 chat 插件的通用聊天壳与消息列表
import 'package:aboutme/plugins/chat/models/message.dart'
    show Message, MessageType;
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/chat_screen_scaffold.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_list.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_bubble/index.dart'
    as chat_bubble;
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

/// 聊天界面
class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final StorageManager storage;
  final ConversationService? conversationService;
  final Map<String, dynamic> Function()? getSettings; // 获取插件设置的回调
  final String? initialMessage; // 初始消息文本（预填充到输入框）
  final List<File>? initialFiles; // 初始附件文件（预添加到消息）
  final bool autoSend; // 是否自动发送 initialMessage

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.storage,
    this.conversationService,
    this.getSettings,
    this.initialMessage,
    this.initialFiles,
    this.autoSend = false,
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

  /// 检查并朗读新的AI消息
  void _checkAndReadNewAIMessage() {
    try {
      // 获取所有消息
      final messages = _controller.messages;
      if (messages.isEmpty) return;

      // 从后往前查找第一条AI消息(非生成中)
      for (int i = messages.length - 1; i >= 0; i--) {
        final message = messages[i];

        // 只朗读AI消息，且消息已完成(非生成中)
        if (!message.isUser && !message.isGenerating) {
          // 检查是否是新消息(避免重复朗读)
          if (_lastReadMessageId != message.id &&
              message.content.trim().isNotEmpty) {
            _lastReadMessageId = message.id;

            // 调用TTS朗读
            _readMessage(message.content);
          }
          break; // 只处理最新的一条AI消息
        }
      }
    } catch (e) {
      debugPrint('检查并朗读AI消息失败: $e');
    }
  }

  /// 朗读消息
  Future<void> _readMessage(String text) async {
    try {
      final ttsPlugin = TTSPlugin.instance;
      await ttsPlugin.speak(
        text,
        serviceId: _selectedTTSServiceId, // 使用选择的服务
        onStart: () {
          debugPrint('开始朗读AI消息');
        },
        onComplete: () {
          debugPrint('朗读AI消息完成');
        },
        onError: (error) {
          debugPrint('朗读AI消息出错: $error');
        },
      );
    } catch (e) {
      debugPrint('调用TTS朗读失败: $e');
    }
  }

  // ========== 语音通话相关方法 ==========

  /// 初始化语音通话功能
  Future<void> _initializeVoiceCall() async {
    try {
      // 从全局配置服务获取ASR配置
      final asrConfig = SpeechRecognitionConfigService.instance.config;

      if (asrConfig == null || !asrConfig.isValid()) {
        debugPrint('⚠️ 未配置ASR服务，语音通话功能将不可用');
        return;
      }

      final recognitionService = TencentASRService(config: asrConfig);

      _voiceCallManager = VoiceCallManager(
        recognitionService: recognitionService,
        onUserMessage: (text) async {
          // 设置输入框文本并发送
          _controller.setInputText(text);
          await _controller.sendMessage();
        },
        aiMessageStream: _aiMessageStreamController.stream,
        onStateChanged: (state) {
          debugPrint('语音通话状态变更: $state');
        },
        onPhaseChanged: (phase) {
          debugPrint('语音通话阶段: $phase');
        },
        onError: (error) {
          if (mounted) {
            toastService.showToast('语音通话错误: $error');
          }
        },
      );

      // 应用从设置加载的配置
      _voiceCallManager!.updateConfig(_voiceCallConfig);

      await _voiceCallManager!.initialize();
      debugPrint('✅ 语音通话管理器初始化完成');
    } catch (e) {
      debugPrint('❌ 语音通话管理器初始化失败: $e');
    }
  }

  /// 检查并发送AI消息到语音通话管理器
  void _checkAndSendAIMessageToVoiceCall() {
    if (_voiceCallManager == null || !_voiceCallManager!.isCallActive) return;

    try {
      final messages = _controller.messages;
      if (messages.isEmpty) return;

      // 获取最新的AI消息
      for (int i = messages.length - 1; i >= 0; i--) {
        final message = messages[i];

        // 只处理AI消息，且消息已完成(非生成中)
        if (!message.isUser && !message.isGenerating) {
          // 检查是否是新消息（避免重复处理）
          if (_lastVoiceCallMessageId != message.id &&
              message.content.trim().isNotEmpty) {
            _lastVoiceCallMessageId = message.id;
            _voiceCallManager?.handleAIMessage(message.content);
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('发送AI消息到语音通话管理器失败: $e');
    }
  }

  /// 打开语音通话界面
  Future<void> _openVoiceCall() async {
    if (_voiceCallManager == null) {
      toastService.showToast('语音通话功能未初始化，请先配置ASR服务');
      return;
    }

    // 启动前台服务
    await _startVoiceCallForegroundService();

    // 打开语音通话全屏界面
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          manager: _voiceCallManager!,
          agent: _currentAgent,
          onExit: () async {
            await _stopVoiceCallForegroundService();
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
          onConfigChanged: (config) async {
            setState(() {
              _voiceCallConfig = config;
            });
            await _saveChatSettings();
          },
        ),
      ),
    );
  }

  /// 启动语音通话前台服务
  Future<void> _startVoiceCallForegroundService() async {
    if (!UniversalPlatform.isAndroid) return;

    try {
      final isRunning = await FlutterForegroundTask.isRunningService;

      if (!isRunning) {
        await FlutterForegroundTask.startService(
          serviceId: 258, // 使用不同的ID避免与聊天前台服务冲突
          notificationTitle: 'AI 语音通话',
          notificationText: '正在通话中...',
          notificationButtons: [
            NotificationButton(text: '暂停', id: 'pause'),
            NotificationButton(text: '结束', id: 'end'),
          ],
          callback: startVoiceCallTaskCallback,
        );
        debugPrint('✅ 语音通话前台服务已启动');
      }
    } catch (e) {
      debugPrint('❌ 启动语音通话前台服务失败: $e');
    }
  }

  /// 停止语音通话前台服务
  Future<void> _stopVoiceCallForegroundService() async {
    if (!UniversalPlatform.isAndroid) return;

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        debugPrint('✅ 语音通话前台服务已停止');
      }
    } catch (e) {
      debugPrint('❌ 停止语音通话前台服务失败: $e');
    }
  }

  /// 显示语音通话配置对话框的便捷方法
  Future<VoiceCallConfig?> showVoiceCallConfigDialog(
    BuildContext context, {
    required VoiceCallConfig initialConfig,
  }) {
    return showDSDialog<VoiceCallConfig>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => VoiceCallConfigDialog(initialConfig: initialConfig),
    );
  }

  /// 加载建议问题
  Future<void> _loadSuggestedQuestions() async {
    // 检查 agent 是否开启了猜你想问功能
    if (_currentAgent == null || !_currentAgent!.enableOpeningQuestions) {
      setState(() {
        _suggestedQuestions = [];
      });
      return;
    }

    // 如果有预设问题,使用预设问题
    if (_currentAgent!.openingQuestions.isNotEmpty) {
      setState(() {
        _suggestedQuestions = List.from(_currentAgent!.openingQuestions);
      });
    } else {
      // 否则使用随机问题
      final questions = await _suggestionsService.getRandomQuestions(count: 5);
      setState(() {
        _suggestedQuestions = questions;
      });
    }
  }

  /// 刷新建议问题（使用 AI 生成）
  Future<void> _refreshSuggestedQuestions() async {
    if (_currentAgent == null) return;

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      // 使用 AI 生成新问题
      final questions = await _suggestionsService.generateQuestionsWithAI(
        agent: _currentAgent!,
        count: 5,
      );

      setState(() {
        _suggestedQuestions = questions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSuggestions = false;
      });

      if (mounted) {
        toastService.showToast('生成问题失败: $e');
      }
    }
  }

  /// 打开TTS设置对话框
  Future<void> _openTTSSettings() async {
    final result = await showTTSSettingsDialog(
      context,
      initialEnabled: _autoReadEnabled,
      initialServiceId: _selectedTTSServiceId,
    );

    if (result != null) {
      setState(() {
        _autoReadEnabled = result.enabled;
        _selectedTTSServiceId = result.serviceId;
      });

      // 保存设置到插件配置
      await _saveChatSettings();

      // 显示提示
      if (mounted) {
        toastService.showToast(result.enabled ? '已开启自动朗读' : '已关闭自动朗读');
      }
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

  /// 顶栏标题：会话名 + Agent/输入中状态，点击打开 Agent 选择器
  Widget _buildAgentTitle() {
    final isTyping =
        _controller.isSending ||
        _controller.isThinking ||
        _controller.alivenessFlushActive;

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showAgentSelector,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 正在输入状态（替代 agent 信息显示）
                      if (isTyping) ...[
                        SizedBox(
                          width: 6,
                          height: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _controller.typingStatusText ?? '正在输入中…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.caption.copyWith(
                              color: theme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else ...[
                        DsIcon(
                          _isChainMode ? DsIconKind.layers : DsIconKind.bot,
                          size: 12,
                          color: theme.textSub,
                        ),
                        const SizedBox(width: 4),
                        // 显示 agent 信息
                        Flexible(
                          child: Text(
                            _getAgentDisplayText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.caption.copyWith(
                              color: _hasValidAgent()
                                  ? theme.textSub
                                  : theme.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      DsIcon(
                        DsIconKind.chevronDown,
                        size: 14,
                        color: theme.textSub,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 顶栏操作按钮：工具Agent配置/工具模板/TTS/语音通话/更多菜单
  List<Widget> _buildAgentActions() {
    // 颜色在构建期解析（按钮挂到导航壳的 actions 槽位，不依赖渲染处主题祖树）
    final theme = DSThemeBridge.resolve(context);

    // 多选模式：复制/删除选中 + 退出
    if (_isMultiSelectMode) {
      return [
        DSIconButton(
          icon: DsIconKind.copy,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: _copySelectedMessages,
          tooltip: '复制选中消息',
        ),
        DSIconButton(
          icon: DsIconKind.trash,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.danger,
          onPressed: _deleteSelectedMessages,
          tooltip: '删除选中消息',
        ),
        DSIconButton(
          icon: DsIconKind.close,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: _toggleMultiSelectMode,
          tooltip: '退出多选模式',
        ),
      ];
    }

    return [
      DSIconButton(
        icon: DsIconKind.gear,
        size: 36,
        color: theme.surfaceAlt,
        iconColor: theme.textSub,
        onPressed: _showToolAgentsConfig,
        tooltip: '工具调用 Agent',
      ),
      DSIconButton(
        icon: DsIconKind.clipboard,
        size: 36,
        color: theme.surfaceAlt,
        iconColor: theme.textSub,
        onPressed: _openToolTemplateManagement,
        tooltip: '工具模板',
      ),
      // 语音相关按钮（仅在设置了 Agent 时显示）
      if (_currentAgent != null) ...[
        DSIconButton(
          icon: DsIconKind.bell,
          size: 36,
          color: _autoReadEnabled ? theme.primary : theme.surfaceAlt,
          iconColor: _autoReadEnabled ? theme.onPrimary : theme.textSub,
          onPressed: _openTTSSettings,
          tooltip: '语音播报设置',
        ),
        DSIconButton(
          icon: DsIconKind.mic,
          size: 36,
          color: theme.surfaceAlt,
          iconColor: theme.textSub,
          onPressed: _openVoiceCall,
          tooltip: '语音通话',
        ),
      ],
      _buildMoreMenu(theme),
    ];
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
        MessageInput(controller: _controller),
      ],
    );
  }

  /// 消息列表：适配为通用 Message 模型，气泡复用 chat 框架 + agent 内容注入
  Widget _buildAgentMessageList() {
    // 搜索/过滤时展示过滤结果
    final messages = _searchQuery.isNotEmpty || _filterState.hasAnyFilter
        ? _filteredMessages
        : _controller.messages;
    final sourceById = <String, ChatMessage>{};
    final adapted = <Message>[];
    for (final message in messages) {
      sourceById[message.id] = message;
      adapted.add(_adaptMessage(message));
    }

    // 组内首条：发送方切换或跨天时重显头像/用户名（与 chat 分组策略一致）
    final firstOfGroupById = <String, bool>{};
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      firstOfGroupById[message.id] =
          prev == null ||
          prev.isUser != message.isUser ||
          !_isSameDay(prev.timestamp, message.timestamp);
    }

    return MessageList(
      items: _buildItemsWithDateSeparators(adapted),
      isMultiSelectMode: _isMultiSelectMode,
      selectedMessageIds: _selectedMessageIds,
      scrollController: _scrollController,
      // 新会话按钮固定在列表视觉底部（随内容滚动）
      listBottomWidget: _buildNewSessionButton(),
      bubbleBuilder: (context, message) {
        final source = sourceById[message.id];
        if (source == null) return const SizedBox.shrink();

        // 会话分隔符：特殊样式，不进气泡框架
        if (source.isSessionDivider) {
          return _SessionDivider(message: source);
        }

        // 链式调用的后续消息/最终总结隐藏（与原 agent 气泡逻辑一致）
        if (source.chainExecutionId != null &&
            ((source.chainStepIndex != null && source.chainStepIndex! > 0) ||
                source.isFinalSummary)) {
          return const SizedBox.shrink();
        }

        return _BubbleEntrance(
          isNew: source.timestamp.isAfter(
            DateTime.now().subtract(const Duration(seconds: 5)),
          ),
          alignRight: source.isUser,
          // chat 气泡框架：头像/时间戳/悬浮操作栏，内容由 agent 组件注入
          child: chat_bubble.MessageBubble(
            message: message,
            isSelected: _selectedMessageIds.value.contains(source.id),
            isMultiSelectMode: _isMultiSelectMode,
            // 多选模式下点击气泡切换选中
            onTap: _isMultiSelectMode
                ? () => _toggleMessageSelection(source.id)
                : null,
            currentUserId: _localUser.id,
            showAvatar: true,
            isFirstOfGroup: firstOfGroupById[source.id] ?? true,
            onEdit: () => _showEditMessageDialog(source),
            onDelete: () => _showDeleteConfirmation(source.id),
            onCopy: () => _copyMessage(source),
            onSetFixedSymbol: (_) {},
            contentBuilder: (context, message, textColor) =>
                AgentMessageContent(
                  message: source,
                  textColor: textColor,
                  onExecuteTemplate: (messageId, templateId) async {
                    final template = _controller.templateService
                        ?.getTemplateById(templateId);
                    if (template != null) {
                      await _controller.executeMatchedTemplate(
                        messageId,
                        template,
                      );
                    }
                  },
                  onRerunStep: (messageId, stepIndex) async {
                    await _handleRerunStep(messageId, stepIndex);
                  },
                  getTemplateName: (templateId) {
                    return _controller.templateService
                        ?.getTemplateById(templateId)
                        ?.name;
                  },
                  getAgentName: (agentId) {
                    // 从 agent 链中查找
                    if (_isChainMode && _agentChain != null) {
                      final agent = _agentChain!.firstWhere(
                        (a) => a.id == agentId,
                        orElse: () => _agentChain!.first,
                      );
                      return agent.name;
                    }
                    return _currentAgent?.name;
                  },
                  messageService: _controller.messageService,
                ),
            infoBarTrailing: _buildThinkingEntry(source),
            actionsOverride: _buildAgentActionRow(source),
            showActionsOnOwnMessage: true,
          ),
        );
      },
      // 以下回调仅默认气泡路径使用，自定义气泡下不生效
      onMessageEdit: (_) {},
      onMessageDelete: (_) async {},
      onMessageCopy: (_) {},
      onSetFixedSymbol: (_, _) {},
      onSetBubbleColor: (_, _) {},
      onReply: (_) {},
      onToggleFavorite: (_) {},
      onToggleMessageSelection: (_) {},
      onReplyTap: (_) {},
    );
  }

  /// 将 agent 的 ChatMessage 适配为通用 Message 模型（用于气泡框架布局/日期分隔）
  Message _adaptMessage(ChatMessage message) {
    final isUser = message.isUser;
    return Message(
      id: message.id,
      content: message.content,
      user: isUser
          ? _localUser
          : User(
              id: 'agent_chat_agent',
              username: _getAgentDisplayText(),
              iconPath: _currentAgent?.avatarUrl,
            ),
      type: isUser ? MessageType.sent : MessageType.received,
      date: message.timestamp,
      editedAt: message.editedAt,
      metadata: {
        ...?message.metadata,
        // 用户消息被 AI 已读（活人感）：转换为 chat 气泡的 readBy 约定
        if (isUser && message.metadata?['readAt'] != null)
          'readBy': <dynamic>['ai'],
      },
    );
  }

  /// 复制消息内容
  void _copyMessage(ChatMessage source) {
    Clipboard.setData(ClipboardData(text: source.content));
    toastService.showToast('已复制到剪贴板');
  }

  /// 切换多选模式（退出时清空选中）
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedMessageIds.value = <String>{};
      }
    });
  }

  /// 切换消息选中状态
  void _toggleMessageSelection(String messageId) {
    final selected = Set<String>.from(_selectedMessageIds.value);
    if (!selected.add(messageId)) {
      selected.remove(messageId);
    }
    _selectedMessageIds.value = selected;
  }

  /// 复制多条选中的消息
  void _copySelectedMessages() {
    final selectedMessages = _controller.messages
        .where((m) => _selectedMessageIds.value.contains(m.id))
        .toList();

    if (selectedMessages.isEmpty) return;

    final textToCopy = selectedMessages
        .map((m) => '${m.isUser ? '我' : 'AI'}: ${m.content}')
        .join('\n\n');

    Clipboard.setData(ClipboardData(text: textToCopy));
    toastService.showToast('已复制 ${selectedMessages.length} 条消息');

    _toggleMultiSelectMode();
  }

  /// 删除多条选中的消息
  Future<void> _deleteSelectedMessages() async {
    final selectedMessages = _controller.messages
        .where((m) => _selectedMessageIds.value.contains(m.id))
        .toList();

    if (selectedMessages.isEmpty) return;

    // 显示一次确认对话框
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) => DSDialog(
            title: '删除消息',
            message: '确定要删除选中的 ${selectedMessages.length} 条消息吗？此操作不可撤销。',
            cancelText: 'agent_chat_cancel'.tr,
            confirmText: 'agent_chat_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () => Navigator.pop(dialogContext, true),
            onCancel: () => Navigator.pop(dialogContext, false),
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      for (final message in selectedMessages) {
        await _controller.deleteMessage(message.id);
      }
      if (mounted) {
        toastService.showToast('已删除 ${selectedMessages.length} 条消息');
        _toggleMultiSelectMode();
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('删除失败: $e');
      }
    }
  }

  /// 气泡悬浮操作栏（chat 风格）：按消息类型动态生成按钮
  Widget _buildAgentActionRow(ChatMessage source) {
    final isToolCallMessage =
        source.toolCall != null && source.toolCall!.steps.isNotEmpty;

    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        Widget action(
          DsIconKind icon,
          String tooltip,
          VoidCallback onPressed, {
          Color? iconColor,
        }) => DSIconButton(
          icon: icon,
          size: 32,
          color: theme.surfaceAlt,
          iconColor: iconColor ?? theme.textSub,
          onPressed: onPressed,
          tooltip: tooltip,
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            action(DsIconKind.copy, '复制', () => _copyMessage(source)),
            // 工具调用消息不可编辑
            if (!isToolCallMessage)
              action(
                DsIconKind.edit,
                '编辑',
                () => _showEditMessageDialog(source),
              ),
            if (!source.isUser && _currentAgent != null)
              action(
                DsIconKind.refresh,
                '重新生成',
                () => _controller.regenerateResponse(source.id),
              ),
            if (!source.isUser && isToolCallMessage) ...[
              action(
                DsIconKind.download,
                '保存工具',
                () => _handleSaveTool(source),
              ),
              action(
                DsIconKind.refresh,
                '重新执行工具',
                () => _handleRerunTool(source.id),
              ),
              action(DsIconKind.info, '查看详情', () => _showToolDetail(source)),
            ],
            action(
              DsIconKind.trash,
              '删除',
              () => _showDeleteConfirmation(source.id),
              iconColor: theme.danger,
            ),
          ],
        );
      },
    );
  }

  /// 时间戳行尾部：思考过程入口（仅 AI 消息且有思考内容，含内联 think 标签）
  Widget? _buildThinkingEntry(ChatMessage source) {
    if (source.isUser || source.resolvedThinkingContent == null) {
      return null;
    }
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Pressable(
          onPressed: () => _showThinkingSheet(source),
          semanticLabel: '查看思考过程',
          builder: (context, states) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsIcon(DsIconKind.bot, size: 12, color: theme.primaryText),
              const SizedBox(width: 4),
              Text(
                '查看思考过程',
                style: DsTypography.caption.copyWith(color: theme.primaryText),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示消息编辑对话框
  void _showEditMessageDialog(ChatMessage source) {
    final textController = TextEditingController(text: source.content);
    // 与原实现一致：字符数在打开时计算一次
    final initialLength = textController.text.length;

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) {
            final theme = DSThemeBridge.resolve(ctx);
            return JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'agent_chat_editMessage'.tr,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      const SizedBox(width: 8),
                      if (!source.isUser)
                        DSBadge(
                          label: 'AI',
                          color: theme.secondary,
                          textColor: theme.text,
                        ),
                    ],
                  ),
                  SizedBox(height: theme.spacing.md),
                  DSInput(
                    controller: textController,
                    hint: '输入消息内容...',
                    maxLines: null,
                    minLines: 5,
                    keyboardType: TextInputType.multiline,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$initialLength 字符',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ),
                  SizedBox(height: theme.spacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          label: 'agent_chat_cancel'.tr,
                          variant: DSButtonVariant.outline,
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ),
                      SizedBox(width: theme.spacing.md),
                      Expanded(
                        child: DSButton(
                          label: 'agent_chat_save'.tr,
                          onPressed: () {
                            final newContent = textController.text.trim();
                            if (newContent.isNotEmpty &&
                                newContent != source.content) {
                              _controller.editMessage(source.id, newContent);
                            }
                            Navigator.pop(dialogContext);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 底部 sheet 显示思考过程（独立 thinkingContent + 内联 think 合并展示）
  void _showThinkingSheet(ChatMessage source) {
    showDSBottomSheet(
      context: context,
      title: '思考过程',
      builder: (sheetContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) {
            final theme = DSThemeBridge.resolve(ctx);
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
                child: MarkdownContent(
                  content: source.resolvedThinkingContent ?? '',
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 显示工具调用详情对话框
  Future<void> _showToolDetail(ChatMessage source) async {
    // 显示加载指示器
    showDSDialog(
      context: context,
      barrierDismissible: false,
      theme: DSThemeBridge.resolve(context),
      builder: (_) =>
          const DSThemeBridge(child: Center(child: DSLoadingDots())),
    );

    try {
      // 加载消息详细数据
      final detailService = MessageDetailService(storage: widget.storage);
      final detail = await detailService.loadDetail(source.id);

      // 关闭加载指示器
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (detail == null) {
        if (context.mounted) {
          toastService.showToast('未找到详细数据，可能此消息是在更新前创建的');
        }
        return;
      }

      // 显示详情对话框
      if (context.mounted) {
        showDSDialog(
          context: context,
          theme: DSThemeBridge.resolve(context),
          builder: (dialogContext) => ToolDetailDialog(
            detail: detail,
            toolCallSteps: source.toolCall?.steps,
          ),
        );
      }
    } catch (e) {
      // 关闭加载指示器
      if (context.mounted) {
        Navigator.of(context).pop();
        toastService.showToast('加载详情失败: $e');
      }
    }
  }

  /// 搜索回调
  void _handleSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFiltersAndSearch();
    });
  }

  /// 过滤回调
  void _handleFilterChanged(Map<String, dynamic> filters) {
    filters.forEach((key, value) {
      _filterState.setValue(key, value);
    });
    _applyFiltersAndSearch();
  }

  /// 应用搜索与过滤（发送人/日期/标签）
  void _applyFiltersAndSearch() {
    List<ChatMessage> result = List.from(_controller.messages);

    // 应用搜索（仅匹配消息内容）
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result
          .where((m) => m.content.toLowerCase().contains(query))
          .toList();
    }

    // 应用发送人过滤（我 / AI）
    final selectedSender = _filterState.getValue('sender');
    if (selectedSender == 'me') {
      result = result.where((m) => m.isUser).toList();
    } else if (selectedSender == 'ai') {
      result = result.where((m) => !m.isUser).toList();
    }

    // 应用日期范围过滤
    final dateRange = _filterState.getValue('dateRange');
    if (dateRange != null && dateRange is Map<String, DateTime?>) {
      final startDate = dateRange['start'];
      final endDate = dateRange['end'];
      result = result.where((m) {
        if (startDate != null && m.timestamp.isBefore(startDate)) {
          return false;
        }
        if (endDate != null) {
          final endOfDay = DateTime(
            endDate.year,
            endDate.month,
            endDate.day,
            23,
            59,
            59,
          );
          if (m.timestamp.isAfter(endOfDay)) return false;
        }
        return true;
      }).toList();
    }

    // 应用标签过滤
    final selectedTags = _filterState.getValue('tags');
    if (selectedTags != null &&
        selectedTags is List &&
        selectedTags.isNotEmpty) {
      result = result.where((m) {
        final tags = m.metadata?['tags'] as List<String>?;
        if (tags == null || tags.isEmpty) return false;
        return selectedTags.any((tag) => tags.contains(tag));
      }).toList();
    }

    setState(() {
      _filteredMessages = result;
    });
  }

  /// 构建过滤项配置（发送人/日期/标签）
  List<FilterItem> _buildFilterItems() {
    final hasTags = _controller.messages.any(
      (m) => (m.metadata?['tags'] as List?)?.isNotEmpty == true,
    );

    return [
      // 发送人过滤（我 / AI）
      FilterItem(
        id: 'sender',
        title: '发送人',
        type: FilterType.custom,
        builder: (context, currentValue, onChanged) {
          return Wrap(
            spacing: 8,
            children: [
              DSChip(
                label: '我',
                selected: currentValue == 'me',
                onSelected: (selected) => onChanged(selected ? 'me' : null),
              ),
              DSChip(
                label: 'AI',
                selected: currentValue == 'ai',
                onSelected: (selected) => onChanged(selected ? 'ai' : null),
              ),
            ],
          );
        },
        getBadge: (value) => value == 'me'
            ? '我'
            : value == 'ai'
            ? 'AI'
            : null,
      ),

      // 日期范围过滤
      FilterItem(
        id: 'dateRange',
        title: '日期',
        type: FilterType.dateRange,
        builder: (context, currentValue, onChanged) {
          final Map<String, DateTime?> range =
              currentValue ?? {'start': null, 'end': null};
          final startDate = range['start'];
          final endDate = range['end'];

          Widget dateChip({
            required String label,
            required DateTime? current,
            required bool isStart,
          }) {
            return DSThemeBridge(
              child: Builder(
                builder: (context) {
                  final theme = DSThemeBridge.resolve(context);
                  return DSChip(
                    icon: DsIconKind.calendar,
                    label: current == null
                        ? label
                        : DateFormat('MM/dd').format(current),
                    onSelected: (_) async {
                      final picked = await showDSDatePickerDialog(
                        context: context,
                        theme: theme,
                        initial: current ?? DateTime.now(),
                      );
                      if (picked != null) {
                        onChanged({
                          'start': isStart ? picked : startDate,
                          'end': isStart ? endDate : picked,
                        });
                      }
                    },
                  );
                },
              ),
            );
          }

          return Wrap(
            spacing: 8,
            children: [
              dateChip(label: '开始日期', current: startDate, isStart: true),
              dateChip(label: '结束日期', current: endDate, isStart: false),
              if (startDate != null || endDate != null)
                DSThemeBridge(
                  child: Builder(
                    builder: (context) {
                      final theme = DSThemeBridge.resolve(context);
                      return DSIconButton(
                        icon: DsIconKind.close,
                        size: 32,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: () => onChanged(null),
                      );
                    },
                  ),
                ),
            ],
          );
        },
        getBadge: (value) {
          if (value == null) return null;
          final Map<String, DateTime?> range = value;
          final start = range['start'];
          final end = range['end'];
          if (start != null && end != null) {
            return '${DateFormat('MM/dd').format(start)}-${DateFormat('MM/dd').format(end)}';
          } else if (start != null) {
            return '从${DateFormat('MM/dd').format(start)}';
          } else if (end != null) {
            return '至${DateFormat('MM/dd').format(end)}';
          }
          return null;
        },
      ),

      // 标签过滤（仅存在标签时显示）
      if (hasTags)
        FilterItem(
          id: 'tags',
          title: '标签',
          type: FilterType.tagsMultiple,
          builder: (context, currentValue, onChanged) {
            final tags = _getAllMessageTags();
            final List<String> selectedTags = currentValue ?? [];
            return Wrap(
              spacing: 8,
              children: tags.map((tag) {
                final isSelected = selectedTags.contains(tag);
                return DSChip(
                  label: tag,
                  selected: isSelected,
                  onSelected: (selected) {
                    final newTags = List<String>.from(selectedTags);
                    if (selected) {
                      newTags.add(tag);
                    } else {
                      newTags.remove(tag);
                    }
                    onChanged(newTags.isEmpty ? null : newTags);
                  },
                );
              }).toList(),
            );
          },
          getBadge: (value) {
            if (value == null || (value as List).isEmpty) return null;
            final tags = value as List<String>;
            return tags.length == 1 ? tags[0] : '${tags.length}个标签';
          },
        ),
    ];
  }

  /// 获取所有消息标签（去重排序）
  List<String> _getAllMessageTags() {
    final tags = <String>{};
    for (final message in _controller.messages) {
      final messageTags = message.metadata?['tags'] as List?;
      if (messageTags != null) {
        for (final tag in messageTags) {
          if (tag is String) tags.add(tag);
        }
      }
    }
    return tags.toList()..sort();
  }

  /// 构建带日期分隔符的列表项（newest-first，配合 reverse ListView）
  List<dynamic> _buildItemsWithDateSeparators(List<Message> messages) {
    final result = <dynamic>[];
    DateTime? lastDate;

    for (int i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      final messageDate = DateTime(
        message.date.year,
        message.date.month,
        message.date.day,
      );

      // 如果是新的一天，先添加上一天的日期分隔符
      if (lastDate == null || !_isSameDay(lastDate, messageDate)) {
        if (lastDate != null) {
          result.add(lastDate);
        }
        lastDate = messageDate;
      }
      result.add(message);
    }

    // 添加最早一天的日期分隔符
    if (lastDate != null) {
      result.add(lastDate);
    }

    return result;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 构建已选工具栏
  Widget _buildSelectedToolsBar() {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.primary.mixWhite(0.9),
            border: Border(
              bottom: BorderSide(color: theme.primary.withValues(alpha: 0.3)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DsIcon(DsIconKind.gear, size: 16, color: theme.primaryText),
                  const SizedBox(width: 4),
                  Text(
                    '已选工具:',
                    style: DsTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryText,
                    ),
                  ),
                  const Spacer(),
                  DSButton(
                    label: 'agent_chat_clear'.tr,
                    icon: DsIconKind.close,
                    size: DSButtonSize.sm,
                    variant: DSButtonVariant.ghost,
                    onPressed: () async {
                      final confirm = await showDSDialog<bool>(
                        context: context,
                        theme: DSThemeBridge.resolve(context),
                        builder: (dialogContext) => DSThemeBridge(
                          child: Builder(
                            builder: (ctx) => DSDialog(
                              title: 'agent_chat_confirmClear'.tr,
                              message: 'agent_chat_confirmClearTools'.tr,
                              cancelText: 'agent_chat_cancel'.tr,
                              confirmText: 'agent_chat_confirm'.tr,
                              onConfirm: () =>
                                  Navigator.pop(dialogContext, true),
                              onCancel: () =>
                                  Navigator.pop(dialogContext, false),
                            ),
                          ),
                        ),
                      );
                      if (confirm == true) {
                        await _controller.clearSelectedTools();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _controller.selectedTools.map((tool) {
                  return DSChip(
                    label: tool['toolName'] ?? tool['toolId'] ?? '',
                    onDeleted: () async {
                      await _controller.removeToolFromConversation(tool['id']!);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
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

  /// 构建猜你想问横条
  Widget _buildSuggestedQuestionsBar() {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: theme.textSub.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          DsIcon(DsIconKind.star, size: 18, color: theme.primaryText),
          const SizedBox(width: 8),
          Text(
            '猜你想问',
            style: DsTypography.caption.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestedQuestions.length,
                itemBuilder: (context, index) {
                  final question = _suggestedQuestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: DSChip(
                        label: question,
                        icon: DsIconKind.chat,
                        onSelected: (_) {
                          // 点击问题填入输入框
                          _controller.setInputText(question);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 刷新按钮
          Pressable(
            onPressed: _isLoadingSuggestions
                ? null
                : _refreshSuggestedQuestions,
            semanticLabel: '刷新问题',
            builder: (context, states) => SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: _isLoadingSuggestions
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: DSLoadingDots(size: 5),
                      )
                    : DsIcon(
                        DsIconKind.refresh,
                        size: 20,
                        color: theme.primaryText,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final theme = DSThemeBridge.resolve(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DsIcon(DsIconKind.chat, size: 64, color: theme.textSub),
          const SizedBox(height: 16),
          Text(
            _currentAgent != null ? '开始新的对话' : '请先选择一个Agent',
            style: DsTypography.heading.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 8),
          if (_currentAgent != null)
            Text(
              '当前Agent: ${_currentAgent!.name}',
              style: DsTypography.body.copyWith(color: theme.textSub),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DSButton(
                label: 'agent_chat_selectAgent'.tr,
                icon: DsIconKind.bot,
                variant: DSButtonVariant.outline,
                onPressed: _showAgentSelector,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建新会话按钮
  Widget _buildNewSessionButton() {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _controller.isLastMessageSessionDivider
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.success.mixWhite(0.88),
                      borderRadius: theme.radii.sm,
                      border: Border.all(color: theme.success),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DsIcon(
                          DsIconKind.check,
                          size: 16,
                          color: theme.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '已开启新会话',
                          style: DsTypography.body.copyWith(
                            color: theme.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : DSButton(
                    label: 'agent_chat_createNewChat'.tr,
                    icon: DsIconKind.plus,
                    variant: DSButtonVariant.outline,
                    onPressed: () async {
                      // reverse 列表停留在底部，新分隔符出现后自动可见
                      await _controller.createNewSession();
                    },
                  ),
          ),
        );
      },
    );
  }

  /// 显示Token统计
  void _showTokenStats() {
    final totalTokens = _controller.getTotalTokens();
    final contextTokens = _controller.getContextTokens();

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) {
            final theme = DSThemeBridge.resolve(ctx);
            return JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'agent_chat_tokenStatistics'.tr,
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.md),
                  _buildStatRow(ctx, '总Token数', totalTokens.toString()),
                  SizedBox(height: theme.spacing.sm),
                  _buildStatRow(ctx, '上下文Token数', contextTokens.toString()),
                  SizedBox(height: theme.spacing.sm),
                  _buildStatRow(
                    ctx,
                    '上下文消息数',
                    '${_controller.contextMessageCount} 条',
                  ),
                  SizedBox(height: theme.spacing.md),
                  Text(
                    '注：Token数为估算值，实际消耗以API返回为准',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  SizedBox(height: theme.spacing.md),
                  DSButton(
                    label: 'agent_chat_close'.tr,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    final theme = DSThemeBridge.resolve(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: DsTypography.body.copyWith(color: theme.text)),
        Text(
          value,
          style: DsTypography.body.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
      ],
    );
  }

  /// 处理保存工具
  Future<void> _handleSaveTool(ChatMessage message) async {
    await showSaveToolDialog(
      context,
      message,
      _templateService,
      declaredTools: _controller.selectedTools,
    );
  }

  /// 处理重新执行工具
  Future<void> _handleRerunTool(String messageId) async {
    try {
      await _controller.rerunToolCall(messageId);
      if (mounted) {
        toastService.showToast('工具重新执行完成');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('重新执行工具失败: $e');
      }
    }
  }

  /// 处理重新执行单个步骤
  Future<void> _handleRerunStep(String messageId, int stepIndex) async {
    try {
      await _controller.rerunSingleStep(messageId, stepIndex);
      if (mounted) {
        toastService.showToast('步骤 ${stepIndex + 1} 重新执行完成');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('重新执行步骤失败: $e');
      }
    }
  }

  /// 顶栏更多操作气泡菜单
  Widget _buildMoreMenu(AppThemeData theme) {
    return DSPopover(
      width: 190,
      contentBuilder: (popoverContext, close) {
        final popoverTheme = DSThemeBridge.resolve(popoverContext);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppBarMenuAction(
              icon: DsIconKind.list,
              label: '多选模式',
              theme: popoverTheme,
              onTap: () {
                close();
                _toggleMultiSelectMode();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.gear,
              label: 'agent_chat_toolManagement'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                _openToolManagement();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.image,
              label: '朋友圈',
              theme: popoverTheme,
              onTap: () {
                close();
                _openMoments();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.sort,
              label: 'agent_chat_tokenStatistics'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                _showTokenStats();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.trash,
              label: 'agent_chat_confirmClear'.tr,
              theme: popoverTheme,
              danger: true,
              onTap: () {
                close();
                _showClearMessagesConfirm();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.gear,
              label: 'agent_chat_conversationSettings'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                _showSettings();
              },
            ),
          ],
        );
      },
      child: JellyBox(
        width: 36,
        height: 36,
        radius: theme.radii.md,
        color: theme.primary,
        child: Center(
          child: DsIcon(DsIconKind.more, size: 18, color: theme.onPrimary),
        ),
      ),
    );
  }

  /// 打开工具模板管理界面
  void _openToolTemplateManagement() {
    NavigationHelper.push(
      context,
      ToolTemplateScreen(
        templateService: _templateService,
        onUseTemplate: (template) {
          _controller.setSelectedToolTemplate(template);
        },
      ),
    );
  }

  /// 打开工具管理界面
  void _openToolManagement() {
    NavigationHelper.push(
      context,
      ToolManagementScreen(
        conversationId: widget.conversation.id,
        onAddToChat: (pluginId, toolId, config) async {
          await _controller.addToolToConversation(
            pluginId,
            toolId,
            config.title,
          );
          if (mounted) {
            toastService.showToast('已添加工具: ${config.title}');
          }
        },
      ),
    );
  }

  /// 打开 agent 朋友圈
  void _openMoments() {
    NavigationHelper.push(context, const MomentsScreen());
  }

  /// 显示设置对话框
  void _showSettings() {
    int? customContextCount = widget.conversation.contextMessageCount;

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => DSThemeBridge(
          child: Builder(
            builder: (ctx) {
              final theme = DSThemeBridge.resolve(ctx);
              return JellyBox(
                radius: theme.radii.xxl,
                padding: EdgeInsets.all(theme.spacing.xl),
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'agent_chat_conversationSettings'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.md),
                    Text(
                      '上下文消息数量',
                      style: DsTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    // 与原实现一致：单选项仅作展示（无切换回调）
                    Row(
                      children: [
                        DSRadio<int?>(
                          value: null,
                          groupValue: null,
                          onChanged: null,
                        ),
                        Expanded(
                          child: Text(
                            'agent_chat_useGlobalSettings'.tr,
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        DSRadio<int?>(
                          value: -1,
                          groupValue: null,
                          onChanged: null,
                        ),
                        Expanded(
                          child: Text(
                            'agent_chat_custom'.tr,
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (customContextCount != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: DSSlider(
                                value: (customContextCount! - 1) / 49,
                                onChanged: (value) {
                                  setDialogState(() {
                                    customContextCount =
                                        (value * 49).round() + 1;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '$customContextCount',
                                textAlign: TextAlign.center,
                                style: DsTypography.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: theme.spacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: 'agent_chat_cancel'.tr,
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ),
                        SizedBox(width: theme.spacing.md),
                        Expanded(
                          child: DSButton(
                            label: 'agent_chat_save'.tr,
                            onPressed: () async {
                              // 保存设置
                              final updatedConversation = widget.conversation
                                  .copyWith(
                                    contextMessageCount: customContextCount,
                                  );
                              await _controller.conversationService
                                  .updateConversation(updatedConversation);
                              if (mounted) {
                                Navigator.pop(dialogContext);
                                toastService.showToast('Settings saved');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 显示清空聊天记录确认对话框
  Future<void> _showClearMessagesConfirm() async {
    if (_controller.messages.isEmpty) {
      toastService.showToast('当前没有消息记录');
      return;
    }

    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) => DSDialog(
            title: 'agent_chat_confirmClear'.tr,
            message:
                '确定要清空当前会话的所有消息吗？\n\n'
                '当前共有 ${_controller.messages.length} 条消息，此操作不可恢复。',
            cancelText: 'agent_chat_cancel'.tr,
            confirmText: 'agent_chat_clear'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () => Navigator.pop(dialogContext, true),
            onCancel: () => Navigator.pop(dialogContext, false),
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        await _controller.clearAllMessages();
        if (mounted) {
          toastService.showToast('聊天记录已清空');
        }
      } catch (e) {
        if (mounted) {
          toastService.showToast('清空失败: $e');
        }
      }
    }
  }

  /// 显示Agent选择器（支持单/链模式选择）
  Future<void> _showAgentSelector() async {
    if (!mounted) return;

    // 检查当前配置状态
    final isCurrentlySingleMode = !_isChainMode && _currentAgent != null;
    final isCurrentlyChainMode =
        _isChainMode && _agentChain != null && _agentChain!.isNotEmpty;

    // 获取当前配置的agent显示文本
    String getCurrentAgentDisplayText() {
      if (isCurrentlySingleMode) {
        return '当前: ${_currentAgent!.name}';
      } else if (isCurrentlyChainMode) {
        final chainLength = _agentChain!.length;
        final agentNames = _agentChain!.map((a) => a.name).join(' → ');
        return '当前 ($chainLength个): $agentNames';
      }
      return '未配置';
    }

    // 显示模式选择对话框
    final mode = await showDSDialog<String>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) {
            final theme = DSThemeBridge.resolve(ctx);
            return JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '选择配置模式',
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.md),
                  _ModeOption(
                    icon: isCurrentlySingleMode
                        ? DsIconKind.check
                        : DsIconKind.bot,
                    accent: isCurrentlySingleMode ? theme.success : null,
                    title: '单 Agent 模式',
                    subtitle: isCurrentlySingleMode
                        ? '${getCurrentAgentDisplayText()} | 选择一个 Agent 进行对话'
                        : '选择一个 Agent 进行对话',
                    onTap: () => Navigator.pop(dialogContext, 'single'),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  _ModeOption(
                    icon: isCurrentlyChainMode
                        ? DsIconKind.check
                        : DsIconKind.layers,
                    accent: isCurrentlyChainMode ? theme.success : null,
                    title: 'Agent 链模式',
                    subtitle: isCurrentlyChainMode
                        ? '${getCurrentAgentDisplayText()} | 配置多个 Agent 顺序执行'
                        : '配置多个 Agent 顺序执行',
                    onTap: () => Navigator.pop(dialogContext, 'chain'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (mode == null || !mounted) return;

    if (mode == 'single') {
      await _showSingleAgentSelector();
    } else {
      await _showAgentChainConfig();
    }
  }

  /// 显示单 Agent 选择器
  Future<void> _showSingleAgentSelector() async {
    if (!mounted) return;

    final currentAgent = _currentAgent;
    final selectedAgents = currentAgent != null
        ? [
            {'id': currentAgent.id, 'name': currentAgent.name},
          ]
        : <Map<String, String>>[];

    await SmoothBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AgentListDrawer(
        selectedAgents: selectedAgents,
        allowMultipleSelection: false,
        onAgentSelected: (List<Map<String, String>> agents) async {
          if (agents.isEmpty) return;

          final selectedAgentId = agents.first['id'];
          if (selectedAgentId == null) return;

          try {
            await _controller.switchToSingleAgent(selectedAgentId);
            await _loadSuggestedQuestions();

            // 立即更新本地状态并刷新 UI
            if (mounted) {
              // 重新从 controller 同步状态
              _syncAgentStateFromController();
              // 强制刷新 UI
              setState(() {});
              toastService.showToast('已切换到 ${agents.first['name']}');
            }
          } catch (e) {
            if (mounted) {
              toastService.showToast('切换Agent失败: $e');
            }
          }
        },
      ),
    );
  }

  /// 显示 Agent 链配置对话框
  Future<void> _showAgentChainConfig() async {
    if (!mounted) return;

    await showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => AgentChainConfigDialog(
        initialChain: _controller.conversation.agentChain,
        onSave: (chain) async {
          try {
            await _controller.selectAgentChain(chain);

            // 立即更新本地状态并刷新 UI
            if (mounted) {
              // 重新从 controller 同步状态
              _syncAgentStateFromController();
              // 强制刷新 UI
              setState(() {});
              toastService.showToast('Agent 链配置成功');
            }
          } catch (e) {
            if (mounted) {
              toastService.showToast('配置失败: $e');
            }
          }
        },
      ),
    );
  }

  /// 显示工具调用 Agent 配置对话框（工具识别与工具执行两个阶段共用一个 agent）
  Future<void> _showToolAgentsConfig() async {
    if (!mounted) return;

    // 加载已保存的服务商列表
    List<Map<String, dynamic>> providers = [];
    try {
      final openAIPlugin =
          PluginManager.instance.getPlugin('openai') as OpenAIPlugin?;
      if (openAIPlugin != null) {
        final result = await openAIPlugin.useCase.getServiceProviders({});
        if (result.isSuccess && result.dataOrNull != null) {
          providers = result.dataOrNull!;
        }
      }
    } catch (e) {
      debugPrint('加载服务商列表失败: $e');
    }
    if (!mounted) return;

    final initialConfig = _controller.conversation.toolAgentConfig;
    String? selectedProviderId = initialConfig?.providerId;
    String? selectedModelId = initialConfig?.modelId;

    await showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => DSThemeBridge(
                  child: Builder(
                    builder: (ctx) {
                      final theme = DSThemeBridge.resolve(ctx);
                      final models = _getModelsForProvider(selectedProviderId);
                      return JellyBox(
                        radius: theme.radii.xxl,
                        padding: EdgeInsets.all(theme.spacing.xl),
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                DsIcon(
                                  DsIconKind.gear,
                                  color: theme.primaryText,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '工具调用 Agent 配置',
                                  style: DsTypography.title.copyWith(
                                    color: theme.text,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: theme.spacing.md),
                            Text(
                              '为工具调用的两个阶段（工具识别、生成调用代码）配置共用的专用 Agent。未配置时使用默认 prompt 替换当前 agent 的 system prompt。',
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 选择服务商
                            DSSelect<String>(
                              value: selectedProviderId,
                              hint: '请选择服务商',
                              items: providers
                                  .map(
                                    (p) => DSSelectItem<String>(
                                      value: p['id'] as String,
                                      label: p['label'] as String,
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedProviderId = value;
                                  selectedModelId = null;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // 选择模型
                            if (selectedProviderId != null)
                              DSSelect<String>(
                                value: selectedModelId,
                                hint: '请选择模型',
                                items: models
                                    .map(
                                      (m) => DSSelectItem<String>(
                                        value: m.id,
                                        label: m.name,
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setDialogState(() => selectedModelId = value);
                                },
                              ),
                            SizedBox(height: theme.spacing.lg),
                            Row(
                              children: [
                                if (initialConfig != null) ...[
                                  Expanded(
                                    child: DSButton(
                                      label: '清除配置',
                                      variant: DSButtonVariant.destructive,
                                      onPressed: () {
                                        _saveToolAgentConfig(null);
                                        Navigator.pop(dialogContext);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: DSButton(
                                    label: '取消',
                                    variant: DSButtonVariant.outline,
                                    onPressed:
                                        () => Navigator.pop(dialogContext),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DSButton(
                                    label: '保存',
                                    onPressed: () {
                                      if (selectedProviderId != null &&
                                          selectedModelId != null) {
                                        final model = models.firstWhere(
                                          (m) => m.id == selectedModelId,
                                        );
                                        _saveToolAgentConfig(
                                          ToolAgentConfig(
                                            providerId: selectedProviderId!,
                                            modelId: selectedModelId!,
                                            modelName: model.name,
                                          ),
                                        );
                                        Navigator.pop(dialogContext);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
          ),
    );
  }

  /// 获取指定服务商的所有模型
  List<LLMModel> _getModelsForProvider(String? providerId) {
    if (providerId == null) return [];
    for (final group in llmModelGroups) {
      if (group.id == providerId) {
        return group.models;
      }
    }
    return [];
  }

  /// 保存/清除工具调用专用 Agent 配置
  Future<void> _saveToolAgentConfig(ToolAgentConfig? config) async {
    try {
      await _controller.configureToolAgents(toolAgentConfig: config);
      if (mounted) {
        toastService.showToast('工具 Agent 配置成功');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('配置失败: $e');
      }
    }
  }

  /// 获取 Agent 显示文本
  String _getAgentDisplayText() {
    if (_isChainMode) {
      final chainLength = _agentChain?.length ?? 0;
      if (chainLength == 0) return '配置 Agent 链';
      return '$chainLength 个 Agent 链';
    } else {
      return _currentAgent?.name ?? 'agent_chat_selectAgent'.tr;
    }
  }

  /// 检查是否有有效的 Agent
  bool _hasValidAgent() {
    if (_isChainMode) {
      return _agentChain != null && _agentChain!.isNotEmpty;
    } else {
      return _currentAgent != null;
    }
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmation(String messageId) async {
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (ctx) => DSDialog(
            title: 'agent_chat_confirmDelete'.tr,
            message: 'agent_chat_confirmDeleteMessage'.tr,
            cancelText: 'agent_chat_cancel'.tr,
            confirmText: 'agent_chat_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () => Navigator.pop(dialogContext, true),
            onCancel: () => Navigator.pop(dialogContext, false),
          ),
        ),
      ),
    );

    if (confirm == true) {
      await _controller.deleteMessage(messageId);
    }
  }
}

/// 顶栏气泡菜单行
class _AppBarMenuAction extends StatelessWidget {
  const _AppBarMenuAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.danger = false,
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.text;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: pressed ? theme.surfaceAlt : null,
            borderRadius: theme.radii.sm,
          ),
          child: Row(
            children: [
              DsIcon(icon, size: 16, color: accent),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: DsTypography.caption.copyWith(color: accent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 配置模式选择行（单 Agent / Agent 链）
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final DsIconKind icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final effective = accent ?? theme.text;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.all(theme.spacing.md),
          decoration: BoxDecoration(
            color: pressed ? theme.surfaceAlt : null,
            borderRadius: theme.radii.lg,
            border: Border.all(color: theme.textSub.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              DsIcon(icon, size: 24, color: effective),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DsTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========== 前台服务回调 ==========

/// 语音通话前台服务启动回调
///
/// 必须是顶层函数，用于前台服务启动
@pragma('vm:entry-point')
void startVoiceCallTaskCallback() {
  FlutterForegroundTask.setTaskHandler(VoiceCallTaskHandler());
}

/// 语音通话前台服务任务处理器
class VoiceCallTaskHandler extends TaskHandler {
  static String notificationTitle = 'AI 语音通话';
  static String notificationText = '正在通话中...';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('🚀 语音通话前台服务已启动');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 定期任务（可选）
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('🗑️ 语音通话前台服务已销毁');
  }

  void onButtonPressed(String id) {
    debugPrint('🔔 通知按钮被点击: $id');
    // 发送事件到主应用
    switch (id) {
      case '0': // 第一个按钮
        FlutterForegroundTask.sendDataToTask({'event': 'pause_call'});
        break;
      case '1': // 第二个按钮
        FlutterForegroundTask.sendDataToTask({'event': 'end_call'});
        break;
    }
  }

  @override
  void onReceiveData(Object data) {
    // 接收来自主应用的数据
    if (data is Map<String, dynamic>) {
      final action = data['action'];
      if (action == 'update_notification') {
        notificationTitle = data['title'] ?? notificationTitle;
        notificationText = data['content'] ?? notificationText;

        FlutterForegroundTask.updateService(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
        );
      }
    }
  }
}

/// 新消息气泡入场动画：淡入 + 轻微上移/缩放。
/// 仅对"5 秒内到达"的新消息播放，历史消息滚动回看时不重播。
class _BubbleEntrance extends StatelessWidget {
  final Widget child;
  final bool isNew;
  final bool alignRight;

  const _BubbleEntrance({
    required this.child,
    required this.isNew,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    if (!isNew) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: Transform.scale(
              scale: 0.96 + 0.04 * t,
              alignment: alignRight
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// 会话分隔符（新会话标记），居中胶囊 + 两侧分割线
class _SessionDivider extends StatelessWidget {
  final ChatMessage message;

  const _SessionDivider({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.primary.withValues(alpha: 0.45),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primary.mixWhite(0.88),
                borderRadius: theme.radii.md,
                border: Border.all(color: theme.primary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsIcon(DsIconKind.plus, size: 16, color: theme.primaryText),
                  const SizedBox(width: 6),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.primary.withValues(alpha: 0.45),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}
