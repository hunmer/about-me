import 'dart:io';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

void main() {
  test('旧客户端与 MCP 消息归一化，未知字段/附件/回复不丢失', () {
    final old = {
      'id': 'm',
      'content': 'text',
      'createdAt': '2026-10-23T01:00:00Z',
      'senderId': 'u',
      'senderName': 'name',
      'replyToId': 'root',
      'extension': {'x': 1},
      'metadata': {
        'fileInfo': {'assetId': 'asset'},
      },
    };
    final dto = MessageDto.fromJson(old);
    expect(dto.user.id, 'u');
    expect(dto.user.name, 'name');
    expect(dto.toJson()['extension'], {'x': 1});
    expect(dto.toJson()['metadata'], old['metadata']);
    expect(dto.toJson()['replyToId'], 'root');
    expect(
      ChannelDto.fromJson({
        'id': 'c',
        'name': 'legacy',
        'isArchived': true,
      }).toJson()['isArchived'],
      isTrue,
    );
  });

  test('typed send/list/watch、消息 ID 保留和同毫秒稳定游标', () async {
    final root = await Directory.systemTemp.createTemp('chat_contract_');
    final data = AboutmeData.local(root.path);
    addTearDown(() async {
      await data.dispose();
      await root.delete(recursive: true);
    });
    await data.call('chat', 'create', {'id': 'channel', 'name': 'legacy'});
    final sent = await data.chat.sendMessage(
      SendMessageCommand(
        channelId: 'channel',
        message: MessageDto(
          id: 'client-id',
          content: 'hello',
          channelId: 'channel',
          user: const UserDto(id: 'u', name: 'User'),
          date: DateTime(2000),
        ),
        clientMutationId: 'once',
      ),
    );
    expect(sent.id, 'client-id');
    expect(sent.user.name, 'User');
    expect(sent.date.year, isNot(2000));
    // 构造旧数据同毫秒消息，只用于 codec/游标兼容验证。
    await data.writeFile('chat', 'messages/channel.json', {
      'messages': [
        for (final id in ['a', 'b', 'c', 'd', 'e'])
          {
            'id': id,
            'content': id,
            'date': '2026-10-23T00:00:00.000Z',
            'user': {'id': 'u', 'username': 'User'},
          },
      ],
    });
    final ids = <String>[];
    String? cursor;
    do {
      final page = await data.chat.listMessages(
        channelId: 'channel',
        limit: 2,
        before: cursor,
      );
      ids.addAll(page.items.map((item) => item.id));
      cursor = page.nextCursor;
    } while (cursor != null);
    expect(ids.toSet(), {'a', 'b', 'c', 'd', 'e'});
    expect(ids.length, 5);
    final summary = (await data.get('chat', 'getById', {
      'id': 'channel',
    }))['data'];
    expect(summary['lastMessage']['id'], 'client-id');
  });
}
