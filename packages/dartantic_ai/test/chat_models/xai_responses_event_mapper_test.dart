import 'dart:typed_data';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

void main() {
  group('XAIResponsesEventMapper', () {
    test('emits MCP metadata from raw JSON events', () async {
      final mapper = XAIResponsesEventMapper(
        storeSession: false,
        downloadContainerFile: (_, __) async =>
            ContainerFileData(bytes: Uint8List(0)),
      );

      final chunks = await mapper.handleRawJson({
        'type': 'response.completed',
        'response': {
          'id': 'resp_123',
          'output': [
            {'type': 'mcp_call_output', 'status': 'completed'},
          ],
        },
      }).toList();

      expect(chunks, hasLength(1));
      expect(chunks.first.metadata['mcp'], isNotNull);
    });

    test('does not emit metadata for non-MCP raw events', () async {
      final mapper = XAIResponsesEventMapper(
        storeSession: false,
        downloadContainerFile: (_, __) async =>
            ContainerFileData(bytes: Uint8List(0)),
      );

      final chunks = await mapper.handleRawJson({
        'type': 'response.text.delta',
        'delta': 'hello',
      }).toList();

      expect(chunks, isEmpty);
    });
  });
}
