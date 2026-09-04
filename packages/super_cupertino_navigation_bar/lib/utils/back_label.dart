import 'package:flutter/cupertino.dart';

/// A widget that shows next to the back chevron when `automaticallyImplyLeading`
/// is true.
class BackLabel extends StatelessWidget {
  const BackLabel({
    super.key,
    required this.specifiedPreviousTitle,
    required this.route,
    this.textStyle,
  });

  final String? specifiedPreviousTitle;
  final ModalRoute<dynamic>? route;

  /// 自定义标签文字样式；为 null 时沿用导航动作默认样式。
  /// Text 的 style 会合并到上层 DefaultTextStyle 之上，可只传部分属性
  final TextStyle? textStyle;

  // `child` is never passed in into ValueListenableBuilder so it's always
  // null here and unused.
  Widget _buildPreviousTitleWidget(
      BuildContext context, String? previousTitle, Widget? child) {
    if (previousTitle == null) {
      return const SizedBox.shrink();
    }

    Text textWidget = Text(
      previousTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );

    if (previousTitle.length > 12) {
      textWidget = Text('Back', style: textStyle);
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1.0,
      child: textWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (specifiedPreviousTitle != null) {
      return _buildPreviousTitleWidget(context, specifiedPreviousTitle, null);
    } else if (route is CupertinoRouteTransitionMixin<dynamic> &&
        !route!.isFirst) {
      final CupertinoRouteTransitionMixin<dynamic> cupertinoRoute =
          route! as CupertinoRouteTransitionMixin<dynamic>;
      // There is no timing issue because the previousTitle Listenable changes
      // happen during route modifications before the ValueListenableBuilder
      // is built.
      return ValueListenableBuilder<String?>(
        valueListenable: cupertinoRoute.previousTitle,
        builder: _buildPreviousTitleWidget,
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
