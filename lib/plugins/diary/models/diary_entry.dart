import 'package:shared_models/shared_models.dart';

class DiaryEntry {
  final int? sdkVersion;
  final Map<String, dynamic> extensions;
  final DateTime date;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? mood; // 心情表情符号
  final List<String> tags; // 多标签

  DiaryEntry({
    required this.date,
    this.title = '',
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.mood,
    this.tags = const [],
    this.sdkVersion,
    this.extensions = const {},
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    json = DiaryCodec.entry(json);
    return DiaryEntry(
      sdkVersion: json['_sdkVersion'] as int?,
      extensions: Map<String, dynamic>.from(json)..remove('_sdkVersion'),
      date: parseIsoDateTime(json['date']),
      title: json['title'] ?? '',
      content: json['content'],
      createdAt: parseIsoDateTime(json['createdAt']),
      updatedAt: parseIsoDateTime(json['updatedAt']),
      mood: json['mood'],
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...extensions,
      'date': date.toIso8601String().split('T')[0],
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'mood': mood,
      'tags': tags,
    };
  }

  DiaryEntry copyWith({
    DateTime? date,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? mood,
    List<String>? tags,
  }) {
    return DiaryEntry(
      date: date ?? this.date,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      sdkVersion: sdkVersion,
      extensions: extensions,
    );
  }
}
