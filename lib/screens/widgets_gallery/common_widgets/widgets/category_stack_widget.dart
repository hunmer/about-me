/// 分类堆叠消费小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 + 翻牌计数器 / 斜纹纵向堆叠柱（各分类数据色斜纹，逐段生长）/
/// 分类图例列表（手绘色块指示器 + 标签 + 数值，逐项错峰入场）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 分类数据模型
class CategoryData {
  final String label;
  final double amount;
  final Color color;
  final double percentage;

  const CategoryData({
    required this.label,
    required this.amount,
    required this.color,
    required this.percentage,
  });

  /// 从 JSON 创建
  factory CategoryData.fromJson(
    Map<String, dynamic> json, {
    double totalAmount = 0.0,
  }) {
    // 安全获取 amount，支持多种类型
    final amountValue = json['amount'];
    double amount = 0.0;
    if (amountValue is num) {
      amount = amountValue.toDouble();
    } else if (amountValue is String) {
      amount = double.tryParse(amountValue) ?? 0.0;
    }

    // 确保 totalAmount 是有效的数字
    final safeTotalAmount =
        totalAmount.isNaN || totalAmount.isInfinite ? 0.0 : totalAmount;

    // 安全获取 percentage
    final percentageValue = json['percentage'];
    double percentage = 0.0;
    if (percentageValue is num) {
      percentage = percentageValue.toDouble();
    } else if (safeTotalAmount > 0) {
      percentage = (amount / safeTotalAmount * 100).clamp(0.0, 100.0);
    }

    // 支持 label 和 name 两种键名
    final label = json['label'] as String? ?? json['name'] as String? ?? '';

    // 安全获取 color
    final colorValue = json['color'];
    int colorInt = 0xFF000000;
    if (colorValue is int) {
      colorInt = colorValue;
    } else if (colorValue is String) {
      colorInt = int.tryParse(colorValue) ?? 0xFF000000;
    }

    return CategoryData(
      label: label,
      amount: amount,
      color: Color(colorInt),
      percentage: percentage,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'amount': amount,
      'color': color.value,
      'percentage': percentage,
    };
  }
}

/// 分类堆叠消费小组件
class CategoryStackWidget extends StatefulWidget {
  final String title;
  final double currentAmount;
  final double targetAmount;
  final String currency;
  final List<CategoryData> categories;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const CategoryStackWidget({
    super.key,
    required this.title,
    required this.currentAmount,
    required this.targetAmount,
    this.currency = '\$',
    required this.categories,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory CategoryStackWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    // 安全获取 currentAmount，支持多种类型
    final currentAmountValue = props['currentAmount'];
    double currentAmount = 0.0;
    if (currentAmountValue is num) {
      currentAmount = currentAmountValue.toDouble();
    } else if (currentAmountValue is String) {
      currentAmount = double.tryParse(currentAmountValue) ?? 0.0;
    }

    // 安全获取 targetAmount
    final targetAmountValue = props['targetAmount'];
    double targetAmount = 0.0;
    if (targetAmountValue is num) {
      targetAmount = targetAmountValue.toDouble();
    } else if (targetAmountValue is String) {
      targetAmount = double.tryParse(targetAmountValue) ?? 0.0;
    }

    // 确保 currentAmount 不是 NaN 或 Infinite
    if (currentAmount.isNaN || currentAmount.isInfinite) {
      currentAmount = 0.0;
    }

    final categoriesList =
        (props['categories'] as List<dynamic>?)
            ?.map(
              (e) => CategoryData.fromJson(
                e as Map<String, dynamic>,
                totalAmount: currentAmount,
              ),
            )
            .toList() ??
        const [];

    return CategoryStackWidget(
      title: props['title'] as String? ?? '',
      currentAmount: currentAmount,
      targetAmount: targetAmount,
      currency: props['currency'] as String? ?? '\$',
      categories: categoriesList,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<CategoryStackWidget> createState() => _CategoryStackWidgetState();
}

class _CategoryStackWidgetState extends State<CategoryStackWidget>
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
        width: widget.inline ? double.maxFinite : 220,
        height: widget.inline ? double.maxFinite : 220,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => _buildHeader(theme),
            ),
            SizedBox(height: widget.size.getItemSpacing()),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 40,
                    child: _StackedBarChart(
                      categories: widget.categories,
                      animation: _animation,
                      size: widget.size,
                      theme: theme,
                    ),
                  ),
                  SizedBox(width: widget.size.getItemSpacing()),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            widget.size.getRankedBarListHeight() * 0.8,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                              width: constraints.maxWidth,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  widget.categories.length,
                                  (index) {
                                    final category =
                                        widget.categories[index];
                                    // 均匀分配动画区间
                                    final count =
                                        widget.categories.length;
                                    final step =
                                        count > 0 ? 1.0 / count : 1.0;
                                    final start = index * step;
                                    final end = ((index + 1) * step)
                                        .clamp(0.0, 1.0);
                                    final itemAnimation = CurvedAnimation(
                                      parent: _animationController,
                                      curve: Interval(
                                        start,
                                        end,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    );
                                    return _CategoryItem(
                                      category: category,
                                      animation: itemAnimation,
                                      currency: widget.currency,
                                      size: widget.size,
                                      theme: theme,
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 标题 + 翻牌计数器（数值随入场动画增长）
  Widget _buildHeader(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            color: theme.textSub,
            fontSize: widget.size.getSubtitleFontSize(),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: widget.size.getSmallSpacing()),
        SizedBox(
          height:
              widget.size.isAtLeast(const LargeSize())
                  ? widget.size.getLargeFontSize() * 1.2
                  : null,
          child:
              widget.size.isAtLeast(const LargeSize())
                  ? Row(
                    children: [
                      Text(
                        widget.currency,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: widget.size.getLargeFontSize(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        width: widget.size.getSmallSpacing(),
                      ),
                      SizedBox(
                        width:
                            widget.size.getLargeFontSize() * 2.2,
                        height:
                            widget.size.getLargeFontSize() * 1.2,
                        child: AnimatedFlipCounter(
                          value:
                              widget.currentAmount *
                              _animation.value,
                          wholeDigits: 3,
                          fractionDigits: 0,
                          textStyle: TextStyle(
                            color: theme.text,
                            fontSize:
                                widget.size.getLargeFontSize(),
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: widget.size.getItemSpacing(),
                      ),
                      SizedBox(
                        height:
                            widget.size.getLargeFontSize() * 1.2,
                        child: Text(
                          '${widget.currency}${widget.targetAmount}',
                          style: TextStyle(
                            color: theme.textSub,
                            fontSize:
                                widget.size.getTitleFontSize() *
                                0.75,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.currency,
                            style: TextStyle(
                              color: theme.text,
                              fontSize:
                                  widget.size.getLargeFontSize(),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: widget.size.getSmallSpacing(),
                          ),
                          SizedBox(
                            width:
                                widget.size.getLargeFontSize() *
                                2.2,
                            height:
                                widget.size.getLargeFontSize() * 1.2,
                            child: AnimatedFlipCounter(
                              value:
                                  widget.currentAmount *
                                  _animation.value,
                              wholeDigits: 3,
                              fractionDigits: 0,
                              textStyle: TextStyle(
                                color: theme.text,
                                fontSize: widget.size
                                    .getLargeFontSize(),
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${widget.currency}${widget.targetAmount}',
                        style: TextStyle(
                          color: theme.textSub,
                          fontSize:
                              widget.size.getTitleFontSize() * 0.75,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }
}

/// 斜纹纵向堆叠柱（数据区手绘斜纹，各段随动画从各自槽底生长）
class _StackedBarChart extends StatelessWidget {
  final List<CategoryData> categories;
  final Animation<double> animation;
  final HomeWidgetSize size;
  final AppThemeData theme;

  const _StackedBarChart({
    required this.categories,
    required this.animation,
    required this.size,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size(double.infinity, double.infinity),
          painter: _StripedStackedBarPainter(
            categories: categories,
            theme: theme,
            scale: size.scale,
            progress: animation.value,
          ),
        );
      },
    );
  }
}

/// 分类图例项（手绘色块指示器 + 标签 + 数值，逐项错峰入场）
class _CategoryItem extends StatelessWidget {
  final CategoryData category;
  final Animation<double> animation;
  final String currency;
  final HomeWidgetSize size;
  final AppThemeData theme;

  const _CategoryItem({
    required this.category,
    required this.animation,
    required this.currency,
    required this.size,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: category != _lastCategory ? size.getItemSpacing() : 0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // 手绘色块指示器：数据色实底 + 墨线描边
                    Container(
                      width: size.getLegendIndicatorWidth() * 0.5,
                      height: size.getLegendIndicatorHeight() * 0.75,
                      decoration: dsSketchDecoration(
                        theme: theme,
                        radius: BorderRadius.circular(
                          size.getStrokeWidth() / 4,
                        ),
                        fillColor: category.color,
                      ),
                    ),
                    SizedBox(width: size.getSmallSpacing() * 2),
                    Text(
                      category.label,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: size.getLegendFontSize(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: size.getLegendFontSize() * 4,
                height: size.getLegendFontSize() * 1.2,
                child: AnimatedFlipCounter(
                  value: category.amount * animation.value,
                  wholeDigits: 2,
                  fractionDigits: 0,
                  prefix: currency,
                  textStyle: TextStyle(
                    color: theme.text,
                    fontSize: size.getLegendFontSize(),
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  CategoryData get _lastCategory => category;
}

/// 斜纹纵向堆叠柱绘制器
///
/// 胶囊轨道（surfaceAlt 底 + 淡墨斜纹 + 淡墨描边）内按金额占比切槽：
/// 每段铺数据色浅底 + 数据色斜纹（0.9，与分段进度条/条纹柱同款纹样）+
/// 数据色描边，段高随入场动画从各自槽底生长。
class _StripedStackedBarPainter extends CustomPainter {
  final List<CategoryData> categories;
  final AppThemeData theme;
  final double scale;
  final double progress;

  const _StripedStackedBarPainter({
    required this.categories,
    required this.theme,
    required this.scale,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width / 2),
    );

    // 轨道：surfaceAlt 底 + 淡墨斜纹 + 淡墨描边
    final trackPath = Path()..addRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      trackPath,
      Offset.zero & size,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    final total = categories.fold<double>(0, (sum, c) => sum + c.amount);
    if (total <= 0) return;

    canvas.save();
    canvas.clipRRect(rrect);
    var y = 0.0;
    for (final category in categories) {
      final slotHeight = size.height * (category.amount / total);
      final h = slotHeight * progress;
      if (h > 0.5) {
        // 与原实现一致：色块锚定各槽底部向上生长
        final rect = Rect.fromLTWH(
          0,
          y + slotHeight - h,
          size.width,
          h,
        );
        canvas.drawRect(
          rect,
          Paint()..color = category.color.withValues(alpha: 0.28),
        );
        paintDiagonalStripes(
          canvas,
          Path()..addRect(rect),
          rect,
          color: category.color.withValues(alpha: 0.9),
          strokeWidth: 3 * scale,
          spacing: 6.5 * scale,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = category.color.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * scale,
        );
      }
      y += slotHeight;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripedStackedBarPainter oldDelegate) {
    return oldDelegate.categories != categories ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale ||
        oldDelegate.progress != progress;
  }
}
