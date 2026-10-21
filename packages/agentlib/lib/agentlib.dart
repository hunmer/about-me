import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// AgentLib transport facade. Agent orchestration remains in the app while
/// this class provides the OpenAI-compatible HTTP and SSE transport.
class AgentLibClient {
  AgentLibClient({
    required this.baseUrl,
    required this.headers,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final Map<String, String> headers;
  final http.Client _httpClient;

  Uri _endpoint() {
    final normalized = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse(
      normalized.endsWith('/chat/completions')
          ? normalized
          : '$normalized/chat/completions',
    );
  }

  Future<Map<String, dynamic>> requestJson(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? body,
  }) async {
    final normalized = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$normalized/$path');
    final request = http.Request(method, uri)
      ..headers.addAll({'Content-Type': 'application/json', ...headers});
    if (body != null) request.body = jsonEncode(body);
    final response = await _httpClient.send(request);
    final raw = await response.stream.bytesToString();
    dynamic decoded;
    try {
      decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    } catch (_) {
      decoded = raw;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AgentLibException('HTTP ${response.statusCode}', decoded);
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<String> complete({
    required String model,
    required List<Map<String, dynamic>> messages,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? extraBody,
  }) async {
    final response = await _httpClient.post(
      _endpoint(),
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode({
        ...?extraBody,
        'model': model,
        'messages': messages,
        'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (responseFormat != null) 'response_format': responseFormat,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawBody = utf8.decode(response.bodyBytes);
      dynamic body;
      try {
        body = jsonDecode(rawBody);
      } catch (_) {
        body = rawBody;
      }
      throw AgentLibException('HTTP ${response.statusCode}', body);
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    return (((body as Map)['choices'] as List).first
                as Map)['message']['content']
            as String? ??
        '';
  }

  Stream<String> stream({
    required String model,
    required List<Map<String, dynamic>> messages,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? responseFormat,
    Map<String, dynamic>? extraBody,
    void Function(String)? onThinking,
  }) async* {
    final request =
        http.Request('POST', _endpoint())
          ..headers.addAll({'Content-Type': 'application/json', ...headers})
          ..body = jsonEncode({
            ...?extraBody,
            'model': model,
            'messages': messages,
            'temperature': temperature,
            if (maxTokens != null) 'max_tokens': maxTokens,
            'stream': true,
            if (responseFormat != null) 'response_format': responseFormat,
          });
    final response = await _httpClient.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawBody = await response.stream.bytesToString();
      dynamic body;
      try {
        body = jsonDecode(rawBody);
      } catch (_) {
        body = rawBody;
      }
      throw AgentLibException('HTTP ${response.statusCode}', body);
    }
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data == '[DONE]' || data.isEmpty) continue;
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) continue;
      final delta =
          (choices.first as Map<String, dynamic>)['delta']
              as Map<String, dynamic>?;
      final content = delta?['content'];
      final thinking = delta?['reasoning_content'];
      if (thinking is String && thinking.isNotEmpty) onThinking?.call(thinking);
      if (content is String && content.isNotEmpty) yield content;
    }
  }
}

class AgentLibException implements Exception {
  AgentLibException(this.message, this.body);
  final String message;
  final dynamic body;
  @override
  String toString() => 'AgentLibException: $message';
}
