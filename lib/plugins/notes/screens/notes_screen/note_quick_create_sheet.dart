import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 新建笔记底部抽屉：标题 + 纯文本内容 + 标签
class NoteQuickCreateSheet extends StatefulWidget {
  final Future<void> Function(String title, String content, List<String> tags) onSave;

  const NoteQuickCreateSheet({super.key, required this.onSave});

  static Future<void> show({
    required BuildContext context,
    required Future<void> Function(String title, String content, List<String> tags) onSave,
  }) {
    return SmoothBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: NoteQuickCreateSheet(onSave: onSave),
      ),
    );
  }

  @override
  State<NoteQuickCreateSheet> createState() => _NoteQuickCreateSheetState();
}

class _NoteQuickCreateSheetState extends State<NoteQuickCreateSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagInputController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  List<String> _tags = [];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagInputController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagInputController.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) {
      _tagInputController.clear();
      return;
    }
    setState(() => _tags = [..._tags, tag]);
    _tagInputController.clear();
  }

  void _save() async {
    await widget.onSave(
      _titleController.text,
      _contentController.text,
      List.of(_tags),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'notes_newNote'.tr,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                    ),
                    DSIconButton(
                      icon: DsIconKind.check,
                      size: 36,
                      color: theme.surface,
                      iconColor: theme.text,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _titleController,
                  autofocus: true,
                  style: DsTypography.title.copyWith(color: theme.text),
                  decoration: InputDecoration(
                    hintText: 'notes_titleHint'.tr,
                    hintStyle: DsTypography.title.copyWith(color: theme.disabled),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    maxLines: null,
                    style: DsTypography.body.copyWith(color: theme.textSub),
                    decoration: InputDecoration(
                      hintText: 'notes_quickContentHint'.tr,
                      hintStyle: DsTypography.body.copyWith(color: theme.disabled),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    DsIcon(DsIconKind.tag, size: 16, color: theme.textSub),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _tagInputController,
                        style: DsTypography.body.copyWith(color: theme.textSub),
                        decoration: InputDecoration(
                          hintText: 'notes_tagHint'.tr,
                          hintStyle: DsTypography.body.copyWith(color: theme.disabled),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addTag(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    DSIconButton(
                      icon: DsIconKind.plus,
                      size: 30,
                      color: theme.surface,
                      iconColor: theme.text,
                      onPressed: _addTag,
                    ),
                  ],
                ),
              ),
              if (_tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final tag in _tags)
                        DSChip(
                          label: tag,
                          onSelected: (_) => setState(() => _tags = _tags.where((t) => t != tag).toList()),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}
