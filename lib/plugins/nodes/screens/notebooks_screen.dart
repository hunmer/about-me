import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Node;
import 'package:provider/provider.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/plugins/nodes/controllers/nodes_controller.dart';
import 'package:aboutme/plugins/nodes/models/notebook.dart';
import 'package:aboutme/plugins/nodes/models/node.dart';
import 'package:aboutme/widgets/picker/circle_icon_picker.dart';
import 'package:skribble/skribble.dart';
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
                  final selected =
                      notebook.id == controller.selectedNotebook?.id;
                  // 手绘便签:随机倾斜 + 文件夹标签页贴条(标题/选中态);
                  // key 必须在列表直接子级上;挂载即描画入场
                  return HandDrawnStickyItem(
                    key: Key(notebook.id),
                    tiltKey: notebook.id,
                    tapeStyle: HandDrawnTapeStyle.folderTab,
                    tapeTitle: notebook.title,
                    tapeColor: selected ? theme.primary : null,
                    tapeLabelColor: selected ? theme.onPrimary : null,
                    child: WiredDraw(
                      child: ReorderableDelayedDragStartListener(
                        index: index,
                        child: _buildNotebookItem(context, controller, notebook),
                      ),
                    ),
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
    final theme = DSThemeBridge.resolve(context);
    // 手绘便签:随机倾斜 + 文件夹标签页贴条(标题/选中态)
    return HandDrawnListView(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      itemCount: notebooks.length,
      tiltKeyOf: (index) => notebooks[index].id,
      tapeStyle: HandDrawnTapeStyle.folderTab,
      tapeTitleOf: (index) => notebooks[index].title,
      tapeColor: (index) =>
          notebooks[index].id == controller.selectedNotebook?.id
          ? theme.primary
          : null,
      tapeLabelColorOf: (index) =>
          notebooks[index].id == controller.selectedNotebook?.id
          ? theme.onPrimary
          : null,
      itemBuilder: (context, index) => WiredDraw(
        child: _buildNotebookItem(context, controller, notebooks[index]),
      ),
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
    this.onTap,
    this.onMore,
  });

  final Notebook notebook;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final seed = notebook.id.hashCode & 0x7fffffff;
    // 环境描画动画（外层 WiredDraw 注入）；null = 已画完
    final progress = WiredDrawTransition.progressOf(context);

    final nodes = notebook.nodes;

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
      progress: progress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (nodes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'nodes_noNodesYet'.tr,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            )
          else
            // 节点横向滚动条：圆点（节点色）+ 手绘连线 + 标题
            SizedBox(
              height: 56,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < nodes.length; i++) ...[
                      if (i > 0) _RoughConnector(seed: seed + i),
                      _NodeDot(node: nodes[i], seed: seed + i),
                    ],
                  ],
                ),
              ),
            ),
          SizedBox(height: theme.spacing.md),
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

    // 标签页贴条由外层 HandDrawnStickyItem(folderTab) 绘制,
    // 卡体保持左上小圆角为标签让位
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: panel,
      ),
    );
  }
}

/// 节点圆点：节点色描边 + 同色淡底 + 状态图标，标题在下方
class _NodeDot extends StatelessWidget {
  const _NodeDot({required this.node, required this.seed});

  final Node node;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final progress = WiredDrawTransition.progressOf(context);
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: dsSketchDecoration(
              theme: theme,
              circle: true,
              fillColor: node.color.withValues(alpha: 0.2),
              stroke: node.color,
              strokeWidth: 1.8,
              seed: seed,
              progress: progress,
            ),
            child: DsIcon(
              _statusIcon(node.status),
              size: 15,
              color: node.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            node.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }
}

/// 节点圆点间的手绘连线：skribble rough 直线，风格随全局墨线档位
class _RoughConnector extends StatelessWidget {
  const _RoughConnector({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    final progress = WiredDrawTransition.progressOf(context);
    return SizedBox(
      width: 22,
      height: 32,
      child: CustomPaint(
        painter: _RoughLinePainter(
          theme: AppTheme.of(context),
          seed: seed,
          progress: progress,
        ),
      ),
    );
  }
}

class _RoughLinePainter extends CustomPainter {
  _RoughLinePainter({
    required this.theme,
    required this.seed,
    this.progress,
  }) : super(repaint: progress);

  final AppThemeData theme;
  final int seed;

  /// 环境描画动画（外层 WiredDraw 注入）；null = 已画完
  final Animation<double>? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final drawConfig = theme.wired.drawConfig;
    drawConfig.randomizer.reset();
    final generator = Generator(drawConfig, NoFiller());
    final y = size.height / 2;
    final drawable = generator.line(1, y, size.width - 1, y);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..color = theme.ink.withValues(alpha: 0.45);
    RoughDrawing(
      drawable,
      paint,
      paint,
    ).paint(canvas, progress: progress?.value ?? 1, pressure: 0);
  }

  @override
  bool shouldRepaint(_RoughLinePainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.seed != seed ||
      oldDelegate.progress != progress;
}
