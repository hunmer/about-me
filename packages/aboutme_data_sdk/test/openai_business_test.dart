import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

/// openai 域文件层命令：保持旧客户端 openai/ 分区文件布局。
/// getAgents 缺失返回 null（客户端按空对象兜底，对齐旧 readPath 语义）；
/// 损坏数据返回 CORRUPT_DATA。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('openai_business_');
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
      data.get('openai', action, p);

  Future<void> fixture(String path, dynamic value) async {
    final f = File(root.path + '/' + path);
    await f.parent.create(recursive: true);
    await f.writeAsString(value is String ? value : jsonEncode(value));
  }

  test('agents/providers/presets：旧文件 fixture 兼容、命令往返、损坏拒绝', () async {
    // 旧客户端写入的文件（缩进 JSON 文本），命令读侧直接解码
    await fixture('openai/agents.json', {
      'agents': [
        {'id': 'a1', 'name': '助手一', 'model': 'gpt-4o-mini'},
      ],
    });
    await fixture('openai/providers.json', {
      'providers': [
        {'id': 'ollama', 'label': 'Ollama', 'baseUrl': 'http://localhost:11434'},
      ],
    });

    final agents = ok(await data.get('openai', 'getAgents', {})) as Map;
    expect(agents['agents'].first['name'], '助手一');

    final providers = ok(await data.get('openai', 'getProviders', {})) as Map;
    expect(providers['providers'].first['id'], 'ollama');

    // 缺失文件返回 null（客户端按空对象处理）
    expect(ok(await data.get('openai', 'getPresets', {})), isNull);

    // 整文件写（保持 {xxx:[...]} 顶层结构）后往返一致
    ok(
      await data.call('openai', 'saveAgents', {
        'agents': {
          'agents': [
            {'id': 'a2', 'name': '助手二'},
            {'id': 'a3', 'name': '助手三'},
          ],
        },
      }),
    );
    final agents2 = ok(await data.get('openai', 'getAgents', {})) as Map;
    expect((agents2['agents'] as List).length, 2);
    // 直接覆盖旧 fixture 文件
    expect(
      File(root.path + '/openai/agents.json').existsSync(),
      isTrue,
    );

    ok(
      await data.call('openai', 'savePresets', {
        'presets': {
          'presets': [
            {'id': 'p1', 'name': '通用对话'},
          ],
        },
      }),
    );
    final presets = ok(await data.get('openai', 'getPresets', {})) as Map;
    expect(presets['presets'].first['id'], 'p1');

    // 损坏（顶层非对象）拒绝读
    await fixture('openai/providers.json', [1, 2]);
    expect((await fail('getProviders', {}))['success'], false);
    // 缺参/参数非对象拒绝写
    expect((await fail('saveAgents', {'agents': 'x'}))['success'], false);
  });

  test('aliveness：各 kind 读写、全局文档、路径穿越与未知 kind 拒绝', () async {
    // per-agent 各 kind
    const perAgent = {
      'state': 'openai/aliveness/ag1/state.json',
      'stats': 'openai/aliveness/ag1/stats.json',
      'fragments': 'openai/aliveness/ag1/memory/fragments.json',
      'openLoops': 'openai/aliveness/ag1/memory/open_loops.json',
      'schedule': 'openai/aliveness/ag1/schedule.json',
    };
    for (final entry in perAgent.entries) {
      expect(
        ok(await data.get('openai', 'alivenessGetDoc', {
          'agentId': 'ag1',
          'kind': entry.key,
        })),
        isNull,
      );
      ok(
        await data.call('openai', 'alivenessSetDoc', {
          'agentId': 'ag1',
          'kind': entry.key,
          'doc': {'v': entry.key},
        }),
      );
      final doc = ok(await data.get('openai', 'alivenessGetDoc', {
        'agentId': 'ag1',
        'kind': entry.key,
      })) as Map;
      expect(doc['v'], entry.key);
      expect(File(root.path + '/${entry.value}').existsSync(), isTrue,
          reason: entry.value);
    }

    // 全局文档（无 agentId）
    for (final kind in ['memoryExtraction', 'settings']) {
      ok(
        await data.call('openai', 'alivenessSetDoc', {
          'kind': kind,
          'doc': {'k': kind},
        }),
      );
      expect(
        (ok(await data.get('openai', 'alivenessGetDoc', {'kind': kind}))
                as Map)['k'],
        kind,
      );
    }

    // 旧 fixture 直读
    await fixture('openai/aliveness/ag2/state.json', {'mood': 'calm'});
    expect(
      (ok(await data.get('openai', 'alivenessGetDoc', {
        'agentId': 'ag2',
        'kind': 'state',
      })) as Map)['mood'],
      'calm',
    );

    // 未知 kind / 路径穿越 agentId / per-agent 缺 agentId 拒绝
    expect(
      (await fail('alivenessGetDoc', {'kind': 'arbitrary'}))['success'],
      false,
    );
    expect(
      (await fail('alivenessGetDoc', {
        'agentId': '../x',
        'kind': 'state',
      }))['success'],
      false,
    );
    expect(
      (await fail('alivenessSetDoc', {'kind': 'state', 'doc': {}}))['success'],
      false,
    );
    expect(
      (await fail('alivenessGetDoc', {'agentId': 'a/b', 'kind': 'stats'}))[
          'success'],
      false,
    );
  });

  test('aliveness 独立 memoryId 库：专用 kind 隔离且禁止隐式写入', () async {
    const firstId = 'memory-one';
    const secondId = 'memory-two';

    // 专用 kind 必须使用 memoryId，不能复用 agentId 或省略 ID。
    expect(
      (await fail('alivenessGetDoc', {
        'kind': 'memory_library',
        'agentId': 'agent-1',
      }))['success'],
      false,
    );
    expect(
      (await fail('alivenessSetDoc', {
        'kind': 'memory_library',
        'doc': {'value': 'no-id'},
      }))['success'],
      false,
    );
    expect(
      (await fail('alivenessSetDoc', {
        'kind': 'memory_library',
        'memoryId': '../escape',
        'doc': {'value': 'invalid-id'},
      }))['success'],
      false,
    );

    ok(
      await data.call('openai', 'alivenessSetDoc', {
        'kind': 'memory_libraries',
        'doc': {
          'libraries': [
            {'id': firstId, 'name': '第一库'},
            {'id': secondId, 'name': '第二库'},
          ],
        },
      }),
    );
    final libraries =
        ok(
              await data.get('openai', 'alivenessGetDoc', {
                'kind': 'memory_libraries',
              }),
            )
            as Map;
    expect((libraries['libraries'] as List).length, 2);
    for (final id in [firstId, secondId]) {
      expect(
        ok(
          await data.get('openai', 'alivenessGetDoc', {
            'memoryId': id,
            'kind': 'memory_library',
          }),
        ),
        isNull,
      );
      ok(
        await data.call('openai', 'alivenessSetDoc', {
          'memoryId': id,
          'kind': 'memory_library',
          'doc': {'value': id},
        }),
      );
      ok(
        await data.call('openai', 'alivenessSetDoc', {
          'memoryId': id,
          'kind': 'memory_library_loops',
          'doc': {'loop': id},
        }),
      );
    }

    expect(
      (ok(
            await data.get('openai', 'alivenessGetDoc', {
              'memoryId': firstId,
              'kind': 'memory_library',
            }),
          )
          as Map)['value'],
      firstId,
    );
    expect(
      (ok(
            await data.get('openai', 'alivenessGetDoc', {
              'memoryId': secondId,
              'kind': 'memory_library',
            }),
          )
          as Map)['value'],
      secondId,
    );
    expect(
      File(
        root.path + '/openai/aliveness/memory_libraries/$firstId/memory.json',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        root.path +
            '/openai/aliveness/memory_libraries/$firstId/open_loops.json',
      ).existsSync(),
      isTrue,
    );
  });

  test('aliveness decisions：.log 扩展名 JSON 读写、滚动留在客户端', () async {
    expect(
      ok(await data.get('openai', 'alivenessGetDecisions', {'agentId': 'ag1'})),
      isNull,
    );

    // 客户端滚动截断后全量写回（命令不感知条数上限）
    final logs = List.generate(
      200,
      (i) => {'ts': '2026-01-01T00:00:0${i % 10}Z', 'step': 'step$i'},
    );
    ok(
      await data.call('openai', 'alivenessSaveDecisions', {
        'agentId': 'ag1',
        'logs': {'logs': logs},
      }),
    );
    final doc = ok(
      await data.get('openai', 'alivenessGetDecisions', {'agentId': 'ag1'}),
    ) as Map;
    expect((doc['logs'] as List).length, 200);
    expect(File(root.path + '/openai/aliveness/ag1/decisions.log').existsSync(),
        isTrue);

    // 损坏拒绝 + agentId 校验
    await fixture('openai/aliveness/ag3/decisions.log', {'logs': 'not-a-list'});
    // 内容是合法 JSON 对象，读侧返回原样（行结构校验在客户端）
    expect(
      (ok(await data.get('openai', 'alivenessGetDecisions', {
        'agentId': 'ag3',
      })) as Map)['logs'],
      'not-a-list',
    );
    expect(
      (await fail('alivenessGetDecisions', {'agentId': '../x'}))['success'],
      false,
    );
  });

  test('moments：posts / ui_state / profile_bg / assets 四类', () async {
    await fixture('openai/moments/posts.json', {
      'posts': [
        {'id': 'p1', 'text': '今天天气不错'},
      ],
    });

    final posts = ok(await data.get('openai', 'getPosts', {})) as Map;
    expect(posts['posts'].first['id'], 'p1');

    ok(
      await data.call('openai', 'savePosts', {
        'posts': {'posts': []},
      }),
    );
    expect(
      (ok(await data.get('openai', 'getPosts', {})) as Map)['posts'],
      isEmpty,
    );

    // UI 偏好
    expect(ok(await data.get('openai', 'getMomentsUiState', {})), isNull);
    ok(
      await data.call('openai', 'saveMomentsUiState', {
        'uiState': {'seenAuthors': ['ag1'], 'savedPosts': ['p1']},
      }),
    );
    final ui = ok(await data.get('openai', 'getMomentsUiState', {})) as Map;
    expect(ui['seenAuthors'], ['ag1']);

    // 背景映射（authorId -> path）
    ok(
      await data.call('openai', 'saveProfileBg', {
        'backgrounds': {'ag1': './openai/moments/images/bg.png'},
      }),
    );
    final bg = ok(await data.get('openai', 'getProfileBg', {})) as Map;
    expect(bg['ag1'], './openai/moments/images/bg.png');

    // 资产图索引（per-agent）
    expect(
      ok(await data.get('openai', 'getAssets', {'agentId': 'ag1'})),
      isNull,
    );
    ok(
      await data.call('openai', 'saveAssets', {
        'agentId': 'ag1',
        'assets': {
          'assets': [
            {'id': 'as1', 'name': '三视图'},
          ],
        },
      }),
    );
    final assets = ok(
      await data.get('openai', 'getAssets', {'agentId': 'ag1'}),
    ) as Map;
    expect(assets['assets'].first['name'], '三视图');
    expect(
      File(root.path + '/openai/moments/ag1/assets.json').existsSync(),
      isTrue,
    );

    // agentId 路径穿越拒绝
    expect(
      (await fail('getAssets', {'agentId': '../x'}))['success'],
      false,
    );
  });

  test('topics：合集 / 合集 agent 读写删 + 遗留文件删除', () async {
    await fixture('openai/topic_collections/daily.json', {
      'id': 'daily',
      'name': '日常',
      'version': 2,
    });
    await fixture('openai/topic_agents_daily.json', {
      'agents': [
        {'id': 'builtin_topic_daily', 'name': '日常'},
      ],
    });
    await fixture('openai/topic_collections.json', {'legacy': true});

    // 合集
    final c = ok(
      await data.get('openai', 'getTopicCollection', {'id': 'daily'}),
    ) as Map;
    expect(c['version'], 2);
    expect(ok(await data.get('openai', 'getTopicCollection', {'id': 'none'})),
        isNull);
    ok(
      await data.call('openai', 'saveTopicCollection', {
        'id': 'night',
        'collection': {'id': 'night', 'name': '晚间', 'version': 1},
      }),
    );
    expect(
      (ok(await data.get('openai', 'getTopicCollection', {'id': 'night'}))
              as Map)['name'],
      '晚间',
    );
    expect(
      (ok(await data.call('openai', 'deleteTopicCollection', {'id': 'night'}))
              as Map)['deleted'],
      true,
    );
    expect(ok(await data.get('openai', 'getTopicCollection', {'id': 'night'})),
        isNull);

    // 合集 agent（extra storage）
    final ta = ok(
      await data.get('openai', 'getTopicAgents', {'collectionId': 'daily'}),
    ) as Map;
    expect(ta['agents'].first['id'], 'builtin_topic_daily');
    ok(
      await data.call('openai', 'saveTopicAgents', {
        'collectionId': 'night',
        'agents': {
          'agents': [
            {'id': 'builtin_topic_night'},
          ],
        },
      }),
    );
    expect(
      (ok(await data.get('openai', 'getTopicAgents', {'collectionId': 'night'}))
              as Map)['agents']
          .length,
      1,
    );
    expect(
      (ok(await data.call('openai', 'deleteTopicAgents', {
        'collectionId': 'night',
      })) as Map)['deleted'],
      true,
    );
    expect(
      File(root.path + '/openai/topic_agents_night.json').existsSync(),
      isFalse,
    );

    // 遗留文件删除：存在返回 true，再次调用（不存在）返回 false 不报错
    expect(
      (ok(await data.call('openai', 'deleteLegacyTopicCollections', {}))
              as Map)['deleted'],
      true,
    );
    expect(
      (ok(await data.call('openai', 'deleteLegacyTopicCollections', {}))
              as Map)['deleted'],
      false,
    );
    // 其余数据不受影响
    expect(
      (ok(await data.get('openai', 'getTopicCollection', {'id': 'daily'}))
              as Map)['name'],
      '日常',
    );

    // id 路径穿越拒绝
    expect(
      (await fail('getTopicCollection', {'id': '../x'}))['success'],
      false,
    );
    expect(
      (await fail('getTopicAgents', {'collectionId': 'a/b'}))['success'],
      false,
    );
  });
}
