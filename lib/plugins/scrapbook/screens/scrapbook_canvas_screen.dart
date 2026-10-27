import 'dart:async';

import 'package:flutter/material.dart';

import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/scrapbook_canvas_card/scrapbook_canvas_card.dart';

import '../models/scrapbook_page.dart';
import '../services/scrapbook_repository.dart';

/// 手账画布编辑页：全屏画布（组件自带 Back/Save/导出/FAB 工具层），
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
        ),
      ),
    );
  }
}
