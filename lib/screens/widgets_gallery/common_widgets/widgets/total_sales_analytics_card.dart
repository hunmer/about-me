import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 总销售分析卡片（深色）
///
/// 顶部为品牌圆标 + 标题 + 三个圆形操作按钮（筛选 / 通知带红点 / 展开），
/// 中部为大号总额指标，底部为多列柱状图：激活柱为斜纹（缓慢滑动）+
/// 顶部圆点光环 + 悬浮石灰黄数值胶囊，点击柱子切换激活态。
/// 存在多个周期数据集时，筛选按钮弹出周期切换菜单，展开按钮循环切换。
class TotalSalesAnalyticsCardWidget extends StatefulWidget {
  /// 卡片标题（如 'Total sales'）
  final String title;

  /// 周期数据集列表（如 'for all time' / 'this year'）
  final List<SalesPeriodData> periods;

  /// 初始周期下标
  final int initialPeriodIndex;

  /// 通知红点数量（0 或 null 不显示）
  final int? notificationCount;

  /// 柱子点击回调（激活切换后触发）
  final ValueChanged<int>? onBarTap;

  /// 筛选按钮回调（null 且多周期时内部弹出周期菜单）
  final VoidCallback? onFilterTap;

  /// 通知按钮回调（null 时内部切换红点显隐）
  final VoidCallback? onNotificationTap;

  /// 展开按钮回调（null 且多周期时内部循环切换周期）
  final VoidCallback? onExpandTap;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const TotalSalesAnalyticsCardWidget({
    super.key,
    this.title = 'Total sales',
    required this.periods,
    this.initialPeriodIndex = 0,
    this.notificationCount,
    this.onBarTap,
    this.onFilterTap,
    this.onNotificationTap,
    this.onExpandTap,
    this.inline = false,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例
  factory TotalSalesAnalyticsCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final periods = <SalesPeriodData>[];
    final periodsData = props['periods'];
    if (periodsData is List) {
      for (final item in periodsData) {
        if (item is Map<String, dynamic>) {
          final barsData = item['bars'];
          periods.add(
            SalesPeriodData(
              label: item['label'] as String? ?? '',
              total: (item['total'] as num?)?.toDouble() ?? 0.0,
              activeIndex: (item['activeIndex'] as num?)?.toInt() ?? 0,
              bars:
                  barsData is List
                      ? barsData.map((b) {
                        if (b is Map<String, dynamic>) {
                          return SalesBarData(
                            label: b['label'] as String? ?? '',
                            value: (b['value'] as num?)?.toDouble() ?? 0.0,
                          );
                        }
                        return const SalesBarData(label: '', value: 0);
                      }).toList()
                      : const [],
            ),
          );
        }
      }
    }

    return TotalSalesAnalyticsCardWidget(
      title: props['title'] as String? ?? 'Total sales',
      periods: periods,
      initialPeriodIndex: (props['initialPeriodIndex'] as num?)?.toInt() ?? 0,
      notificationCount: (props['notificationCount'] as num?)?.toInt(),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<TotalSalesAnalyticsCardWidget> createState() =>
      _TotalSalesAnalyticsCardWidgetState();
}

class _TotalSalesAnalyticsCardWidgetState
    extends State<TotalSalesAnalyticsCardWidget>
    with TickerProviderStateMixin {
  static const _cardColor = Color(0xFF171717);
  static const _buttonColor = Color(0xFF2C2C2C);
  static const _barColor = Color(0xFF2B2B2B);
  static const _pillColor = Color(0xFFEFFA87);
  static const _pillTextMain = Color(0xFF171717);
  static const _pillTextMuted = Color(0xFF6D7342);
  static const _badgeRed = Color(0xFFE53935);
  static const _mutedText = Color(0xFF7E7E7E);

  late AnimationController _entranceController;
  late Animation<double> _entrance;

  /// 激活柱斜纹缓慢滑动（18s 线性循环）
  late AnimationController _stripeController;

  late int _periodIndex;
  late int _activeBarIndex;
  bool _popoverOpen = false;
  late bool _badgeVisible;

  @override
  void initState() {
    super.initState();
    _periodIndex = widget.initialPeriodIndex.clamp(
      0,
      math.max(0, widget.periods.length - 1),
    );
    _activeBarIndex = _period.activeIndex.clamp(
      0,
      math.max(0, _period.bars.length - 1),
    );
    _badgeVisible = (widget.notificationCount ?? 0) > 0;

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceController.addListener(() {
      setState(() {});
    });
    _entranceController.forward();

    _stripeController = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _stripeController.dispose();
    super.dispose();
  }

  SalesPeriodData get _period =>
      widget.periods[_periodIndex.clamp(0, widget.periods.length - 1)];

  void _applyPeriod(int index) {
    if (index == _periodIndex) return;
    setState(() {
      _periodIndex = index;
      _activeBarIndex = _period.activeIndex.clamp(
        0,
        math.max(0, _period.bars.length - 1),
      );
    });
  }

  void _onFilterTap() {
    if (widget.onFilterTap != null) {
      widget.onFilterTap!();
      return;
    }
    if (widget.periods.length > 1) {
      setState(() => _popoverOpen = !_popoverOpen);
    }
  }

  void _onNotificationTap() {
    if (widget.onNotificationTap != null) {
      widget.onNotificationTap!();
    } else {
      setState(() => _badgeVisible = !_badgeVisible);
    }
  }

  void _onExpandTap() {
    if (widget.onExpandTap != null) {
      widget.onExpandTap!();
      return;
    }
    if (widget.periods.length > 1) {
      _applyPeriod((_periodIndex + 1) % widget.periods.length);
    }
  }

  void _onBarTap(int index) {
    setState(() => _activeBarIndex = index);
    widget.onBarTap?.call(index);
  }

  /// 千分位格式化并按首个逗号拆为主/副两段（90,744 -> '90' / ',744'）
  static (String, String) _splitAmount(double value) {
    final str = value.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final remaining = str.length - i;
      buf.write(str[i]);
      if (remaining > 1 && (remaining - 1) % 3 == 0) buf.write(',');
    }
    final formatted = buf.toString();
    final idx = formatted.indexOf(',');
    if (idx < 0) return (formatted, '');
    return (formatted.substring(0, idx), formatted.substring(idx));
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
          borderRadius: BorderRadius.circular(40 * s),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF121822).withOpacity(0.22),
              blurRadius: 60 * s,
              offset: Offset(0, 28 * s),
              spreadRadius: -15 * s,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40 * s),
          child: Padding(
            padding: EdgeInsets.fromLTRB(26 * s, 24 * s, 26 * s, 20 * s),
            child: _buildContent(s),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(double s) {
    // 矮尺寸只显示柱状图
    if (widget.size is SmallSize ||
        widget.size is MediumSize ||
        widget.size is WideSize) {
      return Center(child: _buildChart(s));
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(s),
            SizedBox(height: 16 * s),
            _buildMetric(s),
            SizedBox(height: 8 * s),
            Expanded(child: _buildChart(s)),
          ],
        ),
        // 周期筛选弹层
        if (_popoverOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _popoverOpen = false),
              child: const SizedBox.shrink(),
            ),
          ),
          Positioned(top: 62 * s, right: 0, child: _buildPopover(s)),
        ],
      ],
    );
  }

  /// 头部：品牌圆标 + 标题 + 三个圆形操作按钮
  Widget _buildHeader(double s) {
    return Row(
      children: [
        // 品牌圆标（双圆角柱线框）
        Container(
          width: 48 * s,
          height: 48 * s,
          decoration: BoxDecoration(
            color: _cardColor,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF343434), width: 1),
          ),
          child: Center(
            child: CustomPaint(
              size: Size(22 * s, 22 * s),
              painter: _LogoMarkPainter(scale: s),
            ),
          ),
        ),
        SizedBox(width: 14 * s),
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 23 * s,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.015 * 23 * s,
              height: 1.0,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        _buildActionButton(
          s,
          icon: Icons.tune,
          onTap: _onFilterTap,
          pressed: _popoverOpen,
        ),
        SizedBox(width: 8 * s),
        _buildActionButton(
          s,
          icon: Icons.chat_bubble_outline,
          onTap: _onNotificationTap,
          badgeCount: _badgeVisible ? widget.notificationCount : null,
        ),
        SizedBox(width: 8 * s),
        _buildActionButton(s, icon: Icons.arrow_outward, onTap: _onExpandTap),
      ],
    );
  }

  Widget _buildActionButton(
    double s, {
    required IconData icon,
    required VoidCallback onTap,
    int? badgeCount,
    bool pressed = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 48 * s,
        height: 48 * s,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              transform:
                  pressed ? (Matrix4.identity()..scale(0.95)) : Matrix4.identity(),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                color: pressed ? const Color(0xFF3A3A3A) : _buttonColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 6 * s,
                    offset: Offset(0, 2 * s),
                  ),
                ],
              ),
              child: Icon(icon, size: 21 * s, color: Colors.white),
            ),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: -2 * s,
                right: -1 * s,
                child: Container(
                  width: 18 * s,
                  height: 18 * s,
                  decoration: BoxDecoration(
                    color: _badgeRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 5 * s,
                        offset: Offset(0, 2 * s),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 99 ? '99' : badgeCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11 * s,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 总额指标（与标题文字左对齐）
  Widget _buildMetric(double s) {
    final (main, suffix) = _splitAmount(_period.total);
    return Padding(
      padding: EdgeInsets.only(left: 62 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _period.label,
            style: TextStyle(
              color: _mutedText,
              fontSize: 14 * s,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.01 * s,
              height: 1.0,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          SizedBox(height: 5 * s),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: main,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48 * s,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.02 * 48 * s,
                    height: 1.08,
                  ),
                ),
                TextSpan(
                  text: suffix,
                  style: TextStyle(
                    color: const Color(0xFF707070),
                    fontSize: 48 * s,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.02 * 48 * s,
                    height: 1.08,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 柱状图（柱子 + 顶部圆点 + 悬浮数值胶囊 + 月份标签）
  Widget _buildChart(double s) {
    final bars = _period.bars;
    if (bars.isEmpty) return const SizedBox.shrink();
    final maxValue = bars.fold<double>(0, (m, b) => b.value > m ? b.value : m);
    final barMaxHeight = 150 * s;

    return Padding(
      // 顶部预留数值胶囊空间
      padding: EdgeInsets.only(top: 42 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(bars.length, (i) {
          final bar = bars[i];
          final active = i == _activeBarIndex;
          final targetHeight =
              maxValue > 0 ? (bar.value / maxValue * barMaxHeight) : 0.0;
          final barHeight =
              math.max(targetHeight * _entrance.value, 8 * s);

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onBarTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      _buildBarPillar(s, barHeight, active),
                      // 悬浮石灰黄数值胶囊
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        bottom: barHeight + 1 * s,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 280),
                          scale: active ? 1.0 : 0.92,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 240),
                            opacity: active ? 1.0 : 0.0,
                            child: _buildValuePill(s, bar.value),
                          ),
                        ),
                      ),
                      // 顶部圆点
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        bottom: barHeight - 3 * s,
                        child: Container(
                          width: 6 * s,
                          height: 6 * s,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow:
                                active
                                    ? [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.2),
                                        spreadRadius: 5 * s,
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.18),
                                        blurRadius: 12 * s,
                                        spreadRadius: 2 * s,
                                      ),
                                    ]
                                    : [
                                      BoxShadow(
                                        color: const Color(0xFF1F1F1F),
                                        spreadRadius: 3.5 * s,
                                      ),
                                    ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12 * s),
                  Text(
                    bar.label,
                    style: TextStyle(
                      color:
                          active ? const Color(0xFF9E9E9E) : const Color(0xFF7C7C7C),
                      fontSize: 13 * s,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1 * s,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 柱子：非激活为深灰 + 顶部渐变描边，激活为滑动斜纹
  Widget _buildBarPillar(double s, double height, bool active) {
    final radius = BorderRadius.circular(18 * s);

    if (active) {
      return AnimatedBuilder(
        animation: _stripeController,
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            height: height,
            margin: EdgeInsets.symmetric(horizontal: 2 * s),
            decoration: BoxDecoration(
              color: const Color(0xFF212121),
              borderRadius: radius,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: CustomPaint(
                painter: _StripesPainter(
                  offset: _stripeController.value,
                  scale: s,
                ),
              ),
            ),
          );
        },
      );
    }

    // 非激活：外层渐变（模拟顶部弧光描边）+ 内层深灰
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      height: height,
      margin: EdgeInsets.symmetric(horizontal: 2 * s),
      padding: EdgeInsets.all(1.2 * s),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF767676),
            Color(0x73767676),
            Color(0x0AFFFFFF),
            Colors.transparent,
          ],
          stops: [0.0, 0.12, 0.28, 0.6],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: _barColor, borderRadius: radius),
      ),
    );
  }

  /// 石灰黄数值胶囊（主段深色 + 千分位副段灰绿）
  Widget _buildValuePill(double s, double value) {
    final (main, dec) = _splitAmount(value);
    return Container(
      padding: EdgeInsets.fromLTRB(13 * s, 9 * s, 13 * s, 10 * s),
      decoration: BoxDecoration(
        color: _pillColor,
        borderRadius: BorderRadius.circular(20 * s),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 20 * s,
            offset: Offset(0, 8 * s),
            spreadRadius: -4 * s,
          ),
        ],
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: main,
              style: TextStyle(
                color: _pillTextMain,
                fontSize: 16 * s,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.2 * s,
                height: 1.2,
              ),
            ),
            TextSpan(
              text: dec,
              style: TextStyle(
                color: _pillTextMuted,
                fontSize: 16 * s,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.2 * s,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 周期筛选弹层
  Widget _buildPopover(double s) {
    return Container(
      padding: EdgeInsets.all(6 * s),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 32 * s,
            offset: Offset(0, 16 * s),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(widget.periods.length, (i) {
          final period = widget.periods[i];
          final selected = i == _periodIndex;
          final (main, suffix) = _splitAmount(period.total);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _applyPeriod(i);
              setState(() => _popoverOpen = false);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 7 * s),
              decoration: BoxDecoration(
                color:
                    selected
                        ? _pillColor.withOpacity(0.12)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12 * s),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    period.label,
                    style: TextStyle(
                      color: selected ? _pillColor : const Color(0xFFB5B5B5),
                      fontSize: 13 * s,
                      fontWeight: FontWeight.w400,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(width: 16 * s),
                  Text(
                    '$main$suffix',
                    style: TextStyle(
                      color: selected ? _pillColor : const Color(0xFFB5B5B5),
                      fontSize: 13 * s,
                      fontWeight: FontWeight.w400,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 品牌圆标线框绘制（双圆角柱轮廓）
class _LogoMarkPainter extends CustomPainter {
  final double scale;

  _LogoMarkPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 22;
    final paint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * k;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4.5 * k, 7 * k, 5.2 * k, 11.5 * k),
        Radius.circular(2.6 * k),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12.3 * k, 3.5 * k, 5.2 * k, 15 * k),
        Radius.circular(2.6 * k),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoMarkPainter oldDelegate) =>
      oldDelegate.scale != scale;
}

/// 激活柱斜纹绘制（-45° 深浅交替条纹，offset 0..1 循环滑动）
class _StripesPainter extends CustomPainter {
  final double offset;
  final double scale;

  _StripesPainter({required this.offset, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale;
    final stripeW = 7.5 * s;
    // background-size 21.21px = 15px × √2，一个循环周期
    final period = 15 * s * math.sqrt2;
    final shift = offset * period;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);
    final extent = (size.width + size.height);
    final dark =
        Paint()
          ..color = const Color(0xFF2C2C2C)
          ..strokeWidth = stripeW;
    final light =
        Paint()
          ..color = const Color(0xFF1E1E1E)
          ..strokeWidth = stripeW;
    var i = 0;
    for (double x = -extent - period + (shift % period);
        x < extent;
        x += stripeW, i++) {
      canvas.drawLine(
        Offset(x, -extent),
        Offset(x, extent),
        i.isEven ? dark : light,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripesPainter oldDelegate) =>
      oldDelegate.offset != offset || oldDelegate.scale != scale;
}

/// 柱状图条目数据模型
class SalesBarData {
  /// 标签（如 'Jun'）
  final String label;

  /// 数值（如 16520）
  final double value;

  const SalesBarData({required this.label, required this.value});
}

/// 周期数据集模型
class SalesPeriodData {
  /// 周期标签（如 'for all time'）
  final String label;

  /// 周期总额（如 90744）
  final double total;

  /// 柱条目列表
  final List<SalesBarData> bars;

  /// 默认激活柱下标
  final int activeIndex;

  const SalesPeriodData({
    required this.label,
    required this.total,
    required this.bars,
    this.activeIndex = 0,
  });
}
