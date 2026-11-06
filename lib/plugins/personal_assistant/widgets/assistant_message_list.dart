import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grok_icon_study/grok_icon_study.dart';
import 'package:get/get.dart' hide Value;

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/message_bubble.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_status_panel_settings.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 消息流：头像在上、气泡在下的上下布局；最新 AI 消息的 bot 头像为
/// grok 动态表情，随处理状态切换（thinking/happy/idle），历史 AI 消息为静态图标；
/// 从 [PersonalAssistantScreen] 按功能拆出，仅做视图装配
class AssistantMessageList extends StatelessWidget {
  const AssistantMessageList({
    super.key,
    required this.theme,
    required this.controller,
    required this.messages,
    required this.scrollController,
    required this.avatarCharacter,
    required this.messageService,
    required this.userSettings,
  });

  final AppThemeData theme;
  final ChatController controller;
  final List<ChatMessage> messages;

  /// 消息列表滚动控制器
  final ScrollController scrollController;

  /// 消息流头像的动态角色（与首页大角色各自独立实例）
  final GrokCharacter avatarCharacter;

  /// 当前实例的消息服务（气泡内媒体渲染用）
  final MessageService? messageService;

  /// 用户头像/昵称（与状态面板共用），更换头像后消息头像同步刷新
  final JellyStatusPanelSettings userSettings;

  @override
  Widget build(BuildContext context) {
    String? lastAiId;
    for (final message in messages) {
      if (!message.isUser && !message.isSessionDivider) lastAiId = message.id;
    }
    // AI 尚未产出文本（发送中且最后一条是用户消息）时末尾显示占位气泡；
    // 占位期间动态头像挂到占位行，上一条 AI 消息转静态图标
    final showPlaceholder =
        controller.isSending && (messages.isEmpty || messages.last.isUser);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 气泡最大宽度：列表可视宽度的 80%，余量留作两侧留白
        final bubbleMaxWidth = constraints.maxWidth * 0.8;
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              theme.spacing.lg,
              theme.spacing.md,
              theme.spacing.lg,
              theme.spacing.md,
            ),
            itemCount: messages.length + (showPlaceholder ? 1 : 0),
            itemBuilder: (context, index) {
              final isLast =
                  index == messages.length + (showPlaceholder ? 1 : 0) - 1;
              if (showPlaceholder && index == messages.length) {
                return _buildPlaceholderRow(isLast: isLast);
              }
              final message = messages[index];
              if (message.isSessionDivider) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      message.content,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ),
                );
              }
              return Padding(
                key: ValueKey('msg_${message.id}_${message.isSessionDivider}'),
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: message.isUser
                    ? Column(
                        // 用户消息整体右对齐：脚注与头像同行，气泡在下
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildBubbleFooter(context, message),
                              SizedBox(width: theme.spacing.sm),
                              _buildUserAvatar(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _buildUserBubble(
                            context,
                            message,
                            maxWidth: bubbleMaxWidth,
                          ),
                        ],
                      )
                    : Column(
                        // AI 消息整体左对齐：头像与脚注同行，气泡在下
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildBotAvatar(
                                live:
                                    !showPlaceholder && message.id == lastAiId,
                              ),
                              SizedBox(width: theme.spacing.sm),
                              _buildBubbleFooter(context, message),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _buildAiBubble(
                            context,
                            message,
                            maxWidth: bubbleMaxWidth,
                          ),
                          if (_hasThinking(message)) ...[
                            const SizedBox(height: 4),
                            _buildThinkingEntry(context, message),
                          ],
                        ],
                      ),
              );
            },
          ),
        );
      },
    );
  }

  /// AI 处理中的占位气泡：动态 grok 头像（thinking，置于气泡上方）+ 加载墨点
  Widget _buildPlaceholderRow({required bool isLast}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBotAvatar(live: true),
          SizedBox(height: theme.spacing.sm),
          Align(
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
                  children: [DSLoadingDots(size: 6, color: theme.textSub)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    // 用户真实头像（与状态面板共用同一数据源），未设置回退默认头像；
    // 圆形裁剪打底，手绘圆框叠上层（同状态面板 _AvatarFrame）
    final avatarPath = userSettings.avatarPath;
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: avatarPath == null
                ? Image.asset(
                    'assets/images/default_avatar.jpg',
                    fit: BoxFit.cover,
                  )
                : AdaptiveImage(imagePath: avatarPath, fit: BoxFit.cover),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: dsSketchDecoration(theme: theme, circle: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotAvatar({required bool live}) {
    if (live) {
      // 视图在 postFrame 才同步渲染宽度；新 AI 消息到达时头像重挂载，
      // 预置宽度避免首帧按旧宽度绘制导致「慢半拍」出场
      avatarCharacter.updateRenderWidth(36);
      return GestureDetector(
        onTap: avatarCharacter.bounceOnce,
        child: SizedBox(
          width: 36,
          height: 36,
          child: GrokCharacterView(character: avatarCharacter, sizePx: 36),
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

  Widget _buildUserBubble(
    BuildContext context,
    ChatMessage message, {
    required double maxWidth,
  }) {
    return GestureDetector(
      // 长按气泡弹出更多选项（与脚注 ⋯ 入口一致）
      onLongPress: () => _showMessageOptions(context, message),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.primary,
          radius: BorderRadius.circular(18),
        ),
        child: AgentMessageContent(
          message: message,
          textColor: theme.onPrimary,
          messageService: messageService,
        ),
      ),
    );
  }

  Widget _buildAiBubble(
    BuildContext context,
    ChatMessage message, {
    required double maxWidth,
  }) {
    return GestureDetector(
      // 长按气泡弹出更多选项（与脚注 ⋯ 入口一致）
      onLongPress: () => _showMessageOptions(context, message),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DsSketchPanel(
          theme: theme,
          hachure: false,
          radius: BorderRadius.circular(18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: AgentMessageContent(
            message: message,
            textColor: theme.text,
            messageService: messageService,
            getAgentName: (_) => controller.currentAgent?.name,
          ),
        ),
      ),
    );
  }

  /// 消息是否带思考内容（左下角入口仅在存在思考时展示）
  bool _hasThinking(ChatMessage message) {
    final thinking = message.resolvedThinkingContent;
    return thinking != null && thinking.isNotEmpty;
  }

  /// 气泡左下角「查看思考过程」入口：点击经 SmoothBottomSheet 在底部弹出思考全文
  Widget _buildThinkingEntry(BuildContext context, ChatMessage message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Pressable(
        onPressed: () {
          final thinking = message.resolvedThinkingContent;
          if (thinking == null || thinking.isEmpty) return;
          final sheetTheme = DSThemeBridge.resolve(context);
          SmoothBottomSheet.showWithTitle(
            context: context,
            title: '思考过程',
            showCloseButton: true,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SelectableText(
                  thinking,
                  style: DsTypography.caption.copyWith(
                    color: sheetTheme.textSub,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          );
        },
        builder: (context, states) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.primary.mixWhite(0.9),
            borderRadius: theme.radii.sm,
            border: Border.all(
              color: theme.primary.withValues(
                alpha: states.contains(WidgetState.pressed) ? 0.6 : 0.35,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsIcon(DsIconKind.sparkle, size: 13, color: theme.primaryText),
              const SizedBox(width: 4),
              Text(
                '查看思考过程',
                style: DsTypography.caption.copyWith(
                  fontSize: 11,
                  color: theme.primaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 消息头行脚注：消息时间 + 更多选项入口（⋯），与头像同行置于气泡上方
  Widget _buildBubbleFooter(BuildContext context, ChatMessage message) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatMessageTime(message.timestamp),
          style: DsTypography.caption.copyWith(color: theme.textSub),
        ),
        SizedBox(
          width: 26,
          height: 22,
          child: Pressable(
            onPressed: () => _showMessageOptions(context, message),
            builder: (context, states) => Center(
              child: DsIcon(DsIconKind.more, size: 15, color: theme.textSub),
            ),
          ),
        ),
      ],
    );
  }

  /// 消息时间：当天 HH:mm，跨天 MM-dd HH:mm
  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final hm = '${two(time.hour)}:${two(time.minute)}';
    final isToday =
        time.year == now.year && time.month == now.month && time.day == now.day;
    return isToday ? hm : '${two(time.month)}-${two(time.day)} $hm';
  }

  /// 消息「更多选项」面板：复制文本 / 复制完整消息 / 删除消息
  void _showMessageOptions(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final sheetTheme = DSThemeBridge.resolve(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MessageOptionRow(
                  icon: DsIconKind.copy,
                  label: 'app_copy'.tr,
                  theme: sheetTheme,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Clipboard.setData(
                      ClipboardData(text: message.content),
                    );
                    if (context.mounted) {
                      toastService.showToast('screens_assistantCopied'.tr);
                    }
                  },
                ),
                _MessageOptionRow(
                  icon: DsIconKind.code,
                  label: '复制完整消息',
                  theme: sheetTheme,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    // 完整消息 JSON（含 toolCall 的 steps 数组）
                    final text = const JsonEncoder.withIndent(
                      '  ',
                    ).convert(message.toJson());
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      toastService.showToast('已复制完整消息');
                    }
                  },
                ),
                _MessageOptionRow(
                  icon: DsIconKind.trash,
                  label: 'screens_assistantDeleteMessage'.tr,
                  theme: sheetTheme,
                  danger: true,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await controller.deleteMessage(message.id);
                    } catch (e) {
                      if (context.mounted) toastService.showToast('$e');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 消息选项面板行（复制/删除等，结构与 _TestMenuAction 一致，支持危险态）
class _MessageOptionRow extends StatelessWidget {
  const _MessageOptionRow({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm,
            ),
            decoration: BoxDecoration(
              color: pressed ? theme.surfaceAlt : null,
              borderRadius: theme.radii.sm,
            ),
            child: Row(
              children: [
                DsIcon(
                  icon,
                  size: 18,
                  color: danger ? theme.danger : theme.primary,
                ),
                SizedBox(width: theme.spacing.md),
                Text(
                  label,
                  style: DsTypography.body.copyWith(
                    color: danger ? theme.danger : theme.text,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
