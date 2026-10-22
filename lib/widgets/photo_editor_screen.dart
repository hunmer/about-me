import 'dart:io';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:pro_image_editor/pro_image_editor.dart';

/// 照片编辑器组件（包装 pro_image_editor）：
/// 解析任意来源图片（网络 URL / assets / 本地文件 / 应用存储相对路径）
/// 为字节后打开内置编辑器；导出结果优先覆盖写回原位置
/// （本地文件 / 应用存储），无法写回的网络/Asset 图片保存副本到 './editor/'。
///
/// 返回导出的图片字节（用户取消或失败返回 null）。
/// 写回原位时 url 不变，调用方需自行 evict 图片缓存后刷新显示。
Future<Uint8List?> showPhotoEditor(
  BuildContext context, {
  required String imageUrl,
}) async {
  final edited = await NavigationHelper.push<Uint8List>(
    context,
    _PhotoEditorScreen(imageUrl: imageUrl),
  );
  if (edited == null) return null;

  try {
    final savedPath = await _persistEdited(imageUrl, edited);
    if (!context.mounted) return edited;
    if (savedPath == imageUrl) {
      Toast.success('app_photoEditSaved'.tr);
    } else if (savedPath != null) {
      Toast.success('${'app_photoEditSavedCopy'.tr}: $savedPath');
    }
  } catch (e) {
    debugPrint('照片编辑保存失败: $e');
    if (context.mounted) Toast.error('app_photoEditSaveFailed'.tr);
  }
  return edited;
}

/// 读取任意来源图片字节：网络下载 / asset 加载 / 存储读取 / 本地文件读取
Future<Uint8List?> _loadImageBytes(String url) async {
  try {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      return res.bodyBytes;
    }
    if (url.startsWith('assets/')) {
      final data = await rootBundle.load(url);
      return data.buffer.asUint8List();
    }
    // 应用存储相对路径（Web=IndexedDB；本地/远端=存储后端，远端物化前读不到文件）
    if (kIsWeb || url.startsWith('./')) {
      final bytes = await ImageUtils.readStorageBytes(url);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }
    if (!kIsWeb) {
      final absolutePath = await ImageUtils.getAbsolutePath(url);
      if (absolutePath.isNotEmpty) {
        final file = File(absolutePath);
        if (await file.exists()) return await file.readAsBytes();
      }
    }
    return null;
  } catch (e) {
    debugPrint('照片编辑读取图片失败: $e');
    return null;
  }
}

/// 持久化编辑结果：返回保存路径（与 [url] 相同表示覆盖写回原位），
/// 保存副本时返回新路径，失败抛异常
Future<String?> _persistEdited(String url, Uint8List bytes) async {
  final isHttp = url.startsWith('http://') || url.startsWith('https://');
  final isAsset = url.startsWith('assets/');
  if (!isHttp && !isAsset) {
    final storagePath = url.startsWith('./')
        ? url.substring(2).replaceAll(r'\', '/')
        : null;
    // Web / 远端存储：经全局存储后端写回原位
    if (storagePath != null && (kIsWeb || globalStorage.isRemote)) {
      await globalStorage.writeBytes(storagePath, bytes);
      return url;
    }
    // 本地模式：覆盖本地文件
    if (!kIsWeb) {
      final absolutePath = await ImageUtils.getAbsolutePath(url);
      if (absolutePath.isNotEmpty && !absolutePath.startsWith('http')) {
        final file = File(absolutePath);
        if (await file.exists()) {
          await file.writeAsBytes(bytes, flush: true);
          return url;
        }
      }
    }
  }
  // 无法写回原位（网络/Asset/本地文件缺失）：保存副本到应用存储
  return ImageUtils.saveBytesToAppDirectory(bytes, 'editor');
}

/// 编辑器全屏页：进入时加载图片字节（loading/错误占位），完成后交给 ProImageEditor
class _PhotoEditorScreen extends StatefulWidget {
  const _PhotoEditorScreen({required this.imageUrl});

  final String imageUrl;

  @override
  State<_PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<_PhotoEditorScreen> {
  Uint8List? _bytes;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await _loadImageBytes(widget.imageUrl);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _loadFailed = true);
      Toast.error('app_photoEditLoadFailed'.tr);
    } else {
      setState(() => _bytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.white38),
              const SizedBox(height: 16),
              Text(
                'app_photoEditLoadFailed'.tr,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: ProImageEditor.memory(
        bytes,
        callbacks: ProImageEditorCallbacks(
          // 编辑器导出期间保持自带 loading 遮罩，pop 后由 showPhotoEditor 持久化
          onImageEditingComplete: (editedBytes) async {
            Navigator.of(context).pop(editedBytes);
          },
          // 设置了该回调时编辑器不会自行 pop，由这里统一关闭
          onCloseEditor: (mode) => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
