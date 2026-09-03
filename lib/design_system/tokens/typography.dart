import 'package:flutter/widgets.dart';

/// 设计令牌：字体（不携带颜色，颜色由组件按主题传入）
abstract final class DsTypography {
  /// 大标题（页面主标题）
  static const TextStyle display = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.25,
  );

  /// 标题（分区标题）
  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// 小标题（卡片标题）
  static const TextStyle heading = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// 正文
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// 辅助说明
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  /// 按钮文字
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.0,
  );

  /// 徽标/角标
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.0,
  );
}
