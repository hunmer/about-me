import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';

/// 手绘标签页：文字 + 底部滑动墨线指示条
///
/// 传入 [children] 后，指示条下方渲染可左右滑动的手绘内容页，
/// 点击标签与滑动内容共用同一 PageController，指示条随拖动实时跟手。
class DSTabs extends StatefulWidget {
  const DSTabs({
    super.key,
    required this.labels,
    required this.selected,
    this.onChanged,
    this.children,
    this.contentHeight,
  }) : assert(
         children == null || children.length == labels.length,
         'children 数量须与 labels 一致',
       ),
       assert(
         children == null || contentHeight != null,
         '提供 children 时必须同时提供 contentHeight',
       );

  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onChanged;

  /// 可选内容页，提供后启用滑动切换
  final List<Widget>? children;

  /// 内容区固定高度（PageView 需要有界高度）
  final double? contentHeight;

  @override
  State<DSTabs> createState() => _DSTabsState();
}

class _DSTabsState extends State<DSTabs> {
  PageController? _controller;

  @override
  void initState() {
    super.initState();
    _createControllerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant DSTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null) return;
    // 外部 selected 变化（点击标签等）时带动内容页。
    // 滑动触发的 onChanged 回流时 round(page) 已等于 selected，跳过，
    // 避免打断 PageView 自身的惯性吸附。
    final controller = _controller!;
    if (widget.selected != oldWidget.selected &&
        controller.hasClients &&
        controller.page?.round() != widget.selected) {
      controller.animateToPage(
        widget.selected,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _createControllerIfNeeded() {
    if (widget.children != null && _controller == null) {
      _controller = PageController(
        initialPage: widget.selected.clamp(0, widget.labels.length - 1),
      );
    }
  }

  double? get _livePage => _controller?.hasClients == true
      ? _controller!.page
      : null;

  @override
  Widget build(BuildContext context) {
    _createControllerIfNeeded();
    final theme = AppTheme.of(context);
    final disabled = widget.onChanged == null;
    final labels = widget.labels;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Pressable(
                  onPressed: disabled ? null : () => widget.onChanged!(i),
                  semanticLabel: labels[i],
                  builder: (context, states) {
                    final hovered = states.contains(WidgetState.hovered);
                    final active = i == widget.selected;
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: theme.spacing.sm + 2,
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: DsTypography.button.copyWith(
                            fontSize: 14,
                            color: active
                                ? theme.primaryText
                                : theme.textSub.withValues(
                                    alpha: hovered ? 0.9 : 0.75,
                                  ),
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        _buildIndicator(theme),
        if (widget.children != null)
          SizedBox(
            height: widget.contentHeight,
            child: PageView(
              controller: _controller,
              // 禁用态禁手势，保留程序化翻页
              physics: disabled ? const NeverScrollableScrollPhysics() : null,
              onPageChanged: widget.onChanged,
              children: widget.children!,
            ),
          ),
      ],
    );
  }

  /// 滑动手绘指示条：主色实底胶囊 + 墨线描边。
  /// 挂内容页时随 PageController 实时跟手，纯标签模式用 AnimatedAlign 补间。
  Widget _buildIndicator(AppThemeData theme) {
    final count = widget.labels.length;

    Widget pill() => FractionallySizedBox(
      widthFactor: 1 / count,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 12,
        margin: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
        // （rough 引擎墨迹内收数像素，需比果冻版略高才能画成胶囊）
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.primary,
          radius: theme.radii.pill,
          strokeWidth: 1.2,
        ),
      ),
    );

    Alignment alignmentOf(double page) => Alignment(
      count <= 1 ? -1 : -1 + 2 * (page / (count - 1)),
      0,
    );

    final controller = _controller;
    if (controller == null) {
      return SizedBox(
        height: 12,
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: alignmentOf(widget.selected.toDouble()),
          child: pill(),
        ),
      );
    }

    return SizedBox(
      height: 12,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Align(
          alignment: alignmentOf(_livePage ?? widget.selected.toDouble()),
          child: pill(),
        ),
      ),
    );
  }
}
