/// 任务列表卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 数据色圆形图标徽章 + 翻牌计数 / 任务列表（墨线分隔线、逐项错峰浮现）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 任务列表卡片小组件
///
/// 显示任务列表、数量统计和图标标识，支持自定义颜色和动画效果
class TaskListCardWidget extends StatefulWidget {
  /// 图标
  final IconData icon;

  /// 图标背景颜色
  final Color iconBackgroundColor;

  /// 任务总数
  final int count;

  /// 计数标签
  final String countLabel;

  /// 任务项列表
  final List<String> items;

  /// 更多任务数量
  final int moreCount;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const TaskListCardWidget({
    super.key,
    required this.icon,
    required this.iconBackgroundColor,
    required this.count,
    required this.countLabel,
    required this.items,
    required this.moreCount,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory TaskListCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final itemsList = props['items'] as List<dynamic>?;
    final items = itemsList?.map((item) => item as String).toList() ?? [];

    // 从 props 中读取 size，如果不存在则使用传入的 size 参数
    HomeWidgetSize widgetSize = size;
    if (props['size'] != null) {
      widgetSize = HomeWidgetSize.fromJson(
        props['size'] as Map<String, dynamic>,
      );
    }

    return TaskListCardWidget(
      icon:
          props['icon'] is String
              ? dynamicIconData(
                int.parse(props['icon'] as String),
                fontFamily: 'MaterialIcons',
              )
              : (props['icon'] as IconData? ?? Icons.format_list_bulleted),
      iconBackgroundColor:
          props['iconBackgroundColor'] != null
          ? Color(props['iconBackgroundColor'] as int)
          : const Color(0xFF5A72EA),
      count: props['count'] as int? ?? 0,
      countLabel: props['countLabel'] as String? ?? 'Tasks',
      items: items,
      moreCount: props['moreCount'] as int? ?? 0,
      inline: props['inline'] as bool? ?? false,
      size: widgetSize,
    );
  }

  /// 转换为 props
  Map<String, dynamic> toProps() {
    return {
      'icon': icon.codePoint.toString(),
      'iconBackgroundColor': iconBackgroundColor.value,
      'count': count,
      'countLabel': countLabel,
      'items': items,
      'moreCount': moreCount,
      'inline': inline,
      'size': size.toJson(),
    };
  }

  @override
  State<TaskListCardWidget> createState() => _TaskListCardWidgetState();
}

class _TaskListCardWidgetState extends State<TaskListCardWidget>
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：图标和计数
              _buildLeftSection(theme),
              SizedBox(width: widget.size.getTitleSpacing()),
              // 右侧：任务列表
              Expanded(child: _buildRightSection(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftSection(AppThemeData theme) {
    final iconContainerSize =
        widget.size.getIconSize() * widget.size.iconContainerScale;
    final leftSectionWidth = iconContainerSize + 8;

    return SizedBox(
      width: leftSectionWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标徽章：数据色实底 + 墨线描边（大圆角被 rough 引擎钳成圆）
          Container(
            width: iconContainerSize,
            height: iconContainerSize,
            decoration: dsSketchDecoration(
              theme: theme,
              radius: BorderRadius.circular(iconContainerSize / 2),
              fillColor: widget.iconBackgroundColor,
            ),
            child: Center(
              child: WiredIcon(
                icon: widget.icon,
                size: widget.size.getIconSize(),
                color: theme.onPrimary,
                drawConfig: theme.wired.drawConfig,
              ),
            ),
          ),
          SizedBox(height: widget.size.getItemSpacing()),
          // 计数
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: widget.size.getLargeFontSize() * 0.9,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return AnimatedFlipCounter(
                      value: widget.count.toDouble() * _animation.value,
                      textStyle: TextStyle(
                        fontSize: widget.size.getLargeFontSize() * 0.6,
                        fontWeight: FontWeight.w500,
                        color: theme.text,
                        height: 1.0,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: widget.size.getItemSpacing()),
              SizedBox(
                height: widget.size.getSubtitleFontSize(),
                child: Text(
                  widget.countLabel,
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
      ),
    );
  }

  Widget _buildRightSection(AppThemeData theme) {
    // 空状态：当没有任务项时显示提示
    if (widget.items.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 任务列表
        Flexible(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.items.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 1,
                      margin: EdgeInsets.symmetric(
                        vertical: widget.size.getItemSpacing(),
                      ),
                      color: theme.ink.withValues(alpha: 0.18),
                    ),
                  _TaskItemWidget(
                    title: widget.items[i],
                    animation: _animation,
                    index: i,
                    textColor: theme.text,
                    size: widget.size,
                  ),
                ],
                SizedBox(height: widget.size.getItemSpacing()),
                // 更多任务链接
                _MoreLinkWidget(
                  count: widget.moreCount,
                  animation: _animation,
                  index: widget.items.length,
                  color: widget.iconBackgroundColor,
                  size: widget.size,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyState(AppThemeData theme) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // 计算延迟动画值
        const intervalStart = 0.3;
        const intervalEnd = 0.8;
        final value = _animation.value;
        final delayedValue =
            value <= intervalStart
                ? 0.0
                : value >= intervalEnd
                ? 1.0
                : Curves.easeOutCubic.transform(
                  (value - intervalStart) / (intervalEnd - intervalStart),
                );

        return Opacity(
          opacity: delayedValue,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - delayedValue)),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: widget.size.getItemSpacing() * 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WiredIcon(
                      icon: Icons.check_circle_outline,
                      size: widget.size.getFeaturedIconSize(),
                      color: theme.textSub,
                      drawConfig: theme.wired.drawConfig,
                    ),
                    SizedBox(height: widget.size.getItemSpacing()),
                    Text(
                      '暂无已完成项目',
                      style: TextStyle(
                        fontSize: widget.size.getSubtitleFontSize(),
                        color: theme.textSub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 任务项组件
class _TaskItemWidget extends StatelessWidget {
  final String title;
  final Animation<double> animation;
  final int index;
  final Color textColor;
  final HomeWidgetSize size;

  const _TaskItemWidget({
    required this.title,
    required this.animation,
    required this.index,
    required this.textColor,
    required this.size,
  });

  // 计算延迟动画值
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
              padding: EdgeInsets.symmetric(vertical: size.getItemSpacing()),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: size.getSubtitleFontSize(),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 更多任务链接组件
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

  // 计算延迟动画值
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
              child: Text(
                '+$count more',
                style: TextStyle(
                  fontSize: size.getSubtitleFontSize(),
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
