import 'dart:async';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart';
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
      final savedPath = await ImageUtils.saveBytesToAppDirectory(
        edited,
        'editor',
        // 擦除产物为 PNG（保留透明），按魔数判断扩展名
        extension: _looksLikePng(edited) ? '.png' : '.jpg',
      );
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
  const _PhotoEditorScreen({required this.imageUrl, this.savePath});

  final String imageUrl;

  /// 目标保存路径（空=提交/返回时弹保存询问，保存到默认 app_data/editor/）
  final String? savePath;

  @override
  State<_PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<_PhotoEditorScreen> {
  Uint8List? _bytes;
  bool _loadFailed = false;

  /// 编辑器 state 引用（返回时导出画布用）；
  /// AI 修图替换画布时换新实例整体重建（编辑历史随之重置）
  GlobalKey<ProImageEditorState> _editorKey = GlobalKey<ProImageEditorState>();

  /// 返回时选择"保存"的暂存结果（onCloseEditor pop 带出）
  _EditorExit? _closeExit;

  /// 画布是否含透明像素（橡皮擦擦除后置 true）：
  /// 编辑器导出格式随之切 PNG，避免透明被 JPG 压黑
  bool _canvasHasAlpha = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// AI 修图：以当前画布为参考图生成新图，替换后重建编辑器
  Future<void> _openAiEdit() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final generated = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AiEditDialog(imageBytes: bytes),
    );
    if (generated == null || !mounted) return;
    setState(() {
      _bytes = generated;
      _editorKey = GlobalKey<ProImageEditorState>();
    });
  }

  /// 像素橡皮擦：涂抹擦除图片本体为透明，完成后替换画布
  Future<void> _openPixelEraser() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final erased = await NavigationHelper.push<Uint8List>(
      context,
      PixelEraserPage(imageBytes: bytes),
    );
    if (erased == null || !mounted) return;
    setState(() {
      _bytes = erased;
      _editorKey = GlobalKey<ProImageEditorState>();
      _canvasHasAlpha = true;
    });
  }

  Future<void> _load() async {
    final bytes = await _loadImageBytes(widget.imageUrl);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _loadFailed = true);
      Toast.error('app_photoEditLoadFailed'.tr);
    } else {
      // 记录打开历史（编辑器主界面"最近打开"用）
      unawaited(PhotoEditorHistory.record(widget.imageUrl));
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
        key: _editorKey,
        configs: ProImageEditorConfigs(
          i18n: _buildI18n(),
          // 擦除后画布含透明，导出必须 PNG（JPG 无 alpha 会压黑）
          imageGeneration: ImageGenerationConfigs(
            outputFormat: _canvasHasAlpha ? OutputFormat.png : OutputFormat.jpg,
          ),
          mainEditor: MainEditorConfigs(
            widgets: MainEditorWidgets(
              // AI 修图 / 像素橡皮擦浮动入口：子编辑器（裁剪/滤镜等）打开时隐藏
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
                ],
              ),
              // 未指定保存路径：返回时的关闭警告替换为保存询问
              //（保存=导出存副本；指定了路径的调用方保留编辑器自带警告）
              closeWarningDialog: widget.savePath == null
                  ? _customCloseWarning
                  : null,
            ),
          ),
        ),
        callbacks: ProImageEditorCallbacks(
          // 编辑器导出期间保持自带 loading 遮罩，pop 后由 showPhotoEditor 持久化
          onImageEditingComplete: (editedBytes) async {
            Navigator.of(context).pop(_EditorExit(bytes: editedBytes));
          },
          // 设置了该回调时编辑器不会自行 pop，由这里统一关闭
          onCloseEditor: (mode) => Navigator.of(context).pop(_closeExit),
        ),
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
