import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/openai/aliveness/models/memory_fragment.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_extraction.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';

MemoryFragment fragment(
  String id, {
  bool self = false,
  String category = 'preference',
}) => MemoryFragment(
  id: id,
  content: '喜欢咖啡 $id',
  tags: ['咖啡'],
  isSelf: self,
  category: category,
);

void main() {
  test('分类索引只返回计数与关键词，不泄漏正文和 ID', () {
    final retrieval = MemoryExtraction([fragment('private-id')]);
    final index = jsonEncode(retrieval.index());
    expect(index, contains('咖啡'));
    expect(index, isNot(contains('喜欢咖啡')));
    expect(index, isNot(contains('private-id')));
  });

  test('按主体分类隔离，未命中不回退无关记忆', () {
    final retrieval = MemoryExtraction([
      fragment('user'),
      fragment('self', self: true),
      fragment('plan', category: 'plan'),
    ])..index();
    final result = retrieval.search({
      'subject': 'user',
      'category': 'preference',
      'query': '咖啡',
    });
    expect((result['memories'] as List).map((f) => f['id']), ['user']);
    expect(retrieval.retrievedIds, {'user'});
    expect(
      retrieval.search({
        'subject': 'user',
        'category': 'preference',
        'query': '完全不相关',
      })['memories'],
      isEmpty,
    );
  });

  test('精确 key 返回归档记录并保留 key/value 元数据，未命中不回退', () {
    final archived = MemoryFragment(
      id: 'archived',
      key: 'user.preference.drink',
      content: '喜欢红茶',
      tags: ['饮品'],
      category: 'preference',
      archived: true,
      revision: 3,
      source: 'extraction',
      confidence: 0.8,
    );
    final other = MemoryFragment(
      id: 'other',
      key: 'user.preference.food',
      content: '喜欢面条',
      tags: ['饮食'],
      category: 'preference',
    );
    final retrieval = MemoryExtraction([archived, other])..index();

    final hit = retrieval.search({
      'subject': 'user',
      'category': 'preference',
      'key': 'user.preference.drink',
    });
    expect(hit['total'], 1);
    expect(
      (hit['memories'] as List).single,
      allOf([
        containsPair('key', 'user.preference.drink'),
        containsPair('value', '喜欢红茶'),
        containsPair('revision', 3),
        containsPair('source', 'extraction'),
        containsPair('confidence', 0.8),
        containsPair('archived', true),
      ]),
    );
    expect(retrieval.retrievedIds, {'archived'});

    final miss = retrieval.search({
      'subject': 'user',
      'category': 'preference',
      'key': 'user.preference.unknown',
      'query': '红茶',
    });
    expect(miss['memories'], isEmpty);
    expect(miss['total'], 0);
  });

  test('检索分页每次最多5条，含归档记录供查重', () {
    final fragments = List.generate(7, (i) => fragment('$i'));
    fragments.first.archived = true;
    final retrieval = MemoryExtraction(fragments)..index();
    final args = {'subject': 'user', 'category': 'preference', 'query': ''};
    final first = retrieval.search(args);
    final second = retrieval.search({...args, 'page': 1});
    expect(first['total'], 7);
    expect(first['hasMore'], true);
    expect((first['memories'] as List).length, 5);
    expect((second['memories'] as List).length, 2);
    expect(second['hasMore'], false);
    expect(retrieval.retrievedIds.length, 7);
  });

  test('写入要求先读取索引并检索同主体目标分类和旧记忆分类', () {
    final retrieval = MemoryExtraction([]);
    final args = {'subject': 'user', 'category': 'preference', 'query': '咖啡'};
    expect(retrieval.search(args), contains('error'));
    expect(retrieval.canWrite('user', 'preference'), false);
    retrieval.index();
    retrieval.search(args);
    expect(retrieval.canWrite('user', 'preference'), false);
    retrieval.search({...args, 'category': 'other'});
    expect(retrieval.canWrite('user', 'preference'), true);
    expect(retrieval.canWrite('self', 'preference'), false);
    expect(retrieval.canWrite('user', 'plan'), false);
  });

  test('旧记忆归入 other，新分类持久化往返兼容', () {
    final old = fragment('old').toJson()..remove('category');
    expect(MemoryFragment.fromJson(old).category, 'other');
    expect(
      MemoryFragment.fromJson(fragment('new').toJson()).category,
      'preference',
    );
  });

  test('本地模拟 API 验证 Agent 实际调用索引与搜索工具，按需回传命中正文', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <Map<String, dynamic>>[];
    final retrieval = MemoryExtraction([fragment('known')]);
    const finalJson = '{"userMemories":[],"selfMemories":[],"openLoops":[]}';
    final handler = server.listen((request) async {
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      requests.add(body);
      final round = requests.length;
      final delta = round <= 3
          ? {
              'role': 'assistant',
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_$round',
                  'type': 'function',
                  'function': {
                    'name': round == 1
                        ? 'list_memory_categories'
                        : 'search_memories',
                    'arguments': round == 1
                        ? '{}'
                        : jsonEncode({
                            'subject': 'user',
                            'category': round == 2 ? 'preference' : 'other',
                            'query': '咖啡',
                          }),
                  },
                },
              ],
            }
          : {'role': 'assistant', 'content': finalJson};
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      request.response.write(
        'data: ${jsonEncode({
          'id': 'response_$round',
          'object': 'chat.completion.chunk',
          'created': 1,
          'model': 'test-model',
          'choices': [
            {'index': 0, 'delta': delta, 'finish_reason': null},
          ],
        })}\n\n',
      );
      request.response.write(
        'data: ${jsonEncode({
          'id': 'response_$round',
          'object': 'chat.completion.chunk',
          'created': 1,
          'model': 'test-model',
          'choices': [
            {'index': 0, 'delta': {}, 'finish_reason': round <= 3 ? 'tool_calls' : 'stop'},
          ],
        })}\n\ndata: [DONE]\n\n',
      );
      await request.response.close();
    });
    addTearDown(handler.cancel);
    final agent = AIAgent.fromJson({
      'id': 'test',
      'name': 'test',
      'description': '',
      'serviceProviderId': 'test',
      'model': 'test-model',
      'baseUrl': 'http://127.0.0.1:${server.port}/v1',
      'headers': {'Authorization': 'Bearer test-key'},
    });
    expect(await retrieval.run(agent, '整理本轮咖啡偏好'), finalJson);
    expect(requests.length, 4);
    expect(jsonEncode(requests[0]['messages']), isNot(contains('喜欢咖啡 known')));
    expect(jsonEncode(requests[1]['messages']), isNot(contains('喜欢咖啡 known')));
    expect(jsonEncode(requests[2]['messages']), contains('喜欢咖啡 known'));
    expect(retrieval.canWrite('user', 'preference'), true);
    expect(retrieval.toolCalls, 3);
  });
}
