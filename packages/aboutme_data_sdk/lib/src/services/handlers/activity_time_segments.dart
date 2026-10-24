import 'record_domain_support.dart';

/// 以开始时间的时区为日界线；无时区的时间保持原有本地时钟语义。
List<Map<String, dynamic>> splitActivityByDay(Map<String, dynamic> activity) {
  final startText = activity['startTime'] as String?;
  final endText = activity['endTime'] as String?;
  final start = DateTime.tryParse(startText ?? '');
  final end = DateTime.tryParse(endText ?? '');
  if (start == null || end == null || !end.isAfter(start)) {
    throw const DomainFailure('CORRUPT_DATA', '活动起止时间无效');
  }
  final suffix =
      RegExp(r'(Z|[+-]\d{2}:?\d{2})$').firstMatch(startText!)?.group(0) ?? '';
  var offsetMinutes = 0;
  if (suffix.isNotEmpty && suffix != 'Z') {
    final digits = suffix.substring(1).replaceAll(':', '');
    offsetMinutes =
        (int.parse(digits.substring(0, 2)) * 60 +
            int.parse(digits.substring(2))) *
        (suffix.startsWith('-') ? -1 : 1);
  }
  DateTime clock(DateTime value) {
    if (suffix.isNotEmpty) {
      return value.toUtc().add(Duration(minutes: offsetMinutes));
    }
    final local = value.toLocal();
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  String encode(DateTime value) =>
      value.toIso8601String().replaceFirst(RegExp(r'Z$'), suffix);

  var cursor = clock(start);
  final finish = clock(end);
  final segments = <Map<String, dynamic>>[];
  while (cursor.isBefore(finish)) {
    final midnight = DateTime.utc(cursor.year, cursor.month, cursor.day + 1);
    final segmentEnd = finish.isBefore(midnight) ? finish : midnight;
    final date = encode(cursor).split('T')[0];
    segments.add({
      ...activity,
      if (segments.isNotEmpty) 'id': '${activity['id']}__$date',
      if (activity.containsKey('date')) 'date': date,
      'startTime': segments.isEmpty ? startText : encode(cursor),
      'endTime': segmentEnd == finish ? endText : encode(segmentEnd),
    });
    cursor = segmentEnd;
  }
  return segments;
}
