import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('XAIResponsesMediaGenerationModel', () {
    test(
      'image generation posts to /images/generations with options',
      () async {
        final client = _ScriptedHttpClient([
          (request) {
            expect(request.method, 'POST');
            expect(request.uri.path, '/v1/images/generations');
            final authHeader =
                request.headers['Authorization'] ??
                request.headers['authorization'];
            expect(authHeader, 'Bearer test-key');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['model'], 'grok-imagine-image');
            expect(body['prompt'], 'Draw a blue robot');
            expect(body['n'], 2);
            expect(body['aspect_ratio'], '16:9');
            expect(body['resolution'], '2k');
            expect(body['response_format'], 'b64_json');
            expect(body['user'], 'u-1');
            return _ScriptedResponse(
              statusCode: 200,
              body: jsonEncode({
                'data': [
                  {'url': 'https://cdn.example.com/a.jpg'},
                  {
                    'b64_json': base64Encode(Uint8List.fromList([1, 2, 3])),
                  },
                ],
              }),
            );
          },
        ]);
        final model = XAIResponsesMediaGenerationModel(
          name: 'grok-imagine-image',
          defaultOptions: const XAIResponsesMediaGenerationModelOptions(),
          apiKey: 'test-key',
          baseUrl: Uri.parse('https://api.x.ai/v1'),
          httpClient: client,
        );

        final chunks = await model
            .generateMediaStream(
              'Draw a blue robot',
              mimeTypes: const ['image/png'],
              options: const XAIResponsesMediaGenerationModelOptions(
                n: 2,
                aspectRatio: '16:9',
                resolution: '2k',
                responseFormat: 'b64_json',
                user: 'u-1',
              ),
            )
            .toList();

        expect(chunks, hasLength(1));
        expect(chunks.single.isComplete, isTrue);
        expect(chunks.single.links, isNotEmpty);
        expect(chunks.single.assets.whereType<DataPart>(), isNotEmpty);
        model.dispose();
      },
    );

    test('image editing posts to /images/edits with image payload', () async {
      final client = _ScriptedHttpClient([
        (request) {
          expect(request.uri.path, '/v1/images/edits');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final image = body['image'] as Map<String, dynamic>;
          expect(image['type'], 'image_url');
          expect(
            (image['url'] as String).startsWith('data:image/png;base64,'),
            isTrue,
          );
          return _ScriptedResponse(
            statusCode: 200,
            body: jsonEncode({
              'data': [
                {'url': 'https://cdn.example.com/edited.png'},
              ],
            }),
          );
        },
      ]);
      final model = XAIResponsesMediaGenerationModel(
        name: 'grok-imagine-image',
        defaultOptions: const XAIResponsesMediaGenerationModelOptions(),
        apiKey: 'test-key',
        baseUrl: Uri.parse('https://api.x.ai/v1'),
        httpClient: client,
      );

      final chunks = await model
          .generateMediaStream(
            'Edit this',
            mimeTypes: const ['image/png'],
            attachments: [
              DataPart(Uint8List.fromList([9, 8, 7]), mimeType: 'image/png'),
            ],
          )
          .toList();

      expect(chunks.single.links, isNotEmpty);
      model.dispose();
    });

    test('video generation polls pending then done', () async {
      final client = _ScriptedHttpClient([
        (_) => const _ScriptedResponse(
          statusCode: 200,
          body: '{"request_id":"req_123"}',
        ),
        (request) {
          expect(request.uri.path, '/v1/videos/req_123');
          return const _ScriptedResponse(
            statusCode: 200,
            body: '{"status":"pending"}',
          );
        },
        (request) {
          expect(request.uri.path, '/v1/videos/req_123');
          return _ScriptedResponse(
            statusCode: 200,
            body: jsonEncode({
              'status': 'done',
              'video': {'url': 'https://cdn.example.com/video.mp4'},
            }),
          );
        },
      ]);
      final model = XAIResponsesMediaGenerationModel(
        name: 'grok-imagine-video',
        defaultOptions: const XAIResponsesMediaGenerationModelOptions(),
        apiKey: 'test-key',
        baseUrl: Uri.parse('https://api.x.ai/v1'),
        httpClient: client,
      );

      final chunks = await model
          .generateMediaStream(
            'Create a cube animation',
            mimeTypes: const ['video/mp4'],
            options: const XAIResponsesMediaGenerationModelOptions(
              pollIntervalSeconds: 0,
              pollTimeoutSeconds: 10,
              durationSeconds: 1,
            ),
          )
          .toList();

      expect(chunks, hasLength(2));
      expect(chunks.first.isComplete, isFalse);
      expect(chunks.first.metadata['status'], 'pending');
      expect(chunks.last.isComplete, isTrue);
      expect(chunks.last.links, isNotEmpty);
      model.dispose();
    });

    test('video editing posts to /videos/edits', () async {
      final client = _ScriptedHttpClient([
        (request) {
          expect(request.uri.path, '/v1/videos/edits');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final video = body['video'] as Map<String, dynamic>;
          expect(video['url'], 'https://example.com/input.mp4');
          return const _ScriptedResponse(
            statusCode: 200,
            body: '{"request_id":"req_edit_1"}',
          );
        },
        (_) => _ScriptedResponse(
          statusCode: 200,
          body: jsonEncode({
            'status': 'done',
            'video': {'url': 'https://cdn.example.com/out.mp4'},
          }),
        ),
      ]);
      final model = XAIResponsesMediaGenerationModel(
        name: 'grok-imagine-video',
        defaultOptions: const XAIResponsesMediaGenerationModelOptions(),
        apiKey: 'test-key',
        baseUrl: Uri.parse('https://api.x.ai/v1'),
        httpClient: client,
      );

      final chunks = await model
          .generateMediaStream(
            'Add snow',
            mimeTypes: const ['video/mp4'],
            attachments: [
              LinkPart(
                Uri.parse('https://example.com/input.mp4'),
                mimeType: 'video/mp4',
              ),
            ],
            options: const XAIResponsesMediaGenerationModelOptions(
              pollIntervalSeconds: 0,
            ),
          )
          .toList();

      expect(chunks.last.links, isNotEmpty);
      model.dispose();
    });

    test('throws when video request expires', () async {
      final client = _ScriptedHttpClient([
        (_) => const _ScriptedResponse(
          statusCode: 200,
          body: '{"request_id":"req_expired"}',
        ),
        (_) => const _ScriptedResponse(
          statusCode: 200,
          body: '{"status":"expired"}',
        ),
      ]);
      final model = XAIResponsesMediaGenerationModel(
        name: 'grok-imagine-video',
        defaultOptions: const XAIResponsesMediaGenerationModelOptions(),
        apiKey: 'test-key',
        baseUrl: Uri.parse('https://api.x.ai/v1'),
        httpClient: client,
      );

      expect(
        () => model
            .generateMediaStream('x', mimeTypes: const ['video/mp4'])
            .drain<void>(),
        throwsA(isA<StateError>()),
      );
      model.dispose();
    });

    test('throws when video request id is missing', () async {
      final client = _ScriptedHttpClient([
        (_) => const _ScriptedResponse(statusCode: 200, body: '{}'),
      ]);
      final model = XAIResponsesMediaGenerationModel(
        name: 'grok-imagine-video',
        defaultOptions: const XAIResponsesMediaGenerationModelOptions(),
        apiKey: 'test-key',
        baseUrl: Uri.parse('https://api.x.ai/v1'),
        httpClient: client,
      );

      expect(
        () => model
            .generateMediaStream('x', mimeTypes: const ['video/mp4'])
            .drain<void>(),
        throwsA(isA<StateError>()),
      );
      model.dispose();
    });

    test('throws when start request fails', () async {
      final client = _ScriptedHttpClient([
        (_) => const _ScriptedResponse(statusCode: 500, body: 'bad'),
      ]);
      final model = XAIResponsesMediaGenerationModel(
        name: 'grok-imagine-video',
        defaultOptions: const XAIResponsesMediaGenerationModelOptions(),
        apiKey: 'test-key',
        baseUrl: Uri.parse('https://api.x.ai/v1'),
        httpClient: client,
      );

      expect(
        () => model
            .generateMediaStream('x', mimeTypes: const ['video/mp4'])
            .drain<void>(),
        throwsA(isA<Exception>()),
      );
      model.dispose();
    });

    test('throws when poll request fails', () async {
      final client = _ScriptedHttpClient([
        (_) => const _ScriptedResponse(
          statusCode: 200,
          body: '{"request_id":"req_poll_fail"}',
        ),
        (_) => const _ScriptedResponse(statusCode: 500, body: 'bad poll'),
      ]);
      final model = XAIResponsesMediaGenerationModel(
        name: 'grok-imagine-video',
        defaultOptions: const XAIResponsesMediaGenerationModelOptions(),
        apiKey: 'test-key',
        baseUrl: Uri.parse('https://api.x.ai/v1'),
        httpClient: client,
      );

      expect(
        () => model
            .generateMediaStream('x', mimeTypes: const ['video/mp4'])
            .drain<void>(),
        throwsA(isA<Exception>()),
      );
      model.dispose();
    });

    test('throws when video polling times out', () async {
      final client = _ScriptedHttpClient([
        (_) => const _ScriptedResponse(
          statusCode: 200,
          body: '{"request_id":"req_timeout"}',
        ),
        (_) => const _ScriptedResponse(
          statusCode: 200,
          body: '{"status":"pending"}',
        ),
      ]);
      final model = XAIResponsesMediaGenerationModel(
        name: 'grok-imagine-video',
        defaultOptions: const XAIResponsesMediaGenerationModelOptions(),
        apiKey: 'test-key',
        baseUrl: Uri.parse('https://api.x.ai/v1'),
        httpClient: client,
      );

      expect(
        () => model
            .generateMediaStream(
              'x',
              mimeTypes: const ['video/mp4'],
              options: const XAIResponsesMediaGenerationModelOptions(
                pollTimeoutSeconds: -1,
                pollIntervalSeconds: 0,
              ),
            )
            .drain<void>(),
        throwsA(isA<TimeoutException>()),
      );
      model.dispose();
    });

    test('throws for mixed image and video mime types', () {
      final model = XAIResponsesMediaGenerationModel(
        name: 'grok',
        defaultOptions: const XAIResponsesMediaGenerationModelOptions(),
        apiKey: 'test-key',
        httpClient: _ScriptedHttpClient(const []),
      );

      expect(
        () => model
            .generateMediaStream(
              'x',
              mimeTypes: const ['image/png', 'video/mp4'],
            )
            .drain<void>(),
        throwsA(isA<UnsupportedError>()),
      );
      model.dispose();
    });

    test('throws for unsupported mime types', () {
      final model = XAIResponsesMediaGenerationModel(
        name: 'grok',
        defaultOptions: const XAIResponsesMediaGenerationModelOptions(),
        apiKey: 'test-key',
        httpClient: _ScriptedHttpClient(const []),
      );

      expect(
        () => model
            .generateMediaStream('x', mimeTypes: const ['application/pdf'])
            .drain<void>(),
        throwsA(isA<UnsupportedError>()),
      );
      model.dispose();
    });
  });
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String body;
}

class _ScriptedResponse {
  const _ScriptedResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class _ScriptedHttpClient extends http.BaseClient {
  _ScriptedHttpClient(this._responses);

  final List<_ScriptedResponse Function(_CapturedRequest request)> _responses;
  int _index = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_index >= _responses.length) {
      throw StateError('No scripted response left for ${request.url}');
    }

    final bodyBytes = await request.finalize().expand((x) => x).toList();
    final captured = _CapturedRequest(
      method: request.method,
      uri: request.url,
      headers: Map<String, String>.from(request.headers),
      body: utf8.decode(bodyBytes),
    );
    final scripted = _responses[_index++](captured);

    return http.StreamedResponse(
      Stream.value(utf8.encode(scripted.body)),
      scripted.statusCode,
      headers: const {},
      request: request,
    );
  }
}
