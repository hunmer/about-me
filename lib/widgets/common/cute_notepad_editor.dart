import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_platform/universal_platform.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_stickers.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_variants.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 可爱手账贴图编辑器（共用组件）
///
/// 基于 [CuteNotepadCardWidget] 的贴图制作页：
/// - 可传入初始文本或待办项目（如聊天消息内容）
/// - 横向列表切换 16 种便签样式（贴纸与内容跨样式保留）
/// - 横向列表点击添加 31 种手绘贴纸，预览区可拖拽/旋转/缩放/删除
/// - 保存：移动端存入相册（photo_manager），桌面端弹出文件保存对话框
/// - 分享：写入临时文件后调用系统分享（share_plus）
class CuteNotepadEditorPage extends StatefulWidget {
  final String? initialText;
  final List<CuteNotepadTodoItem>? initialItems;
  final String? initialVariantId;

  const CuteNotepadEditorPage({
    super.key,
    this.initialText,
    this.initialItems,
    this.initialVariantId,
  });

  /// 打开编辑器
  static Future<void> show(
    BuildContext context, {
    String? initialText,
    List<CuteNotepadTodoItem>? initialItems,
    String? initialVariantId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => CuteNotepadEditorPage(
              initialText: initialText,
              initialItems: initialItems,
              initialVariantId: initialVariantId,
            ),
      ),
    );
  }

  @override
  State<CuteNotepadEditorPage> createState() => _CuteNotepadEditorPageState();
}

class _CuteNotepadEditorPageState extends State<CuteNotepadEditorPage> {
  late final TextEditingController _textController;
  late final List<_EditorTodoRow> _todoRows;
  late String _variantId;
  late List<CuteNotepadSticker> _stickers;

  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _variantId = widget.initialVariantId ?? cuteNotepadPresets.first.id;
    _textController = TextEditingController(text: widget.initialText ?? '');
    final initialItems =
        widget.initialItems ??
        resolveCuteNotepadVariant(_variantId).items;
    _todoRows = [
      for (final item in initialItems)
        _EditorTodoRow(
          checked: item.checked,
          controller: TextEditingController(text: item.text),
        ),
    ];
    // 初始贴纸 = 初始样式预设的拷贝，之后完全由编辑器管理
    _stickers = List.of(resolveCuteNotepadVariant(_variantId).stickers);
  }

  @override
  void dispose() {
    _textController.dispose();
    for (final row in _todoRows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  CuteNotepadVariant get _variant => resolveCuteNotepadVariant(_variantId);

  List<CuteNotepadTodoItem> get _currentItems => [
    for (final row in _todoRows)
      CuteNotepadTodoItem(checked: row.checked, text: row.controller.text),
  ];

  void _toast(String message, {ToastType type = ToastType.success}) {
    ToastService.instance.showToast(message, type: type);
  }

  // ---- 贴纸管理 ----

  void _addSticker(String asset) {
    final box = cuteNotepadStickerViewBoxes[asset];
    if (box == null) return;
    // 新贴纸落在画布中心附近，随数量轻微错开避免完全重叠
    final n = _stickers.length;
    setState(() {
      _stickers = [
        ..._stickers,
        CuteNotepadSticker(
          asset: asset,
          anchor: CuteNotepadStickerAnchor.center,
          w: box[0] * 0.8,
          h: box[1] * 0.8,
          dx: ((n % 5) - 2) * 16.0,
          dy: ((n % 3) - 1) * 14.0,
        ),
      ];
    });
  }

  void _removeSticker(int index) {
    setState(() {
      _stickers = List.of(_stickers)..removeAt(index);
    });
  }

  // ---- 内容编辑 ----

  void _addTodoRow() {
    setState(() {
      _todoRows.add(_EditorTodoRow(controller: TextEditingController()));
    });
  }

  void _removeTodoRow(int index) {
    setState(() {
      final row = _todoRows.removeAt(index);
      row.controller.dispose();
    });
  }

  // ---- 导出与分享 ----

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await captureCuteNotepadPng(_boundaryKey);
      if (bytes == null) {
        throw StateError('截图失败');
      }
      final name =
          'cute-notepad-$_variantId-'
          '${DateTime.now().millisecondsSinceEpoch}.png';

      if (UniversalPlatform.isWindows ||
          UniversalPlatform.isLinux ||
          UniversalPlatform.isMacOS) {
        // 桌面端：弹出保存文件对话框
        final String? path = await FilePicker.platform.saveFile(
          fileName: name,
          type: FileType.image,
        );
        if (path == null) return; // 用户取消
        final file = File(
          path.toLowerCase().endsWith('.png') ? path : '$path.png',
        );
        await file.writeAsBytes(bytes);
        _toast('已保存：${file.path}');
      } else {
        // 移动端：保存到相册
        final state = await PhotoManager.requestPermissionExtend();
        if (!state.hasAccess) {
          _toast('未获得相册权限', type: ToastType.error);
          return;
        }
        await PhotoManager.editor.saveImage(
          bytes,
          filename: name,
          title: name,
        );
        _toast('已保存到相册');
      }
    } catch (e) {
      _toast('保存失败：$e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await captureCuteNotepadPng(_boundaryKey);
      if (bytes == null) {
        throw StateError('截图失败');
      }
      final name =
          'cute-notepad-$_variantId-'
          '${DateTime.now().millisecondsSinceEpoch}.png';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: '可爱手账贴图');
    } catch (e) {
      _toast('分享失败：$e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final variant = _variant;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('制作贴图')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 便签预览（直接可编辑：拖拽/旋转/缩放/删除贴纸，
                          // 保存/分享由编辑器底部按钮负责）
                      Center(
                        child: CuteNotepadCardWidget(
                          variant: variant,
                          text: _textController.text,
                          items: _currentItems,
                          stickers: _stickers,
                          onStickerRemoved: _removeSticker,
                          repaintBoundaryKey: _boundaryKey,
                          editable: true,
                          initialEditing: true,
                          showModeButton: false,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildContentEditor(variant),
                      const SizedBox(height: 20),
                      _buildStylePicker(),
                      const SizedBox(height: 16),
                      _buildStickerPicker(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              _buildBottomActions(isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// 内容编辑：自由文本或多行待办
  Widget _buildContentEditor(CuteNotepadVariant variant) {
    if (variant.type == CuteNotepadNoteType.freeform) {
      return TextField(
        controller: _textController,
        maxLines: 5,
        minLines: 2,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: '便签文字',
          hintText: '输入要写在便签上的内容...',
          border: OutlineInputBorder(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _todoRows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Checkbox(
                    value: _todoRows[i].checked,
                    onChanged:
                        (v) => setState(() => _todoRows[i].checked = v ?? false),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _todoRows[i].controller,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '待办 ${i + 1}',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed:
                      _todoRows.length > 1 ? () => _removeTodoRow(i) : null,
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addTodoRow,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加一行'),
          ),
        ),
      ],
    );
  }

  /// 便签样式选择（16 种预设，切换时贴纸与内容保留）
  Widget _buildStylePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '便签样式',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cuteNotepadPresets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = cuteNotepadPresets[index];
              final selected = preset.id == _variantId;
              return GestureDetector(
                onTap: () => setState(() => _variantId = preset.id),
                child: Tooltip(
                  message: preset.name,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 46,
                        height: 32,
                        decoration: BoxDecoration(
                          color: preset.paperColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                selected
                                    ? const Color(0xFFE11D48)
                                    : Colors.black26,
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${index + 1}'.padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              selected
                                  ? const Color(0xFFE11D48)
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 贴纸选择（点击添加到便签中心）
  Widget _buildStickerPicker() {
    final assets = cuteNotepadStickerBodies.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '添加贴纸（点击添加，预览区可拖拽/旋转/缩放）',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: assets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final asset = assets[index];
              final box = cuteNotepadStickerViewBoxes[asset] ?? const [40, 40];
              // 高 36 内等比
              final h = 36.0;
              final w = (h * box[0] / box[1]).clamp(20.0, 56.0);
              return GestureDetector(
                onTap: () {
                  _addSticker(asset);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已添加贴纸，可在预览区拖动调整'),
                      duration: const Duration(milliseconds: 1200),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  width: 60,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Center(
                    child: SvgThumb(asset: asset, w: w, h: h),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _share,
              icon: const Icon(Icons.share, size: 18),
              label: const Text('分享'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon:
                  _busy
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Icon(
                          UniversalPlatform.isWindows ||
                                  UniversalPlatform.isLinux ||
                                  UniversalPlatform.isMacOS
                              ? Icons.save_alt
                              : Icons.photo_library,
                          size: 18,
                        ),
              label: Text(
                UniversalPlatform.isWindows ||
                        UniversalPlatform.isLinux ||
                        UniversalPlatform.isMacOS
                    ? '保存到文件'
                    : '保存到相册',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 待办编辑行
class _EditorTodoRow {
  bool checked;
  final TextEditingController controller;

  _EditorTodoRow({this.checked = false, required this.controller});
}

/// 贴纸缩略图
class SvgThumb extends StatelessWidget {
  final String asset;
  final double w;
  final double h;

  const SvgThumb({
    super.key,
    required this.asset,
    required this.w,
    required this.h,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      cuteNotepadStickerSvg(asset),
      width: w,
      height: h,
      fit: BoxFit.contain,
    );
  }
}
