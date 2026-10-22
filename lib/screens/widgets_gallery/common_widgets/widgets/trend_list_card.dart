/// 趋势列表卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆形图标徽章 + 标题头部 / 趋势条目列表（手绘涨跌箭头 +
/// 翻牌计数器 + 主题语义色涨跌）。数值动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import '../models/trend_list_card_data.dart';

/// 趋势列表卡片小组件
/// 用于显示股票、指数、价格等带有趋势变化的列表数据
class TrendListCardWidget extends StatefulWidget {
  /// 卡片数据
  final TrendListCardData data;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const TrendListCardWidget({
    super.key,
    required this.data,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory TrendListCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return TrendListCardWidget(
      data: TrendListCardData.fromJson(props),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<TrendListCardWidget> createState() => _TrendListCardWidgetState();
}

class _TrendListCardWidgetState extends State<TrendListCardWidget>
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
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 340,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme),
            SizedBox(height: widget.size.getTitleSpacing()),
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildItems(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeData theme) {
    final iconData = _getIconData(widget.data.iconName);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          // 大圆角被 rough 引擎自动钳制成圆
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(16),
            fillColor: theme.surfaceAlt,
          ),
          child: Center(
            child: WiredIcon(
              icon: iconData,
              size: 20,
              color: theme.primary,
              drawConfig: theme.wired.drawConfig,
            ),
          ),
        ),
        SizedBox(width: widget.size.getItemSpacing()),
        Flexible(
          child: Text(
            widget.data.title,
            style: TextStyle(
              fontSize: widget.size.getTitleFontSize(),
              fontWeight: FontWeight.w700,
              color: theme.text,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildItems() {
    final List<Widget> widgets = [];

    for (int i = 0; i < widget.data.items.length; i++) {
      if (i > 0) {
        widgets.add(SizedBox(height: widget.size.getItemSpacing()));
      }
      widgets.add(
        _TrendItemWidget(
          data: widget.data.items[i],
          animation: _animation,
          index: i,
          size: widget.size,
        ),
      );
    }

    return widgets;
  }

  /// 根据图标名称获取图标数据
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'monetization_on':
        return Icons.monetization_on;
      case 'trending_up':
        return Icons.trending_up;
      case 'show_chart':
        return Icons.show_chart;
      case 'attach_money':
        return Icons.attach_money;
      case 'euro':
        return Icons.euro;
      case 'yen':
        return Icons.currency_yen;
      case 'currency_bitcoin':
        return Icons.currency_bitcoin;
      case 'account_balance':
        return Icons.account_balance;
      default:
        return Icons.trending_up;
    }
  }
}

/// 趋势列表项组件
class _TrendItemWidget extends StatelessWidget {
  final TrendItemData data;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _TrendItemWidget({
    required this.data,
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
        index * 0.1,
        0.5 + index * 0.1,
        curve: Curves.easeOutCubic,
      ),
    );

    // 涨跌语义色
    final trendColor = data.isPositive ? theme.success : theme.danger;

    return Row(
      children: [
        SizedBox(
          width: 32,
          child: WiredIcon(
            icon: data.isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 24,
            color: trendColor,
            drawConfig: theme.wired.drawConfig,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.symbol,
                style: TextStyle(
                  fontSize: size.getSubtitleFontSize() * 0.8,
                  fontWeight: FontWeight.w600,
                  color: theme.textSub,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              SizedBox(height: size.getSmallSpacing()),
              SizedBox(
                height: 24,
                child: AnimatedFlipCounter(
                  value: data.value * itemAnimation.value,
                  fractionDigits: 2,
                  textStyle: TextStyle(
                    fontSize: size.getSubtitleFontSize(),
                    fontWeight: FontWeight.w700,
                    color: theme.text,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${data.isPositive ? '+' : ''}${data.percentChange.toStringAsFixed(2)}%',
              style: TextStyle(
                fontSize: size.getSubtitleFontSize(),
                fontWeight: FontWeight.w700,
                color: trendColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            SizedBox(height: size.getSmallSpacing()),
            SizedBox(
              height: 20,
              child: Text(
                '${data.isPositive ? '+' : ''}${data.valueChange.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: size.getSubtitleFontSize(),
                  fontWeight: FontWeight.w500,
                  color: trendColor.withValues(alpha: 0.8),
                  height: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
