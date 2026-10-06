import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

void main() {
  group('xAI Provider', () {
    test('has expected provider identity', () {
      final provider = XAIProvider(apiKey: 'test-key');

      expect(provider.name, equals('xai'));
      expect(provider.displayName, equals('xAI'));
      expect(provider.apiKeyName, equals('XAI_API_KEY'));
      expect(provider.defaultModelNames[ModelKind.chat], isNotNull);
      expect(provider.defaultModelNames[ModelKind.embeddings], isNull);
    });

    test('rejects temperature for chat model creation', () {
      final provider = XAIProvider(apiKey: 'test-key');

      expect(
        () => provider.createChatModel(temperature: 0.2),
        throwsA(isA<UnsupportedError>()),
      );

      expect(
        () => provider.createChatModel(
          options: const OpenAIChatOptions(temperature: 0.2),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
