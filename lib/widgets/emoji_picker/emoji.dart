import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';

/// 单个表情项。
///
/// 迁移说明：原 vendor 包基于 freezed + json_serializable 生成，
/// 与宿主工程 freezed_annotation 版本冲突，改为手写实现，
/// 字段与 fromJson 行为保持不变。
class Emoji {
  final Widget widget;
  final String value;
  final IList<String> aliases;
  final String description;
  final IList<String> tags;

  Emoji({
    required this.widget,
    required this.value,
    required this.aliases,
    required this.description,
    required this.tags,
  });

  factory Emoji.fromJson(Map<String, Object?> json) => Emoji(
    widget: Text(json['emoji'] as String),
    value: json['emoji'] as String,
    aliases: IList<String>.fromJson(json['aliases'], (value) => value as String),
    description: json['description'] as String,
    tags: IList<String>.fromJson(json['tags'], (value) => value as String),
  );
}
