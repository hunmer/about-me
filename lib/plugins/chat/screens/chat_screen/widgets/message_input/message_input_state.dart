import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aboutme/plugins/chat/models/message.dart';

class MessageInputState {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode keyboardListenerFocusNode;
  final List<Map<String, String>> selectedAgents;

  /// 待发送文件列表（每个文件独立成一条消息）
  final List<Map<String, dynamic>> selectedFiles;
  final bool showAgentList;
  final Message? replyTo;
  final Map<String, dynamic>? metadata;
  final Function(String) onSaveDraft;
  final Function(
    String, {
    Map<String, dynamic>? metadata,
    String type,
    Message? replyTo,
  })
  onSendMessage;

  // 清空文件选择的回调函数
  final VoidCallback? onClearFile;

  MessageInputState({
    required this.controller,
    required this.focusNode,
    required this.keyboardListenerFocusNode,
    required this.selectedAgents,
    required this.selectedFiles,
    required this.showAgentList,
    required this.replyTo,
    required this.onSaveDraft,
    required this.onSendMessage,
    this.onClearFile,
    this.metadata,
  });

  void sendMessage() {
    final messageText = controller.text.trim();
    final hasFiles = selectedFiles.isNotEmpty;
    final hasMessage = messageText.isNotEmpty;
    final currentChannel = ChatPlugin.instance.channelService.currentChannel;

    // 检查是否有当前频道
    if (currentChannel == null) {
      debugPrint('无法发送消息：当前没有选择频道');
      return;
    }

    if (hasFiles || hasMessage) {
      Map<String, dynamic>? metadata = {};

      // 文件逐条发送：每个文件一条独立消息
      if (hasFiles) {
        for (final selectedFile in selectedFiles) {
          final fileInfo =
              selectedFile['fileInfo'] as Map<String, dynamic>?;
          if (fileInfo == null) {
            debugPrint('文件信息无效，跳过该文件');
            continue;
          }
          onSendMessage(
            fileInfo['path'] as String,
            type: fileInfo['type'] as String,
            metadata: selectedFile,
          );
        }
      }

      // 如果有消息文本，再发送消息
      if (hasMessage) {
        // 如果有预设的元数据，先添加
        if (this.metadata != null) {
          metadata.addAll(this.metadata!);
        }

        // 添加智能体信息（如果元数据中没有）
        if (selectedAgents.isNotEmpty && !metadata.containsKey('agents')) {
          metadata['agents'] = selectedAgents.map((agent) => agent).toList();
        }

        // 确保上下文数量存在（如果元数据中没有）
        if (selectedAgents.isNotEmpty &&
            !metadata.containsKey('contextCount')) {
          metadata['contextCount'] = 20; // 默认上下文数量
          debugPrint('[MessageInputState] 设置默认 contextCount: 20');
        }
        debugPrint('[MessageInputState] 最终 metadata: $metadata');

        // 发送消息（消息实例由 ChatScreenController.sendMessage 统一创建并持久化，
        // chat_message_sent 事件由 ChatScreen 用该真实实例广播，避免双实例重复）
        onSendMessage(
          messageText,
          type: 'sent',
          replyTo: replyTo,
          metadata: metadata,
        );

        // 清空输入框并保持焦点
        controller.clear();
        focusNode.requestFocus();
      }

      // 清空文件选择（纯文件发送时也需清空）
      if (hasFiles && onClearFile != null) {
        onClearFile!();
      }
    }
  }

  KeyEventResult handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (HardwareKeyboard.instance.isControlPressed) {
          // Ctrl+Enter: 插入换行符
          final currentText = controller.text;
          final selection = controller.selection;
          final newText = currentText.replaceRange(
            selection.start,
            selection.end,
            '\n',
          );
          controller.value = controller.value.copyWith(
            text: newText,
            selection: TextSelection.collapsed(offset: selection.start + 1),
          );
        } else if (!HardwareKeyboard.instance.isShiftPressed) {
          sendMessage();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
