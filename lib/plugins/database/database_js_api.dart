part of 'database_plugin.dart';

// ==================== JS API 定义 ====================

Map<String, Function> _defineJSAPI() {
  return {
    // 数据库管理
    'getDatabases': _jsGetDatabases,
    'createDatabase': _jsCreateDatabase,
    'updateDatabase': _jsUpdateDatabase,
    'deleteDatabase': _jsDeleteDatabase,

    // 记录管理
    'getRecords': _jsGetRecords,
    'createRecord': _jsCreateRecord,
    'updateRecord': _jsUpdateRecord,
    'deleteRecord': _jsDeleteRecord,

    // 查询功能
    'query': _jsQuery,

    // 统计功能
    'getCount': _jsGetCount,

    // 数据库查找方法
    'findDatabaseBy': _jsFindDatabaseBy,
    'findDatabaseById': _jsFindDatabaseById,
    'findDatabaseByName': _jsFindDatabaseByName,

    // 记录查找方法
    'findRecordBy': _jsFindRecordBy,
    'findRecordById': _jsFindRecordById,
  };
}

// ==================== 参数归一化 ====================
// 对外（工具 schema / JS API）声明 databaseId/recordId/fieldsJson 等参数名，
// UseCase 层实际使用 tableId/id/fields，在此层统一转换。
// 注意 fields 参数在 PluginToolRegistry 中会被 cleanParams 当作输出过滤器删除，
// 因此结构化数据只能通过 fieldsJson(JSON字符串) 传入。

/// 解析 JSON 参数：Map/List 原样返回，字符串则 jsonDecode，无法解析返回 null
dynamic _parseJsonParam(dynamic value) {
  if (value is Map || value is List) return value;
  if (value is String && value.isNotEmpty) {
    try {
      return jsonDecode(value);
    } catch (_) {}
  }
  return null;
}

/// databaseId -> tableId
Map<String, dynamic> _toTableParams(Map<String, dynamic> params) {
  final normalized = Map<String, dynamic>.from(params);
  final databaseId = normalized.remove('databaseId');
  if (databaseId != null) {
    normalized.putIfAbsent('tableId', () => databaseId);
  }
  return normalized;
}

/// recordId/databaseId -> id（recordId 优先，UseCase 的记录和数据库更新/删除均按 id 操作）
Map<String, dynamic> _toIdParams(Map<String, dynamic> params) {
  final normalized = Map<String, dynamic>.from(params);
  dynamic idValue;
  for (final key in ['recordId', 'databaseId']) {
    final value = normalized.remove(key);
    if (value != null && idValue == null) idValue = value;
  }
  if (idValue != null) {
    normalized.putIfAbsent('id', () => idValue);
  }
  return normalized;
}

/// fieldsJson(JSON字符串) -> fields(Map/List)，解析失败返回错误信息
String? _applyFieldsJson(Map<String, dynamic> normalized) {
  if (!normalized.containsKey('fieldsJson')) return null;
  final parsed = _parseJsonParam(normalized.remove('fieldsJson'));
  if (parsed == null) return '参数 fieldsJson 不是合法的 JSON';
  normalized.putIfAbsent('fields', () => parsed);
  return null;
}

/// 校验数据库ID（databaseId 或 tableId 均可）
String? _checkTableId(Map<String, dynamic> params) {
  final value = params['databaseId'] ?? params['tableId'];
  if (value == null || (value is String && value.isEmpty)) {
    return '缺少必需参数: databaseId（数据库ID，可先调用 getDatabases 获取数据库列表）';
  }
  return null;
}

// ==================== JS API 实现 ====================

/// 获取所有数据库
/// 支持分页参数: offset, count
Future<String> _jsGetDatabases(Map<String, dynamic> params) async {
  final result = await DatabasePlugin.instance.useCase.getDatabases(params);

  if (result.isFailure) {
    return jsonEncode({'error': result.errorOrNull?.message});
  }

  return jsonEncode(result.dataOrNull);
}

/// 创建数据库
Future<String> _jsCreateDatabase(Map<String, dynamic> params) async {
  final normalized = Map<String, dynamic>.from(params);
  final error = _applyFieldsJson(normalized);
  if (error != null) return jsonEncode({'error': error});

  final result = await DatabasePlugin.instance.useCase.createDatabase(normalized);

  if (result.isFailure) {
    return jsonEncode({'error': result.errorOrNull?.message});
  }

  return jsonEncode(result.dataOrNull);
}

/// 更新数据库
Future<String> _jsUpdateDatabase(Map<String, dynamic> params) async {
  final result = await DatabasePlugin.instance.useCase.updateDatabase(
    _toIdParams(params),
  );

  if (result.isFailure) {
    return jsonEncode({'error': result.errorOrNull?.message});
  }

  return jsonEncode(result.dataOrNull);
}

/// 删除数据库
Future<String> _jsDeleteDatabase(Map<String, dynamic> params) async {
  final result = await DatabasePlugin.instance.useCase.deleteDatabase(
    _toIdParams(params),
  );

  if (result.isFailure) {
    return jsonEncode({'success': false, 'error': result.errorOrNull?.message});
  }

  return jsonEncode({'success': true});
}

/// 获取数据库的所有记录
/// 支持分页参数: offset, count, limit
Future<String> _jsGetRecords(Map<String, dynamic> params) async {
  final checkError = _checkTableId(params);
  if (checkError != null) return jsonEncode({'error': checkError});

  final normalized = _toTableParams(params);
  // limit 与 count 语义一致：限制返回条数
  final limit = normalized.remove('limit');
  if (limit != null && !normalized.containsKey('count')) {
    normalized['count'] = limit is num ? limit.toInt() : int.tryParse('$limit');
  }

  final result = await DatabasePlugin.instance.useCase.getRecords(normalized);

  if (result.isFailure) {
    return jsonEncode({'error': result.errorOrNull?.message});
  }

  return jsonEncode(result.dataOrNull);
}

/// 创建记录
Future<String> _jsCreateRecord(Map<String, dynamic> params) async {
  final normalized = _toTableParams(params);
  final error = _applyFieldsJson(normalized);
  if (error != null) return jsonEncode({'error': error});

  final result = await DatabasePlugin.instance.useCase.createRecord(normalized);

  if (result.isFailure) {
    return jsonEncode({'error': result.errorOrNull?.message});
  }

  return jsonEncode(result.dataOrNull);
}

/// 更新记录
Future<String> _jsUpdateRecord(Map<String, dynamic> params) async {
  final normalized = _toIdParams(params);
  final error = _applyFieldsJson(normalized);
  if (error != null) return jsonEncode({'error': error});

  final result = await DatabasePlugin.instance.useCase.updateRecord(normalized);

  if (result.isFailure) {
    return jsonEncode({'error': result.errorOrNull?.message});
  }

  return jsonEncode(result.dataOrNull);
}

/// 删除记录
Future<String> _jsDeleteRecord(Map<String, dynamic> params) async {
  final result = await DatabasePlugin.instance.useCase.deleteRecord(
    _toIdParams(params),
  );

  if (result.isFailure) {
    return jsonEncode({'success': false, 'error': result.errorOrNull?.message});
  }

  return jsonEncode({'success': true});
}

/// 查询记录
/// 支持参数: databaseId, filtersJson, offset, count
Future<String> _jsQuery(Map<String, dynamic> params) async {
  final checkError = _checkTableId(params);
  if (checkError != null) return jsonEncode({'error': checkError});

  // 过滤必须发生在分页之前：先取全量，过滤后手动分页
  final normalized = _toTableParams(params)
    ..remove('offset')
    ..remove('count');
  final filters = _parseJsonParam(normalized.remove('filtersJson')) ??
      normalized.remove('filters');
  if (filters != null && filters is! Map<String, dynamic>) {
    return jsonEncode({'error': '参数 filtersJson 不是合法的 JSON 对象'});
  }

  final result = await DatabasePlugin.instance.useCase.searchRecords(normalized);
  if (result.isFailure) {
    return jsonEncode({'error': result.errorOrNull?.message});
  }

  var records = (result.dataOrNull as List)
      .whereType<Map>()
      .map((r) => Map<String, dynamic>.from(r))
      .toList();
  if (filters != null) {
    records = records
        .where((record) => (filters as Map<String, dynamic>).entries.every(
              (e) => _recordFieldMatches(record, e.key, e.value),
            ))
        .toList();
  }

  if (!params.containsKey('offset') && !params.containsKey('count')) {
    return jsonEncode(records);
  }

  final offset = (params['offset'] as num?)?.toInt() ?? 0;
  final count = (params['count'] as num?)?.toInt() ?? 100;
  final start = offset.clamp(0, records.length);
  final end = (start + count).clamp(start, records.length);
  return jsonEncode({
    'data': records.sublist(start, end),
    'total': records.length,
    'offset': start,
    'count': end - start,
    'hasMore': end < records.length,
  });
}

/// 内置字段（id/tableId 等）或 fields 内自定义字段是否与期望值精确匹配
bool _recordFieldMatches(
  Map<String, dynamic> record,
  String key,
  dynamic value,
) {
  if (record[key]?.toString() == value?.toString()) return true;
  final fields = record['fields'] as Map<String, dynamic>?;
  return fields?[key]?.toString() == value?.toString();
}

/// 获取数据库或记录数量
Future<dynamic> _jsGetCount(Map<String, dynamic> params) async {
  final String? type = params['type'];
  if (type == null) {
    return jsonEncode({
      'error': "缺少必需参数: type（'databases' 数据库总数 或 'records' 记录数）",
    });
  }

  if (type == 'databases') {
    return await DatabasePlugin.instance.service.getDatabaseCount();
  }

  if (type == 'records') {
    final String? databaseId = params['databaseId'];
    if (databaseId == null || databaseId.isEmpty) {
      return jsonEncode({
        'error': "type='records' 时必须提供 databaseId（可先调用 getDatabases 获取）",
      });
    }
    final records = await DatabasePlugin.instance.controller.getRecords(
      databaseId,
    );
    return records.length;
  }

  return jsonEncode({'error': "type 只接受 'databases' 或 'records'，收到: $type"});
}

// ==================== 数据库查找方法 ====================

/// 通用数据库查找
/// 支持分页参数: offset, count (仅 findAll=true 时有效)
Future<String> _jsFindDatabaseBy(Map<String, dynamic> params) async {
  try {
    final String? field = params['field'];
    if (field == null || field.isEmpty) {
      return jsonEncode({'error': '缺少必需参数: field'});
    }

    final dynamic value = params['value'];
    if (value == null) {
      return jsonEncode({'error': '缺少必需参数: value'});
    }

    final bool findAll = params['findAll'] ?? false;

    // 使用 UseCase 搜索数据库
    final searchParams = <String, dynamic>{};
    if (field == 'name') {
      searchParams['nameKeyword'] = value.toString();
    }

    final result = await DatabasePlugin.instance.useCase.searchDatabases(
      searchParams,
    );

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    var databases = result.dataOrNull as List;
    // 过滤匹配字段
    databases = databases.where((db) {
      final dbMap = db as Map<String, dynamic>;
      return dbMap.containsKey(field) && dbMap[field] == value;
    }).toList();

    if (findAll) {
      return jsonEncode(databases);
    } else {
      return databases.isEmpty ? jsonEncode(null) : jsonEncode(databases.first);
    }
  } catch (e) {
    return jsonEncode({'error': '查找数据库失败: $e'});
  }
}

/// 根据 ID 查找数据库
Future<String> _jsFindDatabaseById(Map<String, dynamic> params) async {
  final result = await DatabasePlugin.instance.useCase.getDatabaseById(params);

  if (result.isFailure) {
    return jsonEncode({'error': result.errorOrNull?.message});
  }

  return jsonEncode(result.dataOrNull);
}

/// 根据名称查找数据库
/// 支持分页参数: offset, count (仅 findAll=true 时有效)
Future<String> _jsFindDatabaseByName(Map<String, dynamic> params) async {
  try {
    final String? name = params['name'];
    if (name == null || name.isEmpty) {
      return jsonEncode({'error': '缺少必需参数: name'});
    }

    final bool fuzzy = params['fuzzy'] ?? false;
    final bool findAll = params['findAll'] ?? false;

    // 使用 UseCase 搜索数据库
    final searchParams = <String, dynamic>{'nameKeyword': name};

    final result = await DatabasePlugin.instance.useCase.searchDatabases(
      searchParams,
    );

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    var databases = result.dataOrNull as List;
    // 如果不是模糊搜索，进一步过滤精确匹配
    if (!fuzzy) {
      databases = databases.where((db) {
        final dbMap = db as Map<String, dynamic>;
        return dbMap['name'] == name;
      }).toList();
    }

    if (findAll) {
      return jsonEncode(databases);
    } else {
      return databases.isEmpty ? jsonEncode(null) : jsonEncode(databases.first);
    }
  } catch (e) {
    return jsonEncode({'error': '查找数据库失败: $e'});
  }
}

// ==================== 记录查找方法 ====================

/// 通用记录查找
/// 支持分页参数: offset, count (仅 findAll=true 时有效)
Future<String> _jsFindRecordBy(Map<String, dynamic> params) async {
  try {
    final String? databaseId = params['databaseId'];
    if (databaseId == null || databaseId.isEmpty) {
      return jsonEncode({'error': '缺少必需参数: databaseId'});
    }

    final String? field = params['field'];
    if (field == null || field.isEmpty) {
      return jsonEncode({'error': '缺少必需参数: field'});
    }

    final dynamic value = params['value'];
    if (value == null) {
      return jsonEncode({'error': '缺少必需参数: value'});
    }

    final bool findAll = params['findAll'] ?? false;

    // 使用 UseCase 搜索记录
    final searchParams = <String, dynamic>{
      'tableId': databaseId,
      'fieldKeyword': value.toString(),
    };

    final result = await DatabasePlugin.instance.useCase.searchRecords(
      searchParams,
    );

    if (result.isFailure) {
      return jsonEncode({'error': result.errorOrNull?.message});
    }

    var records = result.dataOrNull as List;
    // 进一步过滤匹配字段
    records = records.where((record) {
      final recordMap = record as Map<String, dynamic>;
      // 检查内置字段
      if (recordMap.containsKey(field) && recordMap[field] == value) {
        return true;
      }
      // 检查自定义字段
      final fields = recordMap['fields'] as Map<String, dynamic>?;
      return fields?.containsKey(field) == true && fields![field] == value;
    }).toList();

    if (findAll) {
      return jsonEncode(records);
    } else {
      return records.isEmpty ? jsonEncode(null) : jsonEncode(records.first);
    }
  } catch (e) {
    return jsonEncode({'error': '查找记录失败: $e'});
  }
}

/// 根据 ID 查找记录
Future<String> _jsFindRecordById(Map<String, dynamic> params) async {
  final result = await DatabasePlugin.instance.useCase.getRecordById(params);

  if (result.isFailure) {
    return jsonEncode({'error': result.errorOrNull?.message});
  }

  return jsonEncode(result.dataOrNull);
}
