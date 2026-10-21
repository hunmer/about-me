import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import 'icons.dart';
import 'skeleton.dart';

/// 手绘图片：圆角图片 + 贴边墨线描边框
///
/// 结构：[ClipRRect] 裁剪图片，rough 墨线经 `foregroundDecoration`
/// 画在容器真实边缘（内容之上叠墨线，层次做法同 card.dart）；
/// 加载中显示 [DSSkeleton] 占位，失败显示浅色底 + 手绘图图标。
/// [onTap] 为 null 时不可点；非 null 时按压轻微变暗（同 DSCard）。
class DsImage extends StatelessWidget {
  /// 统一构造：任意 [ImageProvider]
  const DsImage({
    super.key,
    required this.provider,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.onTap,
    this.semanticLabel,
  });

  /// asset 图片便捷构造
  factory DsImage.asset(
    String path, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? radius,
    VoidCallback? onTap,
    String? semanticLabel,
  }) => DsImage(
    provider: AssetImage(path),
    key: key,
    width: width,
    height: height,
    fit: fit,
    radius: radius,
    onTap: onTap,
    semanticLabel: semanticLabel,
  );

  /// 网络图片便捷构造
  factory DsImage.network(
    String url, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? radius,
    VoidCallback? onTap,
    String? semanticLabel,
  }) => DsImage(
    provider: NetworkImage(url),
    key: key,
    width: width,
    height: height,
    fit: fit,
    radius: radius,
    onTap: onTap,
    semanticLabel: semanticLabel,
  );

  final ImageProvider provider;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// 圆角（默认 theme.radii.lg）
  final BorderRadius? radius;

  /// null = 不可点
  final VoidCallback? onTap;

  /// 无障碍标签
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final r = radius ?? theme.radii.lg;

    final image = Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        // 高度未知时给一个中等占位高度（约束有界时以约束为准）
        return DSSkeleton(width: width, height: height ?? 140, radius: r);
      },
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: theme.surfaceAlt,
        alignment: Alignment.center,
        child: DsIcon(DsIconKind.image, color: theme.textSub),
      ),
    );

    final framed = Container(
      width: width,
      height: height,
      // 前景装饰：墨线画在图片之上、容器真实边缘（贴边）
      foregroundDecoration: dsSketchDecoration(
        theme: theme,
        stroke: theme.ink.withValues(alpha: 0.55),
        strokeWidth: 1.4,
        radius: r,
      ),
      child: ClipRRect(borderRadius: r, child: image),
    );

    if (onTap == null) return framed;
    return Pressable(
      onPressed: onTap,
      semanticLabel: semanticLabel,
      builder: (context, states) =>
          states.contains(WidgetState.pressed)
              ? Opacity(opacity: 0.85, child: framed)
              : framed,
    );
  }
}

/// 全屏手绘图片查看器
///
/// 挂在根 Overlay（rootOverlay）上，脱离当前主题树，内部重建 [AppTheme]
/// （同 showDSToast 的浮层模式）：
/// - barrier 用主题遮罩色淡入；点击 barrier 关闭（[dismissible] 为 false 时不可关）
/// - 图片放在 [InteractiveViewer] 里可缩放拖动，双击复位
/// - 图片带手绘墨线描边相框：DsSketchPanel 纸底 + 淡排线 + padding 包裹
/// - 入场 scale 0.92→1 + fade（[DsMotion.base] + [DsMotion.enter]）；
///   退场反向（[DsMotion.fast]）后移除 OverlayEntry
/// - 退场期间整体 [IgnorePointer]；动效减弱时直出直消
void showDsImageViewer(
  BuildContext context, {
  required ImageProvider image,
  bool dismissible = true,
}) {
  final theme = AppTheme.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => AppTheme(
      data: theme,
      child: _DsImageViewerView(
        image: image,
        dismissible: dismissible,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    ),
  );
  overlay.insert(entry);
}

class _DsImageViewerView extends StatefulWidget {
  const _DsImageViewerView({
    required this.image,
    required this.dismissible,
    required this.onDismiss,
  });

  final ImageProvider image;
  final bool dismissible;
  final VoidCallback onDismiss;

  @override
  State<_DsImageViewerView> createState() => _DsImageViewerViewState();
}

class _DsImageViewerViewState extends State<_DsImageViewerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final TransformationController _transform = TransformationController();
  bool _closing = false;
  bool _entered = false;
  bool _staticMode = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: DsMotion.base,
      reverseDuration: DsMotion.fast,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) return;
    _entered = true;
    _staticMode = context.dsAnimationsDisabled;
    if (_staticMode) {
      _ctrl.value = 1;
    } else {
      _ctrl.forward();
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    if (_staticMode) {
      widget.onDismiss();
      return;
    }
    _ctrl.reverse().whenCompleteOrCancel(widget.onDismiss);
  }

  /// 双击复位缩放/位移
  void _resetTransform() => _transform.value = Matrix4.identity();

  @override
  void dispose() {
    _transform.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return IgnorePointer(
      // 退场期间不响应任何点击
      ignoring: _closing,
      child: AnimatedBuilder(
        animation: _ctrl,
        child: _buildFrame(context),
        builder: (context, child) {
          final t = _ctrl.value.clamp(0.0, 1.0);
          return GestureDetector(
            onTap: widget.dismissible ? _close : null,
            child: ColoredBox(
              // barrier 淡入：遮罩色透明度随进度插值
              color: theme.barrier.withValues(alpha: theme.barrier.a * t),
              child: Padding(
                padding: MediaQuery.paddingOf(context),
                child: Center(
                  child: Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: 0.92 + 0.08 * DsMotion.enter.transform(t),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 相框：DsSketchPanel 纸底 + 墨框 + padding 包裹圆角图片
  Widget _buildFrame(BuildContext context) {
    final theme = AppTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    return GestureDetector(
      // 吃掉图片区域的单击，避免冒泡到 barrier 误关；双击复位
      onTap: () {},
      onDoubleTap: _resetTransform,
      child: InteractiveViewer(
        transformationController: _transform,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 1,
        maxScale: 4,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: size.width * 0.82,
            maxHeight: size.height * 0.74,
          ),
          child: DsSketchPanel(
            theme: theme,
            radius: theme.radii.xl,
            padding: EdgeInsets.all(theme.spacing.lg),
            child: ClipRRect(
              borderRadius: theme.radii.lg,
              child: Image(image: widget.image, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
