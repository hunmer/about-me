import 'package:flutter/material.dart';

/// 手帐画布条目类型
enum ScrapItemKind { header, photo, text, companions, sticker, gift }

/// 贴纸子类型
enum ScrapStickerType { tape, cloud, price, sparkles }

/// 同行人数据
class ScrapCompanionData {
  final String name;
  final String emoji;
  final Color color;

  const ScrapCompanionData({
    required this.name,
    required this.emoji,
    required this.color,
  });

  factory ScrapCompanionData.fromMap(Map<String, dynamic> map) {
    return ScrapCompanionData(
      name: map['name'] as String? ?? '',
      emoji: map['emoji'] as String? ?? '🙂',
      color: _parseColor(map['color'], const Color(0xFFFFE4D6)),
    );
  }
}

/// 胶带贴纸装饰数据（相对条目左上角偏移）
class ScrapTapeData {
  final double dx;
  final double dy;
  final double angle;

  const ScrapTapeData({required this.dx, required this.dy, this.angle = 0});

  factory ScrapTapeData.fromMap(Map<String, dynamic> map) {
    return ScrapTapeData(
      dx: (map['dx'] as num?)?.toDouble() ?? 0,
      dy: (map['dy'] as num?)?.toDouble() ?? 0,
      angle: (map['angle'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 用户涂鸦笔画
class ScrapStroke {
  final Color color;
  final List<Offset> points;

  ScrapStroke(this.color, this.points);

  factory ScrapStroke.fromMap(Map<String, dynamic> map) {
    return ScrapStroke(
      _parseColor(map['color'], const Color(0xFF56A8E8)),
      (map['points'] as List?)
              ?.whereType<List>()
              .map(
                (p) => Offset(
                  (p[0] as num?)?.toDouble() ?? 0,
                  (p[1] as num?)?.toDouble() ?? 0,
                ),
              )
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'color': _colorToHex(color),
    'points': [for (final p in points) [p.dx, p.dy]],
  };
}

/// 颜色序列化为 #RRGGBB（与 [_parseColor] 的 '#' 分支对称）
String _colorToHex(Color color) {
  final argb = color.toARGB32() & 0xFFFFFF;
  return '#${argb.toRadixString(16).padLeft(6, '0')}';
}

Color _parseColor(dynamic value, Color fallback) {
  if (value == null) return fallback;
  if (value is Color) return value;
  if (value is int) return Color(value);
  if (value is String) {
    try {
      if (value.startsWith('#')) {
        return Color(int.parse(value.substring(1), radix: 16) + 0xFF000000);
      }
      if (value.startsWith('0x')) {
        return Color(int.parse(value.substring(2), radix: 16));
      }
    } catch (_) {
      // 解析失败走兜底
    }
  }
  return fallback;
}

ScrapItemKind _parseKind(dynamic value) {
  switch (value) {
    case 'header':
      return ScrapItemKind.header;
    case 'photo':
      return ScrapItemKind.photo;
    case 'companions':
      return ScrapItemKind.companions;
    case 'sticker':
      return ScrapItemKind.sticker;
    case 'gift':
      return ScrapItemKind.gift;
    case 'text':
    default:
      return ScrapItemKind.text;
  }
}

ScrapStickerType _parseStickerType(dynamic value) {
  switch (value) {
    case 'cloud':
      return ScrapStickerType.cloud;
    case 'price':
      return ScrapStickerType.price;
    case 'sparkles':
      return ScrapStickerType.sparkles;
    case 'tape':
    default:
      return ScrapStickerType.tape;
  }
}

/// 手帐画布条目数据模型（x/y/rotation/zIndex 可在交互中被修改）
class ScrapItemData {
  final String id;
  final ScrapItemKind kind;
  double x;
  double y;
  double rotation;
  int zIndex;

  // header
  final String? dateLabel;
  final String? title;
  final String? subtitle;

  // photo
  final String? imageUrl;
  final double width;
  final double height;
  final Color fallbackColor;
  final List<String> captions;
  final Color? captionColor;

  /// 手绘图风格：airplaneWindow / fuji / shinkansen / plushie，null 则加载网络图
  final String? artStyle;
  final ScrapTapeData? tape;
  final String? bubbleText;
  final bool narutomakiBorder;
  final bool sparklesDecor;

  // companions
  final List<ScrapCompanionData> companions;

  // sticker
  final ScrapStickerType stickerType;
  final String? stickerText;
  final Color? stickerColor;

  ScrapItemData({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.rotation = 0,
    this.zIndex = 20,
    this.dateLabel,
    this.title,
    this.subtitle,
    this.imageUrl,
    this.width = 96,
    this.height = 132,
    this.fallbackColor = const Color(0xFFE5E0D5),
    this.captions = const [],
    this.captionColor,
    this.artStyle,
    this.tape,
    this.bubbleText,
    this.narutomakiBorder = false,
    this.sparklesDecor = false,
    this.companions = const [],
    this.stickerType = ScrapStickerType.tape,
    this.stickerText,
    this.stickerColor,
  });

  factory ScrapItemData.fromMap(Map<String, dynamic> map) {
    return ScrapItemData(
      id: map['id'] as String? ?? 'item_${map.hashCode}',
      kind: _parseKind(map['kind']),
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0,
      zIndex: (map['zIndex'] as num?)?.toInt() ?? 20,
      dateLabel: map['dateLabel'] as String?,
      title: map['title'] as String?,
      subtitle: map['subtitle'] as String?,
      imageUrl: map['imageUrl'] as String?,
      width: (map['width'] as num?)?.toDouble() ?? 96,
      height: (map['height'] as num?)?.toDouble() ?? 132,
      fallbackColor: _parseColor(
        map['fallbackColor'],
        const Color(0xFFE5E0D5),
      ),
      captions:
          (map['captions'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      captionColor:
          map['captionColor'] != null
              ? _parseColor(map['captionColor'], const Color(0xFFD9388A))
              : null,
      artStyle: map['artStyle'] as String?,
      tape:
          map['tape'] is Map<String, dynamic>
              ? ScrapTapeData.fromMap(map['tape'] as Map<String, dynamic>)
              : null,
      bubbleText: map['bubbleText'] as String?,
      narutomakiBorder: map['narutomakiBorder'] as bool? ?? false,
      sparklesDecor: map['sparklesDecor'] as bool? ?? false,
      companions:
          (map['companions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ScrapCompanionData.fromMap)
              .toList(growable: false) ??
          const [],
      stickerType: _parseStickerType(map['stickerType']),
      stickerText: map['stickerText'] as String?,
      stickerColor:
          map['stickerColor'] != null
              ? _parseColor(map['stickerColor'], const Color(0xFFD9388A))
              : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind.name,
    'x': x,
    'y': y,
    'rotation': rotation,
    'zIndex': zIndex,
    if (dateLabel != null) 'dateLabel': dateLabel,
    if (title != null) 'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    if (imageUrl != null) 'imageUrl': imageUrl,
    'width': width,
    'height': height,
    'fallbackColor': _colorToHex(fallbackColor),
    if (captions.isNotEmpty) 'captions': captions,
    if (captionColor != null) 'captionColor': _colorToHex(captionColor!),
    if (artStyle != null) 'artStyle': artStyle,
    if (tape != null)
      'tape': {'dx': tape!.dx, 'dy': tape!.dy, 'angle': tape!.angle},
    if (bubbleText != null) 'bubbleText': bubbleText,
    if (narutomakiBorder) 'narutomakiBorder': true,
    if (sparklesDecor) 'sparklesDecor': true,
    if (companions.isNotEmpty)
      'companions': [
        for (final c in companions)
          {'name': c.name, 'emoji': c.emoji, 'color': _colorToHex(c.color)},
      ],
    'stickerType': stickerType.name,
    if (stickerText != null) 'stickerText': stickerText,
    if (stickerColor != null) 'stickerColor': _colorToHex(stickerColor!),
  };
}
