import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// 右侧「今日心情」卡：表情 + 鼓励语 + 去聊聊按钮
class JellyMoodCard extends StatelessWidget {
  const JellyMoodCard({
    super.key,
    required this.title,
    required this.emoji,
    required this.message,
    this.actionLabel = '去聊聊',
    this.onAction,
    this.width = 150,
  });

  final String title;
  final String emoji;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return JellyBox(
      width: width,
      radius: theme.radii.xl,
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: DsTypography.heading.copyWith(
              fontSize: 14,
              color: theme.primaryText,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          // 角色素材到位前用 emoji 表情占位
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 36)),
              Positioned(
                right: -10,
                top: -4,
                child: DsIcon(
                  DsIconKind.heart,
                  size: 14,
                  color: theme.secondary,
                  fill: true,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: DsTypography.caption.copyWith(
              fontSize: 11,
              height: 1.5,
              color: theme.text,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          DSButton(
            label: actionLabel,
            size: DSButtonSize.sm,
            expand: true,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}
