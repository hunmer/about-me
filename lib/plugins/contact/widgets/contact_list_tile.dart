import 'package:flutter/material.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

import 'package:aboutme/plugins/contact/models/contact_model.dart';

/// 联系人列表行：手绘圆头像 + 姓名 + 组织副标题（skribble 纸墨风）
class ContactListTile extends StatelessWidget {
  const ContactListTile({
    super.key,
    required this.contact,
    required this.onTap,
    this.onLongPress,
    this.onToggleFavorite,
    this.seed = 1,
  });

  final Contact contact;
  final VoidCallback onTap;

  /// 长按（列表页快速删除等）
  final VoidCallback? onLongPress;

  /// 点击收藏星标切换收藏；为 null 时星标只读
  final VoidCallback? onToggleFavorite;

  /// 传列表索引让每行墨迹有变化
  final int seed;

  static const double height = 68;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (contact.isFavorite) ...[
                GestureDetector(
                  onTap: onToggleFavorite,
                  child: DsIcon(
                    DsIconKind.star,
                    size: 20,
                    color: theme.primary,
                    fill: true,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _buildAvatar(theme),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.body.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (contact.organization != null &&
                        contact.organization!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.organization!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              DsIcon(
                DsIconKind.chevronRight,
                size: 16,
                color: theme.textSub.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(AppThemeData theme) {
    final hasImage = contact.avatar != null && contact.avatar!.isNotEmpty;

    return Container(
      width: 48,
      height: 48,
      decoration: dsSketchDecoration(
        theme: theme,
        circle: true,
        fillColor: hasImage ? theme.surfaceAlt : contact.iconColor.withValues(alpha: 0.2),
        stroke: theme.ink.withValues(alpha: 0.55),
        strokeWidth: 1.6,
        seed: seed,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? AdaptiveImage(
              imagePath: contact.avatar,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            )
          : Icon(contact.icon, size: 22, color: contact.iconColor),
    );
  }
}
