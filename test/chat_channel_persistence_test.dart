import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/config_manager.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/route/route_refresh_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/services/chat_config_service.dart';
import 'package:aboutme/plugins/chat/services/chat_data_service.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestChatPlugin extends ChatPlugin {
  @override
  Future<void> initialize() async {
    configService = ChatConfigService(this);
    dataService = ChatDataService(this);
  }

  @override
  Future<void> registerToApp(
    PluginManager manager,
    ConfigManager config,
  ) async {}
}

void main() {
  late HttpServer server;
  late _TestChatPlugin plugin;
  final files = <String, dynamic>{};
  Completer<void>? messageReadStarted;
  Completer<void>? releaseMessageRead;

  Channel channel(String id) =>
      Channel(id: id, title: id, icon: Icons.chat, messages: []);

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      const prefix = '/api/v1/storage/files/';
      final path = request.uri.path;
      if (path.endsWith('/health')) {
        request.response.write('{}');
      } else if (path.startsWith(prefix)) {
        final key = path.substring(prefix.length);
        switch (request.method) {
          case 'PUT':
            files[key] = jsonDecode(await utf8.decoder.bind(request).join());
            request.response.write('{}');
          case 'DELETE':
            files.remove(key);
            request.response.statusCode = 204;
          default:
            if (files.containsKey(key)) {
              final content = jsonEncode(files[key]);
              if (key == 'chat/messages/slow.json' &&
                  messageReadStarted != null) {
                final release = releaseMessageRead!;
                messageReadStarted!.complete();
                messageReadStarted = null;
                await release.future;
              }
              request.response.write(content);
            } else {
              request.response.statusCode = 404;
            }
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
    await PluginManager.instance.setStorageManager(globalStorage);
    plugin = _TestChatPlugin();
    await PluginManager.instance.registerPlugin(plugin);
  });

  tearDownAll(() => server.close(force: true));

  setUp(() {
    files.clear();
    plugin.dataService.channels.clear();
  });

  test('HTTP：兼容服务器消息，创建频道保留旧频道索引', () async {
    files['chat/channels.json'] = {
      'channels': ['old'],
    };
    files['chat/channel/old.json'] = {'channel': channel('old').toJson()};
    files['chat/messages/old.json'] = {
      'messages': [
        {
          'id': 'message',
          'content': 'server message',
          'senderId': 'default_user',
          'senderName': 'User',
          'createdAt': '2026-10-23T03:15:41.395Z',
        },
        {
          'id': 'legacy-message',
          'content': 'client message',
          'user': {'id': 'default_user'},
          'type': 'sent',
          'date': '2026-10-23T11:13:16.973724',
        },
      ],
    };
    await plugin.dataService.reloadChannels();
    final old = plugin.dataService.channels.single;
    expect(old.messages.first.user.id, 'default_user');
    expect(old.messages.first.user.username, 'User');
    expect(old.messages.first.date, DateTime.parse('2026-10-23T03:15:41.395Z'));
    expect(
      old.messages.last.date,
      DateTime.parse('2026-10-23T11:13:16.973724'),
    );

    await plugin.dataService.createChannel(channel('new'));
    expect(files['chat/channels.json'], {
      'channels': ['old', 'new'],
    });

    await plugin.dataService.reloadChannels();
    expect(
      plugin.dataService.channels.map((c) => c.id),
      containsAll(['old', 'new']),
    );
  });

  test('HTTP：内存尚未加载时创建和保存频道不覆盖旧索引', () async {
    files['chat/channels.json'] = {
      'channels': ['unloaded'],
    };
    await plugin.dataService.createChannel(channel('new'));
    await plugin.dataService.saveChannel(channel('new'));
    expect(files['chat/channels.json'], {
      'channels': ['unloaded', 'new'],
    });
  });

  test('HTTP：首次创建频道允许索引文件不存在', () async {
    await plugin.dataService.createChannel(channel('first'));
    expect(files['chat/channels.json'], {
      'channels': ['first'],
    });
  });

  test('HTTP：连续同步通知后客户端包含全部 MCP 消息', () async {
    final refresh = RouteRefreshManager();
    refresh.setPluginManager(PluginManager.instance);
    files['chat/channels.json'] = {
      'channels': ['batch'],
    };
    files['chat/channel/batch.json'] = {'channel': channel('batch').toJson()};
    final messages = <Map<String, dynamic>>[];
    files['chat/messages/batch.json'] = {'messages': messages};
    messages.add({
      'id': 'first',
      'content': 'first message',
      'senderId': 'zcode_agent',
      'senderName': 'ZCode',
      'createdAt': '2026-10-23T03:37:51.598Z',
    });
    await refresh.onFileSynced('chat/messages/batch.json');
    final updates = <Future<void>>[];
    for (var i = 0; i < 4; i++) {
      messages.add({
        'id': 'batch-$i',
        'content': 'message $i',
        'senderId': 'zcode_agent',
        'senderName': 'ZCode',
        'createdAt': '2026-10-23T03:37:51.685Z',
      });
      updates.add(refresh.onFileSynced('chat/messages/batch.json'));
    }
    await Future.wait(updates);
    final loaded = await plugin.dataService.getChannelMessages('batch');
    expect(loaded!.map((m) => m.id), messages.map((m) => m['id']));
  });

  test('HTTP：刷新过程中新增消息会在下一轮补读', () async {
    final refresh = RouteRefreshManager();
    refresh.setPluginManager(PluginManager.instance);
    files['chat/channels.json'] = {
      'channels': ['slow'],
    };
    files['chat/channel/slow.json'] = {'channel': channel('slow').toJson()};
    final messages = <Map<String, dynamic>>[
      {
        'id': 'first',
        'content': 'first',
        'senderId': 'zcode_agent',
        'createdAt': '2026-10-23T03:37:51.598Z',
      },
    ];
    files['chat/messages/slow.json'] = {'messages': messages};
    final started = messageReadStarted = Completer<void>();
    final release = releaseMessageRead = Completer<void>();
    final first = refresh.onFileSynced('chat/messages/slow.json');
    await started.future;
    messages.add({
      'id': 'during-refresh',
      'content': 'new message',
      'senderId': 'zcode_agent',
      'createdAt': '2026-10-23T03:37:51.685Z',
    });
    final next = refresh.onFileSynced('chat/messages/slow.json');
    release.complete();
    await Future.wait([first, next]);
    final loaded = await plugin.dataService.getChannelMessages('slow');
    expect(loaded!.map((m) => m.id), ['first', 'during-refresh']);
  });

  test('HTTP：消息解析失败时保留已加载的频道列表', () async {
    final existing = channel('existing');
    plugin.dataService.channels.add(existing);
    files['chat/channels.json'] = {
      'channels': ['broken'],
    };
    files['chat/channel/broken.json'] = {'channel': channel('broken').toJson()};
    files['chat/messages/broken.json'] = {
      'messages': [
        {'id': 'invalid'},
      ],
    };
    await plugin.dataService.reloadChannels();
    expect(plugin.dataService.channels, [existing]);
  });
}
