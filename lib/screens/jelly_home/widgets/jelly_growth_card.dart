import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 「成长」卡：经验值进度 + 下一级解锁提示 + 礼盒插画位
class JellyGrowthCard extends StatelessWidget {
  const JellyGrowthCard({
    super.key,
    required this.exp,
    required this.expMax,
    required this.nextUnlock,
  });

  final int exp;
  final int expMax;
  final String nextUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return JellyBox(
      radius: theme.radii.xl,
      padding: EdgeInsets.all(theme.spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              // 双卡等高拉伸后内容垂直居中，避免堆在顶部
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DsIcon(DsIconKind.sprout, size: 15, color: theme.success),
                    SizedBox(width: theme.spacing.sm),
                    Text(
                      '成长',
                      style: DsTypography.heading.copyWith(
                        fontSize: 14,
                        color: theme.primaryText,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.md),
                Text(
                  '经验 $exp/$expMax',
                  style: DsTypography.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                  ),
                ),
                SizedBox(height: theme.spacing.sm),
                DSLinearProgress(
                  value: exp / expMax,
                  height: 10,
                  color: theme.success,
                ),
                SizedBox(height: theme.spacing.sm),
                Text(
                  nextUnlock,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.label.copyWith(
                    fontSize: 10,
                    color: theme.textSub,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.md),
          // 3D 礼盒素材到位前先用图标占位
          DsIcon(
            DsIconKind.gift,
            size: 40,
            color: theme.secondary.mixBlack(0.05),
          ),
        ],
      ),
    );
  }
}
