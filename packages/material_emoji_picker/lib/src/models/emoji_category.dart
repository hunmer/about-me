import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:material_emoji_picker/src/models/emoji.dart";
import "package:flutter/widgets.dart";

/// 表情分类。
///
/// vendor 改造说明：原版基于 freezed 生成，因宿主工程依赖
/// freezed_annotation 2.x 与本包 3.x 冲突，改为手写实现，字段保持不变。
class EmojiCategory {
  final Widget icon;
  final String name;
  final IList<Emoji> emojis;

  EmojiCategory({required this.icon, required this.name, required this.emojis});
}
