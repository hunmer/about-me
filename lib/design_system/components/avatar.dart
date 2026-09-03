import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';

/// 果冻头像：渐变圆 + 白描边，内容为字符或自定义子组件
class DSAvatar extends StatelessWidget {
  const DSAvatar({
    super.key,
    this.label,
    this.child,
    this.size = 44,
    this.color,
    this.secondaryColor,
  });

  /// 展示的字符（如 emoji 或首字母）
  final String? label;

  /// 自定义内容，优先于 [label]
  final Widget? child;
  final double size;

  /// 渐变主色（默认主色）
  final Color? color;

  /// 渐变辅色（默认辅助粉）
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final c1 = color ?? theme.primary;
    final c2 = secondaryColor ?? theme.secondary;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1.mixWhite(0.35), c1, c2],
        ),
        border: Border.all(color: theme.stroke, width: 2.4),
        boxShadow: [
          BoxShadow(
            color: c1.withValues(alpha: theme.isDark ? 0.5 : 0.3),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: child ??
          (label == null
              ? null
              : FittedBox(
                  child: Text(
                    label!,
                    style: TextStyle(fontSize: size * 0.5),
                  ),
                )),
    );
  }
}

/// 圆形字母头像便捷构造
class DSAvatarInitial extends StatelessWidget {
  const DSAvatarInitial({
    super.key,
    required this.initial,
    this.size = 44,
    this.color,
  });

  final String initial;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return DSAvatar(
      size: size,
      color: color,
      child: Text(
        initial,
        style: DsTypography.title.copyWith(color: theme.onPrimary),
      ),
    );
  }
}
