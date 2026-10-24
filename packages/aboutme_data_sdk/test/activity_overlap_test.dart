import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  const date = '2026-10-24';
  String time(int hour) => '${date}T${hour.toString().padLeft(2, '0')}:00:00';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('activity_overlap_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async {
    await data.dispose();
    await root.delete(recursive: true);
  });

  Future<Map> create(String id, int start, int end) async {
    final result = await data.call('activity', 'create', {
      'id': id,
      'title': id,
      'startTime': time(start),
      'endTime': time(end),
      'tags': ['tag'],
      'mood': '😊',
      'description': '保留内容',
    });
    expect(result['success'], isTrue, reason: '$result');
    return result['data'] as Map;
  }

  Future<List<Map>> rows() async {
    final result = await data.get('activity', 'getList', {'date': date});
    expect(result['success'], isTrue, reason: '$result');
    return (result['data']['data'] as List).cast<Map>();
  }

  for (final scenario in [
    (name: '完全重合', start: 9, end: 12, remaining: <List<int>>[]),
    (
      name: '中间覆盖拆成两段',
      start: 10,
      end: 11,
      remaining: [
        [9, 10],
        [11, 12],
      ],
    ),
    (
      name: '覆盖左侧',
      start: 8,
      end: 10,
      remaining: [
        [10, 12],
      ],
    ),
    (
      name: '覆盖右侧',
      start: 11,
      end: 13,
      remaining: [
        [9, 11],
      ],
    ),
    (name: '全部覆盖', start: 8, end: 13, remaining: <List<int>>[]),
    (
      name: '边界相接',
      start: 12,
      end: 13,
      remaining: [
        [9, 12],
      ],
    ),
  ]) {
    test('创建活动${scenario.name}：新活动优先，保留旧活动剩余时间及属性', () async {
      final old = await create('old', 9, 12);
      await create('new', scenario.start, scenario.end);
      final items = await rows();
      final remaining = items.where((a) => a['title'] == 'old').toList();
      expect(items.length, scenario.remaining.length + 1);
      expect(items.where((a) => a['id'] == 'new').length, 1);
      expect(items.map((a) => a['id']).toSet().length, items.length);
      expect(
        remaining.map(
          (a) => [
            DateTime.parse(a['startTime']).hour,
            DateTime.parse(a['endTime']).hour,
          ],
        ),
        scenario.remaining,
      );
      for (final item in remaining) {
        expect(item['tags'], ['tag']);
        expect(item['mood'], '😊');
        expect(item['description'], '保留内容');
        expect(item['createdAt'], old['createdAt']);
      }
    });
  }

  test('一次创建处理多个重叠活动并保留无关活动', () async {
    await create('first', 8, 10);
    await create('second', 10, 12);
    await create('third', 12, 14);
    final untouched = await create('untouched', 15, 16);
    await create('new', 9, 13);
    final items = await rows();
    expect(items.map((a) => a['id']), ['first', 'new', 'third', 'untouched']);
    expect(items.first['endTime'], time(9));
    expect(items[2]['startTime'], time(13));
    expect(items.last, untouched);
  });

  test('并发创建完全相同时间段只保留一条活动', () async {
    await Future.wait([create('first', 9, 10), create('second', 9, 10)]);
    expect(await rows(), hasLength(1));
  });

  test('无效时间段创建失败，不修改已有活动', () async {
    await create('old', 9, 12);
    final before = await rows();
    for (final end in [9, 8]) {
      final result = await data.call('activity', 'create', {
        'title': 'invalid',
        'startTime': time(9),
        'endTime': time(end),
      });
      expect(result['success'], isFalse);
      expect(await rows(), before);
    }
  });
}
