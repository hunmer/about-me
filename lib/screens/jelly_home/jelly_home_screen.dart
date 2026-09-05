import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import 'widgets/jelly_store_banner.dart';
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

  @override
  Widget build(BuildContext context) {
    // IndexedStack 保活各页签状态（滚动位置、编辑进度等）；
    // 页面内容铺满全屏，底部导航悬浮其上
    return JellyBottomNav(
      current: JellyTab.values[_tabIndex],
      onTap: (index) => setState(() => _tabIndex = index),
      child: IndexedStack(
        index: _tabIndex,
        children: [
          HeroMode(enabled: _tabIndex == 0, child: const _CottageTab()),
          HeroMode(
            enabled: _tabIndex == 1,
            child: const HomeScheduleScreen(),
          ),
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

/// 小屋页签（软糖果冻风布局还原）
///
/// 参考设计稿自上而下：资料卡 + 统计卡
/// → Live2D 角色 + 陪伴状态卡 → 商店横幅。
class _CottageTab extends StatefulWidget {
  const _CottageTab();

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
    // 演示页自带浅色主题
    final theme = AppThemeData.light();
    // 悬浮导航栏的避让高度（JellyBottomNav 通过 extendBody 注入的底部内边距）
    final bottomInset = MediaQuery.of(context).padding.bottom;

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
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
              // 内容不足一屏时也撑满视口高度，让底部卡片组贴住悬浮导航栏；
              // 视口高度需减去导航栏避让高度，底部卡片才不会被压在导航栏下面
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: viewport.maxHeight - bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // 富余空间全部落在上下两组之间：上组贴顶、底部组贴底
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: theme.spacing.lg),
                        _buildHeader(theme),
                        SizedBox(height: theme.spacing.xl),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 富余空间都在角色区之上，Live2D 角色贴着底部卡片组
                        SizedBox(height: theme.spacing.md),
                        // 点击命中角色本体（hit area）算一次陪伴互动
                        Center(
                          child: JellyLive2D(
                            message: _live2dMessage,
                            reaction: _live2dReaction,
                            typingInterval: Live2DPlugin.instance.bubbleTypingInterval,
                            onTap: (hitAreaId, _) {
                              if (hitAreaId != null) {
                                _companion.recordInteraction();
                              }
                            },
                          ),
                        ),
                        Live2DChatInput(
                          onReply: _scheduleLive2dReply,
                        ),
                        SizedBox(height: theme.spacing.lg),
                        JellyCompanionCard(controller: _companion),
                        SizedBox(height: theme.spacing.lg),
                        JellyStoreBanner(
                          title: '插件商店上新',
                          subtitle: '新插件限时免费领',
                          onTap: () {},
                        ),
                        SizedBox(height: theme.spacing.lg),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleLive2dReply(String reply, bool streaming) {
    _pendingLive2dReply = reply;
    _pendingLive2dStreaming = streaming;
    if (_live2dReplyFrameScheduled) return;
    _live2dReplyFrameScheduled = true;
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      debugPrint('[Live2DChat] deferred reply update during ${SchedulerBinding.instance.schedulerPhase.name}');
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

  /// 顶部：左资料卡 + 右三张统计卡
  Widget _buildHeader(AppThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: JellyProfileCard(
            name: '小智',
            level: 17,
            exp: 568,
            expMax: 1250,
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < _stats.length; i++) ...[
                if (i > 0) SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: JellyStatCard(
                    icon: _stats[i].$1,
                    label: _stats[i].$2,
                    value: _stats[i].$3,
                    color: [
                      theme.warning,
                      theme.success,
                      theme.primary,
                    ][i],
                    onAdd: () {},
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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
  late final Future<ChatController?> _controllerFuture = _initialize();
  ChatController? _controller;
  MessageService? _messageService;
  String? _lastReplyId;
  String? _lastReplyContent;

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

    final messageService = MessageService(storage: Live2DPlugin.instance.storage);
    final controller = ChatController(
      conversation: conversation,
      messageService: messageService,
      conversationService: agentChat.conversationService,
      messageDetailService: MessageDetailService(storage: Live2DPlugin.instance.storage),
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
    final latestUserIndex = messages.lastIndexWhere((message) => message.isUser);
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
      break;
    }
  }

  @override
  void dispose() {
    _messageService?.removeListener(_onMessagesChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatController?>(
      future: _controllerFuture,
      builder: (context, snapshot) {
        final controller = snapshot.data;
        if (snapshot.hasError) return const Text('Live2D 聊天初始化失败');
        if (controller == null) return const Text('请先在 Live2D 设置中选择 Agent');
        return MessageInput(controller: controller);
      },
    );
  }
}
