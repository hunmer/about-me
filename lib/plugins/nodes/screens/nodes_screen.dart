import 'package:get/get.dart' hide Node;
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/plugins/nodes/controllers/nodes_controller.dart';
import 'package:aboutme/plugins/nodes/models/notebook.dart';
import 'package:aboutme/plugins/nodes/models/node.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/nodes/widgets/node_card.dart';
import 'package:aboutme/plugins/nodes/widgets/node_item.dart';
import 'node_edit_screen.dart';
import 'node_mind_map_screen.dart';
import 'package:uuid/uuid.dart';

class NodesScreen extends StatefulWidget {
  final Notebook notebook;

  const NodesScreen({super.key, required this.notebook});

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<NodesController>(context, listen: true);
    final theme = DSThemeBridge.resolve(context);

    final currentNotebook = controller.getNotebook(widget.notebook.id);

    return SuperCupertinoNavigationWrapper(
      title: Text(widget.notebook.title),
      largeTitle: widget.notebook.title,
      enableLargeTitle: false,

      enableSearchBar: true,
      searchPlaceholder: 'nodes_searchNodeHint'.tr,
      onSearchChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      actions: [
        // SuperAppBar 的 actions 经 Overlay 渲染,DS 组件需自带 DSThemeBridge
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final t = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.layers,
                size: 36,
                color: t.surfaceAlt,
                iconColor: t.textSub,
                tooltip: 'nodes_mindMapPreview'.tr,
                onPressed: () => _openMindMap(context, controller),
              );
            },
          ),
        ),
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final t = DSThemeBridge.resolve(context);
              return DSPopover(
                width: 200,
                contentBuilder: (popoverContext, close) {
                  final pt = DSThemeBridge.resolve(popoverContext);
                  Widget menuRow(
                    DsIconKind icon,
                    String label,
                    VoidCallback onTap, {
                    bool destructive = false,
                  }) {
                    final tint = destructive ? pt.danger : pt.text;
                    return Pressable(
                      onPressed: () {
                        close();
                        onTap();
                      },
                      builder: (context, states) {
                        final pressed = states.contains(WidgetState.pressed);
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: pt.spacing.sm,
                            vertical: pt.spacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: pressed ? pt.surfaceAlt : null,
                            borderRadius: pt.radii.sm,
                          ),
                          child: Row(
                            children: [
                              DsIcon(icon, size: 18, color: tint),
                              SizedBox(width: pt.spacing.sm),
                              Text(
                                label,
                                style: DsTypography.body.copyWith(
                                  color: tint,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      menuRow(
                        DsIconKind.copy,
                        'nodes_copyToText'.tr,
                        () => _copyToText(context, widget.notebook),
                      ),
                      menuRow(
                        DsIconKind.trash,
                        'nodes_clearNodes'.tr,
                        () => _showClearConfirmDialog(context, controller),
                        destructive: true,
                      ),
                    ],
                  );
                },
                child: JellyBox(
                  width: 36,
                  height: 36,
                  radius: t.radii.circle,
                  color: t.surfaceAlt,
                  child: Center(
                    child: DsIcon(
                      DsIconKind.more,
                      size: 18,
                      color: t.textSub,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
      body: Stack(
        children: [
          currentNotebook?.nodes.isEmpty ?? true
              ? _buildEmptyState(
                icon: DsIconKind.spaceDashboard,
                message: 'nodes_emptyNodesMessage'.tr,
              )
              : ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.paddingOf(context).bottom + 96,
                ),
                itemCount: currentNotebook?.nodes.length ?? 0,
                itemBuilder: (context, index) {
                  return NodeItem(
                    node: currentNotebook!.nodes[index],
                    notebookId: widget.notebook.id,
                    depth: 0,
                    isLast: index == currentNotebook.nodes.length - 1,
                  );
                },
              ),
          // FAB 覆盖层
          Positioned(
            bottom: 16,
            right: 16,
            child: DSThemeBridge(
              // DSFab 内部取 AppTheme，需包桥
              child: DSFab(onPressed: () => _addRootNode(context)),
            ),
          ),
        ],
      ),
      searchBody: _buildSearchBody(theme, controller, currentNotebook),
    );
  }

  Widget _buildEmptyState({required DsIconKind icon, required String message}) {
    return Center(child: DSEmptyState(icon: icon, title: message));
  }

  void _copyToText(BuildContext context, Notebook notebook) {
    final buffer = StringBuffer();

    void processNode(Node node, int depth) {
      buffer.writeln('${'  ' * depth}${node.title}');
      if (node.notes.isNotEmpty) {
        buffer.writeln('${'  ' * (depth + 1)}${node.notes}');
      }
      for (var child in node.children) {
        processNode(child, depth + 1);
      }
    }

    for (var node in notebook.nodes) {
      processNode(node, 0);
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    Toast.success('nodes_copiedToClipboard'.tr);
  }

  void _showClearConfirmDialog(
    BuildContext context,
    NodesController controller,
  ) {
    final current = controller.getNotebook(widget.notebook.id);
    if (current == null) return;

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSDialog(
            title: 'nodes_clearNodesTitle'.tr,
            message: 'nodes_clearNodesConfirm'.tr,
            cancelText: 'nodes_cancel'.tr,
            confirmText: 'nodes_clear'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () {
              controller.clearNodes(current.id);
              Navigator.pop(dialogContext);
              Toast.success('nodes_nodesCleared'.tr);
            },
          ),
    );
  }

  void _openMindMap(BuildContext context, NodesController controller) {
    NavigationHelper.push(
      context,
      ChangeNotifierProvider<NodesController>.value(
        value: controller,
        child: NodeMindMapScreen(notebookId: widget.notebook.id),
      ),
    );
  }

  void _addRootNode(BuildContext context) {
    final controller = Provider.of<NodesController>(context, listen: false);
    final newNode = Node(
      id: const Uuid().v4(),
      title: '',
      status: NodeStatus.todo,
      createdAt: DateTime.now(),
    );

    NavigationHelper.push(
      context,
      ChangeNotifierProvider<NodesController>.value(
        value: controller,
        child: NodeEditScreen(
          notebookId: widget.notebook.id,
          node: newNode,
          isNew: true,
        ),
      ),
    );
  }

  void _openNodeEditor(
    BuildContext context,
    NodesController controller,
    Node node,
  ) {
    NavigationHelper.push(
      context,
      ChangeNotifierProvider<NodesController>.value(
        value: controller,
        child: NodeEditScreen(
          notebookId: widget.notebook.id,
          node: node,
          isNew: false,
        ),
      ),
    );
  }

  /// 构建搜索结果页面
  Widget _buildSearchBody(
    AppThemeData theme,
    NodesController controller,
    Notebook? currentNotebook,
  ) {
    if (_searchQuery.isEmpty) {
      return _buildEmptyState(
        icon: DsIconKind.search,
        message: 'nodes_searchEmpty'.tr,
      );
    }

    // 执行搜索：匹配节点标题或笔记内容
    final allNodes = _getAllNodes(currentNotebook?.nodes ?? []);
    final query = _searchQuery.toLowerCase();
    final matchedNodes = allNodes.where((node) {
      return node.title.toLowerCase().contains(query) ||
          node.notes.toLowerCase().contains(query);
    }).toList();

    if (matchedNodes.isEmpty) {
      return _buildEmptyState(
        icon: DsIconKind.search,
        message: 'nodes_searchNoResults'.tr,
      );
    }

    // 显示搜索结果（树卡片样式 + 节点路径）
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      itemCount: matchedNodes.length,
      itemBuilder: (context, index) {
        final node = matchedNodes[index];
        final path = controller.getNodePath(widget.notebook.id, node.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NodeCard(
            node: node,
            pathText: path.join(' / '),
            onTap: () => _openNodeEditor(context, controller, node),
          ),
        );
      },
    );
  }

  /// 递归获取所有节点（包括子节点）
  List<Node> _getAllNodes(List<Node> nodes) {
    final result = <Node>[];
    for (final node in nodes) {
      result.add(node);
      if (node.children.isNotEmpty) {
        result.addAll(_getAllNodes(node.children));
      }
    }
    return result;
  }
}
