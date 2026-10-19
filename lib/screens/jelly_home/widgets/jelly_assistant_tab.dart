import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
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
import 'package:get/get.dart' hide Value;

/// 聊天助手页签（底部导航第 2 个页签）
///
/// 手绘纸墨风的快捷速记入口（自 ai_assistant_voice_chat_ui.html 转译）：
/// 无消息时展示墨线光球 + 问候语 + 热门想法卡；有消息后切换为消息流；
/// 绑定内置「聊天助手」agent（见 [ChatAssistantService]）的临时会话，
/// 把用户一句话描述快速变成插件工具调用并记录。
class JellyAssistantTab extends StatefulWidget {
  const JellyAssistantTab({super.key});

  @override
  State<JellyAssistantTab> createState() => _JellyAssistantTabState();
}

class _JellyAssistantTabState extends State<JellyAssistantTab>
    with SingleTickerProviderStateMixin {
  Future<ChatController?>? _controllerFuture;
  ChatController? _controller;
  MessageService? _messageService;

  final ScrollController _scrollController = ScrollController();

  /// 光球呼吸动画（持续运行，发送中光芒更长）
  late final AnimationController _orbAnimation;

  @override
  void initState() {
    super.initState();
    _orbAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
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

  /// 释放旧 controller（帧末 dispose，避免 MessageInput 先行移除监听）
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
        .getTemporaryConversationForRoute(ChatAssistantService.conversationRoute);
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
    return controller;
  }

  void _onControllerChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    _controller?.removeListener(_onControllerChanged);
    _messageService?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _scrollController.dispose();
    _orbAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 与小屋页签同款：跟随当前主题色板的轻量主题
    final theme = AppThemeData.fromPalette(DsThemeColorController().palette);
    // 输入区避让悬浮导航栏（padding）与键盘（viewInsets）取较大者
    final mq = MediaQuery.of(context);
    final bottomInset = math.max(mq.padding.bottom, mq.viewInsets.bottom);
    _controllerFuture ??= _initialize();

    return AppTheme(
      data: theme,
      child: Container(
        color: theme.background,
        child: SafeArea(
          bottom: false,
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
                              : _buildMessageList(theme, controller, messages),
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
                              showQuickActions: false,
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
    );
  }

  /// 顶栏：标题 + 副标题（工作状态），尾部跳转完整聊天页
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

  /// 打开完整聊天页（搜索 / 消息操作 / agent 切换等完整能力）
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

  /// 空会话首页：墨线光球 + 状态徽章 + 问候 + 热门想法卡
  Widget _buildHero(AppThemeData theme, ChatController controller) {
    return WiredDraw(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          theme.spacing.lg,
          theme.spacing.md,
          theme.spacing.lg,
          theme.spacing.md,
        ),
        children: [
          const SizedBox(height: 12),
          Center(
            child: _AssistantOrb(
              animation: _orbAnimation,
              active: controller.isSending,
              size: 168,
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
            style: DsTypography.caption.copyWith(color: theme.textSub),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'screens_assistantIdeas'.tr,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: [
              for (final (icon, labelKey) in _ideaPresets)
                _buildIdeaCard(theme, icon, labelKey, controller),
            ],
          ),
        ],
      ),
    );
  }

  /// 预设想法卡：(图标, 文案键)；文案本身即发给 agent 的提示
  static const List<(DsIconKind, String)> _ideaPresets = [
    (DsIconKind.clock, 'screens_assistantIdeaTodo'),
    (DsIconKind.piggy, 'screens_assistantIdeaBill'),
    (DsIconKind.book, 'screens_assistantIdeaDiary'),
    (DsIconKind.drop, 'screens_assistantIdeaCheckin'),
  ];

  /// 状态徽章胶囊：小助手 / 正在处理
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
            working ? 'screens_assistantWorking'.tr : 'screens_assistantBadgeIdle'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }

  /// 热门想法卡：点击把预设提示填入输入框
  Widget _buildIdeaCard(
    AppThemeData theme,
    DsIconKind icon,
    String labelKey,
    ChatController controller,
  ) {
    return Pressable(
      onPressed: () => controller.setInputText(labelKey.tr),
      semanticLabel: labelKey.tr,
      builder: (context, states) => Opacity(
        opacity: states.contains(WidgetState.pressed) ? 0.85 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: theme.surface,
            radius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: theme.hatch,
                  radius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: DsIcon(icon, size: 18, color: theme.primary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                labelKey.tr,
                style: DsTypography.caption.copyWith(color: theme.text),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 消息流：用户右气泡（主题色实底）/ AI 左气泡（复用 AgentMessageContent，
  /// 支持 markdown 与工具调用步骤展示）；聊天流不做便签化（design.md §11.4）
  Widget _buildMessageList(
    AppThemeData theme,
    ChatController controller,
    List<ChatMessage> messages,
  ) {
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
          child: message.isUser
              ? _buildUserBubble(theme, message)
              : _buildAiBubble(theme, controller, message),
        );
      },
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

/// 墨线光球：rough 圆盘（排线淡彩）+ 呼吸光芒 + 中心点；
/// [active]（发送中）时光芒更长，呼应 HTML 版的聆听脉冲
class _AssistantOrb extends StatelessWidget {
  const _AssistantOrb({
    required this.animation,
    required this.active,
    this.size = 168,
  });

  final Animation<double> animation;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => CustomPaint(
        size: Size.square(size),
        painter: _AssistantOrbPainter(
          drawConfig: theme.wired.drawConfig,
          inkColor: theme.ink,
          hatchColor: theme.hatch,
          rayColor: theme.primary,
          t: animation.value,
          active: active,
          progress: WiredDrawTransition.progressOf(context),
        ),
      ),
    );
  }
}

class _AssistantOrbPainter extends CustomPainter {
  _AssistantOrbPainter({
    required this.drawConfig,
    required this.inkColor,
    required this.hatchColor,
    required this.rayColor,
    required this.t,
    required this.active,
    this.progress,
  });

  final DrawConfig drawConfig;
  final Color inkColor;
  final Color hatchColor;
  final Color rayColor;

  /// 呼吸相位（0~1 循环）
  final double t;
  final bool active;

  /// 环境描画动画（WiredDraw 入场）；null = 立即全画
  final Animation<double>? progress;

  static const int _rayCount = 16;

  Paint _ink(Color color, double width) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = color;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final enter = progress?.value ?? 1.0;

    // 中心圆盘：墨线描边 + 排线淡彩
    final discDiameter = size.width * 0.64;
    final discConfig = drawConfig.copyWith(seed: 21);
    discConfig.randomizer.reset();
    final discGen = Generator(
      discConfig,
      HachureFiller(
        FillerConfig.build(
          drawConfig: discConfig,
          hachureGap: 7,
          fillWeight: 1.2,
        ),
      ),
    );
    RoughDrawing(
      discGen.circle(cx, cy, discDiameter),
      _ink(inkColor, 2),
      _ink(hatchColor, 1.2),
    ).paint(canvas, progress: enter, pressure: 0);

    // 放射光芒：圆盘外圈向外的短墨线，长度随呼吸相位起伏
    final amplitude = active ? 1.4 : 1.0;
    final innerRadius = discDiameter / 2 + size.width * 0.02;
    final rayPaint = _ink(rayColor, 1.6);
    for (var i = 0; i < _rayCount; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / _rayCount;
      final phase = i * 1.7;
      final breathe =
          (0.6 + 0.4 * math.sin(2 * math.pi * t + phase)) * amplitude;
      final outer = innerRadius + size.width * 0.08 * breathe;
      final config = drawConfig.copyWith(seed: 40 + i);
      config.randomizer.reset();
      final gen = Generator(config, NoFiller());
      RoughDrawing(
        gen.line(
          cx + math.cos(angle) * innerRadius,
          cy + math.sin(angle) * innerRadius,
          cx + math.cos(angle) * outer,
          cy + math.sin(angle) * outer,
        ),
        rayPaint,
        rayPaint,
      ).paint(canvas, progress: enter, pressure: 0);
    }

    // 中心实心点 + 右上两颗小星星（对应原版星芒点缀）
    final coreConfig = drawConfig.copyWith(seed: 77);
    coreConfig.randomizer.reset();
    final coreGen = Generator(
      coreConfig,
      SolidFiller(),
    );
    RoughDrawing(
      coreGen.circle(cx, cy, size.width * 0.09),
      _ink(rayColor, 1.4),
      _ink(rayColor, 1.4),
    ).paint(canvas, progress: enter, pressure: 0);

    for (final (sx, sy, s) in [
      (size.width * 0.78, size.height * 0.24, size.width * 0.045),
      (size.width * 0.22, size.height * 0.72, size.width * 0.032),
    ]) {
      final config = drawConfig.copyWith(seed: 90 + s.toInt());
      config.randomizer.reset();
      final gen = Generator(config, NoFiller());
      final star = _ink(rayColor, 1.4);
      RoughDrawing(
        gen.line(sx - s, sy, sx + s, sy),
        star,
        star,
      ).paint(canvas, progress: enter, pressure: 0);
      RoughDrawing(
        gen.line(sx, sy - s, sx, sy + s),
        star,
        star,
      ).paint(canvas, progress: enter, pressure: 0);
    }
  }

  @override
  bool shouldRepaint(_AssistantOrbPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.active != active ||
      oldDelegate.drawConfig != drawConfig ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.hatchColor != hatchColor ||
      oldDelegate.rayColor != rayColor ||
      oldDelegate.progress != progress;
}
