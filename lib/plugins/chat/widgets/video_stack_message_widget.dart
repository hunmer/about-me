import 'package:flutter/material.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/widgets/video_message_widget.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/walk_stack_card.dart';

/// 多视频消息渲染：一次发送的多段视频折叠为 WalkStackCard 卡片堆，
/// 一视频一卡（卡面复用 [VideoMessageWidget]，继承封面展示、播放角标
/// 与点击播放行为），左下角 "+N" 角标提示总段数，拖拽顶层卡飞出切换下一段。
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

  /// 卡面：VideoMessageWidget（封面 + 播放角标，自带点击播放）
  /// + 左下 "+N" 视频数角标 + 右下序号提示
  Widget _buildCardFace(
    BuildContext context,
    WalkStackCardData card,
    List<String> videos,
  ) {
    final videoPath = card.imagePaths.first;
    final index = videos.indexOf(videoPath);
    final theme = DSThemeBridge.resolve(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 铺满卡片：父级 SizedBox 严格约束覆盖 _buildFrame 的 maxWidth；
        // galleryPaths 传入全部视频，预览内可左右切换
        VideoMessageWidget(
          message: message,
          isOutgoing: isOutgoing,
          videoPath: videoPath,
          galleryPaths: videos,
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
    );
  }
}
