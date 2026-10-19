import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';

/// ToolConfig → 原生 function calling 的 JSON Schema / 描述文本
///
/// 供 dartantic_ai 的 Tool(name, description, inputSchema) 使用
class ToolSchemaBuilder {
  /// 脏 type → JSON Schema type 的规范化映射（键统一小写比较）
  static const _typeMap = {
    'string': 'string',
    'string|number': 'string',
    'number': 'number',
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
      final type = _normalizeType(p.type);
      final prop = <String, Object?>{
        'type': type,
        'description': p.description,
      };
      if (type == 'object' && p.properties.isNotEmpty) {
        prop['properties'] = _propsMap(p.properties);
        prop['required'] = _requiredOf(p.properties);
      }
      properties[p.name] = prop;
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
      final prop = <String, Object?>{
        'type': _normalizeType(p.type),
        'description': p.description,
      };
      if (prop['type'] == 'object' && p.properties.isNotEmpty) {
        prop['properties'] = _propsMap(p.properties);
        prop['required'] = _requiredOf(p.properties);
      }
      map[p.name] = prop;
    }
    return map;
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
