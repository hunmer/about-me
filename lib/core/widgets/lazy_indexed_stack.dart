import 'package:flutter/widgets.dart';

/// 页签首次访问时才构建，访问后保留状态，隐藏页暂停 Ticker 动画。
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
  });

  final int index;
  final List<WidgetBuilder> builders;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = {};

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.builders.length; i++)
          TickerMode(
            enabled: i == widget.index,
            child: _visited.contains(i)
                ? Builder(builder: widget.builders[i])
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
