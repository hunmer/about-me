import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_platform/universal_platform.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/markdown_content.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_stickers.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_variants.dart';

/// 可爱手账贴图编辑器（共用组件，DS 手绘风格）
///
/// 基于 [CuteNotepadCardWidget] 的贴图制作页：
/// - 可传入初始文本（支持 Markdown 渲染，走 MarkdownContent）或待办项目
/// - 横向列表切换 16 种便签样式（贴纸与内容跨样式保留）
/// - 横向列表点击添加 31 种手绘贴纸，预览区可拖拽/旋转/缩放/水平翻转/删除
/// - 撤销 / 重置贴纸布局
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

  /// 打开编辑器（平台路由，iOS 支持侧滑返回）
  static Future<void> show(
    BuildContext context, {
    String? initialText,
    List<CuteNotepadTodoItem>? initialItems,
    String? initialVariantId,
  }) {
    return NavigationHelper.push(
      context,
      CuteNotepadEditorPage(
        initialText: initialText,
        initialItems: initialItems,
        initialVariantId: initialVariantId,
      ),
      routeName: '/cute_notepad_editor',
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

  /// 正文用 MarkdownContent 渲染
  bool _useMarkdown = true;

  /// 贴纸布局撤销栈（添加/删除/变换/重置前压栈）
  final List<List<CuteNotepadSticker>> _undoStack = [];

  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  static bool get _isDesktop =>
      UniversalPlatform.isWindows ||
      UniversalPlatform.isLinux ||
      UniversalPlatform.isMacOS;

  @override
  void initState() {
    super.initState();
    _variantId = widget.initialVariantId ?? cuteNotepadPresets.first.id;
    _textController = TextEditingController(text: widget.initialText ?? '');
    final initialItems =
        widget.initialItems ?? resolveCuteNotepadVariant(_variantId).items;
    _todoRows = [
      for (final item in initialItems)
        _EditorTodoRow(
          checked: item.checked,
          controller: TextEditingController(text: item.text),
        ),
    ];
    // 初始贴纸 = 当前样式预设的绝对布局，之后完全由编辑器管理
    _stickers = _presetStickerLayouts();
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

  void _toast(String message, {DSToastType type = DSToastType.success}) {
    if (!mounted) return;
    showDSToast(context, message: message, type: type);
  }

  // ---- 贴纸管理 ----

  /// 当前样式预设贴纸的绝对布局（内容变化后底部锚定贴纸自动贴合）
  List<CuteNotepadSticker> _presetStickerLayouts() {
    return resolveCuteNotepadStickerLayouts(
      variant: _variant,
      text: _textController.text,
      items: _currentItems,
    );
  }

  void _pushUndo() {
    _undoStack.add(List.of(_stickers));
    if (_undoStack.length > 50) {
      _undoStack.removeAt(0);
    }
  }

  void _undoStickers() {
    if (_undoStack.isEmpty) return;
    setState(() => _stickers = _undoStack.removeLast());
  }

  /// 重置贴纸布局为当前样式预设
  void _resetStickers() {
    _pushUndo();
    setState(() => _stickers = _presetStickerLayouts());
  }

  /// 组件回传贴纸布局（拖拽/旋转/缩放/翻转结束）：与当前一致时跳过，
  /// 否则压栈撤销并更新
  void _onStickersLayoutChanged(List<CuteNotepadSticker> layouts) {
    if (_sameLayouts(_stickers, layouts)) return;
    _pushUndo();
    setState(() => _stickers = layouts);
  }

  static bool _sameLayouts(
    List<CuteNotepadSticker> a,
    List<CuteNotepadSticker> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].asset != b[i].asset ||
          a[i].x != b[i].x ||
          a[i].y != b[i].y ||
          a[i].rotation != b[i].rotation ||
          a[i].scale != b[i].scale ||
          a[i].flipX != b[i].flipX) {
        return false;
      }
    }
    return true;
  }

  void _addSticker(String asset) {
    final box = cuteNotepadStickerViewBoxes[asset];
    if (box == null) return;
    _pushUndo();
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
    _toast('app_stickerAdded'.tr);
  }

  void _removeSticker(int index) {
    _pushUndo();
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
        throw StateError('app_stickerCaptureFailed'.tr);
      }
      final name =
          'cute-notepad-$_variantId-'
          '${DateTime.now().millisecondsSinceEpoch}.png';

      if (_isDesktop) {
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
          _toast('app_stickerNoPermission'.tr, type: DSToastType.danger);
          return;
        }
        await PhotoManager.editor.saveImage(bytes, filename: name, title: name);
        _toast('app_stickerSavedAlbum'.tr);
      }
    } catch (e) {
      _toast(
        'app_stickerSaveFailed'.trParams({'e': e.toString()}),
        type: DSToastType.danger,
      );
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
        throw StateError('app_stickerCaptureFailed'.tr);
      }
      final name =
          'cute-notepad-$_variantId-'
          '${DateTime.now().millisecondsSinceEpoch}.png';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      _toast(
        'app_stickerShareFailed'.trParams({'e': e.toString()}),
        type: DSToastType.danger,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final variant = _variant;

    return Scaffold(
      backgroundColor: theme.surface,
      body: SafeArea(
        child: Column(
          children: [
            DSLightHeader(title: 'app_makeSticker'.tr),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 便签预览（直接可编辑：拖拽/旋转/缩放/翻转/删除贴纸，
                    // 保存/分享由编辑器底部按钮负责）
                    Center(
                      child: CuteNotepadCardWidget(
                        variant: variant,
                        text: _textController.text,
                        contentWidget:
                            _useMarkdown && variant.type == CuteNotepadNoteType.freeform
                                ? MarkdownContent(
                                    content: _textController.text,
                                    selectable: false,
                                    textColor: variant.textColor,
                                  )
                                : null,
                        items: _currentItems,
                        stickers: _stickers,
                        onStickerRemoved: _removeSticker,
                        onStickersLayoutChanged: _onStickersLayoutChanged,
                        repaintBoundaryKey: _boundaryKey,
                        editable: true,
                        initialEditing: true,
                        showModeButton: false,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xl),
                    _buildContentEditor(theme, variant),
                    SizedBox(height: theme.spacing.xl),
                    _buildStylePicker(theme),
                    SizedBox(height: theme.spacing.lg),
                    _buildStickerPicker(theme),
                  ],
                ),
              ),
            ),
            _buildBottomBar(theme),
          ],
        ),
      ),
    );
  }

  /// 小节标题
  Widget _sectionTitle(AppThemeData theme, String text) {
    return Text(
      text,
      style: DsTypography.caption.copyWith(
        color: theme.textSub,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  /// 内容编辑：自由文本（含 Markdown 开关）或多行待办
  Widget _buildContentEditor(AppThemeData theme, CuteNotepadVariant variant) {
    if (variant.type == CuteNotepadNoteType.freeform) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DSInput(
            controller: _textController,
            label: 'app_notepadText'.tr,
            hint: 'app_notepadTextHint'.tr,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: theme.spacing.sm),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _useMarkdown = !_useMarkdown),
            child: Row(
              children: [
                DSCheckbox(
                  value: _useMarkdown,
                  onChanged: (v) => setState(() => _useMarkdown = v ?? false),
                ),
                SizedBox(width: theme.spacing.sm),
                Text(
                  'app_notepadMarkdown'.tr,
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _todoRows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.sm),
            child: Row(
              children: [
                DSCheckbox(
                  value: _todoRows[i].checked,
                  onChanged:
                      (v) => setState(() => _todoRows[i].checked = v ?? false),
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: DSInput(
                    controller: _todoRows[i].controller,
                    hint: 'app_todoRowLabel'.trParams({'n': '${i + 1}'}),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: theme.spacing.xs),
                DSIconButton(
                  icon: DsIconKind.close,
                  size: 36,
                  color: theme.surface,
                  iconColor: theme.textSub,
                  onPressed:
                      _todoRows.length > 1 ? () => _removeTodoRow(i) : null,
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: DSButton(
            label: 'app_addRow'.tr,
            variant: DSButtonVariant.outline,
            icon: DsIconKind.plus,
            onPressed: _addTodoRow,
          ),
        ),
      ],
    );
  }

  /// 便签样式选择（16 种预设，切换时贴纸与内容保留）
  Widget _buildStylePicker(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(theme, 'app_notepadStyle'.tr),
        SizedBox(height: theme.spacing.sm),
        SizedBox(
          height: 58,
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
                        decoration: dsSketchDecoration(
                          theme: theme,
                          fillColor: preset.paperColor,
                          stroke: selected ? theme.primary : null,
                          strokeWidth: selected ? 2.6 : 1.8,
                          radius: theme.radii.sm,
                          seed: index + 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${index + 1}'.padLeft(2, '0'),
                        style: DsTypography.caption.copyWith(
                          color: selected ? theme.primary : theme.textSub,
                          fontSize: 10,
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

  /// 贴纸选择（点击添加到便签中心），标题行带撤销/重置贴纸布局
  Widget _buildStickerPicker(AppThemeData theme) {
    final assets = cuteNotepadStickerBodies.keys.toList();
    final canUndo = _undoStack.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(theme, 'app_addStickerHint'.tr)),
            DSIconButton(
              icon: DsIconKind.replay,
              size: 36,
              color: theme.surface,
              iconColor: canUndo ? theme.text : theme.textSub,
              tooltip: 'app_undoSticker'.tr,
              onPressed: canUndo ? _undoStickers : null,
            ),
            SizedBox(width: theme.spacing.sm),
            DSIconButton(
              icon: DsIconKind.refresh,
              size: 36,
              color: theme.surface,
              iconColor: theme.text,
              tooltip: 'app_resetSticker'.tr,
              onPressed: _resetStickers,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: assets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final asset = assets[index];
              final box =
                  cuteNotepadStickerViewBoxes[asset] ?? const [40, 40];
              // 高 36 内等比
              const h = 36.0;
              final w = (h * box[0] / box[1]).clamp(20.0, 52.0);
              return GestureDetector(
                onTap: () => _addSticker(asset),
                child: Container(
                  width: 60,
                  height: 50,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    fillColor: theme.surface,
                    radius: theme.radii.sm,
                    seed: index + 1,
                  ),
                  child: Center(
                    child: SvgPicture.string(
                      cuteNotepadStickerSvg(asset),
                      width: w,
                      height: h,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 底部动作条：分享 / 保存
  Widget _buildBottomBar(AppThemeData theme) {
    return Container(
      color: theme.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: DSButton(
              label: 'app_share'.tr,
              variant: DSButtonVariant.outline,
              icon: DsIconKind.share,
              onPressed: _busy ? null : _share,
              expand: true,
            ),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            flex: 2,
            child: DSButton(
              label: _isDesktop ? 'app_saveToFile'.tr : 'app_saveToAlbum'.tr,
              icon: _isDesktop ? DsIconKind.download : DsIconKind.photoLibrary,
              onPressed: _busy ? null : _save,
              expand: true,
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
