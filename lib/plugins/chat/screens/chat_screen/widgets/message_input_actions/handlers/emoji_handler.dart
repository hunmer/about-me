import 'dart:math' as math;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/chat/services/file_service.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:material_emoji_picker/material_emoji_picker.dart';
import 'types.dart';

/// 内置表情资源目录（assets/emojis 下的图片作为表情包）
const String kBuiltInEmojiAssetDir = 'assets/emojis';

/// 内置表情在 Emoji.value 中的标记前缀，用于与 Unicode 表情区分
const String kBuiltInEmojiPrefix = 'aboutme_emoji:';

/// 打开表情选择器底部抽屉：
/// - 内置表情（assets/emojis 下的图片）选中后作为图片附件添加，等待发送
/// - Unicode 表情直接插入输入框光标处
Future<void> handleEmojiSelection({
  required BuildContext context,
  required FileService fileService,
  required OnFileSelected? onFileSelected,
  TextEditingController? textController,
}) async {
  final emojiAssets = await _loadBuiltInEmojiAssets();
  if (!context.mounted) return;

  // 适配小屏：选择器高度不超过屏幕高度的 70%
  final sheetHeight = math.min(480.0, MediaQuery.of(context).size.height * 0.7);

  await SmoothBottomSheet.show(
    context: context,
    builder:
        (sheetContext) => SizedBox(
          height: sheetHeight,
          width: double.infinity,
          child: ProviderScope(
            child: EmojiPicker(
              prependCategories: [_buildBuiltInCategory(emojiAssets)].lock,
              onSelection: (value, isFreeText) {
                if (value.startsWith(kBuiltInEmojiPrefix)) {
                  Navigator.of(sheetContext).pop();
                  _sendBuiltInEmojiAsImage(
                    fileService: fileService,
                    onFileSelected: onFileSelected,
                    assetPath: value.substring(kBuiltInEmojiPrefix.length),
                  );
                } else {
                  _insertTextAtCursor(textController, value);
                }
              },
            ),
          ),
        ),
  );
}

/// 枚举内置表情资源（assets/emojis 目录）
Future<List<String>> _loadBuiltInEmojiAssets() async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets =
        manifest
            .listAssets()
            .where(
              (asset) =>
                  asset.startsWith('$kBuiltInEmojiAssetDir/') &&
                  asset.toLowerCase().endsWith('.png'),
            )
            .toList()
          ..sort();
    return assets;
  } catch (e) {
    debugPrint('加载内置表情资源失败: $e');
    return const [];
  }
}

/// 构建内置表情分类
EmojiCategory _buildBuiltInCategory(List<String> assets) {
  final nameOf =
      (String asset) => path.basenameWithoutExtension(asset).replaceAll('_', ' ');

  return EmojiCategory(
    icon: Image.asset(
      assets.isNotEmpty ? assets.first : '',
      width: 20,
      height: 20,
      errorBuilder: (_, _, _) => const Icon(Icons.emoji_emotions, size: 20),
    ),
    name: '内置表情',
    emojis: assets
        .map(
          (asset) => Emoji(
            widget: Image.asset(asset, fit: BoxFit.contain),
            value: '$kBuiltInEmojiPrefix$asset',
            aliases: [path.basenameWithoutExtension(asset)].lock,
            description: nameOf(asset),
            tags: const ['表情', 'emoji'].lock,
          ),
        )
        .toIList(),
  );
}

/// 将内置表情图片保存为聊天附件并选中（走图片附件发送通道）
Future<void> _sendBuiltInEmojiAsImage({
  required FileService fileService,
  required OnFileSelected? onFileSelected,
  required String assetPath,
}) async {
  try {
    final name = path.basename(assetPath);
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    final storagePath = await fileService.saveImageBytes(bytes, name);

    final Map<String, dynamic> metadata = {
      'fileInfo': {
        'id': const Uuid().v4(),
        'name': name,
        'originalName': name,
        'path': storagePath,
        'size': bytes.length,
        'extension': path.extension(name).toLowerCase(),
        'mimeType': 'image/${path.extension(name).replaceAll('.', '').isEmpty ? 'png' : path.extension(name).replaceAll('.', '')}',
        'type': 'image',
        'isImage': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      'senderInfo': {
        'userId': 'current_user_id',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    };
    onFileSelected?.call(metadata);
  } catch (e) {
    debugPrint('内置表情发送失败: $e');
    toastService.showToast('表情发送失败: $e');
  }
}

/// 在光标处插入文本（Unicode 表情）
void _insertTextAtCursor(TextEditingController? controller, String text) {
  if (controller == null) return;
  final selection = controller.selection.isValid
      ? controller.selection
      : TextSelection.collapsed(offset: controller.text.length);
  final newText = controller.text.replaceRange(
    selection.start,
    selection.end,
    text,
  );
  controller.value = controller.value.copyWith(
    text: newText,
    selection: TextSelection.collapsed(offset: selection.start + text.length),
  );
}
