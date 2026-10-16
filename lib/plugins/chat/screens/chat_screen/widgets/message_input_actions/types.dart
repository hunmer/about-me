import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/message.dart';

/// 消息输入动作的基础类
class MessageInputAction {
  final String title;
  final DsIconKind icon;
  final VoidCallback onTap;

  /// 长按动作（可选，如图片按钮长按进入多选）
  final VoidCallback? onLongPress;

  MessageInputAction({
    required this.title,
    required this.icon,
    required this.onTap,
    this.onLongPress,
  });
}

/// 文件选择回调
typedef OnFileSelected = void Function(Map<String, dynamic> fileInfo);

/// 发送消息回调
typedef OnSendMessage =
    void Function(
      String content, {
      Map<String, dynamic>? metadata,
      String type,
      Message? replyTo,
    });
