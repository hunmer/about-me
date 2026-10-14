import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:aboutme/constants/app_icons.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 标签文件夹卡片
///
/// 磨砂玻璃文件夹造型：前盖板压住底部，前几张图片从开口处伸出并扇形堆叠，
/// 右下角可贴一个圆形贴纸（图标/emoji/图片），下方为标签名 + 图片数量。
class TagFolderCard extends StatelessWidget {
  const TagFolderCard({
    super.key,
    required this.tag,
    required this.imageUrls,
    required this.count,
    this.sticker,
  });

  /// 标签名
  final String tag;

  /// 堆放展示的图片（取前几张）
  final List<String> imageUrls;

  /// 该标签下的图片总数
  final int count;

  /// 右下角贴纸（可选）：
  /// - `emoji:<字符>` → emoji 文字
  /// - `img:<图片地址>` → 图片贴图
  /// - 其他 → AppIcons.predefinedIcons 的图标键
  final String? sticker;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final previews = imageUrls.take(3).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              // 前盖板顶部位置（上方留给伸出的图片）
              final panelTop = h * 0.26;
              final thumbW = w * 0.56;
              final thumbH = h * 0.62;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 扇形堆叠的图片（被前盖板压住下半部分）
                  for (var i = 0; i < previews.length; i++)
                    _buildFannedThumb(
                      index: i,
                      count: previews.length,
                      url: previews[i],
                      width: thumbW,
                      height: thumbH,
                      areaWidth: w,
                      theme: theme,
                    ),

                  // 空文件夹占位
                  if (previews.isEmpty)
                    Positioned(
                      left: w / 2 - thumbW / 2,
                      top: panelTop - thumbH * 0.30,
                      width: thumbW,
                      height: thumbH * 0.72,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.paper,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: DsIcon(
                            DsIconKind.image,
                            size: 22,
                            color: theme.textSub.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),

                  // 磨砂玻璃前盖板（含左上角 tab 凸起）
                  Positioned(
                    left: 0,
                    right: 0,
                    top: panelTop,
                    bottom: 0,
                    child: ClipPath(
                      clipper: _FolderFrontClipper(),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          color:
                              (theme.isDark ? theme.surfaceAlt : theme.surface)
                                  .withValues(alpha: theme.isDark ? 0.55 : 0.6),
                        ),
                      ),
                    ),
                  ),

                  // 右下角贴纸
                  if (sticker != null)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: _FolderSticker(sticker: sticker!, theme: theme),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // 标签名 + 数量
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsTypography.body.copyWith(
                  color: theme.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      ],
    );
  }

  /// 扇形堆放的单张缩略图：中间直立，两侧向外旋转
  Widget _buildFannedThumb({
    required int index,
    required int count,
    required String url,
    required double width,
    required double height,
    required double areaWidth,
    required AppThemeData theme,
  }) {
    // 相对中心的偏移档位：单张居中，两张左右，三张左中右
    final slot = index - (count - 1) / 2; // -1, 0, 1
    final angle = slot * 0.16; // 约 ±9°
    final dx = slot * width * 0.38;
    final top = height * 0.06 + slot.abs() * height * 0.05;

    return Positioned(
      left: areaWidth / 2 - width / 2 + dx,
      top: top,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          decoration: BoxDecoration(
            color: theme.paper,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.ink.withValues(alpha: 0.10)),
          ),
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: _FolderThumb(url: url, theme: theme),
          ),
        ),
      ),
    );
  }
}

/// 文件夹右下角圆形贴纸：emoji / 图片 / 图标三种形态
class _FolderSticker extends StatelessWidget {
  const _FolderSticker({required this.sticker, required this.theme});

  final String sticker;
  final AppThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isEmoji = sticker.startsWith('emoji:');
    final isImage = sticker.startsWith('img:');
    // 基于贴纸内容的伪随机角度（约 ±6°），同一贴纸角度稳定
    final angle = (sticker.hashCode % 21 - 10) * 0.01;
    final emoji = sticker.substring('emoji:'.length);

    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.paper,
          shape: BoxShape.circle,
          border: Border.all(color: theme.paper, width: 2.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Center(
          child:
              isEmoji
                  ? Stack(
                    children: [
                      // 底层描边 + 上层原字，形成贴纸白边
                      Text(
                        emoji,
                        style: TextStyle(
                          fontSize: 26,
                          foreground:
                              Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 2.5
                                ..color = theme.paper,
                        ),
                      ),
                      Text(emoji, style: const TextStyle(fontSize: 26)),
                    ],
                  )
                  : isImage
                  ? _FolderThumb(url: sticker.substring('img:'.length), theme: theme)
                  : Icon(
                    AppIcons.predefinedIcons[sticker] ?? Icons.label_outline,
                    size: 26,
                    color: theme.primaryText,
                  ),
        ),
      ),
    );
  }
}

/// 文件夹前盖板形状：圆角面板 + 左上角 tab 凸起
class _FolderFrontClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const r = 20.0; // 面板圆角
    const tabR = 9.0; // tab 顶部圆角
    final tabW = size.width * 0.42;
    const tabH = 13.0;

    return Path()
      ..moveTo(0, r + tabH)
      // 左侧上行进入 tab
      ..lineTo(0, tabR)
      ..arcToPoint(const Offset(tabR, 0), radius: const Radius.circular(tabR))
      ..lineTo(tabW - tabR - 6, 0)
      ..arcToPoint(
        Offset(tabW - 6, tabR),
        radius: const Radius.circular(tabR),
        clockwise: false,
      )
      // tab 右侧斜边落回面板顶边
      ..lineTo(tabW + 8, tabH)
      ..lineTo(size.width - r, tabH)
      ..arcToPoint(Offset(size.width, tabH + r), radius: const Radius.circular(r))
      ..lineTo(size.width, size.height - r)
      ..arcToPoint(
        Offset(size.width - r, size.height),
        radius: const Radius.circular(r),
      )
      ..lineTo(r, size.height)
      ..arcToPoint(Offset(0, size.height - r), radius: const Radius.circular(r))
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 文件夹内缩略图（网络/本地路径自适应）
class _FolderThumb extends StatelessWidget {
  const _FolderThumb({required this.url, required this.theme});

  final String url;
  final AppThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _fallback();

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }

    return FutureBuilder<String>(
      future: ImageUtils.getAbsolutePath(url),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path != null && path.isNotEmpty && File(path).existsSync()) {
          return Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          );
        }
        return _fallback();
      },
    );
  }

  Widget _fallback() {
    return Container(
      color: theme.surfaceAlt,
      child: Center(
        child: DsIcon(
          DsIconKind.image,
          size: 20,
          color: theme.textSub.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
