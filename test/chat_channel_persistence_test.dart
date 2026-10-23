import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/chat/services/chat_config_service.dart';
import 'package:aboutme/plugins/chat/services/chat_data_service.dart';
import 'package:aboutme/plugins/chat/repositories/client_chat_repository.dart';
import 'package:aboutme/plugins/chat/services/file_service.dart';
import 'package:aboutme/plugins/chat/services/sticker_service.dart';
import 'package:aboutme/plugins/chat/models/file_message.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/core/data/sdk_asset_image_provider.dart';
import 'package:image/image.dart' as img;
import 'package:aboutme/plugins/diary/repositories/client_diary_repository.dart';
import 'package:shared_models/shared_models.dart' as shared;
import 'package:aboutme_data_sdk/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestChatPlugin extends ChatPlugin {
  @override
  Future<void> initialize() async {
    configService = ChatConfigService(this);
    dataService = ChatDataService(this);
  }
  @override
  Future<void> registerToApp(PluginManager manager, ConfigManager config) async {}
}

void main() {
  late Directory root;
  late HttpServer server;
  late _TestChatPlugin plugin;
  late AboutmeData serverData;
  var rawRequests = 0;
  var messageQueries = 0;
  final invoker = PluginInvoker();

  Channel channel(String id) => Channel(id: id, title: id, icon: Icons.chat, messages: []);
  Message message(String id, String channelId) => Message(
    id: id, channelId: channelId, content: id,
    user: User(id: 'u', username: 'User'), type: MessageType.sent, date: DateTime(2000),
  );
  Future<void> send(String channelId, String id) async {
    final result = await serverData.call('chat', 'sendMessage', {'channelId': channelId, 'id': id, 'content': id});
    expect(result['success'], isTrue, reason: '$result');
  }

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('chat_client_business_');
    serverData = AboutmeData.local(root.path);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.startsWith('/api/v1/plugins/')) {
        final query = <String, dynamic>{
          for (final entry in request.uri.queryParameters.entries)
            entry.key: request.headers.value('x-aboutme-query-encoding') == 'json-v1' ? jsonDecode(entry.value) : entry.value,
        };
        final body = await utf8.decoder.bind(request).join();
        if (request.method == 'GET' && request.uri.path.endsWith('/messages')) messageQueries++;
        final result = await invoker.invoke(LocalPluginBackend(root.path), request.method, request.uri.path,
          query: query, body: body.isEmpty ? null : jsonDecode(body));
        request.response.write(jsonEncode(result));
      } else if (request.uri.path.endsWith('/health')) {
        request.response.write('{}');
      } else {
        rawRequests++;
        request.response.statusCode = 405;
        request.response.write('{"error":"raw files disabled"}');
      }
      await request.response.close();
    });
    globalStorage = StorageManager(storage: HttpStorage(
      serverUrl: 'http://127.0.0.1:${server.port}', authType: StorageAuthType.apiKey, credential: 'test',
    ));
    await AboutmeDataService.instance.initialize();
    await PluginManager.instance.setStorageManager(globalStorage);
    plugin = _TestChatPlugin();
    await PluginManager.instance.registerPlugin(plugin);
    rawRequests = 0; // 插件管理器初始化目录不属于本测试的业务操作。
  });
  tearDownAll(() async {
    await plugin.dataService.dispose();
    await AboutmeDataService.instance.data.dispose();
    await serverData.dispose();
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  test('频道列表只读摘要；打开频道读取最新消息；普通写入不调用文件 API', () async {
    await plugin.dataService.createChannel(channel('a'));
    await send('a', 'remote');
    final before = messageQueries;
    await plugin.dataService.reloadChannels();
    expect(messageQueries, before);
    expect(plugin.dataService.channels.single.messageCount, 1);
    expect(plugin.dataService.channels.single.messages, isEmpty);
    expect(plugin.dataService.channels.single.lastMessage?.id, 'remote');
    final messages = await plugin.dataService.getChannelMessages('a');
    expect(messages!.single.id, 'remote');
    final committed = await plugin.dataService.addMessage('a', message('client', 'a'));
    expect(committed.date.year, isNot(2000));
    expect(rawRequests, 0);
  });

  test('用旧页面快照删除一条消息保留并发新增；编辑发送字段 patch', () async {
    await plugin.dataService.createChannel(channel('delete'));
    await send('delete', 'old');
    final old = (await plugin.dataService.getChannelMessages('delete'))!.single;
    await send('delete', 'concurrent');
    await plugin.dataService.deleteMessage(old);
    final remaining = (await plugin.dataService.getChannelMessages('delete'))!;
    expect(remaining.map((m) => m.id), ['concurrent']);
    final edited = await remaining.single.copyWith(content: 'edited');
    await plugin.dataService.updateMessage(edited);
    expect((await plugin.dataService.getChannelMessages('delete'))!.single.content, 'edited');
    expect(rawRequests, 0);
  });

  test('消息窗口使用游标加载历史页；WS 失效后补齐连续远端消息', () async {
    await plugin.dataService.createChannel(channel('pages'));
    for (var i = 0; i < 65; i++) { await send('pages', 'p-$i'); }
    final first = await plugin.dataService.watchMessages('pages').first;
    expect(first.length, 50);
    final snapshots = StreamController<List<Message>>();
    final subscription = plugin.dataService.watchMessages('pages', pages: 2).listen(snapshots.add, onError: snapshots.addError);
    final iterator = StreamIterator(snapshots.stream);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.length, 65);
    await Future.wait([for (var i = 0; i < 10; i++) send('pages', 'new-$i')]);
    AboutmeDataService.instance.publishRemoteEvent('chat', 'messages');
    do { expect(await iterator.moveNext(), isTrue); } while (iterator.current.length != 75);
    expect(iterator.current.map((m) => m.id).toSet().length, 75);
    await subscription.cancel();
    await iterator.cancel();
    await snapshots.close();
  });

  test('陈旧编辑返回冲突并保留远端内容；损坏消息不变成空文件', () async {
    await plugin.dataService.createChannel(channel('conflict'));
    await send('conflict', 'm');
    final stale = (await plugin.dataService.getChannelMessages('conflict'))!.single;
    await serverData.call('chat', 'updateMessage', {'channelId': 'conflict', 'messageId': 'm', 'content': 'remote edit'});
    await expectLater(plugin.dataService.updateMessage(await stale.copyWith(content: 'stale edit')), throwsA(isA<QueryFailure>()));
    expect((await plugin.dataService.getChannelMessages('conflict'))!.single.content, 'remote edit');
    await File('${root.path}/chat/messages/conflict.json').writeAsString('{broken');
    await expectLater(plugin.dataService.getChannelMessages('conflict'), throwsA(isA<QueryFailure>()));
    expect(await File('${root.path}/chat/messages/conflict.json').readAsString(), '{broken');
  });
  test('共享用例提交字段 patch/null 并保留其他字段；DTO 编辑透传原版本', () async {
    final repository = ClientChatRepository(dataService: plugin.dataService, configService: plugin.configService, pluginColor: Colors.blue);
    final useCase = shared.ChatUseCase(repository);
    await plugin.dataService.createChannel(channel('repository'));
    final stale = (await repository.getChannelById('repository')).dataOrNull!;
    final remote = await serverData.call('chat', 'patch', {'id': 'repository', 'groups': ['remote'], 'metadata': {'keep': true}, 'backgroundColor': '#123456'});
    expect(remote['success'], true);
    final patched = await useCase.updateChannel({'id': 'repository', 'title': 'only title', 'backgroundColor': null});
    expect(patched.isSuccess, true, reason: '$patched');
    final current = (await repository.getChannelById('repository')).dataOrNull!;
    expect(current.groups, ['remote']); expect(current.metadata, {'keep': true}); expect(current.backgroundColor, isNull);
    expect((await repository.updateChannel('repository', stale.copyWith(title: 'stale'))).isFailure, true);
    expect((await repository.getChannelById('repository')).dataOrNull!.title, 'only title');
    final diaryRepository = ClientDiaryRepository();
    final diary = shared.DiaryUseCase(diaryRepository);
    final saved = await serverData.call('diary', 'save', {'date': '2026-01-01', 'content': 'keep', 'mood': 'happy', 'tags': ['keep']});
    final cleared = await diary.updateEntry({'date': '2026-01-01', 'mood': null, 'expectedVersion': saved['version']});
    expect(cleared.isSuccess, true, reason: '$cleared');
    final entry = (await diaryRepository.getEntryByDate('2026-01-01')).dataOrNull!;
    expect(entry.content, 'keep'); expect(entry.mood, isNull); expect(entry.tags, ['keep']);
    expect((await diary.updateEntry({'date': '2026-01-01', 'title': 'stale', 'expectedVersion': saved['version']})).isFailure, true);
    expect(rawRequests, 0);
  });

  test('客户端附件/贴图走业务 API，模型保存稳定引用且物化路径不进入消息', () async {
    final fileService = FileService();
    final bytes = img.encodePng(img.Image(width: 1, height: 1));
    final reference = await fileService.saveImageBytes(bytes, 'emoji.png');
    expect(reference, startsWith('asset://'));
    expect(await ImageUtils.readStorageBytes(reference), bytes);
    expect(ImageUtils.createImageProvider(reference), isA<SdkAssetImageProvider>());
    expect(ImageUtils.createImageProvider('./$reference'), ImageUtils.createImageProvider(reference));
    final selected = File('${root.path}/selected.png'); await selected.writeAsBytes(bytes);
    final materialized = await fileService.saveImage(selected);
    final fileMessage = await FileMessage.fromFile(materialized, originalFileName: 'selected.png');
    expect(fileMessage.filePath, startsWith('asset://'));
    expect((await fileMessage.getAbsolutePath()), materialized.path);
    expect(fileMessage.toJson()['filePath'], isNot(contains(root.path)));
    final collection = await StickerService.instance.createCollection('images', sourcePaths: [selected.path]);
    expect(collection.stickerPaths.single, startsWith('asset://'));
    expect(await StickerService.instance.readStickerBytes(collection.stickerPaths.single), bytes);
    final audio = await fileService.saveAudioBytes([1, 2], 'recording.webm');
    expect((await AboutmeDataService.instance.data.assets.getMetadata(audio.substring(8))).mediaType, 'audio/webm');
    expect(await selected.exists(), true);
    expect(rawRequests, 0);
  });
}
