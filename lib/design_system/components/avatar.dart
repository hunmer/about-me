import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'jelly_box.dart';

/// 手绘头像：纯色圆 + 淡墨描边，内容为字符或自定义子组件
class DSAvatar extends StatelessWidget {
  const DSAvatar({
    super.key,
    this.label,
    this.child,
    this.size = 44,
    this.color,
    this.secondaryColor,
    this.peel = false,
  });

  /// 展示的字符（如 emoji 或首字母）
  final String? label;

  /// 自定义内容，优先于 [label]
  final Widget? child;
  final double size;

  /// 底色主色（默认主色）
  final Color? color;

  /// 辅色，与 [color] 混成纯色底（默认辅助粉）
  final Color? secondaryColor;

  /// 贴纸剥离感：外圈加 2px 主题 surface 色描边，
  /// 用于叠放在彩色底上时的「撕下来的贴纸」分离感（总尺寸 +4）
  final bool peel;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final c1 = color ?? theme.primary;
    final c2 = secondaryColor ?? theme.secondary;

    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: dsSketchDecoration(
        theme: theme,
        circle: true,
        fillColor: Color.lerp(c1, c2, 0.35),
        stroke: theme.ink.withValues(alpha: 0.55),
        strokeWidth: 2,
      ),
      child:
          child ??
          (label == null
              ? null
              : FittedBox(
                  child: Text(
                    label!,
                    style: TextStyle(
                      fontSize: size * 0.5,
                      color: theme.onPrimary,
                    ),
                  ),
                )),
    );
    return peel ? _PeelRing(child: avatar) : avatar;
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

/// 贴纸剥离描边：子组件外圈 [width] px 主题 surface 色实环
class _PeelRing extends StatelessWidget {
  // ignore: unused_element_parameter
  const _PeelRing({required this.child, this.width = 2});

  final Widget child;

  /// 环宽
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(width),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

/// 头像堆叠：横向重叠排布（后一个压住前一个，步进左移 radius * 0.8）
///
/// 超出 [maxCount] 的头像折叠为一枚 +N 的手绘计数块；
/// 每个头像自动带贴纸剥离描边（surface 色外圈），彩色底上层次清晰。
class DSAvatarStack extends StatelessWidget {
  const DSAvatarStack({
    super.key,
    required this.avatars,
    this.radius = 18,
    this.maxCount = 4,
  });

  /// 头像组件列表（建议传 DSAvatar，size 取 radius * 2）
  final List<Widget> avatars;

  /// 头像半径（直径 = radius * 2）
  final double radius;

  /// 最多直接展示的头像数，超出部分折叠为 +N 计数块
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final size = radius * 2;
    final overflow = avatars.length > maxCount;
    final shown = overflow ? (maxCount > 1 ? maxCount - 1 : 0) : avatars.length;
    final extra = avatars.length - shown;
    final itemCount = shown + (overflow ? 1 : 0);
    if (itemCount == 0) return const SizedBox.shrink();

    final step = radius * 0.8;
    return SizedBox(
      width: size + (itemCount - 1) * step,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown; i++)
            Positioned(
              left: i * step,
              child: _PeelRing(child: avatars[i]),
            ),
          if (overflow)
            Positioned(
              left: shown * step,
              child: _PeelRing(
                // +N 计数块：手绘圆（方盒 + pill 圆角被 rough 引擎钳成正圆）
                child: JellyBox(
                  width: size,
                  height: size,
                  radius: theme.radii.pill,
                  color: theme.surfaceAlt,
                  alignment: Alignment.center,
                  child: Text(
                    '+$extra',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
