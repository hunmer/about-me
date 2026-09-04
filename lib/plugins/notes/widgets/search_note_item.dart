import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/utils/text_highlight.dart';

class SearchNoteItem extends StatelessWidget {
  final Note note;
  final String folderName;
  final String query;

  const SearchNoteItem({
    super.key,
    required this.note,
    required this.folderName,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DSCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextHighlight.highlightText(
                      note.title,
                      query,
                      baseStyle: DsTypography.title.copyWith(color: theme.text),
                      highlightStyle: DsTypography.title.copyWith(
                        color: theme.danger,
                      ),
                    ),
                  ),
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children:
                          note.tags.map((tag) => DSChip(label: tag)).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  RichText(
                    text: TextHighlight.highlightText(
                      note.content,
                      query,
                      baseStyle: DsTypography.body.copyWith(color: theme.text),
                      highlightStyle: DsTypography.body.copyWith(
                        color: theme.danger,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: DSChip(label: folderName, icon: DsIconKind.layers),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
