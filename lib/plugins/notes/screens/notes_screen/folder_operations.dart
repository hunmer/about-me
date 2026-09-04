import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'notes_screen_state.dart';

mixin FolderOperations on NotesMainViewState {
  Future<void> createNewFolder() async {
    final TextEditingController folderNameController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    // 获取当前文件夹名称用于提示
    final parentFolderName = currentFolder?.name ?? 'notes_root'.tr;

    // DSInput 无 autofocus 参数，用 FocusNode 在首帧后聚焦
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNode.canRequestFocus) focusNode.requestFocus();
    });

    final result = await showDSDialog<String>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'notes_newFolder'.tr,
                        textAlign: TextAlign.center,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.sm),
                      // 显示将在哪个文件夹下创建
                      Text(
                        '${'notes_createIn'.tr}: $parentFolderName',
                        textAlign: TextAlign.center,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      DSInput(
                        controller: folderNameController,
                        focusNode: focusNode,
                        hint: 'notes_folderNameHint'.tr,
                        onSubmitted: (value) => Navigator.pop(context, value),
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
                              onPressed: () {
                                if (folderNameController.text.isNotEmpty) {
                                  Navigator.pop(
                                    context,
                                    folderNameController.text,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
    focusNode.dispose();
    folderNameController.dispose();

    if (result != null && result.isNotEmpty) {
      // 使用 currentFolderId 作为父文件夹 ID
      await plugin.controller.createFolder(result, currentFolderId);
      loadCurrentFolder();
    }
  }

  Future<void> renameFolder(Folder folder) async {
    final TextEditingController renameController = TextEditingController(
      text: folder.name,
    );
    final FocusNode focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNode.canRequestFocus) focusNode.requestFocus();
    });

    final result = await showDSDialog<String>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'notes_renameFolder'.tr,
                        textAlign: TextAlign.center,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      DSInput(
                        controller: renameController,
                        focusNode: focusNode,
                        hint: '文件夹名称',
                        onSubmitted: (value) => Navigator.pop(context, value),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: DSButton(
                              label: 'app_cancel'.tr,
                              variant: DSButtonVariant.outline,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          SizedBox(width: theme.spacing.md),
                          Expanded(
                            child: DSButton(
                              label: 'app_ok'.tr,
                              onPressed:
                                  () => Navigator.pop(
                                    context,
                                    renameController.text,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
    focusNode.dispose();
    renameController.dispose();

    if (result != null && result.isNotEmpty) {
      await plugin.controller.renameFolder(folder.id, result);
      loadCurrentFolder();
    }
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
