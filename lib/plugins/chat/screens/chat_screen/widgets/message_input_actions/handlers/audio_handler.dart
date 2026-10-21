import 'dart:io';
import 'dart:math' as math;
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
          onStopBytes: (bytes, fileName, duration, amplitudes) async {
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
                amplitudes: amplitudes,
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
          onStop: (File audioFile, Duration duration, List<double> amplitudes) async {
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
                amplitudes: amplitudes,
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
  List<double> amplitudes = const [],
}) {
  final extension = path.extension(fileName).isEmpty
      ? '.webm'
      : path.extension(fileName);
  final waveform = _buildWaveform(amplitudes);
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
      if (waveform.isNotEmpty) 'waveform': waveform,
      'createdAt': DateTime.now().toIso8601String(),
    },
    'senderInfo': {
      'userId': 'current_user_id',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    },
  };
}

/// 振幅采样（dBFS，约 -45 静音 ~ 0 最响）重采样为固定根数的波形高度（7~25），
/// 与深色语音卡片的默认波形高度范围一致
List<int> _buildWaveform(List<double> amplitudes, {int bars = 70}) {
  if (amplitudes.isEmpty) return const [];
  // 按时间均分到各桶，取桶内最大响度
  final peaks = List<double>.filled(bars, -45.0);
  for (var i = 0; i < amplitudes.length; i++) {
    final b = (i * bars / amplitudes.length).floor().clamp(0, bars - 1);
    if (amplitudes[i] > peaks[b]) peaks[b] = amplitudes[i];
  }
  final norms = peaks.map((db) => (((db + 45) / 45).clamp(0.0, 1.0))).toList();
  final peak = norms.reduce(math.max);
  // 相对峰值归一化 + 幂次压低弱音，让波形层次接近 demo 观感
  return norms
      .map((v) => (7 + 18 * math.pow(peak > 0 ? v / peak : 0.0, 1.4)).round())
      .toList();
}
