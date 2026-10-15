import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Colors, Icons, Theme;
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/event/event.dart' as aboutme_event;
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/widgets/swipe_action/index.dart';
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

  /// 右滑操作栏的分享回调（null 时不显示分享项）
  final VoidCallback? onShare;
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

  /// 自定义气泡内容构建器（传入时替换默认 MessageContent，供其他聊天场景复用气泡框架）
  final Widget Function(BuildContext context, Message message, Color textColor)?
  contentBuilder;

  /// 时间戳行尾部插槽（如 agent 场景的"显示思考过程"入口）
  final Widget? infoBarTrailing;

  /// 自定义悬浮操作栏内容（传入时替换默认 MessageActions 按钮行）
  final Widget? actionsOverride;

  /// 自己的消息是否也显示悬浮操作栏（默认仅他人消息显示）
  final bool showActionsOnOwnMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    this.onShare,
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
    this.contentBuilder,
    this.infoBarTrailing,
    this.actionsOverride,
    this.showActionsOnOwnMessage = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  Message? replyMessage;
  late String _messageUpdateSubscriptionId;
  // 保存当前消息的副本，以便在更新时替换
  late Message _currentMessage;
  String? _currentReplyToId;
  // 右上角光标按钮控制的操作栏展开状态
  bool _showActions = false;

  // 新消息入场动画：他人消息自左上角、自己的消息自右上角放大复原
  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;

  @override
  void initState() {
    super.initState();
    // 初始化当前消息为widget传入的消息
    _currentMessage = widget.message;
    _currentReplyToId = widget.message.replyToId;
    // 仅对刚创建的消息播放入场动画，历史消息滚动重建时不触发
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _entranceScale = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack, // 过冲放大后复原到 1.0
    );
    if (DateTime.now().difference(widget.message.createdAt) <=
        const Duration(seconds: 5)) {
      _entranceController.forward();
    } else {
      // 历史消息不播入场动画，直接停在完成态；
      // 控制器默认值为 0，若不推进 ScaleTransition 将停留在 scale=0，气泡不绘制
      _entranceController.value = 1.0;
    }
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
    _entranceController.dispose();
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

    // 从右向左滑露出快捷操作（编辑/复制/分享/删除）；
    // 不设 leadingActions，从左向右滑留给系统侧滑返回；多选模式禁用避免与点选冲突
    return SwipeActionWrapper(
      key: ValueKey('msg_swipe_${widget.message.id}'),
      isEditMode: widget.isMultiSelectMode,
      trailingActions: [
        SwipeActionPresets.edit(onTap: widget.onEdit),
        SwipeActionOption(
          label: 'app_copy'.tr,
          icon: Icons.copy,
          backgroundColor: Colors.blueGrey,
          textColor: Colors.white,
          onTap: widget.onCopy,
        ),
        if (widget.onShare != null)
          SwipeActionPresets.share(onTap: widget.onShare!),
        SwipeActionPresets.delete(onTap: widget.onDelete),
      ],
      child: DSThemeBridge(
        child: GestureDetector(
          onLongPress: widget.isMultiSelectMode ? null : widget.onLongPress,
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            child: ScaleTransition(
              scale: _entranceScale,
              // 自己的消息自右上角、他人消息自左上角放大复原
              alignment: _isCurrentUser
                  ? Alignment.topRight
                  : Alignment.topLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: _isCurrentUser
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
                      crossAxisAlignment: _isCurrentUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        // 自己的消息：头像与光标按钮同一栏（镜像他人消息），光标贴整行左缘、头像贴右
                        if (_isCurrentUser && widget.showActionsOnOwnMessage)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                _buildActionsToggle(theme, mirror: true),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.centerLeft,
                                  child: _showActions
                                      ? _buildActions(theme)
                                      : const SizedBox.shrink(),
                                ),
                                const Spacer(),
                                if (widget.showAvatar && widget.isFirstOfGroup)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: MessageAvatar(
                                      user: _currentMessage.user,
                                      onTap: widget.onAvatarTap,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        else if (_isCurrentUser &&
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
                                      ? _buildActions(theme)
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
                                'chat_read'.tr,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontSize: 10,
                                      color: Colors.blueGrey,
                                    ),
                              ),
                            ],
                            // 时间戳行尾部插槽（agent 场景的思考过程入口等）
                            if (widget.infoBarTrailing != null) ...[
                              const SizedBox(width: 8),
                              widget.infoBarTrailing!,
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
        ),
      ),
    );
  }

  Widget _buildBubble(
    AppThemeData theme,
    Color backgroundColor,
    Color textColor,
  ) {
    // 环境描画动画（外层 WiredDraw 注入）；null = 已画完
    final drawProgress = WiredDrawTransition.progressOf(context);
    // 气泡不占满行宽（长文本/文件卡受限换行）
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      child: Container(
        padding: _isImageMessage()
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        // 图片气泡透明无装饰，其余实底 + 手绘墨线描边（design.md §9）
        decoration: _isImageMessage()
            ? null
            : dsSketchDecoration(
                theme: theme,
                fillColor: backgroundColor,
                radius: BorderRadius.circular(24.0),
                seed: _currentMessage.id.hashCode & 0x7fffffff,
                progress: drawProgress,
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
              ReplyWidget(
                replyMessage: replyMessage!,
                onTap: widget.onReplyTap!,
              ),
            // 自定义内容插槽（agent 等场景），默认渲染 chat 消息内容
            if (widget.contentBuilder != null)
              widget.contentBuilder!(context, _currentMessage, textColor)
            else
              MessageContent(message: _currentMessage, textColor: textColor),
          ],
        ),
      ),
    );
  }

  /// 悬浮操作栏内容：自定义插槽优先，否则用默认按钮行
  Widget _buildActions(AppThemeData theme) {
    if (widget.actionsOverride != null) {
      return widget.actionsOverride!;
    }
    return MessageActions(
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
      onCopy: widget.onCopy,
      onSetFixedSymbol: widget.onSetFixedSymbol,
    );
  }

  /// 光标按钮；mirror 时图标镜像（自己消息场景：未展开指向右侧的按钮行）
  Widget _buildActionsToggle(AppThemeData theme, {bool mirror = false}) {
    return GestureDetector(
      onTap: () => setState(() => _showActions = !_showActions),
      child: Container(
        width: 24,
        height: 24,
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surfaceAlt,
          circle: true,
          strokeWidth: 1.4,
        ),
        child: Center(
          // 展开时光标旋转180°指向按钮行的相反方向
          child: AnimatedRotation(
            turns: _showActions ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: DsIcon(
              mirror ? DsIconKind.chevronRight : DsIconKind.chevronLeft,
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
      // 未选中仅墨圈，选中实底 + 勾
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: widget.isSelected ? theme.primary : null,
        stroke: widget.isSelected ? theme.primary : theme.stroke,
        circle: true,
        strokeWidth: 1.6,
      ),
      child: widget.isSelected
          ? Center(
              child: DsIcon(DsIconKind.check, size: 14, color: theme.onPrimary),
            )
          : null,
    );
  }
}
