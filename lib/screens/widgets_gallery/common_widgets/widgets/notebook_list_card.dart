/// 笔记本列表卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 笔记本列表（数据色手绘图标 + 展开节点子列表 + 数据色竖条指示）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 笔记本列表卡片小组件
///
/// 显示笔记本和节点列表，支持展开/折叠
class NotebookListCardWidget extends StatefulWidget {
  /// 笔记本数量
  final int notebookCount;

  /// 笔记本项目列表
  final List<NotebookItemData> items;

  /// 是否为内联模式
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const NotebookListCardWidget({
    super.key,
    required this.notebookCount,
    required this.items,
    this.inline = false,
    this.size = const LargeSize(),
  });

  /// 从 props 创建实例
  factory NotebookListCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final itemsList = props['items'] as List<dynamic>?;
    final items = itemsList?.map((item) {
          final data = item as Map<String, dynamic>;
          final nodesList = data['nodes'] as List<dynamic>?;
          return NotebookItemData(
            id: data['id'] as String? ?? '',
            title: data['title'] as String? ?? '',
            icon: data['icon'] is String
                ? dynamicIconData(int.parse(data['icon'] as String), fontFamily: 'MaterialIcons')
                : Icons.book,
            color: data['color'] != null ? Color(data['color'] as int) : null,
            nodeCount: data['nodeCount'] as int? ?? 0,
            nodes: nodesList?.map((nodeData) {
                  final node = nodeData as Map<String, dynamic>;
                  return NodeData(
                    id: node['id'] as String? ?? '',
                    title: node['title'] as String? ?? '',
                    depth: node['depth'] as int? ?? 0,
                    color: node['color'] != null ? Color(node['color'] as int) : null,
                    status: node['status'] as String? ?? 'none',
                  );
                }).toList() ?? [],
          );
        }).toList() ?? [];

    // 从 props 中读取 size，如果不存在则使用传入的 size 参数
    HomeWidgetSize widgetSize = size;
    if (props['size'] != null) {
      widgetSize = HomeWidgetSize.fromJson(
        props['size'] as Map<String, dynamic>,
      );
    }

    return NotebookListCardWidget(
      notebookCount: props['notebookCount'] as int? ?? 0,
      items: items,
      inline: props['inline'] as bool? ?? false,
      size: widgetSize,
    );
  }

  @override
  State<NotebookListCardWidget> createState() => _NotebookListCardWidgetState();
}

class _NotebookListCardWidgetState extends State<NotebookListCardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          width: widget.inline ? double.maxFinite : null,
          height: widget.inline ? double.maxFinite : null,
          radius: BorderRadius.circular(24 * widget.size.scale),
          padding: widget.size.getPadding(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Padding(
                padding: EdgeInsets.only(bottom: widget.size.getItemSpacing()),
                child: Text(
                  '${widget.notebookCount} 笔记本',
                  style: TextStyle(
                    fontSize: widget.size.getSubtitleFontSize(),
                    fontWeight: FontWeight.w600,
                    color: theme.text,
                  ),
                ),
              ),
              // 笔记本列表
              Expanded(
                child: ListView.separated(
                  itemCount: widget.items.length,
                  separatorBuilder: (context, index) => Container(
                    height: 1,
                    color: theme.ink.withValues(alpha: 0.18),
                  ),
                  itemBuilder: (context, index) {
                    final notebook = widget.items[index];
                    return _NotebookItemWidget(
                      notebook: notebook,
                      size: widget.size,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotebookItemWidget extends StatefulWidget {
  final NotebookItemData notebook;
  final HomeWidgetSize size;

  const _NotebookItemWidget({
    required this.notebook,
    required this.size,
  });

  @override
  State<_NotebookItemWidget> createState() => _NotebookItemWidgetState();
}

class _NotebookItemWidgetState extends State<_NotebookItemWidget> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final notebook = widget.notebook;

    return InkWell(
      onTap: _toggleExpanded,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: widget.size.getItemSpacing()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 笔记本标题行
            Row(
              children: [
                WiredIcon(
                  icon: notebook.icon,
                  size: widget.size.getIconSize(),
                  color: notebook.color ?? theme.primary,
                  drawConfig: theme.wired.drawConfig,
                ),
                SizedBox(width: widget.size.getItemSpacing()),
                Expanded(
                  child: Text(
                    notebook.title,
                    style: TextStyle(
                      fontSize: widget.size.getSubtitleFontSize(),
                      fontWeight: FontWeight.w500,
                      color: theme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${notebook.nodeCount} 节点',
                  style: TextStyle(
                    fontSize: widget.size.getSubtitleFontSize() * 0.85,
                    color: theme.textSub,
                  ),
                ),
              ],
            ),
            // 节点列表（展开时显示）
            if (_isExpanded && notebook.nodes.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  left: widget.size.getIconSize() + widget.size.getItemSpacing(),
                  top: widget.size.getItemSpacing(),
                ),
                child: Column(
                  children: notebook.nodes.map((node) {
                    return _NodeItemWidget(
                      node: node,
                      depth: node.depth,
                      size: widget.size,
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NodeItemWidget extends StatelessWidget {
  final NodeData node;
  final int depth;
  final HomeWidgetSize size;

  const _NodeItemWidget({
    required this.node,
    required this.depth,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final indent = depth * 16.0;
    return Padding(
      padding: EdgeInsets.only(
        left: indent,
        top: size.getItemSpacing() * 0.5,
      ),
      child: Row(
        children: [
          // 数据色竖条（节点分类色）
          Container(
            width: 3,
            height: size.getSubtitleFontSize() * 1.2,
            decoration: BoxDecoration(
              color: node.color ?? theme.textSub,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          SizedBox(width: size.getItemSpacing()),
          Expanded(
            child: Text(
              node.title,
              style: TextStyle(
                fontSize: (size.getSubtitleFontSize() * (1.0 - depth * 0.05)).clamp(10.0, size.getSubtitleFontSize()),
                fontWeight: FontWeight.w400,
                color: theme.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 笔记本项目数据
class NotebookItemData {
  final String id;
  final String title;
  final IconData icon;
  final Color? color;
  final int nodeCount;
  final List<NodeData> nodes;

  const NotebookItemData({
    required this.id,
    required this.title,
    required this.icon,
    this.color,
    required this.nodeCount,
    required this.nodes,
  });
}

/// 节点数据
class NodeData {
  final String id;
  final String title;
  final int depth;
  final Color? color;
  final String status;

  const NodeData({
    required this.id,
    required this.title,
    required this.depth,
    this.color,
    required this.status,
  });
}
