import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 左上角用户资料卡：头像 + 昵称 + 等级 + 经验进度
class JellyProfileCard extends StatelessWidget {
  const JellyProfileCard({
    super.key,
    required this.name,
    required this.level,
    required this.exp,
    required this.expMax,
    this.avatarEmoji = '🍬',
    this.onTap,
  });

  final String name;
  final int level;
  final int exp;
  final int expMax;

  /// 角色 3D 素材到位前用 emoji 占位
  final String avatarEmoji;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    final card = JellyBox(
      radius: theme.radii.xl,
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DSAvatar(label: avatarEmoji, size: 40),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.heading.copyWith(
                        color: theme.text,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      'Lv.$level',
                      style: DsTypography.label.copyWith(
                        fontSize: 12,
                        color: theme.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          DSLinearProgress(value: exp / expMax, height: 9),
          SizedBox(height: theme.spacing.xs),
          Center(
            child: Text(
              '$exp/$expMax',
              style: DsTypography.label.copyWith(
                fontSize: 11,
                color: theme.textSub,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) => states.contains(WidgetState.pressed)
          ? Opacity(opacity: 0.85, child: card)
          : card,
    );
  }
}
