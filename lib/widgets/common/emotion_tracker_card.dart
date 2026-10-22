/// 情绪追踪卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题行（Emotion / Today 手绘箭头）/ 当前情绪文本（弹性入场动画保留）/
/// 已记录天数 / 周情绪按钮（手绘圆形徽章：已记录主题色实底 + 墨线描边）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 每日情绪数据模型
class DailyEmotion {
  /// 日期标签（如 'M', 'T', 'W' 等）
  final String day;

  /// 情绪图标
  final IconData icon;

  /// 情绪类型
  final EmotionType emotionType;

  /// 是否已记录
  final bool isLogged;

  const DailyEmotion({
    required this.day,
    required this.icon,
    required this.emotionType,
    required this.isLogged,
  });

  /// 创建副本
  DailyEmotion copyWith({
    String? day,
    IconData? icon,
    EmotionType? emotionType,
    bool? isLogged,
  }) {
    return DailyEmotion(
      day: day ?? this.day,
      icon: icon ?? this.icon,
      emotionType: emotionType ?? this.emotionType,
      isLogged: isLogged ?? this.isLogged,
    );
  }

  /// 从 JSON 创建
  factory DailyEmotion.fromJson(Map<String, dynamic> json) {
    return DailyEmotion(
      day: json['day'] as String,
      icon: dynamicIconData(json['iconCodePoint'] as int, fontFamily: 'MaterialIcons'),
      emotionType: EmotionType.values.firstWhere(
        (e) => e.name == json['emotionType'],
        orElse: () => EmotionType.neutral,
      ),
      isLogged: json['isLogged'] as bool,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'iconCodePoint': icon.codePoint,
      'emotionType': emotionType.name,
      'isLogged': isLogged,
    };
  }
}

/// 情绪类型枚举
enum EmotionType {
  /// 好情绪
  good,

  /// 中性情绪
  neutral,

  /// 坏情绪
  bad,

  /// 糟糕情绪
  terrible,
}

class EmotionTrackerCard extends StatelessWidget {
  /// 当前情绪文本
  final String currentEmotionText;

  /// 已记录天数
  final int loggedCount;

  /// 总天数
  final int totalCount;

  /// 周情绪数据列表
  final List<DailyEmotion> weekEmotions;

  /// 日期按钮点击回调
  final void Function(int index) onDayTapped;

  /// 历史记录点击回调
  final VoidCallback? onHistoryTap;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const EmotionTrackerCard({
    super.key,
    required this.currentEmotionText,
    required this.loggedCount,
    required this.totalCount,
    required this.weekEmotions,
    required this.onDayTapped,
    this.onHistoryTap,
    this.inline = false,
    this.size = const MediumSize(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final size = this.size;
    final scale = size.scale;
    final padding = size.getPadding();

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: padding.horizontal / 2 * 1.2,
        ),
        constraints: BoxConstraints(
          maxWidth: inline ? double.maxFinite : 400,
        ),
        child: DsSketchPanel(
          theme: theme,
          radius: BorderRadius.circular(24 * scale),
          padding: padding.copyWith(
            top: padding.top * 1.2,
            bottom: padding.bottom * 1.2,
            left: padding.left * 1.2,
            right: padding.right * 1.2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题行
              _buildHeader(context, theme),
              SizedBox(height: size.getTitleSpacing() * 1.2),

              // 主要内容区
              _buildMainContent(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标题行
  Widget _buildHeader(BuildContext context, AppThemeData theme) {
    final size = this.size;
    final iconSize = size.getIconSize();
    final titleFontSize = size.getTitleFontSize();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Emotion',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: titleFontSize * 0.67,
            color: theme.text,
          ),
        ),
        InkWell(
          onTap:
              onHistoryTap ??
              () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('查看历史情绪记录')));
              },
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Text(
                'Today',
                style: TextStyle(
                  color: theme.textSub,
                  fontWeight: FontWeight.w300,
                  fontSize: size.getSubtitleFontSize(),
                ),
              ),
              SizedBox(width: size.getSmallSpacing()),
              DsIcon(
                DsIconKind.chevronRight,
                color: theme.textSub,
                size: iconSize,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建主要内容区
  Widget _buildMainContent(AppThemeData theme) {
    final size = this.size;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedEmotionText(
                emotionText: currentEmotionText,
                size: size,
              ),
              SizedBox(height: size.getItemSpacing() / 2),
              Text(
                'Logged $loggedCount/$totalCount',
                style: TextStyle(
                  color: theme.textSub,
                  fontWeight: FontWeight.w300,
                  fontSize: size.getSubtitleFontSize(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: size.getItemSpacing()),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < weekEmotions.length; i += 1) ...[
                  if (i > 0) SizedBox(width: size.getItemSpacing()),
                  _buildDayButton(theme, i),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建日期按钮（手绘圆形徽章：已记录主题色实底，未记录 surfaceAlt 底）
  Widget _buildDayButton(AppThemeData theme, int index) {
    final size = this.size;
    final day = weekEmotions[index];
    final isSelected = day.isLogged;

    final iconSize = size.getIconSize();
    final containerSize = iconSize * size.iconContainerScale;
    final dayFontSize = size.getLegendFontSize();

    return InkWell(
      onTap: () => onDayTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: containerSize,
            height: containerSize,
            // 大圆角被 rough 引擎自动钳制成圆
            decoration: dsSketchDecoration(
              theme: theme,
              radius: BorderRadius.circular(containerSize / 2),
              fillColor: isSelected ? theme.primary : theme.surfaceAlt,
            ),
            child: Center(
              child: WiredIcon(
                icon: day.icon,
                size: iconSize * 0.8,
                color: isSelected ? theme.onPrimary : theme.textSub,
                drawConfig: theme.wired.drawConfig,
              ),
            ),
          ),
          SizedBox(height: size.getSmallSpacing()),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: dayFontSize,
              color: isSelected ? theme.text : theme.textSub,
            ),
            child: Text(day.day),
          ),
        ],
      ),
    );
  }
}

/// 情绪文本动画组件
class AnimatedEmotionText extends StatefulWidget {
  /// 情绪文本
  final String emotionText;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const AnimatedEmotionText({
    super.key,
    required this.emotionText,
    required this.size,
  });

  @override
  State<AnimatedEmotionText> createState() => _AnimatedEmotionTextState();
}

class _AnimatedEmotionTextState extends State<AnimatedEmotionText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void didUpdateWidget(AnimatedEmotionText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emotionText != widget.emotionText) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final size = widget.size;
    final emotionFontSize = size.getLargeFontSize() * 0.35;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Text(
        widget.emotionText,
        style: TextStyle(
          fontSize: emotionFontSize,
          fontWeight: FontWeight.w700,
          color: theme.text,
        ),
      ),
    );
  }
}
