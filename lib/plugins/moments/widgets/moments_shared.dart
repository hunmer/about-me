import 'dart:io';

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart'
    show DrawConfig, waverPath, waveredPolygons;

import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 手绘软糖标签（design.md §9.1：dsSketchDecoration 实底 + 墨线抖动描边）
class InterestPill extends StatelessWidget {
  final String label;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;
  final double fontSize;
  final EdgeInsets padding;

  const InterestPill({
    super.key,
    required this.label,
    this.leading,
    this.selected = false,
    this.onTap,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: selected ? theme.primary : theme.surfaceAlt,
          stroke: theme.ink.withValues(alpha: selected ? 0.75 : 0.45),
          radius: BorderRadius.circular(999),
          seed: label.hashCode & 0x7fffffff,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(
                  size: fontSize + 2,
                  color: selected ? theme.onPrimary : theme.textSub,
                ),
                child: leading!,
              ),
              const SizedBox(width: 4.5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? theme.onPrimary : theme.textSub,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 标签软糖（emoji + 标签名）
class TagPill extends StatelessWidget {
  final MomentTag tag;
  final bool selected;
  final VoidCallback? onTap;
  final double fontSize;
  final EdgeInsets padding;

  const TagPill({
    super.key,
    required this.tag,
    this.selected = false,
    this.onTap,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
  });

  @override
  Widget build(BuildContext context) {
    return InterestPill(
      label: '${tag.emoji} ${tag.label}',
      selected: selected,
      onTap: onTap,
      fontSize: fontSize,
      padding: padding,
    );
  }
}

/// 用户「我」头像：主题色实底墨线圆 + 白色人像
class UserAvatar extends StatelessWidget {
  final double size;

  const UserAvatar({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.primary,
        stroke: theme.ink.withValues(alpha: 0.6),
        circle: true,
      ),
      child: Center(
        child: DsIcon(
          DsIconKind.user,
          size: size * 0.55,
          color: theme.onPrimary,
        ),
      ),
    );
  }
}

/// 手绘云朵头部背景（design.md §9：无渐变/柔影，墨线云 + 纸底）
///
/// 云朵用 skribble waver 轮廓绘制：纸底填充 + 墨线描边，
/// 坐标按 375 宽参考稿换算成横向比例
class MomentsSkyHeader extends StatelessWidget {
  final double height;
  final bool profileVariant;

  const MomentsSkyHeader({
    super.key,
    this.height = 180,
    this.profileVariant = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CloudsPainter(
          profileVariant: profileVariant,
          config: theme.wired.drawConfig,
          paper: theme.paper,
          ink: theme.ink,
          wash: theme.hatch.withValues(alpha: theme.isDark ? 0.10 : 0.16),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CloudSpec {
  final double dx; // 距左边缘比例（基于 375 宽）
  final double top;
  final double scale;
  final double opacity;

  const _CloudSpec(this.dx, this.top, this.scale, this.opacity);
}

const _profileClouds = [
  _CloudSpec(0.62, 6, 1.25, 0.9),
  _CloudSpec(0.02, 48, 1.0, 0.8),
  _CloudSpec(0.05, 128, 1.15, 0.85),
  _CloudSpec(0.66, 120, 1.2, 0.85),
  _CloudSpec(0.25, 178, 1.5, 0.9),
];

const _feedClouds = [
  _CloudSpec(0.55, 10, 1.1, 0.85),
  _CloudSpec(0.03, 34, 0.95, 0.8),
  _CloudSpec(0.16, 76, 1.35, 0.85),
];

class _CloudsPainter extends CustomPainter {
  _CloudsPainter({
    required this.profileVariant,
    required this.config,
    required this.paper,
    required this.ink,
    required this.wash,
  });

  final bool profileVariant;
  final DrawConfig config;
  final Color paper;
  final Color ink;
  final Color wash;

  /// 单朵云的基础轮廓（几个相接的圆拱，viewBox 160×70）
  static Path _cloudBase(Size size) {
    final s = size.shortestSide;
    return Path()
      ..addOval(Rect.fromCircle(center: Offset(s * 0.30, s * 0.62), radius: s * 0.30))
      ..addOval(Rect.fromCircle(center: Offset(s * 0.55, s * 0.42), radius: s * 0.38))
      ..addOval(Rect.fromCircle(center: Offset(s * 0.85, s * 0.66), radius: s * 0.26));
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 顶部主色淡水洗（实底色，非渐变装饰）
    final washRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.72);
    canvas.drawRect(washRect, Paint()..color = wash);

    for (final c in profileVariant ? _profileClouds : _feedClouds) {
      final w = 150.0 * c.scale;
      final h = 66.0 * c.scale;
      final x = c.dx * 375;
      if (x > size.width) continue;
      final rect = Rect.fromLTWH(x, c.top, w, h);
      final path = _cloudBase(Size(w, h)).shift(rect.topLeft);

      final wavered = waveredPolygons(waverPath(path, config, amplitude: 1.0));
      _drawCloud(canvas, wavered, c.opacity);
    }
  }

  void _drawCloud(Canvas canvas, Path wavered, double opacity) {
    canvas.drawPath(
      wavered,
      Paint()..color = paper.withValues(alpha: 0.96 * opacity),
    );
    canvas.drawPath(
      wavered,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = ink.withValues(alpha: 0.55 * opacity),
    );
  }

  @override
  bool shouldRepaint(covariant _CloudsPainter oldDelegate) =>
      oldDelegate.profileVariant != profileVariant ||
      oldDelegate.config != config ||
      oldDelegate.paper != paper ||
      oldDelegate.ink != ink ||
      oldDelegate.wash != wash;
}

/// 朋友圈本地相对路径图片（等比裁切填充，失败显示占位）
class MomentImage extends StatelessWidget {
  final String path;
  final double? height;
  final BoxFit fit;

  const MomentImage({
    super.key,
    required this.path,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return FutureBuilder<String>(
      future: ImageUtils.getAbsolutePath(path),
      builder: (context, snapshot) {
        Widget child = Container(
          color: theme.surfaceAlt,
          alignment: Alignment.center,
          child: DsIcon(DsIconKind.image, size: 26, color: theme.textSub),
        );
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final file = File(snapshot.data!);
          if (file.existsSync()) {
            child = Image.file(
              file,
              fit: fit,
              errorBuilder: (_, __, ___) => child,
            );
          }
        }
        return SizedBox(width: double.infinity, height: height, child: child);
      },
    );
  }
}
