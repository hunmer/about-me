import 'package:flutter/material.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

class Folder {
  int? sdkVersion;
  final String id;
  String name;
  final String? parentId; // null for root folder
  final DateTime createdAt;
  DateTime updatedAt;
  Color color;
  IconData icon;

  /// 已归档（普通视图隐藏，归入"已归档"分组）
  bool isArchived;

  Folder({
    this.sdkVersion,
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    required this.updatedAt,
    this.color = Colors.blue,
    this.icon = Icons.folder,
    this.isArchived = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'color': color.value,
      'icon': icon.codePoint,
      'isArchived': isArchived,
    };
  }

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      sdkVersion: json['_sdkVersion'] as int?,
      id: json['id'] as String,
      name: json['name'] as String,
      // SDK/MCP 允许省略父级，普通文件夹应归入页面使用的 root 目录。
      parentId: json['parentId'] as String? ??
          (json['id'] == 'root' ? null : 'root'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      color: Color(json['color'] as int? ?? Colors.blue.value),
      icon: dynamicIconData(
        json['icon'] as int? ?? Icons.folder.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }
}
