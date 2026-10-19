import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:grok_icon_study/grok_icon_study.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/chat_screen.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/message_bubble.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/message_input.dart';
import 'package:aboutme/plugins/agent_chat/services/message_detail_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_service.dart';
import 'package:aboutme/plugins/openai/services/chat_assistant_service.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/marquee_button_list_card.dart';
import 'package:aboutme/widgets/message_input/message_input.dart'
    show MessageInputQuickAction;
import 'package:get/get.dart' hide Value;

/// 聊天助手页签：手绘风快捷速记入口，
/// 绑定内置「聊天助手」agent（[ChatAssistantService]）的临时会话
class JellyAssistantTab extends StatefulWidget {
  const JellyAssistantTab({super.key});

  @override
  State<JellyAssistantTab> createState() => _JellyAssistantTabState();
}

class _JellyAssistantTabState extends State<JellyAssistantTab> {
  Future<ChatController?>? _controllerFuture;
  ChatController? _controller;
  MessageService? _messageService;
  final ScrollController _scrollController = ScrollController();

  /// 待机 curious / 处理中 thinking / 完成 happy 片刻，点击跳一下；
  /// 空会话作首页大角色，消息流中作最新 AI 消息的动态头像
  final GrokCharacter _character = GrokCharacter(
    mode: 'hold',
    state: 'curious',
  );
  bool _wasSending = false;
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    eventManager.subscribe('plugin_loaded', _onPluginLoaded);
  }

  void _onPluginLoaded(EventArgs args) {
    if (args is! Value<String> || args.value != 'agent_chat' || !mounted) {
      return;
    }
    setState(() {
      _resetController();
      _controllerFuture = null;
    });
  }

  /// 帧末再释放旧 controller，避免 MessageInput 先行移除监听
  void _resetController() {
    final controller = _controller;
    final messageService = _messageService;
    _controller = null;
    _messageService = null;
    controller?.removeListener(_onControllerChanged);
    messageService?.removeListener(_onControllerChanged);
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
  }

  Future<ChatController?> _initialize() async {
    await ChatAssistantService.ensureBuiltinAgent();
    final agentChat = AgentChatPlugin.instance.conversationController;
    if (agentChat == null) return null;

    var conversation = agentChat.conversationService
        .getTemporaryConversationForRoute(
          ChatAssistantService.conversationRoute,
        );
    conversation ??= await agentChat.conversationService
        .createTemporaryConversation(
          title: 'screens_assistantTitle'.tr,
          routeName: ChatAssistantService.conversationRoute,
          agentId: ChatAssistantService.builtinAgentId,
        );

    final plugin = AgentChatPlugin.instance;
    final messageService = MessageService(storage: plugin.storage);
    final controller = ChatController(
      conversation: conversation,
      messageService: messageService,
      conversationService: agentChat.conversationService,
      messageDetailService: MessageDetailService(storage: plugin.storage),
      templateService: ToolTemplateService(plugin.storage),
      getSettings: () => plugin.settings,
    );
    await controller.initialize();
    if (!mounted) {
      controller.dispose();
      return null;
    }
    _messageService = messageService;
    _controller = controller;
    controller.addListener(_onControllerChanged);
    messageService.addListener(_onControllerChanged);
    _syncCharacterState(controller.isSending);
    return controller;
  }

  /// 处理状态映射角色表情：处理中 thinking，完成先 happy 片刻，
  /// 再回到待机（空会话 curious 张望 / 消息流 idle 平静眨眼）
  void _syncCharacterState(bool sending) {
    _settleTimer?.cancel();
    _settleTimer = null;
    if (sending == _wasSending) return;
    _wasSending = sending;
    if (sending) {
      _character.setStateName('thinking');
      return;
    }
    _character.setStateName('happy');
    _settleTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _wasSending) return;
      final empty = _controller?.messages.isEmpty ?? true;
      _character.setStateName(empty ? 'curious' : 'idle');
    });
  }

  void _onControllerChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncCharacterState(_controller?.isSending ?? false);
      setState(() {});
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    eventManager.unsubscribe('plugin_loaded', _onPluginLoaded);
    _settleTimer?.cancel();
    _controller?.removeListener(_onControllerChanged);
    _messageService?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _scrollController.dispose();
    _character.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.fromPalette(DsThemeColorController().palette);
    // 输入区避让悬浮导航栏（padding）与键盘（viewInsets）取较大者
    final mq = MediaQuery.of(context);
    final bottomInset = math.max(mq.padding.bottom, mq.viewInsets.bottom);
    // setColor 不触发重建，角色每帧自绘，可在 build 中安全同步墨色
    final scheme = theme.isDark ? 'dark' : 'light';
    if (_character.scheme != scheme) {
      _character.setColor('black', scheme);
    }
    _controllerFuture ??= _initialize();

    return AppTheme(
      data: theme,
      child: Container(
        color: theme.background,
        child: SafeArea(
          bottom: false,
          // 宽屏下整体内容收拢为居中的中央列
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  _buildHeader(theme),
                  Expanded(
                    child: FutureBuilder<ChatController?>(
                      future: _controllerFuture,
                      builder: (context, snapshot) {
                        final controller = snapshot.data;
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'screens_assistantInitFailed'.tr,
                              style: DsTypography.body.copyWith(
                                color: theme.textSub,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        if (controller == null) return const SizedBox.shrink();
                        final messages = controller.messages;
                        return Column(
                          children: [
                            Expanded(
                              child: messages.isEmpty
                                  ? _buildHero(theme, controller)
                                  : _buildMessageList(
                                      theme,
                                      controller,
                                      messages,
                                    ),
                            ),
                            // removeBottom：外部已按导航栏/键盘避让，
                            // 去掉 MessageInput 内部 SafeArea 的底部 inset
                            MediaQuery.removePadding(
                              context: context,
                              removeBottom: true,
                              child: Padding(
                                padding: EdgeInsets.only(bottom: bottomInset),
                                child: MessageInput(
                                  controller: controller,
                                  showPanelStroke: true,
                                  dashedPanelStroke: true,
                                  trailingToolbarActions: [
                                    MessageInputQuickAction(
                                      icon: DsIconKind.trash,
                                      tooltip:
                                          'screens_assistantClearMessages'.tr,
                                      onPressed: () =>
                                          _confirmClearMessages(controller),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeData theme) {
    final controller = _controller;
    final sending = controller?.isSending ?? false;
    final subtitle = sending
        ? (controller?.typingStatusText ?? 'screens_assistantTyping'.tr)
        : 'screens_assistantSubtitle'.tr;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.lg,
        theme.spacing.sm,
        theme.spacing.sm,
        theme.spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'screens_assistantTitle'.tr,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                Text(
                  subtitle,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          DSIconButton(
            icon: DsIconKind.more,
            size: 38,
            color: theme.surface,
            tooltip: 'screens_assistantOpenFull'.tr,
            onPressed: () => _openFullChat(controller),
          ),
        ],
      ),
    );
  }

  void _openFullChat(ChatController? controller) {
    if (controller == null) return;
    NavigationHelper.push(
      context,
      ChatScreen(
        conversation: controller.conversation,
        storage: AgentChatPlugin.instance.storage,
        conversationService: controller.conversationService,
        getSettings: () => AgentChatPlugin.instance.settings,
      ),
    );
  }

  /// 工具栏「清空消息」：确认后清空当前会话，回到空会话首页
  Future<void> _confirmClearMessages(ChatController controller) async {
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: AppTheme.of(context),
      builder: (dialogContext) => DSDialog(
        title: 'screens_assistantClearMessages'.tr,
        message: 'screens_assistantClearConfirm'.tr,
        cancelText: 'app_cancel'.tr,
        confirmText: 'screens_assistantClearMessages'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () => Navigator.pop(dialogContext, true),
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    );
    if (confirm != true) return;
    try {
      await controller.clearAllMessages();
      if (mounted) toastService.showToast('screens_assistantCleared'.tr);
    } catch (e) {
      if (mounted) toastService.showToast('$e');
    }
  }

  Widget _buildHero(AppThemeData theme, ChatController controller) {
    return WiredDraw(
      // 视口最小高度撑满可用区：内容整体垂直居中，空间不足时仍可滚动
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.lg,
            vertical: theme.spacing.md,
          ),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _character.bounceOnce,
                        child: GrokCharacterView(
                          character: _character,
                          sizePx: 176,
                          pointerFollow: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(child: _buildBadge(theme, controller)),
                    const SizedBox(height: 16),
                    Text(
                      'screens_assistantGreeting'.tr,
                      style: DsTypography.heading.copyWith(color: theme.text),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'screens_assistantReady'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'screens_assistantIdeas'.tr,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                    ),
                    MarqueeButtonListCardWidget(
                      inline: true,
                      rows: 3,
                      // 手绘风：纸底 + 主题文字，去柔影（design.md §9.3）
                      cardColor: theme.surface,
                      textColor: theme.text,
                      showShadow: false,
                      items:
                          [
                                (
                                  Icons.schedule,
                                  'screens_assistantIdeaTodo'.tr,
                                  theme.primary,
                                ),
                                (
                                  Icons.savings,
                                  'screens_assistantIdeaBill'.tr,
                                  theme.warning,
                                ),
                                (
                                  Icons.menu_book,
                                  'screens_assistantIdeaDiary'.tr,
                                  theme.success,
                                ),
                                (
                                  Icons.water_drop,
                                  'screens_assistantIdeaCheckin'.tr,
                                  theme.danger,
                                ),
                                (
                                  Icons.event,
                                  'screens_assistantIdeaEvent'.tr,
                                  theme.primary,
                                ),
                                (
                                  Icons.alarm,
                                  'screens_assistantIdeaTimer'.tr,
                                  theme.warning,
                                ),
                              ]
                              .map(
                                (e) => MarqueeButtonItemData(
                                  label: e.$2,
                                  icon: e.$1,
                                  color: e.$3,
                                  payload: e.$2,
                                ),
                              )
                              .toList(),
                      onItemTap: (item, _) =>
                          controller.setInputText(item.label),
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

  Widget _buildBadge(AppThemeData theme, ChatController controller) {
    final working = controller.isSending;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(
            DsIconKind.sparkle,
            size: 14,
            color: working ? theme.primary : theme.textSub,
          ),
          const SizedBox(width: 6),
          Text(
            working
                ? 'screens_assistantWorking'.tr
                : 'screens_assistantBadgeIdle'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }

  /// 消息流：左右头像 + 气泡；最新 AI 消息的 bot 头像为 grok 动态表情，
  /// 随处理状态切换（thinking/happy/idle），历史 AI 消息为静态图标
  Widget _buildMessageList(
    AppThemeData theme,
    ChatController controller,
    List<ChatMessage> messages,
  ) {
    String? lastAiId;
    for (final message in messages) {
      if (!message.isUser && !message.isSessionDivider) lastAiId = message.id;
    }
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        theme.spacing.lg,
        theme.spacing.md,
        theme.spacing.lg,
        theme.spacing.md,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        if (message.isSessionDivider) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                message.content,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ),
          );
        }
        final isLast = index == messages.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: message.isUser
                ? [
                    Expanded(child: _buildUserBubble(theme, message)),
                    SizedBox(width: theme.spacing.sm),
                    _buildUserAvatar(theme),
                  ]
                : [
                    _buildBotAvatar(theme, live: message.id == lastAiId),
                    SizedBox(width: theme.spacing.sm),
                    Expanded(child: _buildAiBubble(theme, controller, message)),
                  ],
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar(AppThemeData theme) {
    return Container(
      width: 36,
      height: 36,
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        circle: true,
      ),
      child: Center(
        child: DsIcon(DsIconKind.user, size: 18, color: theme.primary),
      ),
    );
  }

  Widget _buildBotAvatar(AppThemeData theme, {required bool live}) {
    if (live) {
      return GestureDetector(
        onTap: _character.bounceOnce,
        child: SizedBox(
          width: 36,
          height: 36,
          child: GrokCharacterView(character: _character, sizePx: 36),
        ),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        circle: true,
      ),
      child: Center(
        child: DsIcon(DsIconKind.bot, size: 18, color: theme.textSub),
      ),
    );
  }

  Widget _buildUserBubble(AppThemeData theme, ChatMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.primary,
          radius: BorderRadius.circular(18),
        ),
        child: Text(
          message.content,
          style: DsTypography.body.copyWith(color: theme.onPrimary),
        ),
      ),
    );
  }

  Widget _buildAiBubble(
    AppThemeData theme,
    ChatController controller,
    ChatMessage message,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DsSketchPanel(
          theme: theme,
          hachure: false,
          radius: BorderRadius.circular(18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: AgentMessageContent(
            message: message,
            textColor: theme.text,
            messageService: _messageService,
            getAgentName: (_) => controller.currentAgent?.name,
          ),
        ),
      ),
    );
  }
}
