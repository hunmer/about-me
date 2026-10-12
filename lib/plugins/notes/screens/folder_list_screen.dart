import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/notes/controllers/notes_controller.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/widgets/folder_item.dart';
import 'package:aboutme/plugins/notes/widgets/note_item.dart';
import 'note_edit_screen.dart';
import 'search_screen.dart';

class FolderListScreen extends StatefulWidget {
  final NotesController controller;

  const FolderListScreen({super.key, required this.controller});

  @override
  State<FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  String currentFolderId = 'root';
  List<Folder> folders = [];
  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentFolder();
  }

  void _loadCurrentFolder() {
    setState(() {
      folders = widget.controller.getFolderChildren(currentFolderId);
      notes = widget.controller.getFolderNotes(currentFolderId);
    });
  }

  void _navigateToFolder(Folder folder) {
    setState(() {
      currentFolderId = folder.id;
      _loadCurrentFolder();
    });
  }

  void _navigateBack() {
    final currentFolder = widget.controller.getFolder(currentFolderId);
    if (currentFolder?.parentId != null) {
      setState(() {
        currentFolderId = currentFolder!.parentId!;
        _loadCurrentFolder();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentFolder = widget.controller.getFolder(currentFolderId);

    return Scaffold(
      appBar: AppBar(
        leading:
            currentFolder?.parentId != null
                ? DSThemeBridge(
                  child: Builder(
                    builder: (context) {
                      final theme = DSThemeBridge.resolve(context);
                      return DSIconButton(
                        icon: DsIconKind.chevronLeft,
                        size: 38,
                        color: theme.surface,
                        iconColor: theme.text,
                        onPressed: _navigateBack,
                      );
                    },
                  ),
                )
                : null,
        title: Text(currentFolder?.name ?? 'Notes'),
        actions: [
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.search,
                  size: 38,
                  color: theme.surface,
                  iconColor: theme.text,
                  onPressed: () {
                    NavigationHelper.push(
                      context,
                      SearchScreen(controller: widget.controller),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      body: ReorderableListView(
        onReorder: (oldIndex, newIndex) {
          // Implement reordering logic here
        },
        children: [
          ...folders.map(
            (folder) => FolderItem(
              key: ValueKey(folder.id),
              folder: folder,
              onTap: () => _navigateToFolder(folder),
            ),
          ),
          ...notes.map(
            (note) => NoteItem(
              key: ValueKey(note.id),
              note: note,
              onTap: () {
                NavigationHelper.push(
                  context,
                  NoteEditScreen(
                    note: note,
                    onSave: (title, content, tags) {
                      final updatedNote = note.copyWith(
                        title: title,
                        content: content,
                        updatedAt: DateTime.now(),
                        tags: tags,
                      );
                      widget.controller.updateNote(updatedNote);
                    },
                  ),
                ).then((_) => _loadCurrentFolder());
              },
            ),
          ),
        ],
      ),
      floatingActionButton: DSThemeBridge(
        child: DSFab(
          icon: DsIconKind.plus,
          onPressed: () {
            showDSDialog(
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
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'notes_createNew'.tr,
                                textAlign: TextAlign.center,
                                style: DsTypography.title.copyWith(
                                  color: theme.text,
                                ),
                              ),
                              SizedBox(height: theme.spacing.lg),
                              DSSheetAction(
                                icon: DsIconKind.layers,
                                label: 'notes_newFolder'.tr,
                                onTap: () {
                                  Navigator.pop(context);
                                  // Show folder creation dialog
                                },
                              ),
                              DSSheetAction(
                                icon: DsIconKind.book,
                                label: 'notes_newNote'.tr,
                                onTap: () {
                                  Navigator.pop(context);
                                  NavigationHelper.push(
                                    context,
                                    NoteEditScreen(
                                      onSave: (title, content, tags) {
                                        widget.controller.createNote(
                                          title,
                                          content,
                                          currentFolderId,
                                          tags: tags,
                                        );
                                      },
                                    ),
                                  ).then((_) => _loadCurrentFolder());
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
            );
          },
        ),
      ),
    );
  }
}
