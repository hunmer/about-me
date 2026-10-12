import 'package:flutter/widgets.dart';

/// 设计令牌：字体（不携带颜色，颜色由组件按主题传入）
///
/// 手绘风格：全部文字使用 skribble 的手写字体（SkribblePlayful，
/// 基于 Recursive Casual 的扭曲轮廓）。该字体不含中文字形，
/// 中文回退到项目字体 AlibabaPuHuiTi / 系统字体。
abstract final class DsTypography {
  /// 手写字体族（skribble_font_recursive 包内注册，零配置）
  static const String sketchFamily = 'SkribblePlayful';
  static const String sketchPackage = 'skribble_font_recursive';

  // 手写字体参数（const 上下文无法 copyWith，逐样式展开）
  static const String _family = sketchFamily;
  static const String _package = sketchPackage;
  static const List<String> _fallback = [
    'AlibabaPuHuiTi',
    'PingFang SC',
    'Microsoft YaHei',
  ];

  /// 大标题（页面主标题）
  static const TextStyle display = TextStyle(
    fontFamily: _family,
    package: _package,
    fontFamilyFallback: _fallback,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.25,
  );

  /// 标题（分区标题）
  static const TextStyle title = TextStyle(
    fontFamily: _family,
    package: _package,
    fontFamilyFallback: _fallback,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// 小标题（卡片标题）
  static const TextStyle heading = TextStyle(
    fontFamily: _family,
    package: _package,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// 正文
  static const TextStyle body = TextStyle(
    fontFamily: _family,
    package: _package,
    fontFamilyFallback: _fallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 辅助说明
  static const TextStyle caption = TextStyle(
    fontFamily: _family,
    package: _package,
    fontFamilyFallback: _fallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  /// 按钮文字
  static const TextStyle button = TextStyle(
    fontFamily: _family,
    package: _package,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.0,
  );

  /// 徽标/角标
  static const TextStyle label = TextStyle(
    fontFamily: _family,
    package: _package,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.0,
  );
}
