import 'dart:convert';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/agent_chat/services/conversation_service.dart';
import 'package:aboutme/plugins/diary/sample_data.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/diary/diary_plugin.dart';
import 'package:shared_models/shared_models.dart' show DiaryCodec;
import 'package:aboutme/plugins/habits/controllers/skill_controller.dart';
import 'package:aboutme/plugins/nodes/controllers/nodes_controller.dart';
import 'package:aboutme/plugins/notes/controllers/notes_controller.dart';
import 'package:aboutme/plugins/activity/services/activity_service.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPersistence implements PluginPersistence {
  _MemoryPersistence(this.files);
  final Map<String, dynamic> files;
  @override
  String get identity => 'sample-http-test';
  @override
  Future<String?> read(String path) async => files.containsKey(path) ? jsonEncode(files[path]) : null;
  @override
  Future<void> write(String path, String content) async { files[path] = jsonDecode(content); }
  @override
  Future<bool> remove(String path) async => files.remove(path) != null;
  @override
  Future<List<String>> keys(String prefix) async => files.keys.where((key) => key.startsWith(prefix)).toList();
}

void main() {
  late HttpServer server;
  final files = <String, dynamic>{};
  var businessOffline = false;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      const prefix = '/api/v1/storage/files/';
      final path = request.uri.path;
      if (path.startsWith('/api/v1/plugins/')) {
        if (businessOffline) {
          request.response.statusCode = 503;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'success': false, 'code': 'OFFLINE', 'error': 'test offline'}));
          await request.response.close();
          return;
        }
        final body = await utf8.decoder.bind(request).join();
        final result = await PluginInvoker().invoke(PersistentPluginBackend(_MemoryPersistence(files)), request.method, path,
          query: {for (final entry in request.uri.queryParameters.entries) entry.key: jsonDecode(entry.value)},
          body: body.isEmpty ? null : jsonDecode(body));
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(result));
      } else if (path.endsWith('/health')) {
        request.response.write('{}');
      } else if (path.startsWith(prefix)) {
        final key = path.substring(prefix.length);
        if (request.method == 'PUT') {
          files[key] = jsonDecode(await utf8.decoder.bind(request).join());
          request.response.headers.set('etag', '"test-version"');
          request.response.write('{}');
        } else if (files.containsKey(key)) {
          request.response.headers.set('etag', '"test-version"');
          request.response.write(jsonEncode(files[key]));
        } else {
          request.response.statusCode = 404;
        }
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    globalStorage = StorageManager(
      storage: HttpStorage(
        serverUrl: 'http://127.0.0.1:${server.port}',
        authType: StorageAuthType.apiKey,
        credential: 'test',
      ),
    );
    await AboutmeDataService.instance.initialize();
    expect(AboutmeDataService.instance.isRemote, isTrue);
  });

  tearDownAll(() => server.close(force: true));
  setUp(() { files.clear(); businessOffline = false; });

  test('日记：完整快照和搜索不受列表默认 100 篇分页限制', () async {
    final now = DateTime.now();
    final index = <String, dynamic>{};
    for (var i = 0; i < 140; i++) {
      final date = DiaryCodec.formatDate(DateTime(now.year, now.month, now.day - i));
      files['diary/$date.json'] = {'date': date, 'content': 'history', 'title': 'snapshot'};
      index[date] = <String, dynamic>{};
    }
    files['diary/diary_index.json'] = index;
    expect((await DiaryUtils.loadDiaryEntries()).length, 140);
    expect((await DiaryUtils.searchDiaryEntries('snapshot')).length, 140);
    final paginated = await AboutmeDataService.instance.get('diary', 'getList');
    expect(paginated['data']['data'].length, 100);
    expect(paginated['data']['hasMore'], isTrue);
  });

  test('日记：离线统计抛错、保留上次快照，重试后清除错误', () async {
    final plugin = DiaryPlugin();
    final date = DiaryCodec.formatDate(DateTime.now());
    files['diary/$date.json'] = {'date': date, 'content': '[{"insert":"中文 abc\\n"}]'};
    files['diary/diary_index.json'] = {date: <String, dynamic>{}};
    expect(await plugin.getMonthWordCount(), 6);
    expect(plugin.hasQuerySnapshot, isTrue);
    businessOffline = true;
    await expectLater(plugin.getMonthWordCount(), throwsA(anything));
    await expectLater(plugin.getMonthProgress(), throwsA(anything));
    await expectLater(plugin.getMonthlyDiaryEntries(), throwsA(anything));
    expect(plugin.queryError, isNotNull);
    expect(plugin.getMonthWordCountSync(), 6);
    expect(plugin.getMonthlyDiaryEntriesSync().length, 1);
    final firstLoad = DiaryPlugin();
    await expectLater(firstLoad.getTodayWordCount(), throwsA(anything));
    expect(firstLoad.hasQuerySnapshot, isFalse);
    expect(firstLoad.queryError, isNotNull);
    businessOffline = false;
    expect(await plugin.getMonthWordCount(), 6);
    expect(plugin.queryError, isNull);
  });

  test('日记：空后端创建示例、索引，重新加载及重复执行保留已有数据', () async {
    await DiaryUtils.createSampleEntries();
    final index = files['diary/diary_index.json'] as Map;
    final samples = DiarySampleData.getSampleDiaryEntries();
    final dates = index.keys.where((key) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key as String)).toList();
    expect(index['entryCount'], samples.length);
    expect(dates.length, samples.length);
    for (final date in dates) {
      expect(files['diary/$date.json'], isNotNull);
    }
    final loaded = await DiaryUtils.loadDiaryEntries();
    expect(
      loaded.values.map((e) => e.title),
      unorderedEquals(samples.map((e) => e.title)),
    );
    final date = dates.first;
    files['diary/$date.json']['title'] = '用户修改的日记';
    await DiaryUtils.createSampleEntries();
    expect(files['diary/$date.json']['title'], '用户修改的日记');
  });


  test('日记：UI 保存与远端并发写入、版本冲突及消息订阅', () async {
    await DiaryUtils.saveDiaryEntry(DateTime(2026, 1, 1), 'original', title: 'title', tags: ['tag']);
    final snapshot = await DiaryUtils.loadDiarySnapshot(DateTime(2026, 1, 1));
    final changed = await AboutmeDataService.instance.call('diary', 'updateByDate', {'date': '2026-01-01', 'content': 'remote'});
    expect(changed['success'], isTrue);
    await expectLater(DiaryUtils.saveDiaryEntry(DateTime(2026, 1, 1), 'stale', expectedVersion: snapshot.version), throwsA(isA<QueryFailure>()));
    final entry = await DiaryUtils.loadDiaryEntry(DateTime(2026, 1, 1));
    expect(entry!.content, 'remote'); expect(entry.tags, ['tag']);
    expect((await DiaryUtils.getDiaryStats())['totalCharCount'], 6);
    final watched = DiaryUtils.watchEntries().firstWhere((entries) => entries.length == 2);
    await DiaryUtils.saveDiaryEntry(DateTime(2026, 1, 2), 'new');
    expect((await watched).length, 2);
  });

  test('智能聊天：空后端创建示例会话及消息', () async {
    final service = ConversationService(storage: globalStorage);
    addTearDown(service.dispose);
    await service.loadSampleData();
    final conversations = files['agent_chat/conversations.json'] as List;
    expect(conversations, isNotEmpty);
    for (final conversation in conversations) {
      expect(
        files['agent_chat/messages/${conversation['id']}.json'],
        isA<List>(),
      );
    }
  });

  test('习惯：空后端创建示例技能', () async {
    final controller = SkillController(globalStorage);
    await controller.loadSkills();
    await controller.createDefaultSkills();
    expect(files['habits/skills.json'], isNotEmpty);
  });

  test('节点笔记：空后端创建示例笔记本', () async {
    final controller = NodesController(globalStorage);
    addTearDown(controller.dispose);
    await controller.reloadData();
    await controller.loadSampleData();
    expect(files['nodes/nodes_notebooks.json']['notebooks'], isNotEmpty);
  });

  test('笔记：空后端创建示例文件夹', () async {
    final controller = NotesController(globalStorage);
    await controller.loadSampleFolders();
    expect(files['notes/folders.json'], isNotEmpty);
  });

  test('活动：REST PUT 数值 mood 后仍能加载当日全部记录', () async {
    final today = DateTime.now();
    final date = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final data = AboutmeDataService.instance;
    for (final id in ['updated', 'unchanged']) {
      final result = await data.call('activity', 'create', {
        'id': id,
        'title': id,
        'startTime': '${date}T${id == 'updated' ? '10' : '12'}:00:00',
        'endTime': '${date}T${id == 'updated' ? '11' : '13'}:00:00',
      });
      expect(result['success'], isTrue);
    }
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.putUrl(Uri.parse(
      'http://127.0.0.1:${server.port}/api/v1/plugins/activity/activities/updated',
    ));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'title': 'scn-act-updated', 'mood': 4}));
    final response = jsonDecode(await utf8.decoder.bind(await request.close()).join());
    expect(response['success'], isTrue);
    expect(response['data']['mood'], 4);

    final service = ActivityService(globalStorage, 'activity');
    final records = await service.getActivitiesForDate(today);
    expect(records.map((r) => r.id), unorderedEquals(['updated', 'unchanged']));
    final updated = records.singleWhere((r) => r.id == 'updated');
    expect(updated.title, 'scn-act-updated');
    expect(updated.mood, '4');
    expect(updated.durationInMinutes, 60);
  });

  test('活动：HTTP 创建重叠时段会拆分，重复时段不并存', () async {
    final data = AboutmeDataService.instance;
    final original = await data.call('activity', 'create', {
      'id': 'old', 'title': '原活动',
      'startTime': '2026-10-24T09:00:00', 'endTime': '2026-10-24T12:00:00',
    });
    expect(original['success'], isTrue);
    final created = await data.call('activity', 'create', {
      'id': 'new', 'title': '新活动',
      'startTime': '2026-10-24T10:00:00', 'endTime': '2026-10-24T11:00:00',
    });
    expect(created['success'], isTrue);
    final service = ActivityService(globalStorage, 'activity');
    var records = await service.getActivitiesForDate(DateTime(2026, 10, 24));
    expect(records.map((r) => [r.startTime.hour, r.endTime.hour]),
        [[9, 10], [10, 11], [11, 12]]);
    final repeated = await data.call('activity', 'create', {
      'id': 'latest', 'title': '最新活动',
      'startTime': '2026-10-24T10:00:00', 'endTime': '2026-10-24T11:00:00',
    });
    expect(repeated['success'], isTrue);
    records = await service.getActivitiesForDate(DateTime(2026, 10, 24));
    expect(records, hasLength(3));
    expect(records.where((r) => r.startTime.hour == 10).single.id, 'latest');
    expect(records.map((r) => r.durationInMinutes).reduce((a, b) => a + b), 180);
  });

  test('活动：HTTP 跨天创建后客户端两日均能加载，首日截止00点', () async {
    final created = await AboutmeDataService.instance.call('activity', 'create', {
      'id': 'overnight', 'title': '睡觉',
      'startTime': '2026-10-24T23:00:00', 'endTime': '2026-10-25T01:00:00',
    });
    expect(created['success'], isTrue);
    final service = ActivityService(globalStorage, 'activity');
    final first = (await service.getActivitiesForDate(DateTime(2026, 10, 24))).single;
    final second = (await service.getActivitiesForDate(DateTime(2026, 10, 25))).single;
    expect(first.startTime, DateTime(2026, 10, 24, 23));
    expect(first.endTime, DateTime(2026, 10, 25));
    expect(second.startTime, DateTime(2026, 10, 25));
    expect(second.endTime, DateTime(2026, 10, 25, 1));
    expect(first.durationInMinutes + second.durationInMinutes, 120);
  });

  test('活动：客户端可加载只存在于首日文件的旧跨天记录', () async {
    files['activity/activities_2026-10-24.json'] = [
      {'id': 'legacy', 'title': '旧跨天活动',
        'startTime': '2026-10-24T23:00:00', 'endTime': '2026-10-25T01:00:00'},
    ];
    final service = ActivityService(globalStorage, 'activity');
    expect((await service.getActivitiesForDate(DateTime(2026, 10, 24))).single.durationInMinutes, 60);
    expect((await service.getActivitiesForDate(DateTime(2026, 10, 25))).single.durationInMinutes, 60);
  });

  test('笔记：MCP 同参数创建文件夹后根目录可见，重新加载仍可见', () async {
    final data = AboutmeDataService.instance;
    await data.call('notes', 'createFolder', {'id': 'root', 'name': '根目录'});
    final created = await data.call('notes', 'createFolder', {'name': '新建文件夹'});
    expect(created['success'], isTrue);
    final id = created['data']['id'] as String;
    expect(created['data']['parentId'], isNull);

    final controller = NotesController(globalStorage);
    addTearDown(controller.dispose);
    await controller.reloadData();
    expect(controller.getAllFolders().map((f) => f.id), contains(id));
    expect(controller.getFolderChildren('root').map((f) => f.id), contains(id));
    expect(controller.getFolderPath(id).map((f) => f.id), ['root', id]);

    await controller.reloadData();
    expect(controller.getFolderChildren('root').map((f) => f.id), contains(id));
  });
}
