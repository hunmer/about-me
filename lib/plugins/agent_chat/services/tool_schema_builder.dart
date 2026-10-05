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
  static Map<String, dynamic> buildSchemaMap(List<ToolParameter> params) {
    if (params.isEmpty) {
      return {'type': 'object', 'properties': {}, 'required': []};
    }
    final properties = <String, dynamic>{};
    final required = <String>[];
    for (final p in params) {
      final type = _normalizeType(p.type);
      final prop = <String, dynamic>{
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
    return {
      'type': 'object',
      'properties': properties,
      'required': required,
    };
  }

  static Map<String, dynamic> _propsMap(List<ToolParameter> params) {
    final map = <String, dynamic>{};
    for (final p in params) {
      final prop = <String, dynamic>{
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

  /// 生成 FC 工具描述：标题 + 说明 + 返回值 + 首个示例（帮助模型理解参数用法）
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
    // 示例代码对参数格式很有指导性，取一条（截断控制 token）
    if (config.examples.isNotEmpty) {
      final code = config.examples.first.code.trim();
      if (code.isNotEmpty) {
        final clipped =
            code.length > 400 ? '${code.substring(0, 400)}…' : code;
        buffer
          ..write('\n参考调用：')
          ..write(clipped);
      }
    }
    if (config.notes != null && config.notes!.isNotEmpty) {
      buffer
        ..write('\n注意：')
        ..write(config.notes);
    }
    return buffer.toString().trim();
  }
}
