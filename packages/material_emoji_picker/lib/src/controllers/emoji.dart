import "dart:convert";

import "package:collection/collection.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_emoji_picker/src/models/emoji.dart";
import "package:material_emoji_picker/src/models/emoji_category.dart";

class EmojiController extends AsyncNotifier<IList<EmojiCategory>> {
  @override
  Future<IList<EmojiCategory>> build() async {
    final emojiJson = await rootBundle.loadString(
      "packages/material_emoji_picker/assets/emoji.json",
    );
    final decoded = (jsonDecode(emojiJson) as List<dynamic>)
        .cast<Map<String, Object?>>();

    final entries = decoded.map(
      (json) =>
          (category: json["category"]! as String, emoji: Emoji.fromJson(json)),
    );

    final grouped = groupBy(entries, (e) => e.category);

    return .new(
      grouped.entries.map(
        (entry) => .new(
          icon: entry.value.first.emoji.widget,
          name: entry.key,
          emojis: .new(entry.value.map((e) => e.emoji)),
        ),
      ),
    );
  }

  static final provider =
      AsyncNotifierProvider<EmojiController, IList<EmojiCategory>>(
        EmojiController.new,
      );
}
