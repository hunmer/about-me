import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/chat/models/file_message.dart';
import 'package:aboutme/plugins/chat/services/file_service.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/record_audio_dialog.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/utils.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/types.dart';
import '../../../../../../../../core/services/toast_service.dart';

Future<void> handleAudioRecording({
  required BuildContext context,
  required FileService fileService,
  required OnFileSelected? onFileSelected,
}) async {
  if (!context.mounted) return;

  // 显示录音对话框 - 权限检查和录音逻辑在对话框内部处理
  showDSDialog(
    context: context,
    theme: DSThemeBridge.resolve(context),
    barrierDismissible: false,
    builder:
        (dialogContext) => RecordAudioDialog(
          onStopBytes: (bytes, fileName, duration) async {
            try {
              final storagePath = await fileService.saveAudioBytes(
                bytes,
                fileName,
              );

              final Map<String, dynamic> metadata = _buildAudioMetadata(
                storagePath,
                fileName: fileName,
                size: bytes.length,
                duration: duration,
              );
              onFileSelected?.call(metadata);
              toastService.showToast(
                '${'chat_audioRecording'.tr}: ${formatDuration(duration)}',
              );
            } catch (e) {
              debugPrint('处理音频时出错: $e');
              toastService.showToast('${'chat_recordingFailed'.tr}: $e');
            }
          },
          onStop: (File audioFile, Duration duration) async {
            try {
              debugPrint(
                '音频录制完成: ${audioFile.path}, 时长: ${duration.inSeconds}秒',
              );

              // 获取原始文件名
              final originalFileName = path.basename(audioFile.path);

              // 保存音频到应用目录
              debugPrint('开始保存音频...');
              final savedFile = await fileService.saveAudio(audioFile);
              debugPrint('音频已保存: ${savedFile.path}');

              // 创建文件消息
              final fileMessage = await FileMessage.fromFile(
                savedFile,
                originalFileName: originalFileName,
              );

              // 标准化文件信息结构
              final Map<String, dynamic> metadata = _buildAudioMetadata(
                fileMessage.filePath,
                fileName: originalFileName,
                size: fileMessage.fileSize,
                duration: duration,
              );

              // 调用回调函数
              onFileSelected?.call(metadata);

              // 显示音频发送成功的提示
              toastService.showToast(
                '${'chat_audioRecording'.tr}: ${formatDuration(duration)}',
              );
            } catch (e) {
              debugPrint('处理音频时出错: $e');
              toastService.showToast('${'chat_recordingFailed'.tr}: $e');
            }
          },
        ),
  );
}

/// 构造音频消息的标准化元数据（本地文件与 Web 字节录音共用）
Map<String, dynamic> _buildAudioMetadata(
  String storagePath, {
  required String fileName,
  required int size,
  required Duration duration,
}) {
  final extension = path.extension(fileName).isEmpty
      ? '.webm'
      : path.extension(fileName);
  return {
    'fileInfo': {
      'id': const Uuid().v4(),
      'name': fileName,
      'originalName': fileName,
      'path': storagePath,
      'size': size,
      'extension': extension,
      'mimeType': 'audio/${extension.replaceAll('.', '')}',
      'type': 'audio',
      'isAudio': true,
      'duration': duration.inSeconds,
      'createdAt': DateTime.now().toIso8601String(),
    },
    'senderInfo': {
      'userId': 'current_user_id',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    },
  };
}
