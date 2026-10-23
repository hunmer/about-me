import 'package:flutter/material.dart';
import 'package:aboutme/design_system/design_system.dart';

class Note {
  int? sdkVersion;
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

  /// 卡片背景填充风格（DsSketchFill 下标），0 = 默认排线
  int bgStyle;

  /// 右上角水印图标（DsIconKind 枚举名），null = 无
  String? icon;

  /// 已归档（普通视图隐藏，归入"已归档"分组）
  bool isArchived;

  Note({
    this.sdkVersion,
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
    this.bgStyle = 0,
    this.icon,
    this.isArchived = false,
  });

  bool get isTodo => type == typeTodo;

  /// 水印图标枚举（未知名称返回 null）
  DsIconKind? get iconKind {
    final name = icon;
    if (name == null) return null;
    for (final kind in DsIconKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

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
      'bgStyle': bgStyle,
      'icon': icon,
      'isArchived': isArchived,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      sdkVersion: json['_sdkVersion'] as int?,
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
      bgStyle: json['bgStyle'] as int? ?? 0,
      icon: json['icon'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
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
    int? bgStyle,
    String? icon,
    bool? isArchived,
  }) {
    return Note(
      sdkVersion: sdkVersion,
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
      bgStyle: bgStyle ?? this.bgStyle,
      icon: icon ?? this.icon,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
