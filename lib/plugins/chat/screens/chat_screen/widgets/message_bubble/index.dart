import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:aboutme/core/event/event.dart' as aboutme_event;
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'components/avatar.dart';
import 'components/favorite_icon.dart';
import 'components/fixed_symbol.dart';
import 'components/message_actions.dart';
import 'components/message_content.dart';
import 'components/message_timestamp.dart';
import 'components/reply_widget.dart';

// 获取ChatPlugin单例实例
final chatPlugin = ChatPlugin.instance;

// 定义回复消息加载状态
enum ReplyLoadingState { initial, loading, loaded, error }

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isSelected;
  final bool isMultiSelectMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final Function(String?) onSetFixedSymbol;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;
  final bool showAvatar;

  /// 是否为同一用户连续消息组的首条（决定头像与用户名是否显示）
  final bool isFirstOfGroup;
  final String currentUserId;
  final bool isHighlighted;
  final Function(String)? onReplyTap;
  final VoidCallback? onToggleFavorite;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    required this.onSetFixedSymbol,
    required this.currentUserId,
    this.onLongPress,
    this.onTap,
    this.onAvatarTap,
    this.showAvatar = true,
    this.isFirstOfGroup = true,
    this.isHighlighted = false,
    this.onReplyTap,
    this.onToggleFavorite,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  Message? replyMessage;
  late String _messageUpdateSubscriptionId;
  // 保存当前消息的副本，以便在更新时替换
  late Message _currentMessage;
  String? _currentReplyToId;
  // 右上角光标按钮控制的操作栏展开状态
  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    // 初始化当前消息为widget传入的消息
    _currentMessage = widget.message;
    _currentReplyToId = widget.message.replyToId;
    _loadReplyMessage();
    _messageUpdateSubscriptionId = aboutme_event.EventManager.instance
        .subscribe('chat_message_updated', _handleMessageUpdated);
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当widget更新时，检查消息是否发生变化
    if (widget.message != oldWidget.message ||
        widget.message.replyToId != _currentReplyToId) {
      _currentMessage = widget.message;
      _currentReplyToId = widget.message.replyToId;
      _loadReplyMessage(); // 重新加载回复消息
    }
  }

  @override
  void dispose() {
    // ignore: deprecated_member_use_from_same_package
    aboutme_event.EventManager.instance.unsubscribeById(
      _messageUpdateSubscriptionId,
    );
    super.dispose();
  }

  void _handleMessageUpdated(aboutme_event.EventArgs args) {
    if (args is! aboutme_event.Value<Message>) {
      return;
    }
    final updatedMessage = args.value;

    if (!mounted) return;

    if (updatedMessage.id == _currentMessage.id) {
      // 更新当前消息对象为最新的updatedMessage
      setState(() {
        final oldReplyToId = _currentMessage.replyToId;
        _currentMessage = updatedMessage;
        _currentReplyToId = updatedMessage.replyToId;

        // 只有当replyToId发生变化时才重新加载回复消息
        if (oldReplyToId != updatedMessage.replyToId) {
          _loadReplyMessage();
        }
      });
    } else if (_currentReplyToId != null &&
        updatedMessage.id == _currentReplyToId &&
        replyMessage?.id == updatedMessage.id) {
      // 只更新当前正在显示的回复消息
      setState(() {
        replyMessage = updatedMessage;
      });
    }
  }

  Future<void> _loadReplyMessage() async {
    if (!mounted) return;

    // 如果没有回复ID，直接清除状态
    if (_currentMessage.replyToId == null) {
      setState(() {
        replyMessage = null;
        _currentReplyToId = null;
      });
      return;
    }

    // 设置加载状态
    setState(() {});

    try {
      final replyToId = _currentMessage.replyToId!;
      final reply = await chatPlugin.getMessage(replyToId);

      // 确保在异步操作完成后组件仍然挂载且消息ID匹配
      if (!mounted || _currentMessage.replyToId != replyToId) {
        return;
      }

      setState(() {
        if (reply != null) {
          replyMessage = reply;
          _currentReplyToId = replyToId;
        } else {
          replyMessage = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        replyMessage = null;
      });
    }
  }

  bool get _isCurrentUser => _currentMessage.user.id == widget.currentUserId;

  bool _isImageMessage() {
    final metadata = _currentMessage.metadata;
    if (metadata == null ||
        !metadata.containsKey(Message.metadataKeyFileInfo)) {
      return false;
    }
    final fileInfo =
        metadata[Message.metadataKeyFileInfo] as Map<String, dynamic>;
    return fileInfo['type'] == 'image';
  }

  Color _getBackgroundColor(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 优先使用消息的自定义气泡颜色
    if (_currentMessage.bubbleColor != null) {
      return _currentMessage.bubbleColor!;
    }

    // 如果没有自定义颜色，则使用默认主题颜色
    if (widget.isSelected) {
      return theme.primary.mixWhite(0.8);
    }
    if (widget.isHighlighted) {
      return theme.secondary.mixWhite(0.82);
    }
    // 自己的消息实色主色，对方白色表面（参考对话 UI 风格）
    return _isCurrentUser ? theme.primary : theme.surface;
  }

  Color _getTextColor(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 如果消息有自定义气泡颜色，根据背景亮度动态计算文字颜色
    if (_currentMessage.bubbleColor != null) {
      final bgColor = _currentMessage.bubbleColor!;
      // 计算背景颜色的相对亮度
      // 使用 computeLuminance() 方法，返回 0.0（最暗）到 1.0（最亮）
      final luminance = bgColor.computeLuminance();
      // 亮度阈值 0.5：浅色背景用深色文字，深色背景用浅色文字
      return luminance > 0.5
          ? const Color(0xDD000000)
          : const Color(0xFFFFFFFF);
    }

    // 实色主色气泡用 onPrimary，白色/浅色选中高亮气泡用正文色
    if (widget.isSelected || widget.isHighlighted) {
      return theme.text;
    }
    return _isCurrentUser ? theme.onPrimary : theme.text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final backgroundColor = _getBackgroundColor(context);
    final textColor = _getTextColor(context);

    // 气泡内含 DS 组件(内部调 AppTheme.of),宿主可能无 AppTheme 祖树
    // (如未迁移完的根目录 chat_screen / Overlay 重挂载),根部自包桥免疫
    return DSThemeBridge(
      child: GestureDetector(
        onLongPress: widget.isMultiSelectMode ? null : widget.onLongPress,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                _isCurrentUser
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
            children: [
              // 左侧复选框（当前用户的消息在多选模式下显示）
              if (_isCurrentUser && widget.isMultiSelectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 12.0),
                  child: _buildCheckbox(context),
                ),
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      _isCurrentUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  children: [
                    // 自己的消息：头像悬浮于气泡上方外侧，仅组内首条显示
                    if (_isCurrentUser &&
                        widget.showAvatar &&
                        widget.isFirstOfGroup)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, right: 4),
                        child: MessageAvatar(
                          user: _currentMessage.user,
                          onTap: widget.onAvatarTap,
                        ),
                      ),
                    // 他人消息：头像与光标按钮行同一栏，按钮贴整行右缘
                    if (!_isCurrentUser)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            if (widget.showAvatar && widget.isFirstOfGroup)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: MessageAvatar(
                                  user: _currentMessage.user,
                                  onTap: widget.onAvatarTap,
                                ),
                              ),
                            const Spacer(),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.centerRight,
                              child: _showActions
                                  ? MessageActions(
                                      onEdit: widget.onEdit,
                                      onDelete: widget.onDelete,
                                      onCopy: widget.onCopy,
                                      onSetFixedSymbol: widget.onSetFixedSymbol,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            _buildActionsToggle(theme),
                          ],
                        ),
                      ),
                    _buildBubble(theme, backgroundColor, textColor),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentMessage.fixedSymbol != null)
                          FixedSymbolWidget(
                            symbol: _currentMessage.fixedSymbol!,
                          ),
                        if (widget.onToggleFavorite != null &&
                            _currentMessage.metadata?['isFavorite'] == true)
                          FavoriteIcon(
                            isFavorite: true,
                            onTap: widget.onToggleFavorite!,
                          ),
                        const SizedBox(width: 5),
                        MessageTimestamp(
                          date:
                              _currentMessage.updatedAt ??
                              _currentMessage.createdAt,
                          isEdited: _currentMessage.updatedAt != null,
                        ),
                        // 自己的消息被 AI 已读时显示标记（活人感已读机制）
                        if (_isCurrentUser &&
                            (_currentMessage.metadata?['readBy']
                                    as List<dynamic>?)
                                ?.isNotEmpty ==
                                true) ...[
                          const SizedBox(width: 3),
                          Text(
                            '已读',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontSize: 10, color: Colors.blueGrey),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 右侧复选框（其他用户的消息在多选模式下显示）
              if (!_isCurrentUser && widget.isMultiSelectMode)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 12.0),
                  child: _buildCheckbox(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(
    AppThemeData theme,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding:
          _isImageMessage()
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: _isImageMessage() ? const Color(0x00000000) : backgroundColor,
        borderRadius: BorderRadius.circular(_isImageMessage() ? 12.0 : 24.0),
        // 图片气泡透明无阴影，其余按参考风格带柔和投影
        boxShadow: _isImageMessage() ? null : theme.shadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户名仅组内首条显示，与头像折叠策略一致
          if (!_isCurrentUser && widget.isFirstOfGroup)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                _currentMessage.user.username,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          if (replyMessage != null && widget.onReplyTap != null)
            ReplyWidget(replyMessage: replyMessage!, onTap: widget.onReplyTap!),
          MessageContent(message: _currentMessage, textColor: textColor),
        ],
      ),
    );
  }

  Widget _buildActionsToggle(AppThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _showActions = !_showActions),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.surfaceAlt,
          boxShadow: theme.shadows.soft,
        ),
        child: Center(
          // 展开时光标旋转180°由指向左变为指向右
          child: AnimatedRotation(
            turns: _showActions ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: DsIcon(
              DsIconKind.chevronLeft,
              size: 16,
              color: theme.textSub,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isSelected ? theme.primary : theme.stroke,
          width: 2,
        ),
        color: widget.isSelected ? theme.primary : const Color(0x00000000),
      ),
      child:
          widget.isSelected
              ? Center(
                child: DsIcon(
                  DsIconKind.check,
                  size: 14,
                  color: theme.onPrimary,
                ),
              )
              : null,
    );
  }
}
