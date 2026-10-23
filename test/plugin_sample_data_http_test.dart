import 'dart:convert';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/agent_chat/services/conversation_service.dart';
import 'package:aboutme/plugins/diary/sample_data.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/habits/controllers/skill_controller.dart';
import 'package:aboutme/plugins/nodes/controllers/nodes_controller.dart';
import 'package:aboutme/plugins/notes/controllers/notes_controller.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  final files = <String, dynamic>{};

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      const prefix = '/api/v1/storage/files/';
      final path = request.uri.path;
      if (path.endsWith('/health')) {
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
  setUp(files.clear);

  test('日记：空后端创建示例、索引，重新加载及重复执行保留已有数据', () async {
    await DiaryUtils.createSampleEntries();
    final index = files['diary/diary_index.json'] as Map;
    final samples = DiarySampleData.getSampleDiaryEntries();
    expect(index.length, samples.length);
    for (final date in index.keys) {
      expect(files['diary/$date.json'], isNotNull);
    }
    final loaded = await DiaryUtils.loadDiaryEntries();
    expect(
      loaded.values.map((e) => e.title),
      unorderedEquals(samples.map((e) => e.title)),
    );
    final date = index.keys.first;
    files['diary/$date.json']['title'] = '用户修改的日记';
    await DiaryUtils.createSampleEntries();
    expect(files['diary/$date.json']['title'], '用户修改的日记');
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
}
