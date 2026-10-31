import 'dart:typed_data';

String? fileUri(String path) => null;
Future<Uint8List?> readFile(Uri uri) async => null;
Future<String?> persistFiles(
  Map<String, Uint8List> files,
  String manifestPath,
) async => null;
Future<String?> appendFiles(
  String baseUri,
  Map<String, Uint8List> files,
) async => null;
