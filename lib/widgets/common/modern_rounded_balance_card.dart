/// 余额卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 + 翻牌余额 + 可用额度 / 每周斜纹柱状图
/// （主题色浓斜纹数据柱 + 淡墨斜纹轨道胶囊，逐柱错峰生长）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 余额卡片数据模型
///
/// 用于余额卡片的数据序列化
class BalanceCardData {
  /// 卡片标题
  final String title;

  /// 当前余额
  final double balance;

  /// 可用额度
  final double available;

  /// 每周数据 (7天，0.0-1.0)
  final List<double> weeklyData;

  const BalanceCardData({
    required this.title,
    required this.balance,
    required this.available,
    required this.weeklyData,
  });

  /// 从 JSON 创建
  factory BalanceCardData.fromJson(Map<String, dynamic> json) {
    return BalanceCardData(
      title: json['title'] as String,
      balance: (json['balance'] as num).toDouble(),
      available: (json['available'] as num).toDouble(),
      weeklyData:
          (json['weeklyData'] as List<dynamic>)
              .map((e) => (e as num).toDouble())
              .toList(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'balance': balance,
      'available': available,
      'weeklyData': weeklyData,
    };
  }

  /// 创建副本
  BalanceCardData copyWith({
    String? title,
    double? balance,
    double? available,
    List<double>? weeklyData,
  }) {
    return BalanceCardData(
      title: title ?? this.title,
      balance: balance ?? this.balance,
      available: available ?? this.available,
      weeklyData: weeklyData ?? this.weeklyData,
    );
  }
}

/// 余额卡片小组件
///
/// 展示账户余额和可用额度，带有每周数据柱状图
class ModernRoundedBalanceCard extends StatefulWidget {
  /// 卡片标题
  final String title;

  /// 当前余额
  final double balance;

  /// 可用额度
  final double available;

  /// 每周数据 (7天，0.0-1.0)
  final List<double> weeklyData;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const ModernRoundedBalanceCard({
    super.key,
    required this.title,
    required this.balance,
    required this.available,
    required this.weeklyData,
    this.size = const MediumSize(),
  });

  /// 从数据模型创建
  factory ModernRoundedBalanceCard.fromData(
    BalanceCardData data, {
    HomeWidgetSize size = const MediumSize(),
  }) {
    return ModernRoundedBalanceCard(
      title: data.title,
      balance: data.balance,
      available: data.available,
      weeklyData: data.weeklyData,
      size: size,
    );
  }

  /// 从 props 创建实例（用于公共小组件系统）
  factory ModernRoundedBalanceCard.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final weeklyDataList = props['weeklyData'] as List?;
    final weeklyData =
        weeklyDataList?.map((e) => (e as num).toDouble()).toList() ??
        <double>[];

    return ModernRoundedBalanceCard(
      title: props['title'] as String? ?? '余额',
      balance: (props['balance'] as num?)?.toDouble() ?? 0.0,
      available: (props['available'] as num?)?.toDouble() ?? 0.0,
      weeklyData: weeklyData,
      size: size,
    );
  }

  @override
  State<ModernRoundedBalanceCard> createState() =>
      _ModernRoundedBalanceCardState();
}

class _ModernRoundedBalanceCardState extends State<ModernRoundedBalanceCard>
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

    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // 根据 size 计算尺寸
    final padding = widget.size.getPadding();
    final titleFontSize = widget.size.getTitleFontSize();
    final valueFontSize = widget.size.getLargeFontSize() * 0.35; // 约 13-20px
    final subtitleFontSize = widget.size.getSubtitleFontSize();
    final smallSpacing = widget.size.getSmallSpacing();
    final titleSpacing = widget.size.getTitleSpacing();
    final barWidth = widget.size.getBarWidth();

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          radius: BorderRadius.circular(24 * widget.size.scale),
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和余额
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: titleFontSize * 0.45, // 约 7-13px
                      fontWeight: FontWeight.w500,
                      color: theme.text,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: smallSpacing * 2),
                  SizedBox(
                    height: valueFontSize * 1.2,
                    // 翻牌余额：AnimatedBuilder 驱动每 tick rebuild
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return AnimatedFlipCounter(
                          value: widget.balance * _animation.value,
                          prefix: '\$',
                          fractionDigits: 2,
                          thousandSeparator: ',',
                          textStyle: TextStyle(
                            fontSize: valueFontSize,
                            fontWeight: FontWeight.bold,
                            color: theme.text,
                            height: 1.0,
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: smallSpacing),
                  Text(
                    '\$${widget.available.toStringAsFixed(2)} Available',
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      fontWeight: FontWeight.w500,
                      color: theme.textSub,
                      height: 1.0,
                    ),
                  ),
                ],
              ),

              SizedBox(height: titleSpacing * 0.8),

              // 每周柱状图 - 支持横向滚动
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableHeight = constraints.maxHeight;
                    final labelHeight =
                        widget.size.getLegendFontSize() * 1.2 +
                        smallSpacing * 3;
                    final barHeight = (availableHeight - labelHeight).clamp(
                      0.0,
                      availableHeight,
                    );

                    return Align(
                      alignment: Alignment.topCenter,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(
                          horizontal: smallSpacing,
                        ),
                        child: SizedBox(
                          height: barHeight + labelHeight,
                          // 柱高逐柱错峰生长：AnimatedBuilder 驱动每 tick rebuild
                          child: AnimatedBuilder(
                            animation: _animation,
                            builder: (context, _) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(
                                  widget.weeklyData.length,
                                  (index) {
                                    final value = widget.weeklyData[index];
                                    // 计算动画区间，确保 end 不超过 1.0
                                    final totalItems = widget.weeklyData.length;
                                    final animationStart =
                                        index / totalItems * 0.5;
                                    final animationEnd =
                                        (index + 1) / totalItems * 0.9;
                                    final itemAnimation = CurvedAnimation(
                                      parent: _animationController,
                                      curve: Interval(
                                        animationStart.clamp(0.0, 1.0),
                                        animationEnd.clamp(0.0, 1.0),
                                        curve: Curves.easeOutCubic,
                                      ),
                                    );

                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right:
                                            index < widget.weeklyData.length - 1
                                                ? barWidth * 0.5
                                                : 0,
                                      ),
                                      child: _WeeklyBar(
                                        label: weekDays[index % weekDays.length],
                                        value: value * itemAnimation.value,
                                        barColor: theme.primary,
                                        theme: theme,
                                        size: widget.size,
                                        barWidth: barWidth,
                                        barHeight: barHeight,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
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

/// 每周柱状条：胶囊轨道 + 斜纹数据柱（§9.5）
class _WeeklyBar extends StatelessWidget {
  final String label;
  final double value;
  final Color barColor;
  final AppThemeData theme;
  final HomeWidgetSize size;
  final double barWidth;
  final double barHeight;

  const _WeeklyBar({
    required this.label,
    required this.value,
    required this.barColor,
    required this.theme,
    required this.size,
    required this.barWidth,
    required this.barHeight,
  });

  @override
  Widget build(BuildContext context) {
    // 根据 size 计算尺寸
    final legendFontSize = size.getLegendFontSize();
    final smallSpacing = size.getSmallSpacing();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // CustomPaint 无 child 时取 constraints.smallest，须显式撑紧宽高
        SizedBox(
          width: barWidth,
          height: barHeight,
          child: CustomPaint(
            painter: _StripedBarPainter(
              fill: value.clamp(0.0, 1.0),
              barColor: barColor,
              theme: theme,
              scale: size.scale,
            ),
          ),
        ),
        SizedBox(height: smallSpacing * 3),
        SizedBox(
          height: legendFontSize * 1.2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: legendFontSize,
              fontWeight: FontWeight.w500,
              color: theme.textSub,
            ),
          ),
        ),
      ],
    );
  }
}

/// 斜纹柱绘制器
///
/// 胶囊轨道：surfaceAlt 底 + 淡墨斜纹（0.28）+ 淡墨描边（0.45）；
/// 数据柱（自底向上生长）：主题色浅底（0.28）+ 主题色浓斜纹（0.9，
/// 与斜纹进度条/条纹柱同款：右上斜率 0.85、6.5 间距）+ 主题色描边（0.85）；
/// 数据几何保持平直干净（数据区不上 rough 墨线）。
class _StripedBarPainter extends CustomPainter {
  /// 填充比例 0~1（含入场动画插值）
  final double fill;
  final Color barColor;
  final AppThemeData theme;
  final double scale;

  const _StripedBarPainter({
    required this.fill,
    required this.barColor,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = Radius.circular(size.width / 2);

    // 轨道胶囊
    final trackRect = Offset.zero & size;
    final trackRRect = RRect.fromRectAndRadius(trackRect, radius);
    canvas.drawRRect(trackRRect, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(trackRRect),
      trackRect,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      trackRRect,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    // 数据柱：自底向上生长的主题色斜纹填充
    final f = fill.clamp(0.0, 1.0);
    if (f > 0.004) {
      final fillRect = Rect.fromLTWH(
        0,
        size.height * (1 - f),
        size.width,
        size.height * f,
      );
      final fillRRect = RRect.fromRectAndRadius(fillRect, radius);
      canvas.drawRRect(
        fillRRect,
        Paint()..color = barColor.withValues(alpha: 0.28),
      );
      paintDiagonalStripes(
        canvas,
        Path()..addRRect(fillRRect),
        fillRect,
        color: barColor.withValues(alpha: 0.9),
        strokeWidth: 3 * scale,
        spacing: 6.5 * scale,
      );
      canvas.drawRRect(
        fillRRect,
        Paint()
          ..color = barColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripedBarPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.barColor != barColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}
