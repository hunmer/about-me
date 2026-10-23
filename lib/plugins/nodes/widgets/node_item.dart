import 'package:get/get.dart' hide Node;
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/nodes/controllers/nodes_controller.dart';
import 'package:aboutme/plugins/nodes/models/node.dart';
import 'package:aboutme/plugins/nodes/widgets/node_card.dart';
import 'package:aboutme/plugins/nodes/screens/node_edit_screen.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 树内单个节点：卡片 + 父子连线 + 子节点递归 + 长按操作
class NodeItem extends StatelessWidget {
  final Node node;
  final String notebookId;
  final int depth;

  /// 是否为同级最后一个：末枝的竖线止于肘部，不贯穿到底
  final bool isLast;

  const NodeItem({
    super.key,
    required this.node,
    required this.notebookId,
    required this.depth,
    this.isLast = true,
  });

  /// 连线槽宽（参考稿 ml-6 / ml-4 两档）
  double get _gutter => depth == 0 ? 24 : 20;

  /// 肘部高度：对齐子卡片头部行中心
  double get _elbowY => depth == 0 ? 26 : 22;

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<NodesController>(context);
    final theme = AppTheme.of(context);
    final seed = node.id.hashCode & 0x7fffffff;
    final drawProgress = WiredDrawTransition.progressOf(context);

    // 连线层包住整项（卡片 + 间隔 + 子树）：
    // 非末枝的主干贯穿全高，展开子树后与下一同级兄弟仍连续
    return Stack(
      children: [
        if (depth > 0)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _gutter,
            child: CustomPaint(
              painter: _TreeRailPainter(
                theme: theme,
                seed: seed + 17,
                isLast: isLast,
                elbowY: _elbowY,
                thin: depth >= 2,
                progress: drawProgress,
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(left: depth > 0 ? _gutter : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              NodeCard(
                node: node,
                depth: depth,
                onTap:
                    node.children.isNotEmpty
                        ? () => controller.toggleNodeExpansion(
                          notebookId,
                          node.id,
                        )
                        : () => _openEditor(context, controller, node),
                onLongPress: () => _showNodeActions(context, controller),
                onToggleExpand:
                    node.children.isNotEmpty
                        ? () => controller.toggleNodeExpansion(
                          notebookId,
                          node.id,
                        )
                        : null,
              ),
              SizedBox(height: depth == 0 ? 16 : 8),
              // 子节点递归：展开挂载时 WiredDraw 触发手绘描画入场
              //（收起即卸载，再展开重新描画）
              if (node.isExpanded && node.children.isNotEmpty)
                WiredDraw(
                  child: Padding(
                    padding: EdgeInsets.only(left: depth == 0 ? _gutter : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < node.children.length; i++)
                          NodeItem(
                            node: node.children[i],
                            notebookId: notebookId,
                            depth: depth + 1,
                            isLast: i == node.children.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openEditor(
    BuildContext context,
    NodesController controller,
    Node target,
  ) {
    NavigationHelper.push(
      context,
      ChangeNotifierProvider<NodesController>.value(
        value: controller,
        child: NodeEditScreen(notebookId: notebookId, node: target),
      ),
    );
  }

  void _updateNode(
    NodesController controller,
    BuildContext context,
    Node updated,
  ) {
    controller.updateNode(notebookId, updated);
    Navigator.pop(context);
  }

  Node _copyWith(Node source, {NodeStatus? status, Color? color}) => Node(
    sdkVersion: source.sdkVersion,    id: source.id,
    title: source.title,
    createdAt: source.createdAt,
    tags: source.tags,
    status: status ?? source.status,
    startDate: source.startDate,
    endDate: source.endDate,
    customFields: source.customFields,
    notes: source.notes,
    parentId: source.parentId,
    pathValue: source.pathValue,
    color: color ?? source.color,
    children: source.children,
    isExpanded: source.isExpanded,
  );

  /// 长按操作：状态 / 颜色 / 编辑 / 增删（DS 底部 sheet）
  void _showNodeActions(
    BuildContext context,
    NodesController controller,
  ) {
    const commonColors = [
      Colors.grey,
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.yellow,
      Colors.lime,
      Colors.green,
      Colors.teal,
      Colors.cyan,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
    ];

    SmoothBottomSheet.showWithTitle(
      context: context,
      title: node.title.isEmpty ? 'nodes_unnamedNode'.tr : node.title,
      child: Builder(
        builder: (sheetContext) {
          final theme = AppTheme.of(sheetContext);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'nodes_status'.tr,
                      style: DsTypography.label.copyWith(color: theme.textSub),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final status in [
                          NodeStatus.todo,
                          NodeStatus.doing,
                          NodeStatus.done,
                        ])
                          DSChip(
                            label: nodeStatusLabel(status),
                            selected: node.status == status,
                            onSelected: (selected) {
                              if (selected) {
                                _updateNode(
                                  controller,
                                  sheetContext,
                                  _copyWith(node, status: status),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'nodes_nodeColor'.tr,
                      style: DsTypography.label.copyWith(color: theme.textSub),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: commonColors.length,
                        itemBuilder: (context, index) {
                          final color = commonColors[index];
                          final selected = node.color.value == color.value;
                          return GestureDetector(
                            onTap: () => _updateNode(
                              controller,
                              sheetContext,
                              _copyWith(node, color: color),
                            ),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: dsSketchDecoration(
                                theme: theme,
                                circle: true,
                                fillColor: color,
                                stroke: selected ? theme.text : theme.ink,
                                strokeWidth: selected ? 2.6 : 1.4,
                                seed: index + 1,
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SmoothSheetAction(
                icon: DsIconKind.edit,
                label: 'nodes_editNode'.tr,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openEditor(context, controller, node);
                },
              ),
              SmoothSheetAction(
                icon: DsIconKind.plus,
                label: 'nodes_addChildNode'.tr,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _addNode(context, controller, parentOf: node);
                },
              ),
              SmoothSheetAction(
                icon: DsIconKind.reply,
                label: 'nodes_addSiblingNode'.tr,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _addNode(context, controller, parentId: node.parentId);
                },
              ),
              SmoothSheetAction(
                icon: DsIconKind.trash,
                label: 'nodes_deleteNode'.tr,
                destructive: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDeleteConfirmation(context, controller);
                },
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  void _addNode(
    BuildContext context,
    NodesController controller, {
    Node? parentOf,
    String? parentId,
  }) {
    final newNode = Node(
      id: const Uuid().v4(),
      title: '',
      createdAt: DateTime.now(),
      parentId: parentOf?.id ?? parentId ?? '',
      status: NodeStatus.todo,
    );
    _openEditor(context, controller, newNode);
  }

  void _showDeleteConfirmation(
    BuildContext context,
    NodesController controller,
  ) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSDialog(
            title: 'nodes_deleteNode'.tr,
            message: 'nodes_deleteNodeConfirmation'.trParams({
              'title': node.title,
            }),
            cancelText: 'nodes_cancel'.tr,
            confirmText: 'nodes_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () {
              controller.deleteNode(notebookId, node.id);
              Navigator.pop(dialogContext);
            },
          ),
    );
  }
}

/// 树形连线：竖主干 + 水平肘线（rough 手绘，风格随全局墨线档位）
class _TreeRailPainter extends CustomPainter {
  _TreeRailPainter({
    required this.theme,
    required this.seed,
    required this.isLast,
    required this.elbowY,
    required this.thin,
    this.progress,
  }) : super(repaint: progress);

  final AppThemeData theme;
  final int seed;
  final bool isLast;
  final double elbowY;

  /// 层级越深线越细越淡（参考稿 2.2 → 2.0 两档）
  final bool thin;

  /// 环境描画动画（外层 WiredDraw 注入）；null = 已画完
  final Animation<double>? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final drawConfig = theme.wired.drawConfig;
    drawConfig.randomizer.reset();
    final generator = Generator(drawConfig, NoFiller());
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = thin ? 1.6 : 2.0
          ..color = theme.ink.withValues(alpha: thin ? 0.45 : 0.6);

    // 参考稿弧形肘线：主干竖线在 ry 处交给贝塞尔弯，弯出后接水平支线
    final x = 1.5;
    final rx = thin ? 8.0 : 10.0;
    final ry = thin ? 6.0 : 8.0;
    final endY = isLast ? elbowY - ry : size.height;
    final trunk = generator.line(x, 0, x, endY);
    final branch =
        generator.curvePath([
          PointD(x, elbowY - ry),
          PointD(x + 0.6, elbowY - ry * 0.25),
          PointD(x + rx * 0.6, elbowY - 0.5),
          PointD(x + rx, elbowY),
        ]);
    final tail = generator.line(x + rx, elbowY, size.width - 2, elbowY);
    final t = progress?.value ?? 1;
    RoughDrawing(trunk, paint, paint).paint(canvas, progress: t, pressure: 0);
    RoughDrawing(branch, paint, paint).paint(canvas, progress: t, pressure: 0);
    RoughDrawing(tail, paint, paint).paint(canvas, progress: t, pressure: 0);
  }

  @override
  bool shouldRepaint(_TreeRailPainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.seed != seed ||
      oldDelegate.isLast != isLast ||
      oldDelegate.elbowY != elbowY ||
      oldDelegate.thin != thin ||
      oldDelegate.progress != progress;
}
