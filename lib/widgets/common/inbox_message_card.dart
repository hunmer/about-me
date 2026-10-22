/// 收件箱消息卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 数据色收件箱图标徽章 + 数量徽章 / 消息列表（头像 + 墨线分隔线、
/// 逐项错峰浮现）/ 更多链接。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/image_helper.dart';

/// 收件箱消息数据模型
class InboxMessage {
  final String name;
  final String avatarUrl;
  final String preview;
  final String timeAgo;
  /// 图标 codePoint（可选，优先于 avatarUrl 使用）
  final int? iconCodePoint;

  /// 图标背景颜色（可选，配合 iconCodePoint 使用）
  final int? iconBackgroundColor;

  const InboxMessage({
    required this.name,
    required this.avatarUrl,
    required this.preview,
    required this.timeAgo,
    this.iconCodePoint,
    this.iconBackgroundColor,
  });

  /// 从 JSON 创建（用于公共小组件系统）
  factory InboxMessage.fromJson(Map<String, dynamic> json) {
    return InboxMessage(
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      timeAgo: json['timeAgo'] as String? ?? '',
      iconCodePoint: json['iconCodePoint'] as int?,
      iconBackgroundColor: json['iconBackgroundColor'] as int?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'avatarUrl': avatarUrl,
      'preview': preview,
      'timeAgo': timeAgo,
      'iconCodePoint': iconCodePoint,
      'iconBackgroundColor': iconBackgroundColor,
    };
  }
}

/// 收件箱消息小组件
class InboxMessageCardWidget extends StatefulWidget {
  final List<InboxMessage> messages;
  final int totalCount;
  final int remainingCount;
  final VoidCallback? onMoreTap;
  final String? title; // 可配置标题
  final Color? primaryColor; // 可配置主色调
  final HomeWidgetSize size; // 小组件尺寸

  const InboxMessageCardWidget({
    super.key,
    required this.messages,
    required this.totalCount,
    required this.remainingCount,
    this.onMoreTap,
    this.title,
    this.primaryColor,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory InboxMessageCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final messagesList = (props['messages'] as List<dynamic>?)
            ?.map((e) => InboxMessage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return InboxMessageCardWidget(
      messages: messagesList,
      totalCount: props['totalCount'] as int? ?? 0,
      remainingCount: props['remainingCount'] as int? ?? 0,
      title: props['title'] as String?,
      primaryColor: props['primaryColor'] != null
          ? Color(props['primaryColor'] as int)
          : null,
    );
  }

  @override
  State<InboxMessageCardWidget> createState() => _InboxMessageCardWidgetState();
}

class _InboxMessageCardWidgetState extends State<InboxMessageCardWidget>
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

    // 主色调（可配置数据色，默认橙色 #FBBF57）
    final primaryColor = widget.primaryColor ?? const Color(0xFFFBBF57);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: 340.0 * scale,
        radius: BorderRadius.circular(24 * scale),
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏：数据色图标徽章 + 标题 + 数量徽章
            _buildHeader(theme, primaryColor),
            // 消息列表（支持滚动）
            Expanded(
              child: Padding(
                padding: widget.size.getPadding().copyWith(
                  top: widget.size.getItemSpacing() * 1.2,
                  left: widget.size.getPadding().left * 1.2,
                  right: widget.size.getPadding().right * 1.2,
                  bottom: widget.size.getPadding().bottom * 1.2,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < widget.messages.length; i++) ...[
                        if (i > 0)
                          Container(
                            height: 1,
                            margin: EdgeInsets.symmetric(
                              vertical: widget.size.getItemSpacing() * 0.5,
                            ),
                            color: theme.ink.withValues(alpha: 0.18),
                          ),
                        _MessageItem(
                          message: widget.messages[i],
                          animation: _animation,
                          index: i,
                          size: widget.size,
                        ),
                      ],
                      SizedBox(height: widget.size.getItemSpacing() * 2.5),
                      // 更多按钮
                      GestureDetector(
                        onTap: widget.onMoreTap,
                        child: Text(
                          '+${widget.remainingCount} more',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: widget.size.getSubtitleFontSize(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: widget.size.getItemSpacing() * 1.2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(AppThemeData theme, Color primaryColor) {
    final badgeSize = widget.size.getThumbnailIconSize() * 1.6;

    return Padding(
      padding: widget.size.getPadding().copyWith(
        top: widget.size.getPadding().top * 1.2,
        bottom: widget.size.getPadding().bottom * 1.2,
        left: widget.size.getPadding().left * 1.2,
        right: widget.size.getPadding().right * 1.2,
      ),
      child: Row(
        children: [
          // 收件箱图标徽章：数据色实底 + 墨线描边（大圆角被 rough 引擎钳成圆）
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: dsSketchDecoration(
              theme: theme,
              radius: BorderRadius.circular(badgeSize / 2),
              fillColor: primaryColor,
            ),
            child: Center(
              child: DsIcon(
                DsIconKind.inbox,
                size: widget.size.getThumbnailIconSize(),
                color: theme.onPrimary,
              ),
            ),
          ),
          SizedBox(width: widget.size.getItemSpacing() * 1.2),
          Expanded(
            child: Text(
              widget.title ?? 'Inbox',
              style: TextStyle(
                color: theme.text,
                fontSize: widget.size.getTitleFontSize() * 0.75,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: widget.size.getSmallSpacing() * 2),
          // 数量徽章：浅底 + 墨线描边
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.size.getSmallSpacing() * 1.5,
              vertical: widget.size.getSmallSpacing() * 0.5,
            ),
            decoration: dsSketchDecoration(
              theme: theme,
              radius: BorderRadius.circular(widget.size.getSmallSpacing() * 1.5),
              fillColor: theme.surfaceAlt,
            ),
            child: Text(
              widget.totalCount.toString(),
              style: TextStyle(
                color: theme.text,
                fontSize: widget.size.getLegendFontSize(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 消息列表项组件
class _MessageItem extends StatelessWidget {
  final InboxMessage message;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _MessageItem({
    required this.message,
    required this.animation,
    required this.index,
    required this.size,
  });

  /// 构建头像或图标
  Widget _buildAvatarOrIcon(InboxMessage message) {
    return CommonImageBuilder.buildAvatarOrIcon(
      imageUrl: message.avatarUrl,
      iconCodePoint: message.iconCodePoint,
      iconBackgroundColor: message.iconBackgroundColor,
      size: size.getThumbnailIconSize() * 1.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 为每个列表项创建延迟动画，确保 end <= 1.0
    final step = 0.08;
    final start = index * step;
    final end = (0.6 + index * step).clamp(0.0, 1.0);
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        start,
        end,
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
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: size.getItemSpacing() * 1.2),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 头像或图标
                    SizedBox(
                      width: size.getThumbnailIconSize() * 1.5,
                      height: size.getThumbnailIconSize() * 1.5,
                      child: _buildAvatarOrIcon(message),
                    ),
                    SizedBox(width: size.getItemSpacing() * 1.5),
                    // 内容
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(
                                child: Text(
                                  message.name,
                                  style: TextStyle(
                                    color: theme.text,
                                    fontSize: size.getSubtitleFontSize(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: size.getSmallSpacing() * 2),
                              Text(
                                message.timeAgo,
                                style: TextStyle(
                                  color: theme.textSub,
                                  fontSize: size.getLegendFontSize(),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: size.getSmallSpacing()),
                          Text(
                            message.preview,
                            style: TextStyle(
                              color: theme.textSub,
                              fontSize: size.getLegendFontSize(),
                              height: 1.2,
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
          ),
        );
      },
    );
  }
}
