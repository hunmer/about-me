import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
import 'package:aboutme/plugins/openai/widgets/agent_list_drawer.dart';
import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'components/message_bubble.dart';
import 'components/message_input.dart';
import 'components/save_tool_dialog.dart';
import 'components/agent_chain_config_dialog.dart';
import 'components/tool_agents_config_dialog.dart';
import 'package:aboutme/plugins/agent_chat/screens/tool_management_screen/tool_management_screen.dart';
import 'package:aboutme/plugins/openai/moments/screens/moments_screen.dart';
import 'package:aboutme/plugins/agent_chat/screens/tool_template_screen/tool_template_screen.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _uiHandlersRegistered = false;
  int _lastMessageCount = 0; // 记录上次的消息数量
  bool _autoReadEnabled = false; // 自动朗读开关
  String? _selectedTTSServiceId; // 选择的TTS服务ID
  String? _lastReadMessageId; // 上次朗读的消息ID
  String? _lastVoiceCallMessageId; // 上次发送到语音通话的消息ID（防止重复处理）
  bool _isListReady = false; // 列表是否准备好显示（滚动到底部后）

  // Agent 选择状态 - 由 ChatScreen 自己管理
  AIAgent? _currentAgent;
  List<AIAgent>? _agentChain; // 使用 AIAgent 列表而不是 AgentChainNode
  bool _isChainMode = false;

  // 猜你想问相关
  List<String> _suggestedQuestions = [];
  bool _isLoadingSuggestions = false;
  final SuggestedQuestionsService _suggestionsService =
      SuggestedQuestionsService();

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
          // 先初始化消息计数，避免 _onControllerChanged 中 wasEmpty 触发额外滚动
          _lastMessageCount = _controller.messages.length;

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

          // 延迟等待 Markdown 等复杂组件渲染完成后再滚动和显示
          // Markdown 渲染会导致内容高度变化，需要等待高度稳定
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _scrollToBottom();
              // 滚动完成后显示列表
              setState(() {
                _isListReady = true;
              });
            }
          });
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
      final currentMessageCount = _controller.messages.length;
      final hasNewMessage = currentMessageCount > _lastMessageCount;
      final wasEmpty = _lastMessageCount == 0;
      _lastMessageCount = currentMessageCount;

      // 使用 addPostFrameCallback 避免在构建过程中调用 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
          // 在以下情况自动滚动到底部（需等 setState 重建后的下一帧，
          // 否则 maxScrollExtent 还是旧值导致滚不到真正底部）：
          // 1. 有新消息添加时
          // 2. 从空消息列表变为有消息时（首次进入或清空后）
          if (hasNewMessage || wasEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _scrollToBottom(animated: true);
            });
          }
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
        builder:
            (context) => VoiceCallScreen(
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

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _voiceCallManager?.dispose();
    _aiMessageStreamController.close();
    _controller.removeListener(_onControllerChanged);
    _controller.messageService.removeListener(_onControllerChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _AgentChatAppBar(
        title: widget.conversation.title,
        isTyping:
            _controller.isSending ||
            _controller.isThinking ||
            _controller.alivenessFlushActive,
        typingStatusText: _controller.typingStatusText,
        isChainMode: _isChainMode,
        agentDisplayText: _getAgentDisplayText(),
        hasValidAgent: _hasValidAgent(),
        autoReadEnabled: _autoReadEnabled,
        showVoiceActions: _currentAgent != null,
        onTitleTap: _showAgentSelector,
        onToolAgentsConfig: _showToolAgentsConfig,
        onToolTemplateManagement: _openToolTemplateManagement,
        onTTSSettings: _openTTSSettings,
        onVoiceCall: _openVoiceCall,
        onToolManagement: _openToolManagement,
        onMoments: _openMoments,
        onTokenStats: _showTokenStats,
        onClearMessages: _showClearMessagesConfirm,
        onSettings: _showSettings,
      ),
      body:
          _controller.isLoading
              ? const Center(child: DSThemeBridge(child: DSLoadingDots()))
              : Column(
                children: [
                  // 已选工具列表
                  if (_controller.selectedTools.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final theme = DSThemeBridge.resolve(context);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primary.mixWhite(0.9),
                            border: Border(
                              bottom: BorderSide(
                                color: theme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  DsIcon(
                                    DsIconKind.gear,
                                    size: 16,
                                    color: theme.primaryText,
                                  ),
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
                                        builder:
                                            (dialogContext) => DSThemeBridge(
                                              child: Builder(
                                                builder:
                                                    (ctx) => DSDialog(
                                                      title:
                                                          'agent_chat_confirmClear'
                                                              .tr,
                                                      message:
                                                          'agent_chat_confirmClearTools'
                                                              .tr,
                                                      cancelText:
                                                          'agent_chat_cancel'
                                                              .tr,
                                                      confirmText:
                                                          'agent_chat_confirm'
                                                              .tr,
                                                      onConfirm:
                                                          () => Navigator.pop(
                                                            dialogContext,
                                                            true,
                                                          ),
                                                      onCancel:
                                                          () => Navigator.pop(
                                                            dialogContext,
                                                            false,
                                                          ),
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
                                children:
                                    _controller.selectedTools.map((tool) {
                                      return DSChip(
                                        label:
                                            tool['toolName'] ??
                                            tool['toolId'] ??
                                            '',
                                        onDeleted: () async {
                                          await _controller
                                              .removeToolFromConversation(
                                                tool['id']!,
                                              );
                                        },
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  // 猜你想问区域
                  if (_suggestedQuestions.isNotEmpty &&
                      _controller.messages.isEmpty)
                    _buildSuggestedQuestionsBar(),

                  // 消息列表
                  Expanded(
                    child:
                        _controller.messages.isEmpty
                            ? _buildEmptyState()
                            : AnimatedOpacity(
                              opacity: _isListReady ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 150),
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount:
                                    _controller.messages.length +
                                    1, // +1 for new session button
                                physics: const ClampingScrollPhysics(),
                                itemBuilder: (context, index) {
                                  // 最后一个 item 显示新会话按钮
                                  if (index == _controller.messages.length) {
                                    return _buildNewSessionButton();
                                  }

                                  final message = _controller.messages[index];

                                  return _BubbleEntrance(
                                    isNew: message.timestamp.isAfter(
                                      DateTime.now().subtract(
                                        const Duration(seconds: 5),
                                      ),
                                    ),
                                    alignRight: message.isUser,
                                    child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: MessageBubble(
                                      message: message,
                                      hasAgent: _currentAgent != null,
                                      storage: widget.storage,
                                      onEdit: (messageId, newContent) async {
                                        await _controller.editMessage(
                                          messageId,
                                          newContent,
                                        );
                                      },
                                      onDelete: (messageId) async {
                                        await _showDeleteConfirmation(
                                          messageId,
                                        );
                                      },
                                      onRegenerate: (messageId) async {
                                        await _controller.regenerateResponse(
                                          messageId,
                                        );
                                      },
                                      onSaveTool: (message) async {
                                        await _handleSaveTool(message);
                                      },
                                      onRerunTool: (messageId) async {
                                        await _handleRerunTool(messageId);
                                      },
                                      onRerunStep: (
                                        messageId,
                                        stepIndex,
                                      ) async {
                                        await _handleRerunStep(
                                          messageId,
                                          stepIndex,
                                        );
                                      },
                                      onExecuteTemplate: (
                                        messageId,
                                        templateId,
                                      ) async {
                                        final template = _controller
                                            .templateService
                                            ?.getTemplateById(templateId);
                                        if (template != null) {
                                          await _controller
                                              .executeMatchedTemplate(
                                                messageId,
                                                template,
                                              );
                                        }
                                      },
                                      getTemplateName: (templateId) {
                                        return _controller.templateService
                                            ?.getTemplateById(templateId)
                                            ?.name;
                                      },
                                      getAgentName: (agentId) {
                                        // 从 agent 链中查找
                                        if (_isChainMode &&
                                            _agentChain != null) {
                                          final agent = _agentChain!.firstWhere(
                                            (a) => a.id == agentId,
                                            orElse: () => _agentChain!.first,
                                          );
                                          return agent.name;
                                        }
                                        return _currentAgent?.name;
                                      },
                                      onCancel:
                                          message.isGenerating
                                              ? () =>
                                                  _controller.cancelSending()
                                              : null,
                                      messageService:
                                          _controller.messageService,
                                    ),
                                    ),
                                  );
                                },
                              ),
                            ),
                  ),

                  // 输入框
                  MessageInput(controller: _controller),
                ],
              ),
    );
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
            onPressed:
                _isLoadingSuggestions ? null : _refreshSuggestedQuestions,
            semanticLabel: '刷新问题',
            builder:
                (context, states) => SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child:
                        _isLoadingSuggestions
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
            child:
                _controller.isLastMessageSessionDivider
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
                        await _controller.createNewSession();
                        // 自动滚动到底部
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom();
                        });
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
      builder:
          (dialogContext) => DSThemeBridge(
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
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
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
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => DSThemeBridge(
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
                              style: DsTypography.title.copyWith(
                                color: theme.text,
                              ),
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
                                    onPressed:
                                        () => Navigator.pop(dialogContext),
                                  ),
                                ),
                                SizedBox(width: theme.spacing.md),
                                Expanded(
                                  child: DSButton(
                                    label: 'agent_chat_save'.tr,
                                    onPressed: () async {
                                      // 保存设置
                                      final updatedConversation = widget
                                          .conversation
                                          .copyWith(
                                            contextMessageCount:
                                                customContextCount,
                                          );
                                      await _controller.conversationService
                                          .updateConversation(
                                            updatedConversation,
                                          );
                                      if (mounted) {
                                        Navigator.pop(dialogContext);
                                        toastService.showToast(
                                          'Settings saved',
                                        );
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
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (ctx) => DSDialog(
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
      builder:
          (dialogContext) => DSThemeBridge(
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
                        icon:
                            isCurrentlySingleMode
                                ? DsIconKind.check
                                : DsIconKind.bot,
                        accent: isCurrentlySingleMode ? theme.success : null,
                        title: '单 Agent 模式',
                        subtitle:
                            isCurrentlySingleMode
                                ? '${getCurrentAgentDisplayText()} | 选择一个 Agent 进行对话'
                                : '选择一个 Agent 进行对话',
                        onTap: () => Navigator.pop(dialogContext, 'single'),
                      ),
                      SizedBox(height: theme.spacing.sm),
                      _ModeOption(
                        icon:
                            isCurrentlyChainMode
                                ? DsIconKind.check
                                : DsIconKind.layers,
                        accent: isCurrentlyChainMode ? theme.success : null,
                        title: 'Agent 链模式',
                        subtitle:
                            isCurrentlyChainMode
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
    final selectedAgents =
        currentAgent != null
            ? [
              {'id': currentAgent.id, 'name': currentAgent.name},
            ]
            : <Map<String, String>>[];

    await SmoothBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => AgentListDrawer(
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
      builder:
          (context) => AgentChainConfigDialog(
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

  /// 显示工具调用 Agent 配置对话框
  Future<void> _showToolAgentsConfig() async {
    if (!mounted) return;

    await showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => ToolAgentsConfigDialog(
            initialToolDetectionConfig:
                _controller.conversation.toolDetectionConfig,
            initialToolExecutionConfig:
                _controller.conversation.toolExecutionConfig,
            onSave: (toolDetectionConfig, toolExecutionConfig) async {
              try {
                await _controller.configureToolAgents(
                  toolDetectionConfig: toolDetectionConfig,
                  toolExecutionConfig: toolExecutionConfig,
                );
                if (mounted) {
                  toastService.showToast('工具 Agent 配置成功');
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
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (ctx) => DSDialog(
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

// ========== 自绘顶栏与对话框辅助 ==========

/// 聊天页顶部栏（自绘果冻风，替代 Material AppBar）
class _AgentChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isTyping;

  /// 输入中状态的具体文案（如"🔍 正在识别需要的工具..."），null 时显示"正在输入中…"
  final String? typingStatusText;
  final bool isChainMode;
  final String agentDisplayText;
  final bool hasValidAgent;
  final bool autoReadEnabled;
  final bool showVoiceActions;
  final VoidCallback onTitleTap;
  final VoidCallback onToolAgentsConfig;
  final VoidCallback onToolTemplateManagement;
  final VoidCallback onTTSSettings;
  final VoidCallback onVoiceCall;
  final VoidCallback onToolManagement;
  final VoidCallback onMoments;
  final VoidCallback onTokenStats;
  final VoidCallback onClearMessages;
  final VoidCallback onSettings;

  const _AgentChatAppBar({
    required this.title,
    this.isTyping = false,
    this.typingStatusText,
    required this.isChainMode,
    required this.agentDisplayText,
    required this.hasValidAgent,
    required this.autoReadEnabled,
    required this.showVoiceActions,
    required this.onTitleTap,
    required this.onToolAgentsConfig,
    required this.onToolTemplateManagement,
    required this.onTTSSettings,
    required this.onVoiceCall,
    required this.onToolManagement,
    required this.onMoments,
    required this.onTokenStats,
    required this.onClearMessages,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Material(
            color: theme.surface,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      DSIconButton(
                        icon: DsIconKind.chevronLeft,
                        size: 40,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    Expanded(
                      child: Pressable(
                        onPressed: onTitleTap,
                        semanticLabel: title,
                        builder:
                            (context, states) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DsTypography.heading.copyWith(
                                    color: theme.text,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 正在输入状态（替代 agent 信息显示）
                                    if (isTyping) ...[
                                      SizedBox(
                                        width: 8,
                                        height: 8,
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
                                          typingStatusText ?? '正在输入中…',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: DsTypography.caption.copyWith(
                                            color: theme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                    // 显示模式图标
                                    DsIcon(
                                      isChainMode
                                          ? DsIconKind.layers
                                          : DsIconKind.bot,
                                      size: 14,
                                      color: theme.textSub,
                                    ),
                                    const SizedBox(width: 4),
                                    // 显示 agent 信息
                                    Flexible(
                                      child: Text(
                                        agentDisplayText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: DsTypography.caption.copyWith(
                                          color:
                                              hasValidAgent
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
                                      size: 16,
                                      color: theme.textSub,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      ),
                    ),
                    // 工具调用 Agent 配置按钮
                    DSIconButton(
                      icon: DsIconKind.gear,
                      size: 40,
                      color: theme.surfaceAlt,
                      iconColor: theme.textSub,
                      onPressed: onToolAgentsConfig,
                      tooltip: '工具调用 Agent',
                    ),
                    // 工具模板管理按钮
                    DSIconButton(
                      icon: DsIconKind.clipboard,
                      size: 40,
                      color: theme.surfaceAlt,
                      iconColor: theme.textSub,
                      onPressed: onToolTemplateManagement,
                      tooltip: '工具模板',
                    ),
                    // 语音相关按钮（仅在设置了 Agent 时显示）
                    if (showVoiceActions) ...[
                      // 自动朗读设置按钮
                      DSIconButton(
                        icon: DsIconKind.bell,
                        size: 40,
                        color:
                            autoReadEnabled ? theme.primary : theme.surfaceAlt,
                        iconColor:
                            autoReadEnabled ? theme.onPrimary : theme.textSub,
                        onPressed: onTTSSettings,
                        tooltip: '语音播报设置',
                      ),
                      // 语音通话按钮
                      DSIconButton(
                        icon: DsIconKind.mic,
                        size: 40,
                        onPressed: onVoiceCall,
                        tooltip: '语音通话',
                      ),
                    ],
                    _buildMenu(context, theme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 更多操作气泡菜单
  Widget _buildMenu(BuildContext context, AppThemeData theme) {
    return DSPopover(
      width: 190,
      contentBuilder: (popoverContext, close) {
        final popoverTheme = DSThemeBridge.resolve(popoverContext);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppBarMenuAction(
              icon: DsIconKind.gear,
              label: 'agent_chat_toolManagement'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                onToolManagement();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.image,
              label: '朋友圈',
              theme: popoverTheme,
              onTap: () {
                close();
                onMoments();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.sort,
              label: 'agent_chat_tokenStatistics'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                onTokenStats();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.trash,
              label: 'agent_chat_confirmClear'.tr,
              theme: popoverTheme,
              danger: true,
              onTap: () {
                close();
                onClearMessages();
              },
            ),
            _AppBarMenuAction(
              icon: DsIconKind.gear,
              label: 'agent_chat_conversationSettings'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                onSettings();
              },
            ),
          ],
        );
      },
      child: JellyBox(
        width: 40,
        height: 40,
        radius: theme.radii.md,
        color: theme.primary,
        child: Center(
          child: DsIcon(DsIconKind.more, size: 20, color: theme.onPrimary),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
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
