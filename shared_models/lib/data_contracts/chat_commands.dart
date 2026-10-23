import '../repositories/chat/chat_repository.dart';

class SendMessageCommand {
  const SendMessageCommand(
      {required this.channelId,
      required this.message,
      required this.clientMutationId});
  final String channelId;
  final MessageDto message;
  final String clientMutationId;
  Map<String, dynamic> toJson() => {
        ...message.toJson(),
        'channelId': channelId,
        'clientMutationId': clientMutationId
      };
}

class MessagePage {
  const MessagePage(
      {required this.items,
      required this.total,
      required this.hasMore,
      this.nextCursor,
      this.version});
  final List<MessageDto> items;
  final int total;
  final bool hasMore;
  final String? nextCursor;
  final int? version;
}
