import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:grok_icon_study/grok_icon_study.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/core/services/grok_bot_style_controller.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/chat_screen.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/message_bubble.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/message_input.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/suggested_question_test_dialog.dart';
import 'package:aboutme/plugins/agent_chat/screens/conversation_list_screen/test_conversation_list_screen.dart';
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

  final GrokBotStyleController _botStyle = GrokBotStyleController();

  /// 首页大角色与消息流头像各用独立实例：共享实例在 36px/176px 间切换时，
  /// 位置弹簧会按新宽度放大旧偏移（清空消息出现闪现/侧滑回归）。
  /// 两实例同步同一套表情状态：处理中 thinking / 完成 happy 片刻 /
  /// 待机（首页 curious 张望、头像 idle 眨眼），点击跳一下；
  /// 身形/墨色取自外观设置（启动时已加载完成）
  final GrokCharacter _heroCharacter = GrokCharacter(
    mode: 'hold',
    state: 'curious',
    shapeName: GrokBotStyleController().shapeId,
    colorId: GrokBotStyleController().colorId,
  );
  final GrokCharacter _avatarCharacter = GrokCharacter(
    mode: 'hold',
    state: 'idle',
    shapeName: GrokBotStyleController().shapeId,
    colorId: GrokBotStyleController().colorId,
  );
  bool _wasSending = false;
  bool _questionTestOpen = false;
  bool _controllerUpdateScheduled = false;
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    eventManager.subscribe('plugin_loaded', _onPluginLoaded);
    _botStyle.addListener(_onBotStyleChanged);
  }

  /// 外观设置变化：同步应用到两个角色实例
  /// （setShape 走弹簧变形动画，setColor 每帧自绘即时生效）
  void _onBotStyleChanged() {
    _heroCharacter.setShape(_botStyle.shapeId);
    _avatarCharacter.setShape(_botStyle.shapeId);
    _heroCharacter.setColor(_botStyle.colorId);
    _avatarCharacter.setColor(_botStyle.colorId);
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
          title: '聊天助手',
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
  /// 再回到各自待机态（首页 curious 张望 / 头像 idle 平静眨眼）
  void _syncCharacterState(bool sending) {
    _settleTimer?.cancel();
    _settleTimer = null;
    if (sending == _wasSending) return;
    _wasSending = sending;
    if (sending) {
      _heroCharacter.setStateName('thinking');
      // 头像不用 thinking（三点眼）——与占位气泡的墨点加载动画重复
      _avatarCharacter.setStateName('searching');
      return;
    }
    _heroCharacter.setStateName('happy');
    _avatarCharacter.setStateName('happy');
    _settleTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _wasSending) return;
      _heroCharacter.setStateName('curious');
      _avatarCharacter.setStateName('idle');
    });
  }

  void _onControllerChanged() {
    if (!mounted || _controllerUpdateScheduled) return;
    _controllerUpdateScheduled = true;
    // 主动请求下一帧，并合并同一帧内的流式更新；仅注册帧末回调不会触发重绘。
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _controllerUpdateScheduled = false;
      if (!mounted) return;
      _syncCharacterState(_controller?.isSending ?? false);
      setState(() {});
      // 等消息内容完成布局后再读取最新的滚动范围。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
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

  /// 气泡最大高度：屏幕高的 80%，超长内容在气泡内滚动
  double get _bubbleMaxHeight => MediaQuery.sizeOf(context).height * 0.8;

  @override
  void dispose() {
    eventManager.unsubscribe('plugin_loaded', _onPluginLoaded);
    _botStyle.removeListener(_onBotStyleChanged);
    _settleTimer?.cancel();
    _controller?.removeListener(_onControllerChanged);
    _messageService?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _scrollController.dispose();
    _heroCharacter.dispose();
    _avatarCharacter.dispose();
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
    if (_heroCharacter.scheme != scheme) {
      // 主题明暗切换只换 scheme，墨色保留外观设置的选择
      _heroCharacter.setColor(_botStyle.colorId, scheme);
      _avatarCharacter.setColor(_botStyle.colorId, scheme);
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
                                padding: EdgeInsets.fromLTRB(
                                  theme.spacing.lg,
                                  theme.spacing.sm,
                                  theme.spacing.lg,
                                  bottomInset,
                                ),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.lg,
        theme.spacing.sm,
        theme.spacing.sm,
        theme.spacing.sm,
      ),
      child: Row(
        children: [
          const Spacer(),
          if (kDebugMode)
            DSPopover(
              width: 190,
              contentBuilder: (popoverContext, close) {
                final popoverTheme = DSThemeBridge.resolve(popoverContext);
                // 与原测试按钮一致的禁用条件：发送中/思考中/测试运行中不可开启新测试
                final testDisabled =
                    controller == null ||
                    sending ||
                    controller.isThinking ||
                    _questionTestOpen;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TestMenuAction(
                      icon: DsIconKind.science,
                      label: '选择测试',
                      theme: popoverTheme,
                      enabled: !testDisabled,
                      onTap: () {
                        close();
                        _openQuestionTest(controller!);
                      },
                    ),
                    _TestMenuAction(
                      icon: DsIconKind.list,
                      label: '查看测试会话记录',
                      theme: popoverTheme,
                      onTap: () {
                        close();
                        NavigationHelper.push(
                          context,
                          const TestConversationListScreen(),
                        );
                      },
                    ),
                  ],
                );
              },
              // DSPopover 接管点击，child 不能用会吞手势的按钮
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_outlined, size: 18, color: theme.textSub),
                    const SizedBox(width: 4),
                    Text(
                      '测试',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
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

  Future<void> _openQuestionTest(ChatController controller) async {
    setState(() => _questionTestOpen = true);
    try {
      await showSuggestedQuestionTestDialog(context, controller);
    } finally {
      if (mounted) setState(() => _questionTestOpen = false);
    }
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
    // 同头像：预置渲染宽度，避免挂载首帧几何错位
    _heroCharacter.updateRenderWidth(176);
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
                      child: SizedBox(
                        width: 176,
                        height: 176,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: _heroCharacter.bounceOnce,
                                child: GrokCharacterView(
                                  character: _heroCharacter,
                                  sizePx: 176,
                                  pointerFollow: true,
                                ),
                              ),
                            ),
                            // 右上角外观设置入口（身形/墨色）
                            Positioned(
                              top: -2,
                              right: -2,
                              child: GestureDetector(
                                onTap: _openBotStyleSheet,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: dsSketchDecoration(
                                    theme: theme,
                                    fillColor: theme.surface,
                                    circle: true,
                                  ),
                                  child: Center(
                                    child: DsIcon(
                                      DsIconKind.gear,
                                      size: 15,
                                      color: theme.textSub,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  /// 首页角色右上角设置：选择身形/墨色，即时应用到当前角色并持久化
  void _openBotStyleSheet() {
    final theme = DSThemeBridge.resolve(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        final sheetTheme = DSThemeBridge.resolve(sheetContext);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            child: AnimatedBuilder(
              animation: _botStyle,
              builder: (context, _) {
                final selectedShape = _botStyle.shapeId;
                final selectedColor = _botStyle.colorId;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: sheetTheme.textSub.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '角色外观',
                        style: DsTypography.title.copyWith(
                          color: sheetTheme.text,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '外形',
                        style: DsTypography.caption.copyWith(
                          color: sheetTheme.textSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in GrokGeometry.shapes.entries)
                            _buildSheetShapeChip(
                              sheetTheme,
                              id: entry.key,
                              label: entry.value.label,
                              selected: entry.key == selectedShape,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '颜色',
                        style: DsTypography.caption.copyWith(
                          color: sheetTheme.textSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final entry in GrokGeometry.palette.entries)
                            _buildSheetColorDot(
                              sheetTheme,
                              id: entry.key,
                              colorValue: entry.value.$1,
                              selected: entry.key == selectedColor,
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
      },
    );
  }

  Widget _buildSheetShapeChip(
    AppThemeData theme, {
    required String id,
    required String label,
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () => _botStyle.setShape(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: selected ? theme.primary : theme.surface,
          radius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: DsTypography.caption.copyWith(
            color: selected ? theme.onPrimary : theme.textSub,
          ),
        ),
      ),
    );
  }

  Widget _buildSheetColorDot(
    AppThemeData theme, {
    required String id,
    required int colorValue,
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () => _botStyle.setColor(id),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? theme.primary : theme.textSub,
            width: selected ? 3 : 1.5,
          ),
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
    // AI 尚未产出文本（发送中且最后一条是用户消息）时末尾显示占位气泡；
    // 占位期间动态头像挂到占位行，上一条 AI 消息转静态图标
    final showPlaceholder =
        controller.isSending && (messages.isEmpty || messages.last.isUser);
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        theme.spacing.lg,
        theme.spacing.md,
        theme.spacing.lg,
        theme.spacing.md,
      ),
      itemCount: messages.length + (showPlaceholder ? 1 : 0),
      itemBuilder: (context, index) {
        final isLast = index == messages.length + (showPlaceholder ? 1 : 0) - 1;
        if (showPlaceholder && index == messages.length) {
          return _buildPlaceholderRow(theme, controller, isLast: isLast);
        }
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
                    _buildBotAvatar(
                      theme,
                      live: !showPlaceholder && message.id == lastAiId,
                    ),
                    SizedBox(width: theme.spacing.sm),
                    Expanded(child: _buildAiBubble(theme, controller, message)),
                  ],
          ),
        );
      },
    );
  }

  /// AI 处理中的占位气泡：动态 grok 头像（thinking）+ 当前执行步骤的 muted 小文本
  Widget _buildPlaceholderRow(
    AppThemeData theme,
    ChatController controller, {
    required bool isLast,
  }) {
    final stepText =
        controller.typingStatusText ?? 'screens_assistantTyping'.tr;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBotAvatar(theme, live: true),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                child: DsSketchPanel(
                  theme: theme,
                  hachure: false,
                  radius: BorderRadius.circular(18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DSLoadingDots(size: 6, color: theme.textSub),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          stepText,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
      // 视图在 postFrame 才同步渲染宽度；新 AI 消息到达时头像重挂载，
      // 预置宽度避免首帧按旧宽度绘制导致「慢半拍」出场
      _avatarCharacter.updateRenderWidth(36);
      return GestureDetector(
        onTap: _avatarCharacter.bounceOnce,
        child: SizedBox(
          width: 36,
          height: 36,
          child: GrokCharacterView(character: _avatarCharacter, sizePx: 36),
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
        constraints: BoxConstraints(maxWidth: 460, maxHeight: _bubbleMaxHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.primary,
          radius: BorderRadius.circular(18),
        ),
        // 超长内容（粘贴大段文本）在气泡内滚动，不撑满整屏
        child: SingleChildScrollView(
          child: Text(
            message.content,
            style: DsTypography.body.copyWith(color: theme.onPrimary),
          ),
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
        constraints: BoxConstraints(maxWidth: 520, maxHeight: _bubbleMaxHeight),
        child: DsSketchPanel(
          theme: theme,
          hachure: false,
          radius: BorderRadius.circular(18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: SingleChildScrollView(
            child: AgentMessageContent(
              message: message,
              textColor: theme.text,
              messageService: _messageService,
              getAgentName: (_) => controller.currentAgent?.name,
            ),
          ),
        ),
      ),
    );
  }
}

/// 测试弹出气泡的菜单项（结构与工具管理页 _ToolMenuAction 一致，支持禁用态）
class _TestMenuAction extends StatelessWidget {
  const _TestMenuAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.enabled = true,
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? theme.text : theme.textSub;
    return Pressable(
      onPressed: enabled ? onTap : null,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: pressed && enabled ? theme.surfaceAlt : null,
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
