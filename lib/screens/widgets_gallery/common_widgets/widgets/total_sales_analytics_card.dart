/// 总销售分析卡片（手绘纸卡风格，深底核心视觉保留）
///
/// 手绘深色纸卡（深底 + rough 墨线框，WiredDraw 描画入场）：
/// 顶部为品牌圆标 + 标题 + 三个手绘圆形操作按钮（筛选 / 通知带红点 / 展开），
/// 中部为大号总额指标，底部为多列柱状图：激活柱为石灰黄滑动斜纹 +
/// 顶部圆点 + 悬浮石灰黄数值胶囊，点击柱子切换激活态。
/// 存在多个周期数据集时，筛选按钮弹出周期切换菜单，展开按钮循环切换。
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

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
  /// 深底核心视觉：近黑纸底 + 配套深灰描边/轨道（原型设计保留）
  static const _cardColor = Color(0xFF171717);
  static const _buttonColor = Color(0xFF2C2C2C);
  static const _strokeSubtle = Color(0xFF3A3A3A);
  static const _barColor = Color(0xFF2B2B2B);
  static const _pillColor = Color(0xFFEFFA87);
  static const _pillTextMain = Color(0xFF171717);
  static const _pillTextMuted = Color(0xFF6D7342);
  static const _badgeRed = Color(0xFFE53935);
  static const _mutedText = Color(0xFF7E7E7E);
  static const _labelActive = Color(0xFF9E9E9E);
  static const _labelMuted = Color(0xFF7C7C7C);

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
    // 柱高生长动画（整卡淡入已交由 WiredDraw 描画入场）
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
    final theme = AppTheme.of(context);
    final s = widget.size.scale;

    // 手绘深色纸卡：深底 + 淡灰排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * s,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        radius: BorderRadius.circular(24 * s),
        padding: EdgeInsets.fromLTRB(26 * s, 24 * s, 26 * s, 20 * s),
        fillColor: _cardColor,
        hachureColor: _barColor,
        stroke: _strokeSubtle,
        child: _buildContent(theme, s),
      ),
    );
  }

  Widget _buildContent(AppThemeData theme, double s) {
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
            _buildHeader(theme, s),
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
          Positioned(top: 62 * s, right: 0, child: _buildPopover(theme, s)),
        ],
      ],
    );
  }

  /// 头部：品牌圆标 + 标题 + 三个圆形操作按钮
  Widget _buildHeader(AppThemeData theme, double s) {
    return Row(
      children: [
        // 品牌圆标（手绘圆底 + 双圆角柱线框）
        Container(
          width: 48 * s,
          height: 48 * s,
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(48 * s / 2),
            fillColor: _cardColor,
            stroke: const Color(0xFF343434),
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
          theme,
          s,
          icon: Icons.tune,
          onTap: _onFilterTap,
          pressed: _popoverOpen,
        ),
        SizedBox(width: 8 * s),
        _buildActionButton(
          theme,
          s,
          icon: Icons.chat_bubble_outline,
          onTap: _onNotificationTap,
          badgeCount: _badgeVisible ? widget.notificationCount : null,
        ),
        SizedBox(width: 8 * s),
        _buildActionButton(theme, s, icon: Icons.arrow_outward, onTap: _onExpandTap),
      ],
    );
  }

  Widget _buildActionButton(
    AppThemeData theme,
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
            // 手绘圆底操作按钮（深底核心视觉保留，柔影删除）
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              transform:
                  pressed ? (Matrix4.identity()..scale(0.95)) : Matrix4.identity(),
              transformAlignment: Alignment.center,
              decoration: dsSketchDecoration(
                theme: theme,
                radius: BorderRadius.circular(48 * s / 2),
                fillColor: pressed ? _strokeSubtle : _buttonColor,
                stroke: _strokeSubtle,
              ),
              child: Center(
                child: _buildActionIcon(theme, icon, 21 * s),
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: -2 * s,
                right: -1 * s,
                child: Container(
                  width: 18 * s,
                  height: 18 * s,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: BorderRadius.circular(18 * s / 2),
                    fillColor: _badgeRed,
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

  /// 操作按钮图标：DsIconKind 收录的走手绘目录，其余走 WiredIcon 兜底
  Widget _buildActionIcon(AppThemeData theme, IconData icon, double size) {
    if (icon == Icons.tune) {
      return DsIcon(DsIconKind.tune, size: size, color: Colors.white);
    }
    if (icon == Icons.chat_bubble_outline) {
      return DsIcon(DsIconKind.chat, size: size, color: Colors.white);
    }
    return WiredIcon(
      icon: icon,
      size: size,
      color: Colors.white,
      drawConfig: theme.wired.drawConfig,
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
                      // 顶部圆点（激活态外圈光环改实心小圆环，柔影删除）
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        bottom: barHeight - 3 * s,
                        child: _buildTopDot(s, active),
                      ),
                    ],
                  ),
                  SizedBox(height: 12 * s),
                  Text(
                    bar.label,
                    style: TextStyle(
                      color: active ? _labelActive : _labelMuted,
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

  /// 顶部圆点：激活为白点 + 淡白光环（平直小圆几何，无柔影）
  Widget _buildTopDot(double s, bool active) {
    if (!active) {
      return Container(
        width: 6 * s,
        height: 6 * s,
        decoration: BoxDecoration(color: _labelMuted, shape: BoxShape.circle),
      );
    }
    return Container(
      width: 14 * s,
      height: 14 * s,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 6 * s,
          height: 6 * s,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  /// 柱子：非激活为深灰轨道段，激活为石灰黄滑动斜纹（数据色 §9.5）
  Widget _buildBarPillar(double s, double height, bool active) {
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
            child: CustomPaint(
              painter: _ActiveBarPainter(
                offset: _stripeController.value,
                scale: s,
              ),
            ),
          );
        },
      );
    }

    // 非激活：深灰轨道段（深底卡片语言：淡白斜纹 + 淡白描边）
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      height: height,
      margin: EdgeInsets.symmetric(horizontal: 2 * s),
      child: CustomPaint(
        painter: _InactiveBarPainter(scale: s),
      ),
    );
  }

  /// 石灰黄数值胶囊（主段深色 + 千分位副段灰绿，手绘墨线框）
  Widget _buildValuePill(double s, double value) {
    final theme = AppTheme.of(context);
    final (main, dec) = _splitAmount(value);
    return Container(
      padding: EdgeInsets.fromLTRB(13 * s, 9 * s, 13 * s, 10 * s),
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(20 * s),
        fillColor: _pillColor,
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

  /// 周期筛选弹层（手绘深底面板）
  Widget _buildPopover(AppThemeData theme, double s) {
    return Container(
      padding: EdgeInsets.all(6 * s),
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(18 * s),
        fillColor: const Color(0xFF242424),
        stroke: Colors.white.withValues(alpha: 0.25),
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
                        ? _pillColor.withValues(alpha: 0.12)
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

/// 激活柱绘制：石灰黄数据色浅底 + 滑动斜纹 + 描边（§9.5，公共斜纹工具）
///
/// 斜纹沿 offset 0..1 循环滑动（平移画布 + 反向平移裁剪路径实现，
/// 条纹本体仍统一走 paintDiagonalStripes）。
class _ActiveBarPainter extends CustomPainter {
  final double offset;
  final double scale;

  _ActiveBarPainter({required this.offset, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(18 * scale),
    );
    final rect = Offset.zero & size;

    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFFEFFA87).withValues(alpha: 0.28),
    );
    final spacing = 6.5 * scale;
    final dx = offset * spacing;
    canvas.save();
    canvas.translate(-dx, 0);
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(rrect.shift(Offset(dx, 0))),
      rect.shift(Offset(dx, 0)),
      color: const Color(0xFFEFFA87).withValues(alpha: 0.9),
      strokeWidth: 3 * scale,
      spacing: spacing,
    );
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFFEFFA87).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _ActiveBarPainter oldDelegate) =>
      oldDelegate.offset != offset || oldDelegate.scale != scale;
}

/// 非激活柱绘制：深灰轨道底 + 淡白斜纹 + 淡白描边（§9.5 轨道语言，深底适配）
class _InactiveBarPainter extends CustomPainter {
  final double scale;

  _InactiveBarPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(18 * scale),
    );
    final rect = Offset.zero & size;

    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF2B2B2B));
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(rrect),
      rect,
      color: Colors.white.withValues(alpha: 0.10),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _InactiveBarPainter oldDelegate) =>
      oldDelegate.scale != scale;
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
