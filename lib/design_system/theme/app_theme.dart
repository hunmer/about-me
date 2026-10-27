import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:skribble_icons_material/skribble_icons_material.dart';

import '../tokens/colors.dart';
import '../tokens/palettes.dart';
import '../tokens/radii.dart';
import '../tokens/shadows.dart';
// ignore: unused_import, sketch.dart 反向引用本文件（循环 import 合法）
import '../tokens/sketch.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

// 转发导出：组件只 import theme 即可拿到颜色令牌与派生扩展
export '../tokens/colors.dart';
export '../tokens/palettes.dart';
export '../tokens/sketch.dart';

/// 主题数据：语义化设计令牌的集合
///
/// 组件内部禁止硬编码颜色/圆角/间距，一律从这里读取；
/// 果冻质感的渐变、描边、投影派生规则也集中在这里，保证全局一致。
class AppThemeData {
  const AppThemeData({
    required this.isDark,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.textSub,
    required this.ink,
    required this.stroke,
    required this.barrier,
    required this.disabled,
  });

  /// 浅色主题（对应设计稿）
  factory AppThemeData.light() =>
      AppThemeData.fromPalette(DsThemePalettes.pink, isDark: false);

  /// 深色主题
  factory AppThemeData.dark() =>
      AppThemeData.fromPalette(DsThemePalettes.pink, isDark: true);

  /// 按色板构建主题：浅色下观感色（主色/背景/文字）均来自色板；
  /// 深色下从主色派生同色相的深色阶梯（背景/面板/文字），避免非紫色板
  /// 在深色模式下泛紫
  factory AppThemeData.fromPalette(
    DsThemePalette palette, {
    bool isDark = false,
  }) {
    if (isDark) {
      final night = _deepShade(palette.primary, 0.45, 0.15);
      return AppThemeData(
        isDark: true,
        primary: palette.primary.mixWhite(0.12),
        onPrimary: DsColors.white,
        secondary: palette.secondary,
        onSecondary: DsColors.nightText,
        success: DsColors.success,
        onSuccess: DsColors.nightText,
        warning: DsColors.warning,
        onWarning: DsColors.nightText,
        danger: Color(0xFFFF8A9B),
        onDanger: DsColors.night,
        background: night,
        backgroundAlt: _deepShade(palette.primary, 0.48, 0.21),
        surface: _deepShade(palette.primary, 0.44, 0.23),
        surfaceAlt: _deepShade(palette.primary, 0.39, 0.31),
        text: _deepShade(palette.primary, 0.55, 0.95),
        textSub: _deepShade(palette.primary, 0.55, 0.78),
        ink: _deepShade(palette.primary, 0.55, 0.95),
        stroke: Color(0x33FFFFFF),
        barrier: night.withValues(alpha: 0.55),
        disabled: _deepShade(palette.primary, 0.28, 0.31),
      );
    }
    return AppThemeData(
      isDark: false,
      primary: palette.primary,
      onPrimary: DsColors.white,
      secondary: palette.secondary,
      onSecondary: palette.text,
      success: DsColors.success,
      onSuccess: DsColors.text,
      warning: DsColors.warning,
      onWarning: DsColors.text,
      danger: DsColors.danger,
      onDanger: DsColors.white,
      background: palette.background,
      backgroundAlt: palette.backgroundAlt,
      surface: DsColors.white,
      surfaceAlt: palette.backgroundAlt,
      text: palette.text,
      textSub: palette.textSub,
      ink: palette.ink ?? palette.text,
      stroke: DsColors.white,
      barrier: Color(0x594C1D95),
      disabled: Color(0xFFE5DDF2),
    );
  }

  /// 是否深色模式
  final bool isDark;

  // ---- 语义色 ----
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color danger;
  final Color onDanger;

  /// 页面背景（与 [backgroundAlt] 组成渐变）
  final Color background;
  final Color backgroundAlt;

  /// 卡片/面板表面
  final Color surface;

  /// 次级表面（滑轨、分段控件底）
  final Color surfaceAlt;
  final Color text;
  final Color textSub;

  /// 墨线色：手绘描边与手绘图标的主色
  /// （浅色取自色板、缺省跟文字同色相；深色自主色派生）
  final Color ink;

  /// 白色描边（果冻件外圈）
  final Color stroke;

  /// 遮罩颜色（对话框/底部面板背景）
  final Color barrier;

  /// 禁用态填充
  final Color disabled;

  // ---- 令牌组 ----
  DsSpacingToken get spacing => const DsSpacingToken();
  DsRadiiToken get radii => const DsRadiiToken();
  DsShadowsToken get shadows => const DsShadowsToken();

  /// 果冻渐变（手绘化后仅保兼容：返回纯色，无渐变）
  List<Color> jellyGradient(Color base) => [base, base, base, base];

  /// 果冻渐变的分段（保兼容）
  List<double> get jellyStops => const [0.0, 0.32, 0.55, 1.0];

  /// 果冻描边：手绘化后即基色
  Color jellyStroke(Color base) => base;

  /// 水晶描边：手绘化后即基色
  Color jellyRim(Color base) => base;

  /// 水晶高光罩层：手绘化后全透明
  LinearGradient jellyGloss() => LinearGradient(
        colors: [
          DsColors.transparent,
          DsColors.transparent,
          DsColors.transparent,
        ],
        stops: const [0.0, 0.35, 0.6],
      );

  /// 投影：手绘风格无彩色柔影，返回空
  List<BoxShadow> jellyShadow(Color base, {double height = 5}) => const [];

  /// 按压态投影：返回空
  List<BoxShadow> pressedShadow(Color base, {double height = 5}) => const [];

  /// 派生：主色文字（浅色模式直接用主色，深色模式提亮）
  Color get primaryText => isDark ? primary : primary.mixBlack(0.08);

  /// 深色表面色派生：保持 [base] 色相，压到目标饱和度/明度，
  /// 得到同色系的深色阶梯（数值对标原紫色 night 系硬编码值）
  static Color _deepShade(Color base, double saturation, double lightness) {
    return HSLColor.fromColor(base)
        .withSaturation(saturation)
        .withLightness(lightness)
        .toColor();
  }
}

/// 间距令牌透传（组件通过 `theme.spacing.xs` 读取）
class DsSpacingToken {
  const DsSpacingToken();
  double get xs => DsSpacing.xs;
  double get sm => DsSpacing.sm;
  double get md => DsSpacing.md;
  double get lg => DsSpacing.lg;
  double get xl => DsSpacing.xl;
  double get xxl => DsSpacing.xxl;
  double get xxxl => DsSpacing.xxxl;
}

/// 圆角令牌透传
class DsRadiiToken {
  const DsRadiiToken();
  BorderRadius get sm => DsRadii.sm;
  BorderRadius get md => DsRadii.md;
  BorderRadius get lg => DsRadii.lg;
  BorderRadius get xl => DsRadii.xl;
  BorderRadius get xxl => DsRadii.xxl;
  BorderRadius get xxxl => DsRadii.xxxl;
  BorderRadius get pill => DsRadii.pill;
  BorderRadius get circle => DsRadii.circle;
  double get xxlValue => DsRadii.xxlValue;
}

/// 阴影令牌透传
class DsShadowsToken {
  const DsShadowsToken();
  List<BoxShadow> get card => DsShadows.card;
  List<BoxShadow> get soft => DsShadows.soft;
  List<BoxShadow> get float => DsShadows.float;
}

/// 主题入口：`AppTheme.of(context)` 读取令牌
///
/// 与 Material 的 `Theme` 同构：外层 StatelessWidget 负责组装
/// [DefaultTextStyle] 与继承作用域。默认文字样式是必须的——设计系统
/// 完全基于 widgets 层，页面与浮层都没有 Material 祖先，`Text` 会命中
/// Flutter 的调试回退样式（红色文字 + 黄色双下划线，提示
/// "consider putting your text in a Material"）。这里按令牌给出基线
/// 样式并显式关闭装饰线，组件内 `inherit: true` 的样式都会合并到它。
class AppTheme extends StatelessWidget {
  const AppTheme({
    super.key,
    required this.data,
    required this.child,
  });

  final AppThemeData data;
  final Widget child;

  static AppThemeData of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_AppThemeScope>()!
          .data;

  /// 可空版本：用于脱离主题树的浮层（Overlay/Dialog）取默认值
  static AppThemeData? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AppThemeScope>()
      ?.data;

  @override
  Widget build(BuildContext context) {
    // 手绘图标目录注册（幂等：重复调用仅覆盖同一目录；
    // 不能走 assert——release 下会被剥除导致 WiredIcon 拿不到手绘几何）
    registerSkribbleMaterialIcons();
    return _AppThemeScope(
      data: data,
      child: WiredThemeScope(
        data: data.wired,
        // 透明 Material 兜底：Wired* 组件内嵌的 Material 控件
        // （TextButton/Card/Checkbox...）在纯 widgets 树里需要 Material 祖先
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: DsTypography.body.copyWith(
              color: data.text,
              decoration: TextDecoration.none,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AppThemeScope extends InheritedWidget {
  const _AppThemeScope({required this.data, required super.child});

  final AppThemeData data;

  @override
  bool updateShouldNotify(_AppThemeScope oldWidget) =>
      data != oldWidget.data;
}
