import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/controllers/notes_controller.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';

// 创建新文件夹
Future<void> createNewFolder(
  BuildContext context,
  NotesController controller,
  String currentFolderId,
  VoidCallback onReload,
) async {
  final TextEditingController folderNameController = TextEditingController();

  String? result = await showDSDialog<String>(
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
                    SizedBox(height: theme.spacing.lg),
                    DSInput(
                      controller: folderNameController,
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
                                  folderNameController.text,
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
  folderNameController.dispose();

  if (result != null && result.isNotEmpty) {
    await controller.createFolder(result, currentFolderId);
    onReload();
  }
}

// 重命名文件夹
Future<void> renameFolderDialog(
  BuildContext context,
  NotesController controller,
  Folder folder,
  VoidCallback onReload,
) async {
  final TextEditingController renameController = TextEditingController(
    text: folder.name,
  );

  String? result = await showDSDialog<String>(
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
                    DSInput(controller: renameController, hint: '文件夹名称'),
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
  renameController.dispose();

  if (result != null && result.isNotEmpty) {
    await controller.renameFolder(folder.id, result);
    onReload();
  }
}

// 删除文件夹
Future<void> deleteFolderDialog(
  BuildContext context,
  NotesController controller,
  Folder folder,
  VoidCallback onReload,
) async {
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
                  confirmText: 'app_delete'.tr,
                  confirmVariant: DSButtonVariant.destructive,
                  onCancel: () => Navigator.of(context).pop(false),
                  onConfirm: () => Navigator.of(context).pop(true),
                ),
          ),
        ),
  );

  if (confirmed == true) {
    await controller.deleteFolder(folder.id);
    onReload();
  }
}
