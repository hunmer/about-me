import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/home_schedule_screen.dart';
import 'package:aboutme/screens/home_screen/home_screen.dart';
import 'package:aboutme/screens/settings_screen/settings_screen.dart';

import 'companion_controller.dart';
import 'widgets/jelly_bottom_nav.dart';
import 'widgets/jelly_companion_card.dart';
import 'widgets/jelly_live2d.dart';
import 'widgets/jelly_profile_card.dart';
import 'widgets/jelly_stat_card.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_detail_service.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_service.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/message_input.dart';

/// 果冻小屋主页（应用默认启动页）
///
/// 底部导航在四个页签间切换内容（不切换路由）：
/// 小屋（果冻风布局）/ 日程（日期数据视图）/ 看板（固定布局网格）/ 我的（设置）。
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

  @override
  Widget build(BuildContext context) {
    // IndexedStack 保活各页签状态（滚动位置、编辑进度等）；
    // 页面内容铺满全屏，底部导航悬浮其上
    return JellyBottomNav(
      current: JellyTab.values[_tabIndex],
      onTap: (index) => setState(() => _tabIndex = index),
      chatActive: _chatVisible,
      onToggleChat: () => setState(() => _chatVisible = !_chatVisible),
      child: IndexedStack(
        index: _tabIndex,
        children: [
          HeroMode(
            enabled: _tabIndex == 0,
            child: _CottageTab(chatVisible: _chatVisible),
          ),
          HeroMode(enabled: _tabIndex == 1, child: const HomeScheduleScreen()),
          HeroMode(
            enabled: _tabIndex == 2,
            child: const HomeScreen(asRoot: false),
          ),
          HeroMode(enabled: _tabIndex == 3, child: const SettingsScreen()),
        ],
      ),
    );
  }
}

/// 小屋页签：Live2D 角色全屏展示，
/// 左右两侧悬浮信息按钮（弹窗展示资料/陪伴状态），
/// 底部聊天表单按需切换显示。
class _CottageTab extends StatefulWidget {
  const _CottageTab({this.chatVisible = false});

  /// Live2D 聊天表单是否显示
  final bool chatVisible;

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

    return AppTheme(
      data: theme,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.backgroundAlt, theme.background],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Live2D 角色全屏铺满，点击命中角色本体（hit area）算一次陪伴互动
              JellyLive2D(
                fill: false,
                fitContainer: false,
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
              // 左侧按钮：资料 + 统计（原顶部卡片信息改为弹窗展示）
              Align(
                alignment: Alignment.centerLeft,
                child: _buildSideButton(
                  theme,
                  icon: DsIconKind.user,
                  semanticLabel: '查看资料与统计',
                  onTap: () => _showProfileDialog(theme),
                ),
              ),
              // 右侧按钮：陪伴状态（原状态卡信息改为弹窗展示）
              Align(
                alignment: Alignment.centerRight,
                child: _buildSideButton(
                  theme,
                  icon: DsIconKind.bot,
                  semanticLabel: '查看陪伴状态',
                  onTap: _showCompanionDialog,
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
    );
  }

  /// 两侧悬浮信息按钮：圆形果冻质感小钮
  Widget _buildSideButton(
    AppThemeData theme, {
    required DsIconKind icon,
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
              child: DsIcon(icon, size: 20, color: theme.primaryText),
            ),
          ),
        ),
      ),
    );
  }

  /// 左侧按钮弹窗：资料卡 + 三张统计卡（原顶部四卡的内容）
  Future<void> _showProfileDialog(AppThemeData theme) {
    return showDSDialog<void>(
      context: context,
      builder: (dialogContext) => DSDialog(
        title: '我的资料',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JellyProfileCard(
              name: Live2DPlugin.instance.selected?.name ?? '小智',
              level: 17,
              exp: 568,
              expMax: 1250,
            ),
            SizedBox(height: theme.spacing.md),
            Row(
              children: [
                for (var i = 0; i < _stats.length; i++) ...[
                  if (i > 0) SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: JellyStatCard(
                      icon: _stats[i].$1,
                      label: _stats[i].$2,
                      value: _stats[i].$3,
                      color: [theme.warning, theme.success, theme.primary][i],
                      onAdd: () {},
                    ),
                  ),
                ],
              ],
            ),
          ],
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

  static const List<(DsIconKind, String, String)> _stats = [
    (DsIconKind.clipboard, '今日待办', '3/8'),
    (DsIconKind.calendarCheck, '连续打卡', '26 天'),
    (DsIconKind.book, '本月记录', '128 条'),
  ];
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
        if (snapshot.hasError) return const Text('Live2D 聊天初始化失败');
        if (controller == null) return const SizedBox.shrink();
        return MessageInput(controller: controller);
      },
    );
  }
}
