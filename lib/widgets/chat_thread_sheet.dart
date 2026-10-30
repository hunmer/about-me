import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:skribble/skribble.dart' show WiredDraw, WiredDrawTransition;

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/markdown_content.dart';
import 'package:aboutme/plugins/chat/widgets/audio_player_widget.dart';
import 'package:aboutme/widgets/message_input/message_input.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 通用聊天记录气泡数据（各插件的消息模型映射成此结构后展示）
class ChatThreadBubbleData {
  const ChatThreadBubbleData({
    required this.id,
    required this.content,
    required this.isUser,
    this.agentName,
    this.status,
    this.type = 'text',
    this.audioPath,
    this.audioDurationSec,
  });

  final String id;

  /// 文本内容（AI 消息支持 Markdown 渲染）
  final String content;

  final bool isUser;

  /// AI 消息署名（气泡上方小字）
  final String? agentName;

  /// 'thinking' 显示输入中占位，'error' 出错淡红底
  final String? status;

  /// 'text' | 'audio'
  final String type;

  final String? audioPath;

  final int? audioDurationSec;
}

/// 通用聊天记录 bottomSheet 面板（从 AI 回复线程抽屉抽离）：
/// 拖拽条 + 标题 + 气泡消息列表 + 可选输入行。
///
/// 手绘纸墨风（design.md §9）：面板走 DsSketchPanel（纸底 + 排线 +
/// 墨线框），气泡走 dsSketchDecoration 实底墨线描边。
///
/// 只负责展示与输入回调；消息数据由调用方提供（如线程事件、会话快照），
/// 数据变化时调用方 setState 重建本组件即可，列表自动滚到底部。
class ChatThreadSheet extends StatefulWidget {
  const ChatThreadSheet({
    super.key,
    required this.title,
    required this.bubbles,
    this.showTyping = false,
    this.inputHint,
    this.onSend,
    this.sending = false,
  });

  final String title;

  final List<ChatThreadBubbleData> bubbles;

  /// 标题右侧"正在输入…"提示
  final bool showTyping;

  /// 非空时显示输入行（续聊），null 则纯展示
  final String? inputHint;

  final Future<void> Function(String text)? onSend;

  /// 发送中（禁用输入行发送）
  final bool sending;

  @override
  State<ChatThreadSheet> createState() => _ChatThreadSheetState();
}

class _ChatThreadSheetState extends State<ChatThreadSheet> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(covariant ChatThreadSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 消息到达/更新（流式）时贴底
    final oldLast = oldWidget.bubbles.isEmpty ? null : oldWidget.bubbles.last;
    final newLast = widget.bubbles.isEmpty ? null : widget.bubbles.last;
    if (oldLast?.id != newLast?.id ||
        oldLast?.content != newLast?.content ||
        oldWidget.bubbles.length != widget.bubbles.length) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || widget.sending) return;
    final onSend = widget.onSend;
    if (onSend == null) return;
    _inputController.clear();
    await onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final mq = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: DSThemeBridge(
        // 打开 sheet 时墨线描画入场（design.md §10）
        child: WiredDraw(
          child: DsSketchPanel(
            theme: theme,
            // 键盘弹出时压缩高度，保证输入行可见
            height: (mq.size.height * 0.78 - mq.viewInsets.bottom).clamp(
              300.0,
              mq.size.height * 0.85,
            ),
            radius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // 拖拽条 + 标题
                  Column(
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.ink.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: DsTypography.title.copyWith(
                                  color: theme.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.showTyping)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  'chat_threadTyping'.tr,
                                  style: DsTypography.caption.copyWith(
                                    color: theme.primary,
                                  ),
                                ),
                              ),
                            DSIconButton(
                              icon: DsIconKind.close,
                              size: 36,
                              color: theme.surface,
                              iconColor: theme.text,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _SketchDivider(color: theme.ink.withValues(alpha: 0.35)),
                  // 消息列表（聊天流不套便签化，design.md §11.4）
                  Expanded(
                    child:
                        widget.bubbles.isEmpty
                            ? const SizedBox.shrink()
                            : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              itemCount: widget.bubbles.length,
                              itemBuilder: (context, index) {
                                final msg = widget.bubbles[index];
                                return _buildBubble(context, msg);
                              },
                            ),
                  ),
                  // 输入行（复用通用 MessageInput：手绘面板 + 底部安全区）
                  if (widget.inputHint != null)
                    MessageInput(
                      controller: _inputController,
                      hintText: widget.inputHint,
                      onSend: widget.sending ? null : _send,
                      useSketchPanel: true,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context, ChatThreadBubbleData msg) {
    final theme = DSThemeBridge.resolve(context);
    final isThinking = msg.status == 'thinking';
    final isError = msg.status == 'error';

    // 自己的消息实底主色，AI 消息次级纸面，出错淡红底（design.md §9.1）
    final bgColor =
        msg.isUser
            ? theme.primary
            : isError
            ? theme.danger.mixWhite(0.82)
            : theme.surfaceAlt;
    final fgColor =
        msg.isUser ? theme.onPrimary : isError ? theme.danger : theme.text;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: bgColor,
        radius: BorderRadius.circular(16),
        seed: msg.id.hashCode & 0x7fffffff,
        progress: WiredDrawTransition.progressOf(context),
      ),
      child:
          msg.type == 'audio' && msg.audioPath != null
          ? AudioPlayerWidget(
              audioPath: msg.audioPath!,
              durationInSeconds: msg.audioDurationSec ?? 0,
              primaryColor: theme.primary,
            )
          : isThinking
          ? Text(
              'chat_threadThinking'.tr,
              style: DsTypography.body.copyWith(color: theme.textSub),
            )
          : msg.isUser
          ? Text(
              msg.content,
              style: DsTypography.body.copyWith(color: fgColor),
            )
          // AI 回复可能含 markdown（代码块/列表等）与内联 think 标签，
          // 与 agent_chat 消息渲染保持一致
          : _buildAiTextContent(context, msg, fgColor),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!msg.isUser && msg.agentName != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                msg.agentName!,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ),
          bubble,
        ],
      ),
    );
  }

  /// AI 文本内容：抽出内联 `<think>` 思考块（复用 agent_chat 的
  /// ChatMessage.splitThink），思考过程经"查看思考过程"入口在底部
  /// sheet 查看，正文只渲染剥离后的部分（与 agent_chat 消息一致）
  Widget _buildAiTextContent(
    BuildContext context,
    ChatThreadBubbleData msg,
    Color textColor,
  ) {
    final (thinking, visible) = ChatMessage.splitThink(msg.content);
    if (thinking.isEmpty) {
      return MarkdownContent(content: msg.content, textColor: textColor);
    }

    final theme = DSThemeBridge.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 思考过程入口（样式复用 agent_chat 的时间戳行思考入口）
        Pressable(
          onPressed: () => _showThinkingSheet(context, thinking),
          semanticLabel: 'chat_threadViewThinking'.tr,
          builder: (context, states) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsIcon(DsIconKind.bot, size: 12, color: theme.primary),
              const SizedBox(width: 4),
              Text(
                'chat_threadViewThinking'.tr,
                style: DsTypography.caption.copyWith(color: theme.primary),
              ),
            ],
          ),
        ),
        if (visible.isNotEmpty) ...[
          const SizedBox(height: 6),
          MarkdownContent(content: visible, textColor: textColor),
        ],
      ],
    );
  }

  /// 底部 sheet 显示思考过程（复用 agent_chat _showThinkingSheet 模式）
  void _showThinkingSheet(BuildContext context, String thinking) {
    SmoothBottomSheet.showWithTitle(
      context: context,
      title: 'chat_threadThinkingProcess'.tr,
      child: DSThemeBridge(
        child: Builder(
          builder: (ctx) {
            final theme = DSThemeBridge.resolve(ctx);
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.xl),
                child: MarkdownContent(content: thinking),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 手绘虚线分隔线：断续墨线段替代 Material Divider（design.md §9.3）
class _SketchDivider extends StatelessWidget {
  const _SketchDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final w in const [22.0, 14.0, 30.0, 18.0, 24.0, 12.0])
            Container(
              width: w,
              height: 2,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}
