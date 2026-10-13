import 'dart:math' as math;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/chat/models/sticker_collection.dart';
import 'package:aboutme/plugins/chat/screens/sticker_manager_screen.dart';
import 'package:aboutme/plugins/chat/services/file_service.dart';
import 'package:aboutme/plugins/chat/services/sticker_service.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:material_emoji_picker/material_emoji_picker.dart';
import '../types.dart';

import 'package:get/get.dart';
/// 内置表情资源目录（assets/emojis 下的图片作为表情包）
const String kBuiltInEmojiAssetDir = 'assets/emojis';

/// 方块表情资源目录（assets/emoji_faces 下的透明 WebP 表情）
const String kEmojiFaceAssetDir = 'assets/emoji_faces';

/// 内置表情在 Emoji.value 中的标记前缀，用于与 Unicode 表情/贴图区分
const String kBuiltInEmojiPrefix = 'aboutme_emoji:';

/// 贴图在 Emoji.value 中的标记前缀（后接存储相对路径）
const String kStickerPrefix = 'sticker:';

/// 打开表情选择器底部抽屉：
/// - 内置表情（assets/emojis 下的图片）选中后作为图片附件添加，等待发送
/// - 贴图合集（StickerService 管理）同样作为图片附件发送
/// - Unicode 表情直接插入输入框光标处
Future<void> handleEmojiSelection({
  required BuildContext context,
  required FileService fileService,
  required OnFileSelected? onFileSelected,
  TextEditingController? textController,
}) async {
  final emojiFaces = await _loadEmojiAssets(kEmojiFaceAssetDir);
  final emojiAssets = await _loadEmojiAssets(kBuiltInEmojiAssetDir);
  final stickerCollections = await StickerService.instance.listCollections();
  if (!context.mounted) return;

  // 适配小屏：选择器高度不超过屏幕高度的 70%
  final sheetHeight = math.min(520.0, MediaQuery.of(context).size.height * 0.7);

  await SmoothBottomSheet.show(
    context: context,
    builder:
        (sheetContext) => SizedBox(
          height: sheetHeight,
          width: double.infinity,
          child: ProviderScope(
            child: Column(
              children: [
                // 顶部工具条：贴图管理入口
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed:
                        () => Navigator.push(
                          sheetContext,
                          MaterialPageRoute(
                            builder: (_) => const StickerManagerScreen(),
                          ),
                        ),
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: Text('chat_stickerManager'.tr),
                  ),
                ),
                Expanded(
                  child: EmojiPicker(
                    prependCategories: [
                      _buildEmojiCategory(emojiFaces, '方块表情'),
                      _buildEmojiCategory(emojiAssets, '内置表情'),
                    ].lock,
                    appendCategories: _buildStickerCategories(
                      stickerCollections,
                    ),
                    onSelection: (value, isFreeText) {
                      if (value.startsWith(kBuiltInEmojiPrefix)) {
                        Navigator.of(sheetContext).pop();
                        _sendBuiltInEmojiAsImage(
                          fileService: fileService,
                          onFileSelected: onFileSelected,
                          assetPath: value.substring(kBuiltInEmojiPrefix.length),
                        );
                      } else if (value.startsWith(kStickerPrefix)) {
                        Navigator.of(sheetContext).pop();
                        _sendStickerAsImage(
                          fileService: fileService,
                          onFileSelected: onFileSelected,
                          stickerPath: value.substring(kStickerPrefix.length),
                        );
                      } else {
                        _insertTextAtCursor(textController, value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
  );
}

/// 枚举表情资源目录（PNG/WebP 静态 + GIF 动图）
Future<List<String>> _loadEmojiAssets(String dir) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets =
        manifest
            .listAssets()
            .where((asset) {
              if (!asset.startsWith('$dir/')) return false;
              final lower = asset.toLowerCase();
              return lower.endsWith('.png') ||
                  lower.endsWith('.gif') ||
                  lower.endsWith('.webp');
            })
            .toList()
          ..sort();
    return assets;
  } catch (e) {
    debugPrint('加载表情资源失败: $e');
    return const [];
  }
}

/// 构建表情分类
EmojiCategory _buildEmojiCategory(List<String> assets, String categoryName) {
  String nameOf(String asset) =>
      path.basenameWithoutExtension(asset).replaceAll('_', ' ');

  return EmojiCategory(
    icon: Image.asset(
      assets.isNotEmpty ? assets.first : '',
      width: 20,
      height: 20,
      errorBuilder: (_, _, _) => const Icon(Icons.emoji_emotions, size: 20),
    ),
    name: categoryName,
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

/// 将贴图合集转为选择器分类（每个合集一个分类）
IList<EmojiCategory> _buildStickerCategories(
  List<StickerCollection> collections,
) {
  return collections
      .where((c) => c.stickerPaths.isNotEmpty)
      .map((collection) {
        final coverPath =
            collection.coverPath ??
            collection.stickerPaths.first;
        return EmojiCategory(
          icon: Image(
            image: ImageUtils.createImageProvider('./$coverPath'),
            width: 20,
            height: 20,
            errorBuilder:
                (_, _, _) => const Icon(Icons.emoji_emotions, size: 20),
          ),
          name: collection.name,
          emojis: collection.stickerPaths
              .map(
                (stickerPath) => Emoji(
                  widget: Image(
                    image: ImageUtils.createImageProvider('./$stickerPath'),
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, _, _) => const Icon(Icons.broken_image_outlined),
                  ),
                  value: '$kStickerPrefix$stickerPath',
                  aliases: [collection.name].lock,
                  description: collection.name,
                  tags: const ['贴图', 'sticker'].lock,
                ),
              )
              .toIList(),
        );
      })
      .toIList();
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
    await _attachImageBytes(
      fileService: fileService,
      onFileSelected: onFileSelected,
      name: name,
      bytes: bytes,
    );
  } catch (e) {
    debugPrint('内置表情发送失败: $e');
    toastService.showToast('表情发送失败: $e');
  }
}

/// 将贴图保存为聊天附件并选中（走图片附件发送通道）
Future<void> _sendStickerAsImage({
  required FileService fileService,
  required OnFileSelected? onFileSelected,
  required String stickerPath,
}) async {
  try {
    final bytes = await StickerService.instance.readStickerBytes(stickerPath);
    if (bytes == null) {
      toastService.showToast('贴图文件不存在或读取失败');
      return;
    }
    await _attachImageBytes(
      fileService: fileService,
      onFileSelected: onFileSelected,
      name: path.basename(stickerPath),
      bytes: bytes,
    );
  } catch (e) {
    debugPrint('贴图发送失败: $e');
    toastService.showToast('贴图发送失败: $e');
  }
}

/// 图片字节 → 聊天图片附件（与拍照/选图共用同一元数据结构）
Future<void> _attachImageBytes({
  required FileService fileService,
  required OnFileSelected? onFileSelected,
  required String name,
  required List<int> bytes,
}) async {
  final storagePath = await fileService.saveImageBytes(bytes, name);
  final ext = path.extension(name).toLowerCase();

  final Map<String, dynamic> metadata = {
    'fileInfo': {
      'id': const Uuid().v4(),
      'name': name,
      'originalName': name,
      'path': storagePath,
      'size': bytes.length,
      'extension': ext,
      'mimeType':
          'image/${ext.replaceAll('.', '').isEmpty ? 'png' : ext.replaceAll('.', '')}',
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
