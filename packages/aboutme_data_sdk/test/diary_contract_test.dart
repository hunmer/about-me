import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async { root = await Directory.systemTemp.createTemp('diary_contract_'); data = AboutmeData.local(root.path); });
  tearDown(() async { await data.dispose(); await root.delete(recursive: true); });
  Map value(Map<String, dynamic> result) { expect(result['success'], isTrue, reason: '$result'); return result['data'] as Map; }
  Future<void> fixture(String file, dynamic value) async {
    final target = File('${root.path}/diary/$file');
    await target.parent.create(recursive: true);
    await target.writeAsString(jsonEncode(value));
  }

  test('完整快照超过 100 篇仍包含全部日记；普通列表保持分页', () async {
    final index = <String, dynamic>{};
    for (var i = 0; i < 140; i++) {
      final day = DiaryCodec.formatDate(DateTime(2026, 1, 1 + i));
      await fixture('$day.json', {'date': day, 'content': 'entry', 'title': 'all'});
      index[day] = <String, dynamic>{};
    }
    await fixture('diary_index.json', index);
    final page = value(await data.get('diary', 'getList'));
    expect((page['data'] as List).length, 100);
    expect(page['hasMore'], isTrue);
    final snapshot = value(await data.query('diary', 'getSnapshot'));
    expect(snapshot['total'], 140);
    expect((snapshot['data'] as List).length, 140);
    expect(snapshot['hasMore'], isFalse);
    final watched = await data.diary.watchEntries().firstWhere((s) => s.status == QueryStatus.data);
    expect((watched.result!['data']['data'] as List).length, 140);
  });

  test('旧 ISO 日期、Delta、标签和扩展字段无损；标题 patch 不减少字数，显式 null 清空心情', () async {
    await fixture('diary_index.json', {'2026-01-01': {'legacy': true}});
    await fixture('2026-01-01.json', {
      'date': '2026-01-01T00:00:00.000', 'content': '[{"insert":"中文 abc\\n","attributes":{"bold":true}}]',
      'mood': 'happy', 'tags': ['work'], 'extension': {'x': 1},
    });
    final before = value(await data.get('diary', 'getByDate', {'date': '2026-01-01'}));
    expect(before['date'], '2026-01-01'); expect(before['contentFormat'], 'delta');
    final patched = value(await data.call('diary', 'updateByDate', {'date': '2026-01-01', 'title': 'new', 'mood': null}));
    expect(patched['content'], before['content']); expect(patched['tags'], ['work']); expect(patched['extension'], {'x': 1}); expect(patched['mood'], isNull);
    final stats = value(await data.get('diary', 'getStats'));
    expect(stats['totalWords'], 6); expect(stats['totalEntries'], 1);
    final index = await data.readFile('diary', 'diary_index.json');
    expect(index['totalCharCount'], 6); expect(index['2026-01-01']['contentLength'], 6); expect(index['2026-01-01']['legacy'], isTrue);
    final search = value(await data.get('diary', 'search', {'keyword': 'work'})); expect(search['total'], 1);
    final noise = value(await data.get('diary', 'search', {'keyword': 'attributes'})); expect(noise['total'], 0);
    final dto = DiaryEntryDto.fromJson(Map<String, dynamic>.from(patched));
    expect(dto.toJson()['extension'], {'x': 1}); expect(dto.tags, ['work']);
  });

  test('并发创建与编辑维护索引；旧版本冲突后内容保持不变', () async {
    final other = AboutmeData.local(root.path); addTearDown(other.dispose);
    final results = await Future.wait([for (var i = 1; i <= 20; i++) (i.isEven ? data : other).call('diary', 'create', {'date': '2026-01-${i.toString().padLeft(2, '0')}', 'content': 'abc'})]);
    expect(results.every((r) => r['success'] == true), isTrue);
    expect(value(await data.get('diary', 'getStats'))['totalWords'], 60);
    final snapshot = await data.get('diary', 'getByDate', {'date': '2026-01-01'});
    value(await other.call('diary', 'save', {'date': '2026-01-01', 'content': 'remote'}));
    final stale = await data.call('diary', 'save', {'date': '2026-01-01', 'content': 'stale', 'expectedVersion': snapshot['version']});
    expect(stale['code'], 'CONFLICT');
    expect(value(await data.get('diary', 'getByDate', {'date': '2026-01-01'}))['content'], 'remote');
    value(await data.call('diary', 'deleteByDate', {'date': '2026-01-01'}));
    expect(value(await data.get('diary', 'getStats'))['totalWords'], 57);
  });

  test('并发示例只创建一次；部分已有日记保留，删除示例后不重建', () async {
    final date = DiaryCodec.formatDate(DateTime.now().subtract(const Duration(days: 7)));
    value(await data.call('diary', 'create', {'date': date, 'content': 'keep', 'extension': true}));
    final seeded = await Future.wait([for (var i = 0; i < 5; i++) data.call('diary', 'seedExamples', {'groups': ['entries'], 'templateVersion': 1})]);
    expect(seeded.every((r) => r['success'] == true), isTrue);
    expect(value(await data.get('diary', 'getByDate', {'date': date}))['content'], 'keep');
    final count = value(await data.get('diary', 'getStats'))['totalEntries'] as int;
    value(await data.call('diary', 'deleteByDate', {'date': date}));
    value(await data.call('diary', 'seedExamples', {'groups': ['entries'], 'templateVersion': 1}));
    expect(value(await data.get('diary', 'getStats'))['totalEntries'], count - 1);
  });

  test('无效日期拒绝；损坏索引/日记返回 CORRUPT_DATA，失败不留下部分更新', () async {
    expect((await data.call('diary', 'create', {'date': '2026-02-30', 'content': 'x'}))['code'], 'INVALID_PARAMS');
    expect((await data.call('diary', 'create', {'date': '2026-01-01Tbad', 'content': 'x'}))['code'], 'INVALID_PARAMS');
    await fixture('diary_index.json', {'2026-01-02': {}});
    final result = await data.call('diary', 'create', {'date': '2026-01-01', 'content': 'x'});
    expect(result['code'], 'CORRUPT_DATA'); expect(await data.readFile('diary', '2026-01-01.json'), isNull);
    expect(jsonEncode(await data.readFile('diary', 'diary_index.json')), '{"2026-01-02":{}}');
  });
  test('未来 schema 和错误索引值不被更新覆盖', () async {
    value(await data.call('diary', 'save', {'date': '2026-01-01', 'content': 'keep'}));
    await fixture('diary_index.json', {'2026-01-01': 42});
    expect((await data.call('diary', 'save', {'date': '2026-01-01', 'content': 'bad'}))['code'], 'CORRUPT_DATA');
    expect(value(await data.get('diary', 'getByDate', {'date': '2026-01-01'}))['content'], 'keep');
    await fixture('2026-01-02.json', {'date': '2026-01-02', 'content': 'future', 'schemaVersion': 2});
    expect((await data.call('diary', 'save', {'date': '2026-01-02', 'title': 'bad'}))['code'], 'CORRUPT_DATA');
    expect(jsonDecode(await File('${root.path}/diary/2026-01-02.json').readAsString())['schemaVersion'], 2);
  });
}
