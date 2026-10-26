import 'dart:convert';

import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_response_json_parser.dart';

/// 模板修改策略
enum TemplateStrategy {
  /// 关键词替换 - 简单的字符串替换
  replace,

  /// 重写代码 - AI 根据需求重新生成代码
  rewrite,
}

/// 工具模版匹配结果
class TemplateMatch {
  final String id;
  final TemplateStrategy strategy;
  final List<ReplacementRule>? replacements;
  final List<Map<String, dynamic>>? rewrittenSteps;

  TemplateMatch({
    required this.id,
    this.strategy = TemplateStrategy.replace,
    this.replacements,
    this.rewrittenSteps,
  });

  factory TemplateMatch.fromJson(Map<String, dynamic> json) {
    final replacementsList = json['replacements'] as List<dynamic>?;
    final rewrittenStepsList = json['rewritten_steps'] as List<dynamic>?;
    final strategyStr = json['strategy'] as String? ?? 'replace';

    return TemplateMatch(
      id: json['id'] as String,
      strategy:
          strategyStr == 'rewrite'
              ? TemplateStrategy.rewrite
              : TemplateStrategy.replace,
      replacements:
          replacementsList
              ?.map((r) => ReplacementRule.fromJson(r as Map<String, dynamic>))
              .toList(),
      rewrittenSteps:
          rewrittenStepsList?.map((s) => s as Map<String, dynamic>).toList(),
    );
  }
}

/// 参数替换规则
class ReplacementRule {
  final String from;
  final String to;

  ReplacementRule({required this.from, required this.to});

  factory ReplacementRule.fromJson(Map<String, dynamic> json) {
    return ReplacementRule(
      from: json['from'] as String,
      to: json['to'] as String,
    );
  }
}

/// 工具模版匹配器（第零阶段）
///
/// 负责工具模版匹配的 Schema 定义、Prompt 生成和匹配结果解析
class ToolTemplateMatcher {
  /// 第零阶段 JSON Schema - 工具模版匹配
  static const Map<String, dynamic> schema = {
    'type': 'object',
    'properties': {
      'use_tool_temps': {
        'type': 'array',
        'description': '匹配的工具模版列表',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string', 'description': '模版ID'},
            'strategy': {
              'type': 'string',
              'enum': ['replace', 'rewrite'],
              'description': '修改策略：replace=关键词替换（简单参数变化），rewrite=重写代码（复杂逻辑变化）',
            },
            'replacements': {
              'type': 'array',
              'description': '需要替换的参数列表（strategy=replace时使用）',
              'items': {
                'type': 'object',
                'properties': {
                  'from': {'type': 'string', 'description': '要替换的原始字符串'},
                  'to': {'type': 'string', 'description': '替换后的新字符串'},
                },
                'required': ['from', 'to'],
                'additionalProperties': false,
              },
            },
            'rewritten_steps': {
              'type': 'array',
              'description': '重写后的代码步骤（strategy=rewrite时使用）',
              'items': {
                'type': 'object',
                'properties': {
                  'method': {
                    'type': 'string',
                    'enum': ['run_js'],
                    'description': '执行方法',
                  },
                  'title': {'type': 'string', 'description': '步骤标题'},
                  'desc': {'type': 'string', 'description': '步骤描述'},
                  'data': {'type': 'string', 'description': 'JavaScript 代码'},
                },
                'required': ['method', 'title', 'desc', 'data'],
                'additionalProperties': false,
              },
            },
          },
          'required': ['id', 'strategy'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['use_tool_temps'],
    'additionalProperties': false,
  };

  /// 生成工具模版列表 Prompt（第零阶段）
  ///
  /// 参数：
  /// - templates: 工具模版列表（需要从 ToolTemplateService 获取）
  ///
  /// 返回格式化的模版列表字符串，用于让 AI 匹配合适的模版
  static String buildTemplatePrompt(List<dynamic> templates) {
    if (templates.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('\n## 📋 可用工具模版');
    buffer.writeln('\n以下是已保存的工具模版列表。请分析用户的需求，判断是否有合适的模版可以使用。');
    buffer.writeln('\n### 🎯 双策略选择');
    buffer.writeln('你需要根据用户需求与模版的差异程度选择合适的修改策略：\n');
    buffer.writeln('**策略1: `replace` - 关键词替换**（优先选择）');
    buffer.writeln('- 适用场景：功能相同，只是参数/名称不同');
    buffer.writeln('- 示例：模版"签到早起"→用户输入"签到早睡"，只需替换"早起"→"早睡"');
    buffer.writeln(
      '- 返回：`{"id": "xxx", "strategy": "replace", "replacements": [{"from": "早起", "to": "早睡"}]}`\n',
    );
    buffer.writeln('**策略2: `rewrite` - 重写代码**');
    buffer.writeln('- 适用场景：逻辑需要修改，简单替换无法满足');
    buffer.writeln('- 示例：模版"记录跑步5公里"→用户输入"记录游泳30分钟"（单位和逻辑都不同）');
    buffer.writeln(
      '- 返回：`{"id": "xxx", "strategy": "rewrite", "rewritten_steps": [...]}`\n',
    );
    buffer.writeln('### 📝 返回格式\n');
    buffer.writeln('```json');
    buffer.writeln('{');
    buffer.writeln('  "use_tool_temps": [');
    buffer.writeln('    {');
    buffer.writeln('      "id": "template_id",');
    buffer.writeln('      "strategy": "replace",  // 或 "rewrite"');
    buffer.writeln(
      '      "replacements": [{"from": "原字符串", "to": "新字符串"}],  // strategy=replace时',
    );
    buffer.writeln('      "rewritten_steps": [...]  // strategy=rewrite时');
    buffer.writeln('    }');
    buffer.writeln('  ]');
    buffer.writeln('}');
    buffer.writeln('```');
    buffer.writeln('\n如果没有合适的模版，返回空数组：');
    buffer.writeln('```json');
    buffer.writeln('{"use_tool_temps": []}');
    buffer.writeln('```\n');
    buffer.writeln('### 工具模版列表\n');

    // 格式化模版列表为 [['id', 'title', 'desc'], ...]
    for (final template in templates) {
      // template 可能是 SavedToolTemplate 对象，需要访问其属性
      final id = template.id ?? 'unknown';
      final name = template.name ?? '未命名模版';
      final description = template.description ?? '无描述';

      buffer.writeln('**$id**: $name');
      buffer.writeln('  描述: $description');

      // 显示声明的工具
      if (template.declaredTools != null && template.declaredTools.isNotEmpty) {
        final toolNames = template.declaredTools
            .map((t) => t['toolName'] ?? t['toolId'])
            .join(', ');
        buffer.writeln('  使用工具: $toolNames');
      }

      // 🔍 添加代码预览（前2个步骤，每个步骤最多200字符）
      // if (template.steps != null && template.steps.isNotEmpty) {
      //   buffer.writeln('  代码预览:');
      //   for (int i = 0; i < template.steps.length && i < 2; i++) {
      //     final step = template.steps[i];
      //     final code =
      //         step.data.length > 200
      //             ? '${step.data.substring(0, 200)}...'
      //             : step.data;
      //     // 转义代码中的特殊字符，避免破坏 Markdown 格式
      //     final escapedCode = code.replaceAll('`', '\\`').replaceAll('\n', ' ');
      //     buffer.writeln('    - ${step.title}: `$escapedCode`');
      //   }
      // }

      buffer.writeln();
    }

    buffer.writeln('### 匹配规则\n');
    buffer.writeln('1. **完全匹配**：用户需求与模版完全一致');
    buffer.writeln(
      '   → `{"id": "xxx", "strategy": "replace", "replacements": []}`\n',
    );
    buffer.writeln('2. **参数化匹配**：功能相同但参数不同（优先使用 replace 策略）');
    buffer.writeln('   - 示例：模版"签到早起"，代码中有 `i.name === "早起"`，用户输入"签到早睡"');
    buffer.writeln(
      '   → `{"id": "xxx", "strategy": "replace", "replacements": [{"from": "早起", "to": "早睡"}]}`\n',
    );
    buffer.writeln('3. **逻辑变更**：需要修改代码逻辑（使用 rewrite 策略）');
    buffer.writeln('   - 示例：原模版记录"个数"，用户想改成记录"时长"');
    buffer.writeln(
      '   → `{"id": "xxx", "strategy": "rewrite", "rewritten_steps": [...]}`\n',
    );
    buffer.writeln('4. **多模版**：可以返回多个模版（如果用户需求可以拆分为多个任务）');
    buffer.writeln('5. **无匹配**：不确定或没有合适的模版 → 返回空数组');
    buffer.writeln('6. **优先级**：replace > rewrite（能用替换解决的就不要重写）\n');
    buffer.writeln('⚠️ **重要**：');
    buffer.writeln('- `strategy` 字段**必填**，必须是 "replace" 或 "rewrite"');
    buffer.writeln('- replacements 中的 `from` 必须是**代码预览中实际存在**的精确字符串');
    buffer.writeln('- rewritten_steps 需要完整的代码步骤，参考原模版的代码结构');

    return buffer.toString();
  }

  /// 解析 AI 返回的工具模版匹配结果
  static List<TemplateMatch>? parseMatch(String response) {
    try {
      // 使用通用JSON提取方法
      final jsonStr = ToolResponseJsonParser.extractJsonFromResponse(
        response,
        requiredField: 'use_tool_temps',
      );

      if (jsonStr == null) {
        return null;
      }

      // 修复JSON格式错误并解析
      final fixedJsonStr = ToolResponseJsonParser.fixInvalidJson(jsonStr);
      final json = jsonDecode(fixedJsonStr) as Map<String, dynamic>;
      if (!json.containsKey('use_tool_temps')) {
        print('[ToolService] JSON 中缺少 use_tool_temps 字段');
        return null;
      }

      final templates = json['use_tool_temps'] as List<dynamic>;
      final matches =
          templates.map((e) {
            if (e is String) {
              // 兼容旧格式（只有ID）
              return TemplateMatch(id: e);
            } else if (e is Map<String, dynamic>) {
              // 新格式（包含replacements）
              return TemplateMatch.fromJson(e);
            } else {
              throw Exception('无效的模版匹配格式');
            }
          }).toList();

      print('[ToolService] 成功解析工具模版匹配，匹配到 ${matches.length} 个模版');
      for (var match in matches) {
        if (match.replacements != null && match.replacements!.isNotEmpty) {
          print(
            '[ToolService]   - ${match.id}: ${match.replacements!.length} 个参数替换',
          );
        }
      }
      return matches;
    } catch (e) {
      print('[ToolService] 解析工具模版匹配失败: $e');
      return null;
    }
  }

  /// 应用参数替换到模版步骤
  static List<ToolCallStep> applyReplacements(
    List<ToolCallStep> steps,
    List<ReplacementRule> replacements,
  ) {
    if (replacements.isEmpty) return steps;

    return steps.map((step) {
      String newData = step.data;
      String newTitle = step.title;
      String newDesc = step.desc;

      // 对每个替换规则应用到代码、标题、描述
      for (var rule in replacements) {
        newData = newData.replaceAll(rule.from, rule.to);
        newTitle = newTitle.replaceAll(rule.from, rule.to);
        newDesc = newDesc.replaceAll(rule.from, rule.to);
      }

      // 创建新的步骤对象
      return ToolCallStep(
        method: step.method,
        title: newTitle,
        desc: newDesc,
        data: newData,
      );
    }).toList();
  }
}
