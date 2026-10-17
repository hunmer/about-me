import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/walk_stack_card.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/file_preview/file_preview_screen.dart';

/// 多视频消息渲染：一次发送的多段视频折叠为 WalkStackCard 卡片堆，
/// 一视频一卡（卡面为伴生首帧缩略图 `<name>.thumb.jpg` + 播放角标，
/// 缩略图缺失/在线 URL 时以图标占位兜底），
/// 点击卡片用 FilePreviewScreen 播放该视频，左下角 "+N" 角标提示总数，
/// 拖拽顶层卡飞出切换下一段。
/// fileInfo['videos'] 为视频路径列表（'./' 相对路径或 http URL）。
class VideoStackMessageWidget extends StatelessWidget {
  final Message message;
  final bool isOutgoing;

  /// 聊天气泡内的卡片缩放（与 ImageStackMessageWidget 一致）
  static const double _cardScale = 0.62;

  const VideoStackMessageWidget({
    super.key,
    required this.message,
    this.isOutgoing = false,
  });

  /// 本地视频的伴生首帧缩略图路径（沿用 `<name>.thumb` 命名约定），
  /// 在线 URL 无缩略图返回 null
  String? _thumbPathOf(String videoPath) {
    if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
      return null;
    }
    final dir = path.dirname(videoPath);
    final name = path.basenameWithoutExtension(videoPath);
    return '$dir/$name.thumb.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final fileInfo =
        message.metadata?[Message.metadataKeyFileInfo]
            as Map<String, dynamic>?;
    final videosRaw = fileInfo?['videos'] as List?;
    final videos =
        videosRaw?.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() ??
        const <String>[];
    if (videos.isEmpty) return const SizedBox.shrink();

    // 一视频一卡：卡面内容与播放目标都对应同一段视频
    final cards = <WalkStackCardData>[
      for (var i = 0; i < videos.length; i++)
        WalkStackCardData(
          id: 'stack_${message.id}_$i',
          // cardBuilder 模式下不渲染纸面，quote 仅作占位数据
          quote: '',
          imagePaths: [videos[i]],
        ),
    ];

    return WalkStackCardWidget(
      cards: cards,
      size: const SmallSize(scale: _cardScale),
      // 与多图卡片堆一致：气泡内容较纯色，省 BackdropFilter 开销
      frosted: false,
      cardBuilder: (context, card) => _buildCardFace(context, card, videos),
    );
  }

  /// 卡面：首帧缩略图 + 播放角标 + 左下 "+N" 视频数角标；
  /// 点击播放该视频（与单视频消息点击行为一致）
  Widget _buildCardFace(
    BuildContext context,
    WalkStackCardData card,
    List<String> videos,
  ) {
    final videoPath = card.imagePaths.first;
    final index = videos.indexOf(videoPath);
    final theme = DSThemeBridge.resolve(context);
    final thumbPath = _thumbPathOf(videoPath);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _preview(context, videoPath),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 铺满卡片：首帧缩略图，缺失或解码失败时图标占位
          if (thumbPath != null)
            Image(
              image: ImageUtils.createImageProvider(thumbPath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _videoFallback(theme),
            )
          else
            _videoFallback(theme),
          // 居中播放角标
          Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
              ),
              child: const Center(
                child: DsIcon(DsIconKind.play, size: 24, color: Colors.white),
              ),
            ),
          ),
          // 左下角 "+N" 视频数量角标
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsIcon(DsIconKind.video, size: 12, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    '+${videos.length}',
                    style: DsTypography.caption.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 后层渐显提示（与堆叠层数一致）；顶层不显示剩余数避免与 +N 重复
          if (index >= 0 && videos.length > 1)
            Positioned(
              right: 8,
              bottom: 8,
              child: Text(
                '${index + 1}/${videos.length}',
                style: DsTypography.caption.copyWith(
                  color: theme.textSub,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 与单视频消息一致的预览（播放）行为
  void _preview(BuildContext context, String videoPath) {
    final fileInfo =
        message.metadata?[Message.metadataKeyFileInfo]
            as Map<String, dynamic>?;
    NavigationHelper.push(
      context,
      FilePreviewScreen(
        filePath: videoPath,
        fileName: (fileInfo?['name'] as String?) ?? '视频',
        mimeType: (fileInfo?['mimeType'] as String?) ?? 'video/mp4',
        fileSize: (fileInfo?['fileSize'] as int?) ??
            (fileInfo?['size'] as int?) ??
            0,
      ),
    );
  }

  Widget _videoFallback(AppThemeData theme) {
    return Container(
      color: theme.primary.mixWhite(0.85),
      child: Center(
        child: DsIcon(DsIconKind.video, size: 26, color: theme.primary),
      ),
    );
  }
}
