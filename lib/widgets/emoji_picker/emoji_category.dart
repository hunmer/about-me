import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';

import 'emoji.dart';

/// 表情分类。
///
/// 迁移说明：原 vendor 包基于 freezed 生成，与宿主工程
/// freezed_annotation 版本冲突，改为手写实现，字段保持不变。
class EmojiCategory {
  final Widget icon;
  final String name;
  final IList<Emoji> emojis;

  EmojiCategory({required this.icon, required this.name, required this.emojis});
}
