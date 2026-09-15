// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// 将字节数据包装为浏览器 blob: URL，供 video/image 等原生元素加载。
String createBlobUrl(Uint8List bytes, String mimeType) =>
    html.Url.createObjectUrlFromBlob(html.Blob([bytes], mimeType));

/// 释放 blob URL 引用的内存，使用完毕后必须调用。
void revokeBlobUrl(String url) => html.Url.revokeObjectUrl(url);
