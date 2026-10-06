import 'dart:io' show Platform;

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

void main() {
  // Run manually with:
  // XAI_API_KEY=your_key \
  // XAI_MCP_TEST_MODEL=grok-4-fast \
  // dart test test/xai_responses_mcp_integration_test.dart
  final hasXaiKey = (Platform.environment['XAI_API_KEY'] ?? '')
      .trim()
      .isNotEmpty;
  final testModel =
      (Platform.environment['XAI_MCP_TEST_MODEL'] ?? 'grok-4-fast').trim();

  group('xAI Responses MCP Integration', () {
    test(
      'accepts MCP tool configuration and returns a response',
      () async {
        final agent = Agent(
          'xai-responses:$testModel',
          chatModelOptions: const XAIResponsesChatModelOptions(
            serverSideTools: {XAIServerSideTool.mcp},
            mcpTools: [
              XAIMcpToolConfig(
                serverUrl: 'https://mcp.deepwiki.com/mcp',
                serverLabel: 'deepwiki',
              ),
            ],
          ),
        );

        final chunks = <ChatResult<String>>[];
        await agent
            .sendStream(
              'You must use an MCP tool call to inspect '
              'https://github.com/xai-org/xai-sdk-python '
              'and summarize one capability.',
            )
            .forEach(chunks.add);

        expect(chunks, isNotEmpty);
        final fullText = chunks.map((c) => c.output).join().trim();
        expect(fullText, isNotEmpty);

        final hadMcpMetadata = chunks.any((c) => c.metadata['mcp'] != null);
        expect(
          hadMcpMetadata,
          isTrue,
          reason:
              'MCP-enabled request should emit MCP metadata when the tool is '
              'used.',
        );
      },
      skip: hasXaiKey ? false : 'Requires XAI_API_KEY',
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
