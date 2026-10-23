import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String generateUUID() => _uuid.v4();

/// 错误码到 HTTP 状态码映射。
int errorCodeToStatus(String? code) {
  switch (code) {
    case 'NOT_FOUND':
      return 404;
    case 'INVALID_PARAMS':
      return 400;
    case 'UNSUPPORTED':
      return 501;
    case 'CORRUPT_DATA':
      return 422;
    case 'OFFLINE':
      return 503;
    case 'UNAUTHORIZED':
      return 401;
    case 'FORBIDDEN':
      return 403;
    case 'CONFLICT':
      return 409;
    default:
      return 500;
  }
}

/// 格式化日期为 YYYY-MM-DD（本地时区）。
String formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// JS `Date.toISOString()` 格式（UTC，毫秒 3 位，Z 结尾）。
String jsIsoDateTime(DateTime time) {
  final utc = time.toUtc();
  final y = utc.year.toString().padLeft(4, '0');
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  final h = utc.hour.toString().padLeft(2, '0');
  final min = utc.minute.toString().padLeft(2, '0');
  final s = utc.second.toString().padLeft(2, '0');
  final ms = utc.millisecond.toString().padLeft(3, '0');
  return '$y-$m-${d}T$h:$min:$s.${ms}Z';
}

/// 分页。
Map<String, dynamic> createPaginatedResult(
  List<dynamic> items, {
  int? offset,
  int? count,
}) {
  final start = offset ?? 0;
  final size = count ?? 100;
  final total = items.length;
  final end = (start + size).clamp(0, total);
  final data = start >= total ? <dynamic>[] : items.sublist(start, end);
  return {
    'data': data,
    'total': total,
    'offset': start,
    'count': data.length,
    'hasMore': start + data.length < total,
  };
}

/// 匹配路由模式（如 /channels/:id），成功返回路径参数。
Map<String, String>? matchRoute(String pattern, String subPath) {
  final patternParts = pattern.split('/');
  final pathParts = subPath.split('/');
  if (patternParts.length != pathParts.length) return null;

  final params = <String, String>{};
  for (var i = 0; i < patternParts.length; i++) {
    if (patternParts[i].startsWith(':')) {
      params[patternParts[i].substring(1)] = Uri.decodeComponent(pathParts[i]);
    } else if (patternParts[i] != pathParts[i]) {
      return null;
    }
  }
  return params;
}

/// JS 宽松真值语义模拟（业务 handler 兼容旧数据用）。
bool truthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String)
    return value.isNotEmpty && value != 'false' && value != '0';
  return true;
}

/// JS Number() 宽松数值转换模拟。
num toNum(dynamic value, [num fallback = 0]) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? fallback;
  return fallback;
}
