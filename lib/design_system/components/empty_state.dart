import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'button.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 手绘空状态：大图标（手绘 DsIcon）/表情/SVG + 标题 + 说明 + 可选操作按钮
/// （对应设计稿「还没有记录哦」）
///
/// 全应用的空内容占位统一走这里，不要在页面里手写
/// `Center + Icon(64) + Text` 的散装占位。
class DSEmptyState extends StatelessWidget {
  const DSEmptyState({
    super.key,
    this.icon,
    this.emoji,
    this.svgAsset,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : assert(
         icon != null || emoji != null || svgAsset != null,
         'icon 与 emoji、svgAsset 至少提供一个',
       );

  /// 主视觉手绘图标（如 inbox），优先于 emoji / svgAsset
  final DsIconKind? icon;

  /// 主视觉表情（如 🐰）
  final String? emoji;

  /// 主视觉 SVG 资源路径（如 assets/icons/svg/tag.svg），优先于 emoji
  final String? svgAsset;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Center(
      child: Padding(
        // 宽区域/弹窗中兜底留白，避免按钮与文本贴边
        padding: EdgeInsets.all(theme.spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 表情底座：手绘圆盘
            JellyBox(
              width: 92,
              height: 92,
              radius: theme.radii.circle,
              color: theme.surfaceAlt,
              raised: true,
              alignment: Alignment.center,
              child: icon != null
                  ? DsIcon(icon!, size: 44, color: theme.textSub)
                  : svgAsset != null
                  ? SvgPicture.asset(
                      svgAsset!,
                      width: 44,
                      height: 44,
                      colorFilter: ColorFilter.mode(
                        theme.textSub,
                        BlendMode.srcIn,
                      ),
                    )
                  : Text(emoji!, style: const TextStyle(fontSize: 42)),
            ),
            SizedBox(height: theme.spacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DsTypography.heading.copyWith(color: theme.text),
            ),
            if (message != null) ...[
              SizedBox(height: theme.spacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ],
            if (actionLabel != null) ...[
              SizedBox(height: theme.spacing.lg),
              DSButton(
                label: actionLabel!,
                size: DSButtonSize.sm,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
