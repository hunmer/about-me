import 'package:aboutme/widgets/quill_editor.dart';
import 'package:flutter/widgets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/types.dart';

Future<void> handleAdvancedEditor({
  required BuildContext context,
  required OnSendMessage? onSendMessage,
}) async {
  final theme = DSThemeBridge.resolve(context);
  showDSDialog(
    context: context,
    theme: theme,
    barrierDismissible: false,
    builder:
        (context) => JellyBox(
          radius: theme.radii.xxl,
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: QuillEditor(
            showTitle: false,
            contentHint: '在此输入消息内容...',
            onSave: (_, content) {
              if (content.isNotEmpty) {
                // 发送消息
                onSendMessage?.call(content, type: 'sent');
              }
              Navigator.of(context).pop();
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
  );
}
