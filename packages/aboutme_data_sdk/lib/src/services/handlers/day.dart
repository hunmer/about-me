import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

// Day 插件专用处理器（移植自 nodejs handlers/day.ts）。
//
// 数据格式：memorial_days.json 直接存储纪念日数组

PluginHandlers createDayHandlers(PluginData data) {
  // 读取所有纪念日
  Future<List<Map<String, dynamic>>> readAllMemorialDays() async {
    final content = await data.read('day', 'memorial_days.json');
    // memorial_days.json 直接是数组格式
    if (content is! List) return [];
    return List<Map<String, dynamic>>.from(content);
  }

  // 保存所有纪念日
  Future<void> saveAllMemorialDays(List<Map<String, dynamic>> days) {
    return data.write('day', 'memorial_days.json', days);
  }

  return {
    // 获取纪念日列表
    'getList': (data, params) async {
      try {
        final days = await readAllMemorialDays();

        // 排序
        final sortMode = params['sortMode'] as String?;
        if (sortMode != null && sortMode.isNotEmpty) {
          switch (sortMode) {
            case 'upcoming':
              days.sort(
                (a, b) => _toNum(
                  a['daysRemaining'],
                ).compareTo(_toNum(b['daysRemaining'])),
              );
              break;
            case 'recent':
              days.sort((a, b) {
                final aDate = (a['targetDate'] ?? '').toString();
                final bDate = (b['targetDate'] ?? '').toString();
                return bDate.compareTo(aDate);
              });
              break;
            case 'manual':
              days.sort(
                (a, b) =>
                    _toNum(a['sortIndex']).compareTo(_toNum(b['sortIndex'])),
              );
              break;
          }
        }

        // 分页
        final offset = params['offset'] as int? ?? 0;
        final count = params['count'] as int? ?? 100;
        final total = days.length;
        final end = (offset + count).clamp(0, total);
        final paginatedDays = offset >= total
            ? <Map<String, dynamic>>[]
            : days.sublist(offset, end);

        return PluginResult.success({
          'data': paginatedDays,
          'total': total,
          'offset': offset,
          'count': paginatedDays.length,
          'hasMore': offset + paginatedDays.length < total,
        });
      } catch (e) {
        return PluginResult.failure('获取纪念日列表失败: $e');
      }
    },

    // 根据 ID 获取
    'getById': (data, params) async {
      try {
        final days = await readAllMemorialDays();
        final index = days.indexWhere((d) => d['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('纪念日不存在', 'NOT_FOUND');
        }

        return PluginResult.success(days[index]);
      } catch (e) {
        return PluginResult.failure('获取纪念日失败: $e');
      }
    },

    // 创建纪念日
    'create': (data, params) async {
      try {
        final days = await readAllMemorialDays();
        final now = jsIsoDateTime(DateTime.now());

        final id = params['id'];
        final newDay = <String, dynamic>{
          ...params,
          'id': id != null && id.toString().isNotEmpty ? id : generateUUID(),
          'createdAt': now,
          'updatedAt': now,
        };

        days.add(newDay);
        await saveAllMemorialDays(days);

        return PluginResult.success(newDay);
      } catch (e) {
        return PluginResult.failure('创建纪念日失败: $e');
      }
    },

    // 更新纪念日
    'update': (data, params) async {
      try {
        final days = await readAllMemorialDays();
        final index = days.indexWhere((d) => d['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('纪念日不存在', 'NOT_FOUND');
        }

        final updatedDay = <String, dynamic>{
          ...days[index],
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        days[index] = updatedDay;

        await saveAllMemorialDays(days);
        return PluginResult.success(updatedDay);
      } catch (e) {
        return PluginResult.failure('更新纪念日失败: $e');
      }
    },

    // 删除纪念日
    'delete': (data, params) async {
      try {
        final days = await readAllMemorialDays();
        final initialLength = days.length;
        final filtered = days
            .where((d) => d['id'] != params['id'])
            .toList();

        if (filtered.length == initialLength) {
          return const PluginResult.failure('纪念日不存在', 'NOT_FOUND');
        }

        await saveAllMemorialDays(filtered);
        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除纪念日失败: $e');
      }
    },

    // 搜索纪念日
    'search': (data, params) async {
      try {
        var days = await readAllMemorialDays();

        final startDate = params['startDate'];
        final endDate = params['endDate'];
        final includeExpired = params['includeExpired'];
        // 注：原版解构了 sortMode 但未使用

        final today = jsIsoDateTime(DateTime.now()).split('T')[0];

        if (!_truthy(includeExpired)) {
          days = days
              .where((d) => _targetDateOf(d).compareTo(today) >= 0)
              .toList();
        }
        if (startDate != null && startDate.toString().isNotEmpty) {
          days = days
              .where(
                (d) => _targetDateOf(d).compareTo(startDate.toString()) >= 0,
              )
              .toList();
        }
        if (endDate != null && endDate.toString().isNotEmpty) {
          days = days
              .where(
                (d) => _targetDateOf(d).compareTo(endDate.toString()) <= 0,
              )
              .toList();
        }

        return PluginResult.success({'data': days, 'total': days.length});
      } catch (e) {
        return PluginResult.failure('搜索失败: $e');
      }
    },

    // 获取统计
    'getStats': (data, params) async {
      try {
        final days = await readAllMemorialDays();

        return PluginResult.success({
          'totalDays': days.length,
        });
      } catch (e) {
        return PluginResult.failure('获取统计失败: $e');
      }
    },
  };
}

/// (d.targetDate || d.date) 的取值，缺失时为空字符串（比较结果与 JS 一致）。
String _targetDateOf(Map<String, dynamic> day) {
  final targetDate = day['targetDate'];
  if (targetDate != null && targetDate.toString().isNotEmpty) {
    return targetDate.toString();
  }
  final date = day['date'];
  return date?.toString() ?? '';
}

/// JS 真值判断（null/false/0/空串为假，其余为真）。
bool _truthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.isNotEmpty;
  return true;
}

/// 模拟 JS 算术场景下的宽松数字转换（(x as number) || 0 的语义）。
num _toNum(dynamic value) =>
    value is num ? value : (num.tryParse(value?.toString() ?? '') ?? 0);
