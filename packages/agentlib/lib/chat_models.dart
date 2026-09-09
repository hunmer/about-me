typedef ChatPartMapper<T> =
    T Function({
      required String text,
      required ChatCompletionMessageImageUrl image,
      required Object audio,
      required String refusal,
    });

enum ChatCompletionMessageRole { system, user, assistant, tool }

class ChatCompletionMessage {
  ChatCompletionMessage._(this.role, this.content);
  final ChatCompletionMessageRole role;
  final dynamic content;

  factory ChatCompletionMessage.system({required String content}) =>
      ChatCompletionMessage._(ChatCompletionMessageRole.system, content);
  factory ChatCompletionMessage.user({
    required ChatCompletionUserMessageContent content,
  }) => ChatCompletionMessage._(ChatCompletionMessageRole.user, content);
  factory ChatCompletionMessage.assistant({String? content}) =>
      ChatCompletionMessage._(ChatCompletionMessageRole.assistant, content);
}

abstract class ChatCompletionUserMessageContent {
  const ChatCompletionUserMessageContent();
  factory ChatCompletionUserMessageContent.string(String value) =
      StringContent;
  factory ChatCompletionUserMessageContent.parts(
    List<ChatCompletionMessageContentPart> value,
  ) = PartsContent;

  T map<T>({
    required T Function(PartsContent value) parts,
    required T Function(StringContent value) string,
  });
}

class StringContent extends ChatCompletionUserMessageContent {
  const StringContent(this.value);
  final String value;
  @override
  T map<T>({
    required T Function(PartsContent value) parts,
    required T Function(StringContent value) string,
  }) => string(this);
}

class PartsContent extends ChatCompletionUserMessageContent {
  const PartsContent(this.value);
  final List<ChatCompletionMessageContentPart> value;
  @override
  T map<T>({
    required T Function(PartsContent value) parts,
    required T Function(StringContent value) string,
  }) => parts(this);
}

class ChatCompletionMessageContentPart {
  ChatCompletionMessageContentPart._(
    this.kind, {
    String? text,
    ChatCompletionMessageImageUrl? imageUrl,
  }) : _text = text,
       _imageUrl = imageUrl;
  final String kind;
  final String? _text;
  final ChatCompletionMessageImageUrl? _imageUrl;
  String get text => _text ?? '';
  ChatCompletionMessageImageUrl get imageUrl => _imageUrl!;

  factory ChatCompletionMessageContentPart.text({required String text}) =>
      ChatCompletionMessageContentPart._('text', text: text);
  factory ChatCompletionMessageContentPart.image({
    required ChatCompletionMessageImageUrl imageUrl,
  }) => ChatCompletionMessageContentPart._('image', imageUrl: imageUrl);
  factory ChatCompletionMessageContentPart.audio({Object? audio}) =>
      ChatCompletionMessageContentPart._('audio');
  factory ChatCompletionMessageContentPart.refusal({required String refusal}) =>
      ChatCompletionMessageContentPart._('refusal', text: refusal);

  T map<T>({
    required T Function(ChatCompletionMessageContentPart value) text,
    required T Function(ChatCompletionMessageContentPart value) image,
    required T Function(ChatCompletionMessageContentPart value) audio,
    required T Function(ChatCompletionMessageContentPart value) refusal,
  }) {
    return switch (kind) {
      'text' => text(this),
      'image' => image(this),
      'audio' => audio(this),
      _ => refusal(this),
    };
  }
}

class ChatCompletionMessageImageUrl {
  const ChatCompletionMessageImageUrl({required this.url});
  final String url;
}

class ChatCompletionModel {
  static String modelId(String value) => value;
}

class CreateChatCompletionRequest {
  CreateChatCompletionRequest({
    required this.model,
    required this.messages,
    this.temperature,
    this.maxTokens,
    this.responseFormat,
  });
  final String model;
  final List<ChatCompletionMessage> messages;
  final double? temperature;
  final int? maxTokens;
  final ResponseFormat? responseFormat;
}

class JsonSchemaObject {
  const JsonSchemaObject({
    required this.name,
    required this.schema,
    this.description,
    this.strict,
  });
  final String name;
  final String? description;
  final Map<String, dynamic> schema;
  final bool? strict;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'schema': schema,
    if (strict != null) 'strict': strict,
  };
}

class ResponseFormat {
  const ResponseFormat._(this.type, [this.jsonSchema]);
  final String type;
  final JsonSchemaObject? jsonSchema;
  factory ResponseFormat.text() => const ResponseFormat._('text');
  factory ResponseFormat.jsonObject() => const ResponseFormat._('json_object');
  factory ResponseFormat.jsonSchema({required JsonSchemaObject jsonSchema}) =>
      ResponseFormat._('json_schema', jsonSchema);

  Map<String, dynamic> toJson() => {
    'type': type,
    if (jsonSchema != null) 'json_schema': jsonSchema!.toJson(),
  };
}
