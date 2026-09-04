import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// 顶部统计小卡：彩色图标 + 标签 + 数值 + 右下角「+」按钮
class JellyStatCard extends StatelessWidget {
  const JellyStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
    this.onAdd,
  });

  final DsIconKind icon;
  final String label;
  final String value;

  /// 图标主色（待办橙 / 打卡绿 / 记录紫）
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    final card = JellyBox(
      radius: theme.radii.lg,
      // 横向三卡并排，空间紧张，内边距取小值
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIcon(icon, size: 13, color: color),
              SizedBox(width: theme.spacing.xs),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: DsTypography.label.copyWith(
                      fontSize: 10,
                      color: theme.textSub,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.xs + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: DsTypography.heading.copyWith(
                      fontSize: 14,
                      color: theme.text,
                    ),
                  ),
                ),
              ),
              SizedBox(width: theme.spacing.xs),
              _MiniPlusButton(onTap: onAdd),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Pressable(
      onPressed: onTap,
      builder:
          (context, states) =>
              states.contains(WidgetState.pressed)
                  ? Opacity(opacity: 0.85, child: card)
                  : card,
    );
  }
}

/// 卡片右下角的小圆形「+」按钮
class _MiniPlusButton extends StatelessWidget {
  const _MiniPlusButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: onTap,
      semanticLabel: '添加',
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.surfaceAlt,
              border: Border.all(color: theme.stroke, width: 1.2),
            ),
            child: DsIcon(DsIconKind.plus, size: 10, color: theme.textSub),
          ),
        );
      },
    );
  }
}
