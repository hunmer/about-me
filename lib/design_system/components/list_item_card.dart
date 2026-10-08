import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';

/// 果冻列表卡片：标题/副标题 + 尾部信息，左上角带扇形标志
///
/// 标志（[icon] 或 [leading]）是贴在卡片左上角的实心四分之一圆：
/// 1:1 占位框，边长取卡片高度的一半（布局后测量，上限 70）。
/// 标志叠在面板之上，不作为行内元素占位——内容区仅为其让出左侧
/// 间距。面板为半透明描边圆角面板，透出页面背景实现融合。
class DSListItemCard extends StatefulWidget {
  const DSListItemCard({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.iconColor,
    this.trailing,
    this.trailingText,
    this.onTap,
  });

  final String title;

  /// 左上角标志图标（与 [leading] 二选一）
  final DsIconKind? icon;

  /// 左上角标志自定义内容（如 Material 图标），优先于 [icon]
  final Widget? leading;

  final String? subtitle;

  /// 标志扇形填充色（默认主题主色）
  final Color? iconColor;

  final Widget? trailing;

  /// 简单尾部文字（如时间、状态）
  final String? trailingText;

  final VoidCallback? onTap;

  @override
  State<DSListItemCard> createState() => _DSListItemCardState();
}

class _DSListItemCardState extends State<DSListItemCard> {
  final GlobalKey _panelKey = GlobalKey();

  /// 扇形标志边长（首帧布局后测得：卡片高度的一半，上限 70）
  double? _badgeSize;

  static const double _maxBadgeSize = 70;

  /// 首帧前的预估边长，避免内容避让间距跳变过大
  static const double _initialBadgeSize = 40;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final hasBadge = widget.leading != null || widget.icon != null;
    final radius = theme.radii.xl;
    final badgeSize = _badgeSize ?? _initialBadgeSize;

    // 布局后测量卡片高度：标志边长 = 高度一半（≤70）。内容避让
    // 随标志变化会反过来影响高度，仅在尺寸明显变化时重建，收敛
    // 后不再触发。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = _panelKey.currentContext?.size?.height;
      if (height == null) return;
      final next = (height / 2).clamp(24.0, _maxBadgeSize);
      if ((next - badgeSize).abs() > 0.5) {
        setState(() => _badgeSize = next);
      }
    });

    final card = ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Container(
            key: _panelKey,
            decoration: BoxDecoration(
              // 半透明表面透出页面背景，卡片自然融入
              color: theme.surface.withValues(alpha: theme.isDark ? 0.5 : 0.65),
              borderRadius: radius,
              border: Border.all(
                color: theme.primary.withValues(
                  alpha: theme.isDark ? 0.6 : 0.45,
                ),
                width: 1.8,
              ),
            ),
            // 内容区为左上角扇形标志让出左侧间距
            padding: EdgeInsets.only(
              left: hasBadge ? badgeSize + theme.spacing.md : theme.spacing.md,
              top: theme.spacing.md,
              right: theme.spacing.md,
              bottom: theme.spacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: DsTypography.heading.copyWith(color: theme.text),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.trailingText != null) ...[
                  SizedBox(width: theme.spacing.sm),
                  Text(
                    widget.trailingText!,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ],
                if (widget.trailing != null) ...[
                  SizedBox(width: theme.spacing.sm),
                  widget.trailing!,
                ],
              ],
            ),
          ),
          // 左上角扇形标志：贴顶边与左边，仅圆右下角，叠层不占行内布局
          if (hasBadge)
            Positioned(
              left: 0,
              top: 0,
              child: SizedBox(
                width: badgeSize,
                height: badgeSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.iconColor ?? theme.primary,
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(badgeSize),
                    ),
                  ),
                  // 图标中心沿对角线内收，完整落在扇形内
                  child: Align(
                    alignment: const Alignment(-0.05, -0.05),
                    child:
                        widget.leading ??
                        DsIcon(
                          widget.icon!,
                          size: badgeSize * 0.42,
                          color: theme.onPrimary,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.onTap == null) return card;
    return Pressable(
      onPressed: widget.onTap,
      builder: (context, states) => states.contains(WidgetState.pressed)
          ? Opacity(opacity: 0.85, child: card)
          : card,
    );
  }
}
