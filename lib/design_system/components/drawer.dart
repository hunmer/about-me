import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/motion.dart';

/// 抽屉弹出侧
enum DsDrawerSide { left, right, bottom }

/// 手绘抽屉：rootOverlay 浮层面板（左/右/底部滑入）
///
/// 面板为 [DsSketchPanel]（纸底 + 淡排线 + 墨线框），
/// 入场自侧边位移滑入（[DsMotion.slow] + [DsMotion.enter]），
/// barrier 淡入；点 barrier 或调用方自行收起时反向播放
/// （≈[DsMotion.base]）后移除浮层。
///
/// ```dart
/// // 侧边抽屉（默认左，宽 320）
/// showDSDrawer(
///   context,
///   builder: (context) => ListView(children: [...]),
/// );
///
/// // 底部抽屉：高度按内容、封顶屏高 60%
/// showDSDrawer(
///   context,
///   side: DsDrawerSide.bottom,
///   builder: (context) => DsListItem(title: '...'),
/// );
/// ```
void showDSDrawer(
  BuildContext context, {
  required WidgetBuilder builder,
  DsDrawerSide side = DsDrawerSide.left,
  double? width,
  double? height,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  // 浮层挂在根 Overlay，脱离主题树，这里提前捕获主题
  final theme = AppTheme.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => AppTheme(
      data: theme,
      child: _DsDrawerHost(
        entry: entry,
        theme: theme,
        builder: builder,
        side: side,
        width: width,
        height: height,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
      ),
    ),
  );
  overlay.insert(entry);
}

/// 抽屉宿主：管理入场/退场动画与浮层生命周期
class _DsDrawerHost extends StatefulWidget {
  const _DsDrawerHost({
    required this.entry,
    required this.theme,
    required this.builder,
    required this.side,
    required this.width,
    required this.height,
    required this.barrierDismissible,
    required this.barrierColor,
  });

  final OverlayEntry entry;
  final AppThemeData theme;
  final WidgetBuilder builder;
  final DsDrawerSide side;
  final double? width;
  final double? height;
  final bool barrierDismissible;
  final Color? barrierColor;

  @override
  State<_DsDrawerHost> createState() => _DsDrawerHostState();
}

class _DsDrawerHostState extends State<_DsDrawerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _progress;

  /// 退场中：整个浮层 IgnorePointer，防连点
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DsMotion.slow,
      value: 0,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: DsMotion.enter,
      // 出场收回用 easeIn：让滑出加速离场，与入场的回弹对称
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首帧依赖 MediaQuery（减少动画时直接就位，不播入场）
    if (_controller.value == 0 && !_controller.isAnimating) {
      if (context.dsAnimationsDisabled) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    if (mounted) setState(() {});
    // reverse() 不接受 duration 覆写，退场时长写回控制器
    _controller.duration = context.dsAnimationsDisabled
        ? Duration.zero
        : DsMotion.base;
    await _controller.reverse();
    widget.entry.remove();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      ignoring: _closing,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final t = _progress.value;
          return Stack(
            children: [
              // barrier：淡入淡出的全屏遮罩 + 点击关闭
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !widget.barrierDismissible,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: ColoredBox(
                        color: widget.barrierColor ?? theme.barrier,
                      ),
                    ),
                  ),
                ),
              ),
              // 面板：自侧边位移滑入（easeOutBack 的过冲即贴纸回弹）
              Align(
                alignment: widget.side == DsDrawerSide.left
                    ? Alignment.centerLeft
                    : widget.side == DsDrawerSide.right
                    ? Alignment.centerRight
                    : Alignment.bottomCenter,
                child: FractionalTranslation(
                  translation: switch (widget.side) {
                    DsDrawerSide.left => Offset(-(1 - t), 0),
                    DsDrawerSide.right => Offset(1 - t, 0),
                    DsDrawerSide.bottom => Offset(0, 1 - t),
                  },
                  child: _buildPanel(context, size),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPanel(BuildContext context, Size viewport) {
    final theme = widget.theme;
    switch (widget.side) {
      case DsDrawerSide.left:
      case DsDrawerSide.right:
        final sideWidth = (widget.width ?? 320)
            .clamp(0.0, viewport.width)
            .toDouble();
        return DsSketchPanel(
          theme: theme,
          width: sideWidth,
          height: viewport.height,
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.lg,
            vertical: theme.spacing.lg,
          ),
          child: widget.builder(context),
        );
      case DsDrawerSide.bottom:
        // 底部：宽度铺满，高度按内容自适应、封顶屏高 60%
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: viewport.height * 0.6),
          child: DsSketchPanel(
            theme: theme,
            width: viewport.width,
            height: widget.height,
            radius: BorderRadius.vertical(top: theme.radii.xl.topLeft),
            padding: EdgeInsets.all(theme.spacing.xl),
            child: widget.builder(context),
          ),
        );
    }
  }
}
