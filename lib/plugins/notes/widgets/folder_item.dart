import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';

class FolderItem extends StatelessWidget {
  final Folder folder;
  final VoidCallback onTap;

  const FolderItem({super.key, required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          return DSListItem(
            // folder.icon 为持久化 IconData，保留 Material Icons 定义
            leading: DSAvatar(
              color: folder.color,
              size: 40,
              child: Icon(folder.icon, color: Colors.white, size: 20),
            ),
            title: folder.name,
            onTap: onTap,
          );
        },
      ),
    );
  }
}
