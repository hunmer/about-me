import 'package:flutter/widgets.dart';

/// 设计令牌：阴影（白色/中性表面用；彩色果冻投影由主题派生）
abstract final class DsShadows {
  /// 卡片软阴影
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x144C1D95), offset: Offset(0, 8), blurRadius: 24),
  ];

  /// 轻量阴影（输入框、小元素）
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0F4C1D95), offset: Offset(0, 4), blurRadius: 12),
  ];

  /// 悬浮元素（浮层、FAB）
  static const List<BoxShadow> float = [
    BoxShadow(color: Color(0x264C1D95), offset: Offset(0, 12), blurRadius: 32),
  ];
}

/// 手绘错位阴影档位：同形状偏移复制的实体投影（零模糊）
///
/// 不是拟物光影——在手绘语言里它等价于「纸上再叠一张同形状的纸」，
/// 呈现贴纸/游戏按键的厚度感。消费方见 [JellyBox.shadow]。
abstract final class DsHandShadow {
  /// 轻厚度（chip、输入框）
  static const Offset light = Offset(0, 3);

  /// 常规厚度（按钮、徽章）
  static const Offset regular = Offset(0, 5);
}
