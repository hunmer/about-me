/// 待办节点列表小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘图标 + 标题 + 翻牌计数 / 待办节点列表（数据色竖条、逐项错峰浮现）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 待办节点列表小组件
///
/// 显示所有待办节点列表
class TodoNodesListWidget extends StatefulWidget {
  /// 待办数量
  final int todoCount;

  /// 待办节点项列表
  final List<TodoNodeItemData> items;

  /// 更多任务数量
  final int moreCount;

  /// 是否为内联模式
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const TodoNodesListWidget({
    super.key,
    required this.todoCount,
    required this.items,
    required this.moreCount,
    this.inline = false,
    this.size = const LargeSize(),
  });

  /// 从 props 创建实例
  factory TodoNodesListWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final itemsList = props['items'] as List<dynamic>?;
    final items = itemsList?.map((item) {
          final data = item as Map<String, dynamic>;
          return TodoNodeItemData(
            id: data['id'] as String? ?? '',
            notebookId: data['notebookId'] as String? ?? '',
            notebookTitle: data['notebookTitle'] as String? ?? '',
            nodeId: data['nodeId'] as String? ?? '',
            title: data['title'] as String? ?? '',
            path: data['path'] as String? ?? '',
            color: data['color'] != null ? Color(data['color'] as int) : null,
          );
        }).toList() ?? [];

    // 从 props 中读取 size，如果不存在则使用传入的 size 参数
    HomeWidgetSize widgetSize = size;
    if (props['size'] != null) {
      widgetSize = HomeWidgetSize.fromJson(
        props['size'] as Map<String, dynamic>,
      );
    }

    return TodoNodesListWidget(
      todoCount: props['todoCount'] as int? ?? 0,
      items: items,
      moreCount: props['moreCount'] as int? ?? 0,
      inline: props['inline'] as bool? ?? false,
      size: widgetSize,
    );
  }

  @override
  State<TodoNodesListWidget> createState() => _TodoNodesListWidgetState();
}

class _TodoNodesListWidgetState extends State<TodoNodesListWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          width: widget.inline ? double.maxFinite : null,
          height: widget.inline ? double.maxFinite : null,
          radius: BorderRadius.circular(24 * scale),
          padding: widget.size.getPadding(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  WiredIcon(
                    icon: Icons.check_circle_outline,
                    size: widget.size.getIconSize(),
                    color: theme.primary,
                    drawConfig: theme.wired.drawConfig,
                  ),
                  SizedBox(width: widget.size.getItemSpacing()),
                  Text(
                    '待办节点',
                    style: TextStyle(
                      fontSize: widget.size.getSubtitleFontSize(),
                      fontWeight: FontWeight.w600,
                      color: theme.text,
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return AnimatedFlipCounter(
                        value: widget.todoCount.toDouble() * _animation.value,
                        textStyle: TextStyle(
                          fontSize: widget.size.getSubtitleFontSize(),
                          fontWeight: FontWeight.w700,
                          color: theme.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: widget.size.getItemSpacing()),
              // 待办节点列表
              Expanded(
                child: ListView.separated(
                  itemCount: widget.items.length + (widget.moreCount > 0 ? 1 : 0),
                  separatorBuilder:
                      (context, index) => Container(
                        height: 1,
                        color: theme.ink.withValues(alpha: 0.18),
                      ),
                  itemBuilder: (context, index) {
                    if (index < widget.items.length) {
                      final todoNode = widget.items[index];
                      return _TodoNodeItemWidget(
                        todoNode: todoNode,
                        index: index,
                        animation: _animation,
                        size: widget.size,
                      );
                    } else {
                      // 更多链接
                      return _MoreLinkWidget(
                        count: widget.moreCount,
                        animation: _animation,
                        index: widget.items.length,
                        color: theme.primary,
                        size: widget.size,
                      );
                    }
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

class _TodoNodeItemWidget extends StatelessWidget {
  final TodoNodeItemData todoNode;
  final int index;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _TodoNodeItemWidget({
    required this.todoNode,
    required this.index,
    required this.animation,
    required this.size,
  });

  double _getDelayedAnimationValue(double value) {
    final intervalStart = index * 0.1;
    final intervalEnd = (0.4 + index * 0.1).clamp(0.0, 1.0);

    if (value <= intervalStart) return 0.0;
    if (value >= intervalEnd) return 1.0;
    final t = (value - intervalStart) / (intervalEnd - intervalStart);
    return Curves.easeOutCubic.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final delayedValue = _getDelayedAnimationValue(animation.value);
        return Opacity(
          opacity: delayedValue,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - delayedValue)),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: size.getItemSpacing()),
              child: Row(
                children: [
                  // 颜色竖条：数据色实底 + 墨线描边
                  Container(
                    width: 4,
                    height: size.getSubtitleFontSize() * 1.2,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(2),
                      fillColor: todoNode.color ?? theme.surfaceAlt,
                    ),
                  ),
                  SizedBox(width: size.getItemSpacing()),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todoNode.title,
                          style: TextStyle(
                            fontSize: size.getSubtitleFontSize(),
                            fontWeight: FontWeight.w500,
                            color: theme.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: size.getItemSpacing() * 0.3),
                        Text(
                          todoNode.path,
                          style: TextStyle(
                            fontSize: size.getSubtitleFontSize() * 0.75,
                            color: theme.textSub,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MoreLinkWidget extends StatelessWidget {
  final int count;
  final Animation<double> animation;
  final int index;
  final Color color;
  final HomeWidgetSize size;

  const _MoreLinkWidget({
    required this.count,
    required this.animation,
    required this.index,
    required this.color,
    required this.size,
  });

  double _getDelayedAnimationValue(double value) {
    final intervalStart = index * 0.1;
    final intervalEnd = (0.4 + index * 0.1).clamp(0.0, 1.0);

    if (value <= intervalStart) return 0.0;
    if (value >= intervalEnd) return 1.0;
    final t = (value - intervalStart) / (intervalEnd - intervalStart);
    return Curves.easeOutCubic.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final delayedValue = _getDelayedAnimationValue(animation.value);
        return Opacity(
          opacity: delayedValue,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - delayedValue)),
            child: Padding(
              padding: EdgeInsets.only(top: size.getItemSpacing()),
              child: Center(
                child: Text(
                  '+$count 更多',
                  style: TextStyle(
                    fontSize: size.getSubtitleFontSize(),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 待办节点项数据
class TodoNodeItemData {
  final String id;
  final String notebookId;
  final String notebookTitle;
  final String nodeId;
  final String title;
  final String path;
  final Color? color;

  const TodoNodeItemData({
    required this.id,
    required this.notebookId,
    required this.notebookTitle,
    required this.nodeId,
    required this.title,
    required this.path,
    this.color,
  });
}
