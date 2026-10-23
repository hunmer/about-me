import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

/// agent_chat 外围配置命令：tools/tool_templates/message_details/
/// route_agent_configs/test_runs/preferences 保持旧文件布局。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('agent_chat_periph_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async {
    await data.dispose();
    await root.delete(recursive: true);
  });

  dynamic ok(Map<String, dynamic> r) {
    expect(r['success'], true, reason: '$r');
    return r['data'];
  }

  Future<Map<String, dynamic>> fail(String action, Map<String, dynamic> p) =>
      data.get('agent_chat', action, p);

  Future<void> fixture(String path, dynamic value) async {
    final f = File(root.path + '/' + path);
    await f.parent.create(recursive: true);
    await f.writeAsString(value is String ? value : jsonEncode(value));
  }

  test('tools：旧缩进 JSON 文本可读、读写命令往返、索引与清空', () async {
    // 旧客户端写入的是缩进 JSON 字符串（磁盘为文本），命令读侧解码
    await fixture(
      'agent_chat/tools/todo.json',
      const JsonEncoder.withIndent('  ').convert({
        'todo_create': {'title': '新建任务', 'enabled': true},
      }),
    );

    final plugin = ok(await data.get('agent_chat', 'getToolPlugin', {
      'pluginId': 'todo',
    })) as Map;
    expect(plugin['todo_create']['title'], '新建任务');

    // 不存在的插件返回 null
    expect(
      ok(await data.get('agent_chat', 'getToolPlugin', {'pluginId': 'notes'})),
      isNull,
    );

    // saveToolPlugin 写结构化 Map，重新读回一致
    ok(await data.get('agent_chat', 'saveToolPlugin', {
      'pluginId': 'notes',
      'tools': {
        'query': {'title': '统一查询', 'enabled': true},
      },
    }));
    final saved = ok(await data.get('agent_chat', 'getToolPlugin', {
      'pluginId': 'notes',
    })) as Map;
    expect(saved['query']['enabled'], true);

    // 索引读写（旧格式是 List[List[String]]）
    ok(await data.get('agent_chat', 'saveToolIndexFile', {
      'index': [
        ['todo_create', '新建任务'],
        ['notes_query', '统一查询'],
      ],
    }));
    final index = ok(
      await data.get('agent_chat', 'getToolIndexFile', {}),
    ) as List;
    expect(index.length, 2);
    expect(index.first.first, 'todo_create');

    // 清空：tools/ 下全部文件删除（含旧注入与命令写入的）
    final cleared = ok(
      await data.get('agent_chat', 'clearToolPlugins', {}),
    ) as Map;
    expect(cleared['count'], 3); // todo.json + notes.json + index.json
    expect(
      ok(await data.get('agent_chat', 'getToolPlugin', {'pluginId': 'todo'})),
      isNull,
    );
    expect(ok(await data.get('agent_chat', 'getToolIndexFile', {})), isNull);

    // pluginId 路径穿越拒绝
    final r = await fail('getToolPlugin', {'pluginId': '../diary'});
    expect(r['success'], false);
  });

  test('tool_templates：列表/保存/删除（每模板一文件）', () async {
    await fixture('agent_chat/tool_templates/t1.json', {
      'id': 't1',
      'name': '晨间记录',
      'steps': [],
    });

    final rows = ok(
      await data.get('agent_chat', 'listToolTemplates', {}),
    ) as List;
    expect(rows.length, 1);
    expect(rows.first['name'], '晨间记录');

    ok(await data.get('agent_chat', 'saveToolTemplate', {
      'id': 't2',
      'template': {'id': 't2', 'name': '晚间总结', 'steps': []},
    }));
    final rows2 = ok(
      await data.get('agent_chat', 'listToolTemplates', {}),
    ) as List;
    expect(rows2.length, 2);

    ok(await data.get('agent_chat', 'deleteToolTemplate', {'id': 't1'}));
    final rows3 = ok(
      await data.get('agent_chat', 'listToolTemplates', {}),
    ) as List;
    expect(rows3.length, 1);
    expect(rows3.first['id'], 't2');
  });

  test('message_details：无扩展名单文件读写删', () async {
    await fixture('agent_chat/message_details/m1', {
      'messageId': 'm1',
      'conversationId': 'c1',
      'finalReply': 'ok',
    });

    final detail = ok(await data.get('agent_chat', 'getMessageDetail', {
      'messageId': 'm1',
    })) as Map;
    expect(detail['finalReply'], 'ok');

    ok(await data.get('agent_chat', 'saveMessageDetail', {
      'messageId': 'm2',
      'detail': {'messageId': 'm2', 'finalReply': 'reply2'},
    }));
    expect(
      (ok(await data.get('agent_chat', 'getMessageDetail', {
        'messageId': 'm2',
      })) as Map)['finalReply'],
      'reply2',
    );

    ok(await data.get('agent_chat', 'deleteMessageDetail', {
      'messageId': 'm2',
    }));
    expect(
      ok(await data.get('agent_chat', 'getMessageDetail', {'messageId': 'm2'})),
      isNull,
    );
    // 旧数据仍在
    expect(
      (ok(await data.get('agent_chat', 'getMessageDetail', {
        'messageId': 'm1',
      })) as Map)['conversationId'],
      'c1',
    );
  });

  test('route_agent_configs：单文件 Map 读写、损坏拒绝', () async {
    // 文件缺失返回空对象
    expect(
      ok(await data.get('agent_chat', 'getRouteAgentConfigs', {})),
      isEmpty,
    );

    ok(await data.get('agent_chat', 'saveRouteAgentConfigs', {
      'configs': {
        '/chat': {'agentId': 'a1'},
      },
    }));
    final configs = ok(
      await data.get('agent_chat', 'getRouteAgentConfigs', {}),
    ) as Map;
    expect(configs['/chat']['agentId'], 'a1');

    // 损坏数据拒绝覆盖读
    await fixture('agent_chat/route_agent_configs', [1, 2]);
    final r = await data.get('agent_chat', 'getRouteAgentConfigs', {});
    expect(r['success'], false);
  });

  test('test_runs：报告写入与列表', () async {
    await fixture('agent_chat/test_runs/run_old.json', {
      'runId': 'run_old',
      'results': [],
    });

    ok(await data.get('agent_chat', 'saveTestRun', {
      'runId': 'run_new',
      'report': {
        'runId': 'run_new',
        'results': [
          {'category': '日常', 'question': '你好', 'status': 'passed'},
        ],
      },
    }));

    final runs = ok(await data.get('agent_chat', 'listTestRuns', {})) as List;
    expect(runs.length, 2);
    expect(
      runs.any((r) => r['runId'] == 'run_new'),
      isTrue,
    );
  });

  test('preferences：key 白名单、类型校验、旧值兼容', () async {
    // 旧客户端写入 List（quick_toolbar_actions）与 String（last_category）
    await fixture('agent_chat/quick_toolbar_actions', ['image', 'skill']);
    // 旧客户端对 String 是原样文本写入（非 JSON），读取按无配置处理
    final f = File(root.path + '/agent_chat/suggested_questions_last_category');
    await f.parent.create(recursive: true);
    await f.writeAsString('日常');

    final actions = ok(await data.get('agent_chat', 'getPreference', {
      'key': 'quickToolbarActions',
    })) as List;
    expect(actions, ['image', 'skill']);

    // 旧裸文本文件读取得到 CORRUPT_DATA（客户端按无配置兜底，
    // 与旧 readPathText 失败即 null 一致）
    final raw = await data.get('agent_chat', 'getPreference', {
      'key': 'suggestedQuestionsCategory',
    });
    expect(raw['success'], false);
    expect(raw['code'], 'CORRUPT_DATA');

    // 更新
    ok(await data.get('agent_chat', 'setPreference', {
      'key': 'quickToolbarActions',
      'value': ['image'],
    }));
    expect(
      ok(await data.get('agent_chat', 'getPreference', {
        'key': 'quickToolbarActions',
      })),
      ['image'],
    );
    // setPreference 覆盖后旧裸文本文件被修复为合法 JSON
    ok(await data.get('agent_chat', 'setPreference', {
      'key': 'suggestedQuestionsCategory',
      'value': '日常',
    }));
    expect(
      ok(await data.get('agent_chat', 'getPreference', {
        'key': 'suggestedQuestionsCategory',
      })),
      '日常',
    );

    // 白名单外 key 拒绝
    expect(
      (await data.get('agent_chat', 'getPreference', {
        'key': 'arbitrary',
      }))['success'],
      false,
    );
    // 类型不符拒绝且不写坏旧值
    expect(
      (await data.get('agent_chat', 'setPreference', {
        'key': 'suggestedQuestionsCategory',
        'value': 42,
      }))['success'],
      false,
    );
    expect(
      ok(await data.get('agent_chat', 'getPreference', {
        'key': 'suggestedQuestionsCategory',
      })),
      '日常',
    );
  });
}
