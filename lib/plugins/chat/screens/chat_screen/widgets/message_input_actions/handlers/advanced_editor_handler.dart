import 'package:flutter/widgets.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/widgets/rich_editor_screen.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/types.dart';

Future<void> handleAdvancedEditor({
  required BuildContext context,
  required OnSendMessage? onSendMessage,
}) async {
  // 全屏富文本编辑，保存即发送
  await NavigationHelper.push(
    context,
    RichEditorScreen(
      showTitle: false,
      initialContent: '',
      texts: const RichEditorTexts(contentHint: '在此输入消息内容...'),
      onSave: (_, content, __) async {
        if (content.isNotEmpty) {
          onSendMessage?.call(content, type: 'sent');
        }
      },
    ),
  );
}
