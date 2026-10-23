import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async { root = await Directory.systemTemp.createTemp('chat_support_'); data = AboutmeData.local(root.path); });
  tearDown(() async { await data.dispose(); await root.delete(recursive: true); });
  Map value(Map<String, dynamic> result) { expect(result['success'], isTrue, reason: '$result'); return result['data'] as Map; }
  Future<void> createRoot() async {
    value(await data.call('chat', 'create', {'id': 'c'}));
    value(await data.call('chat', 'sendMessage', {'id': 'root', 'channelId': 'c', 'content': 'root'}));
    value(await data.call('chat', 'ensureThread', {'channelId': 'c', 'rootMessageId': 'root', 'agentId': 'agent'}));
  }
  test('不同设置字段并发 patch 保留；用户按 ID 更新', () async {
    await Future.wait([data.call('chat', 'updateSettings', {'patch': {'sound': false}}), data.call('chat', 'updateSettings', {'patch': {'avatar': false}})]);
    expect(value(await data.get('chat', 'getSettings')), {'sound': false, 'avatar': false});
    await Future.wait([for (final id in ['a', 'b']) data.call('chat', 'updateUser', {'id': id, 'username': id})]);
    expect((value(await data.get('chat', 'getUsers'))['users'] as List).length, 2);
  });
  test('AI 线程并发追加与重试不会覆盖；批删根消息在同一事务清理线程', () async {
    await createRoot();
    final params = {'channelId': 'c', 'rootMessageId': 'root', 'message': {'id': 'a', 'content': 'reply'}, 'clientMutationId': 'thread-a'};
    value(await data.call('chat', 'appendThreadMessage', params));
    await data.call('chat', 'appendThreadMessage', params);
    await Future.wait([for (var i = 0; i < 10; i++) data.call('chat', 'appendThreadMessage', {'channelId': 'c', 'rootMessageId': 'root', 'message': {'id': 'r-$i', 'content': '$i'}})]);
    var thread = value(await data.get('chat', 'getThreads', {'channelId': 'c'}));
    expect((thread['threads']['root']['messages'] as List).length, 11);
    value(await data.call('chat', 'deleteMessages', {'channelId': 'c', 'messageIds': ['root']}));
    thread = value(await data.get('chat', 'getThreads', {'channelId': 'c'})); expect(thread['threads'], isEmpty);
    expect(value(await data.get('chat', 'getById', {'id': 'c'}))['messageCount'], 0);
    expect((await data.call('chat', 'ensureThread', {'channelId': 'c', 'rootMessageId': 'root', 'agentId': 'agent'}))['code'], 'NOT_FOUND');
  });
  test('服务端 seed 保留用户频道与消息；并发/重复 seed 幂等', () async {
    value(await data.call('chat', 'create', {'id': 'default', 'title': 'keep'}));
    value(await data.call('chat', 'sendMessage', {'channelId': 'default', 'content': 'keep'}));
    await Future.wait([for (var i = 0; i < 4; i++) data.call('chat', 'seedExamples', {'groups': ['channels'], 'templateVersion': 1})]);
    expect(value(await data.get('chat', 'getById', {'id': 'default'}))['title'], 'keep');
    expect(value(await data.get('chat', 'getMessages', {'channelId': 'default'}))['total'], 1);
    final count = value(await data.get('chat', 'getList'))['total'];
    value(await data.call('chat', 'delete', {'id': 'default'}));
    value(await data.call('chat', 'seedExamples', {'groups': ['channels'], 'templateVersion': 1}));
    expect(value(await data.get('chat', 'getList'))['total'], (count as int) - 1);
  });
  test('游标解码的结构/字段错误均返回 INVALID_PARAMS', () async {
    value(await data.call('chat', 'create', {'id': 'c'}));
    for (final cursor in [null, {}, [1, 2], ['bad-date', 'id']]) {
      final encoded = base64Url.encode(utf8.encode(jsonEncode(cursor)));
      final result = await data.get('chat', 'getMessages', {'channelId': 'c', 'limit': 2, 'before': encoded});
      expect(result['code'], 'INVALID_PARAMS', reason: '$result');
    }
  });
  test('非法设置/用户/线程参数不会提交；损坏线程阻止根消息级联删除', () async {
    await createRoot();
    final before = await data.get('chat', 'getThreads', {'channelId': 'c'});
    for (final request in <(String, Map<String, dynamic>)>[
      ('updateSettings', {'patch': {'showAvatarInChat': 'true'}}),
      ('updateTimelineState', {'patch': {'filterData': {'selectedChannelIds': [1]}}}),
      ('updateUser', {'id': 'u', 'username': 1}),
      ('appendThreadMessage', {'channelId': 'c', 'rootMessageId': 'root', 'message': {'id': 'bad', 'content': 'x', 'audioDurationSec': '1'}}),
    ]) {
      expect((await data.call('chat', request.$1, request.$2))['code'], 'INVALID_PARAMS');
    }
    expect((await data.get('chat', 'getThreads', {'channelId': 'c'}))['version'], before['version']);
    value(await data.call('chat', 'appendThreadMessage', {'channelId': 'c', 'rootMessageId': 'root', 'message': {'id': 'valid', 'content': 'x'}}));
    expect((await data.call('chat', 'updateThreadMessage', {'channelId': 'c', 'rootMessageId': 'root', 'messageId': 'valid', 'patch': {'content': null}}))['code'], 'INVALID_PARAMS');
    final file = File('${root.path}/chat/ai_threads/c.json');
    const broken = '{"threads":{"root":{"rootMessageId":"root","channelId":"c","messages":[42]}}}';
    await file.writeAsString(broken);
    expect((await data.get('chat', 'getThreads', {'channelId': 'c'}))['code'], 'CORRUPT_DATA');
    expect((await data.call('chat', 'deleteMessages', {'channelId': 'c', 'messageIds': ['root']}))['code'], 'CORRUPT_DATA');
    expect(await file.readAsString(), broken);
    expect(value(await data.get('chat', 'getMessages', {'channelId': 'c'}))['total'], 1);
  });
  test('损坏用户和设置拒绝读取/修改；时间线分组 patch 保留并发字段', () async {
    await Future.wait([
      data.call('chat', 'updateTimelineState', {'patch': {'filterData': {'isAI': true}}}),
      data.call('chat', 'updateTimelineState', {'patch': {'filterData': {'selectedChannelIds': ['c']}}}),
    ]);
    expect(value(await data.get('chat', 'getTimelineState'))['filterData'], {'isAI': true, 'selectedChannelIds': ['c']});
    for (final fixture in <(String, String, String, Map<String, dynamic>)>[
      ('users.json', '{"users":[42]}', 'updateUser', {'id': 'u', 'username': 'valid'}),
      ('settings.json', '{"showAvatarInChat":42}', 'updateSettings', {'patch': {'playSoundOnSend': true}}),
    ]) {
      final file = File('${root.path}/chat/${fixture.$1}');
      await file.writeAsString(fixture.$2);
      expect((await data.call('chat', fixture.$3, fixture.$4))['code'], 'CORRUPT_DATA');
      expect(await file.readAsString(), fixture.$2);
    }
  });
}
