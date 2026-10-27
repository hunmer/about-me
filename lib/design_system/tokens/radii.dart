import 'package:flutter/widgets.dart';

/// 设计令牌：圆角
abstract final class DsRadii {
  static const double smValue = 8;
  static const double mdValue = 12;
  static const double lgValue = 16;
  static const double xlValue = 20;
  static const double xxlValue = 28;
  static const double xxxlValue = 36;

  static const BorderRadius sm = BorderRadius.all(Radius.circular(smValue));
  static const BorderRadius md = BorderRadius.all(Radius.circular(mdValue));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(lgValue));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(xlValue));
  static const BorderRadius xxl = BorderRadius.all(Radius.circular(xxlValue));
  static const BorderRadius xxxl = BorderRadius.all(Radius.circular(xxxlValue));

  /// 胶囊形
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  /// 正圆
  static const BorderRadius circle = BorderRadius.all(Radius.circular(999));
}
