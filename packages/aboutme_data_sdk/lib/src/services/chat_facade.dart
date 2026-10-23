import 'package:shared_models/shared_models.dart';
import 'aboutme_data.dart';
import 'query_store.dart';

class ChatFacade {
  const ChatFacade(this.data);
  final AboutmeData data;

  Future<MessagePage> listMessages({
    required String channelId,
    int limit = 50,
    String? before,
  }) async {
    final response = await data.query('chat', 'getMessages', {
      'channelId': channelId,
      'limit': limit,
      if (before != null) 'before': before,
    });
    final page = response['data'] as Map;
    return MessagePage(
      items: (page['data'] as List)
          .map(
            (item) =>
                MessageDto.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      total: page['total'] as int,
      hasMore: page['hasMore'] as bool,
      nextCursor: page['nextCursor'] as String?,
      version: response['version'] as int?,
    );
  }

  Future<MessageDto> sendMessage(SendMessageCommand command) async {
    final result = await data.call('chat', 'sendMessage', command.toJson());
    if (result['success'] != true) throw QueryFailure(result);
    return MessageDto.fromJson(
      Map<String, dynamic>.from(result['data'] as Map),
    );
  }

  Stream<QuerySnapshot> watchMessages({
    required String channelId,
    int limit = 50,
  }) => data.watch('chat', 'getMessages', {
    'channelId': channelId,
    'limit': limit,
  });
}
