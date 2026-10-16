import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/chat/models/file_message.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/types.dart';
import 'package:aboutme/plugins/chat/services/file_service.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/picker/video_picker_dialog.dart';

/// 选择视频（VideoPickerDialog：存储网格 + 相册/录像/在线URL）
/// [multiple=true] 供长按多选入口，可一次选多段
Future<void> handleLocalVideoSelection({
  required BuildContext context,
  required FileService fileService,
  required OnFileSelected? onFileSelected,
  bool multiple = false,
}) async {
  try {
    final result = await VideoPickerDialog.show<dynamic>(
      context,
      saveDirectory: 'chat/chat_files',
      multiple: multiple,
    );
    if (result == null) return;

    // 单选返回 Map，多选返回 List<Map>，统一成列表逐个处理
    final List<Map<String, dynamic>> items =
        result is List
            ? result
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : [Map<String, dynamic>.from(result as Map)];

    for (final item in items) {
      final url = item['url'] as String?;
      if (url == null || url.isEmpty) continue;
      debugPrint('视频选择完成: $url');

      try {
        final metadata = _isHttpUrl(url)
            ? _buildHttpVideoMetadata(url)
            : await _buildLocalVideoMetadata(url);
        onFileSelected?.call(metadata);
      } catch (e) {
        toastService.showToast(
          '${'chat_videoProcessingFailed'.tr}: $e',
        );
      }
    }
  } catch (e) {
    toastService.showToast(
      '${'chat_videoSelectionFailed'.tr}: $e',
    );
  }
}

bool _isHttpUrl(String url) =>
    url.startsWith('http://') || url.startsWith('https://');

/// 在线视频 URL 不落盘，消息直接引用远程地址
Map<String, dynamic> _buildHttpVideoMetadata(String url) {
  final nameFromUrl = url.split('/').last.split('?').first;
  final fileName = nameFromUrl.isEmpty ? 'video.mp4' : nameFromUrl;
  final ext =
      path.extension(fileName).isEmpty ? '.mp4' : path.extension(fileName);

  return {
    'fileInfo': {
      'id': const Uuid().v4(),
      'name': fileName,
      'originalName': fileName,
      'path': url,
      'size': 0,
      'extension': ext,
      'mimeType': 'video/${ext.replaceAll('.', '')}',
      'type': 'video',
      'isImage': false,
      'createdAt': DateTime.now().toIso8601String(),
    },
    'senderInfo': {
      'userId': 'current_user',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    },
  };
}

/// 存储内视频已在选择器内落盘，这里仅构造消息元数据
Future<Map<String, dynamic>> _buildLocalVideoMetadata(
  String relativePath,
) async {
  final absolutePath = await ImageUtils.getAbsolutePath(relativePath);
  final videoFile = File(absolutePath);

  if (!await videoFile.exists()) {
    throw Exception('chat_videoFileNotExist'.tr);
  }

  final originalFileName = path.basename(absolutePath);
  final fileMessage = await FileMessage.fromFile(
    videoFile,
    originalFileName: originalFileName,
  );

  return {
    'fileInfo': {
      'id': fileMessage.id,
      'name': fileMessage.fileName,
      'originalName': fileMessage.originalFileName,
      'path': fileMessage.filePath,
      'size': fileMessage.fileSize,
      'extension': fileMessage.extension,
      'mimeType': 'video/${fileMessage.extension.replaceAll('.', '')}',
      'type': 'video',
      'isImage': false,
      'createdAt': DateTime.now().toIso8601String(),
    },
    'senderInfo': {
      'userId': 'current_user',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    },
  };
}
