/// 任务统计列表小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 数据色圆形图标徽章 + 翻牌计数 / 任务列表（墨线分隔线、逐项错峰浮现）。
library;

import 'package:flutter/material.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 任务数据模型
class TaskListItem {
  final String title;

  const TaskListItem({
    required this.title,
  });

  factory TaskListItem.fromJson(Map<String, dynamic> json) {
    return TaskListItem(
      title: json['title'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title};
  }
}

/// 任务统计列表小组件
class TaskListStatCardWidget extends StatefulWidget {
  /// 图标
  final IconData icon;

  /// 任务总数
  final int count;

  /// 状态标签（如 "Upcoming"）
  final String statusLabel;

  /// 任务列表
  final List<String> tasks;

  /// 剩余任务数量
  final int remainingCount;

  /// 主色调
  final Color? primaryColor;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const TaskListStatCardWidget({
    super.key,
    required this.icon,
    required this.count,
    required this.statusLabel,
    required this.tasks,
    required this.remainingCount,
    this.primaryColor,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory TaskListStatCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return TaskListStatCardWidget(
      icon: _iconFromString(props['icon'] as String? ?? ''),
      count: props['count'] as int? ?? 0,
      statusLabel: props['statusLabel'] as String? ?? '',
      tasks: (props['tasks'] as List<dynamic>?)?.cast<String>() ?? [],
      remainingCount: props['remainingCount'] as int? ?? 0,
      primaryColor: props['primaryColor'] != null
          ? Color(props['primaryColor'] as int)
          : null,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  static IconData _iconFromString(String iconString) {
    // 简单的图标映射
    switch (iconString) {
      case 'Icons.format_list_bulleted':
        return Icons.format_list_bulleted;
      default:
        return Icons.list;
    }
  }

  @override
  State<TaskListStatCardWidget> createState() => _TaskListStatCardWidgetState();
}

class _TaskListStatCardWidgetState extends State<TaskListStatCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
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
    // 数据色：props 优先，缺省走主题主色
    final primaryColor = widget.primaryColor ?? theme.primary;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          width: widget.inline ? double.maxFinite : 380,
          height: widget.inline ? double.maxFinite : null,
          radius: BorderRadius.circular(24 * scale),
          padding: widget.size.getPadding(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：图标和统计
              _buildLeftSection(theme, primaryColor),
              SizedBox(width: widget.size.getTitleSpacing()),
              // 右侧：任务列表
              Expanded(child: _buildRightSection(primaryColor)),
            ],
          ),
        ),
      ),
    );
  }

  /// 左侧区域
  Widget _buildLeftSection(AppThemeData theme, Color primaryColor) {
    final iconSize = widget.size.getIconSize();
    final containerSize = iconSize * 2;
    final fontSize = widget.size.getLargeFontSize();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 图标徽章：数据色实底 + 墨线描边（大圆角被 rough 引擎钳成圆）
        Container(
          width: containerSize,
          height: containerSize,
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(containerSize / 2),
            fillColor: primaryColor,
          ),
          child: Center(
            child: WiredIcon(
              icon: widget.icon,
              size: iconSize,
              color: theme.onPrimary,
              drawConfig: theme.wired.drawConfig,
            ),
          ),
        ),

        SizedBox(height: widget.size.getTitleSpacing()),

        // 数量和标签
        Column(
          children: [
            SizedBox(
              height: fontSize + 8,
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return AnimatedFlipCounter(
                    value: widget.count * _fadeAnimation.value,
                    textStyle: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                      color: theme.text,
                      height: 1.0,
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 18,
              child: Text(
                widget.statusLabel,
                style: TextStyle(
                  fontSize: widget.size.getSubtitleFontSize(),
                  fontWeight: FontWeight.w500,
                  color: theme.textSub,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 右侧区域
  Widget _buildRightSection(Color primaryColor) {
    final displayTasks = widget.tasks.take(4).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 任务列表
        ...List.generate(displayTasks.length, (index) {
          return _TaskListItem(
            task: displayTasks[index],
            isLast: index == displayTasks.length - 1,
            animation: _animationController,
            index: index,
            size: widget.size,
          );
        }),

        // 更多链接
        if (widget.remainingCount > 0)
          Padding(
            padding: EdgeInsets.only(top: widget.size.getItemSpacing()),
            child: _MoreLinkWidget(
              count: widget.remainingCount,
              primaryColor: primaryColor,
              animation: _animationController,
              index: displayTasks.length,
              size: widget.size,
            ),
          ),
      ],
    );
  }
}

/// 任务列表项（墨线分隔线、逐项错峰浮现）
class _TaskListItem extends StatelessWidget {
  final String task;
  final bool isLast;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _TaskListItem({
    required this.task,
    required this.isLast,
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        index * 0.12,
        0.5 + index * 0.12,
        curve: Curves.easeOutCubic,
      ),
    );

    final itemSpacing = size.getItemSpacing();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: itemAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - itemAnimation.value)),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 4 : itemSpacing,
              bottom: itemSpacing,
            ),
            child: Text(
              task,
              style: TextStyle(
                fontSize: size.getSubtitleFontSize() - 1,
                fontWeight: FontWeight.w600,
                color: theme.text,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isLast)
            Container(height: 1, color: theme.ink.withValues(alpha: 0.18)),
        ],
      ),
    );
  }
}

/// 更多链接组件
class _MoreLinkWidget extends StatelessWidget {
  final int count;
  final Color primaryColor;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _MoreLinkWidget({
    required this.count,
    required this.primaryColor,
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        index * 0.12,
        0.5 + index * 0.12,
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: itemAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - itemAnimation.value)),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('还有 $count 项任务'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Text(
            '+$count more',
            style: TextStyle(
              fontSize: size.getSubtitleFontSize(),
              fontWeight: FontWeight.w700,
              color: primaryColor,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
