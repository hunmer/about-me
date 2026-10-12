import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Node;
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/quill_viewer/quill_viewer.dart';
import 'package:aboutme/plugins/nodes/models/node.dart';

/// 节点状态 → 徽章底色（主题淡彩 wash，对应参考稿 butter/sage/lilac）
Color nodeStatusWash(AppThemeData theme, NodeStatus status) => switch (status) {
  NodeStatus.todo => theme.hatch,
  NodeStatus.doing => theme.warning.withValues(alpha: 0.28),
  NodeStatus.done => theme.success.withValues(alpha: 0.28),
  NodeStatus.none => theme.surfaceAlt,
};

/// 节点状态 → 文案
String nodeStatusLabel(NodeStatus status) => switch (status) {
  NodeStatus.todo => 'nodes_todo'.tr,
  NodeStatus.doing => 'nodes_doing'.tr,
  NodeStatus.done => 'nodes_done'.tr,
  NodeStatus.none => 'nodes_none'.tr,
};

/// 节点树卡片（手绘暖纸风，参考 stitch 树形稿）：
/// 纸底墨线卡 + 右下硬偏移墨影 + 左侧节点色标记条 + 状态徽章 + 标签 + 笔记
///
/// 层级差异（与参考稿一致）：根卡阴影/圆角最大，层级越深越小、底色越次级。
class NodeCard extends StatelessWidget {
  const NodeCard({
    super.key,
    required this.node,
    this.depth = 0,
    this.pathText,
    this.onTap,
    this.onLongPress,
    this.onToggleExpand,
  });

  final Node node;
  final int depth;

  /// 搜索结果场景显示的节点路径（树内为 null）
  final String? pathText;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final seed = node.id.hashCode & 0x7fffffff;

    // 参考稿：3.5 / 2.5 / 1.8 三档硬偏移墨影
    final shadowOffset = depth == 0 ? 3.5 : (depth == 1 ? 2.5 : 2.0);
    final radius = BorderRadius.circular(
      depth == 0 ? 16 : (depth == 1 ? 14 : 12),
    );
    final fill = depth >= 2 ? theme.surfaceAlt : theme.surface;
    final strokeWidth = depth >= 2 ? 1.5 : 1.8;
    final hasChildren = node.children.isNotEmpty;
    final titleStyle =
        depth == 0
            ? DsTypography.heading.copyWith(color: theme.text)
            : DsTypography.body.copyWith(
              color: theme.text,
              fontWeight: FontWeight.w700,
            );

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasChildren && onToggleExpand != null) ...[
              _ExpandButton(
                expanded: node.isExpanded,
                seed: seed + 3,
                onTap: onToggleExpand!,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                node.title.isEmpty ? 'nodes_unnamedNode'.tr : node.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            if (node.status != NodeStatus.none) ...[
              const SizedBox(width: 8),
              _StatusBadge(node: node, seed: seed + 5),
            ],
          ],
        ),
        if (pathText != null && pathText!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            pathText!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
        if (node.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 0; i < node.tags.length; i++)
                _TagChip(tag: node.tags[i], seed: seed + 10 + i),
            ],
          ),
        ],
        if (_hasActualContent(node.notes)) ...[
          const SizedBox(height: 8),
          ClipRect(child: QuillViewer(data: node.notes, selectable: false)),
        ],
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          // 右下硬偏移墨影（零模糊实底影，参考稿 shadow-[3.5px_3.5px_0px_ink]）
          Positioned.fill(
            left: shadowOffset,
            top: shadowOffset,
            child: DecoratedBox(
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.ink,
                stroke: theme.ink,
                strokeWidth: 1.2,
                radius: radius,
                seed: seed + 13,
              ),
            ),
          ),
          // 卡体：纸底 + 墨线框（内容层）
          DecoratedBox(
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: fill,
              radius: radius,
              strokeWidth: strokeWidth,
              seed: seed,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: content,
            ),
          ),
          // 左侧节点色标记条
          Positioned(
            left: 0,
            top: 10,
            child: Container(
              width: 6,
              height: depth == 0 ? 32 : 24,
              decoration: BoxDecoration(
                color: node.color,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _hasActualContent(String notes) {
    try {
      final List<dynamic> delta = json.decode(notes);
      for (var item in delta) {
        if (item is Map<String, dynamic> && item.containsKey('insert')) {
          final insert = item['insert'].toString();
          if (insert.trim().isNotEmpty) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      // 如果解析失败，回退到简单判断
      return notes.trim().isNotEmpty;
    }
  }
}

/// 展开/收起小方钮（参考稿 w-6 rounded-lg 带小影）
class _ExpandButton extends StatelessWidget {
  const _ExpandButton({
    required this.expanded,
    required this.seed,
    required this.onTap,
  });

  final bool expanded;
  final int seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surfaceAlt,
          radius: BorderRadius.circular(8),
          strokeWidth: 1.4,
          seed: seed,
        ),
        child: DsIcon(
          expanded ? DsIconKind.chevronDown : DsIconKind.chevronRight,
          size: 16,
          color: theme.text,
        ),
      ),
    );
  }
}

/// 状态徽章：pill 淡彩 wash + 墨线圈
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.node, required this.seed});

  final Node node;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: nodeStatusWash(theme, node.status),
        stroke: theme.ink.withValues(alpha: 0.4),
        strokeWidth: 1.4,
        radius: DsRadii.pill,
        seed: seed,
      ),
      child: Text(
        nodeStatusLabel(node.status),
        style: DsTypography.label.copyWith(color: theme.text),
      ),
    );
  }
}

/// 标签 chip：小墨线框 + 次级底
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.seed});

  final String tag;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surfaceAlt,
        stroke: theme.ink.withValues(alpha: 0.5),
        strokeWidth: 1.2,
        radius: BorderRadius.circular(6),
        seed: seed,
      ),
      child: Text(tag, style: DsTypography.label.copyWith(color: theme.text)),
    );
  }
}
