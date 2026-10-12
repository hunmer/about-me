import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:skribble/skribble.dart' show WiredIcon;

class BackChevron extends StatelessWidget {
  const BackChevron({super.key});

  @override
  Widget build(BuildContext context) {
    final TextDirection textDirection = Directionality.of(context);
    final TextStyle textStyle = DefaultTextStyle.of(context).style;

    // 手绘返回箭头（WiredIcon 对 Material 图标套手绘几何；
    // CupertinoIcons 不在手绘目录，用等价的 chevron_left）
    Widget iconWidget = Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, end: 2),
      child: WiredIcon(
        icon: Icons.chevron_left,
        size: 25.0,
        color: textStyle.color,
      ),
    );
    switch (textDirection) {
      case TextDirection.rtl:
        iconWidget = Transform(
          transform: Matrix4.identity()
            ..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
          alignment: Alignment.center,
          transformHitTests: false,
          child: iconWidget,
        );
        break;
      case TextDirection.ltr:
        break;
    }

    return iconWidget;
  }
}
