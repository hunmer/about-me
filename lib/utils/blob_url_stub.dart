import 'dart:typed_data';

/// 非 Web 平台 stub：blob URL 仅在浏览器中存在。
String createBlobUrl(Uint8List bytes, String mimeType) =>
    throw UnsupportedError('createBlobUrl 仅支持 Web 平台');

void revokeBlobUrl(String url) {}

/// 非 Web 平台无操作
void reloadPage() {}

Future<Uint8List> readBlobBytes(String url) =>
    throw UnsupportedError('readBlobBytes 仅支持 Web 平台');
