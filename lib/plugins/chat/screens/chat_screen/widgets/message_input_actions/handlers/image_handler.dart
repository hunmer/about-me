import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/chat/models/file_message.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_input_actions/types.dart';
import 'package:aboutme/plugins/chat/services/file_service.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';

/// 选择图片（multiple=true 供长按多选入口，可一次选多张）
Future<void> handleImageSelection({
  required BuildContext context,
  required FileService fileService,
  required OnFileSelected? onFileSelected,
  required bool fromCamera,
  bool multiple = false,
}) async {
  try {
    // 使用 ImagePickerDialog 并启用压缩
    final result = await ImagePickerDialog.show<dynamic>(
      context,
      enableCompression: true,
      compressionQuality: 85,
      multiple: multiple,
    );
    if (result == null) return;

    // 单选返回 Map，多选返回 List<Map>，统一成列表逐张处理
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
      debugPrint('图片选择完成: $url');

      try {
        final metadata =
            _isHttpUrl(url)
                ? _buildHttpImageMetadata(url)
                : await _buildLocalImageMetadata(
                  url,
                  item['thumbUrl'] as String?,
                );
        onFileSelected?.call(metadata);
      } catch (e) {
        toastService.showToast(
          '${'chat_imageProcessingFailed'.tr}: $e',
        );
      }
    }
  } catch (e) {
    toastService.showToast(
      '${'chat_imageSelectionFailed'.tr}: $e',
    );
  }
}

bool _isHttpUrl(String url) =>
    url.startsWith('http://') || url.startsWith('https://');

/// http 图片不落盘，消息直接引用远程 URL（渲染层 NetworkImage 可显示），
/// 与图片选择器「在线图片」入口行为一致
Map<String, dynamic> _buildHttpImageMetadata(String url) {
  final nameFromUrl = url.split('/').last.split('?').first;
  final fileName = nameFromUrl.isEmpty ? 'image.jpg' : nameFromUrl;
  final ext =
      path.extension(fileName).isEmpty ? '.jpg' : path.extension(fileName);

  return {
    'fileInfo': {
      'id': const Uuid().v4(),
      'name': fileName,
      'originalName': fileName,
      'path': url,
      'thumbPath': null,
      'size': 0,
      'extension': ext,
      'mimeType': 'image/${ext.replaceAll('.', '')}',
      'type': 'image',
      'isImage': true,
      'createdAt': DateTime.now().toIso8601String(),
    },
    'senderInfo': {
      'userId': 'current_user', // 需要替换为实际用户ID
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    },
  };
}

Future<Map<String, dynamic>> _buildLocalImageMetadata(
  String relativePath,
  String? thumbUrl,
) async {
  final assetId = ImageUtils.sdkAssetId(relativePath);
  final FileMessage fileMessage;
  if (assetId != null) {
    final asset = await AboutmeDataService.instance.data.assets.getMetadata(assetId);
    fileMessage = FileMessage.fromAsset(asset, thumbPath: thumbUrl);
  } else {
    final absolutePath = await ImageUtils.getAbsolutePath(relativePath);
  final imageFile = File(absolutePath);

  if (!await imageFile.exists()) {
    throw Exception('chat_imageNotExist'.tr);
  }

  final originalFileName = path.basename(absolutePath);
  fileMessage = await FileMessage.fromFile(
    imageFile,
    originalFileName: originalFileName,
    thumbPath: thumbUrl,
  );
  }

  return {
    'fileInfo': {
      'id': fileMessage.id,
      'name': fileMessage.fileName,
      'originalName': fileMessage.originalFileName,
      'path': fileMessage.filePath,
      'thumbPath': fileMessage.thumbPath,
      'size': fileMessage.fileSize,
      'extension': fileMessage.extension,
      'mimeType': fileMessage.mimeType,
      'type': 'image',
      'isImage': true,
      'createdAt': DateTime.now().toIso8601String(),
    },
    'senderInfo': {
      'userId': 'current_user',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    },
  };
}
