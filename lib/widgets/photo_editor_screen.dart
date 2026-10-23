import 'dart:async';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/data/sdk_media_service.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/ai_image_service.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/photo_editor_history.dart';
import 'package:aboutme/widgets/pixel_eraser_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:photo_manager/photo_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:universal_platform/universal_platform.dart';

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

/// 编辑器退出结果（bytes 为空表示取消/丢弃）
class _EditorExit {
  const _EditorExit({
    required this.bytes,
    this.savedInEditor = false,
    this.savedPath,
  });

  final Uint8List? bytes;

  /// 返回前已在编辑器内完成保存（返回时选择"保存"的路径）
  final bool savedInEditor;

  final String? savedPath;
}

/// 多图编辑项：每张图独立的 url 与保存配置
class PhotoEditorItem {
  const PhotoEditorItem({required this.url, this.savePath, this.name});

  final String url;

  /// 目标保存路径（空=提交时弹保存询问，保存到 app_data/editor/）
  final String? savePath;

  /// 显示名（默认取 url basename）
  final String? name;
}

/// 多图批量编辑：底部缩略图条切换实例，每张图独立编辑。
/// 多图模式下提交导出（编辑器右上完成）立即保存该图
/// （savePath 直写或弹保存目标询问），编辑器不关闭可继续下一张；
/// 切换图片时未提交的编辑丢弃（有确认提示）。
Future<void> showPhotoEditorList(
  BuildContext context, {
  required List<PhotoEditorItem> items,
  int initialIndex = 0,
}) async {
  if (items.isEmpty) return;
  await NavigationHelper.push(
    context,
    _PhotoEditorScreen(
      imageUrl: items.first.url,
      savePath: items.first.savePath,
      items: items,
      initialIndex: initialIndex,
    ),
  );
}

/// 照片编辑器组件（包装 pro_image_editor）：
/// 解析任意来源图片（网络 URL / assets / 本地文件 / 应用存储相对路径）
/// 为字节后打开内置编辑器。
///
/// [savePath] 为可选的目标保存路径（文件完整路径：相对 app_data 如
/// 'editor/x.png'，或本地绝对路径）：
/// - 传入：提交后直接写入该路径，不弹保存询问
/// - 未传入：提交后弹"是否保存"询问（保存=存副本到 app_data/editor/，
///   不保存=丢弃）；返回时有未保存编辑同样弹询问（保存=导出存副本后关闭）
///
/// 返回 [PhotoEditorResult]（用户取消、丢弃或失败返回 null）。
/// 写回原位（savePath 与 imageUrl 相同）时 url 不变，
/// 调用方需自行 evict 图片缓存后刷新显示。
Future<PhotoEditorResult?> showPhotoEditor(
  BuildContext context, {
  required String imageUrl,
  String? savePath,
}) async {
  final exit = await NavigationHelper.push<_EditorExit>(
    context,
    _PhotoEditorScreen(imageUrl: imageUrl, savePath: savePath),
  );
  final edited = exit?.bytes;
  if (edited == null || edited.isEmpty) return null;

  try {
    // 返回时已在编辑器内保存：直接返回（相册场景 savedPath 为空，toast 已弹）
    if (exit!.savedInEditor) {
      final path = exit.savedPath ?? '';
      if (path.isNotEmpty && context.mounted) {
        Toast.success('${'app_photoEditSavedCopy'.tr}: $path');
      }
      return PhotoEditorResult(
        bytes: edited,
        savedPath: path,
        overwroteOriginal: false,
      );
    }
    if (savePath != null && savePath.isNotEmpty) {
      // 调用方指定保存路径：提交后直接写入
      final savedPath = await _writeToSavePath(savePath, edited);
      if (!context.mounted) return null;
      if (savedPath == imageUrl) {
        Toast.success('app_photoEditSaved'.tr);
      } else {
        Toast.success('${'app_photoEditSavedCopy'.tr}: $savedPath');
      }
      return PhotoEditorResult(
        bytes: edited,
        savedPath: savedPath,
        overwroteOriginal: savedPath == imageUrl,
      );
    }
    // 未指定路径：提交后询问保存目标（软件内部 / 系统相册 / 不保存）
    final target = await _chooseSaveTarget(context, allowCancel: false);
    if (target == _SaveTarget.internal) {
      final savedPath = (await SdkMediaService.uploadBytes(
        edited,
        'photo_editor_${DateTime.now().millisecondsSinceEpoch}${_looksLikePng(edited) ? '.png' : '.jpg'}',
      )).reference;
      // 副本入打开历史，主界面可继续编辑
      unawaited(PhotoEditorHistory.record(savedPath));
      if (context.mounted) {
        Toast.success('${'app_photoEditSavedCopy'.tr}: $savedPath');
      }
      return PhotoEditorResult(
        bytes: edited,
        savedPath: savedPath,
        overwroteOriginal: false,
      );
    }
    if (target == _SaveTarget.album) {
      final ok = await _saveToAlbum(context, edited);
      // savedPath 留空：相册产物不在 app_data（toast 已由保存流程弹出）
      return ok
          ? PhotoEditorResult(
              bytes: edited,
              savedPath: '',
              overwroteOriginal: false,
            )
          : null;
    }
    return null;
  } catch (e) {
    debugPrint('照片编辑保存失败: $e');
    if (context.mounted) Toast.error('app_photoEditSaveFailed'.tr);
    return null;
  }
}

/// 未保存编辑的保存目标
enum _SaveTarget { internal, album, discard, cancel }

/// 保存目标询问：软件内部 / 系统相册（Web 隐藏）/ 不保存 [/ 继续编辑]。
/// [allowCancel] 为 true 时（编辑器还开着）多一个"继续编辑"选项。
Future<_SaveTarget?> _chooseSaveTarget(
  BuildContext context, {
  required bool allowCancel,
}) async {
  return showDialog<_SaveTarget>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('app_photoEditUnsavedTitle'.tr),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, _SaveTarget.internal),
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text('app_photoEditSaveInternal'.tr),
            subtitle: const Text('app_data/editor/'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (!kIsWeb)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _SaveTarget.album),
            child: ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('app_photoEditSaveAlbum'.tr),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, _SaveTarget.discard),
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text('app_photoEditUnsavedDiscard'.tr),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (allowCancel)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _SaveTarget.cancel),
            child: ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('app_photoEditUnsavedCancel'.tr),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    ),
  );
}

/// 保存到系统相册：移动端走 PhotoManager，桌面端退化为另存为文件。
/// 成功返回 true（toast 已弹）。
Future<bool> _saveToAlbum(BuildContext context, Uint8List bytes) async {
  final name =
      'photo_editor_${DateTime.now().millisecondsSinceEpoch}'
      '${_looksLikePng(bytes) ? '.png' : '.jpg'}';
  try {
    if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
      final state = await PhotoManager.requestPermissionExtend();
      if (!state.hasAccess) {
        if (context.mounted) Toast.error('app_stickerNoPermission'.tr);
        return false;
      }
      await PhotoManager.editor.saveImage(bytes, filename: name, title: name);
      if (context.mounted) Toast.success('app_stickerSavedAlbum'.tr);
      return true;
    }
    // 桌面端无系统相册：另存为文件
    final savePath = await FilePicker.platform.saveFile(
      fileName: name,
      type: FileType.image,
    );
    if (savePath == null) return false;
    final ext = path.extension(name);
    final file = File(
      savePath.toLowerCase().endsWith(ext) ? savePath : '$savePath$ext',
    );
    await file.writeAsBytes(bytes, flush: true);
    if (context.mounted) {
      Toast.success('${'app_photoEditSavedCopy'.tr}: ${file.path}');
    }
    return true;
  } catch (e) {
    debugPrint('保存到相册失败: $e');
    if (context.mounted) Toast.error('app_photoEditSaveFailed'.tr);
    return false;
  }
}

/// 写入指定保存路径：绝对路径直接写文件，其余按 app_data 相对路径走存储后端
Future<String> _writeToSavePath(String savePath, Uint8List bytes) async {
  final normalized = savePath.replaceAll(r'\', '/');
  if (!kIsWeb &&
      (normalized.startsWith('/') ||
          RegExp(r'^[A-Za-z]:/').hasMatch(normalized))) {
    final file = File(normalized);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return normalized;
  }
  final rel = normalized.startsWith('./')
      ? normalized.substring(2)
      : normalized;
  if (ImageUtils.sdkAssetId(savePath) != null) return savePath;
  await globalStorage.writeBytes(rel, bytes);
  return './$rel';
}

/// PNG 魔数（0x89 50 4E 47）探测
bool _looksLikePng(Uint8List bytes) =>
    bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;

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

/// 编辑器全屏页：进入时加载图片字节（loading/错误占位），完成后交给 ProImageEditor
class _PhotoEditorScreen extends StatefulWidget {
  const _PhotoEditorScreen({
    required this.imageUrl,
    this.savePath,
    this.items,
    this.initialIndex = 0,
  });

  final String imageUrl;

  /// 目标保存路径（空=提交/返回时弹保存询问，保存到默认 app_data/editor/）
  final String? savePath;

  /// 多图编辑项（空=单图模式，仅 imageUrl/savePath）
  final List<PhotoEditorItem>? items;

  /// 多图初始索引
  final int initialIndex;

  @override
  State<_PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

/// 单张图的画布状态（多图时每张独立）
class _CanvasState {
  Uint8List? bytes;
  bool loadFailed = false;
  bool hasAlpha = false;

  /// 字节被修改过（切换烘焙 / AI 修图 / 橡皮擦 / 提交保存），
  /// "全部导出"据此挑选待保存画布
  bool touched = false;

  /// 本次会话已保存到目标（提交导出或全部导出处理过）
  bool saved = false;
  GlobalKey<ProImageEditorState> editorKey = GlobalKey<ProImageEditorState>();
}

class _PhotoEditorScreenState extends State<_PhotoEditorScreen> {
  late final List<PhotoEditorItem> _items =
      widget.items ??
      [PhotoEditorItem(url: widget.imageUrl, savePath: widget.savePath)];
  late final List<_CanvasState> _canvases = List.generate(
    _items.length,
    (_) => _CanvasState(),
  );
  late int _index = widget.initialIndex.clamp(0, _items.length - 1);

  /// 多图导出保存进行中（防重复触发提交）
  bool _savingExport = false;

  _CanvasState get _canvas => _canvases[_index];
  bool get _isMulti => _items.length > 1;

  /// 返回时选择"保存"的暂存结果（onCloseEditor pop 带出）
  _EditorExit? _closeExit;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  /// AI 修图：以当前画布为参考图生成新图，替换后重建编辑器
  Future<void> _openAiEdit() async {
    final bytes = _canvas.bytes;
    if (bytes == null) return;
    final generated = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AiEditDialog(imageBytes: bytes),
    );
    if (generated == null || !mounted) return;
    setState(() {
      _canvas.bytes = generated;
      _canvas.editorKey = GlobalKey<ProImageEditorState>();
      _canvas.touched = true;
    });
  }

  /// 像素橡皮擦：涂抹擦除图片本体为透明，完成后替换画布
  Future<void> _openPixelEraser() async {
    final bytes = _canvas.bytes;
    if (bytes == null) return;
    final erased = await NavigationHelper.push<Uint8List>(
      context,
      PixelEraserPage(imageBytes: bytes),
    );
    if (erased == null || !mounted) return;
    setState(() {
      _canvas.bytes = erased;
      _canvas.editorKey = GlobalKey<ProImageEditorState>();
      _canvas.hasAlpha = true;
      _canvas.touched = true;
    });
  }

  Future<void> _loadCurrent() async {
    final canvas = _canvas;
    final bytes = await _loadImageBytes(_items[_index].url);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      setState(() => canvas.loadFailed = true);
      Toast.error('app_photoEditLoadFailed'.tr);
    } else {
      // 记录打开历史（编辑器主界面"最近打开"用）
      unawaited(PhotoEditorHistory.record(_items[_index].url));
      setState(() => canvas.bytes = bytes);
    }
  }

  /// 把当前编辑器中未提交的编辑烘焙进画布字节：
  /// 效果保留（切回可见），编辑历史随实例重建重置。
  /// 无编辑返回 true；导出失败返回 false（调用方走丢弃确认）。
  Future<bool> _bakeCurrent() async {
    final editor = _canvas.editorKey.currentState;
    if (editor == null || !editor.canUndo) return true;
    try {
      final bytes = await editor.captureEditorImage();
      if (bytes.isEmpty) throw Exception('导出为空');
      _canvas.bytes = bytes;
      _canvas.touched = true;
      return true;
    } catch (e) {
      debugPrint('烘焙当前画布失败: $e');
      return false;
    }
  }

  /// 切换当前编辑的图片；未提交的编辑先烘焙进画布（不丢失），
  /// 烘焙失败才弹丢弃确认。
  Future<void> _switchTo(int index) async {
    if (index == _index || index < 0 || index >= _items.length) return;
    final baked = await _bakeCurrent();
    if (!baked) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('app_photoEditorSwitchTitle'.tr),
          content: Text('app_photoEditorSwitchMessage'.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('app_cancel'.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('app_confirm'.tr),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    setState(() => _index = index);
    final target = _canvases[index];
    if (target.bytes == null && !target.loadFailed) await _loadCurrent();
  }

  /// 多图模式提交导出：立即保存该图（savePath 直写或询问目标），
  /// 保存后重置当前画布继续编辑；询问"继续编辑"则不动。
  Future<void> _saveCurrentExport(Uint8List bytes) async {
    if (_savingExport) return;
    _savingExport = true;
    var resetCanvas = true;
    try {
      final item = _items[_index];
      if (item.savePath != null && item.savePath!.isNotEmpty) {
        await _writeToSavePath(item.savePath!, bytes);
        if (mounted) Toast.success('app_photoEditSaved'.tr);
      } else {
        final target = await _chooseSaveTarget(context, allowCancel: true);
        if (target == null || target == _SaveTarget.cancel) {
          resetCanvas = false;
          return;
        }
        if (target == _SaveTarget.internal) {
          final rel = (await SdkMediaService.uploadBytes(
            bytes,
            'photo_editor_${DateTime.now().millisecondsSinceEpoch}${_looksLikePng(bytes) ? '.png' : '.jpg'}',
          )).reference;
          unawaited(PhotoEditorHistory.record(rel));
          if (mounted) {
            Toast.success('${'app_photoEditSavedCopy'.tr}: $rel');
          }
        } else if (target == _SaveTarget.album) {
          await _saveToAlbum(context, bytes);
        }
        // discard：不保存，仅重置画布
      }
      _canvas.saved = true;
      _canvas.touched = true;
    } catch (e) {
      debugPrint('照片编辑保存失败: $e');
      if (mounted) Toast.error('app_photoEditSaveFailed'.tr);
    } finally {
      _savingExport = false;
      if (mounted && resetCanvas) {
        // 保存完成重置当前画布编辑历史（画布内容 = 已保存结果）
        setState(() => _canvas.editorKey = GlobalKey<ProImageEditorState>());
      }
    }
  }

  /// 全部导出：烘焙当前画布后，把所有被修改过且未保存的画布
  /// 逐张保存（savePath 直写；无 savePath 的统一弹一次保存目标询问）。
  Future<void> _exportAll() async {
    if (_savingExport) return;
    await _bakeCurrent();
    final targets = <int>[
      for (var i = 0; i < _canvases.length; i++)
        if (_canvases[i].bytes != null &&
            _canvases[i].touched &&
            !_canvases[i].saved)
          i,
    ];
    if (targets.isEmpty) {
      Toast.info('app_photoEditorExportNone'.tr);
      return;
    }

    // 存在无 savePath 的目标时统一询问一次保存目标
    final needAsk = targets.any(
      (i) => _items[i].savePath == null || _items[i].savePath!.isEmpty,
    );
    _SaveTarget? target;
    if (needAsk) {
      target = await _chooseSaveTarget(context, allowCancel: true);
      if (target == null || target == _SaveTarget.cancel) return;
      if (target == _SaveTarget.discard) return;
    }

    _savingExport = true;
    var ok = 0;
    try {
      for (final i in targets) {
        final item = _items[i];
        final canvas = _canvases[i];
        final bytes = canvas.bytes!;
        try {
          if (item.savePath != null && item.savePath!.isNotEmpty) {
            await _writeToSavePath(item.savePath!, bytes);
          } else if (target == _SaveTarget.internal) {
            final rel = (await SdkMediaService.uploadBytes(
              bytes,
              'photo_editor_${DateTime.now().millisecondsSinceEpoch}${_looksLikePng(bytes) ? '.png' : '.jpg'}',
            )).reference;
            unawaited(PhotoEditorHistory.record(rel));
          } else if (target == _SaveTarget.album) {
            await _saveToAlbum(context, bytes);
          }
          canvas.saved = true;
          ok++;
        } catch (e) {
          debugPrint('全部导出第 ${i + 1} 张失败: $e');
        }
      }
    } finally {
      _savingExport = false;
    }
    if (!mounted) return;
    setState(() {
      // 当前画布已导出：重置编辑历史
      if (_canvases[_index].saved) {
        _canvas.editorKey = GlobalKey<ProImageEditorState>();
      }
    });
    Toast.success('app_photoEditorExported'.trParams({'n': '$ok'}));
  }

  @override
  Widget build(BuildContext context) {
    if (_canvas.loadFailed) {
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

    final bytes = _canvas.bytes;
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
        key: _canvas.editorKey,
        configs: ProImageEditorConfigs(
          i18n: _buildI18n(),
          // 擦除后画布含透明，导出必须 PNG（JPG 无 alpha 会压黑）
          imageGeneration: ImageGenerationConfigs(
            outputFormat: _canvas.hasAlpha
                ? OutputFormat.png
                : OutputFormat.jpg,
          ),
          mainEditor: MainEditorConfigs(
            widgets: MainEditorWidgets(
              // AI 修图 / 像素橡皮擦浮动入口 + 多图缩略图条：
              // 子编辑器（裁剪/滤镜等）打开时隐藏
              wrapBody: (editor, rebuildStream, content) => Stack(
                children: [
                  content,
                  Positioned(
                    right: 14,
                    bottom: 96,
                    child: ReactiveWidget(
                      stream: rebuildStream,
                      builder: (_) => editor.isSubEditorOpen
                          ? const SizedBox.shrink()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildAiFab(),
                                const SizedBox(height: 12),
                                _buildEraserFab(),
                              ],
                            ),
                    ),
                  ),
                  if (_isMulti)
                    Positioned(
                      left: 12,
                      right: 84,
                      bottom: 14,
                      child: ReactiveWidget(
                        stream: rebuildStream,
                        builder: (_) => editor.isSubEditorOpen
                            ? const SizedBox.shrink()
                            : _buildThumbBar(),
                      ),
                    ),
                ],
              ),
              // 未指定保存路径：返回时的关闭警告替换为保存询问
              //（保存=导出存副本；多图模式走编辑器自带丢弃警告，
              //  保存已在每张图提交导出时完成）
              closeWarningDialog: !_isMulti && widget.savePath == null
                  ? _customCloseWarning
                  : null,
            ),
          ),
        ),
        callbacks: ProImageEditorCallbacks(
          // 单图：导出即关闭，由 showPhotoEditor 走保存流程；
          // 多图：导出立即保存当前图，留在编辑器继续
          onImageEditingComplete: (editedBytes) async {
            if (!_isMulti) {
              Navigator.of(context).pop(_EditorExit(bytes: editedBytes));
              return;
            }
            unawaited(_saveCurrentExport(editedBytes));
          },
          // 设置了该回调时编辑器不会自行 pop，由这里统一关闭
          onCloseEditor: (mode) => Navigator.of(context).pop(_closeExit),
        ),
      ),
    );
  }

  /// 多图缩略图条：横向切换当前编辑的图片（当前项白框高亮，
  /// 已保存绿勾 / 待导出橙点角标），尾部"全部导出"
  Widget _buildThumbBar() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // 尾部：全部导出
          if (index == _items.length) {
            return GestureDetector(
              onTap: _exportAll,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white38),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.done_all, color: Colors.white70, size: 18),
                    const SizedBox(height: 2),
                    Text(
                      'app_photoEditorExportAll'.tr,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            );
          }
          final selected = index == _index;
          final canvas = _canvases[index];
          return GestureDetector(
            onTap: () => _switchTo(index),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 52,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: ImageUtils.createImageProvider(
                          _items[index].url,
                        ),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Colors.white24,
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white38,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 3,
                        top: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      // 已保存绿勾 / 待导出橙点
                      if (canvas.saved)
                        const Positioned(
                          right: 3,
                          top: 3,
                          child: Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.greenAccent,
                          ),
                        )
                      else if (canvas.touched)
                        const Positioned(
                          right: 5,
                          top: 5,
                          child: SizedBox.square(
                            dimension: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 返回且有未保存编辑：选择保存目标（软件内部/相册）后导出关闭，
  /// 不保存=丢弃关闭，继续编辑=留在编辑器。
  /// 导出走 captureEditorImage（与提交导出同一管线）。
  Future<bool> _customCloseWarning(ProImageEditorState editor) async {
    final target = await _chooseSaveTarget(context, allowCancel: true);
    if (target == null || target == _SaveTarget.cancel) return false;
    if (target == _SaveTarget.discard) return true;
    try {
      final bytes = await editor.captureEditorImage();
      if (bytes.isEmpty) throw Exception('导出为空');
      if (target == _SaveTarget.internal) {
        final rel = await ImageUtils.saveBytesToAppDirectory(
          bytes,
          'editor',
          extension: _looksLikePng(bytes) ? '.png' : '.jpg',
        );
        _closeExit = _EditorExit(
          bytes: bytes,
          savedInEditor: true,
          savedPath: rel,
        );
      } else {
        // 相册：toast 由保存流程弹出，savedPath 置空
        final ok = await _saveToAlbum(context, bytes);
        if (!ok) return false;
        _closeExit = _EditorExit(
          bytes: bytes,
          savedInEditor: true,
          savedPath: '',
        );
      }
      return true;
    } catch (e) {
      debugPrint('照片编辑返回导出失败: $e');
      if (mounted) Toast.error('app_photoEditSaveFailed'.tr);
      return false;
    }
  }

  /// AI 修图浮动按钮（Web 无本地文件供服务上传，点击仅提示）
  Widget _buildAiFab() {
    return FloatingActionButton.small(
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      foregroundColor: Colors.white,
      tooltip: 'app_aiEdit'.tr,
      onPressed: kIsWeb
          ? () => Toast.error('app_aiEditWebUnsupported'.tr)
          : _openAiEdit,
      child: const Icon(Icons.auto_fix_high, size: 20),
    );
  }

  /// 像素橡皮擦浮动按钮
  Widget _buildEraserFab() {
    return FloatingActionButton.small(
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      foregroundColor: Colors.white,
      tooltip: 'app_pixelEraser'.tr,
      onPressed: _openPixelEraser,
      child: const Icon(Icons.cleaning_services_outlined, size: 20),
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

/// AI 修图对话框：输入修改指令，复用工具箱图生图服务
/// （当前画布落临时文件作为参考图），成功后 pop 返回新图字节
class _AiEditDialog extends StatefulWidget {
  const _AiEditDialog({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_AiEditDialog> createState() => _AiEditDialogState();
}

class _AiEditDialogState extends State<_AiEditDialog> {
  /// 自定义预设与上次 prompt 的持久化位置（随本地/远端存储）
  static const _configPath = 'configs/photo_editor/ai_edit_config.json';

  /// 内置快捷指令预设键（文案在 zh/en 翻译文件，跟随界面语言）
  static const _builtinPresetKeys = [
    'app_aiEditPreset_deblur',
    'app_aiEditPreset_denoise',
    'app_aiEditPreset_recolor',
    'app_aiEditPreset_colorize',
    'app_aiEditPreset_restore',
    'app_aiEditPreset_removePeople',
    'app_aiEditPreset_anime',
    'app_aiEditPreset_bgClean',
  ];

  final TextEditingController _input = TextEditingController();

  /// 用户自定义预设（原文保存，跨语言直接使用）
  final List<String> _customPresets = [];

  bool _running = false;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final data = await AboutmeDataService.instance.readPath(_configPath);
      if (!mounted || data is! Map<String, dynamic>) return;
      final presets =
          (data['presets'] as List?)?.whereType<String>().toList() ?? [];
      final last = data['lastPrompt'] as String?;
      setState(() {
        _customPresets.addAll(presets);
        if (last != null && last.isNotEmpty && _input.text.isEmpty) {
          _input.text = last;
        }
      });
    } catch (_) {
      /* 配置读取失败走纯内置预设 */
    }
  }

  Future<void> _saveConfig() async {
    try {
      await AboutmeDataService.instance.writePath(_configPath, {
        'presets': _customPresets,
        'lastPrompt': _input.text.trim(),
      });
    } catch (_) {
      /* 保存失败不影响主流程 */
    }
  }

  /// 把输入框当前指令保存为自定义预设
  void _addCustomPreset() {
    final text = _input.text.trim();
    if (text.isEmpty) {
      Toast.error('app_aiEditPresetEmpty'.tr);
      return;
    }
    final exists =
        _customPresets.contains(text) ||
        _builtinPresetKeys.any((k) => k.tr == text);
    if (exists) {
      Toast.error('app_aiEditPresetExists'.tr);
      return;
    }
    setState(() => _customPresets.add(text));
    unawaited(_saveConfig());
    Toast.success('app_aiEditPresetAdded'.tr);
  }

  void _removeCustomPreset(String preset) {
    setState(() => _customPresets.remove(preset));
    unawaited(_saveConfig());
  }

  /// 预设填入输入框（光标移到末尾，便于追加细节）
  void _applyPreset(String prompt) {
    if (_running) return;
    _input.text = prompt;
    _input.selection = TextSelection.collapsed(offset: prompt.length);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _input.text.trim();
    if (prompt.isEmpty || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _status = null;
    });
    File? refFile;
    try {
      // 服务仅接受本地绝对路径/URL，画布字节先落临时文件
      refFile = File(
        '${Directory.systemTemp.path}'
        '/photo_editor_ai_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await refFile.writeAsBytes(widget.imageBytes, flush: true);

      final result = await AiImageService.instance.generate(
        prompt: prompt,
        refImages: [refFile.path],
        aspectRatio: await _closestAspectRatio(widget.imageBytes),
        returnBytes: true,
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      if (!result.success) {
        throw Exception(result.error ?? result.message ?? '未知错误');
      }
      final images = result.data?['images'] as List?;
      final bytes = images != null && images.isNotEmpty
          ? (images.first as GeneratedImage).bytes
          : null;
      if (bytes == null || bytes.isEmpty) throw Exception('未返回图片字节');
      // 记住这次成功的指令，下次打开对话框预填
      unawaited(_saveConfig());
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _running = false;
        });
      }
    } finally {
      try {
        await refFile?.delete();
      } catch (_) {
        /* 临时文件清理失败忽略 */
      }
    }
  }

  /// 依据原图宽高比选择服务预设中最接近的比例，避免修图后画布变形
  Future<String?> _closestAspectRatio(Uint8List bytes) async {
    try {
      // 此处 decodeImageFromList 为 pro_image_editor 导出的 Future 版本
      final image = await decodeImageFromList(
        bytes,
      ).timeout(const Duration(seconds: 5));
      final target = image.width / image.height;
      const presets = {
        '1:1': 1.0,
        '16:9': 16 / 9,
        '9:16': 9 / 16,
        '4:3': 4 / 3,
        '3:4': 3 / 4,
        '3:2': 1.5,
        '2:3': 2 / 3,
      };
      var best = '1:1';
      var bestDiff = double.infinity;
      presets.forEach((name, value) {
        final diff = (value - target).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          best = name;
        }
      });
      return best;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 生成中禁止关闭（结果即回，取消会浪费一次生成）
      canPop: !_running,
      child: AlertDialog(
        title: Text('app_aiEdit'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _input,
              enabled: !_running,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'app_aiEditHint'.tr,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _generate(),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final key in _builtinPresetKeys)
                  ActionChip(
                    label: Text(key.tr, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: _running ? null : () => _applyPreset(key.tr),
                  ),
                // 自定义预设：带 x 可删除
                for (final preset in _customPresets)
                  InputChip(
                    label: Text(preset, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: _running ? null : () => _applyPreset(preset),
                    onDeleted: _running
                        ? null
                        : () => _removeCustomPreset(preset),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(
                    'app_aiEditPresetAdd'.tr,
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: _running ? null : _addCustomPreset,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'app_aiEditNote'.tr,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.orange),
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _running ? null : () => Navigator.of(context).pop(),
            child: Text('app_cancel'.tr),
          ),
          FilledButton(
            onPressed: _running ? null : _generate,
            child: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('app_aiEditGenerate'.tr),
          ),
        ],
      ),
    );
  }
}
