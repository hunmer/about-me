import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 统一管理消息操作的处理器
class MessageOperations {
  final ChatPlugin _chatPlugin;
  final BuildContext context;

  MessageOperations(this.context) : _chatPlugin = ChatPlugin.instance;

  /// 编辑消息
  Future<void> editMessage(Message message) async {
    final controller = TextEditingController(text: message.content);

    // 显示编辑对话框
    final result = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'chat_editMessage'.tr,
                        textAlign: TextAlign.center,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      DSInput(
                        controller: controller,
                        hint: '输入新的消息内容...',
                        maxLines: null,
                      ),
                      SizedBox(height: theme.spacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _FormatButton(
                            label: 'B',
                            style: DsTypography.heading.copyWith(
                              color: theme.text,
                              fontWeight: FontWeight.w900,
                            ),
                            onTap: () => _insertMarkdownStyle(controller, '**'),
                          ),
                          _FormatButton(
                            label: 'I',
                            style: DsTypography.heading.copyWith(
                              color: theme.text,
                              fontStyle: FontStyle.italic,
                            ),
                            onTap: () => _insertMarkdownStyle(controller, '*'),
                          ),
                          _FormatButton(
                            label: 'S',
                            style: DsTypography.heading.copyWith(
                              color: theme.text,
                              decoration: TextDecoration.lineThrough,
                            ),
                            onTap: () => _insertMarkdownStyle(controller, '~~'),
                          ),
                          _FormatButton(
                            label: 'U',
                            style: DsTypography.heading.copyWith(
                              color: theme.text,
                              decoration: TextDecoration.underline,
                            ),
                            onTap: () => _insertMarkdownStyle(controller, '__'),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: DSButton(
                              label: 'app_cancel'.tr,
                              variant: DSButtonVariant.outline,
                              onPressed: () => Navigator.pop(context, false),
                            ),
                          ),
                          SizedBox(width: theme.spacing.md),
                          Expanded(
                            child: DSButton(
                              label: 'app_save'.tr,
                              onPressed: () => Navigator.pop(context, true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );

    if (result == true && controller.text.isNotEmpty) {
      final updatedMessage = await message.copyWith(
        content: controller.text,
        editedAt: DateTime.now(),
      );

      // 直接调用 updateMessage 方法更新消息
      await _chatPlugin.channelService.updateMessage(updatedMessage);
    }

    controller.dispose();
  }

  /// 删除消息（带确认对话框）
  Future<void> deleteMessage(Message message) async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('chat_deleteMessage'.tr),
            content: Text('chat_deleteMessageConfirmation'.tr),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('app_cancel'.tr),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('chat_delete'.tr),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await deleteMessageWithoutConfirmation(message);
    }
  }

  /// 删除消息（不带确认对话框）
  Future<void> deleteMessageWithoutConfirmation(Message message) async {
    // 获取频道ID
    final channelId = message.channelId;
    if (channelId == null) {
      return;
    }

    await _chatPlugin.channelService.deleteMessageById(channelId, message.id);
  }

  Future<void> deleteMessagesWithoutConfirmation(List<Message> messages) async {
    final grouped = <String, List<String>>{};
    for (final message in messages) {
      final id = message.channelId;
      if (id != null) grouped.putIfAbsent(id, () => []).add(message.id);
    }
    for (final entry in grouped.entries) {
      await _chatPlugin.channelService.deleteMessages(entry.key, entry.value);
    }
  }

  /// 复制消息内容
  void copyMessage(Message message) {
    if (message.type == MessageType.received ||
        message.type == MessageType.sent) {
      Clipboard.setData(ClipboardData(text: message.content));
      toastService.showToast('chat_copiedToClipboard'.tr);
    }
  }

  /// 设置固定符号
  Future<void> setFixedSymbol(Message message, String? symbol) async {
    final updatedMessage = await message.copyWith(fixedSymbol: symbol);
    // 直接调用 updateMessage 方法更新消息
    await _chatPlugin.channelService.updateMessage(updatedMessage);
  }

  /// 设置气泡颜色
  Future<void> setBubbleColor(Message message, Color? color) async {
    final updatedMessage = await message.copyWith(bubbleColor: color);
    // 直接调用 updateMessage 方法更新消息
    await _chatPlugin.channelService.updateMessage(updatedMessage);
  }

  /// 收藏/取消收藏消息
  Future<void> toggleFavorite(Message message) async {
    // 获取当前消息的metadata，如果不存在则创建一个新的
    final metadata = Map<String, dynamic>.from(message.metadata ?? {});

    // 切换收藏状态
    final isFavorite = metadata['isFavorite'] as bool? ?? false;
    metadata['isFavorite'] = !isFavorite;

    // 如果收藏，添加收藏时间
    if (metadata['isFavorite'] == true) {
      metadata['favoritedAt'] = DateTime.now().toIso8601String();
    } else {
      // 如果取消收藏，移除收藏时间
      metadata.remove('favoritedAt');
    }

    // 更新消息
    final updatedMessage = await message.copyWith(metadata: metadata);

    // 直接调用 updateMessage 方法更新消息
    await _chatPlugin.channelService.updateMessage(updatedMessage);

    // 显示操作结果
    if (context.mounted) {
      toastService.showToast(metadata['isFavorite'] ? '已添加到收藏' : '已从收藏中移除');
    }
  }

  /// 插入 Markdown 样式
  void _insertMarkdownStyle(TextEditingController controller, String style) {
    final text = controller.text;
    final selection = controller.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$style${selection.textInside(text)}$style',
    );
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset:
            selection.baseOffset +
            style.length * 2 +
            selection.textInside(text).length,
      ),
    );
  }
}

/// Markdown 格式按钮：果冻底座 + 带格式样的字母
class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed ? theme.primary.mixWhite(0.86) : theme.surfaceAlt,
            borderRadius: theme.radii.sm,
            border: Border.all(color: theme.stroke, width: 1.2),
          ),
          child: Text(label, style: style),
        );
      },
    );
  }
}
