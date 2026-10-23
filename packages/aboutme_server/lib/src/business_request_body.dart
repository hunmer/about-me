import 'dart:convert';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

class BusinessBodyTooLarge implements Exception {}

/// REST/MCP 使用同一有界 JSON 传输；限制在流式读取阶段执行。
Future<dynamic> readBusinessRequestBody(Request request, {bool allowEmpty = false}) async {
  const maxBodyBytes = 24 * 1024 * 1024;
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in request.read()) {
    if (bytes.length + chunk.length > maxBodyBytes) throw BusinessBodyTooLarge();
    bytes.add(chunk);
  }
  if (bytes.length == 0 && allowEmpty) return null;
  return jsonDecode(utf8.decode(bytes.takeBytes()));
}
