import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 头像旁的 SVG 刻贴纸（复刻参考稿 4 枚 die-cut 贴纸）。
///
/// 原稿白描边用 SVG 滤镜（feMorphology 膨胀）实现，flutter_svg 的
/// vector_graphics 后端不支持滤镜——这里改为把主要轮廓路径以粗白描边
/// 先画一遍再叠彩色本体，等效烘焙出白色刻贴纸边。
class MomentStickerKind {
  final String svg;
  final double width;
  final double height;

  const MomentStickerKind(this.svg, this.width, this.height);
}

/// 辣椒（参考稿 sticker-chili）
const _chiliSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 110 105" fill="none">
  <g stroke="#FFFFFF" stroke-width="9.5" stroke-linecap="round" stroke-linejoin="round" fill="none">
    <path d="M26 72C15 64 13 46 21 34C22 41 27 43 28 38C30 27 25 17 33 8C38 15 44 23 43 34C46 31 49 25 49 20C56 28 57 42 52 54C46 67 36 75 26 72Z"/>
    <path d="M47 41C51 32 62 32 65 40C68 53 60 72 44 82C33 89 22 86 20 82C19 79 25 78 32 73C41 66 44 50 47 41Z"/>
    <path d="M56 35C57 27 63 20 71 19"/>
    <path d="M62 43C67 34 79 36 81 46C83 62 71 82 51 89C38 93 25 89 23 85C22 82 29 81 38 77C51 71 58 53 62 43Z"/>
    <path d="M64 41C68 38 76 39 79 44C75 41 68 41 64 41Z"/>
    <path d="M72 40C74 31 80 24 89 23"/>
  </g>
  <path d="M26 72C15 64 13 46 21 34C22 41 27 43 28 38C30 27 25 17 33 8C38 15 44 23 43 34C46 31 49 25 49 20C56 28 57 42 52 54C46 67 36 75 26 72Z" fill="#FF6B1A"/>
  <path d="M29 70C22 64 21 52 27 43C28 47 32 48 33 43C35 36 33 29 37 23C41 28 44 35 43 43C47 49 44 63 36 69C33 71 31 71 29 70Z" fill="#FF9E2C"/>
  <path d="M32 68C28 64 28 57 32 51C34 55 37 51 38 46C41 51 41 61 36 66C35 68 33 69 32 68Z" fill="#FFE066"/>
  <path d="M47 41C51 32 62 32 65 40C68 53 60 72 44 82C33 89 22 86 20 82C19 79 25 78 32 73C41 66 44 50 47 41Z" fill="#D91B1B"/>
  <path d="M56 35C57 27 63 20 71 19" stroke="#15803D" stroke-width="5" stroke-linecap="round"/>
  <path d="M62 43C67 34 79 36 81 46C83 62 71 82 51 89C38 93 25 89 23 85C22 82 29 81 38 77C51 71 58 53 62 43Z" fill="#EF2323"/>
  <path d="M68 48C68 58 61 70 49 77" stroke="#FF8585" stroke-width="3.2" stroke-linecap="round" opacity="0.75"/>
  <path d="M64 41C68 38 76 39 79 44C75 41 68 41 64 41Z" fill="#16A34A"/>
  <path d="M72 40C74 31 80 24 89 23" stroke="#15803D" stroke-width="5" stroke-linecap="round"/>
  <path d="M47 41C51 32 62 32 65 40M62 43C67 34 79 36 81 46C83 62 71 82 51 89C38 93 25 89 23 85C22 82 29 81 38 77C51 71 58 53 62 43Z" stroke="#3B0A0A" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

/// 炸弹（参考稿 sticker-bomb）
const _bombSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 94" fill="none">
  <g stroke="#FFFFFF" stroke-width="9" stroke-linecap="round" stroke-linejoin="round" fill="none">
    <path d="M54 34C60 28 67 27 74 29"/>
    <path d="M45 33L54 27L61 36L51 43L45 33Z"/>
    <circle cx="36" cy="54" r="24"/>
    <path d="M75 11L78 22L89 17L82 27L93 33L80 34L83 45L74 36L65 43L69 32L59 27L70 25L75 11Z"/>
  </g>
  <path d="M54 34C60 28 67 27 74 29" stroke="#64748B" stroke-width="4" stroke-linecap="round"/>
  <path d="M45 33L54 27L61 36L51 43L45 33Z" fill="#60A5FA" stroke="#1E293B" stroke-width="2.4" stroke-linejoin="round"/>
  <ellipse cx="54" cy="31" rx="6" ry="3.2" transform="rotate(35 54 31)" fill="#93C5FD" stroke="#1E293B" stroke-width="2.2"/>
  <circle cx="36" cy="54" r="24" fill="#18181B" stroke="#09090B" stroke-width="2.5"/>
  <path d="M20 69C29 77 45 76 54 66" stroke="#3F3F46" stroke-width="3" stroke-linecap="round"/>
  <path d="M21 46C23 39 29 35 36 35" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>
  <path d="M75 11L78 22L89 17L82 27L93 33L80 34L83 45L74 36L65 43L69 32L59 27L70 25L75 11Z" fill="#EF4444" stroke="#B91C1C" stroke-width="1.5" stroke-linejoin="round"/>
  <path d="M75 17L77 24L84 21L79 27L86 31L78 32L80 38L74 33L69 37L71 30L65 27L72 26L75 17Z" fill="#FBBF24"/>
  <circle cx="75" cy="29" r="3" fill="#FEF08A"/>
</svg>''';

/// 鸡尾酒（参考稿 sticker-cocktail）
const _cocktailSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 102" fill="none">
  <g stroke="#FFFFFF" stroke-width="9" stroke-linecap="round" stroke-linejoin="round" fill="none">
    <path d="M35 14L41 40"/>
    <path d="M16 34L58 23L42 54L16 34Z"/>
    <path d="M42 54L50 74"/>
    <path d="M28 73C24 69 27 62 34 62L46 61C51 56 59 56 62 61C67 60 72 64 70 70C74 73 73 80 67 82C65 86 58 88 49 87L36 86C28 85 25 78 28 73Z"/>
  </g>
  <path d="M35 14L41 40" stroke="#38BDF8" stroke-width="4" stroke-linecap="round"/>
  <path d="M35 14L41 40" stroke="#0284C7" stroke-width="4" stroke-dasharray="3 3" stroke-linecap="round"/>
  <path d="M16 34L58 23L42 54L16 34Z" fill="#BAE6FD" fill-opacity="0.85" stroke="#334155" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M23 36L52 28L41 50L23 36Z" fill="#F97316"/>
  <path d="M23 36L52 28L38 38L23 36Z" fill="#FB923C"/>
  <path d="M42 54L50 74" stroke="#334155" stroke-width="2.6" stroke-linecap="round"/>
  <path d="M28 73C24 69 27 62 34 62L46 61C51 56 59 56 62 61C67 60 72 64 70 70C74 73 73 80 67 82C65 86 58 88 49 87L36 86C28 85 25 78 28 73Z" fill="#FFFFFF" stroke="#334155" stroke-width="2.2" stroke-linejoin="round"/>
  <path d="M50 67C56 66 63 67 68 70" stroke="#334155" stroke-width="2" stroke-linecap="round"/>
  <path d="M51 74C57 73 63 75 67 78" stroke="#334155" stroke-width="2" stroke-linecap="round"/>
  <path d="M37 68C41 67 45 69 45 73C45 76 41 78 36 77" stroke="#334155" stroke-width="2" stroke-linecap="round"/>
</svg>''';

/// Figma 几何贴纸（参考稿 sticker-figma）
const _figmaSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 88 104" fill="none">
  <defs>
    <linearGradient id="figRed" x1="15" y1="16" x2="44" y2="38" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FF5E4D"/><stop offset="1" stop-color="#FF7A59"/>
    </linearGradient>
    <linearGradient id="figOrange" x1="44" y1="16" x2="71" y2="38" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FF8364"/><stop offset="1" stop-color="#FFA372"/>
    </linearGradient>
    <linearGradient id="figPurple" x1="15" y1="38" x2="44" y2="60" gradientUnits="userSpaceOnUse">
      <stop stop-color="#A855F7"/><stop offset="1" stop-color="#C084FC"/>
    </linearGradient>
    <linearGradient id="figBlue" x1="45" y1="38" x2="69" y2="60" gradientUnits="userSpaceOnUse">
      <stop stop-color="#38BDF8"/><stop offset="1" stop-color="#93C5FD"/>
    </linearGradient>
    <linearGradient id="figGreen" x1="22" y1="60" x2="44" y2="82" gradientUnits="userSpaceOnUse">
      <stop stop-color="#6EE7B7"/><stop offset="1" stop-color="#A7F3D0"/>
    </linearGradient>
  </defs>
  <g stroke="#FFFFFF" stroke-width="11" stroke-linejoin="round" fill="none">
    <path d="M26 16H44V38H26C19.9 38 15 33.1 15 27C15 20.9 19.9 16 26 16Z"/>
    <path d="M44 16H60C66.1 16 71 20.9 71 27C71 33.1 66.1 38 60 38H44V16Z"/>
    <path d="M26 38H44V60H26C19.9 60 15 55.1 15 49C15 42.9 19.9 38 26 38Z"/>
    <circle cx="57" cy="49" r="11.5"/>
    <path d="M26 60H44V71C44 77.1 39.1 82 33 82C26.9 82 22 77.1 22 71C22 64.9 23.5 60 26 60Z"/>
  </g>
  <path d="M26 16H44V38H26C19.9249 38 15 33.0751 15 27C15 20.9249 19.9249 16 26 16Z" fill="url(#figRed)"/>
  <path d="M44 16H60C66.0751 16 71 20.9249 71 27C71 33.0751 66.0751 38 60 38H44V16Z" fill="url(#figOrange)"/>
  <path d="M26 38H44V60H26C19.9249 60 15 55.0751 15 49C15 42.9249 19.9249 38 26 38Z" fill="url(#figPurple)"/>
  <circle cx="57" cy="49" r="11.5" fill="url(#figBlue)"/>
  <path d="M26 60H44V71C44 77.0751 39.0751 82 33 82C26.9249 82 22 77.0751 22 71C22 64.9249 23.5 60 26 60Z" fill="url(#figGreen)"/>
</svg>''';

const stickerChili = MomentStickerKind(_chiliSvg, 86, 82);
const stickerBomb = MomentStickerKind(_bombSvg, 78, 74);
const stickerCocktail = MomentStickerKind(_cocktailSvg, 76, 82);
const stickerFigma = MomentStickerKind(_figmaSvg, 72, 86);

/// 漂浮的刻贴纸：缓慢正弦漂浮 + 轻微摇摆（非按钮，无点击态）
class MomentSticker extends StatefulWidget {
  final MomentStickerKind kind;
  final double rotation;
  final double amplitude;

  const MomentSticker({
    super.key,
    required this.kind,
    required this.rotation,
    this.amplitude = 4,
  });

  @override
  State<MomentSticker> createState() => _MomentStickerState();
}

class _MomentStickerState extends State<MomentSticker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final dy = -widget.amplitude * math.sin(t * 2 * math.pi);
        final wobble = 0.05 * math.sin(t * 2 * math.pi + math.pi / 3);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: widget.rotation + wobble,
            child: SvgPicture.string(
              widget.kind.svg,
              width: widget.kind.width,
              height: widget.kind.height,
            ),
          ),
        );
      },
    );
  }
}
