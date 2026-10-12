import 'package:flutter/material.dart';
import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';

/// 成就徽章：图标贴纸 + 右下角等级角标（Lv1 灰铁 / Lv2 青铜 / Lv3 白银 / Lv4 黄金 / Lv5 彩虹）
///
/// level = 0 表示未解锁（图标灰化 + 半透明）
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.iconAsset,
    required this.level,
    this.size = 56,
    this.showLevelTag = false,
  });

  final String iconAsset;
  final int level;
  final double size;

  /// 是否在右下角显示 Lv 角标
  final bool showLevelTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = level > 0;

    Widget badge = SizedBox(
      width: size,
      height: size,
      child: _buildIcon(theme, unlocked),
    );

    if (showLevelTag) {
      badge = Stack(
        clipBehavior: Clip.none,
        children: [
          badge,
          Positioned(
            right: -2,
            bottom: -2,
            child: _buildLevelTag(theme, level),
          ),
        ],
      );
    }
    return badge;
  }

  Widget _buildIcon(ThemeData theme, bool unlocked) {
    // 图标资源为带透明底的贴纸（如六边形），直接原样展示，不做圆形裁剪与描边
    Widget icon = Image.asset(
      iconAsset,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.emoji_events_outlined,
        size: size * 0.5,
        color: theme.disabledColor,
      ),
    );
    if (!unlocked) {
      // 灰度 + 半透明，保留轮廓神秘感
      icon = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 0.6, 0,
        ]),
        child: icon,
      );
    }
    return icon;
  }

  Widget _buildLevelTag(ThemeData theme, int level) {
    final color = level > 0 ? AchievementLevels.borderColor(level) : theme.disabledColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        level > 0 ? '$level' : '-',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          height: 1,
        ),
      ),
    );
  }
}
