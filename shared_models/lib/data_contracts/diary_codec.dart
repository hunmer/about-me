import 'dart:convert';

/// 日历日期与富文本格式统一，兼容旧 ISO 日期并保留扩展字段。
class DiaryCodec {
  static String date(String value) {
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}(?:$|T)').firstMatch(value);
    if (match == null) throw const FormatException('日期必须为 YYYY-MM-DD');
    final day = value.substring(0, 10);
    if (value.length > 10 && DateTime.tryParse(value) == null) {
      throw const FormatException('无效 ISO 日期');
    }
    final parsed = DateTime.tryParse(day);
    if (parsed == null || formatDate(parsed) != day) {
      throw const FormatException('无效日历日期');
    }
    return day;
  }

  static String formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String plainText(String content) {
    try {
      final decoded = jsonDecode(content);
      final ops = decoded is Map ? decoded['ops'] : decoded;
      if (ops is List &&
          ops.every((op) => op is Map && op.containsKey('insert'))) {
        return ops
            .map((op) => op['insert'] is String ? op['insert'] as String : '')
            .join();
      }
    } on FormatException {/* 旧纯文本保留原样。 */}
    return content;
  }

  static Map<String, dynamic> entry(Map<String, dynamic> json) {
    if ((json['schemaVersion'] != null && json['schemaVersion'] != 1) ||
        (json['contentFormat'] != null && !['text', 'delta'].contains(json['contentFormat']))) {
      throw const FormatException('不支持的日记版本或内容格式');
    }
    if (json['date'] is! String ||
        json['content'] is! String ||
        (json['title'] != null && json['title'] is! String) ||
        (json['mood'] != null && json['mood'] is! String) ||
        (json['tags'] != null &&
            (json['tags'] is! List ||
                (json['tags'] as List).any((tag) => tag is! String)))) {
      throw const FormatException('日记字段类型错误');
    }
    final day = date(json['date'] as String);
    final created = json['createdAt'] ?? '${day}T00:00:00Z';
    final updated = json['updatedAt'] ?? created;
    if (created is! String ||
        updated is! String ||
        DateTime.tryParse(created) == null ||
        DateTime.tryParse(updated) == null) {
      throw const FormatException('日记时间戳错误');
    }
    return {
      ...json,
      'schemaVersion': 1,
      'date': day,
      'title': json['title'] ?? '',
      'tags': json['tags'] ?? <String>[],
      'createdAt': created,
      'updatedAt': updated,
      'contentFormat': json['contentFormat'] ??
          (plainText(json['content'] as String) == json['content']
              ? 'text'
              : 'delta'),
    };
  }
}
