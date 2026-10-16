import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'emoji.dart';
import 'emoji_category.dart';

/// 内置 Unicode 表情数据（assets/emoji/emoji.json，按 category 字段分组）
class EmojiController extends AsyncNotifier<IList<EmojiCategory>> {
  @override
  Future<IList<EmojiCategory>> build() async {
    final emojiJson = await rootBundle.loadString('assets/emoji/emoji.json');
    final decoded = (jsonDecode(emojiJson) as List<dynamic>)
        .cast<Map<String, Object?>>();

    final entries = decoded.map(
      (json) => (
        category: json['category']! as String,
        emoji: Emoji.fromJson(json),
      ),
    );

    final grouped = groupBy(entries, (e) => e.category);

    return IList(
      grouped.entries.map(
        (entry) => EmojiCategory(
          icon: entry.value.first.emoji.widget,
          name: entry.key,
          emojis: IList(entry.value.map((e) => e.emoji)),
        ),
      ),
    );
  }

  static final provider =
      AsyncNotifierProvider<EmojiController, IList<EmojiCategory>>(
        EmojiController.new,
      );
}
