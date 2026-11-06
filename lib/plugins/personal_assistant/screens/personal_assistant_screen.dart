import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:grok_icon_study/grok_icon_study.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/core/services/grok_bot_style_controller.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/chat_screen.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/message_input.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/suggested_question_test_dialog.dart';
import 'package:aboutme/plugins/agent_chat/services/message_detail_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_service.dart';
import 'package:aboutme/plugins/openai/services/chat_assistant_service.dart';
import 'package:aboutme/plugins/personal_assistant/services/grok_bot_instance_service.dart';
import 'package:aboutme/plugins/personal_assistant/widgets/assistant_header.dart';
import 'package:aboutme/plugins/personal_assistant/widgets/assistant_hero.dart';
import 'package:aboutme/plugins/personal_assistant/widgets/assistant_message_list.dart';
import 'package:aboutme/plugins/personal_assistant/widgets/bot_style_sheet.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_status_panel_settings.dart';
import 'package:get/get.dart' hide Value;

/// 个人助手主视图：手绘风快捷速记入口，
/// 绑定内置「聊天助手」agent（[ChatAssistantService]）的临时会话；
/// 也作为果冻小屋主页的助手页签复用。
/// 顶栏维护多个 grokbot 实例（形象随机抽取、各自独立会话），
/// 点击图标切换会话，加号新增实例
///
/// 视图按功能拆分（仅装配，状态统一留在本类）：
/// - 顶栏/实例切换条/测试入口/新增按钮 → [AssistantHeader]
/// - 首页空态（大角色/徽章/灵感速记）→ [AssistantHero]
/// - 消息流/气泡/头像/消息更多选项 → [AssistantMessageList]
/// - 角色外观设置弹层（身形/墨色）→ [showBotStyleSheet]
class PersonalAssistantScreen extends StatefulWidget {
  const PersonalAssistantScreen({super.key});

  @override
  State<PersonalAssistantScreen> createState() =>
      _PersonalAssistantScreenState();
}

class _PersonalAssistantScreenState extends State<PersonalAssistantScreen> {
  /// grokbot 实例列表（含随机形象与各实例专属会话路由）
  final GrokBotInstanceService _botService = GrokBotInstanceService();

  /// 当前展示的实例 id
  String? _activeBotId;

  /// 各实例独立的会话控制器/消息服务（按实例 id 索引）
  final Map<String, ChatController> _botControllers = {};
  final Map<String, MessageService> _botMessageServices = {};

  /// 各实例初始化 Future（防止快速切换时重复初始化）
  final Map<String, Future<ChatController?>> _botFutures = {};

  /// 顶栏切换条中各实例的独立小角色（多个视图不能共享一个 character）
  final Map<String, GrokCharacter> _headerCharacters = {};

  /// 顶栏图标横滚控制器（新增实例后滚到最右）
  final ScrollController _botStripController = ScrollController();
  final ScrollController _scrollController = ScrollController();

  ChatController? get _controller =>
      _activeBotId == null ? null : _botControllers[_activeBotId];

  MessageService? get _messageService =>
      _activeBotId == null ? null : _botMessageServices[_activeBotId];

  /// 当前活动实例（未加载完成时为 null）
  GrokBotInstance? get _activeBot {
    final id = _activeBotId;
    if (id == null) return null;
    for (final bot in _botService.bots) {
      if (bot.id == id) return bot;
    }
    return null;
  }

  /// 用户头像/昵称（与状态面板共用），更换头像后消息头像同步刷新
  final JellyStatusPanelSettings _userSettings =
      JellyStatusPanelSettings.instance;

  /// 首页大角色与消息流头像各用独立实例：共享实例在 36px/176px 间切换时，
  /// 位置弹簧会按新宽度放大旧偏移（清空消息出现闪现/侧滑回归）。
  /// 两实例同步同一套表情状态：处理中 thinking / 完成 happy 片刻 /
  /// 待机（首页 curious 张望、头像 idle 眨眼），点击跳一下；
  /// 初始身形/墨色取自外观设置（启动时已加载完成），
  /// 实例列表加载后由 [_applyActiveBotStyle] 覆盖为活动 bot 的形象
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
    _botService.addListener(_onBotsChanged);
    _userSettings.load();
    _userSettings.addListener(_onUserSettingsChanged);
    _boot();
  }

  /// 加载实例列表：空则创建首个实例（沿用外观设置的身形/墨色），
  /// 默认激活首个并开始初始化其会话
  Future<void> _boot() async {
    var bots = await _botService.loadBots();
    if (bots.isEmpty) {
      final style = GrokBotStyleController();
      await _botService.addBot(
        id: GrokBotInstanceService.firstBotId,
        shapeId: style.shapeId,
        colorId: style.colorId,
      );
      bots = _botService.bots;
    }
    if (!mounted || bots.isEmpty) return;
    setState(() => _activeBotId ??= bots.first.id);
    _applyActiveBotStyle();
    _botFutures[bots.first.id] ??= _initializeFor(bots.first.id);
  }

  /// 实例列表/形象变化：同步活动 bot 形象并刷新顶栏
  void _onBotsChanged() {
    if (!mounted) return;
    _applyActiveBotStyle();
    setState(() {});
  }

  /// 头像/昵称变化：重建消息头像
  void _onUserSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onPluginLoaded(EventArgs args) {
    if (args is! Value<String> || args.value != 'agent_chat' || !mounted) {
      return;
    }
    setState(() {
      _resetController();
      _botFutures.clear();
      final activeId = _activeBotId;
      if (activeId != null) {
        _botFutures[activeId] = _initializeFor(activeId);
      }
    });
  }

  /// 帧末再释放旧 controller，避免 MessageInput 先行移除监听
  void _resetController() {
    final controllers = _botControllers.values.toList();
    final services = _botMessageServices.values.toList();
    _botControllers.clear();
    _botMessageServices.clear();
    for (final controller in controllers) {
      controller.removeListener(_onControllerChanged);
    }
    for (final service in services) {
      service.removeListener(_onControllerChanged);
    }
    if (controllers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
    }
  }

  /// 初始化指定实例的会话控制器：按实例专属路由取/建临时会话
  Future<ChatController?> _initializeFor(String botId) async {
    await ChatAssistantService.ensureBuiltinAgent();
    final bots = await _botService.loadBots();
    final agentChat = AgentChatPlugin.instance.conversationController;
    if (agentChat == null) return null;
    // 列表尚未含该 id（理论上仅首个实例竞态时）回退到第一个实例
    GrokBotInstance? bot;
    for (final item in bots) {
      if (item.id == botId) bot = item;
    }
    bot ??= bots.isNotEmpty ? bots.first : null;
    if (bot == null) return null;

    var conversation = agentChat.conversationService
        .getTemporaryConversationForRoute(bot.conversationRoute);
    conversation ??= await agentChat.conversationService
        .createTemporaryConversation(
          title: '聊天助手',
          routeName: bot.conversationRoute,
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
    // 页面已卸载，或实例在初始化期间被删除（快速新建后即删）：
    // 不写回缓存，直接释放
    // （bot 已在上方空检查保证非空，闭包捕获会失效类型提升，此处用 !）
    if (!mounted || !_botService.bots.any((item) => item.id == bot!.id)) {
      controller.dispose();
      return null;
    }
    _botMessageServices[bot.id] = messageService;
    _botControllers[bot.id] = controller;
    controller.addListener(_onControllerChanged);
    messageService.addListener(_onControllerChanged);
    _syncCharacterState(controller.isSending);
    return controller;
  }

  /// 切换活动实例：已初始化则直接展示，否则异步初始化
  void _switchBot(GrokBotInstance bot) {
    if (_activeBotId == bot.id) return;
    setState(() => _activeBotId = bot.id);
    _applyActiveBotStyle();
    _syncCharacterState(_botControllers[bot.id]?.isSending ?? false);
    _botFutures[bot.id] ??= _initializeFor(bot.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
  }

  /// 新增实例：形象随机抽取，顶栏滚到最右并切入新实例
  Future<void> _addBot() async {
    final bot = await _botService.addBot();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_botStripController.hasClients) return;
      _botStripController.animateTo(
        _botStripController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
    _switchBot(bot);
  }

  /// 删除当前活动实例（首个固定保留）：切换到相邻实例，
  /// 释放该实例的控制器/消息服务/顶栏角色，并删除其专属临时会话
  Future<void> _removeActiveBot() async {
    final bot = _activeBot;
    if (bot == null || bot.id == GrokBotInstanceService.firstBotId) return;
    final bots = _botService.bots;
    final index = bots.indexOf(bot);
    if (index < 0 || bots.length <= 1) return;
    // 优先切到左侧相邻实例，删的是首位时取右侧
    final fallback = bots[index > 0 ? index - 1 : index + 1];

    // 先切换活动实例，避免 UI 短暂指向已删实例
    setState(() => _activeBotId = fallback.id);
    _applyActiveBotStyle();
    _syncCharacterState(_botControllers[fallback.id]?.isSending ?? false);
    _botFutures[fallback.id] ??= _initializeFor(fallback.id);

    // 释放该实例的控制器/消息服务/顶栏角色
    final controller = _botControllers.remove(bot.id);
    final service = _botMessageServices.remove(bot.id);
    _botFutures.remove(bot.id);
    controller?.removeListener(_onControllerChanged);
    service?.removeListener(_onControllerChanged);
    _headerCharacters.remove(bot.id)?.dispose();
    if (controller != null) {
      // 帧末再释放旧 controller，避免 MessageInput 先行移除监听
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }

    // 删除该实例的专属临时会话（会话记录与消息一并清除）
    final conversationId = controller?.conversation.id;
    final agentChat = AgentChatPlugin.instance.conversationController;
    if (conversationId != null && agentChat != null) {
      try {
        await agentChat.conversationService.deleteConversation(
          conversationId,
        );
      } catch (e) {
        debugPrint('删除 grokbot 实例会话失败: $e');
      }
    }

    await _botService.removeBot(bot.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });
  }

  /// 应用活动实例的身形/墨色到各角色实例
  /// （setShape 走弹簧变形动画，setColor 每帧自绘即时生效）
  void _applyActiveBotStyle() {
    final bot = _activeBot;
    if (bot == null) return;
    _heroCharacter.setShape(bot.shapeId);
    _avatarCharacter.setShape(bot.shapeId);
    _heroCharacter.setColor(bot.colorId);
    _avatarCharacter.setColor(bot.colorId);
    final header = _headerCharacters[bot.id];
    header?.setShape(bot.shapeId);
    header?.setColor(bot.colorId);
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
      // 头像不用 thinking（三点眼）——与占位气泡的墨点加载动画重复；
      // 也不用 searching——该状态每 4-7s 自动转一圈，回复长时反复转圈
      _avatarCharacter.setStateName('listening');
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

  @override
  void dispose() {
    eventManager.unsubscribe('plugin_loaded', _onPluginLoaded);
    _botService.removeListener(_onBotsChanged);
    _userSettings.removeListener(_onUserSettingsChanged);
    _settleTimer?.cancel();
    for (final controller in _botControllers.values) {
      controller.removeListener(_onControllerChanged);
      controller.dispose();
    }
    for (final service in _botMessageServices.values) {
      service.removeListener(_onControllerChanged);
    }
    _scrollController.dispose();
    _botStripController.dispose();
    _heroCharacter.dispose();
    _avatarCharacter.dispose();
    for (final character in _headerCharacters.values) {
      character.dispose();
    }
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
    final activeColorId =
        _activeBot?.colorId ?? GrokBotStyleController().colorId;
    if (_heroCharacter.scheme != scheme) {
      // 主题明暗切换只换 scheme，墨色保留活动实例的选择
      _heroCharacter.setColor(activeColorId, scheme);
      _avatarCharacter.setColor(activeColorId, scheme);
    }

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
                  _buildHeader(theme, scheme),
                  Expanded(child: _buildChatArea(theme, bottomInset, scheme)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 顶栏：实例切换条 + 测试入口 + 新增实例按钮（装配见 [AssistantHeader]）
  Widget _buildHeader(AppThemeData theme, String scheme) {
    final controller = _controller;
    return AssistantHeader(
      theme: theme,
      scheme: scheme,
      bots: _botService.bots,
      activeBotId: _activeBotId,
      controller: controller,
      sending: controller?.isSending ?? false,
      questionTestOpen: _questionTestOpen,
      botStripController: _botStripController,
      headerCharacters: _headerCharacters,
      onSwitchBot: _switchBot,
      onAddBot: _addBot,
      onRemoveBot: _removeActiveBot,
      onOpenQuestionTest: _openQuestionTest,
      onOpenFullChat: _openFullChat,
    );
  }

  /// 对话区：活动实例已有缓存控制器时直接渲染（瞬时切换），
  /// 否则挂 FutureBuilder 等待初始化完成
  Widget _buildChatArea(AppThemeData theme, double bottomInset, String scheme) {
    final controller = _controller;
    if (controller != null) {
      return _buildChatContent(context, theme, bottomInset, controller);
    }
    return FutureBuilder<ChatController?>(
      future: _activeBotId == null ? null : _botFutures[_activeBotId],
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'screens_assistantInitFailed'.tr,
              style: DsTypography.body.copyWith(color: theme.textSub),
              textAlign: TextAlign.center,
            ),
          );
        }
        final live = snapshot.data;
        if (live == null) return const SizedBox.shrink();
        return _buildChatContent(context, theme, bottomInset, live);
      },
    );
  }

  Widget _buildChatContent(
    BuildContext context,
    AppThemeData theme,
    double bottomInset,
    ChatController controller,
  ) {
    final messages = controller.messages;
    // 切换实例时强制重建 MessageInput 的 State，避免其残留旧控制器的监听
    return KeyedSubtree(
      key: ValueKey('chat_${controller.conversation.id}'),
      child: Column(
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 首页空态（装配见 [AssistantHero]）
  Widget _buildHero(AppThemeData theme, ChatController controller) {
    return AssistantHero(
      theme: theme,
      controller: controller,
      heroCharacter: _heroCharacter,
      onOpenStyleSheet: _openBotStyleSheet,
    );
  }

  /// 消息流（装配见 [AssistantMessageList]）
  Widget _buildMessageList(
    AppThemeData theme,
    ChatController controller,
    List<ChatMessage> messages,
  ) {
    return AssistantMessageList(
      theme: theme,
      controller: controller,
      messages: messages,
      scrollController: _scrollController,
      avatarCharacter: _avatarCharacter,
      messageService: _messageService,
      userSettings: _userSettings,
    );
  }

  /// 首页角色右上角设置：选择当前活动实例的身形/墨色，
  /// 即时应用到各角色并持久化到实例配置（弹层见 [showBotStyleSheet]）
  void _openBotStyleSheet() {
    final bot = _activeBot;
    if (bot == null) return;
    showBotStyleSheet(context, botService: _botService, bot: bot);
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
}
