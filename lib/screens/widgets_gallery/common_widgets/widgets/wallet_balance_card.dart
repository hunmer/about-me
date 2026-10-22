/// 钱包余额概览卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 头像 + 翻牌余额 + 涨幅徽章（success 实底墨线描边）/
/// 斜纹进度条（主题色斜纹数据段 + 淡墨轨道胶囊 + 指示圆点）/
/// 收支统计 / 手绘按钮组（墨底 Send / 纸底 Receive / 圆形加号）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 钱包余额概览卡片小组件
///
/// 显示钱包余额、可用余额、收入支出统计和操作按钮
class WalletBalanceCardWidget extends StatefulWidget {
  /// 头像 URL
  final String avatarUrl;

  /// 可用余额
  final double availableBalance;

  /// 总余额
  final double totalBalance;

  /// 变化百分比
  final int changePercent;

  /// 收入
  final double income;

  /// 支出
  final double expenses;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const WalletBalanceCardWidget({
    super.key,
    required this.avatarUrl,
    required this.availableBalance,
    required this.totalBalance,
    required this.changePercent,
    required this.income,
    required this.expenses,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从属性 Map 创建组件（用于公共小组件系统）
  static WalletBalanceCardWidget fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return WalletBalanceCardWidget(
      avatarUrl: props['avatarUrl'] as String? ?? '',
      availableBalance: (props['availableBalance'] as num?)?.toDouble() ?? 0.0,
      totalBalance: (props['totalBalance'] as num?)?.toDouble() ?? 0.0,
      changePercent: props['changePercent'] as int? ?? 0,
      income: (props['income'] as num?)?.toDouble() ?? 0.0,
      expenses: (props['expenses'] as num?)?.toDouble() ?? 0.0,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<WalletBalanceCardWidget> createState() =>
      _WalletBalanceCardWidgetState();
}

class _WalletBalanceCardWidgetState extends State<WalletBalanceCardWidget>
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

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 340,
        radius: BorderRadius.circular(24 * widget.size.scale),
        padding: widget.size.getPadding(),
        child: _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(AppThemeData theme) {
    final scale = widget.size.scale;

    // 计算进度比例
    final progress = (widget.availableBalance / widget.totalBalance).clamp(
      0.0,
      1.0,
    );

    // 根据尺寸计算各元素大小
    final iconSize = widget.size.getIconSize();
    final avatarSize = iconSize * widget.size.iconContainerScale;
    final labelFontSize = widget.size.getSubtitleFontSize();
    final balanceFontSize = widget.size.getTitleFontSize() * 0.5;
    final changePercentFontSize = widget.size.getLegendFontSize();
    final changePercentPadding = EdgeInsets.symmetric(
      horizontal: widget.size.getSmallSpacing() * 2,
      vertical: widget.size.getSmallSpacing(),
    );
    final progressHeight = widget.size.getStrokeWidth() * 0.5;
    final indicatorSize = widget.size.getIconSize() * 0.8;
    final indicatorBorderWidth = widget.size.getStrokeWidth() * 0.3;
    final statFontSize = widget.size.getSubtitleFontSize();
    final buttonHeight = iconSize * widget.size.iconContainerScale;
    final buttonFontSize = widget.size.getSubtitleFontSize() * 1.2;
    final buttonIconSize = iconSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 头像和余额信息
        Row(
          children: [
            ClipOval(
              child: Image.network(
                widget.avatarUrl,
                width: avatarSize,
                height: avatarSize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 加载失败兜底：纸底圆形徽章 + 用户图标
                  return Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(avatarSize / 2),
                      fillColor: theme.surfaceAlt,
                    ),
                    child: Center(
                      child: DsIcon(
                        DsIconKind.user,
                        size: iconSize * 0.6,
                        color: theme.textSub,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: widget.size.getItemSpacing()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${widget.availableBalance.toStringAsFixed(2)} Available',
                    style: TextStyle(
                      fontSize: labelFontSize,
                      color: theme.textSub,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: widget.size.getItemSpacing() / 2),
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return AnimatedFlipCounter(
                            value: widget.totalBalance * _animation.value,
                            fractionDigits: 2,
                            prefix: '\$',
                            textStyle: TextStyle(
                              fontSize: balanceFontSize,
                              fontWeight: FontWeight.bold,
                              color: theme.text,
                            ),
                          );
                        },
                      ),
                      SizedBox(width: widget.size.getItemSpacing()),
                      // 涨幅徽章：success 实底 + 墨线描边
                      Container(
                        padding: changePercentPadding,
                        decoration: dsSketchDecoration(
                          theme: theme,
                          radius: BorderRadius.circular(12 * scale),
                          fillColor: theme.success,
                        ),
                        child: Text(
                          '+${widget.changePercent}%',
                          style: TextStyle(
                            fontSize: changePercentFontSize,
                            fontWeight: FontWeight.bold,
                            color: theme.onSuccess,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: widget.size.getTitleSpacing()),

        // 进度条（斜纹数据填充，见 design.md §9.5）
        _buildProgressBar(
          theme,
          progress,
          progressHeight,
          indicatorSize,
          indicatorBorderWidth,
          statFontSize,
        ),
        const Spacer(),

        // 操作按钮 - 固定在底部
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                theme,
                'Send',
                theme.ink,
                theme.surface,
                buttonHeight,
                buttonFontSize,
              ),
            ),
            SizedBox(width: widget.size.getItemSpacing()),
            Expanded(
              child: _buildActionButton(
                theme,
                'Receive',
                theme.surfaceAlt,
                theme.text,
                buttonHeight,
                buttonFontSize,
              ),
            ),
            SizedBox(width: widget.size.getItemSpacing()),
            _buildAddButton(theme, buttonHeight, buttonIconSize),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressBar(
    AppThemeData theme,
    double progress,
    double height,
    double indicatorSize,
    double indicatorBorderWidth,
    double fontSize,
  ) {
    final isWideMode = widget.size is WideSize || widget.size is Wide2Size;

    return Column(
      children: [
        // 画布高度以指示圆点外扩为准，条体垂直居中
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return SizedBox(
              // CustomPaint 无 child 时取 constraints.smallest，须显式撑宽
              width: double.infinity,
              height: indicatorSize,
              child: CustomPaint(
                painter: _StripedProgressBarPainter(
                  fill: progress * _animation.value,
                  barHeight: height,
                  barColor: theme.primary,
                  indicatorSize: indicatorSize,
                  indicatorBorderWidth: indicatorBorderWidth,
                  theme: theme,
                  scale: widget.size.scale,
                ),
              ),
            );
          },
        ),
        SizedBox(height: widget.size.getItemSpacing()),
        // 非宽屏模式下换行显示，宽屏模式下并排显示
        if (isWideMode)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatLabel(theme, 'Income:', '\$${widget.income}', fontSize),
              _buildStatLabel(
                theme,
                'Expenses:',
                '\$${widget.expenses}',
                fontSize,
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatLabel(theme, 'Income:', '\$${widget.income}', fontSize),
              SizedBox(height: widget.size.getSmallSpacing()),
              _buildStatLabel(
                theme,
                'Expenses:',
                '\$${widget.expenses}',
                fontSize,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatLabel(
    AppThemeData theme,
    String label,
    String value,
    double fontSize,
  ) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: fontSize, color: theme.textSub),
        ),
        SizedBox(width: widget.size.getItemSpacing() / 2),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    AppThemeData theme,
    String text,
    Color bgColor,
    Color textColor,
    double height,
    double fontSize,
  ) {
    return Container(
      height: height,
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(height * 0.36),
        fillColor: bgColor,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildAddButton(
    AppThemeData theme,
    double height,
    double iconSize,
  ) {
    return Container(
      width: height,
      height: height,
      // 大圆角被 rough 引擎自动钳制成圆
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(height / 2),
        fillColor: theme.surfaceAlt,
      ),
      child: Center(
        child: DsIcon(DsIconKind.plus, size: iconSize * 0.6, color: theme.text),
      ),
    );
  }
}

/// 斜纹进度条绘制器
///
/// 胶囊轨道：surfaceAlt 底 + 淡墨斜纹（0.28）+ 淡墨描边（0.45）；
/// 数据段：主题色浅底（0.28）+ 主题色浓斜纹（0.9，与半圆仪表盘/
/// 条纹柱同款：右上斜率 0.85、6.5 间距）+ 主题色描边（0.85）；
/// 指示圆点：纸底实心 + 主题色描边平直几何（数据区不上 rough 墨线）。
class _StripedProgressBarPainter extends CustomPainter {
  /// 填充比例 0~1（含入场动画插值）
  final double fill;
  final double barHeight;
  final Color barColor;
  final double indicatorSize;
  final double indicatorBorderWidth;
  final AppThemeData theme;
  final double scale;

  const _StripedProgressBarPainter({
    required this.fill,
    required this.barHeight,
    required this.barColor,
    required this.indicatorSize,
    required this.indicatorBorderWidth,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width <= indicatorSize) return;
    final barTop = (size.height - barHeight) / 2;
    final trackRect = Rect.fromLTWH(0, barTop, size.width, barHeight);
    final trackRRect = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(barHeight / 2),
    );

    // 轨道胶囊
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

    // 数据段：主题色斜纹填充
    final f = fill.clamp(0.0, 1.0);
    if (f > 0.004) {
      final fillRect = Rect.fromLTWH(0, barTop, size.width * f, barHeight);
      final fillRRect = RRect.fromRectAndRadius(
        fillRect,
        Radius.circular(barHeight / 2),
      );
      canvas.drawRRect(fillRRect, Paint()..color = barColor.withValues(alpha: 0.28));
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

    // 指示圆点：位置钳制在有效范围内，避免超出边界
    final minRatio = indicatorSize / 2 / size.width;
    final knobRatio = f.clamp(minRatio, 1 - minRatio).toDouble();
    final center = Offset(knobRatio * size.width, size.height / 2);
    final knobRadius = indicatorSize / 2 - indicatorBorderWidth / 2;
    canvas.drawCircle(center, knobRadius, Paint()..color = theme.surface);
    canvas.drawCircle(
      center,
      knobRadius,
      Paint()
        ..color = barColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = indicatorBorderWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _StripedProgressBarPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.barHeight != barHeight ||
        oldDelegate.barColor != barColor ||
        oldDelegate.indicatorSize != indicatorSize ||
        oldDelegate.indicatorBorderWidth != indicatorBorderWidth ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}
