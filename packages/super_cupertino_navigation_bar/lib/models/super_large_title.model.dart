import 'package:flutter/material.dart';
import 'package:super_cupertino_navigation_bar/utils/sketch_font.dart';

class SuperLargeTitle {
  SuperLargeTitle({
    this.largeTitle = "Hello Super Human",
    this.actions,
    this.textStyle = const TextStyle(
      inherit: false,
      // 原 iOS 系统字体在非苹果平台上不存在
      fontFamily: kSketchFontFamily,
      fontSize: 34.0,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.41,
    ),
    this.height = kToolbarHeight,
    this.padding = const EdgeInsets.symmetric(horizontal: 15.0),
    this.enabled = true,
  });

  final bool enabled;
  final String largeTitle;
  final List<Widget>? actions;
  final TextStyle textStyle;

  /// {@template flutter.material.appbar.toolbarHeight}
  /// Defines the height of the toolbar component of an [AppBar].
  ///
  /// By default, the value of [toolbarHeight] is [kToolbarHeight].
  /// {@endtemplate}
  double height;
  final EdgeInsets padding;
}
