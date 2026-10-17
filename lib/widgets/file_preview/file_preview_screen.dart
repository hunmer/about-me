import 'dart:io' show File;
import 'package:aboutme/core/storage/storage_manager.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:get/get.dart';

class FilePreviewScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final bool isVideo;

  const FilePreviewScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    this.isVideo = false,
  });

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  late bool _isImage;
  late bool _isVideo;
  String _absoluteFilePath = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _isImage = widget.mimeType.startsWith('image/');
    _isVideo = widget.isVideo || widget.mimeType.startsWith('video/');
    _resolveFilePath();
  }

  Future<void> _resolveFilePath() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 解码 URI 编码的路径
      String resolvedPath = Uri.decodeFull(widget.filePath);

      // 统一路径分隔符为系统分隔符
      resolvedPath = resolvedPath
          .replaceAll('/', path.separator)
          .replaceAll(r'\\', path.separator);

      // 如果是相对路径（不是以系统分隔符开头），则转换为绝对路径
      if (!path.isAbsolute(resolvedPath)) {
        // 移除可能的 './' 前缀
        if (resolvedPath.startsWith('./') ||
            resolvedPath.startsWith('.${path.separator}')) {
          resolvedPath = resolvedPath.substring(2);
        }

        // 获取应用文档目录作为基础路径
        final appDocDir =
            await StorageManager.getApplicationDocumentsDirectory();
        String appDirPath = appDocDir.path;

        // 如果路径包含 app_data，确保正确处理
        if (!resolvedPath.contains('app_data')) {
          appDirPath = path.join(appDirPath, 'app_data');
        }

        resolvedPath = path.join(appDirPath, resolvedPath);
      }

      // 规范化路径（处理 .. 和 . 等特殊路径）
      _absoluteFilePath = path.normalize(resolvedPath);

      // 验证文件是否存在
      final file = File(_absoluteFilePath);
      final fileExists = await file.exists();
      debugPrint('文件路径: $_absoluteFilePath');
      if (!fileExists) {
        if (mounted) {
          Toast.error('file_preview_fileNotExist'.tr);
          // 清空文件路径，这样 _buildPreviewContent 会显示错误界面
          setState(() {
            _absoluteFilePath = '';
          });
        }
      } else {
        // 文件存在，更新状态
        setState(() {
          _absoluteFilePath = file.path;
        });
      }
    } catch (e) {
      if (mounted) {
        Toast.error(
          '${'file_preview_errorFilePreviewFailed'.tr}${e.toString()}',
        );
        // 出错时也清空文件路径
        setState(() {
          _absoluteFilePath = '';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 视频伴生首帧缩略图路径（沿用 `<name>.thumb.jpg` 命名约定），
  /// 供 GalleryViewer 缩略图条作封面，文件不存在时由查看器图标占位
  String? _videoThumbPath() {
    if (_absoluteFilePath.isEmpty) return null;
    final dir = path.dirname(_absoluteFilePath);
    final name = path.basenameWithoutExtension(_absoluteFilePath);
    return '$dir${path.separator}$name.thumb.jpg';
  }

  /// 分享与定位统一走 GalleryFileActions（与 GalleryViewer 顶栏同一实现）
  Future<void> _shareFile() {
    return GalleryFileActions.share(
      context,
      _absoluteFilePath,
      text: '分享文件：${widget.fileName}',
    );
  }

  Future<void> _showInFolder() {
    return GalleryFileActions.locate(
      context,
      _absoluteFilePath,
      fileName: widget.fileName,
    );
  }

  Widget _buildPreviewContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_absoluteFilePath.isEmpty || !File(_absoluteFilePath).existsSync()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 72,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'file_preview_errorFilePreviewFailed'.tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'file_preview_fileNotExist'.tr,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '文件路径: ${_absoluteFilePath.isEmpty ? "未设置" : _absoluteFilePath}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isImage) {
      // 图片预览：统一走 GalleryViewer（沉浸式 + 缩放），
      // 标题/分享/定位/关闭由内置 header 承载
      return GalleryViewer(
        title: widget.fileName,
        photos: [GalleryPhoto(url: _absoluteFilePath, caption: widget.fileName)],
        showFileActions: true,
        entranceAnimation: true,
      );
    } else if (_isVideo) {
      // 视频预览：统一走 GalleryViewer（内嵌播放器 + 封面缩略图）
      return GalleryViewer(
        title: widget.fileName,
        photos: [
          GalleryPhoto(
            url: _absoluteFilePath,
            caption: widget.fileName,
            isVideo: true,
            thumbUrl: _videoThumbPath(),
          ),
        ],
        showFileActions: true,
        entranceAnimation: true,
      );
    } else {
      // 普通文件预览
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_drive_file,
                size: 72,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                widget.fileName,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _formatFileSize(widget.fileSize),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.mimeType,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 媒体（图片/视频）预览由 GalleryViewer 内置 header 全屏承载
    // （标题 + 分享/定位/关闭），仅非媒体文件保留本屏 AppBar
    final isMediaPreview = _isImage || _isVideo;
    return Scaffold(
      appBar: isMediaPreview ? null : AppBar(
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '打开文件位置',
            onPressed: _showInFolder,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享文件',
            onPressed: _shareFile,
          ),
        ],
      ),
      body: _buildPreviewContent(),
    );
  }
}
