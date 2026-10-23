import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_compress_plus/image_compress_plus.dart';
import 'package:path/path.dart' as path;

/// 图片压缩任务
class ImageCompressionTask {
  final String sourcePath;
  final String targetPath;
  final int quality;

  /// 显式输出格式；null 时按源文件扩展名推断
  final CompressFormat? format;

  final Completer<String> completer;

  ImageCompressionTask({
    required this.sourcePath,
    required this.targetPath,
    required this.quality,
    this.format,
  }) : completer = Completer<String>();
}

/// 图片压缩服务
///
/// 提供队列化的图片压缩功能，避免同时压缩多个图片导致性能问题
class ImageCompressionService {
  static final ImageCompressionService _instance = ImageCompressionService._internal();
  factory ImageCompressionService() => _instance;
  ImageCompressionService._internal();

  final List<ImageCompressionTask> _taskQueue = [];
  bool _isProcessing = false;

  /// 添加压缩任务到队列
  ///
  /// [sourcePath] 源文件路径
  /// [targetPath] 目标文件路径（可选，默认覆盖源文件）
  /// [quality] 压缩质量 0-100（默认 85）
  /// [format] 显式输出格式（可选，默认按源文件扩展名推断）
  ///
  /// 返回压缩后的文件路径
  Future<String> compressImage({
    required String sourcePath,
    String? targetPath,
    int quality = 85,
    CompressFormat? format,
  }) async {
    // 如果没有指定目标路径，使用源文件路径
    final outputPath = targetPath ?? sourcePath;

    // 创建任务
    final task = ImageCompressionTask(
      sourcePath: sourcePath,
      targetPath: outputPath,
      quality: quality,
      format: format,
    );

    // 添加到队列
    _taskQueue.add(task);

    // 触发处理
    _processQueue();

    // 等待任务完成
    return task.completer.future;
  }

  /// 处理队列中的任务
  Future<void> _processQueue() async {
    if (_isProcessing || _taskQueue.isEmpty) {
      return;
    }

    _isProcessing = true;

    while (_taskQueue.isNotEmpty) {
      final task = _taskQueue.removeAt(0);

      try {
        final compressedPath = await _compressImageInternal(
          sourcePath: task.sourcePath,
          targetPath: task.targetPath,
          quality: task.quality,
          format: task.format,
        );
        task.completer.complete(compressedPath);
      } catch (e) {
        task.completer.completeError(e);
      }
    }

    _isProcessing = false;
  }

  /// 内部压缩实现
  Future<String> _compressImageInternal({
    required String sourcePath,
    required String targetPath,
    required int quality,
    CompressFormat? format,
  }) async {
    try {
      // Web 平台需在 index.html 引入 pica 才可用，暂不支持压缩，直接返回源文件路径
      if (kIsWeb) {
        debugPrint('Web 平台暂不支持图片压缩');
        return sourcePath;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('源文件不存在: $sourcePath');
      }

      // 确保目标目录存在
      final targetDir = Directory(path.dirname(targetPath));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // 确定输出格式：显式指定优先（如格式转换场景），否则按源文件扩展名推断
      final extension = path.extension(sourcePath).toLowerCase();
      CompressFormat outputFormat;
      if (format != null) {
        outputFormat = format;
      } else {
        switch (extension) {
          case '.png':
            outputFormat = CompressFormat.png;
          case '.webp':
            outputFormat = CompressFormat.webp;
          case '.heic':
            outputFormat = CompressFormat.heic;
          case '.jpg':
          case '.jpeg':
          default:
            outputFormat = CompressFormat.jpeg;
        }
      }

      // heic 仅移动端支持，桌面端（Windows/Linux/macOS）降级为 jpeg，
      // 同时目标路径扩展名改为 .jpg 保持与实际编码一致
      String outputPath = targetPath;
      if (outputFormat == CompressFormat.heic &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        outputFormat = CompressFormat.jpeg;
        if (path.extension(targetPath).toLowerCase() == '.heic') {
          outputPath = '${targetPath.substring(0, targetPath.length - 5)}.jpg';
        }
      }

      // 执行压缩
      final result = await ImageCompressPlus.compressAndGetFile(
        sourcePath,
        outputPath,
        quality: quality,
        format: outputFormat,
        // 保持原始方向
        keepExif: false,
        // 自动旋转
        autoCorrectionAngle: true,
      );

      if (result == null) {
        throw Exception('图片压缩失败: 返回结果为空');
      }

      debugPrint('图片压缩完成: $sourcePath -> $targetPath (质量: $quality)');
      return result.path;
    } catch (e) {
      debugPrint('图片压缩失败: $e');
      rethrow;
    }
  }

  /// 获取当前队列长度
  int get queueLength => _taskQueue.length;

  /// 是否正在处理任务
  bool get isProcessing => _isProcessing;

  /// 清空队列（慎用）
  void clearQueue() {
    for (final task in _taskQueue) {
      task.completer.completeError(Exception('任务已取消'));
    }
    _taskQueue.clear();
  }
}
