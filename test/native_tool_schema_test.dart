import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartantic_ai/dartantic_ai.dart';

import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_schema_builder.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';

void main() {
  test('时间工具返回可解析的时间和时区', () {
    final now = DateTime(2026, 10, 19, 18, 21);
    final result = NativeToolAgentService.currentTimeData(now);
    expect(DateTime.parse(result['datetime'] as String).millisecondsSinceEpoch,
        now.millisecondsSinceEpoch);
    expect(result['timezone'], now.timeZoneName);
    expect(result['utcOffset'], matches(RegExp(r'^[+-]\d{2}:\d{2}$')));
    expect(result['year'], 2026);
    final utc = NativeToolAgentService.currentTimeData(now.toUtc());
    expect(utc['utcOffset'], '+00:00');
    expect(DateTime.parse(utc['datetime'] as String), now.toUtc());
  });

  group('工具执行模式', () {
    test('提问工具在普通、JS 和内置工具模式均可用', () {
      for (final mode in [(false, false), (true, false), (false, true)]) {
        final tools = NativeToolAgentService.buildToolSet(
          pluginTools: [],
          onRunJs: (_) async => {},
          onAskUserQuestions: (_) async => {'status': 'answered'},
          useJsTools: mode.$1,
          builtInOnly: mode.$2,
        );
        expect(tools.map((tool) => tool.name), contains('askuserquestions'));
      }
    });
    late Tool<Map<String, dynamic>> pluginTool;
    setUp(() {
      pluginTool = Tool<Map<String, dynamic>>(
        name: 'bill',
        description: '账单插件',
        inputSchema: Schema.fromMap(ToolSchemaBuilder.buildSchemaMap([])),
        onCall: (args) async => {'ok': true},
      );
    });

    test('默认同时提供插件工具与 run_js', () {
      final tools = NativeToolAgentService.buildToolSet(
        pluginTools: [pluginTool],
        onRunJs: (args) async => {'result': args['code']},
      );
      expect(tools.map((t) => t.name), ['bill', 'get_current_time', 'run_js']);
      expect(tools.first, same(pluginTool));
      expect(tools.last.description, contains('专用工具可完成的操作应直接调用'));
      expect(tools.last.description, isNot(contains('账单插件')));
    });

    test('JS 模式仍保留内置记忆，关闭通用工具时不提供 run_js', () {
      final memory = Tool<Map<String, dynamic>>(
        name: 'memory',
        description: '历史记忆',
        inputSchema: Schema.fromMap(ToolSchemaBuilder.buildSchemaMap([])),
        onCall: (_) async => {'memories': []},
      );
      final jsMode = NativeToolAgentService.buildToolSet(
        pluginTools: [pluginTool, memory],
        onRunJs: (_) async => {},
        useJsTools: true,
      );
      expect(jsMode.map((t) => t.name), ['memory', 'get_current_time', 'run_js']);
      final builtInMode = NativeToolAgentService.buildToolSet(
        pluginTools: [memory],
        onRunJs: (_) async => {},
        useJsTools: true,
        builtInOnly: true,
      );
      expect(builtInMode.map((t) => t.name), ['memory', 'get_current_time']);
    });

    test('JS 模式保留六个记忆读写工具', () {
      final memoryTools = [
        for (final name in [
          'list_memory_keys',
          'search_memory',
          'batch_search_memory',
          'add_memory',
          'update_memory',
          'delete_memory',
        ])
          Tool<Map<String, dynamic>>(
            name: name,
            description: name,
            inputSchema: Schema.fromMap(ToolSchemaBuilder.buildSchemaMap([])),
            onCall: (_) async => {'memoryId': 'library'},
          ),
      ];
      final tools = NativeToolAgentService.buildToolSet(
        pluginTools: memoryTools,
        onRunJs: (_) async => {},
        useJsTools: true,
      );
      expect(
        tools.map((tool) => tool.name),
        ['list_memory_keys', 'search_memory', 'batch_search_memory', 'add_memory', 'update_memory', 'delete_memory', 'get_current_time', 'run_js'],
      );
    });

    test('开启 JS 模式时保留时间工具与 run_js', () {
      final tools = NativeToolAgentService.buildToolSet(
        pluginTools: [pluginTool],
        onRunJs: (args) async => {'result': args['code']},
        useJsTools: true,
      );
      expect(tools.map((t) => t.name), ['get_current_time', 'run_js']);
      expect(tools.last.description, '执行 JavaScript 代码。');
    });

    test('开启 JS 模式时仍保留 read_image 标准工具', () {
      final readImageTool = Tool<Map<String, dynamic>>(
        name: 'read_image',
        description: '读取图片',
        inputSchema: Schema.fromMap({
          'type': 'object',
          'properties': {
            'paths': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
          'required': ['paths'],
        }),
        onCall: (args) async => {'result': args['paths']},
      );
      final tools = NativeToolAgentService.buildToolSet(
        pluginTools: [pluginTool, readImageTool],
        onRunJs: (args) async => {'result': args['code']},
        useJsTools: true,
      );

      expect(tools.map((tool) => tool.name), ['read_image', 'get_current_time', 'run_js']);
    });
  });

  group('ToolParameter 嵌套 properties 解析', () {
    test('约束字段支持序列化往返和 copyWith', () {
      final param = ToolParameter.fromJson({
        'name': 'keys',
        'type': 'array',
        'required': true,
        'description': '要查询的 key 列表',
        'minItems': 1,
        'items': {
          'type': 'string',
          'minLength': 1,
          'pattern': r'^\S+$',
        },
      });

      expect(param.minItems, 1);
      expect(param.items?.name, '');
      expect(param.items?.description, '');
      expect(param.items?.minLength, 1);
      expect(param.items?.pattern, r'^\S+$');
      final roundTripped = ToolParameter.fromJson(param.toJson());
      expect(roundTripped.toJson(), param.toJson());

      final copied = param.copyWith(
        minLength: 2,
        pattern: r'^key\.',
        minItems: 2,
        items: ToolParameter(
          name: '',
          type: 'string',
          description: '',
          minLength: 2,
        ),
      );
      expect(copied.minLength, 2);
      expect(copied.pattern, r'^key\.');
      expect(copied.minItems, 2);
      expect(copied.items?.minLength, 2);
    });

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
          {
            'name': 'tag',
            'type': 'string',
            'required': true,
            'description': '标签',
          },
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

    test('object 参数解析映射格式嵌套属性（activity/todo/tracker 旧配置）', () {
      final param = ToolParameter.fromJson({
        'name': 'params',
        'type': 'object',
        'required': true,
        'description': '查询参数',
        'properties': {
          'date': {'type': 'string', 'required': false, 'description': '日期'},
          'offset': {'type': 'number', 'required': false, 'description': '偏移'},
          'title': {'type': 'string', 'required': true, 'description': '标题'},
        },
      });
      expect(param.properties.length, 3);
      expect(param.properties[0].name, 'date');
      expect(param.properties[0].optional, true);
      expect(param.properties[2].optional, false);
      expect(param.properties[2].type, 'string');
    });
  });

  group('ToolSchemaBuilder', () {
    test('插件聚合 schema 可以构造原生 Tool', () {
      final tool = Tool<Map<String, dynamic>>(
        name: 'bill',
        description: '插件 bill 可用方法：create: 创建账单',
        inputSchema: Schema.fromMap(<String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'method': <String, Object?>{
              'type': 'string',
              'enum': <String>['create'],
            },
            'args': <String, Object?>{'type': 'object'},
          },
          'required': <String>['method', 'args'],
        }),
        onCall: (args) async => {'ok': true},
      );
      expect(tool.name, 'bill');
    });

    test('空参数 schema 可以构造并执行原生 Tool', () async {
      final tool = Tool<Map<String, dynamic>>(
        name: 'no_parameters',
        description: '无参数工具',
        inputSchema: Schema.fromMap(ToolSchemaBuilder.buildSchemaMap([])),
        onCall: (args) async => {'ok': true},
      );
      expect(tool.name, 'no_parameters');
    });

    test('脏 type 规范化', () {
      final schema = ToolSchemaBuilder.buildSchemaMap([
        ToolParameter(name: 'a', type: 'String', description: '大小写变体'),
        ToolParameter(name: 'b', type: 'Array<string>', description: '泛型数组'),
        ToolParameter(name: 'c', type: 'any', description: '未知类型降级 string'),
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
      final filter =
          (schema['properties'] as Map<String, dynamic>)['filter']
              as Map<String, dynamic>;
      expect(filter['type'], 'object');
      final nested = filter['properties'] as Map<String, dynamic>;
      expect(nested.keys.toSet(), {'date', 'limit'});
      expect(filter['required'], ['date']);
      expect(schema['required'], ['filter']);
    });

    test('递归生成数组 items 的约束 schema', () {
      final schema = ToolSchemaBuilder.buildSchemaMap([
        ToolParameter(
          name: 'groups',
          type: 'array',
          description: '分组列表',
          minItems: 1,
          items: ToolParameter(
            name: '',
            type: 'object',
            description: '',
            properties: [
              ToolParameter(
                name: 'keys',
                type: 'array',
                description: 'key 列表',
                minItems: 1,
                items: ToolParameter(
                  name: '',
                  type: 'string',
                  description: '',
                  minLength: 1,
                  pattern: r'^\S+$',
                ),
              ),
            ],
          ),
        ),
      ]);

      final groups = (schema['properties'] as Map<String, dynamic>)['groups']
          as Map<String, dynamic>;
      expect(groups['minItems'], 1);
      final item = groups['items'] as Map<String, dynamic>;
      final keys = (item['properties'] as Map<String, dynamic>)['keys']
          as Map<String, dynamic>;
      expect(keys['minItems'], 1);
      expect(keys['items'], {
        'type': 'string',
        'description': '',
        'minLength': 1,
        'pattern': r'^\S+$',
      });
    });

    test('空参数生成空 object schema', () {
      final schema = ToolSchemaBuilder.buildSchemaMap([]);
      expect(schema['type'], 'object');
      expect(schema['properties'], {});
    });

    test('原生工具描述包含说明但不携带 JS 调用示例', () {
      final config = ToolConfig(
        title: '测试工具',
        description: '这是描述',
        parameters: [],
        returns: ToolReturns(type: 'string', description: '返回字符串'),
        examples: [ToolExample(code: "const r = await test();", comment: '示例')],
      );
      final desc = ToolSchemaBuilder.buildDescription(config);
      expect(desc.contains('这是描述'), true);
      expect(desc.contains('返回字符串'), true);
      expect(desc.contains('await test()'), false);
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

  group('NativeToolAgentService.resolveMethodName 杂质纠错', () {
    final known = {'getNotebooks', 'createNode', 'updateNode'};

    test('提取尾部混入杂质的标识符（模型输出 getNotebooks"> 场景）', () {
      expect(
        NativeToolAgentService.resolveMethodName(known, 'getNotebooks">'),
        'getNotebooks',
      );
      expect(
        NativeToolAgentService.resolveMethodName(known, "createNode'>"),
        'createNode',
      );
      expect(
        NativeToolAgentService.resolveMethodName(known, ' updateNode)'),
        'updateNode',
      );
    });

    test('干净的方法名与无法识别的输入保持原语义', () {
      // 干净且已注册（正常路径不会走到这里，但不应误伤）
      expect(
        NativeToolAgentService.resolveMethodName(known, 'getNotebooks'),
        'getNotebooks',
      );
      // 杂质后的标识符不在注册表中 → null，走原有报错
      expect(
        NativeToolAgentService.resolveMethodName(known, 'getNotebooksX">'),
        isNull,
      );
      // 完全非法输入 → null
      expect(NativeToolAgentService.resolveMethodName(known, '">'), isNull);
      expect(NativeToolAgentService.resolveMethodName(known, ''), isNull);
    });
  });

  group('记忆工具资源契约', () {
    late Map<String, dynamic> memoryTools;
    late List<dynamic> toolIndex;

    setUpAll(() {
      memoryTools = Map<String, dynamic>.from(
        jsonDecode(
          File('lib/plugins/agent_chat/tools/memory.json').readAsStringSync(),
        ) as Map,
      );
      toolIndex = jsonDecode(
        File('lib/plugins/agent_chat/tools/index.json').readAsStringSync(),
      ) as List<dynamic>;
    });

    test('六个记忆工具均已定义并要求显式 memoryId', () {
      const names = {
        'list_memory_keys',
        'search_memory',
        'batch_search_memory',
        'add_memory',
        'update_memory',
        'delete_memory',
      };
      expect(memoryTools.keys.toSet(), containsAll(names));
      for (final name in names) {
        final config = memoryTools[name] as Map<String, dynamic>;
        final parameters = (config['parameters'] as List<dynamic>)
            .map((parameter) => ToolParameter.fromJson(
                  Map<String, dynamic>.from(parameter as Map),
                ))
            .toList();
        final schema = ToolSchemaBuilder.buildSchemaMap(parameters);
        expect(schema['required'], contains('memoryId'), reason: name);
      }
    });

    test('list_memory_keys 的 prefix 参数可选', () {
      final parameters = (memoryTools['list_memory_keys']
              as Map<String, dynamic>)['parameters'] as List<dynamic>;
      final schema = ToolSchemaBuilder.buildSchemaMap(
        parameters
            .map((parameter) => ToolParameter.fromJson(
                  Map<String, dynamic>.from(parameter as Map),
                ))
            .toList(),
      );
      expect(schema['required'], ['memoryId']);
      expect(
        (schema['properties'] as Map).keys,
        containsAll(['memoryId', 'prefix']),
      );
    });

    test('search_memory 和 batch_search_memory 透传 key 约束', () {
      final searchParameters = (memoryTools['search_memory']
              as Map<String, dynamic>)['parameters'] as List<dynamic>;
      final searchSchema = ToolSchemaBuilder.buildSchemaMap(
        searchParameters
            .map((parameter) => ToolParameter.fromJson(
                  Map<String, dynamic>.from(parameter as Map),
                ))
            .toList(),
      );
      expect(searchSchema['required'], ['memoryId', 'key']);
      final key = (searchSchema['properties'] as Map)['key'] as Map;
      expect(key['minLength'], 1);
      expect(key['pattern'], r'^\S+$');

      final batchParameters = (memoryTools['batch_search_memory']
              as Map<String, dynamic>)['parameters'] as List<dynamic>;
      final batchSchema = ToolSchemaBuilder.buildSchemaMap(
        batchParameters
            .map((parameter) => ToolParameter.fromJson(
                  Map<String, dynamic>.from(parameter as Map),
                ))
            .toList(),
      );
      expect(batchSchema['required'], ['memoryId', 'keys']);
      final keys = (batchSchema['properties'] as Map)['keys'] as Map;
      expect(keys['minItems'], 1);
      expect(keys['items'], {
        'type': 'string',
        'description': '',
        'minLength': 1,
        'pattern': r'^\S+$',
      });
    });
    test('写入和查询工具声明后续操作所需的 key 参数', () {
      final searchNames = ((memoryTools['search_memory']
                  as Map<String, dynamic>)['parameters'] as List<dynamic>)
              .cast<Map>()
              .map((p) => p['name'])
              .toSet();
      expect(searchNames, {'memoryId', 'key'});
      for (final name in ['add_memory', 'update_memory', 'delete_memory']) {
        final parameters = (memoryTools[name] as Map<String, dynamic>)['parameters']
            as List<dynamic>;
        final names = parameters.cast<Map>().map((p) => p['name']).toSet();
        expect(names, contains('key'), reason: name);
      }
      for (final name in ['add_memory', 'update_memory']) {
        final parameters = (memoryTools[name] as Map<String, dynamic>)['parameters']
            as List<dynamic>;
        final names = parameters.cast<Map>().map((p) => p['name']).toSet();
        expect(names, contains('value'), reason: name);
        expect(names, isNot(contains('content')), reason: name);
      }
      for (final name in ['update_memory', 'delete_memory']) {
        final parameters = (memoryTools[name] as Map<String, dynamic>)['parameters']
            as List<dynamic>;
        final names = parameters.cast<Map>().map((p) => p['name']).toSet();
        expect(names, isNot(contains('fragmentId')), reason: name);
      }
    });

    test('索引包含六个记忆工具', () {
      final names = toolIndex.map((entry) => (entry as List).first).toSet();
      expect(names, containsAll([
        'memory_list_memory_keys',
        'memory_search_memory',
        'memory_batch_search_memory',
        'memory_add_memory',
        'memory_update_memory',
        'memory_delete_memory',
      ]));
    });
  });

  group('NativeToolAgentService.supports', () {
    test('启用 function calling 的 OpenAI Agent 使用标准工具调用', () {
      final now = DateTime(2026, 1, 1);
      final agent = AIAgent(
        id: 'openai-agent',
        name: 'OpenAI',
        description: '',
        tags: const [],
        serviceProviderId: 'openai',
        baseUrl: 'https://api.openai.com/v1',
        headers: const {'Authorization': 'Bearer test-key'},
        createdAt: now,
        updatedAt: now,
        model: 'gpt-4o-mini',
        enableFunctionCalling: true,
      );

      expect(NativeToolAgentService.instance.supports(agent, true), isTrue);
      expect(NativeToolAgentService.instance.supports(agent, false), isFalse);
      expect(
        NativeToolAgentService.instance.supports(
          agent.copyWith(enableFunctionCalling: false),
          true,
        ),
        isFalse,
      );
    });

    test('Anthropic 自定义 endpoint 使用标准 function calling', () {
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
        isTrue,
      );
      expect(
        NativeToolAgentService.instance.supports(
          agent.copyWith(baseUrl: 'https://api.anthropic.com'),
          true,
        ),
        isTrue,
      );
      expect(
        NativeToolAgentService.instance.supports(
          agent.copyWith(baseUrl: 'https://api.minimaxi.com/anthropic'),
          true,
        ),
        isTrue,
      );
    });

    test('未识别的 API 格式不进入原生工具调用路径', () {
      final agent = AIAgent(
        id: 'unknown-format-agent',
        name: 'Unknown format',
        description: '',
        tags: const [],
        serviceProviderId: 'custom',
        baseUrl: 'https://example.com/v1',
        headers: const {'Authorization': 'Bearer test-key'},
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        model: 'model',
        enableFunctionCalling: true,
        apiFormat: 'unknown',
      );

      expect(NativeToolAgentService.instance.supports(agent, true), isFalse);
    });

    test('独立记忆开启时不依赖通用工具调用或活人感开关', () {
      final agent = AIAgent.fromJson({
        'id': 'memory-agent', 'name': 'Memory', 'description': '',
        'serviceProviderId': 'test', 'baseUrl': 'https://example.com/v1',
        'headers': <String, String>{}, 'model': 'test',
        'enableFunctionCalling': false,
        'alivenessConfig': {
          'enabled': false,
          'memoryEnabled': true,
          'memoryIds': ['memory-library'],
        },
      });
      expect(NativeToolAgentService.instance.supports(agent, false), true);
      expect(NativeToolAgentService.instance.supports(agent, true), true);
      expect(NativeToolAgentService.instance.supports(agent.copyWith(
        alivenessConfig: const AlivenessConfig(memoryEnabled: false),
      ), false), false);
    });

    test('活人感开启时不依赖通用工具调用开关', () {
      final agent = AIAgent(
        id: 'aliveness-agent',
        name: 'Aliveness',
        description: '',
        tags: const [],
        serviceProviderId: 'custom',
        baseUrl: 'https://example.com/v1',
        headers: const {'Authorization': 'Bearer test-key'},
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        model: 'model',
        enableFunctionCalling: false,
        alivenessConfig: const AlivenessConfig(enabled: true),
      );

      expect(NativeToolAgentService.instance.supports(agent, true), isTrue);
      expect(NativeToolAgentService.instance.supports(agent, false), isTrue);
      expect(
        NativeToolAgentService.instance.supports(
          agent.copyWith(
            alivenessConfig: const AlivenessConfig(enabled: false),
          ),
          true,
        ),
        isFalse,
      );
    });
  });
}
