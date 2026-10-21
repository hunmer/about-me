import 'dart:async';

import 'package:flutter/widgets.dart';

import '../tokens/motion.dart';
import '../tokens/spacing.dart';
import 'page_indicator.dart';

/// 手绘轮播图：PageView + 底部叠放 [DSPageIndicator]
///
/// - 尺寸：[height] 与 [aspectRatio] 二选一，[height] 优先；
///   都不给时按 [aspectRatio]（默认 16:9）由可用宽度推高度
/// - [autoplay] 用 `Timer.periodic` 翻到下一页（末页循环回首页）；
///   动效减弱（`context.dsAnimationsDisabled`）或 [TickerMode] 静音
///   （上层路由遮挡）时暂停，恢复后继续；dispose 清理 Timer。
///   局限：未接入可见性检测，组件被滚出视口但 ticker 未静音的
///   场景仍会继续翻页；用户手动滑动也不重置计时（保持简单）
class DSCarousel extends StatefulWidget {
  const DSCarousel({
    super.key,
    required this.children,
    this.height,
    this.aspectRatio = 16 / 9,
    this.onPageChanged,
    this.autoplay = false,
    this.autoplayInterval = const Duration(seconds: 4),
    this.indicatorPadding = const EdgeInsets.only(bottom: DsSpacing.md),
  });

  final List<Widget> children;

  /// 固定高度（优先于 [aspectRatio]）
  final double? height;

  /// 宽高比（[height] 为 null 时生效）
  final double aspectRatio;

  final ValueChanged<int>? onPageChanged;

  /// 自动翻页（单页时自动失效）
  final bool autoplay;

  /// 自动翻页间隔
  final Duration autoplayInterval;

  /// 指示器相对轮播底边的内边距（默认底部 12）
  final EdgeInsetsGeometry indicatorPadding;

  @override
  State<DSCarousel> createState() => _DSCarouselState();
}

class _DSCarouselState extends State<DSCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;
  bool _tickerActive = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context) && !context.dsAnimationsDisabled;
    if (active != _tickerActive) {
      _tickerActive = active;
      _syncTimer();
    }
  }

  @override
  void didUpdateWidget(covariant DSCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoplay != widget.autoplay ||
        oldWidget.autoplayInterval != widget.autoplayInterval ||
        oldWidget.children.length != widget.children.length) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!widget.autoplay || !_tickerActive || widget.children.length < 2) {
      return;
    }
    _timer = Timer.periodic(widget.autoplayInterval, (_) {
      if (!_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % widget.children.length,
        duration: DsMotion.base,
        curve: DsMotion.curve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = widget.height ?? constraints.maxWidth / widget.aspectRatio;
        return SizedBox(
          height: h,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.children.length,
                onPageChanged: (index) {
                  setState(() => _page = index);
                  widget.onPageChanged?.call(index);
                },
                itemBuilder: (context, index) => widget.children[index],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: widget.indicatorPadding,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: DSPageIndicator(
                      count: widget.children.length,
                      index: _page,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
