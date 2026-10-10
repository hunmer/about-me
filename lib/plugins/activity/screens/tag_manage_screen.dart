import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/activity/screens/activity_timeline_screen/controllers/tag_controller.dart';
import 'package:aboutme/plugins/activity/services/activity_service.dart';
import 'package:aboutme/widgets/tags_dialog/tags_dialog.dart';

/// 标签管理完整页面
///
/// 由弧形底部导航栏左侧的标签入口打开，替代原底部抽屉式标签管理；
/// 修改经 [TagController.updateGroups] 持久化并广播 activity_tags_changed
/// 事件，时间线页收到事件后重载标签（过滤项、图标随之刷新）。
class TagManageScreen extends StatefulWidget {
  const TagManageScreen({super.key, required this.activityService});

  final ActivityService activityService;

  @override
  State<TagManageScreen> createState() => _TagManageScreenState();
}

class _TagManageScreenState extends State<TagManageScreen> {
  TagController? _tagController;

  @override
  void initState() {
    super.initState();
    final controller = TagController(
      activityService: widget.activityService,
      onTagsChanged: () {
        if (mounted) setState(() {});
      },
    );
    controller.initialize().then((_) {
      if (mounted) setState(() => _tagController = controller);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _tagController;
    if (controller == null) {
      // DSLoadingDots 内部取 AppTheme，需包桥
      return Scaffold(
        body: Center(
          child: DSThemeBridge(
            child: Builder(builder: (_) => const DSLoadingDots()),
          ),
        ),
      );
    }

    return DSThemeBridge(
      child: TagsDialog(
        groups: controller.tagGroups,
        config: const TagsDialogConfig(
          title: '标签管理',
          selectionMode: TagsSelectionMode.none,
          enableEditing: true,
          enableBatchEdit: true,
        ),
        displayMode: TagsDisplayMode.embedded,
        onGroupsChanged: controller.updateGroups,
      ),
    );
  }
}
