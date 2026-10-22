/// 提醒列表卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 翻牌计数 + danger 标题 / danger 实底操作圆钮（墨线描边）/
/// 手绘勾选框列表（墨线分隔线、逐项错峰浮现）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 提醒事项数据模型
class ReminderItem {
  /// 提醒文本内容
  final String text;

  /// 是否已完成
  final bool isCompleted;

  const ReminderItem({required this.text, this.isCompleted = false});

  /// 创建副本
  ReminderItem copyWith({String? text, bool? isCompleted}) {
    return ReminderItem(
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// 从 JSON 创建
  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    return ReminderItem(
      text: json['text'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'text': text, 'isCompleted': isCompleted};
  }
}

/// 提醒列表卡片组件
///
/// 用于显示提醒事项列表，支持动画效果和主题适配。
/// 显示项目总数和列表内容，支持浅色/深色模式切换。
///
/// 使用示例：
/// ```dart
/// ReminderListCard(
///   size: const MediumSize(),
///   itemCount: 18,
///   items: [
///     ReminderItem(text: 'Pick up arts & crafts supplies'),
///     ReminderItem(text: 'Send cookie recipe to Rigo'),
///     ReminderItem(text: 'Book club prep'),
///   ],
///   title: 'Reminders',
/// )
/// ```
class ReminderListCard extends StatefulWidget {
  /// 小组件尺寸
  final HomeWidgetSize size;

  /// 提醒事项总数
  final int itemCount;

  /// 提醒事项列表
  final List<ReminderItem> items;

  /// 标题（可选）
  final String? title;

  /// 宽度（可选）
  final double? width;

  /// 高度（可选）
  final double? height;

  /// 项目点击回调（可选）
  final ValueChanged<ReminderItem>? onItemTap;

  /// 操作按钮点击回调（可选）
  final VoidCallback? onActionTap;

  /// 复选框状态变更回调（可选）
  final ValueChanged<int>? onCheckboxChanged;

  const ReminderListCard({
    super.key,
    required this.itemCount,
    required this.items,
    this.title,
    this.width,
    this.height,
    this.onItemTap,
    this.onActionTap,
    this.onCheckboxChanged,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory ReminderListCard.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final itemsList =
        (props['items'] as List<dynamic>?)
            ?.map((e) => ReminderItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return ReminderListCard(
      size: size,
      itemCount: props['itemCount'] as int? ?? itemsList.length,
      items: itemsList,
      title: props['title'] as String?,
    );
  }

  @override
  State<ReminderListCard> createState() => _ReminderListCardState();
}

class _ReminderListCardState extends State<ReminderListCard>
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

    // 根据 size 计算尺寸
    final padding = widget.size.getPadding();
    final subtitleFontSize = widget.size.getSubtitleFontSize();
    final largeFontSize = widget.size.getLargeFontSize() * 0.8;
    final iconSize = widget.size.getIconSize();
    final smallSpacing = widget.size.getSmallSpacing();

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.width,
        height: widget.height,
        radius: BorderRadius.circular(24 * widget.size.scale),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // 标题区域
            Padding(
              padding: padding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: largeFontSize + smallSpacing * 2,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // 翻牌计数：AnimatedBuilder 驱动每 tick rebuild
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, _) {
                                return AnimatedFlipCounter(
                                  value:
                                      widget.itemCount.toDouble() *
                                      _animation.value,
                                  textStyle: TextStyle(
                                    color: theme.text,
                                    fontSize: largeFontSize,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: smallSpacing),
                      SizedBox(
                        height: subtitleFontSize + smallSpacing,
                        child: Text(
                          widget.title ?? 'Reminders',
                          style: TextStyle(
                            color: theme.danger,
                            fontSize: subtitleFontSize,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 操作按钮：danger 实底 + 墨线描边（大圆角被 rough 引擎钳成圆）
                  GestureDetector(
                    onTap: widget.onActionTap,
                    child: Container(
                      width: iconSize * 1.8,
                      height: iconSize * 1.8,
                      decoration: dsSketchDecoration(
                        theme: theme,
                        radius: BorderRadius.circular(iconSize * 0.9),
                        fillColor: theme.danger,
                      ),
                      child: Center(
                        child: DsIcon(
                          DsIconKind.list,
                          color: theme.onDanger,
                          size: iconSize,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 墨线分隔线
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding.left),
              child: Container(height: 1, color: theme.ink.withValues(alpha: 0.18)),
            ),
            // 列表区域
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  padding.left,
                  smallSpacing,
                  padding.right,
                  smallSpacing,
                ),
                itemCount: widget.items.length,
                separatorBuilder:
                    (context, index) => Padding(
                      padding: EdgeInsets.only(
                        left: iconSize * 2 + smallSpacing * 2,
                      ),
                      child: Container(
                        height: 1,
                        color: theme.ink.withValues(alpha: 0.18),
                      ),
                    ),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final itemAnimation = CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(
                      index * 0.08,
                      0.4 + index * 0.08,
                      curve: Curves.easeOutCubic,
                    ),
                  );

                  return AnimatedBuilder(
                    animation: itemAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: itemAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - itemAnimation.value)),
                          child: _ReminderItemTile(
                            item: item,
                            size: widget.size,
                            onTap:
                                widget.onItemTap != null
                                    ? () => widget.onItemTap!(item)
                                    : null,
                            onCheckboxChanged:
                                widget.onCheckboxChanged != null
                                    ? (completed) => widget
                                        .onCheckboxChanged!(index)
                                    : null,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个提醒事项项
class _ReminderItemTile extends StatefulWidget {
  final ReminderItem item;
  final HomeWidgetSize size;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onCheckboxChanged;

  const _ReminderItemTile({
    required this.item,
    required this.size,
    this.onTap,
    this.onCheckboxChanged,
  });

  @override
  State<_ReminderItemTile> createState() => _ReminderItemTileState();
}

class _ReminderItemTileState extends State<_ReminderItemTile> {
  bool _isHoveringCheckbox = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 根据 size 计算尺寸
    final iconSize = widget.size.getIconSize();
    final checkboxSize = iconSize * 0.9;
    final smallSpacing = widget.size.getSmallSpacing();
    final fontSize = widget.size.getSubtitleFontSize() + 1;
    final spacingBetween = iconSize * 0.7;
    final isCompleted = widget.item.isCompleted;

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: smallSpacing * 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 圆形复选框：勾选 danger 实底 + 手绘勾号，未勾选浅底空格
            Padding(
              padding: EdgeInsets.only(top: smallSpacing),
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHoveringCheckbox = true),
                onExit: (_) => setState(() => _isHoveringCheckbox = false),
                child: GestureDetector(
                  onTap: () {
                    if (widget.onCheckboxChanged != null) {
                      widget.onCheckboxChanged!(!isCompleted);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: checkboxSize,
                    height: checkboxSize,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(checkboxSize / 2),
                      fillColor:
                          isCompleted ? theme.danger : theme.surfaceAlt,
                      // 悬停时墨线换成 danger，保留原悬停反馈
                      stroke: _isHoveringCheckbox && !isCompleted
                          ? theme.danger
                          : null,
                    ),
                    child:
                        isCompleted
                            ? Center(
                              child: DsIcon(
                                DsIconKind.check,
                                color: theme.onDanger,
                                size: checkboxSize * 0.6,
                              ),
                            )
                            : null,
                  ),
                ),
              ),
            ),
            SizedBox(width: spacingBetween),
            // 文本内容
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: smallSpacing * 2),
                child: Text(
                  widget.item.text,
                  style: TextStyle(
                    color: isCompleted ? theme.textSub : theme.text,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
