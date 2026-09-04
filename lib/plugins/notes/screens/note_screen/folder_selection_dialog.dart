import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/controllers/notes_controller.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/plugins/notes/models/note.dart';

Future<Folder?> showFolderSelectionDialog(
  BuildContext context,
  NotesController controller,
  Note? note, {
  Folder? parentFolder,
  Folder? currentFolder,
}) async {
  final rootFolder = controller.getFolder('root')!;
  final startFolder = parentFolder ?? rootFolder;
  final currentFolderId = note?.folderId ?? currentFolder?.id;

  return showDSDialog<Folder>(
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
                      parentFolder != null ? '选择子文件夹' : '选择目标文件夹',
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.md),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFolderTree(
                              context,
                              startFolder,
                              controller,
                              isRoot: startFolder.id == 'root',
                              currentFolderId: currentFolderId,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: theme.spacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: 'app_cancel'.tr,
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        if (parentFolder != null &&
                            parentFolder.id != currentFolderId) ...[
                          SizedBox(width: theme.spacing.md),
                          Expanded(
                            child: DSButton(
                              label: 'notes_selectCurrentFolder'.tr,
                              onPressed:
                                  () => Navigator.pop(context, parentFolder),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
  );
}

Widget _buildFolderTree(
  BuildContext context,
  Folder folder,
  NotesController controller, {
  bool isRoot = false,
  String? currentFolderId,
}) {
  final children = controller.getFolderChildren(folder.id);

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!isRoot)
        DSListItem(
          // folder.icon 为持久化 IconData，保留 Material Icons 定义
          leading: Icon(folder.icon),
          title: folder.name,
          showChevron: children.isNotEmpty,
          onTap: () async {
            if (children.isEmpty) {
              Navigator.pop(context, folder);
            } else {
              final selectedFolder = await showFolderSelectionDialog(
                context,
                controller,
                null,
                parentFolder: folder,
              );
              if (selectedFolder != null && context.mounted) {
                Navigator.pop(context, selectedFolder);
              }
            }
          },
        ),
      if (children.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                children
                    .map(
                      (child) => _buildFolderTree(
                        context,
                        child,
                        controller,
                        currentFolderId: currentFolderId,
                      ),
                    )
                    .toList(),
          ),
        ),
    ],
  );
}
