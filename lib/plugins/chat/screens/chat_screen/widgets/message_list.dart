import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/file_message.dart';
import 'package:aboutme/plugins/chat/utils/message_options_handler.dart';
import 'ai_thread_entry.dart';
import 'message_bubble.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/date_separator.dart';
import 'package:aboutme/plugins/chat/utils/date_formatter.dart';
import 'package:aboutme/widgets/file_preview/index.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class MessageList extends StatefulWidget {
  final List<dynamic> items;
  final bool isMultiSelectMode;
  final ValueNotifier<Set<String>> selectedMessageIds;
  final void Function(Message) onMessageEdit;
  final Future<void> Function(Message) onMessageDelete;
  final void Function(Message) onMessageCopy;
  final void Function(Message, String?) onSetFixedSymbol;
  final void Function(Message, Color?) onSetBubbleColor;
  final void Function(Message) onReply; // 添加回复消息回调
  final void Function(Message) onToggleFavorite; // 添加收藏消息回调
  final void Function(String) onToggleMessageSelection;
  final void Function(String) onReplyTap; // 添加回复消息点击回调
  final AutoScrollController scrollController;
  final void Function(Message)? onAvatarTap;
  final bool showAvatar;
  final String? currentUserId;
  final Message? highlightedMessage;
  final bool shouldHighlight;
  final Map<String, int>? messageIndexMap;

  const MessageList({
    super.key,
    required this.items,
    required this.isMultiSelectMode,
    required this.selectedMessageIds,
    this.onAvatarTap,
    this.showAvatar = true,
    required this.onMessageEdit,
    required this.onMessageDelete,
    required this.onMessageCopy,
    required this.onSetFixedSymbol,
    required this.onSetBubbleColor,
    required this.onReply,
    required this.onToggleFavorite,
    required this.onToggleMessageSelection,
    required this.onReplyTap,
    required this.scrollController,
    this.currentUserId,
    this.highlightedMessage,
    this.shouldHighlight = false,
    this.messageIndexMap,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

/// 仅在指定消息自身的选中状态变化时重建，
/// 避免监听整个选中集合导致所有可见气泡随每次勾选全量刷新
class _SelectableMessageBubble extends StatefulWidget {
  const _SelectableMessageBubble({
    required this.selectedMessageIds,
    required this.messageId,
    required this.builder,
  });

  final ValueNotifier<Set<String>> selectedMessageIds;
  final String messageId;
  final MessageBubble Function(bool isSelected) builder;

  @override
  State<_SelectableMessageBubble> createState() =>
      _SelectableMessageBubbleState();
}

class _SelectableMessageBubbleState extends State<_SelectableMessageBubble> {
  late bool _isSelected;

  @override
  void initState() {
    super.initState();
    _isSelected = widget.selectedMessageIds.value.contains(widget.messageId);
    widget.selectedMessageIds.addListener(_handleSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant _SelectableMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMessageIds != widget.selectedMessageIds ||
        oldWidget.messageId != widget.messageId) {
      oldWidget.selectedMessageIds.removeListener(_handleSelectionChanged);
      _isSelected = widget.selectedMessageIds.value.contains(widget.messageId);
      widget.selectedMessageIds.addListener(_handleSelectionChanged);
    }
  }

  @override
  void dispose() {
    widget.selectedMessageIds.removeListener(_handleSelectionChanged);
    super.dispose();
  }

  void _handleSelectionChanged() {
    final selected =
        widget.selectedMessageIds.value.contains(widget.messageId);
    if (selected != _isSelected) {
      setState(() => _isSelected = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_isSelected);
  }
}

class _MessageListState extends State<MessageList> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      reverse: true,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        var item = widget.items[index];
        final nextItem = index > 0 ? widget.items[index - 1] : null;

        // 处理日期分隔符
        Widget? dateSeparator;
        if (item is DateTime) {
          // 如果项目本身是日期，直接显示日期分隔符
          return DateSeparator(date: item);
        } else if (item is Message &&
            nextItem is Message &&
            _shouldShowDateSeparator(item, nextItem)) {
          // 如果当前消息和下一条消息不是同一天，显示日期分隔符
          dateSeparator = DateSeparator(date: item.date);
        }

        if (item is Message) {
          // 为消息项添加 AutoScrollTag
          final tagIndex = widget.messageIndexMap?[item.id] ?? index;
          // 列表 reverse: true，视觉上方（时间更早）的消息在 index + 1；
          // 与上一条非同一用户（或中间隔着日期分隔符）时视为组内首条
          final prevItem =
              index + 1 < widget.items.length
                  ? widget.items[index + 1]
                  : null;
          final isFirstOfGroup =
              prevItem is! Message || prevItem.user.id != item.user.id;
          return AutoScrollTag(
            key: ValueKey(item.id),
            controller: widget.scrollController,
            index: tagIndex,
            child: Column(
              children: [
                if (dateSeparator != null) dateSeparator,
                GestureDetector(
                  onLongPress: () {
                    // 使用统一的消息选项处理器
                    MessageOptionsHandler.showOptionsDialog(
                      context: context,
                      message: item,
                      onMessageEdit: widget.onMessageEdit,
                      onMessageDelete: widget.onMessageDelete,
                      onMessageCopy: widget.onMessageCopy,
                      onSetFixedSymbol: widget.onSetFixedSymbol,
                      onSetBubbleColor: widget.onSetBubbleColor,
                      onReply: widget.onReply,
                      onToggleFavorite: widget.onToggleFavorite,
                    );
                  },
                  onDoubleTap: () {
                    // 使用统一的消息选项处理器，直接显示固态符号编辑对话框
                    MessageOptionsHandler.showOptionsDialog(
                      context: context,
                      message: item,
                      onMessageEdit: widget.onMessageEdit,
                      onMessageDelete: widget.onMessageDelete,
                      onMessageCopy: widget.onMessageCopy,
                      onSetFixedSymbol: widget.onSetFixedSymbol,
                      onSetBubbleColor: widget.onSetBubbleColor,
                      onReply: widget.onReply,
                      onToggleFavorite: widget.onToggleFavorite,
                      initiallyShowFixedSymbolDialog: true, // 直接显示固态符号编辑对话框
                    );
                  },
                  child: _SelectableMessageBubble(
                    selectedMessageIds: widget.selectedMessageIds,
                    messageId: item.id,
                    builder: (isSelected) => MessageBubble(
                        message: item,
                        isSelected: isSelected,
                        isMultiSelectMode: widget.isMultiSelectMode,
                        onEdit: () => widget.onMessageEdit(item),
                        onDelete: () => widget.onMessageDelete(item),
                        onCopy: () => widget.onMessageCopy(item),
                        onSetFixedSymbol:
                            (symbol) => widget.onSetFixedSymbol(item, symbol),
                        onLongPress: null, // 移除重复的长按处理
                        onTap:
                            widget.isMultiSelectMode
                                ? () => widget.onToggleMessageSelection(item.id)
                                : () {
                                  if ((item.type == MessageType.file ||
                                          item.type == MessageType.video ||
                                          item.type == MessageType.image) &&
                                      item.metadata != null &&
                                      item.metadata![Message.metadataKeyFileInfo] !=
                                          null) {
                                    try {
                                      final fileInfo = FileMessage.fromJson(
                                        Map<String, dynamic>.from(
                                          item.metadata![Message.metadataKeyFileInfo],
                                        ),
                                      );
                                      NavigationHelper.push(context, FilePreviewScreen(
                                                filePath: fileInfo.filePath,
                                                fileName: fileInfo.fileName,
                                                mimeType:
                                                    fileInfo.mimeType ??
                                                    'application/octet-stream',
                                                fileSize: fileInfo.fileSize,),
                                      );
                                    } catch (e) {
                                      Toast.error('chat_errorFilePreviewFailed'.tr);
                                    }
                                  }
                                },
                        onAvatarTap:
                            widget.onAvatarTap != null
                                ? () => widget.onAvatarTap!(item)
                                : null,
                        showAvatar: widget.showAvatar,
                        isFirstOfGroup: isFirstOfGroup,
                        currentUserId: widget.currentUserId ?? '',
                        isHighlighted:
                            widget.shouldHighlight &&
                            widget.highlightedMessage != null &&
                            item.id == widget.highlightedMessage?.id,
                        onToggleFavorite: () => widget.onToggleFavorite(item),
                        onReplyTap: widget.onReplyTap,
                      ),
                  ),
                ),
                // AI 回复线程入口（@AI 消息下方：有 xx 条回复 / 正在输入…）
                if (!widget.isMultiSelectMode) AiThreadEntry(message: item),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  bool _shouldShowDateSeparator(Message currentMessage, Message nextMessage) {
    return !DateFormatter.isSameDay(currentMessage.date, nextMessage.date);
  }
}
