/// 待办条目：一段文本 + 勾选状态。
///
/// 序列化为纯文本清单存入 Note.content（每行一项），
/// 形如 `☐ 买牛奶` / `☑ 买面包`，保证搜索与各处只读渲染无需感知待办类型。
/// 条目完成时间记录在 Note.meta（[TodoMeta]），保持 content 协议纯净。
library;

import 'dart:convert';

class TodoItem {
  String text;
  bool checked;

  TodoItem({required this.text, this.checked = false});

  static const String _checkedMark = '☑';
  static const String _uncheckedMark = '☐';

  /// 将条目列表编码为存储用文本（过滤空白条目）
  static String encodeList(List<TodoItem> items) {
    return items
        .where((item) => item.text.trim().isNotEmpty)
        .map(
          (item) =>
              '${item.checked ? _checkedMark : _uncheckedMark} ${item.text}',
        )
        .join('\n');
  }

  /// 从存储文本解析条目列表，兼容无前缀的行（视为未勾选）
  static List<TodoItem> parseList(String content) {
    final items = <TodoItem>[];
    for (var line in content.split('\n')) {
      line = line.trimLeft();
      if (line.isEmpty) continue;
      if (line.startsWith(_checkedMark)) {
        final text = line.substring(_checkedMark.length).trim();
        // 跳过只有勾选标记的空行（历史脏数据）
        if (text.isEmpty) continue;
        items.add(TodoItem(text: text, checked: true));
      } else if (line.startsWith(_uncheckedMark)) {
        final text = line.substring(_uncheckedMark.length).trim();
        if (text.isEmpty) continue;
        items.add(TodoItem(text: text));
      } else {
        items.add(TodoItem(text: line));
      }
    }
    return items;
  }
}

/// 待办条目完成时间记录，以条目文本为键存入 Note.meta。
///
/// [toJson]/[parse] 负责 Note.meta（JSON 字符串）与完成时间表的互转。
class TodoMeta {
  /// 条目文本 -> 完成时间
  final Map<String, DateTime> doneAt;

  TodoMeta({Map<String, DateTime>? doneAt}) : doneAt = doneAt ?? {};

  static TodoMeta parse(String? meta) {
    if (meta == null || meta.isEmpty) return TodoMeta();
    try {
      final json = Map<String, dynamic>.from(
        (jsonDecode(meta) as Map?)?.cast<String, dynamic>() ?? {},
      );
      final doneAt = <String, DateTime>{};
      json['doneAt']?.forEach((key, value) {
        if (value is String) doneAt[key] = DateTime.parse(value);
      });
      return TodoMeta(doneAt: doneAt);
    } catch (_) {
      return TodoMeta();
    }
  }

  String toJson() {
    return jsonEncode({
      'doneAt': doneAt.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    });
  }

  DateTime? doneAtOf(String text) => doneAt[text];

  void markDone(String text, DateTime at) => doneAt[text] = at;

  /// 清理已不存在条目的记录
  void retainTexts(Set<String> texts) =>
      doneAt.removeWhere((text, _) => !texts.contains(text));
}
