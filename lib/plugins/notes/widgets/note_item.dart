import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/note.dart';

class NoteItem extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const NoteItem({super.key, required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return DSListItem(
            leading: DsIcon(DsIconKind.book, color: theme.primary),
            title: note.title,
            subtitle:
                note.tags.isNotEmpty ? note.tags.join(' · ') : note.content,
            onTap: onTap,
          );
        },
      ),
    );
  }
}
