import 'package:flutter/widgets.dart';

import '../tokens/colors.dart';
import '../tokens/radii.dart';
import '../tokens/shadows.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

// 转发导出：组件只 import theme 即可拿到颜色令牌与派生扩展
export '../tokens/colors.dart';

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
    required this.stroke,
    required this.barrier,
    required this.disabled,
  });

  /// 浅色主题（对应设计稿）
  factory AppThemeData.light() => const AppThemeData(
        isDark: false,
        primary: DsColors.primary,
        onPrimary: DsColors.white,
        secondary: DsColors.secondary,
        onSecondary: DsColors.text,
        success: DsColors.success,
        onSuccess: DsColors.text,
        warning: DsColors.warning,
        onWarning: DsColors.text,
        danger: DsColors.danger,
        onDanger: DsColors.white,
        background: DsColors.background,
        backgroundAlt: DsColors.backgroundAlt,
        surface: DsColors.white,
        surfaceAlt: DsColors.backgroundAlt,
        text: DsColors.text,
        textSub: DsColors.textSub,
        stroke: DsColors.white,
        barrier: Color(0x594C1D95),
        disabled: Color(0xFFE5DDF2),
      );

  /// 深色主题
  factory AppThemeData.dark() => const AppThemeData(
        isDark: true,
        primary: Color(0xFF9D7BFF),
        onPrimary: DsColors.white,
        secondary: Color(0xFFF5A8D4),
        onSecondary: DsColors.text,
        success: DsColors.success,
        onSuccess: DsColors.text,
        warning: DsColors.warning,
        onWarning: DsColors.text,
        danger: Color(0xFFFF8A9B),
        onDanger: DsColors.night,
        background: DsColors.night,
        backgroundAlt: DsColors.nightAlt,
        surface: Color(0xFF332154),
        surfaceAlt: Color(0xFF46306E),
        text: DsColors.nightText,
        textSub: DsColors.nightTextSub,
        stroke: Color(0x33FFFFFF),
        barrier: Color(0x8C14082B),
        disabled: Color(0xFF463A66),
      );

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

  /// 果冻渐变（水晶质感）：顶部高光带 → 基色 → 底部加深
  List<Color> jellyGradient(Color base) => [
        base.mixWhite(isDark ? 0.34 : 0.55), // 顶部水晶高光带
        base.mixWhite(isDark ? 0.14 : 0.22), // 高光衰减过渡
        base,
        base.mixBlack(isDark ? 0.22 : 0.08), // 底部加深，体积感
      ];

  /// 果冻渐变的分段（上 1/3 是水晶高光区，底部压暗）
  List<double> get jellyStops => const [0.0, 0.32, 0.55, 1.0];

  /// 果冻描边（基色加深），立体感来源之一
  Color jellyStroke(Color base) => base.mixBlack(isDark ? 0.35 : 0.18);

  /// 水晶描边（基色调亮的浅色外圈），对应设计稿的「白色描边」
  Color jellyRim(Color base) => base.mixWhite(isDark ? 0.35 : 0.62);

  /// 水晶高光罩层：叠加在果冻件表层的顶部透亮光泽（覆盖在 child 之上）
  LinearGradient jellyGloss() => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          DsColors.white.withValues(alpha: isDark ? 0.14 : 0.30),
          DsColors.white.withValues(alpha: isDark ? 0.05 : 0.10),
          DsColors.transparent,
        ],
        stops: const [0.0, 0.35, 0.6],
      );

  /// 彩色果冻投影：基色晕染下坠（大而柔的深紫投影）+ 白色外圈顶光
  List<BoxShadow> jellyShadow(Color base, {double height = 5}) => [
        BoxShadow(
          color: base.withValues(alpha: isDark ? 0.6 : 0.5),
          offset: Offset(0, height + 2),
          blurRadius: height * 3.0,
        ),
        BoxShadow(
          color: stroke.withValues(alpha: isDark ? 0.12 : 0.9),
          offset: const Offset(0, -1),
          blurRadius: 2,
        ),
      ];

  /// 按压态投影：下坠更少，模拟被按进果冻里
  List<BoxShadow> pressedShadow(Color base, {double height = 5}) => [
        BoxShadow(
          color: base.withValues(alpha: isDark ? 0.45 : 0.30),
          offset: Offset(0, height * 0.35),
          blurRadius: height,
        ),
      ];

  /// 派生：主色文字（浅色模式直接用主色，深色模式提亮）
  Color get primaryText => isDark ? primary : primary.mixBlack(0.08);
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
    return _AppThemeScope(
      data: data,
      child: DefaultTextStyle(
        style: DsTypography.body.copyWith(
          color: data.text,
          decoration: TextDecoration.none,
        ),
        child: child,
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
