import 'dart:io';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:get/get.dart';
import '../../../utils/blob_url.dart';
import '../../../utils/image_utils.dart';

class VideoPreview extends StatefulWidget {
  final String filePath;

  const VideoPreview({super.key, required this.filePath});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      if (kIsWeb) {
        // Web 无本地文件系统：经存储读取字节(远端=HTTP解密/Web=IndexedDB)
        // 后包装为 blob URL 交给 video 元素播放
        final bytes = await ImageUtils.readStorageBytes(widget.filePath);
        if (bytes == null || bytes.isEmpty) {
          throw Exception('存储中不存在视频：${widget.filePath}');
        }
        _blobUrl = createBlobUrl(bytes, _guessMimeType(widget.filePath));
        _controller = VideoPlayerController.networkUrl(Uri.parse(_blobUrl!));
      } else {
        // 使用 PathUtils 转换路径（远端模式会物化到本地临时文件）
        final absolutePath = await ImageUtils.getAbsolutePath(widget.filePath);
        if (absolutePath.isEmpty) {
          throw Exception('无法获取视频文件的绝对路径');
        }

        final videoFile = File(absolutePath);
        if (!await videoFile.exists()) {
          throw Exception('视频文件不存在：$absolutePath');
        }

        debugPrint('正在初始化视频播放器，文件路径: $absolutePath');
        _controller = VideoPlayerController.file(videoFile);
      }

      // 初始化控制器
      await _controller.initialize();

      // 添加监听器以更新UI
      _controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('视频初始化错误: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isInitialized = false;
        });

        Toast.error(
          '${'app_videoLoadFailed'.tr}: ${e.toString()}',
        );
      }
    }
  }

  /// 根据扩展名推断视频 MIME 类型（浏览器 blob 播放需要）
  String _guessMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return switch (ext) {
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'ogg' || 'ogv' => 'video/ogg',
      _ => 'video/mp4',
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_blobUrl != null) revokeBlobUrl(_blobUrl!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'file_preview_videoLoadFailed'.tr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'app_loadingVideo'.tr,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    _PlayPauseOverlay(controller: _controller),
                  ],
                ),
              ),
            ),
          ),
        ),
        _VideoProgressIndicator(controller: _controller),
      ],
    );
  }
}

class _PlayPauseOverlay extends StatelessWidget {
  final VideoPlayerController controller;

  const _PlayPauseOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = controller.value.isPlaying;
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child:
              isPlaying
                  ? const SizedBox.shrink()
                  : Container(color: Colors.black26),
        ),
        GestureDetector(
          onTap: () {
            if (isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
          },
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ],
    );
  }
}

class _VideoProgressIndicator extends StatelessWidget {
  final VideoPlayerController controller;

  const _VideoProgressIndicator({required this.controller});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds'
        : '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final position = controller.value.position;
    final duration = controller.value.duration;
    final bool isPlaying = controller.value.isPlaying;

    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Theme.of(
                context,
              ).colorScheme.primary.withAlpha(76),
              thumbColor: Theme.of(context).colorScheme.primary,
            ),
            child: Slider(
              value: position.inMilliseconds.toDouble().clamp(
                0.0,
                duration.inMilliseconds.toDouble(),
              ),
              max: duration.inMilliseconds.toDouble(),
              onChanged: (value) {
                controller.seekTo(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: () {
                  if (isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
              ),
              Text(
                _formatDuration(duration),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
