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

/// 照片编辑结果：导出字节 + 保存路径
/// （[overwroteOriginal] 为 true 时已覆盖写回原图位置，路径未变）
class PhotoEditorResult {
  const PhotoEditorResult({
    required this.bytes,
    required this.savedPath,
    required this.overwroteOriginal,
  });

  /// 编辑导出的图片字节
  final Uint8List bytes;

  /// 保存路径（写回原位 = 原 url；网络/Asset 无法写回时为副本新路径）
  final String savedPath;

  /// 是否覆盖写回原图位置
  final bool overwroteOriginal;
}

/// 照片编辑器组件（包装 pro_image_editor）：
/// 解析任意来源图片（网络 URL / assets / 本地文件 / 应用存储相对路径）
/// 为字节后打开内置编辑器；导出结果优先覆盖写回原位置
/// （本地文件 / 应用存储），无法写回的网络/Asset 图片保存副本到 './editor/'。
///
/// 返回 [PhotoEditorResult]（用户取消或失败返回 null）。
/// 写回原位时 url 不变，调用方需自行 evict 图片缓存后刷新显示。
Future<PhotoEditorResult?> showPhotoEditor(
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
    if (!context.mounted) return null;
    if (savedPath == imageUrl) {
      Toast.success('app_photoEditSaved'.tr);
    } else if (savedPath != null) {
      Toast.success('${'app_photoEditSavedCopy'.tr}: $savedPath');
    }
    return PhotoEditorResult(
      bytes: edited,
      savedPath: savedPath ?? imageUrl,
      overwroteOriginal: savedPath == imageUrl,
    );
  } catch (e) {
    debugPrint('照片编辑保存失败: $e');
    if (context.mounted) Toast.error('app_photoEditSaveFailed'.tr);
    return null;
  }
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
        configs: ProImageEditorConfigs(i18n: _buildI18n()),
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

  /// 中文环境下覆写编辑器 UI 文案（默认英文）；
  /// 滤镜名为专有名词（Aden/Amaro 等），保留英文
  I18n _buildI18n() {
    if ((Get.locale?.languageCode ?? 'zh') != 'zh') return const I18n();
    return const I18n(
      importStateHistoryMsg: '初始化编辑器',
      cancel: '取消',
      undo: '撤销',
      redo: '重做',
      done: '完成',
      remove: '移除',
      doneLoadingMsg: '正在应用更改',
      various: I18nVarious(
        loadingDialogMsg: '请稍候...',
        closeEditorWarningTitle: '关闭图片编辑器？',
        closeEditorWarningMessage: '确定要关闭编辑器吗？未保存的更改将会丢失。',
        closeEditorWarningConfirmBtn: '确定',
        closeEditorWarningCancelBtn: '取消',
      ),
      layerInteraction: I18nLayerInteraction(
        remove: '移除',
        edit: '编辑',
        rotateScale: '旋转和缩放',
      ),
      paintEditor: I18nPaintEditor(
        moveAndZoom: '缩放',
        bottomNavigationBarText: '画笔',
        freestyle: '自由绘制',
        freestyleArrowStart: '箭头（起点）',
        freestyleArrowEnd: '箭头（终点）',
        freestyleArrowStartEnd: '双向箭头',
        arrow: '箭头',
        line: '直线',
        rectangle: '矩形',
        circle: '圆形',
        dashLine: '虚线',
        dashDotLine: '点划线',
        hexagon: '六边形',
        polygon: '多边形',
        blur: '模糊',
        pixelate: '像素化',
        lineWidth: '线宽',
        eraser: '橡皮擦',
        toggleFill: '切换填充',
        changeOpacity: '调整不透明度',
        opacity: '不透明度',
        color: '颜色',
        strokeWidth: '笔画宽度',
        fill: '填充',
        back: '返回',
        done: '完成',
        undo: '撤销',
        redo: '重做',
        cancel: '取消',
        smallScreenMoreTooltip: '更多',
      ),
      textEditor: I18nTextEditor(
        inputHintText: '输入文字',
        bottomNavigationBarText: '文字',
        back: '返回',
        done: '完成',
        textAlign: '对齐方式',
        fontScale: '字体大小',
        backgroundMode: '背景模式',
        smallScreenMoreTooltip: '更多',
      ),
      cropRotateEditor: I18nCropRotateEditor(
        bottomNavigationBarText: '裁剪/旋转',
        rotate: '旋转',
        flip: '翻转',
        tilt: '倾斜',
        tiltRotate: '旋转',
        tiltHorizontal: '水平',
        tiltVertical: '垂直',
        ratio: '比例',
        back: '返回',
        done: '完成',
        cancel: '取消',
        undo: '撤销',
        redo: '重做',
        reset: '重置',
        smallScreenMoreTooltip: '更多',
      ),
      tuneEditor: I18nTuneEditor(
        bottomNavigationBarText: '调整',
        back: '返回',
        done: '完成',
        brightness: '亮度',
        contrast: '对比度',
        saturation: '饱和度',
        exposure: '曝光',
        hue: '色相',
        temperature: '色温',
        fade: '褪色',
        tint: '色调',
        undo: '撤销',
        redo: '重做',
      ),
      filterEditor: I18nFilterEditor(
        bottomNavigationBarText: '滤镜',
        back: '返回',
        done: '完成',
        filters: I18nFilters(none: '无滤镜'),
      ),
      blurEditor: I18nBlurEditor(
        bottomNavigationBarText: '模糊',
        back: '返回',
        done: '完成',
      ),
      emojiEditor: I18nEmojiEditor(
        bottomNavigationBarText: '表情',
        search: '搜索',
        categoryRecent: '最近',
        categorySmileys: '笑脸',
        categoryAnimals: '动物与自然',
        categoryFood: '食物与饮品',
        categoryActivities: '活动',
        categoryTravel: '旅行与地点',
        categoryObjects: '物品',
        categorySymbols: '符号',
        categoryFlags: '旗帜',
      ),
      stickerEditor: I18nStickerEditor(bottomNavigationBarText: '贴纸'),
    );
  }
}
