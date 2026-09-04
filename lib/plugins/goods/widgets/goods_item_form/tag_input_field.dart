import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'add_tag_dialog.dart';

class TagInputField extends StatelessWidget {
  final List<String> tags;
  final Function(List<String>) onTagsChanged;

  const TagInputField({
    super.key,
    required this.tags,
    required this.onTagsChanged,
  });

  Future<void> _showAddTagDialog(BuildContext context) async {
    final newTag = await showDSDialog<String>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => const DSThemeBridge(child: AddTagDialog()),
    );
    if (newTag != null && !tags.contains(newTag)) {
      final newTags = List<String>.from(tags);
      newTags.add(newTag);
      onTagsChanged(newTags);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('goods_tag'.tr),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...tags.map((tag) => _buildTag(context, tag)),
              _buildAddButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String tag) {
    return DSChip(
      label: tag,
      onDeleted: () {
        final newTags = List<String>.from(tags);
        newTags.remove(tag);
        onTagsChanged(newTags);
      },
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return DSChip(
      label: 'goods_addTag'.tr,
      icon: DsIconKind.plus,
      onSelected: (_) => _showAddTagDialog(context),
    );
  }
}
