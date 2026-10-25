import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'live2d_online_models.dart';

/// 导入模型记录 → JSON（持久化在 Live2DPlugin settings 的 importedModels）
Map<String, dynamic> importedModelToJson(Live2DModelDefinition model) => {
  'label': model.label,
  'modelDir': model.modelDir,
  'modelFile': model.modelFile,
  if (model.thumbPath != null) 'thumbPath': model.thumbPath,
  'motions': [
    for (final motion in model.motions)
      {
        'group': motion.group,
        'index': motion.index,
        'label': motion.label,
        'hasSound': motion.hasSound,
      },
  ],
};

Live2DModelDefinition importedModelFromJson(Map<String, dynamic> json) =>
    Live2DModelDefinition(
      label: json['label'] as String? ?? '',
      modelDir: json['modelDir'] as String? ?? '',
      modelFile: json['modelFile'] as String? ?? '',
      thumbPath: json['thumbPath'] as String?,
      motions: [
        for (final motion in (json['motions'] as List? ?? const []))
          if (motion is Map)
            Live2DMotionDefinition(
              group: motion['group']?.toString() ?? '',
              index: (motion['index'] as num?)?.toInt() ?? 0,
              label: motion['label']?.toString() ?? '',
              hasSound: motion['hasSound'] == true,
            ),
      ],
    );

/// Live2D 压缩包导入：选择 zip 解压到应用目录，
/// 扫描其中的 .model3.json 生成可加载的模型定义
class Live2DZipImport {
  Live2DZipImport._();

  /// 选择并导入 zip：返回压缩包内全部可用模型（按目录深度排序），
  /// 用户取消返回 null，压缩包无效返回空列表
  static Future<List<Live2DModelDefinition>?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'live2d_importZipPickerTitle'.tr,
    );
    final picked = result?.files.singleOrNull;
    if (picked == null) return null;
    final bytes = picked.path == null
        ? picked.bytes
        : await File(picked.path!).readAsBytes();
    if (bytes == null) return const [];
    return importBytes(bytes, zipName: picked.name);
  }

  /// 解压 [bytes] 并返回其中的模型定义；解压失败抛异常，无模型返回空列表。
  /// [targetDir] 缺省解压到应用目录，测试可注入临时目录
  static Future<List<Live2DModelDefinition>> importBytes(
    List<int> bytes, {
    required String zipName,
    Directory? targetDir,
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final zipLabel = p.basenameWithoutExtension(zipName);
    Directory target;
    if (targetDir != null) {
      target = targetDir;
    } else {
      final root = await getApplicationSupportDirectory();
      target = Directory(
        p.join(root.path, 'live2d_models', 'zip_${const Uuid().v4()}'),
      );
    }
    final modelFiles = <File>[];
    try {
      await target.create(recursive: true);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final relative = _normalizeEntryName(entry.name);
        if (relative == null) continue;
        final file = File(p.join(target.path, relative));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.content as List<int>, flush: true);
        if (relative.toLowerCase().endsWith('.model3.json')) {
          modelFiles.add(file);
        }
      }
    } catch (error) {
      // 半途解压失败时清理残留目录，避免占用磁盘
      try {
        await target.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
    if (modelFiles.isEmpty) {
      await target.delete(recursive: true);
      return const [];
    }

    // 多模型压缩包按目录深度排序，浅层优先作为默认项
    modelFiles.sort((a, b) {
      final da = p.split(a.parent.path).length;
      final db = p.split(b.parent.path).length;
      if (da != db) return da - db;
      return a.path.compareTo(b.path);
    });

    final definitions = <Live2DModelDefinition>[];
    for (final file in modelFiles) {
      final modelName = p.basenameWithoutExtension(
        p.basenameWithoutExtension(file.path),
      );
      Map<String, dynamic>? modelJson;
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) modelJson = decoded;
      } catch (error) {
        debugPrint('[Live2DZipImport] skip invalid ${file.path}: $error');
      }
      definitions.add(
        Live2DModelDefinition(
          label: definitions.isEmpty
              ? zipLabel
              : '$zipLabel · $modelName',
          modelDir: '${file.parent.path}/',
          modelFile: p.basename(file.path),
          motions: modelJson == null
              ? const []
              : Live2DOnlineCatalog.parseMotions(modelJson),
        ),
      );
    }
    return definitions;
  }

  /// 规范化压缩包内路径：反斜杠转正斜杠、拒绝目录穿越/绝对路径，
  /// 过滤 macOS 打包垃圾文件（__MACOSX、.DS_Store 等）
  static String? _normalizeEntryName(String name) {
    final normalized = name.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) {
      return null;
    }
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty && segment != '.')
        .toList();
    if (segments.isEmpty || segments.contains('..')) return null;
    if (segments.first == '__MACOSX' ||
        segments.any((segment) => segment == '.DS_Store')) {
      return null;
    }
    return segments.join('/');
  }
}
