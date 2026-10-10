import 'package:flutter/cupertino.dart';
import 'package:super_cupertino_navigation_bar/utils/measures.dart';

import 'back_button.dart';
import 'navigation_bar_static_components.dart';

class PersistentNavigationBar extends StatelessWidget {
  const PersistentNavigationBar({
    super.key,
    required this.components,
    this.padding,
    this.middleVisible,
    this.height = 56.0,
  });

  final NavigationBarStaticComponents components;

  /// 工具栏内容高度（不含顶部安全区内边距，默认 56，同 Material
  /// [kToolbarHeight] 与包内部 primaryToolbarHeight）。
  ///
  /// NavigationToolbar 会占满父级给的剩余高度：直接用于 Column 等宽松
  /// 父级时（尤其存在 IndexedStack 等兄弟节点）可能拿到无界高度约束
  /// 而崩溃，因此这里必须显式限定；内部展开态挂载同样以该高度传入
  final double height;

  /// Padding for the contents of the navigation bar.
  ///
  /// If null, the navigation bar will adopt the following defaults:
  ///
  ///  * Vertically, contents will be sized to the same height as the navigation
  ///    bar itself minus the status bar.
  ///  * Horizontally, padding will be 16 pixels according to iOS specifications
  ///    unless the leading widget is an automatically inserted back button, in
  ///    which case the padding will be 0.
  ///
  /// Vertical padding won't change the height of the nav bar.
  final EdgeInsetsDirectional? padding;

  /// Whether the middle widget has a visible animated opacity. A null value
  /// means the middle opacity will not be animated.
  final bool? middleVisible;

  @override
  Widget build(BuildContext context) {
    Widget? middle = components.middle;

    if (middle != null) {
      middle = DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
        child: Semantics(header: true, child: middle),
      );
      // When the middle's visibility can change on the fly like with large title
      // slivers, wrap with animated opacity.
      middle = middleVisible == null
          ? middle
          : AnimatedOpacity(
              opacity: middleVisible! ? 1.0 : 0.0,
              duration: Measures.instance.standartAnimationDuration,
              child: middle,
            );
    }

    Widget? leading = components.leading;
    final Widget? backChevron = components.backChevron;
    final Widget? backLabel = components.backLabel;

    if (leading == null && backChevron != null && backLabel != null) {
      leading = SuperCupertinoNavigationBarBackButton.assemble(
        backChevron,
        backLabel,
      );
    }

    Widget paddedToolbar = NavigationToolbar(
      leading: leading,
      middle: middle,
      trailing: components.trailing,
      middleSpacing: 6.0,
    );

    if (padding != null) {
      paddedToolbar = Padding(
        padding: EdgeInsets.only(
          top: padding!.top,
          bottom: padding!.bottom,
        ),
        child: paddedToolbar,
      );
    }

    return SafeArea(
      bottom: false,
      child: SizedBox(height: height, child: paddedToolbar),
    );
  }
}
