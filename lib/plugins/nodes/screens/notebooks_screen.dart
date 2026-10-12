import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Node;
import 'package:provider/provider.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/plugins/nodes/controllers/nodes_controller.dart';
import 'package:aboutme/plugins/nodes/models/notebook.dart';
import 'package:aboutme/plugins/nodes/models/node.dart';
import 'package:aboutme/widgets/picker/circle_icon_picker.dart';
import 'nodes_screen.dart';

class NotebooksScreen extends StatefulWidget {
  const NotebooksScreen({super.key});

  @override
  State<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends State<NotebooksScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<NodesController>(context);
    final theme = DSThemeBridge.resolve(context);

    // 过滤笔记本列表
    final filteredNotebooks =
        _searchQuery.isEmpty
            ? controller.notebooks
            : controller.notebooks.where((notebook) {
              return notebook.title.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );
            }).toList();

    return SuperCupertinoNavigationWrapper(
      title: Text('nodes_notebooks'.tr),
      largeTitle: 'nodes_notebooks'.tr,
      enableSearchBar: true,
      searchPlaceholder: 'nodes_searchNotebooks'.tr,
      onSearchChanged: (query) {
        setState(() {
          _searchQuery = query;
        });
      },
      searchBody: _buildSearchResults(context, filteredNotebooks, controller),
      actions: [
        // SuperAppBar 的 actions 经 Overlay 渲染,DS 组件需自带 DSThemeBridge
        DSThemeBridge(
          child: Builder(
            builder: (buildContext) {
              return DSIconButton(
                icon: DsIconKind.plus,
                size: 40,
                tooltip: 'nodes_addNotebook'.tr,
                onPressed: () => _showNotebookFormSheet(context),
              );
            },
          ),
        ),
      ],
      body:
          filteredNotebooks.isEmpty
              ? _buildEmptyState(searching: _searchQuery.isNotEmpty)
              : ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: EdgeInsets.fromLTRB(
                  theme.spacing.md,
                  theme.spacing.sm,
                  theme.spacing.md,
                  MediaQuery.paddingOf(context).bottom + theme.spacing.xxl,
                ),
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) => Material(
                      elevation: 0,
                      color: Colors.transparent,
                      shadowColor: Colors.transparent,
                      child: child,
                    ),
                    child: child,
                  );
                },
                itemCount: filteredNotebooks.length,
                itemBuilder: (context, index) {
                  final notebook = filteredNotebooks[index];
                  return ReorderableDelayedDragStartListener(
                    key: Key(notebook.id),
                    index: index,
                    child: _buildNotebookItem(context, controller, notebook),
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  controller.reorderNotebooks(oldIndex, newIndex);
                },
              ),
    );
  }

  void _openNotebook(
    BuildContext context,
    NodesController controller,
    Notebook notebook,
  ) {
    controller.selectNotebook(notebook);
    NavigationHelper.push(
      context,
      ChangeNotifierProvider<NodesController>.value(
        value: controller,
        child: NodesScreen(notebook: notebook),
      ),
    );
  }

  Widget _buildNotebookItem(
    BuildContext context,
    NodesController controller,
    Notebook notebook,
  ) {
    final theme = DSThemeBridge.resolve(context);
    return Dismissible(
      key: Key(notebook.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        await _confirmDeleteNotebook(context, notebook);
        return false;
      },
      background: Container(
        color: theme.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: DsIcon(DsIconKind.trash, size: 28, color: theme.onDanger),
      ),
      child: _NotebookCard(
        notebook: notebook,
        selected: notebook.id == controller.selectedNotebook?.id,
        onTap: () => _openNotebook(context, controller, notebook),
        onMore: () => _showNotebookActions(context, notebook),
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    List<Notebook> notebooks,
    NodesController controller,
  ) {
    if (_searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }
    if (notebooks.isEmpty) {
      return _buildEmptyState(searching: true);
    }
    return ListView.builder(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      itemCount: notebooks.length,
      itemBuilder: (context, index) =>
          _buildNotebookItem(context, controller, notebooks[index]),
    );
  }

  Widget _buildEmptyState({required bool searching}) {
    final theme = DSThemeBridge.resolve(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DsIcon(
            searching ? DsIconKind.search : DsIconKind.book,
            size: 64,
            color: theme.textSub,
          ),
          const SizedBox(height: 16),
          Text(
            searching
                ? 'nodes_noResultsFound'.tr
                : 'nodes_noNotebooks'.tr,
            style: DsTypography.body.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }

  /// 新建/编辑笔记本：底部 sheet 表单（图标 + 颜色 + 标题）
  void _showNotebookFormSheet(BuildContext context, {Notebook? notebook}) {
    final controller = Provider.of<NodesController>(context, listen: false);
    final titleController = TextEditingController(text: notebook?.title);
    IconData selectedIcon = notebook?.icon ?? Icons.book;
    Color selectedColor = notebook?.color ?? Colors.blue;

    showDSBottomSheet(
      context: context,
      title:
          (notebook == null
                  ? 'nodes_addNotebook'
                  : 'nodes_editNotebook')
              .tr,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleIconPicker(
                    currentIcon: selectedIcon,
                    backgroundColor: selectedColor,
                    onIconSelected: (icon) =>
                        setSheetState(() => selectedIcon = icon),
                    onColorSelected: (color) =>
                        setSheetState(() => selectedColor = color),
                  ),
                  const SizedBox(height: 16),
                  DSInput(
                    controller: titleController,
                    label: 'nodes_notebookTitle'.tr,
                  ),
                  const SizedBox(height: 16),
                  DSButton(
                    label: 'nodes_save'.tr,
                    expand: true,
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      if (notebook == null) {
                        controller.addNotebook(
                          title,
                          selectedIcon,
                          color: selectedColor,
                        );
                      } else {
                        controller.updateNotebook(
                          Notebook(
                            id: notebook.id,
                            title: title,
                            icon: selectedIcon,
                            color: selectedColor,
                            nodes: notebook.nodes,
                          ),
                        );
                      }
                      Navigator.pop(sheetContext);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 卡片操作：编辑 / 删除
  void _showNotebookActions(BuildContext context, Notebook notebook) {
    showDSBottomSheet(
      context: context,
      title: notebook.title,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DSSheetAction(
              icon: DsIconKind.edit,
              label: 'nodes_editNotebook'.tr,
              onTap: () {
                Navigator.pop(sheetContext);
                _showNotebookFormSheet(context, notebook: notebook);
              },
            ),
            DSSheetAction(
              icon: DsIconKind.trash,
              label: 'nodes_deleteNotebook'.tr,
              destructive: true,
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDeleteNotebook(context, notebook);
              },
            ),
          ],
        );
      },
    );
  }

  /// 删除确认弹窗（确认后直接删除）
  Future<void> _confirmDeleteNotebook(
    BuildContext context,
    Notebook notebook,
  ) async {
    final controller = Provider.of<NodesController>(context, listen: false);
    await showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSDialog(
            title: 'nodes_deleteNotebook'.tr,
            message: 'nodes_deleteNotebookConfirmation'.trParams({
              'notebookTitle': notebook.title,
            }),
            cancelText: 'nodes_cancel'.tr,
            confirmText: 'nodes_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () {
              controller.deleteNotebook(notebook.id);
              Navigator.pop(dialogContext, true);
            },
          ),
    );
  }
}

/// 节点状态 → 卡片内行图标
DsIconKind _statusIcon(NodeStatus status) => switch (status) {
  NodeStatus.todo => DsIconKind.clipboard,
  NodeStatus.doing => DsIconKind.clock,
  NodeStatus.done => DsIconKind.check,
  NodeStatus.none => DsIconKind.minus,
};

/// 笔记本卡片：左上"文件夹标签页"标题 + 排线卡体（节点行 + 底部头像区）
/// 设计参考：标签页内标题、卡内图标行、底部小标签 + 圆头像 + 名称
class _NotebookCard extends StatelessWidget {
  const _NotebookCard({
    required this.notebook,
    required this.selected,
    this.onTap,
    this.onMore,
  });

  final Notebook notebook;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final seed = notebook.id.hashCode & 0x7fffffff;

    final rows = notebook.nodes.take(3).toList();
    final extraCount = notebook.nodes.length - rows.length;

    // 标签页：纸底墨线（选中态换主题色实底）
    final tab = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: selected ? theme.primary : theme.surface,
        stroke: selected ? theme.primary : theme.ink,
        strokeWidth: selected ? 2 : 1.8,
        radius: const BorderRadius.vertical(top: Radius.circular(10)),
        seed: seed,
      ),
      child: Text(
        notebook.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DsTypography.body.copyWith(
          color: selected ? theme.onPrimary : theme.text,
        ),
      ),
    );

    final panel = DsSketchPanel(
      theme: theme,
      seed: seed,
      hachureColor: notebook.color,
      radius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(14),
        bottomLeft: Radius.circular(14),
        bottomRight: Radius.circular(14),
      ),
      padding: EdgeInsets.fromLTRB(
        theme.spacing.lg,
        theme.spacing.lg,
        theme.spacing.lg,
        theme.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'nodes_noNodesYet'.tr,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            )
          else ...[
            for (final node in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    DsIcon(
                      _statusIcon(node.status),
                      size: 18,
                      color:
                          node.status == NodeStatus.done
                              ? theme.primary
                              : theme.textSub,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        node.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsTypography.caption.copyWith(
                          color: theme.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (extraCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    DsIcon(DsIconKind.more, size: 18, color: theme.textSub),
                    const SizedBox(width: 8),
                    Text(
                      'nodes_moreNodesHint'.trParams({'count': '$extraCount'}),
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          SizedBox(height: theme.spacing.md),
          // 底部：小标签 + 头像 + 节点数 + 更多操作
          Text(
            'nodes_nodes'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              DSAvatar(
                size: 30,
                color: notebook.color,
                child: Icon(notebook.icon, size: 16, color: theme.onPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'nodes_nodeCount'.trParams({
                    'count': '${notebook.nodes.length}',
                  }),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
              ),
              DSIconButton(
                icon: DsIconKind.more,
                size: 32,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'nodes_editNotebook'.tr,
                onPressed: onMore,
              ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            // 卡体下移，让标签页叠在卡体上沿，形成文件夹标签效果
            Padding(padding: const EdgeInsets.only(top: 16), child: panel),
            Positioned(left: 4, top: 0, child: tab),
          ],
        ),
      ),
    );
  }
}
