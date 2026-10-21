import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Node;
import 'package:graphview/graphview.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart' show WiredDraw, WiredDrawTransition;

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/nodes/controllers/nodes_controller.dart';
import 'package:aboutme/plugins/nodes/models/node.dart' as model;
import 'package:aboutme/plugins/openai/widgets/sketch_tree_edge_renderer.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 节点笔记本的只读思维导图预览（graphview 手绘树）
///
/// 根节点为笔记本标题；点按带子节点的节点仅切换展开/收起，
/// 不提供任何编辑入口。
class NodeMindMapScreen extends StatefulWidget {
  const NodeMindMapScreen({super.key, required this.notebookId});

  final String notebookId;

  @override
  State<NodeMindMapScreen> createState() => _NodeMindMapScreenState();
}

class _GraphBundle {
  _GraphBundle(this.graph, this.controller);

  final Graph graph;
  final GraphViewController controller;
}

class _NodeMindMapScreenState extends State<NodeMindMapScreen> {
  static const String _rootId = '__notebook_root__';

  NodesController? _controller;
  _GraphBundle? _bundle;
  Map<String, model.Node> _nodesById = {};
  String _rootTitle = '';
  String _signature = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = Provider.of<NodesController>(context, listen: false);
    if (_controller != controller) {
      _controller?.removeListener(_onDataChanged);
      _controller = controller;
      controller.addListener(_onDataChanged);
    }
    _syncGraph(controller);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _syncGraph(_controller!);
  }

  /// 节点树有变更（增删/改名/改状态）才重建图，否则保留展开状态
  void _syncGraph(NodesController controller) {
    final notebook = controller.getNotebook(widget.notebookId);
    if (notebook == null || notebook.id.isEmpty) return;
    final signature = _signatureOf(notebook.nodes);
    if (_bundle != null && signature == _signature) {
      if (_rootTitle != notebook.title) {
        setState(() => _rootTitle = notebook.title);
      }
      return;
    }
    _signature = signature;
    setState(() {
      _rootTitle = notebook.title;
      _nodesById = {
        for (final node in _flatten(notebook.nodes)) node.id: node,
      };
      _bundle = _buildGraph(notebook.nodes);
    });
  }

  String _signatureOf(List<model.Node> nodes) {
    final buffer = StringBuffer();
    void walk(List<model.Node> list) {
      for (final node in list) {
        buffer.write('${node.id}:${node.title}:${node.status.index};');
        walk(node.children);
      }
    }

    walk(nodes);
    return buffer.toString();
  }

  List<model.Node> _flatten(List<model.Node> nodes) {
    final result = <model.Node>[];
    void walk(List<model.Node> list) {
      for (final node in list) {
        result.add(node);
        walk(node.children);
      }
    }

    walk(nodes);
    return result;
  }

  /// 顶层带子节点的节点初始收起：首屏只展示 根 + 各顶层节点，
  /// 点按节点展开子树（graphview 自带展开/收起动画）
  _GraphBundle _buildGraph(List<model.Node> roots) {
    final graph = Graph()..isTree = true;
    final controller = GraphViewController();

    final rootNode = Node.Id(_rootId);
    graph.addNode(rootNode);

    void addTree(Node parent, model.Node node) {
      final gvNode = Node.Id(node.id);
      graph.addNode(gvNode);
      graph.addEdge(parent, gvNode);
      for (final child in node.children) {
        addTree(gvNode, child);
      }
    }

    final collapsible = <Node>[];
    for (final node in roots) {
      final gvNode = Node.Id(node.id);
      graph.addNode(gvNode);
      graph.addEdge(rootNode, gvNode);
      for (final child in node.children) {
        addTree(gvNode, child);
      }
      if (node.children.isNotEmpty) collapsible.add(gvNode);
    }
    controller.setInitiallyCollapsedNodes(graph, collapsible);
    return _GraphBundle(graph, controller);
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    return SuperCupertinoNavigationWrapper(
      title: Text('nodes_mindMapPreview'.tr),
      largeTitle: 'nodes_mindMapPreview'.tr,
      enableLargeTitle: false,
      // 思维导图自持平移/缩放手势，外层滚动锁死
      forceCollapsed: true,
      body: bundle == null
          ? const SizedBox.expand()
          : DSThemeBridge(
              child: Builder(
                builder: (context) {
                  final theme = DSThemeBridge.resolve(context);
                  return WiredDraw(
                    key: ValueKey('nodes_mindmap_${widget.notebookId}'),
                    child: GraphView.builder(
                      graph: bundle.graph,
                      controller: bundle.controller,
                      animated: true,
                      autoZoomToFit: true,
                      paint: Paint()
                        ..color = theme.ink.withValues(alpha: 0.6)
                        ..strokeWidth = 2
                        ..style = PaintingStyle.stroke,
                      algorithm: _buildAlgorithm(theme),
                      builder: (Node node) =>
                          _buildNodeWidget(theme, bundle, node),
                    ),
                  );
                },
              ),
            ),
    );
  }

  BuchheimWalkerAlgorithm _buildAlgorithm(AppThemeData theme) {
    final config = BuchheimWalkerConfiguration()
      ..siblingSeparation = 48
      ..subtreeSeparation = 64
      ..levelSeparation = 96
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT;
    return BuchheimWalkerAlgorithm(
      config,
      SketchTreeEdgeRenderer(
        config,
        drawConfig: theme.wired.drawConfig,
        color: theme.ink.withValues(alpha: 0.6),
        strokeWidth: 1.8,
      ),
    );
  }

  Widget _buildNodeWidget(
    AppThemeData theme,
    _GraphBundle bundle,
    Node node,
  ) {
    final id = node.key?.value as String;
    if (id == _rootId) {
      return _MindNodePill(
        _rootTitle,
        icon: DsIconKind.book,
        fillColor: theme.primary,
        foreground: theme.onPrimary,
      );
    }
    final data = _nodesById[id];
    if (data == null) return const SizedBox.shrink();

    final hasChildren = data.children.isNotEmpty;
    final collapsed = bundle.controller.isNodeCollapsed(node);
    return _MindNodePill(
      data.title.isEmpty ? 'nodes_unnamedNode'.tr : data.title,
      icon: hasChildren
          ? (collapsed ? DsIconKind.chevronRight : DsIconKind.chevronDown)
          : null,
      fillColor: hasChildren ? theme.surface : theme.surfaceAlt,
      done: data.status == model.NodeStatus.done,
      doneColor: data.color,
      onTap: hasChildren ? () => _toggleNode(bundle, node) : null,
    );
  }

  void _toggleNode(_GraphBundle bundle, Node node) {
    // 与话题树一致：toggle 后不聚焦被点节点本身，
    // 展开时改为聚焦第一个子节点
    final collapsed = bundle.controller.isNodeCollapsed(node);
    bundle.controller.toggleNodeExpanded(bundle.graph, node);
    if (!collapsed) return;
    final children = bundle.graph.successorsOf(node);
    if (children.isEmpty) return;
    // 布局在下一帧完成，届时再定位子节点位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bundle.controller.animateToNode(ValueKey(children.first.key?.value));
    });
  }
}

/// 导图节点：手绘胶囊（dsSketchDecoration 墨线 + 实底），只读无长按操作
class _MindNodePill extends StatelessWidget {
  const _MindNodePill(
    this.label, {
    this.icon,
    this.fillColor,
    this.foreground,
    this.done = false,
    this.doneColor,
    this.onTap,
  });

  final String label;
  final DsIconKind? icon;
  final Color? fillColor;
  final Color? foreground;

  /// 已完成状态：右侧显示节点色对勾
  final bool done;
  final Color? doneColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final progress = WiredDrawTransition.progressOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 210),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: fillColor,
          radius: BorderRadius.circular(999),
          progress: progress,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              DsIcon(icon!, size: 14, color: foreground ?? theme.textSub),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: DsTypography.caption.copyWith(
                  color: foreground ?? theme.text,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (done) ...[
              const SizedBox(width: 6),
              DsIcon(
                DsIconKind.check,
                size: 14,
                color: doneColor ?? theme.textSub,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
