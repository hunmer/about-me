import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'package:shared_models/shared_models.dart';
class CalendarEntry {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String? location;

  /// 位置经纬度，格式 "lat,lng"（GCJ-02，来自 LocationPicker），
  /// 与 [location] 地址文本配套，供地图功能使用
  final String? latLng;
  final String? mood;
  final String? weather;
  final List<String> imageUrls;
  final List<String> thumbUrls;

  /// 与 imageUrls 按索引对应的 Live Photo 配对视频路径，普通图片为空字符串。
  final List<String> liveVideoUrls;

  CalendarEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.location,
    this.latLng,
    this.mood,
    this.weather,
    this.imageUrls = const [],
    this.thumbUrls = const [],
    this.liveVideoUrls = const [],
  });

  factory CalendarEntry.create({
    required String title,
    required String content,
    required DateTime createdAt,
    List<String> tags = const [],
    String? location,
    String? latLng,
    String? mood,
    String? weather,
    List<String> imageUrls = const [],
    List<String> thumbUrls = const [],
    List<String> liveVideoUrls = const [],
  }) {
    return CalendarEntry(
      id: const Uuid().v4(),
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: createdAt,
      tags: tags,
      location: location,
      latLng: latLng,
      mood: mood,
      weather: weather,
      imageUrls: imageUrls,
      thumbUrls: thumbUrls,
      liveVideoUrls: liveVideoUrls,
    );
  }

  CalendarEntry copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    List<String>? tags,
    String? location,
    String? latLng,
    String? mood,
    String? weather,
    List<String>? imageUrls,
    List<String>? thumbUrls,
    List<String>? liveVideoUrls,
  }) {
    return CalendarEntry(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      tags: tags ?? this.tags,
      location: location ?? this.location,
      latLng: latLng ?? this.latLng,
      mood: mood ?? this.mood,
      weather: weather ?? this.weather,
      imageUrls: imageUrls ?? this.imageUrls,
      thumbUrls: thumbUrls ?? this.thumbUrls,
      liveVideoUrls: liveVideoUrls ?? this.liveVideoUrls,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
      'location': location,
      'latLng': latLng,
      'mood': mood,
      'weather': weather,
      'imageUrls': imageUrls,
      'thumbUrls': thumbUrls,
      'liveVideoUrls': liveVideoUrls,
    };
  }

  factory CalendarEntry.fromJson(Map<String, dynamic> json) {
    return CalendarEntry(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: parseIsoDateTime(json['createdAt']),
      updatedAt: parseIsoDateTime(json['updatedAt']),
      tags: List<String>.from(json['tags'] ?? []),
      location: json['location'],
      latLng: json['latLng'],
      mood: json['mood'],
      weather: json['weather'],
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      thumbUrls: List<String>.from(json['thumbUrls'] ?? []),
      liveVideoUrls: List<String>.from(json['liveVideoUrls'] ?? []),
    );
  }

  int get wordCount {
    return content
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  // 从Markdown内容中提取图片URL
  List<String> extractImagesFromMarkdown() {
    final RegExp imgRegExp = RegExp(r'!\[.*?\]\((.*?)\)');
    final matches = imgRegExp.allMatches(content);
    return matches.map((match) => match.group(1)!).toList();
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}
