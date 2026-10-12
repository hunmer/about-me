import 'dart:io' show File;

import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 纪念日背景图层：按 URL 自动加载网络/本地图片并铺满容器
///
/// 图片上叠一层纸色遮罩（[dimAlpha]），保证其上的墨色文字可读；
/// 加载失败或 URL 为空时整体不占位。
/// 必须放在 `Stack` 中使用（自身 `StackFit.expand`）。
class MemorialBackgroundImage extends StatefulWidget {
  const MemorialBackgroundImage({
    super.key,
    required this.imageUrl,
    this.dimAlpha = 0.5,
  });

  final String imageUrl;

  /// 纸色遮罩不透明度（0~1），null 则不加遮罩
  final double? dimAlpha;

  @override
  State<MemorialBackgroundImage> createState() =>
      _MemorialBackgroundImageState();
}

class _MemorialBackgroundImageState extends State<MemorialBackgroundImage> {
  ImageProvider? _provider;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MemorialBackgroundImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.imageUrl;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      if (mounted) setState(() => _provider = NetworkImage(url));
      return;
    }
    try {
      final absolutePath = await ImageUtils.getAbsolutePath(url);
      if (mounted) setState(() => _provider = FileImage(File(absolutePath)));
    } catch (e) {
      debugPrint('[MemorialBackgroundImage] 加载背景图失败: $e');
      if (mounted) setState(() => _provider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) return const SizedBox.shrink();

    final theme = AppTheme.maybeOf(context);
    final dim = widget.dimAlpha;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: provider,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        if (dim != null && theme != null)
          ColoredBox(color: theme.surface.withValues(alpha: dim)),
      ],
    );
  }
}

/// 顶层手绘墨线描边：叠在图片等内容之上，保证墨线不被背景盖住
///
/// 与 `dsSketchDecoration(fillColor: null)` 等价的 CustomPaint 形式。
class SketchStrokeOverlay extends StatelessWidget {
  const SketchStrokeOverlay({
    super.key,
    required this.theme,
    this.radius,
    this.circle = false,
    this.strokeWidth = 1.8,
    this.seed = 1,
  });

  final AppThemeData theme;
  final BorderRadius? radius;
  final bool circle;
  final double strokeWidth;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DecorationPainter(
        dsSketchDecoration(
          theme: theme,
          radius: radius,
          circle: circle,
          strokeWidth: strokeWidth,
          seed: seed,
        ),
      ),
    );
  }
}

/// 把 [RoughBoxDecoration] 的 BoxPainter 适配成 CustomPainter
class _DecorationPainter extends CustomPainter {
  _DecorationPainter(this.decoration) : _painter = decoration.createBoxPainter();

  final RoughBoxDecoration decoration;
  final BoxPainter _painter;

  @override
  void paint(Canvas canvas, Size size) {
    _painter.paint(canvas, Offset.zero, ImageConfiguration(size: size));
  }

  @override
  bool shouldRepaint(_DecorationPainter oldDelegate) =>
      !identical(oldDelegate.decoration, decoration);
}
