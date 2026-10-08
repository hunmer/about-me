import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/widgets/audio_player_widget.dart';

class AudioMessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;

  /// 跟随气泡文字色，保证在实色主色/白色/选中高亮气泡上都有对比
  final Color textColor;

  const AudioMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // 获取音频文件路径
    final audioPath = message.content;
    if (audioPath.isEmpty) {
      return Text('chat_audioMessageBubbleErrorText'.tr);
    }

    // 获取音频时长
    final duration = message.audioDuration;

    // 播放器配色跟随气泡文字色
    final primaryColor = textColor;
    final backgroundColor = textColor.withValues(alpha: 0.15);
    final progressColor = textColor;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 音频播放器
          AudioPlayerWidget(
            audioPath: audioPath,
            durationInSeconds: duration,
            isLocalFile: true,
            primaryColor: primaryColor,
            backgroundColor: backgroundColor,
            progressColor: progressColor,
          ),

          // 如果消息被编辑过，显示编辑标记
          if (message.isEdited)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '已编辑',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
