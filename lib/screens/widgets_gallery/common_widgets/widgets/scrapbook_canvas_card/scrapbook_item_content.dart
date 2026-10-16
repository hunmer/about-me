import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scrapbook_item_models.dart';
import 'scrapbook_painters.dart';

/// 构建手帐条目内容（按 kind 分发）
Widget buildScrapItemContent(
  ScrapItemData item,
  bool isDark,
  void Function(String message) showToast,
) {
  switch (item.kind) {
    case ScrapItemKind.header:
      return _buildHeaderItem(item, isDark);
    case ScrapItemKind.photo:
      return _buildPhotoItem(item, isDark);
    case ScrapItemKind.text:
      return _buildTextItem(item, isDark);
    case ScrapItemKind.companions:
      return _buildCompanionsItem(item, isDark);
    case ScrapItemKind.sticker:
      return _buildStickerItem(item);
    case ScrapItemKind.gift:
      return _buildGiftItem(isDark, showToast);
  }
}

Widget _buildHeaderItem(ScrapItemData item, bool isDark) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        (item.dateLabel ?? '').toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: Color(0xFFB5AFA4),
          height: 1.1,
        ),
      ),
      Text(
        item.title ?? '',
        style: TextStyle(
          fontSize: 31,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
          height: 1.05,
          color: isDark ? Colors.white : const Color(0xFF111111),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        item.subtitle ?? '',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: isDark ? Colors.white : const Color(0xFF111111),
        ),
      ),
      SizedBox(
        width: 34,
        height: 10,
        child: CustomPaint(painter: ScrapSquigglePainter()),
      ),
    ],
  );
}

Widget _buildPhotoItem(ScrapItemData item, bool isDark) {
  final captionColor =
      item.captionColor ??
      (isDark ? Colors.white70 : const Color(0xFF1A1A1A));
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.narutomakiBorder)
                Padding(
                  padding: const EdgeInsets.only(bottom: 0),
                  child: SizedBox(
                    width: item.width,
                    height: 16,
                    child: CustomPaint(painter: ScrapNarutomakiRowPainter()),
                  ),
                ),
              _buildPhotoFrame(item),
            ],
          ),
          if (item.tape != null)
            Positioned(
              left: item.tape!.dx,
              top: item.tape!.dy,
              child: Transform.rotate(
                angle: item.tape!.angle * math.pi / 180,
                child: buildScrapTape(),
              ),
            ),
          if (item.bubbleText != null)
            Positioned(
              top: -20,
              right: -15,
              child: _buildCloudBubble(item.bubbleText!),
            ),
          if (item.sparklesDecor)
            const Positioned(
              top: -14,
              left: 4,
              child: SizedBox(
                width: 32,
                height: 30,
                child: CustomPaint(painter: ScrapSparklesPainter()),
              ),
            ),
        ],
      ),
      if (item.captions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in item.captions)
                Text(
                  line,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    height: 1.25,
                    color: captionColor,
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

Widget _buildPhotoFrame(ScrapItemData item) {
  const shadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  switch (item.artStyle) {
    case 'airplaneWindow':
      return Container(
        width: item.width,
        height: item.height,
        decoration: const BoxDecoration(
          color: Color(0xFF16151A),
          boxShadow: shadow,
        ),
        child: Center(
          child: Container(
            width: item.width * 0.7,
            height: item.height * 0.68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF2C2933), width: 2.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(painter: ScrapAirplaneWindowPainter()),
          ),
        ),
      );
    case 'fuji':
      return ClipPath(
        clipper: ScrapArchClipper(),
        child: Container(
          width: item.width,
          height: item.height,
          color: const Color(0xFF87A8C4),
          child: CustomPaint(painter: ScrapFujiPainter()),
        ),
      );
    case 'shinkansen':
      return Container(
        width: item.width,
        height: item.height,
        decoration: const BoxDecoration(
          color: Color(0xFF3E3D38),
          boxShadow: shadow,
        ),
        child: CustomPaint(painter: ScrapShinkansenPainter()),
      );
    case 'plushie':
      return Container(
        width: item.width,
        height: item.height,
        decoration: const BoxDecoration(
          color: Color(0xFFE8C84B),
          boxShadow: shadow,
        ),
        child: CustomPaint(painter: ScrapPlushiePainter()),
      );
    default:
      return Container(
        width: item.width,
        height: item.height,
        decoration: BoxDecoration(
          color: item.fallbackColor,
          boxShadow: shadow,
        ),
        clipBehavior: Clip.antiAlias,
        child:
            item.imageUrl != null
                ? (item.imageUrl!.startsWith('http')
                    ? Image.network(
                      item.imageUrl!,
                      width: item.width,
                      height: item.height,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) =>
                              Container(color: item.fallbackColor),
                    )
                    : Image.file(
                      File(item.imageUrl!),
                      width: item.width,
                      height: item.height,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) =>
                              Container(color: item.fallbackColor),
                    ))
                : null,
      );
  }
}

Widget _buildTextItem(ScrapItemData item, bool isDark) {
  final color =
      item.captionColor ??
      (isDark ? Colors.white : const Color(0xFF111111));
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final line in item.captions)
        Text(
          line,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            height: 1.25,
            color: color,
          ),
        ),
    ],
  );
}

Widget _buildCompanionsItem(ScrapItemData item, bool isDark) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'with',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFFD9388A),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 红心弧
          SizedBox(
            width: 24,
            height: 66,
            child: Stack(
              children: [
                Positioned(
                  left: 13,
                  top: -4,
                  child: Transform.rotate(
                    angle: -0.21,
                    child: Text('❤️', style: TextStyle(fontSize: 7)),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 5,
                  child: Transform.rotate(
                    angle: -0.35,
                    child: Text('❤️', style: TextStyle(fontSize: 8.5)),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 17,
                  child: Transform.rotate(
                    angle: 0.17,
                    child: Text('❤️', style: TextStyle(fontSize: 7)),
                  ),
                ),
                Positioned(
                  left: 2,
                  top: 27,
                  child: Transform.rotate(
                    angle: -0.14,
                    child: Text('❤️', style: TextStyle(fontSize: 10.5)),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 44,
                  child: Transform.rotate(
                    angle: 0.24,
                    child: Text('❤️', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in item.companions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: c.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          c.emoji,
                          style: const TextStyle(fontSize: 9, height: 1),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ],
  );
}

Widget _buildStickerItem(ScrapItemData item) {
  switch (item.stickerType) {
    case ScrapStickerType.tape:
      return buildScrapTape();
    case ScrapStickerType.cloud:
      return _buildCloudBubble(item.stickerText ?? 'omg!!');
    case ScrapStickerType.price:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3D5B5),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          '💸 ${item.stickerText ?? '-\$45'}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Color(0xFF1E1E1E),
          ),
        ),
      );
    case ScrapStickerType.sparkles:
      return const SizedBox(
        width: 38,
        height: 36,
        child: CustomPaint(painter: ScrapSparklesPainter()),
      );
  }
}

/// 胶带贴纸（贴纸条目与创建抽屉预览共用）
Widget buildScrapTape() {
  return Container(
    width: 44,
    height: 16,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xEBF4F1EA), Color(0xE0E8E4DB)],
      ),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: Center(
      child: Container(
        width: 18,
        height: 10,
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0x73A09A8E), width: 1),
            right: BorderSide(color: Color(0x73A09A8E), width: 1),
          ),
        ),
      ),
    ),
  );
}

Widget _buildCloudBubble(String text) {
  return SizedBox(
    width: 54,
    height: 42,
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ScrapCloudBubblePainter())),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: Color(0xFFD9388A),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 礼盒组合（黄色礼盒 + 小票 + 价格 pill + WISHLIST pill）
Widget _buildGiftItem(bool isDark, void Function(String message) showToast) {
  return SizedBox(
    width: 142,
    height: 178,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // 阶梯层叠底卡
        Positioned(
          left: 6,
          top: 14,
          child: Container(width: 116, height: 54, color: const Color(0xFF222421)),
        ),
        Positioned(
          left: 16,
          top: 6,
          child: Container(width: 96, height: 72, color: const Color(0xFF2E302B)),
        ),
        Positioned(
          left: 26,
          top: 0,
          child: Container(width: 76, height: 86, color: const Color(0xFF8E8468)),
        ),
        // 黄色礼盒
        Positioned(
          left: 38,
          top: 10,
          child: Container(
            width: 52,
            height: 76,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5D033), Color(0xFFE8BE1E), Color(0xFFC99E10)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGiftLogo('東京\n銀座'),
                const SizedBox(width: 3),
                _buildGiftLogo('GIN\nZA'),
              ],
            ),
          ),
        ),
        // 小票
        Positioned(
          left: 22,
          top: 60,
          child: Transform.rotate(
            angle: -4 * math.pi / 180,
            child: Container(
              width: 50,
              height: 66,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F3EF),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GINZA SIX',
                        style: TextStyle(
                          fontSize: 5.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        '06/02',
                        style: TextStyle(fontSize: 4, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Divider(height: 2, thickness: 0.4),
                  const Text(
                    'TOTAL  \$1,500',
                    style: TextStyle(
                      fontSize: 4.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: Colors.black,
                    ),
                  ),
                  // 条码
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final w in [1.5, 0.8, 2.0, 1.0, 1.5, 2.2, 0.8, 1.5, 1.0, 2.0])
                        Container(width: w, height: 8, color: Colors.black),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // 价格 pill
        Positioned(
          left: 76,
          top: 80,
          child: Transform.rotate(
            angle: -2 * math.pi / 180,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF3D5B5),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                '💸 -\$1,500',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: Color(0xFF1E1E1E),
                ),
              ),
            ),
          ),
        ),
        // 颜文字
        Positioned(
          left: 38,
          top: 123,
          child: Text(
            'ദ്ദി ( ᵔ ᗜ ᵔ )',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ),
        // WISHLIST pill
        Positioned(
          left: 36,
          top: 148,
          child: GestureDetector(
            onTap: () => showToast('🛍️ Ginza Uniqlo / Luxury Box • \$1,500'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE6E2D8)),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                '🔗 WISHLIST',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: Color(0xFF222222),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildGiftLogo(String text) {
  return Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: const Color(0xFFD9231E),
      border: Border.all(color: Colors.white.withOpacity(0.8), width: 0.5),
    ),
    alignment: Alignment.center,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 4.5,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        height: 1.1,
      ),
    ),
  );
}
