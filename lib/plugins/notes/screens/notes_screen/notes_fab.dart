import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/notes/screens/note_edit_screen.dart';
import 'folder_operations.dart';
import 'notes_screen_state.dart';

mixin NotesFab on NotesMainViewState, FolderOperations {
  bool _fabExpanded = false;

  Widget buildExpandableFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 子按钮 - 使用AnimatedOpacity实现平滑显示/隐藏
        AnimatedOpacity(
          opacity: _fabExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_fabExpanded,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildFabChild(
                  icon: DsIconKind.layers,
                  label: 'notes_newFolder'.tr,
                  onPressed: () {
                    setState(() {
                      _fabExpanded = false;
                    });
                    createNewFolder();
                  },
                ),
                const SizedBox(height: 16),
                _buildFabChild(
                  icon: DsIconKind.book,
                  label: 'notes_newNote'.tr,
                  onPressed: () {
                    setState(() {
                      _fabExpanded = false;
                    });
                    NavigationHelper.openContainerWithHero(
                      context,
                      (context) => NoteEditScreen(
                        onSave: (title, content, tags) async {
                          await plugin.controller.createNote(
                            title,
                            content,
                            currentFolderId,
                            tags: tags,
                          );
                          loadCurrentFolder();
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // 主按钮
        AnimatedRotation(
          turns: _fabExpanded ? 0.125 : 0,
          duration: const Duration(milliseconds: 200),
          child: DSFab(
            icon: DsIconKind.plus,
            onPressed: () {
              setState(() {
                _fabExpanded = !_fabExpanded;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFabChild({
    required DsIconKind icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return DSButton(
      label: label,
      icon: icon,
      variant: DSButtonVariant.outline,
      size: DSButtonSize.sm,
      onPressed: onPressed,
    );
  }
}
