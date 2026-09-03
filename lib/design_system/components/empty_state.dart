import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'button.dart';
import 'jelly_box.dart';

/// 果冻空状态：大表情 + 标题 + 说明 + 可选操作按钮
/// （对应设计稿「还没有记录哦」）
class DSEmptyState extends StatelessWidget {
  const DSEmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  /// 主视觉表情（如 🐰）
  final String emoji;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 表情底座：果冻圆盘
        JellyBox(
          width: 92,
          height: 92,
          radius: theme.radii.circle,
          color: theme.surfaceAlt,
          raised: true,
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 42)),
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
    );
  }
}
