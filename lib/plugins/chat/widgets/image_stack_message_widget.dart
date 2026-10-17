import 'package:flutter/material.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/widgets/image_message_widget.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/walk_stack_card.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';

/// 多图消息渲染：一次发送的多张图片折叠为 WalkStackCard 卡片堆，
/// 一图一卡（卡面复用 [ImageMessageWidget]，继承图片加载与错误兜底），
/// 点击卡片用 GalleryViewer 全屏预览该图（可左右切换全部图片），
/// 左下角 "+N" 角标提示总张数，
/// 拖拽顶层卡飞出切换下一张。
/// fileInfo['images'] 为图片路径列表（'./' 相对路径或 http URL）。
class ImageStackMessageWidget extends StatelessWidget {
  final Message message;
  final bool isOutgoing;

  /// 聊天气泡内的卡片缩放（基准卡 282×348，0.62 档适配气泡宽度）
  static const double _cardScale = 0.62;

  const ImageStackMessageWidget({
    super.key,
    required this.message,
    this.isOutgoing = false,
  });

  @override
  Widget build(BuildContext context) {
    final fileInfo =
        message.metadata?[Message.metadataKeyFileInfo]
            as Map<String, dynamic>?;
    final imagesRaw = fileInfo?['images'] as List?;
    final images =
        imagesRaw?.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() ??
        const <String>[];
    if (images.isEmpty) return const SizedBox.shrink();

    // 一图一卡：卡面内容与预览目标都对应同一张图
    final cards = <WalkStackCardData>[
      for (var i = 0; i < images.length; i++)
        WalkStackCardData(
          id: 'stack_${message.id}_$i',
          // cardBuilder 模式下不渲染纸面，quote/signature 仅作占位数据
          quote: '',
          imagePaths: [images[i]],
        ),
    ];

    return WalkStackCardWidget(
      cards: cards,
      size: const SmallSize(scale: _cardScale),
      // 气泡内容较纯色，磨砂意义不大且省 BackdropFilter 开销
      frosted: false,
      cardBuilder: (context, card) => _buildCardFace(context, card, images),
    );
  }

  /// 卡面：ImageMessageWidget（按卡覆盖图片路径）+ 左下 "+N" 照片数角标；
  /// 点击打开该图的文件预览（与单图消息点击行为一致）
  Widget _buildCardFace(
    BuildContext context,
    WalkStackCardData card,
    List<String> images,
  ) {
    final path = card.imagePaths.first;
    final index = images.indexOf(path);
    final theme = DSThemeBridge.resolve(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _preview(context, images, path),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 铺满卡片：父级 SizedBox 严格约束覆盖 _buildFrame 的 maxWidth
          ImageMessageWidget(message: message, isOutgoing: isOutgoing, imagePath: path),
          // 左下角 "+N" 照片数量角标（替代原拍立得挂件位）
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
                  DsIcon(DsIconKind.image, size: 12, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    '+${images.length}',
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
          if (index >= 0 && images.length > 1)
            Positioned(
              right: 8,
              bottom: 8,
              child: Text(
                '${index + 1}/${images.length}',
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

  /// 与单图消息/timeline 一致的预览行为：
  /// 传入同消息全部图片，预览内可左右切换
  void _preview(BuildContext context, List<String> images, String path) {
    final fileInfo =
        message.metadata?[Message.metadataKeyFileInfo]
            as Map<String, dynamic>?;
    NavigationHelper.push(
      context,
      GalleryViewer(
        title: (fileInfo?['name'] as String?) ?? '图片',
        entranceAnimation: true,
        showFileActions: true,
        photos: [
          for (final p in images) GalleryPhoto(url: p, caption: p),
        ],
        initialIndex: images.indexOf(path).clamp(0, images.length - 1),
      ),
    );
  }
}
