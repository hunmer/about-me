import '../../../../screens/widgets_gallery/common_widgets/widgets/scrapbook_canvas_card/scrapbook_canvas_card.dart';

import 'package:shared_models/shared_models.dart';
/// 一页手账：画布条目 + 涂鸦笔画 + 元数据
///
/// 画布元素复用 widgets_gallery 的 ScrapItemData/ScrapStroke 模型，
/// 序列化走各自的 toMap/fromMap
class ScrapbookPage {
  final String id;
  String title;
  String? subtitle;
  List<ScrapItemData> items;
  List<ScrapStroke> strokes;
  final DateTime createdAt;
  DateTime updatedAt;

  ScrapbookPage({
    required this.id,
    required this.title,
    this.subtitle,
    List<ScrapItemData>? items,
    List<ScrapStroke>? strokes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : items = items ?? [],
       strokes = strokes ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory ScrapbookPage.fromMap(Map<String, dynamic> map) {
    return ScrapbookPage(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String?,
      items:
          (map['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ScrapItemData.fromMap)
              .toList() ??
          [],
      strokes:
          (map['strokes'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ScrapStroke.fromMap)
              .toList() ??
          [],
      createdAt: tryParseIsoDateTime(map['createdAt'] as String? ?? ''),
      updatedAt: tryParseIsoDateTime(map['updatedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    'items': [for (final item in items) item.toMap()],
    'strokes': [for (final stroke in strokes) stroke.toMap()],
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// 首个文字条目内容（列表卡片摘要），无则空串
  String get summary {
    for (final item in items) {
      if (item.kind == ScrapItemKind.text && item.captions.isNotEmpty) {
        return item.captions.first;
      }
    }
    return '';
  }
}
