import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/widgets/lazy_indexed_stack.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/home_schedule_screen.dart';
import 'package:aboutme/screens/home_screen/home_screen.dart';
import 'package:aboutme/screens/profile_screen/profile_screen.dart';

import 'companion_controller.dart';
import 'widgets/jelly_bottom_nav.dart';
import 'widgets/jelly_assistant_tab.dart';
import 'widgets/jelly_companion_card.dart';
import 'widgets/jelly_live2d.dart';
import 'widgets/jelly_live2d_panel.dart';
import 'widgets/jelly_status_panel.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_detail_service.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_service.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/message_input.dart';

import 'package:get/get.dart' hide Value;

/// 果冻小屋主页（应用默认启动页）
///
/// 底部导航在五个页签间切换内容（不切换路由）：
/// 小屋（果冻风布局）/ 聊天助手（快捷速记）/ 日程（日期数据视图）/
/// 看板（固定布局网格）/ 我的（个人主页）。
///
/// 路由：/jelly_home
class JellyHomeScreen extends StatefulWidget {
  const JellyHomeScreen({super.key});

  @override
  State<JellyHomeScreen> createState() => _JellyHomeScreenState();
}

class _JellyHomeScreenState extends State<JellyHomeScreen> {
  int _tabIndex = 0;

  /// Live2D 聊天表单是否显示（由导航栏子栏左侧聊天按钮切换）
  bool _chatVisible = false;

  /// Live2D 底部资源面板开关：导航栏子栏图标写入，
  /// 小屋页签的 JellyLive2D 读取并渲染资源列表
  final ValueNotifier<JellyLive2dPanel?> _live2dPanel =
      ValueNotifier<JellyLive2dPanel?>(null);

  @override
  void initState() {
    super.initState();
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
  }

  @override
  void dispose() {
    _live2dPanel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 页签首次访问时构建，之后保留滚动位置、编辑进度等状态；
    // 页面内容铺满全屏，底部导航悬浮其上
    return JellyBottomNav(
      current: JellyTab.values[_tabIndex],
      onTap: (index) {
        setState(() => _tabIndex = index);
        // 离开小屋页签时收起资源面板（IndexedStack 保活，不会自动消失）
        if (index != 0) _live2dPanel.value = null;
      },
      chatActive: _chatVisible,
      onToggleChat: () {
        setState(() => _chatVisible = !_chatVisible);
        // 打开聊天表单时收起资源面板，两者都悬浮在页面底部
        if (_chatVisible) _live2dPanel.value = null;
      },
      live2dPanel: _live2dPanel,
      child: LazyIndexedStack(
        index: _tabIndex,
        builders: [
          (_) => HeroMode(
            enabled: _tabIndex == 0,
            child: _CottageTab(chatVisible: _chatVisible, panel: _live2dPanel),
          ),
          (_) => HeroMode(
            enabled: _tabIndex == 1,
            child: const JellyAssistantTab(),
          ),
          (_) => HeroMode(
            enabled: _tabIndex == 2,
            child: const HomeScheduleScreen(),
          ),
          (_) => HeroMode(
            enabled: _tabIndex == 3,
            child: const HomeScreen(asRoot: false),
          ),
          (_) => HeroMode(enabled: _tabIndex == 4, child: const ProfileScreen()),
        ],
      ),
    );
  }
}

/// 小屋页签：Live2D 角色全屏展示，
/// 底部可切换状态面板与右侧陪伴状态按钮，
/// 底部聊天表单按需切换显示。
class _CottageTab extends StatefulWidget {
  const _CottageTab({this.chatVisible = false, this.panel});

  /// Live2D 聊天表单是否显示
  final bool chatVisible;

  /// Live2D 底部资源面板开关（透传给 JellyLive2D 渲染资源列表）
  final ValueListenable<JellyLive2dPanel?>? panel;

  @override
  State<_CottageTab> createState() => _CottageTabState();
}

class _CottageTabState extends State<_CottageTab> {
  /// 小智的陪伴数值（情绪/精力/好感度/陪伴天数），挂载时读取并结算
  final CompanionController _companion = CompanionController();
  String? _live2dMessage;
  int _live2dReaction = 0;
  String? _pendingLive2dReply;
  bool _pendingLive2dStreaming = false;
  bool _live2dReplyFrameScheduled = false;

  @override
  void initState() {
    super.initState();
    _companion.load();
  }

  @override
  void dispose() {
    _companion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 演示页自带浅色主题（跟随当前主题色板）
    final theme = AppThemeData.fromPalette(DsThemeColorController().palette);
    // 聊天表单避让底部：悬浮导航栏（padding）与键盘（viewInsets）取较大者
    final mq = MediaQuery.of(context);
    final bottomInset = math.max(mq.padding.bottom, mq.viewInsets.bottom);
    final topInset = mq.padding.top;

    return AppTheme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemStatusBarContrastEnforced: false,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.backgroundAlt, theme.background],
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 背景铺到系统状态栏后方；角色和气泡仍避让顶部安全区。
                // 角色可用高度通过 topInset 扣除顶部预留高度，
                // 点击命中角色本体（hit area）算一次陪伴互动。
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: JellyLive2D(
                    fill: false,
                    fitContainer: true,
                    topInset: topInset,
                    panel: widget.panel,
                    statusPanel: JellyStatusPanel(controller: _companion),
                    message: _live2dMessage,
                    reaction: _live2dReaction,
                    initialModel: modelDefinitionForArchive(
                      Live2DPlugin.instance.selected,
                    ),
                    typingInterval: Live2DPlugin.instance.bubbleTypingInterval,
                    onTap: (hitAreaId, _) {
                      if (hitAreaId != null) {
                        _companion.recordInteraction();
                      }
                    },
                  ),
                ),
                if (topInset > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: topInset + 16,
                    child: const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x99000000), Colors.transparent],
                            stops: [0.6, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                // 左右两侧悬浮图标按钮（assets/jelly_icons 素材）：
                // 右列首项为陪伴状态入口，其余为玩法占位；
                // 顶部避让系统状态栏
                Align(
                  alignment: Alignment.topLeft,
                  child: _buildSideButtonColumn(
                    theme,
                    topOffset: topInset + theme.spacing.sm,
                    buttons: const [
                      (
                        asset: 'assets/jelly_icons/envelope.webp',
                        label: '信封（占位）',
                        onTap: null,
                      ),
                      (
                        asset: 'assets/jelly_icons/shop.webp',
                        label: '商店（占位）',
                        onTap: null,
                      ),
                      (
                        asset: 'assets/jelly_icons/speech_bubble.webp',
                        label: '气泡（占位）',
                        onTap: null,
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: _buildSideButtonColumn(
                    theme,
                    topOffset: topInset + theme.spacing.sm,
                    buttons: [
                      (
                        asset: 'assets/jelly_icons/heart.webp',
                        label: '查看陪伴状态',
                        onTap: _showCompanionDialog,
                      ),
                      const (
                        asset: 'assets/jelly_icons/gift.webp',
                        label: '礼物（占位）',
                        onTap: null,
                      ),
                      const (
                        asset: 'assets/jelly_icons/trophy.webp',
                        label: '奖杯（占位）',
                        onTap: null,
                      ),
                    ],
                  ),
                ),
                // 聊天表单（导航栏聊天按钮切换显示；保持挂载以维持会话监听）
                Positioned(
                  left: theme.spacing.lg,
                  right: theme.spacing.lg,
                  bottom: bottomInset + theme.spacing.sm,
                  child: Visibility(
                    visible: widget.chatVisible,
                    maintainState: true,
                    maintainAnimation: true,
                    child: Live2DChatInput(onReply: _scheduleLive2dReply),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 左右两侧悬浮图标按钮列（jelly_icons 素材），自上而下排列
  Widget _buildSideButtonColumn(
    AppThemeData theme, {
    required double topOffset,
    required List<({String asset, String label, VoidCallback? onTap})> buttons,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topOffset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.spacing.sm,
        children: [
          for (final button in buttons)
            _buildSideButton(
              theme,
              iconAsset: button.asset,
              semanticLabel: button.label,
              onTap: button.onTap ?? () {},
            ),
        ],
      ),
    );
  }

  /// 两侧悬浮信息按钮：圆形果冻质感小钮（jelly_icons 图片图标）
  Widget _buildSideButton(
    AppThemeData theme, {
    required String iconAsset,
    required String semanticLabel,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
      child: Pressable(
        onPressed: onTap,
        semanticLabel: semanticLabel,
        builder: (context, states) => Opacity(
          opacity: states.contains(WidgetState.pressed) ? 0.85 : 1,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.surface.withValues(alpha: 0.72),
              border: Border.all(color: theme.stroke),
              boxShadow: theme.shadows.soft,
            ),
            child: Center(
              child: Image.asset(
                iconAsset,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 右侧按钮弹窗：陪伴状态卡（原底部状态卡的内容）
  Future<void> _showCompanionDialog() {
    final companionName = Live2DPlugin.instance.selected?.name ?? '小智';
    return showDSDialog<void>(
      context: context,
      builder: (dialogContext) => DSDialog(
        title: '$companionName状态',
        content: JellyCompanionCard(controller: _companion),
      ),
    );
  }

  void _scheduleLive2dReply(String reply, bool streaming) {
    _pendingLive2dReply = reply;
    _pendingLive2dStreaming = streaming;
    if (_live2dReplyFrameScheduled) return;
    _live2dReplyFrameScheduled = true;
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      debugPrint(
        '[Live2DChat] deferred reply update during ${SchedulerBinding.instance.schedulerPhase.name}',
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _live2dReplyFrameScheduled = false;
      final pending = _pendingLive2dReply;
      _pendingLive2dReply = null;
      if (!mounted || pending == null) return;
      setState(() {
        _live2dMessage = pending;
        if (!_pendingLive2dStreaming) _live2dReaction++;
      });
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}

class Live2DChatInput extends StatefulWidget {
  const Live2DChatInput({super.key, required this.onReply});

  final void Function(String reply, bool streaming) onReply;

  @override
  State<Live2DChatInput> createState() => _Live2DChatInputState();
}

class _Live2DChatInputState extends State<Live2DChatInput> {
  Future<ChatController?>? _controllerFuture;
  String? _initializedKey;
  ChatController? _controller;
  MessageService? _messageService;
  String? _lastReplyId;
  String? _lastReplyContent;

  @override
  void initState() {
    super.initState();
    eventManager.subscribe('plugin_loaded', _onPluginLoaded);
  }

  void _onPluginLoaded(EventArgs args) {
    if (args is! Value<String> || args.value != 'agent_chat' || !mounted) {
      return;
    }
    debugPrint(
      '[ChatClear] plugin_loaded(agent_chat) -> reset controller future',
    );
    setState(() {
      _initializedKey = null;
      _controllerFuture = null;
    });
  }

  Future<ChatController?> _initialize() async {
    final archive = Live2DPlugin.instance.selected;
    final agentId = archive?.agentId;
    final agentChat = AgentChatPlugin.instance.conversationController;
    if (archive == null || agentId == null || agentChat == null) return null;

    var conversation = agentChat.conversationService
        .getTemporaryConversationForRoute('live2d:${archive.id}');
    conversation ??= await agentChat.conversationService
        .createTemporaryConversation(
          title: archive.name,
          routeName: 'live2d:${archive.id}',
          agentId: agentId,
        );
    if (!conversation.groups.contains(Live2DPlugin.fixedGroup)) {
      conversation = conversation.copyWith(
        groups: [...conversation.groups, Live2DPlugin.fixedGroup],
      );
      await agentChat.conversationService.updateConversation(conversation);
    }

    final messageService = MessageService(
      storage: Live2DPlugin.instance.storage,
    );
    final controller = ChatController(
      conversation: conversation,
      messageService: messageService,
      conversationService: agentChat.conversationService,
      messageDetailService: MessageDetailService(
        storage: Live2DPlugin.instance.storage,
      ),
      templateService: ToolTemplateService(Live2DPlugin.instance.storage),
      getSettings: () => AgentChatPlugin.instance.settings,
    );
    await controller.initialize();
    _messageService = messageService;
    _controller = controller;
    debugPrint(
      '[ChatClear] Live2D controller initialized #${identityHashCode(controller)} key=$_currentKey',
    );
    messageService.addListener(_onMessagesChanged);
    return controller;
  }

  void _onMessagesChanged() {
    final messages = _messageService?.currentMessages ?? const [];
    final latestUserIndex = messages.lastIndexWhere(
      (message) => message.isUser,
    );
    if (latestUserIndex < 0) return;
    for (var index = messages.length - 1; index > latestUserIndex; index--) {
      final message = messages[index];
      if (message.isUser) continue;
      final reply = Live2DPlugin.cleanReply(message.content);
      if (message.isGenerating) {
        final display = reply.isEmpty ? '...' : reply;
        if (display != _lastReplyContent && mounted) {
          _lastReplyContent = display;
          widget.onReply(display, true);
        }
        break;
      }
      if (reply.isEmpty || message.id == _lastReplyId) continue;
      _lastReplyId = message.id;
      _lastReplyContent = reply;
      if (mounted) widget.onReply(reply, false);
      unawaited(Live2DPlugin.instance.speakReply(reply));
      break;
    }
  }

  @override
  void dispose() {
    eventManager.unsubscribe('plugin_loaded', _onPluginLoaded);
    _messageService?.removeListener(_onMessagesChanged);
    _controller?.dispose();
    super.dispose();
  }

  /// 选中的 Live2D 存档或其绑定的 Agent 变化后需要重建会话
  String get _currentKey {
    final archive = Live2DPlugin.instance.selected;
    return '${archive?.id}:${archive?.agentId}';
  }

  void _resetController() {
    final controller = _controller;
    final messageService = _messageService;
    _controller = null;
    _messageService = null;
    _lastReplyId = null;
    _lastReplyContent = null;
    debugPrint(
      '[ChatClear] reset controller old=#${identityHashCode(controller)}',
    );
    messageService?.removeListener(_onMessagesChanged);
    // 帧末再释放旧 controller，避免仍在显示它的 MessageInput 先行移除监听
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _currentKey;
    if (_controllerFuture == null || _initializedKey != key) {
      _initializedKey = key;
      _resetController();
      _controllerFuture = _initialize();
    }
    return FutureBuilder<ChatController?>(
      future: _controllerFuture,
      builder: (context, snapshot) {
        final controller = snapshot.data;
        if (snapshot.hasError) return Text('screens_live2dInitFailed'.tr);
        if (controller == null) return const SizedBox.shrink();
        // 磨砂背景（模糊 + 半透明白着色，圆角 28）
        //
        // removeBottom：外层 Positioned 已避让悬浮导航栏/键盘，
        // 去掉 MessageInput 内部 SafeArea 消费的底部 inset，避免双重避让
        // 抬高输入框；输入框高度随内容（多行文本 / 命令面板 / 附件状态）自动伸缩
        return MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0x59FFFFFF),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: MessageInput(controller: controller),
              ),
            ),
          ),
        );
      },
    );
  }
}
