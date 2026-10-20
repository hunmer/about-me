import 'dart:math' as math;
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 支出追踪卡片（深色）
///
/// 顶部为标题与半圆彩色弧段仪表（每段对应一个支出分类，中心显示总额），
/// 中部为月份胶囊选择条（两侧渐隐遮罩），底部为分类列表
/// （圆形图标徽章 + 名称/金额 + 32 格刻度条）。
/// 点击分类行可高亮对应弧段并在中心显示该分类金额。
class ExpenseTrackerCardWidget extends StatefulWidget {
  /// 卡片标题（如 'Expense Tracker'）
  final String title;

  /// 支出分类列表（颜色同时用于弧段与刻度条）
  final List<ExpenseCategoryData> categories;

  /// 月份数据列表（amounts 与 categories 对齐）；少于 2 个月时隐藏月份条
  final List<ExpenseMonthData> months;

  /// 初始选中月份下标
  final int initialMonthIndex;

  /// 总额标签（如 'Total Expense'）
  final String totalLabel;

  /// 金额前缀（如 '\$'）
  final String currencyPrefix;

  /// 月份切换回调
  final ValueChanged<int>? onMonthChanged;

  /// 分类点击回调（高亮切换后触发，index 为分类下标）
  final ValueChanged<int>? onCategoryTap;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const ExpenseTrackerCardWidget({
    super.key,
    this.title = 'Expense Tracker',
    required this.categories,
    required this.months,
    this.initialMonthIndex = 0,
    this.totalLabel = 'Total Expense',
    this.currencyPrefix = '\$',
    this.onMonthChanged,
    this.onCategoryTap,
    this.inline = false,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例
  factory ExpenseTrackerCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    Color parseColor(dynamic colorValue, Color fallback) {
      if (colorValue == null) return fallback;
      if (colorValue is Color) return colorValue;
      if (colorValue is int) return Color(colorValue);
      if (colorValue is String) {
        try {
          if (colorValue.startsWith('#')) {
            return Color(
              int.parse(colorValue.substring(1), radix: 16) + 0xFF000000,
            );
          }
          if (colorValue.startsWith('0x')) {
            return Color(int.parse(colorValue.substring(2), radix: 16));
          }
        } catch (e) {
          // 解析失败，返回默认颜色
        }
      }
      return fallback;
    }

    final categories = <ExpenseCategoryData>[];
    final categoriesData = props['categories'];
    if (categoriesData is List) {
      for (final item in categoriesData) {
        if (item is Map<String, dynamic>) {
          final iconValue = item['icon'];
          categories.add(
            ExpenseCategoryData(
              label: item['label'] as String? ?? '',
              icon:
                  iconValue is IconData
                      ? iconValue
                      : dynamicIconData(
                          (iconValue as num?)?.toInt() ??
                              Icons.category.codePoint,
                          fontFamily: 'MaterialIcons',
                        ),
              color: parseColor(item['color'], const Color(0xFF6170F8)),
            ),
          );
        }
      }
    }

    final months = <ExpenseMonthData>[];
    final monthsData = props['months'];
    if (monthsData is List) {
      for (final item in monthsData) {
        if (item is Map<String, dynamic>) {
          final amountsData = item['amounts'];
          months.add(
            ExpenseMonthData(
              label: item['label'] as String? ?? '',
              amounts:
                  amountsData is List
                      ? amountsData
                          .map((e) => (e as num?)?.toDouble() ?? 0.0)
                          .toList()
                      : const [],
            ),
          );
        }
      }
    }

    return ExpenseTrackerCardWidget(
      title: props['title'] as String? ?? 'Expense Tracker',
      categories: categories,
      months: months,
      initialMonthIndex: (props['initialMonthIndex'] as num?)?.toInt() ?? 0,
      totalLabel: props['totalLabel'] as String? ?? 'Total Expense',
      currencyPrefix: props['currencyPrefix'] as String? ?? '\$',
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<ExpenseTrackerCardWidget> createState() =>
      _ExpenseTrackerCardWidgetState();
}

class _ExpenseTrackerCardWidgetState extends State<ExpenseTrackerCardWidget>
    with TickerProviderStateMixin {
  static const _cardColor = Color(0xFF151419);
  static const _badgeColor = Color(0xFF1F1E25);
  static const _tickInactiveColor = Color(0xFF26252E);
  static const _labelColor = Color(0xFFECECEF);
  static const _monthInactiveColor = Color(0xFF75757E);
  static const _totalLabelColor = Color(0xFF7E7E87);
  static const _monthActiveColor = Color(0xFF6826F6);
  static const _totalTicks = 32;

  late AnimationController _entranceController;
  late Animation<double> _entrance;
  late AnimationController _monthController;
  late Animation<double> _monthAnimation;

  late int _selectedMonth;
  late List<double> _fromShares;
  int? _highlightIndex;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonthIndex.clamp(
      0,
      math.max(0, widget.months.length - 1),
    );
    _fromShares = _sharesFor(_selectedMonth);

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _monthController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
      value: 1.0,
    );
    _monthAnimation = CurvedAnimation(
      parent: _monthController,
      curve: Curves.easeOutCubic,
    );

    void refresh() => setState(() {});
    _entranceController.addListener(refresh);
    _monthController.addListener(refresh);
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  List<double> _amountsFor(int month) {
    if (widget.months.isEmpty) return const [];
    return widget.months[month.clamp(0, widget.months.length - 1)].amounts;
  }

  List<double> _sharesFor(int month) {
    final amounts = _amountsFor(month);
    final total = amounts.fold<double>(0, (sum, v) => sum + v);
    return amounts
        .map((v) => total > 0 ? v / total : 0.0)
        .toList(growable: false);
  }

  /// 当前动画插值后的分类占比
  List<double> _currentShares() {
    final to = _sharesFor(_selectedMonth);
    final t = _monthAnimation.value;
    return List<double>.generate(to.length, (i) {
      final from = i < _fromShares.length ? _fromShares[i] : 0.0;
      return from + (to[i] - from) * t;
    });
  }

  double get _totalAmount =>
      _amountsFor(_selectedMonth).fold<double>(0, (sum, v) => sum + v);

  void _onMonthTap(int index) {
    if (index == _selectedMonth) return;
    setState(() {
      _fromShares = _currentShares();
      _selectedMonth = index;
    });
    _monthController.forward(from: 0);
    widget.onMonthChanged?.call(index);
  }

  void _onCategoryTap(int index) {
    setState(() {
      _highlightIndex = _highlightIndex == index ? null : index;
    });
    widget.onCategoryTap?.call(index);
  }

  double _defaultHeight() {
    final scale = widget.size.scale;
    if (widget.size is SmallSize) return 150 * scale;
    if (widget.size is MediumSize || widget.size is WideSize) {
      return 190 * scale;
    }
    if (widget.size is LargeSize || widget.size is Wide2Size) {
      return 330 * scale;
    }
    return 430 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size.scale;

    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        return Opacity(
          opacity: _entrance.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _entrance.value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.inline ? double.maxFinite : 384 * s,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(34 * s),
          boxShadow: [
            BoxShadow(
              color: _cardColor.withOpacity(0.35),
              blurRadius: 60 * s,
              offset: Offset(0, 28 * s),
              spreadRadius: -15 * s,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34 * s),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24 * s, 22 * s, 24 * s, 18 * s),
            child: _buildContent(s),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(double s) {
    // 矮尺寸只显示弧段仪表
    if (widget.size is SmallSize ||
        widget.size is MediumSize ||
        widget.size is WideSize) {
      return Center(child: _buildGauge(s));
    }

    final showMonthBar = widget.months.length > 1;
    return Column(
      children: [
        Text(
          widget.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 21 * s,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.01 * s,
            height: 1.0,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        SizedBox(height: 10 * s),
        _buildGauge(s),
        if (showMonthBar) ...[
          SizedBox(height: 14 * s),
          _buildMonthBar(s),
        ],
        SizedBox(height: 16 * s),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildCategoryRows(s),
            ),
          ),
        ),
      ],
    );
  }

  /// 半圆弧段仪表 + 中心读数
  Widget _buildGauge(double s) {
    final stroke = 15.5 * s;
    final glowPad = 8 * s;
    final shares = _currentShares();
    final amounts = _amountsFor(_selectedMonth);
    final highlight = _highlightIndex;

    final centerValue =
        highlight != null && highlight < amounts.length
            ? amounts[highlight]
            : _totalAmount;
    final centerLabel =
        highlight != null && highlight < widget.categories.length
            ? widget.categories[highlight].label
            : widget.totalLabel;
    final centerLabelColor =
        highlight != null && highlight < widget.categories.length
            ? widget.categories[highlight].color
            : _totalLabelColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final radius = math.min(
          constraints.maxWidth / 2 - stroke / 2 - glowPad,
          constraints.maxHeight - stroke - glowPad - 2 * s,
        );
        if (radius <= 0) return const SizedBox.shrink();
        final w = 2 * (radius + stroke / 2 + glowPad);
        final h = radius + stroke + glowPad + 2 * s;

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(w, h),
                painter: _ArcGaugePainter(
                  shares: shares,
                  colors:
                      widget.categories.map((c) => c.color).toList(),
                  progress: _entrance.value,
                  highlightIndex: highlight,
                  scale: s,
                ),
              ),
              // 中心读数（位于弧内偏下）
              Positioned(
                left: 0,
                right: 0,
                bottom: 2 * s,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedFlipCounter(
                      value: centerValue * _entrance.value,
                      fractionDigits: 0,
                      prefix: widget.currencyPrefix,
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 34 * s,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.5 * s,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 3 * s),
                    Text(
                      centerLabel,
                      style: TextStyle(
                        color: centerLabelColor,
                        fontSize: 13 * s,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 月份胶囊选择条（两侧水平渐隐遮罩）
  Widget _buildMonthBar(double s) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        return const LinearGradient(
          colors: [
            Colors.transparent,
            Color(0x40FFFFFF),
            Colors.white,
            Colors.white,
            Color(0x40FFFFFF),
            Colors.transparent,
          ],
          stops: [0.0, 0.07, 0.2, 0.8, 0.93, 1.0],
        ).createShader(rect);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.months.length, (i) {
          final active = i == _selectedMonth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onMonthTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: (active ? 15 : 8) * s,
                vertical: 6 * s,
              ),
              decoration: BoxDecoration(
                color: active ? _monthActiveColor : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow:
                    active
                        ? [
                          BoxShadow(
                            color: _monthActiveColor.withOpacity(0.45),
                            blurRadius: 14 * s,
                            offset: Offset(0, 4 * s),
                          ),
                        ]
                        : null,
              ),
              child: Text(
                widget.months[i].label,
                style: TextStyle(
                  color: active ? Colors.white : _monthInactiveColor,
                  fontSize: 13.5 * s,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  height: 1.0,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildCategoryRows(double s) {
    final amounts = _amountsFor(_selectedMonth);
    final maxAmount = amounts.fold<double>(
      0,
      (max, v) => v > max ? v : max,
    );
    final rows = <Widget>[];

    for (int i = 0; i < widget.categories.length; i++) {
      final category = widget.categories[i];
      final amount = i < amounts.length ? amounts[i] : 0.0;
      // 刻度填充数：相对最大分类金额的比例 × 32
      final targetFilled =
          maxAmount > 0 ? (amount / maxAmount * _totalTicks).round() : 0;
      final filled = (targetFilled * _entrance.value).round();
      final dimmed = _highlightIndex != null && _highlightIndex != i;

      if (i > 0) rows.add(SizedBox(height: 20 * s));

      rows.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onCategoryTap(i),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: dimmed ? 0.4 : 1.0,
            child: Row(
              children: [
                // 圆形图标徽章
                Container(
                  width: 42 * s,
                  height: 42 * s,
                  decoration: const BoxDecoration(
                    color: _badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(category.icon, size: 20 * s, color: category.color),
                ),
                SizedBox(width: 14 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              category.label,
                              style: TextStyle(
                                color: _labelColor,
                                fontSize: 15 * s,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.01 * s,
                                height: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Text(
                            '${widget.currencyPrefix}${amount.round()}',
                            style: TextStyle(
                              color: _labelColor,
                              fontSize: 15 * s,
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8 * s),
                      // 32 格刻度条
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(_totalTicks, (t) {
                          return Container(
                            width: 3 * s,
                            height: 14 * s,
                            decoration: BoxDecoration(
                              color:
                                  t < filled
                                      ? category.color
                                      : _tickInactiveColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return rows;
  }
}

/// 半圆弧段仪表绘制器
class _ArcGaugePainter extends CustomPainter {
  /// 各分类占比（已按月份切换动画插值）
  final List<double> shares;
  final List<Color> colors;

  /// 入场生长进度 0..1
  final double progress;

  /// 高亮分类下标（其余弧段淡出变细，高亮段加粗带辉光）
  final int? highlightIndex;
  final double scale;

  _ArcGaugePainter({
    required this.shares,
    required this.colors,
    required this.progress,
    required this.highlightIndex,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shares.isEmpty) return;

    final s = scale;
    final strokeBase = 15.5 * s;
    final glowPad = 8 * s;
    final radius = size.width / 2 - strokeBase / 2 - glowPad;
    final center = Offset(size.width / 2, radius + strokeBase / 2 + glowPad);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 段间固定间隙角（参考效果图约 12°），只在相邻段之间留缝
    final gapRad = shares.length > 1 ? 12 * math.pi / 180 : 0.0;
    final available = math.pi - gapRad * (shares.length - 1);

    // 从正左方（π）开始，沿上半圆顺时针（画布角递增）到正右方（2π）
    var cursor = math.pi;
    for (int i = 0; i < shares.length; i++) {
      final fullSweep = available * shares[i];
      final sweep = fullSweep * progress;
      final highlighted = highlightIndex == i;
      final dimmed = highlightIndex != null && !highlighted;
      final stroke = (highlighted ? 17.5 : (dimmed ? 14.5 : 15.5)) * s;
      // 圆头线帽会沿切线吃掉间隙，两端内缩使线帽末端正好落在段边界
      final capInset = (stroke / 2) / radius;

      if (sweep > 2 * capInset) {
        final color = colors[i % colors.length];
        final paint =
            Paint()
              ..color = color.withOpacity(dimmed ? 0.28 : 1.0)
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeCap = StrokeCap.round;

        if (highlighted) {
          // 辉光底层
          canvas.drawArc(
            rect,
            cursor + capInset,
            sweep - 2 * capInset,
            false,
            Paint()
              ..color = color.withOpacity(0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeCap = StrokeCap.round
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s),
          );
        }
        canvas.drawArc(
          rect,
          cursor + capInset,
          sweep - 2 * capInset,
          false,
          paint,
        );
      }
      cursor += fullSweep + gapRad;
    }
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.highlightIndex != highlightIndex ||
        oldDelegate.scale != scale ||
        oldDelegate.shares.length != shares.length ||
        !_listEquals(oldDelegate.shares, shares);
  }

  bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.0001) return false;
    }
    return true;
  }
}

/// 支出分类数据模型
class ExpenseCategoryData {
  /// 分类名称（如 'Transfers'）
  final String label;

  /// 图标
  final IconData icon;

  /// 颜色（弧段 + 刻度条 + 图标共用）
  final Color color;

  const ExpenseCategoryData({
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// 月份数据模型
class ExpenseMonthData {
  /// 月份标签（如 'Dec'）
  final String label;

  /// 各分类金额（与 categories 对齐）
  final List<double> amounts;

  const ExpenseMonthData({required this.label, required this.amounts});
}
