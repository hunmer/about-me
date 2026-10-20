import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';
import 'package:aboutme/widgets/tag_folder_card.dart';
import 'package:aboutme/widgets/tags_dialog/tags_dialog.dart';
import 'entry_editor_controller.dart';

class EntryEditorTagHandler extends StatefulWidget {
  final EntryEditorController controller;

  /// 只读模式（隐藏添加按钮与标签删除叉）
  final bool readOnly;

  const EntryEditorTagHandler({
    super.key,
    required this.controller,
    this.readOnly = false,
  });

  @override
  State<EntryEditorTagHandler> createState() => _EntryEditorTagHandlerState();
}

class _EntryEditorTagHandlerState extends State<EntryEditorTagHandler> {
  late final TagController tagController;

  @override
  void initState() {
    super.initState();
    final plugin = PluginManager.instance.getPlugin('calendar_album');
    tagController = (plugin as dynamic).tagController;
    if (widget.controller.selectedTags.isEmpty &&
        widget.controller.entry != null) {
      widget.controller.selectedTags = List.from(widget.controller.entry!.tags);
    }
  }

  /// 标签选择对话框内的文件夹卡片渲染：TagFolderCard + 选中态角标
  Widget _buildFolderTagItem(
    BuildContext context,
    TagItem tag,
    bool isSelected,
  ) {
    final theme = DSThemeBridge.resolve(context);
    final images = tagController.getTagImages(tag.name);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // TagFolderCard 内部依赖有界高度（Expanded），用AspectRatio 撑出格子尺寸
        AspectRatio(
          aspectRatio: 0.8,
          child: TagFolderCard(
            tag: tag.name,
            imageUrls: images,
            count: images.length,
            sticker: tagController.getTagSticker(tag.name),
          ),
        ),
        if (isSelected)
          Positioned(
            right: 0,
            top: 0,
            child: JellyBox(
              width: 22,
              height: 22,
              radius: theme.radii.circle,
              color: theme.primary,
              child: DsIcon(DsIconKind.check, size: 14, color: theme.onPrimary),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 标签来自受管理的标签库，关闭行内自定义输入，仅经对话框增删
    return DSTagInput(
      tags: widget.controller.selectedTags,
      onTagsChanged: widget.readOnly
          ? null
          : (tags) => setState(() {
              widget.controller.selectedTags = List.from(tags);
            }),
      allowCustom: false,
      addLabel: 'calendar_album_add_tag'.tr,
      onAddPressed: widget.readOnly ? null : _showTagManagerDialog,
    );
  }

  Future<void> _showTagManagerDialog() async {
    final result = await tagController.showTagManagerDialog(
      context,
      tagItemBuilder: _buildFolderTagItem,
    );
    if (result != null && mounted) {
      setState(() {
        widget.controller.selectedTags = List.from(result);
      });
    }
  }
}
