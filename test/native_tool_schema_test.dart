import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_schema_builder.dart';

void main() {
  group('ToolParameter 嵌套 properties 解析', () {
    test('object 参数解析嵌套属性', () {
      final param = ToolParameter.fromJson({
        'name': 'params',
        'type': 'object',
        'required': true,
        'description': '查询参数',
        'properties': [
          {
            'name': 'completed',
            'type': 'boolean',
            'optional': true,
            'description': '是否完成',
          },
          {'name': 'tag', 'type': 'string', 'required': true, 'description': '标签'},
        ],
      });
      expect(param.properties.length, 2);
      expect(param.properties[0].name, 'completed');
      expect(param.properties[0].optional, true);
      expect(param.properties[1].optional, false);
      // 序列化往返
      final json = param.toJson();
      expect((json['properties'] as List).length, 2);
    });
  });

  group('ToolSchemaBuilder', () {
    test('脏 type 规范化', () {
      final schema = ToolSchemaBuilder.buildSchemaMap([
        ToolParameter(
          name: 'a',
          type: 'String',
          description: '大小写变体',
        ),
        ToolParameter(
          name: 'b',
          type: 'Array<string>',
          description: '泛型数组',
        ),
        ToolParameter(
          name: 'c',
          type: 'any',
          description: '未知类型降级 string',
        ),
      ]);
      final props = schema['properties'] as Map<String, dynamic>;
      expect((props['a'] as Map)['type'], 'string');
      expect((props['b'] as Map)['type'], 'array');
      expect((props['c'] as Map)['type'], 'string');
      // 无 optional → 全部 required
      expect(schema['required'], ['a', 'b', 'c']);
    });

    test('object 参数生成嵌套 schema', () {
      final schema = ToolSchemaBuilder.buildSchemaMap([
        ToolParameter(
          name: 'filter',
          type: 'object',
          optional: false,
          description: '过滤条件',
          properties: [
            ToolParameter(name: 'date', type: 'string', description: '日期'),
            ToolParameter(
              name: 'limit',
              type: 'number',
              optional: true,
              description: '数量',
            ),
          ],
        ),
      ]);
      final filter = (schema['properties'] as Map<String, dynamic>)['filter']
          as Map<String, dynamic>;
      expect(filter['type'], 'object');
      final nested = filter['properties'] as Map<String, dynamic>;
      expect(nested.keys.toSet(), {'date', 'limit'});
      expect(filter['required'], ['date']);
      expect(schema['required'], ['filter']);
    });

    test('空参数生成空 object schema', () {
      final schema = ToolSchemaBuilder.buildSchemaMap([]);
      expect(schema['type'], 'object');
      expect(schema['properties'], {});
    });

    test('描述组装包含说明与示例', () {
      final config = ToolConfig(
        title: '测试工具',
        description: '这是描述',
        parameters: [],
        returns: ToolReturns(type: 'string', description: '返回字符串'),
        examples: [
          ToolExample(code: "const r = await test();", comment: '示例'),
        ],
      );
      final desc = ToolSchemaBuilder.buildDescription(config);
      expect(desc.contains('这是描述'), true);
      expect(desc.contains('返回字符串'), true);
      expect(desc.contains('await test()'), true);
    });
  });

  group('NativeToolAgentService.matchPluginCandidates 预筛', () {
    test('领域词命中候选插件并并入常驻集合', () {
      final r = NativeToolAgentService.matchPluginCandidates('帮我记个账单');
      expect(r, isNotNull);
      expect(r!.contains('bill'), true);
      expect(r.contains('moments'), true); // 常驻
      expect(r.contains('openai'), true); // 常驻
    });

    test('照片类词同时命中相册与 moments（常驻）', () {
      final r = NativeToolAgentService.matchPluginCandidates('看看你的照片');
      expect(r, isNotNull);
      expect(r!.contains('calendar_album'), true);
      expect(r.contains('moments'), true);
    });

    test('无匹配返回 null（全量注入保底）', () {
      expect(NativeToolAgentService.matchPluginCandidates('今天好累啊'), isNull);
    });

    test('空文本返回 null', () {
      expect(NativeToolAgentService.matchPluginCandidates('  '), isNull);
    });
  });

  group('NativeToolAgentService.supports', () {
    test('Anthropic Agent 使用标准 function calling', () {
      final now = DateTime(2026, 1, 1);
      final agent = AIAgent(
        id: 'anthropic-agent',
        name: 'Anthropic',
        description: '',
        tags: const [],
        serviceProviderId: 'anthropic',
        baseUrl: 'https://api.anthropic.com/v1',
        headers: const {'x-api-key': 'test-key'},
        createdAt: now,
        updatedAt: now,
        model: 'claude-sonnet-4-5',
        enableFunctionCalling: true,
        apiFormat: 'anthropic',
      );

      expect(NativeToolAgentService.instance.supports(agent, true), isTrue);
      expect(NativeToolAgentService.instance.supports(agent, false), isFalse);
      expect(
        NativeToolAgentService.instance.supports(
          agent.copyWith(baseUrl: 'https://open.bigmodel.cn/api/anthropic'),
          true,
        ),
        isFalse,
      );
    });
  });
}
