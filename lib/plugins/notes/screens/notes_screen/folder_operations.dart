import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/plugins/notes/widgets/note_color_picker.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'notes_screen_state.dart';

mixin FolderOperations on NotesMainViewState {
  Future<void> createNewFolder() async {
    final parentFolderName = currentFolder?.name ?? 'notes_root'.tr;
    final result = await _FolderNameSheet.show(context, parentFolderName);
    if (result != null && result.$1.isNotEmpty) {
      // 使用 currentFolderId 作为父文件夹 ID
      await plugin.controller.createFolder(
        result.$1,
        currentFolderId,
        color: result.$2,
      );
      loadCurrentFolder();
    }
  }

  Future<void> renameFolder(Folder folder) async {
    final result = await _FolderNameSheet.show(
      context,
      folder.name,
      titleText: 'notes_renameFolder'.tr,
      initialName: folder.name,
      initialColor: folder.color,
    );
    if (result != null && result.$1.isNotEmpty) {
      await plugin.controller.renameFolder(
        folder.id,
        result.$1,
        color: result.$2,
      );
      loadCurrentFolder();
    }
  }

  /// 切换文件夹归档状态并持久化（长按菜单入口）
  Future<void> toggleFolderArchive(Folder folder) async {
    await plugin.controller.toggleFolderArchive(folder);
    loadCurrentFolder();
  }

  Future<void> deleteFolder(Folder folder) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'notes_deleteFolder'.tr,
                    message: 'notes_deleteFolderConfirm'.tr,
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'notes_delete'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onCancel: () => Navigator.of(context).pop(false),
                    onConfirm: () => Navigator.of(context).pop(true),
                  ),
            ),
          ),
    );

    if (confirmed == true) {
      await plugin.controller.deleteFolder(folder.id);
      loadCurrentFolder();
    }
  }
}

/// 文件夹命名底部抽屉（新建/重命名共用），返回 (名称, 颜色)（取消返回 null）
class _FolderNameSheet extends StatefulWidget {
  final String parentFolderName;
  final String? titleText;
  final String? initialName;
  final Color? initialColor;

  const _FolderNameSheet({
    required this.parentFolderName,
    this.titleText,
    this.initialName,
    this.initialColor,
  });

  static Future<(String, Color?)?> show(
    BuildContext context,
    String parentFolderName, {
    String? titleText,
    String? initialName,
    Color? initialColor,
  }) {
    return SmoothBottomSheet.show<(String, Color?)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _FolderNameSheet(
          parentFolderName: parentFolderName,
          titleText: titleText,
          initialName: initialName,
          initialColor: initialColor,
        ),
      ),
    );
  }

  @override
  State<_FolderNameSheet> createState() => _FolderNameSheetState();
}

class _FolderNameSheetState extends State<_FolderNameSheet> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  Color? _pickedColor;

  bool get _isRename => widget.titleText != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _pickedColor = widget.initialColor;
    // DSInput 无 autofocus 参数，用 FocusNode 在首帧后聚焦
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNode.canRequestFocus) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_controller.text.isNotEmpty) {
      Navigator.pop(context, (_controller.text, _pickedColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.titleText ?? 'notes_newFolder'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                if (!_isRename) ...[
                  SizedBox(height: theme.spacing.sm),
                  // 显示将在哪个文件夹下创建
                  Text(
                    '${'notes_createIn'.tr}: ${widget.parentFolderName}',
                    textAlign: TextAlign.center,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ],
                SizedBox(height: theme.spacing.lg),
                DSInput(
                  controller: _controller,
                  focusNode: _focusNode,
                  hint: 'notes_folderNameHint'.tr,
                  onSubmitted: (value) => _confirm(),
                ),
                SizedBox(height: theme.spacing.lg),
                NoteColorPickerRow(
                  selected: _pickedColor,
                  onChanged: (color) => setState(() => _pickedColor = color),
                ),
                SizedBox(height: theme.spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: DSButton(
                        label: 'notes_cancel'.tr,
                        variant: DSButtonVariant.outline,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: DSButton(
                        label: 'notes_confirm'.tr,
                        onPressed: _confirm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
