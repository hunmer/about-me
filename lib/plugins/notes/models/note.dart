import 'package:flutter/material.dart';

class Note {
  static const String typeText = 'text';
  static const String typeTodo = 'todo';

  final String id;
  String title;
  String content;
  final String? folderId;
  final DateTime createdAt;
  DateTime updatedAt;
  List<String> tags;

  /// 笔记类型：[typeText] 普通笔记（默认）、[typeTodo] 待办清单
  String type;

  /// 扩展元数据（JSON 字符串），待办清单用它记录条目完成时间等
  String? meta;

  /// 可选标记色（ARGB），null = 未指定（跟随主题）
  Color? color;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.folderId,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.type = typeText,
    this.meta,
    this.color,
  });

  bool get isTodo => type == typeTodo;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'folderId': folderId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
      'type': type,
      'meta': meta,
      'color': color?.value,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      folderId: json['folderId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      type: (json['type'] as String?) ?? typeText,
      meta: json['meta'] as String?,
      color: json['color'] == null ? null : Color(json['color'] as int),
    );
  }

  // 创建一个新的Note对象，同时允许更新特定字段
  Note copyWith({
    String? title,
    String? content,
    String? folderId,
    DateTime? updatedAt,
    List<String>? tags,
    String? type,
    String? meta,
    Color? color,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      folderId: folderId ?? this.folderId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      type: type ?? this.type,
      meta: meta ?? this.meta,
      color: color ?? this.color,
    );
  }
}
