import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 朋友圈两块界面共用的视觉语言（复刻自 skygram 参考稿：
/// 天空渐变 + 云朵 + 果冻感软糖标签 + 玻璃拟态 dock）
class MomentsPalette {
  static const skyTop = Color(0xFF169AFF);
  static const skyMid = Color(0xFF3CB2FF);
  static const skyLight = Color(0xFF7DCDFF);
  static const activeBlue = Color(0xFF0088FF);
  static const skyChip = Color(0xFF38BDF8);

  static const pageBg = Color(0xFFF9FAFC);
  static const ink = Color(0xFF0F172A);
  static const inkSoft = Color(0xFF64748B);
  static const inkFaint = Color(0xFF94A3B8);
  static const mistBlue = Color(0xFFF1F5F9);
}

const _pillColors = {
  MomentPillStyle.purple: (bg: Color(0xFFF3EFFB), border: Color(0xFFE7DFF8), fg: Color(0xFF3B2854)),
  MomentPillStyle.orange: (bg: Color(0xFFFFF4ED), border: Color(0xFFFDE4D2), fg: Color(0xFF4A2C18)),
  MomentPillStyle.blue: (bg: Color(0xFFEAF4FF), border: Color(0xFFD5E8FF), fg: Color(0xFF1E3A5F)),
  MomentPillStyle.pink: (bg: Color(0xFFFFF0F4), border: Color(0xFFFFDBE4), fg: Color(0xFF592234)),
};

/// 果冻感兴趣标签（参考稿 .interest-pill）
class InterestPill extends StatelessWidget {
  final String label;
  final Widget? leading;
  final MomentPillStyle style;
  final bool selected;
  final VoidCallback? onTap;
  final double fontSize;
  final EdgeInsets padding;

  const InterestPill({
    super.key,
    required this.label,
    required this.style,
    this.leading,
    this.selected = false,
    this.onTap,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10.5, vertical: 4.5),
  });

  @override
  Widget build(BuildContext context) {
    final c = _pillColors[style]!;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: padding,
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? MomentsPalette.skyChip : c.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: MomentsPalette.skyChip.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 4.5)],
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: c.fg,
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
    this.padding = const EdgeInsets.symmetric(horizontal: 10.5, vertical: 4.5),
  });

  @override
  Widget build(BuildContext context) {
    return InterestPill(
      label: '${tag.emoji} ${tag.label}',
      style: tag.style,
      selected: selected,
      onTap: onTap,
      fontSize: fontSize,
      padding: padding,
    );
  }
}

/// 顶部圆形白色操作按钮（参考稿 .circle-icon-btn）
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final double size;
  final Widget? child;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.iconColor = const Color(0xFF1E293B),
    this.onTap,
    this.size = 36,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0C4A8A).withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child ??
            Icon(icon, size: size * 0.46, color: iconColor),
      ),
    );
  }
}

/// 用户「我」头像：天空蓝渐变圆 + 白色人像
class UserAvatar extends StatelessWidget {
  final double size;

  const UserAvatar({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0088FF), Color(0xFF6EC6FF)],
        ),
      ),
      child: Icon(Icons.person_rounded, size: size * 0.58, color: Colors.white),
    );
  }
}

/// 天空 + 体积感云朵头部背景（参考稿 .sky-canvas）
///
/// 云朵坐标按 375 宽的参考稿换算成横向比例，纵向保持像素值
class MomentsSkyHeader extends StatelessWidget {
  final double height;
  final bool profileVariant;

  const MomentsSkyHeader({
    super.key,
    this.height = 255,
    this.profileVariant = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SkyPainter(profileVariant: profileVariant),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Blob {
  final double dx; // 距左/右边缘的比例（基于 375 宽）
  final bool fromRight;
  final double top;
  final double w;
  final double h;
  final double opacity;
  final bool sharp;

  const _Blob(this.dx, this.fromRight, this.top, this.w, this.h, this.opacity, {this.sharp = false});
}

class _SkyPainter extends CustomPainter {
  final bool profileVariant;

  _SkyPainter({required this.profileVariant});

  static const _profileBlobs = [
    _Blob(0.053, true, -18, 145, 85, 0.88),
    _Blob(0.048, true, -8, 120, 75, 0.78, sharp: true),
    _Blob(0.096, false, 42, 130, 90, 0.72),
    _Blob(0.032, false, 82, 110, 80, 0.82, sharp: true),
    _Blob(0.08, false, 155, 180, 110, 0.94),
    _Blob(0.067, false, 162, 140, 95, 0.88, sharp: true),
    _Blob(0.093, true, 142, 185, 115, 0.94),
    _Blob(0.04, true, 158, 145, 95, 0.88, sharp: true),
    _Blob(0.181, false, 205, 240, 95, 0.96),
  ];

  static const _feedBlobs = [
    _Blob(0.04, true, -12, 150, 85, 0.86),
    _Blob(0.075, false, 58, 140, 85, 0.8),
    _Blob(0.213, false, 120, 220, 90, 0.9, sharp: true),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 天空渐变（末端融入白色，参考稿 #169aff → #3cb2ff → #7dcdff → #ffffff）
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MomentsPalette.skyTop,
            MomentsPalette.skyMid,
            MomentsPalette.skyLight,
            Colors.white,
          ],
          stops: [0.0, 0.45, 0.76, 1.0],
        ).createShader(rect),
    );

    // 云朵
    for (final b in profileVariant ? _profileBlobs : _feedBlobs) {
      final x = b.fromRight ? size.width - b.dx * 375 - b.w : b.dx * 375;
      final center = Offset(x + b.w / 2, b.top + b.h / 2);
      final radius = b.w / 2;
      if (b.sharp) {
        final paint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.98 * b.opacity),
              Colors.white.withValues(alpha: 0.82 * b.opacity),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.55, 0.75],
          ).createShader(Rect.fromCircle(center: center, radius: radius));
        canvas.drawCircle(center, radius, paint);
      } else {
        final paint = Paint()
          ..color = Colors.white.withValues(alpha: b.opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(center, radius * math.max(1, b.h / b.w * 0.9), paint);
      }
    }

    // 底部白色薄雾过渡
    final fadeH = math.min(95.0, size.height * 0.32);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - fadeH, size.width, fadeH),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.82),
            Colors.white,
          ],
        ).createShader(Rect.fromLTWH(0, size.height - fadeH, size.width, fadeH)),
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) =>
      oldDelegate.profileVariant != profileVariant;
}

/// 朋友圈本地相对路径图片（等比裁切填充，失败显示占位）
class MomentImage extends StatelessWidget {
  final String path;
  final double? height;
  final BoxFit fit;

  const MomentImage({super.key, required this.path, this.height, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: ImageUtils.getAbsolutePath(path),
      builder: (context, snapshot) {
        Widget child = Container(
          color: const Color(0xFFE2E8F0),
          alignment: Alignment.center,
          child: const Icon(Icons.image_outlined, color: Colors.white24, size: 28),
        );
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final file = File(snapshot.data!);
          if (file.existsSync()) {
            child = Image.file(file, fit: fit, errorBuilder: (_, __, ___) => child);
          }
        }
        return SizedBox(width: double.infinity, height: height, child: child);
      },
    );
  }
}
