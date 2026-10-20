import 'package:flutter/material.dart';

/// 懒加载版 [IndexedStack]：子项首次被选中时才构建，之后保持状态
///
/// 未加载的子项用 [SizedBox.shrink] 占位，保证 index 对应关系不变。
/// 注意：children 中未构建的项仅是轻量 widget 配置，State 不会创建。
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const LazyIndexedStack({super.key, required this.index, required this.children});

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _built = {};

  @override
  void initState() {
    super.initState();
    _built.add(widget.index);
  }

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _built.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (_built.contains(i)) widget.children[i] else const SizedBox.shrink(),
      ],
    );
  }
}
