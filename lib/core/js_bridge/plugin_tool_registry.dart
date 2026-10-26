import 'dart:convert';

import 'package:aboutme/core/data_filter/field_filter_service.dart';

/// JS API 与 Agent Tool 共用的 Dart 回调，无需初始化 JavaScript 引擎。
class PluginToolRegistry {
  final Map<String, Map<String, Function>> _handlers = {};

  void register(String pluginId, Map<String, Function> handlers) {
    final pluginHandlers = _handlers[pluginId] ??= {};
    pluginHandlers.addAll(handlers);
    // 查询是所有数据型插件的统一入口。插件没有显式实现时，
    // 复用已有 get* API 的结果执行通用过滤，避免重复维护 find* 方法。
    Future<dynamic> queryHandler(Map<String, dynamic> params) {
      return _query(pluginId, params);
    }

    pluginHandlers.putIfAbsent('query', () => queryHandler);
    handlers.putIfAbsent('query', () => queryHandler);
  }

  void clear() => _handlers.clear();

  Future<dynamic> invoke(
    String pluginId,
    String method,
    Map<String, dynamic> args,
  ) async {
    var handler = _handlers[pluginId]?[method];
    if (handler == null) {
      final matches = _handlers.values
          .where((methods) => methods.containsKey(method))
          .toList();
      if (matches.length != 1) {
        throw StateError(
          '插件接口不存在或路由不唯一：$pluginId.$method；'
          '该插件已注册方法：${_handlers[pluginId]?.keys.join(',') ?? '未注册'}；'
          '同名候选数：${matches.length}',
        );
      }
      handler = matches.single[method]!;
    }
    final original = Map<String, dynamic>.from(args);
    final result = await Function.apply(handler, [
      FieldFilterService.cleanParams(Map<String, dynamic>.from(args)),
    ]);
    return FieldFilterService.filterFromParams(result, original);
  }

  Future<dynamic> _query(String pluginId, Map<String, dynamic> params) async {
    final handlers = _handlers[pluginId];
    if (handlers == null) throw StateError('插件未注册：$pluginId');
    final method = _queryMethod(pluginId, params);
    final handler = handlers[method];
    if (handler == null) {
      throw StateError('插件 $pluginId 不支持统一查询');
    }

    final queryParams = Map<String, dynamic>.from(params)
      ..remove('entity')
      ..remove('field')
      ..remove('value')
      ..remove('fuzzy')
      ..remove('filters')
      ..remove('findAll')
      ..remove('offset')
      ..remove('count');
    final raw = await Function.apply(handler, [
      FieldFilterService.cleanParams(queryParams),
    ]);
    var records = _asRecords(raw);
    final field = params['field']?.toString();
    final value = params['value'];
    final fuzzy = params['fuzzy'] == true;
    if (field != null && field.isNotEmpty && value != null) {
      records = records.where((record) {
        final actual = record[field];
        if (fuzzy) {
          return actual?.toString().toLowerCase().contains(
                value.toString().toLowerCase(),
              ) ??
              false;
        }
        return actual?.toString() == value.toString();
      }).toList();
    }
    for (final entry in params.entries) {
      if ({
        'entity',
        'field',
        'value',
        'fuzzy',
        'filters',
        'findAll',
        'offset',
        'count',
        'mode',
        'fields',
        'excludeFields',
        'textLengthLimits',
        'generateSummary',
        'abbreviateFieldNames',
      }.contains(entry.key)) {
        continue;
      }
      if (entry.value == null) {
        continue;
      }
      records = records
          .where((record) => _matches(record[entry.key], entry.value))
          .toList();
    }
    if (params['filters'] is Map) {
      final filters = Map<String, dynamic>.from(params['filters'] as Map);
      records = records.where((record) {
        return filters.entries.every(
          (entry) => _matches(record[entry.key], entry.value),
        );
      }).toList();
    }

    final findAll = params['findAll'] != false;
    if (!findAll) return records.isEmpty ? null : records.first;
    final offset = (params['offset'] as num?)?.toInt() ?? 0;
    final count = (params['count'] as num?)?.toInt();
    if (count == null && offset == 0) return records;
    final start = offset.clamp(0, records.length);
    final end = (start + (count ?? records.length)).clamp(
      start,
      records.length,
    );
    return {
      'data': records.sublist(start, end),
      'total': records.length,
      'offset': start,
      'count': end - start,
      'hasMore': end < records.length,
    };
  }

  bool _matches(dynamic actual, dynamic expected) {
    if (expected is List) {
      return expected.any((value) => _matches(actual, value));
    }
    if (actual is List) {
      return actual.any((value) => _matches(value, expected));
    }
    return actual?.toString() == expected?.toString();
  }

  String _queryMethod(String pluginId, Map<String, dynamic> params) {
    final entity = params['entity']?.toString().toLowerCase();
    const defaults = <String, String>{
      'activity': 'getActivities',
      'bill': 'getBills',
      'calendar': 'getEvents',
      'calendar_album': 'getEntries',
      'chat': 'getChannels',
      'checkin': 'getCheckinItems',
      'contact': 'getContacts',
      'database': 'getDatabases',
      'day': 'getDays',
      'diary': 'getDiaries',
      'goods': 'getGoods',
      'nodes': 'getNotebooks',
      'notes': 'getNotes',
      'store': 'getProducts',
      'timer': 'getTimers',
      'todo': 'getTasks',
      'tracker': 'getGoals',
    };
    const byEntity = <String, Map<String, String>>{
      'activity': {'activity': 'getActivities', 'activities': 'getActivities'},
      'bill': {
        'account': 'getAccounts',
        'accounts': 'getAccounts',
        'bill': 'getBills',
        'bills': 'getBills',
        'subscription': 'getSubscriptions',
        'subscriptions': 'getSubscriptions',
      },
      'calendar': {'event': 'getEvents', 'events': 'getEvents'},
      'calendar_album': {
        'entry': 'getEntries',
        'entries': 'getEntries',
        'photo': 'getPhotos',
        'photos': 'getPhotos',
      },
      'chat': {
        'channel': 'getChannels',
        'channels': 'getChannels',
        'message': 'getMessages',
        'messages': 'getMessages',
      },
      'contact': {
        'contact': 'getContacts',
        'contacts': 'getContacts',
        'interaction': 'getInteractions',
        'interactions': 'getInteractions',
      },
      'checkin': {
        'item': 'getCheckinItems',
        'items': 'getCheckinItems',
        'history': 'getCheckinHistory',
      },
      'database': {
        'database': 'getDatabases',
        'databases': 'getDatabases',
        'record': 'getRecords',
        'records': 'getRecords',
      },
      'day': {'day': 'getDays', 'memorialday': 'getDays'},
      'diary': {'diary': 'getDiaries', 'diaries': 'getDiaries'},
      'goods': {
        'warehouse': 'getWarehouses',
        'warehouses': 'getWarehouses',
        'item': 'getGoods',
        'items': 'getGoods',
      },
      'nodes': {
        'notebook': 'getNotebooks',
        'notebooks': 'getNotebooks',
        'node': 'getNodes',
        'nodes': 'getNodes',
      },
      'notes': {
        'note': 'getNotes',
        'notes': 'getNotes',
        'folder': 'getFolders',
        'folders': 'getFolders',
      },
      'store': {
        'product': 'getProducts',
        'products': 'getProducts',
        'useritem': 'getUserItems',
        'useritems': 'getUserItems',
      },
      'timer': {'timer': 'getTimers', 'timers': 'getTimers'},
      'todo': {'task': 'getTasks', 'tasks': 'getTasks'},
      'tracker': {
        'goal': 'query',
        'goals': 'query',
        'record': 'getRecords',
        'records': 'getRecords',
      },
    };
    final explicit = byEntity[pluginId]?[entity];
    if (explicit != null) return explicit;
    if (entity != null && entity.isNotEmpty) {
      final normalized = entity[0].toUpperCase() + entity.substring(1);
      final candidates = <String>['get$normalized'];
      if (!entity.endsWith('s')) candidates.add('get${normalized}s');
      for (final candidate in candidates) {
        if (_handlers[pluginId]?.containsKey(candidate) == true) {
          return candidate;
        }
      }
    }
    return defaults[pluginId] ??
        (_handlers[pluginId]?.keys.firstWhere(
              (name) => name.startsWith('get'),
              orElse: () => 'query',
            ) ??
            'query');
  }

  List<Map<String, dynamic>> _asRecords(dynamic raw) {
    dynamic value = raw;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return [];
      }
    }
    if (value is Map) {
      if (value['data'] is List) {
        value = value['data'];
      } else if (value['items'] is List) {
        value = value['items'];
      } else if (value['records'] is List) {
        value = value['records'];
      } else if (value['diaries'] is List) {
        value = value['diaries'];
      } else if (value['recs'] is List) {
        value = value['recs'];
      } else {
        value = <dynamic>[];
      }
    }
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
