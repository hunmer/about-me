// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// 将字节数据包装为浏览器 blob: URL，供 video/image 等原生元素加载。
String createBlobUrl(Uint8List bytes, String mimeType) =>
    html.Url.createObjectUrlFromBlob(html.Blob([bytes], mimeType));

/// 释放 blob URL 引用的内存，使用完毕后必须调用。
void revokeBlobUrl(String url) => html.Url.revokeObjectUrl(url);

/// 刷新当前页面（配置变更后重新初始化应用）
void reloadPage() => html.window.location.reload();

/// 读取 blob: URL 的字节内容（如录音返回的 blob 地址）
Future<Uint8List> readBlobBytes(String url) async {
  final response = await html.window.fetch(url);
  final blob = await response.blob();
  final reader = html.FileReader();
  reader.readAsArrayBuffer(blob);
  await reader.onLoadEnd.first;
  return reader.result as Uint8List;
}
