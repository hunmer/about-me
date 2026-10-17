import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/file_preview/file_preview_screen.dart';

/// 视频消息渲染：以伴生首帧缩略图 `<name>.thumb.jpg` 作封面（16:9）展示，
/// 覆盖播放角标，点击用 FilePreviewScreen 播放；
/// 封面缺失（在线 URL / 桌面端未生成缩略图）时以图标占位兜底。
///
/// 封面解析 future 在 State 内缓存（与 ImageMessageWidget 一致）：
/// 父级重建（如卡片堆切卡的层重建）不会重跑解析导致闪 loading，
/// 仅 videoPath / message 变化时重解析。
class VideoMessageWidget extends StatefulWidget {
  final Message message;
  final bool isOutgoing;

  /// 覆盖展示的视频路径（默认取 fileInfo['path']；
  /// 多视频卡片堆复用同一 message 时按卡指定）
  final String? videoPath;

  const VideoMessageWidget({
    super.key,
    required this.message,
    this.isOutgoing = false,
    this.videoPath,
  });

  @override
  State<VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<VideoMessageWidget> {
  Map<String, dynamic>? get fileInfo =>
      widget.message.metadata?[Message.metadataKeyFileInfo]
          as Map<String, dynamic>?;

  /// 封面解析结果（null 表示无封面，占位兜底）
  late Future<ImageProvider?> _future;
  bool _resolved = false;

  String get _displayPath =>
      widget.videoPath ?? (fileInfo?['path'] as String? ?? '');

  /// 在 didChangeDependencies 中初始化（与 ImageMessageWidget 一致）：
  /// 首次依赖可用时再创建；仅 videoPath / message 变化时重解析
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_resolved) {
      _resolved = true;
      _future = _resolveCover();
    }
  }

  @override
  void didUpdateWidget(VideoMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_resolved &&
        (widget.videoPath != oldWidget.videoPath ||
            widget.message != oldWidget.message)) {
      _future = _resolveCover();
    }
  }

  /// 本地视频的伴生首帧缩略图（沿用 `<name>.thumb` 命名约定，统一 jpg），
  /// 在线 URL / 文件不存在返回 null
  Future<ImageProvider?> _resolveCover() async {
    final filePath = _displayPath;
    if (filePath.isEmpty) return null;
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return null;
    }
    final dir = path.dirname(filePath);
    final name = path.basenameWithoutExtension(filePath);
    final thumbPath = '$dir/$name.thumb.jpg';
    try {
      final absolutePath = await ImageUtils.getAbsolutePath(thumbPath);
      if (!await File(absolutePath).exists()) return null;
      return ImageUtils.createImageProvider(thumbPath);
    } catch (e) {
      debugPrint('解析视频封面失败: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = fileInfo;
    if (info == null) {
      return const SizedBox.shrink();
    }

    final theme = DSThemeBridge.resolve(context);

    return FutureBuilder<ImageProvider?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: DSLoadingDots(color: theme.textSub),
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _preview,
          child: _buildFrame(
            context,
            theme,
            Stack(
              children: [
                // 底层封面决定尺寸（16:9），角标 Positioned.fill 居中覆盖
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child:
                      snapshot.data != null
                          ? Image(
                            image: snapshot.data!,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, _, _) => _placeholderBody(theme),
                          )
                          : _placeholderBody(theme),
                ),
                Positioned.fill(child: Center(child: _buildPlayBadge())),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 视频消息外框（与图片消息一致）
  Widget _buildFrame(BuildContext context, AppThemeData theme, Widget child) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
        maxHeight: 200,
      ),
      decoration: BoxDecoration(
        color:
            widget.isOutgoing
                ? theme.primary.withValues(alpha: 0.1)
                : theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.stroke.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }

  Widget _buildPlayBadge() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.35),
      ),
      child: const Center(
        child: DsIcon(DsIconKind.play, size: 24, color: Colors.white),
      ),
    );
  }

  /// 无封面占位：图标 + 文件名（铺满 16:9 卡面）
  Widget _placeholderBody(AppThemeData theme) {
    final fileName = fileInfo?['name'] as String? ?? '视频';
    return Container(
      color: theme.primary.mixWhite(0.85),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(DsIconKind.video, size: 32, color: theme.primary),
          const SizedBox(height: 8),
          Text(
            fileName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }

  /// 与文件消息一致的预览（播放）行为
  void _preview() {
    final filePath = _displayPath;
    if (filePath.isEmpty) return;
    final info = fileInfo;
    NavigationHelper.push(
      context,
      FilePreviewScreen(
        filePath: filePath,
        fileName: (info?['name'] as String?) ?? '视频',
        mimeType: (info?['mimeType'] as String?) ?? 'video/mp4',
        fileSize:
            (info?['fileSize'] as int?) ??
            (info?['size'] as int?) ??
            0,
      ),
    );
  }
}
