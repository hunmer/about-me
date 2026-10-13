/// 媒体记录（阅读/观影）数据模型
library;

/// 记录类型：阅读 / 观影
enum MediaKind { reading, watching }

/// 程序化封面绘制风格（替代真实封面图，墨线风格与全局一致）
enum CoverStyle {
  sheep,
  ring,
  bellJar,
  collage,
  siddhartha,
  beauty,
  norwegianWood,
  kafka,
  tsukuru,
  journals,
  poems,
  pinball,
}

/// 点评条目（可多条，带时间戳）
class MediaReview {
  MediaReview({
    required this.id,
    required this.text,
    required this.timestamp,
    this.rating,
  });

  final String id;
  final String text;
  final DateTime timestamp;

  /// 可选评分（0~5，null = 未评分）
  final double? rating;

  MediaReview copyWith({String? id, String? text, DateTime? timestamp, double? rating}) {
    return MediaReview(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      rating: rating ?? this.rating,
    );
  }

  factory MediaReview.fromJson(Map<String, dynamic> json) {
    return MediaReview(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        if (rating != null) 'rating': rating,
      };
}

/// 媒体条目（一本书 / 一部影片）
class MediaItem {
  MediaItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.cover,
    required this.createdAt,
    this.author,
    this.aspect = 1.42,
    this.rating,
    this.overview,
    this.tags = const [],
    this.finishedAt,
    this.reviews = const [],
  });

  final String id;
  final MediaKind kind;
  final String title;
  final String? author;
  final CoverStyle cover;

  /// 封面高 / 宽 比（瀑布流错落）
  final double aspect;

  /// 总评分（0~5，null = 未评分）
  final double? rating;
  final String? overview;
  final List<String> tags;

  /// 完成（读完/看完）时间；null = 进行中
  final DateTime? finishedAt;
  final DateTime createdAt;
  final List<MediaReview> reviews;

  bool get isFinished => finishedAt != null;

  MediaItem copyWith({
    String? id,
    MediaKind? kind,
    String? title,
    String? author,
    CoverStyle? cover,
    double? aspect,
    double? rating,
    String? overview,
    List<String>? tags,
    DateTime? finishedAt,
    List<MediaReview>? reviews,
  }) {
    return MediaItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      author: author ?? this.author,
      cover: cover ?? this.cover,
      aspect: aspect ?? this.aspect,
      rating: rating ?? this.rating,
      overview: overview ?? this.overview,
      tags: tags ?? this.tags,
      finishedAt: finishedAt ?? this.finishedAt,
      reviews: reviews ?? this.reviews,
      createdAt: createdAt,
    );
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      kind: json['kind'] == 'watching' ? MediaKind.watching : MediaKind.reading,
      title: json['title'] as String? ?? '',
      author: json['author'] as String?,
      cover: CoverStyle.values.firstWhere(
        (s) => s.name == json['cover'],
        orElse: () => CoverStyle.sheep,
      ),
      aspect: (json['aspect'] as num?)?.toDouble() ?? 1.42,
      rating: (json['rating'] as num?)?.toDouble(),
      overview: json['overview'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      finishedAt: DateTime.tryParse(json['finishedAt'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
      reviews: (json['reviews'] as List?)
              ?.map((r) => MediaReview.fromJson(Map<String, dynamic>.from(r)))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        if (author != null) 'author': author,
        'cover': cover.name,
        'aspect': aspect,
        if (rating != null) 'rating': rating,
        if (overview != null) 'overview': overview,
        'tags': tags,
        if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'reviews': [for (final r in reviews) r.toJson()],
      };
}
