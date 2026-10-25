import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';

/// ToolConfig → 原生 function calling 的 JSON Schema / 描述文本
///
/// 供 dartantic_ai 的 Tool(name, description, inputSchema) 使用
class ToolSchemaBuilder {
  /// 单个 params 对象是 JS 的调用包装，原生工具直接展示其业务字段。
  static List<ToolParameter> invocationParameters(ToolConfig config) {
    if (config.parameters.length == 1 &&
        config.parameters.single.name == 'params' &&
        config.parameters.single.type.toLowerCase() == 'object') {
      return config.parameters.single.properties;
    }
    return config.parameters;
  }

  /// 在归一化后的 Dart 实参上校验必填字段，包含嵌套对象。
  static List<String> missingRequiredParameters(
    ToolConfig config,
    Map<String, dynamic> args,
  ) {
    List<String> missing(
      List<ToolParameter> parameters,
      Map values, [
      String prefix = '',
    ]) {
      final result = <String>[];
      for (final parameter in parameters) {
        final value = values[parameter.name];
        final name = '$prefix${parameter.name}';
        if (value == null) {
          if (!parameter.optional) result.add(name);
        } else {
          final valid = _constraintError(parameter, value);
          if (valid != null) {
            result.add('$name: $valid');
          }
          if (value is Map && parameter.properties.isNotEmpty) {
            result.addAll(missing(parameter.properties, value, '$name.'));
          }
        }
      }
      return result;
    }

    return missing(invocationParameters(config), args);
  }

  /// 配置中的 params 表示 JS API 的单个对象实参，Dart 回调直接接收其内容。
  static Map<String, dynamic> invocationArgs(
    ToolConfig config,
    Map<String, dynamic> args,
  ) {
    if (config.parameters.length == 1 &&
        config.parameters.single.name == 'params' &&
        config.parameters.single.type.toLowerCase() == 'object' &&
        args['params'] is Map) {
      return Map<String, dynamic>.from(args['params'] as Map);
    }
    return Map<String, dynamic>.from(args);
  }

  static String? _constraintError(ToolParameter parameter, dynamic value) {
    if (parameter.minLength != null &&
        value is String &&
        value.length < parameter.minLength!) {
      return '长度不能少于 ${parameter.minLength}';
    }
    if (parameter.pattern != null &&
        value is String &&
        !RegExp(parameter.pattern!).hasMatch(value)) {
      return '格式不符合要求';
    }
    if (parameter.minItems != null &&
        value is List &&
        value.length < parameter.minItems!) {
      return '数量不能少于 ${parameter.minItems}';
    }
    if (parameter.items != null && value is List) {
      for (var index = 0; index < value.length; index++) {
        final error = _constraintError(parameter.items!, value[index]);
        if (error != null) return '第 ${index + 1} 项 $error';
      }
    }
    return null;
  }

  static String? resultError(dynamic result) {
    if (result is! Map) return null;
    final error = result['error'];
    if (error != null && error.toString().isNotEmpty) return error.toString();
    if (result['success'] == false) {
      return result['message']?.toString() ?? '插件返回执行失败';
    }
    return null;
  }

  /// 脏 type → JSON Schema type 的规范化映射（键统一小写比较）
  static const _typeMap = {
    'string': 'string',
    'string|number': 'string',
    'number': 'number',
    'integer': 'integer',
    'boolean': 'boolean',
    'array': 'array',
    'object': 'object',
  };

  static String _normalizeType(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'array<string>') return 'array';
    if (lower.startsWith('array')) return 'array';
    return _typeMap[lower] ?? 'string'; // any 等未知类型降级 string
  }

  /// 参数列表 → JSON Schema properties + required
  static Map<String, Object?> buildSchemaMap(List<ToolParameter> params) {
    if (params.isEmpty) {
      return <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{},
        'required': <String>[],
      };
    }
    final properties = <String, Object?>{};
    final required = <String>[];
    for (final p in params) {
      properties[p.name] = _schemaFor(p);
      if (!p.optional) required.add(p.name);
    }
    return <String, Object?>{
      'type': 'object',
      'properties': properties,
      'required': required,
    };
  }

  static Map<String, Object?> _propsMap(List<ToolParameter> params) {
    final map = <String, Object?>{};
    for (final p in params) {
      map[p.name] = _schemaFor(p);
    }
    return map;
  }

  static Map<String, Object?> _schemaFor(ToolParameter parameter) {
    final type = _normalizeType(parameter.type);
    final schema = <String, Object?>{
      'type': type,
      'description': parameter.description,
      if (parameter.minLength != null) 'minLength': parameter.minLength,
      if (parameter.pattern != null) 'pattern': parameter.pattern,
      if (parameter.minItems != null) 'minItems': parameter.minItems,
    };
    if (type == 'object' && parameter.properties.isNotEmpty) {
      schema['properties'] = _propsMap(parameter.properties);
      schema['required'] = _requiredOf(parameter.properties);
    }
    if (parameter.items != null) {
      schema['items'] = _schemaFor(parameter.items!);
    }
    return schema;
  }

  static List<String> _requiredOf(List<ToolParameter> params) =>
      params.where((p) => !p.optional).map((p) => p.name).toList();

  /// 生成原生工具描述，不注入面向 JS 执行环境的调用示例。
  static String buildDescription(ToolConfig config) {
    final buffer = StringBuffer();
    if (config.description.isNotEmpty) {
      buffer.write(config.description);
    }
    if (config.returns.description.isNotEmpty) {
      buffer
        ..write('\n返回：')
        ..write(config.returns.description);
    }
    if (config.notes != null && config.notes!.isNotEmpty) {
      buffer
        ..write('\n注意：')
        ..write(config.notes);
    }
    return buffer.toString().trim();
  }
}
