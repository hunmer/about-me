import 'package:shared_models/shared_models.dart';
/// JSON/JS 日期参数转换为日历业务层使用的本地 DateTime。
Map<String, dynamic> normalizeCalendarApiParams(Map<String, dynamic> params) {
  final converted = Map<String, dynamic>.from(params);
  for (final key in ['startTime', 'endTime', 'completedTime', 'startDate', 'endDate']) {
    final value = converted[key];
    if (value == null) continue;
    if (value is DateTime) {
      converted[key] = value.toLocal();
    } else if (value is String && tryParseIsoDateTime(value) != null) {
      converted[key] = parseIsoDateTime(value).toLocal();
    } else {
      throw FormatException('$key 必须是有效的 ISO 8601 日期时间');
    }
  }
  return converted;
}
