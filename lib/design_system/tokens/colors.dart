import 'package:flutter/widgets.dart';

/// 设计令牌：颜色调色板
///
/// 取值来自「手绘风」设计稿，仅定义原始色值；
/// 语义化配色（主色/表面/文字等）由 [AppThemeData] 组合并派生。
abstract final class DsColors {
  /// 主色（葡萄紫）
  static const Color primary = Color(0xFF885CF6);

  /// 主色深（描边/按压态）
  static const Color primaryDeep = Color(0xFF6B3BE8);

  /// 辅助色（樱花粉）
  static const Color secondary = Color(0xFFF5A8D4);

  /// 成功（薄荷绿）
  static const Color success = Color(0xFF6EE7B7);

  /// 警告（奶油黄）
  static const Color warning = Color(0xFFFCD34D);

  /// 危险（草莓红）
  static const Color danger = Color(0xFFF87185);

  /// 页面背景（浅）
  static const Color background = Color(0xFFFDF7FF);

  /// 页面背景（粉紫渐变另一端）
  static const Color backgroundAlt = Color(0xFFF3E8FF);

  /// 深色模式页面背景
  static const Color night = Color(0xFF201538);

  /// 深色模式背景另一端
  static const Color nightAlt = Color(0xFF2C1B4E);

  /// 主文字（紫黑）
  static const Color text = Color(0xFF4C1D95);

  /// 次要文字（浅紫）
  static const Color textSub = Color(0xFFA78BFA);

  /// 深色模式主文字
  static const Color nightText = Color(0xFFEDE9FE);

  /// 深色模式次要文字
  static const Color nightTextSub = Color(0xFFB9A6F0);

  /// 基础色（widgets 层没有 Colors 类，这里提供中性色）
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);
}

/// 颜色派生扩展：果冻质感的明暗渐变都从这里来
extension DsColorX on Color {
  /// 向白色混合 [t]（0~1），用于顶部高光
  Color mixWhite(double t) => Color.lerp(this, const Color(0xFFFFFFFF), t)!;

  /// 向黑色混合 [t]（0~1），用于描边/按压态
  Color mixBlack(double t) => Color.lerp(this, const Color(0xFF000000), t)!;
}
