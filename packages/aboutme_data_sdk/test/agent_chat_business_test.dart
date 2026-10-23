import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('agent_chat_sdk_');
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

  Future<void> fixture(String path, dynamic value) async {
    final f = File(root.path + '/' + path);
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(value));
  }

  Map<String, dynamic> messageJson(
    String id,
    String conversationId,
    String timestamp,
  ) => {
    'id': id,
    'conversationId': conversationId,
    'content': 'msg-$id',
    'isUser': true,
    'timestamp': timestamp,
    'tokenCount': 3,
  };

  test(
    'conversations/messages CRUD, saveConversations/saveMessages, config and snapshot',
    () async {
      // 旧客户端顶层 List 格式直接可读
      await fixture('agent_chat/conversations.json', [
        {
          'id': 'c1',
          'title': '旧会话',
          'createdAt': '2026-10-01T00:00:00.000',
          'lastMessageAt': '2026-10-01T00:00:00.000',
        },
      ]);
      await fixture('agent_chat/messages/c1.json', [
        messageJson('m0', 'c1', '2026-10-01T08:00:00.000'),
      ]);

      // conversations CRUD
      ok(
        await data.call('agent_chat', 'create', {
          'id': 'c2',
          'title': '新会话',
          'groups': ['工作'],
          'unreadCount': 2,
        }),
      );
      expect(
        (await data.call('agent_chat', 'create', {
          'id': 'c2',
          'title': '重复',
        }))['code'],
        'CONFLICT',
      );
      expect(
        (await data.call('agent_chat', 'create', {'id': 'x'}))['code'],
        'INVALID_PARAMS',
      );
      expect(
        ok(await data.call('agent_chat', 'update', {'id': 'c1', 'title': '改名'}))[
            'title'],
        '改名',
      );
      expect(
        (await data.call('agent_chat', 'update', {'id': 'nope'}))['code'],
        'NOT_FOUND',
      );
      expect(
        ok(await data.get('agent_chat', 'getById', {'id': 'c2'}))['unreadCount'],
        2,
      );
      expect(
        ((ok(await data.get('agent_chat', 'getList')) as Map)['data'] as List)
            .length,
        2,
      );

      // messages：读取旧数据 + 追加 + 更新 + 删除 + 全量替换
      expect(
        ((ok(
          await data.get('agent_chat', 'getMessages', {'conversationId': 'c1'}),
        ) as Map)['data'] as List)
            .length,
        1,
      );
      final appended = ok(
        await data.call('agent_chat', 'appendMessage', {
          'conversationId': 'c1',
          'content': 'hello',
          'isUser': true,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ) as Map;
      expect(appended['conversationId'], 'c1');
      expect(appended['id'] is String, true);
      expect(
        (await data.call('agent_chat', 'appendMessage', {
          'conversationId': 'c1',
          'id': appended['id'],
          'content': 'dup',
          'isUser': true,
          'timestamp': DateTime.now().toIso8601String(),
        }))['code'],
        'CONFLICT',
      );
      ok(
        await data.call('agent_chat', 'updateMessage', {
          'conversationId': 'c1',
          'messageId': appended['id'],
          'content': 'edited',
          'tokenCount': 9,
        }),
      );
      expect(
        (await data.call('agent_chat', 'updateMessage', {
          'conversationId': 'c1',
          'messageId': 'missing',
          'content': 'x',
        }))['code'],
        'NOT_FOUND',
      );
      ok(
        await data.call('agent_chat', 'deleteMessage', {
          'conversationId': 'c1',
          'messageId': 'm0',
        }),
      );
      expect(
        ((ok(
          await data.get('agent_chat', 'getMessages', {'conversationId': 'c1'}),
        ) as Map)['data'] as List)
            .length,
        1,
      );
      final saved = ok(
        await data.call('agent_chat', 'saveMessages', {
          'conversationId': 'c2',
          'messages': [
            messageJson('n1', 'c2', DateTime.now().toIso8601String()),
            messageJson('n2', 'c2', '2026-01-01T00:00:00.000'),
          ],
        }),
      ) as Map;
      expect(saved['count'], 2);

      // saveConversations 全量替换（客户端全量缓存语义）
      final whole = ok(
        await data.call('agent_chat', 'saveConversations', {
          'conversations': [
            {'id': 'c1', 'title': '旧会话'},
          ],
        }),
      ) as Map;
      expect(whole['count'], 1);
      expect(
        ((ok(await data.get('agent_chat', 'getList')) as Map)['data'] as List)
            .length,
        1,
      );

      // config：无扩展名文件读写
      expect(ok(await data.get('agent_chat', 'getConfig')), {});
      ok(
        await data.call('agent_chat', 'updateConfig', {
          'defaultContextMessageCount': 20,
        }),
      );
      expect(
        ok(await data.get('agent_chat', 'getConfig'))[
            'defaultContextMessageCount'],
        20,
      );

      // stats：今日消息数（追加的消息与 c2/n1 为今日）
      final stats = ok(await data.get('agent_chat', 'getStats')) as Map;
      expect(stats['todayMessageCount'], 2);
      expect(stats['totalMessageCount'], 3);

      // 首写备份：保留原始主数据内容（写操作已发生，备份已生成）
      final backup = jsonDecode(
        await File(root.path + '/agent_chat/migration_v1_backup.json')
            .readAsString(),
      ) as Map;
      expect(backup['schemaVersion'], 1);
      expect((backup['conversations'] as List).first['title'], '旧会话');

      // snapshot 概要
      final snapshot = ok(await data.get('agent_chat', 'getSnapshot')) as Map;
      expect((snapshot['conversations'] as List).length, 1);
      expect((snapshot['messageCounts'] as Map)['c1'], 1);
      expect((snapshot['messageCounts'] as Map)['c2'], 2);
      expect((snapshot['config'] as Map)['defaultContextMessageCount'], 20);

      // delete：会话行 + 消息文件一起删除（c2 行已被整表替换移除）
      expect(
        (await data.call('agent_chat', 'delete', {'id': 'c2'}))['code'],
        'NOT_FOUND',
      );
      ok(await data.call('agent_chat', 'delete', {'id': 'c1'}));
      expect(
        (await data.call('agent_chat', 'delete', {'id': 'c1'}))['code'],
        'NOT_FOUND',
      );
      expect(
        await File(root.path + '/agent_chat/messages/c1.json').exists(),
        false,
      );

      // clearMessages：删除消息文件（与旧客户端 deletePath 一致，幂等）
      ok(
        await data.call('agent_chat', 'clearMessages', {'conversationId': 'c1'}),
      );
      expect(
        await File(root.path + '/agent_chat/messages/c1.json').exists(),
        false,
      );
      ok(
        await data.call('agent_chat', 'clearMessages', {'conversationId': 'c2'}),
      );
      expect(
        await File(root.path + '/agent_chat/messages/c2.json').exists(),
        false,
      );
    },
  );

  test('two SDK instances append messages without losing data', () async {
    ok(
      await data.call('agent_chat', 'create', {
        'id': 'c1',
        'title': '并发会话',
      }),
    );
    final second = AboutmeData.local(root.path);
    try {
      await Future.wait(
        List.generate(20, (i) async {
          ok(
            await (i.isEven ? data : second).call('agent_chat', 'appendMessage', {
              'id': 'm$i',
              'conversationId': 'c1',
              'content': 'msg-$i',
              'isUser': true,
              'timestamp': DateTime.now().toIso8601String(),
              'clientMutationId': 'agent-chat-$i',
            }),
          );
        }),
      );
      expect(
        ((ok(
          await second.get('agent_chat', 'getMessages', {'conversationId': 'c1'}),
        ) as Map)['data'] as List)
            .length,
        20,
      );
    } finally {
      await second.dispose();
    }
  });

  test('corrupt data returns CORRUPT_DATA and files stay untouched', () async {
    await fixture('agent_chat/conversations.json', {'broken': true});
    expect(
      (await data.call('agent_chat', 'create', {'id': 'x', 'title': 't'}))[
          'code'],
      'CORRUPT_DATA',
    );
    expect(
        (await data.get('agent_chat', 'getSnapshot'))['code'], 'CORRUPT_DATA');
    await fixture('agent_chat/messages/c1.json', {'broken': true});
    expect(
      (await data.get('agent_chat', 'getMessages', {'conversationId': 'c1'}))[
          'code'],
      'CORRUPT_DATA',
    );
    expect(
      (await data.call('agent_chat', 'appendMessage', {
        'conversationId': 'c1',
        'content': 'x',
        'isUser': true,
        'timestamp': DateTime.now().toIso8601String(),
      }))['code'],
      'CORRUPT_DATA',
    );
    await fixture('agent_chat/config', 'broken');
    expect(
      (await data.get('agent_chat', 'getConfig'))['code'],
      'CORRUPT_DATA',
    );
    expect(
      jsonDecode(
        await File(root.path + '/agent_chat/conversations.json').readAsString(),
      ),
      {'broken': true},
    );
    expect(
      await File(root.path + '/agent_chat/migration_v1_backup.json').exists(),
      false,
    );
  });
}
