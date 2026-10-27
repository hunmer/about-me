import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:aboutme/plugins/scrapbook/scrapbook_plugin.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/scrapbook_canvas_card/scrapbook_canvas_card.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';

import '../models/scrapbook_page.dart';
import '../services/scrapbook_repository.dart';

/// 手账画布编辑页：全屏画布（组件自带 Back/Save/导出/底部工具栏），
/// 画布内容变更后 debounce 自动保存，退出时 flush
class ScrapbookCanvasScreen extends StatefulWidget {
  final ScrapbookPage page;
  final ScrapbookRepository? repository;

  const ScrapbookCanvasScreen({super.key, required this.page, this.repository});

  @override
  State<ScrapbookCanvasScreen> createState() => _ScrapbookCanvasScreenState();
}

class _ScrapbookCanvasScreenState extends State<ScrapbookCanvasScreen> {
  ScrapbookPage get _page => widget.page;
  ScrapbookRepository get _repository =>
      widget.repository ?? ScrapbookRepository.instance;

  Timer? _saveDebounce;
  bool _dirty = false;

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  void _onCanvasChanged(List<ScrapItemData> items, List<ScrapStroke> strokes) {
    _page.items = items;
    _page.strokes = strokes;
    _dirty = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      await _repository.update(_page);
    } catch (e) {
      _dirty = true;
      debugPrint('[Scrapbook] 保存失败: $e');
    }
  }

  Future<void> _flushAndPop() async {
    _saveDebounce?.cancel();
    await _save();
    if (mounted) Navigator.of(context).pop(true);
  }

  /// 工具栏"添加"回调：弹出图片选择器（相册 / 手账素材 / 表情包），
  /// 结果统一转成画布条目素材
  Future<ScrapPickedAsset?> _pickAsset() async {
    final result = await ImagePickerDialog.show<Map<String, dynamic>>(context);
    if (result == null) return null;

    // 内置 SVG 素材：直接返回源码（画布按源码渲染，不依赖文件）
    final svg = result['svg'] as String?;
    if (svg != null && svg.isNotEmpty) return ScrapPickedAsset(svgSource: svg);

    final url = result['url'] as String?;
    // Unicode 表情：以大号文字条目上画布
    if (url != null && url.startsWith('emoji:')) {
      return ScrapPickedAsset(emoji: url.substring(6));
    }

    // 图片：优先字节，网络 URL 下载；存插件存储后物化为本地路径
    Uint8List? data;
    final bytes = result['bytes'] as List<int>?;
    if (bytes != null && bytes.isNotEmpty) {
      data = Uint8List.fromList(bytes);
    } else if (url != null &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      try {
        final resp = await http.get(Uri.parse(url));
        data = resp.bodyBytes;
      } catch (e) {
        debugPrint('[Scrapbook] 下载图片失败: $e');
      }
    }
    if (data == null || data.isEmpty) return null;

    try {
      final relPath =
          'scrapbook/images/${DateTime.now().millisecondsSinceEpoch}.png';
      final storage = ScrapbookPlugin.instance.storage;
      await storage.writeBytes(relPath, data);
      final file = await storage.materializeToTemporaryFile(relPath);
      if (file != null) return ScrapPickedAsset(imageUrl: file.path);
    } catch (e) {
      debugPrint('[Scrapbook] 保存图片失败: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 系统返回（侧滑/桌面返回键）：放行后 flush 未落盘的编辑
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        _saveDebounce?.cancel();
        unawaited(_save());
      },
      child: Scaffold(
        body: ScrapbookCanvasCardWidget(
          inline: true,
          items: _page.items,
          initialStrokes: _page.strokes,
          onChanged: _onCanvasChanged,
          onClose: _flushAndPop,
          onPickAsset: _pickAsset,
        ),
      ),
    );
  }
}
