import 'package:flutter/material.dart';

/// 从运行时数据（数据库 / JSON）构造 [IconData]。
///
/// Flutter 3.44 起 [IconData.codePoint]、[IconData.fontFamily] 等参数被标记为
/// `@mustBeConst`（仅接受编译期常量），而本项目大量图标码点来自持久化数据，
/// 无法满足该约束，因此统一收敛到此处构造，避免各调用点散落 ignore 注释。
///
/// 注意：使用运行时构造的图标时，release 构建需加 `--no-tree-shake-icons`
/// 关闭图标树摇，否则对应字形会被从字体中移除。
IconData dynamicIconData(
  int codePoint, {
  String? fontFamily,
  String? fontPackage,
  bool matchTextDirection = false,
  List<String>? fontFamilyFallback,
}) {
  return IconData(
    // ignore: non_const_argument_for_const_parameter
    codePoint,
    // ignore: non_const_argument_for_const_parameter
    fontFamily: fontFamily,
    // ignore: non_const_argument_for_const_parameter
    fontPackage: fontPackage,
    matchTextDirection: matchTextDirection,
    fontFamilyFallback: fontFamilyFallback,
  );
}
