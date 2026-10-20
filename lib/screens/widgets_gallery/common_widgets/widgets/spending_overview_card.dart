import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 支出概览卡片（磨砂浅灰）
///
/// 顶部为标题与周期下拉，中部为大号总额与趋势，左侧为分类列表
/// （圆形图标徽章 + 名称/百分比 + 金额），右侧为被卡片右缘垂直平切的
/// 甜甜圈图：沿弧顺序为分类列表逆序，首尾两段外凸（投影 + 右缘平切），
/// 中间段基础半径并带斜纹质感。支持任意数量分类。
class SpendingOverviewCardWidget extends StatefulWidget {
  /// 卡片标题（如 'Spending Overview'）
  final String title;

  /// 支出分类列表（颜色用于甜甜圈扇区）
  final List<SpendingCategoryData> categories;

  /// 周期数据集列表（amounts 与 categories 对齐）；多于 1 个时显示下拉切换
  final List<SpendingPeriodData> periods;

  /// 初始周期下标
  final int initialPeriodIndex;

  /// 趋势说明文案（如 'from last month'）
  final String compareLabel;

  /// 货币符号（如 '\$'）
  final String currencySymbol;

  /// 周期切换回调
  final ValueChanged<int>? onPeriodChanged;

  /// 分类点击回调（高亮切换后触发）
  final ValueChanged<int>? onCategoryTap;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const SpendingOverviewCardWidget({
    super.key,
    this.title = 'Spending Overview',
    required this.categories,
    required this.periods,
    this.initialPeriodIndex = 0,
    this.compareLabel = 'from last month',
    this.currencySymbol = '\$',
    this.onPeriodChanged,
    this.onCategoryTap,
    this.inline = false,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例
  factory SpendingOverviewCardWidget.fromProps(
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

    final categories = <SpendingCategoryData>[];
    final categoriesData = props['categories'];
    if (categoriesData is List) {
      for (final item in categoriesData) {
        if (item is Map<String, dynamic>) {
          final iconValue = item['icon'];
          categories.add(
            SpendingCategoryData(
              label: item['label'] as String? ?? '',
              icon:
                  iconValue is IconData
                      ? iconValue
                      : dynamicIconData(
                          (iconValue as num?)?.toInt() ??
                              Icons.category.codePoint,
                          fontFamily: 'MaterialIcons',
                        ),
              color: parseColor(item['color'], const Color(0xFF5B50E6)),
            ),
          );
        }
      }
    }

    final periods = <SpendingPeriodData>[];
    final periodsData = props['periods'];
    if (periodsData is List) {
      for (final item in periodsData) {
        if (item is Map<String, dynamic>) {
          final amountsData = item['amounts'];
          periods.add(
            SpendingPeriodData(
              label: item['label'] as String? ?? '',
              total: (item['total'] as num?)?.toDouble() ?? 0.0,
              trendText: item['trendText'] as String? ?? '',
              trendUp: item['trendUp'] as bool? ?? true,
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

    return SpendingOverviewCardWidget(
      title: props['title'] as String? ?? 'Spending Overview',
      categories: categories,
      periods: periods,
      initialPeriodIndex: (props['initialPeriodIndex'] as num?)?.toInt() ?? 0,
      compareLabel: props['compareLabel'] as String? ?? 'from last month',
      currencySymbol: props['currencySymbol'] as String? ?? '\$',
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<SpendingOverviewCardWidget> createState() =>
      _SpendingOverviewCardWidgetState();
}

class _SpendingOverviewCardWidgetState
    extends State<SpendingOverviewCardWidget>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _entrance;
  late AnimationController _periodController;
  late Animation<double> _periodAnimation;

  late int _periodIndex;
  late List<double> _fromShares;
  int? _highlightIndex;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _periodIndex = widget.initialPeriodIndex.clamp(
      0,
      math.max(0, widget.periods.length - 1),
    );
    _fromShares = _sharesFor(_periodIndex);

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _periodController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
      value: 1.0,
    );
    _periodAnimation = CurvedAnimation(
      parent: _periodController,
      curve: Curves.easeOutCubic,
    );

    void refresh() => setState(() {});
    _entranceController.addListener(refresh);
    _periodController.addListener(refresh);
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  SpendingPeriodData get _period =>
      widget.periods[_periodIndex.clamp(0, widget.periods.length - 1)];

  List<double> _amountsFor(int period) {
    if (widget.periods.isEmpty) return const [];
    return widget.periods[period.clamp(0, widget.periods.length - 1)].amounts;
  }

  List<double> _sharesFor(int period) {
    final amounts = _amountsFor(period);
    final total = amounts.fold<double>(0, (sum, v) => sum + v);
    return amounts
        .map((v) => total > 0 ? v / total : 0.0)
        .toList(growable: false);
  }

  /// 当前动画插值后的分类占比
  List<double> _currentShares() {
    final to = _sharesFor(_periodIndex);
    final t = _periodAnimation.value;
    return List<double>.generate(to.length, (i) {
      final from = i < _fromShares.length ? _fromShares[i] : 0.0;
      return from + (to[i] - from) * t;
    });
  }

  /// 归一化为和为 100 的整数百分比（差值补给最大项）
  static List<int> normalizePercents(List<double> shares) {
    if (shares.isEmpty) return const [];
    final pcts = shares.map((s) => (s * 100).round()).toList();
    var diff = 100 - pcts.fold<int>(0, (sum, v) => sum + v);
    if (diff != 0) {
      var maxIdx = 0;
      for (int i = 1; i < shares.length; i++) {
        if (shares[i] > shares[maxIdx]) maxIdx = i;
      }
      pcts[maxIdx] = math.max(1, pcts[maxIdx] + diff);
    }
    return pcts;
  }

  /// 金额拆为整数段（'$3,480'）与小数段（'.00'）
  (String, String) _splitCurrency(double amount) {
    final fixed = amount.toStringAsFixed(2);
    final dotIdx = fixed.indexOf('.');
    final whole = fixed.substring(0, dotIdx);
    final cents = fixed.substring(dotIdx);
    final buf = StringBuffer(widget.currencySymbol);
    for (int i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buf.write(whole[i]);
      if (remaining > 1 && (remaining - 1) % 3 == 0) buf.write(',');
    }
    return (buf.toString(), cents);
  }

  void _onPeriodSelected(int index) {
    setState(() => _menuOpen = false);
    if (index == _periodIndex) return;
    setState(() {
      _fromShares = _currentShares();
      _periodIndex = index;
    });
    _periodController.forward(from: 0);
    widget.onPeriodChanged?.call(index);
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF0E9EBF0), Color(0xEBDFE2E8)],
          ),
          borderRadius: BorderRadius.circular(36 * s),
          border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D3444).withOpacity(0.16),
              blurRadius: 48 * s,
              offset: Offset(0, 24 * s),
              spreadRadius: -12 * s,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6 * s,
              offset: Offset(0, 2 * s),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36 * s),
          child: _buildBody(s),
        ),
      ),
    );
  }

  Widget _buildBody(double s) {
    final shares = _currentShares();
    final pcts = normalizePercents(shares);

    // 矮尺寸：仅甜甜圈图 + 内圆中心总额
    if (widget.size is SmallSize ||
        widget.size is MediumSize ||
        widget.size is WideSize) {
      final (whole, cents) = _splitCurrency(_period.total);
      return CustomPaint(
        size: Size.infinite,
        painter: _ClippedDonutPainter(
          shares: shares,
          percents: pcts,
          colors: widget.categories.map((c) => c.color).toList(),
          progress: _entrance.value,
          highlightIndex: _highlightIndex,
          centerWhole: whole,
          centerCents: cents,
        ),
      );
    }

    // 甜甜圈图为整卡背景层（右缘被卡片平切）
    final chart = CustomPaint(
      size: Size.infinite,
      painter: _ClippedDonutPainter(
        shares: shares,
        percents: pcts,
        colors: widget.categories.map((c) => c.color).toList(),
        progress: _entrance.value,
        highlightIndex: _highlightIndex,
      ),
    );

    return Stack(
      children: [
        Positioned.fill(child: chart),
        Padding(
          padding: EdgeInsets.all(24 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(s),
              SizedBox(height: 8 * s),
              _buildTotalBlock(s),
              SizedBox(height: 12 * s),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.58,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _buildCategoryRows(s, pcts),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 周期下拉菜单
        if (_menuOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _menuOpen = false),
              child: const SizedBox.shrink(),
            ),
          ),
          Positioned(top: 48 * s, right: 20 * s, child: _buildPeriodMenu(s)),
        ],
      ],
    );
  }

  /// 头部：标题 + 周期下拉按钮
  Widget _buildHeader(double s) {
    final hasMenu = widget.periods.length > 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            color: const Color(0xFF666970),
            fontSize: 16.5 * s,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.01 * 16.5 * s,
            height: 1.0,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: hasMenu ? () => setState(() => _menuOpen = !_menuOpen) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 2 * s),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _period.label,
                  style: TextStyle(
                    color: const Color(0xFF666970),
                    fontSize: 16 * s,
                    fontWeight: FontWeight.w400,
                    height: 1.0,
                  ),
                ),
                if (hasMenu) ...[
                  SizedBox(width: 6 * s),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _menuOpen ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 16 * s,
                      color: const Color(0xFF666970),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 大号总额 + 趋势行
  Widget _buildTotalBlock(double s) {
    final (whole, cents) = _splitCurrency(_period.total);
    final trendColor =
        _period.trendUp ? const Color(0xFF148550) : const Color(0xFFD64545);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: whole,
                style: TextStyle(
                  color: const Color(0xFF111317),
                  fontSize: 42 * s,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.02 * 42 * s,
                  height: 1.08,
                ),
              ),
              TextSpan(
                text: cents,
                style: TextStyle(
                  color: const Color(0xFF6D7078),
                  fontSize: 42 * s,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.02 * 42 * s,
                  height: 1.08,
                ),
              ),
            ],
          ),
        ),
        if (_period.trendText.isNotEmpty) ...[
          SizedBox(height: 6 * s),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _period.trendUp ? Icons.trending_up : Icons.trending_down,
                size: 15 * s,
                color: trendColor,
              ),
              SizedBox(width: 6 * s),
              Text(
                _period.trendText,
                style: TextStyle(
                  color: trendColor,
                  fontSize: 13.5 * s,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
              SizedBox(width: 5 * s),
              Flexible(
                child: Text(
                  widget.compareLabel,
                  style: TextStyle(
                    color: const Color(0xFF696C73),
                    fontSize: 13.5 * s,
                    fontWeight: FontWeight.w400,
                    height: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _buildCategoryRows(double s, List<int> pcts) {
    final amounts = _amountsFor(_periodIndex);
    final rows = <Widget>[];

    for (int i = 0; i < widget.categories.length; i++) {
      final category = widget.categories[i];
      final amount = i < amounts.length ? amounts[i] : 0.0;
      final pct = i < pcts.length ? pcts[i] : 0;
      final (whole, cents) = _splitCurrency(amount);
      final dimmed = _highlightIndex != null && _highlightIndex != i;

      if (i > 0) rows.add(SizedBox(height: 16 * s));

      rows.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onCategoryTap(i),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: dimmed ? 0.45 : 1.0,
            child: Row(
              children: [
                // 圆形图标徽章
                Container(
                  width: 48 * s,
                  height: 48 * s,
                  decoration: BoxDecoration(
                    color: const Color(0xB8F4F5F8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 3 * s,
                        offset: Offset(0, 1 * s),
                      ),
                    ],
                  ),
                  child: Icon(
                    category.icon,
                    size: 22 * s,
                    color: category.color,
                  ),
                ),
                SizedBox(width: 14 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${category.label} '),
                            TextSpan(
                              text: '($pct%)',
                              style: const TextStyle(
                                color: Color(0xFF888B93),
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          color: const Color(0xFF70737B),
                          fontSize: 13 * s,
                          fontWeight: FontWeight.w400,
                          height: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: 4 * s),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: whole,
                              style: TextStyle(
                                color: const Color(0xFF141619),
                                fontSize: 21 * s,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.02 * 21 * s,
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: cents,
                              style: TextStyle(
                                color: const Color(0xFF797C84),
                                fontSize: 21 * s,
                                fontWeight: FontWeight.w300,
                                letterSpacing: -0.02 * 21 * s,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
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

  /// 周期下拉菜单
  Widget _buildPeriodMenu(double s) {
    return Container(
      width: 144 * s,
      padding: EdgeInsets.symmetric(vertical: 6 * s),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24 * s,
            offset: Offset(0, 8 * s),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.periods.length, (i) {
          final selected = i == _periodIndex;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onPeriodSelected(i),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: 14 * s,
                vertical: 7 * s,
              ),
              child: Text(
                widget.periods[i].label,
                style: TextStyle(
                  color:
                      selected
                          ? const Color(0xFF5B50E6)
                          : const Color(0xFF373A40),
                  fontSize: 13.5 * s,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 右缘平切甜甜圈绘制器
///
/// 角度约定（顺时针）：0° = 正上方，90° = 正右方（被竖直平面裁切），
/// 180° = 正下方，270° = 正左方（可见弧区中心）。
/// 沿弧顺序为分类列表逆序：首段（底部）与末段（顶部）外凸并在
/// x = 卡片右缘处垂直平切，中间段使用基础半径。
class _ClippedDonutPainter extends CustomPainter {
  final List<double> shares;
  final List<int> percents;
  final List<Color> colors;

  /// 入场生长进度 0..1
  final double progress;
  final int? highlightIndex;

  /// 内圆中心总额（矮尺寸模式；null 不绘制）
  final String? centerWhole;
  final String? centerCents;

  _ClippedDonutPainter({
    required this.shares,
    required this.percents,
    required this.colors,
    required this.progress,
    required this.highlightIndex,
    this.centerWhole,
    this.centerCents,
  });

  // 几何配置（基于 404×374 设计稿，按卡片宽度缩放）
  static const _arcStartDeg = 155.0;
  static const _arcEndDeg = 401.0;
  static const _minFirstEndDeg = 168.0; // 保证首段外弧始终不越过右缘平面
  static const _maxLastStartDeg = 372.0; // 保证末段外弧始终不越过右缘平面
  static const _labelSafeMinDeg = 170.0;
  static const _labelSafeMaxDeg = 362.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (shares.isEmpty) return;
    final k = size.width / 404;
    final planeX = size.width;
    final cx = size.width - 40 * k;
    final cy = 222 / 374 * size.height;
    final rInner = 50 * k;
    final rBase = 115 * k;
    final rPop = 128 * k;
    final n = shares.length;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // 内圆凹陷底井
    canvas.drawCircle(
      Offset(cx, cy),
      rInner,
      Paint()..color = const Color(0xC7CFD3DC),
    );

    // 沿弧边界（含入场生长），首/末段边界做平切保护钳制
    final span = _arcEndDeg - _arcStartDeg;
    final boundaries = <double>[_arcStartDeg];
    var cursor = _arcStartDeg;
    for (int j = 0; j < n - 1; j++) {
      // 沿弧顺序 = 分类列表逆序
      final share = shares[n - 1 - j];
      cursor += span * share;
      var b = cursor;
      if (j == 0) b = math.max(_minFirstEndDeg, b);
      if (j == n - 2) b = math.min(_maxLastStartDeg, b);
      boundaries.add(b);
    }
    boundaries.add(_arcEndDeg);
    final grown =
        boundaries
            .map((b) => _arcStartDeg + (b - _arcStartDeg) * progress)
            .toList();

    // 扇区描述（沿弧顺序）
    // 平切段在入场生长期间先以径向边收敛，结束时才落到右缘竖直平面
    final naturalFlatStartDeg =
        180 - math.asin((40 * k / rInner).clamp(-1.0, 1.0)) * 180 / math.pi;
    final naturalFlatEndDeg =
        360 + math.asin((40 * k / rInner).clamp(-1.0, 1.0)) * 180 / math.pi;
    final growing = progress < 0.999;
    final flatStartOverride =
        growing
            ? _arcStartDeg + (naturalFlatStartDeg - _arcStartDeg) * progress
            : null;
    final flatEndOverride =
        growing
            ? _arcEndDeg + (naturalFlatEndDeg - _arcEndDeg) * progress
            : null;

    final slices = <_SliceDesc>[];
    for (int j = 0; j < n; j++) {
      final categoryIndex = n - 1 - j;
      final isFirst = j == 0;
      final isLast = j == n - 1;
      final popped = isFirst || isLast;
      slices.add(
        _SliceDesc(
          categoryIndex: categoryIndex,
          startDeg: grown[j],
          endDeg: grown[j + 1],
          rOuter: popped ? rPop : rBase,
          flatRightStart: isFirst,
          flatRightEnd: isLast,
          flatStartDegOverride: isFirst ? flatStartOverride : null,
          flatEndDegOverride: isLast ? flatEndOverride : null,
          startCornerRadius: isLast && n > 1 ? 8 * k : 0,
          endCornerRadius: isFirst && n > 1 ? 8 * k : 0,
          popped: popped,
        ),
      );
    }

    // 先画基础段，再画外凸段（带投影）
    for (final popped in [false, true]) {
      for (final slice in slices) {
        if (slice.popped != popped) continue;
        if (slice.endDeg - slice.startDeg < 1) continue;
        final path = _slicePath(
          cx: cx,
          cy: cy,
          rInner: rInner,
          rOuter: slice.rOuter,
          startDeg: slice.startDeg,
          endDeg: slice.endDeg,
          startCornerRadius: slice.startCornerRadius,
          endCornerRadius: slice.endCornerRadius,
          flatRightStart: slice.flatRightStart,
          flatRightEnd: slice.flatRightEnd,
          flatStartDegOverride: slice.flatStartDegOverride,
          flatEndDegOverride: slice.flatEndDegOverride,
          planeX: planeX,
        );
        final color = colors[slice.categoryIndex % colors.length];
        final dimmed =
            highlightIndex != null && highlightIndex != slice.categoryIndex;
        final opacity = dimmed ? 0.55 : 1.0;

        if (slice.popped) {
          // 外凸段：投影 + 对角渐变
          canvas.drawShadow(path, const Color(0xFF1E222D), 2.5, false);
          final lighter = HSLColor.fromColor(
            color,
          ).withLightness(
            (HSLColor.fromColor(color).lightness + 0.04).clamp(0.0, 1.0),
          ).toColor();
          canvas.drawPath(
            path,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  lighter.withOpacity(opacity),
                  color.withOpacity(opacity),
                ],
              ).createShader(Offset.zero & size),
          );
        } else {
          // 基础段：纯色 + 斜纹质感
          canvas.drawPath(path, Paint()..color = color.withOpacity(opacity));
          canvas.save();
          canvas.clipPath(path);
          canvas.translate(cx, cy);
          canvas.rotate(42 * math.pi / 180);
          final stripePaint =
              Paint()
                ..color = Colors.white.withOpacity(0.085 * opacity)
                ..strokeWidth = 2.6 * k;
          final extent = rBase * 2.2;
          for (double x = -extent; x <= extent; x += 7 * k) {
            canvas.drawLine(Offset(x, -extent), Offset(x, extent), stripePaint);
          }
          canvas.restore();
        }
      }
    }

    // 百分比标签（锁定在左侧可见弧区）
    for (final slice in slices) {
      final spanDeg = slice.endDeg - slice.startDeg;
      if (spanDeg < 16) continue; // 扇区过小不标注，防止重叠
      final pct =
          slice.categoryIndex < percents.length
              ? percents[slice.categoryIndex]
              : 0;
      final midDeg = (slice.startDeg + slice.endDeg) / 2;
      final safeMidDeg = midDeg.clamp(_labelSafeMinDeg, _labelSafeMaxDeg);
      final labelRadius = (rInner + slice.rOuter) / 2 - 2 * k;
      final rad = safeMidDeg * math.pi / 180;
      final pos = Offset(
        math.min(cx + labelRadius * math.sin(rad), 370 * k),
        cy - labelRadius * math.cos(rad),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: '($pct%)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5 * k,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.01 * 13.5 * k,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        pos - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    // 内圆中心总额（按可见底井区域居中：左界 cx - rInner，右界右缘平面）
    if (centerWhole != null) {
      final centerX = (cx - rInner + planeX) / 2;
      final centerText = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: centerWhole,
              style: TextStyle(
                color: const Color(0xFF111317),
                fontSize: rInner * 0.34,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.02 * rInner * 0.34,
                height: 1.0,
              ),
            ),
            if (centerCents != null)
              TextSpan(
                text: centerCents,
                style: TextStyle(
                  color: const Color(0xFF6D7078),
                  fontSize: rInner * 0.28,
                  fontWeight: FontWeight.w300,
                  height: 1.0,
                ),
              ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      centerText.paint(
        canvas,
        Offset(centerX, cy) -
            Offset(centerText.width / 2, centerText.height / 2),
      );
    }

    canvas.restore();
  }

  /// 生成甜甜圈扇区路径（右缘边界可被 x = planeX 的竖直平面平切，
  /// 与基础段相邻的外角使用二次贝塞尔圆角过渡）
  static Path _slicePath({
    required double cx,
    required double cy,
    required double rInner,
    required double rOuter,
    required double startDeg,
    required double endDeg,
    double startCornerRadius = 0,
    double endCornerRadius = 0,
    bool flatRightStart = false,
    bool flatRightEnd = false,
    double? flatStartDegOverride,
    double? flatEndDegOverride,
    required double planeX,
  }) {
    final dx = planeX - cx;

    Offset polar(double r, double deg) {
      final rad = deg * math.pi / 180;
      return Offset(cx + r * math.sin(rad), cy - r * math.cos(rad));
    }

    // 1. 内/外起点（平面平切、生长过渡径向边或径向角）
    Offset pInnerStart, pOuterStart;
    double effectiveOuterStartDeg;
    if (flatRightStart && flatStartDegOverride == null) {
      // 与竖直线 x = planeX 的右下交点
      final innerDeg =
          180 - math.asin((dx / rInner).clamp(-1.0, 1.0)) * 180 / math.pi;
      final outerDeg =
          180 - math.asin((dx / rOuter).clamp(-1.0, 1.0)) * 180 / math.pi;
      pInnerStart = Offset(
        planeX,
        cy + math.sqrt(math.max(0, rInner * rInner - dx * dx)),
      );
      pOuterStart = Offset(
        planeX,
        cy + math.sqrt(math.max(0, rOuter * rOuter - dx * dx)),
      );
      effectiveOuterStartDeg = outerDeg;
      startDeg = innerDeg;
    } else if (flatRightStart) {
      // 入场生长过渡：径向边收敛中，尚未落到平面
      startDeg = flatStartDegOverride!;
      effectiveOuterStartDeg = flatStartDegOverride;
      pInnerStart = polar(rInner, flatStartDegOverride);
      pOuterStart = polar(rOuter, flatStartDegOverride);
    } else {
      pInnerStart = polar(rInner, startDeg);
      pOuterStart = polar(rOuter, startDeg);
      effectiveOuterStartDeg = startDeg;
    }

    // 2. 内/外终点
    Offset pInnerEnd, pOuterEnd;
    double effectiveOuterEndDeg;
    if (flatRightEnd && flatEndDegOverride == null) {
      // 与竖直线 x = planeX 的右上交点
      final innerDeg =
          360 + math.asin((dx / rInner).clamp(-1.0, 1.0)) * 180 / math.pi;
      final outerDeg =
          360 + math.asin((dx / rOuter).clamp(-1.0, 1.0)) * 180 / math.pi;
      pInnerEnd = Offset(
        planeX,
        cy - math.sqrt(math.max(0, rInner * rInner - dx * dx)),
      );
      pOuterEnd = Offset(
        planeX,
        cy - math.sqrt(math.max(0, rOuter * rOuter - dx * dx)),
      );
      effectiveOuterEndDeg = outerDeg;
      endDeg = innerDeg;
    } else if (flatRightEnd) {
      endDeg = flatEndDegOverride!;
      effectiveOuterEndDeg = flatEndDegOverride;
      pInnerEnd = polar(rInner, flatEndDegOverride);
      pOuterEnd = polar(rOuter, flatEndDegOverride);
    } else {
      pInnerEnd = polar(rInner, endDeg);
      pOuterEnd = polar(rOuter, endDeg);
      effectiveOuterEndDeg = endDeg;
    }

    final outerSpanTotal = math.max(
      1.0,
      effectiveOuterEndDeg - effectiveOuterStartDeg,
    );
    final innerSpanTotal = math.max(1.0, endDeg - startDeg);

    // 外角圆角（平切侧无圆角）
    final maxStartCorner =
        flatRightStart
            ? 0.0
            : math.min(startCornerRadius, (rOuter - rInner) * 0.4);
    final startCornerDeg =
        maxStartCorner > 0
            ? math.min(
              outerSpanTotal * 0.32,
              (maxStartCorner / rOuter) * (180 / math.pi),
            )
            : 0.0;
    final maxEndCorner =
        flatRightEnd
            ? 0.0
            : math.min(endCornerRadius, (rOuter - rInner) * 0.4);
    final endCornerDeg =
        maxEndCorner > 0
            ? math.min(
              outerSpanTotal * 0.32,
              (maxEndCorner / rOuter) * (180 / math.pi),
            )
            : 0.0;

    final path = Path()..moveTo(pInnerStart.dx, pInnerStart.dy);

    // 起始边（内圈 -> 外弧起点）
    var arcStartAngle = effectiveOuterStartDeg;
    if (startCornerDeg > 0.2) {
      final pRadialStart = polar(
        rOuter - maxStartCorner,
        effectiveOuterStartDeg,
      );
      final pCornerStartCtrl = polar(rOuter, effectiveOuterStartDeg);
      arcStartAngle = effectiveOuterStartDeg + startCornerDeg;
      final pArcStart = polar(rOuter, arcStartAngle);
      path.lineTo(pRadialStart.dx, pRadialStart.dy);
      path.quadraticBezierTo(
        pCornerStartCtrl.dx,
        pCornerStartCtrl.dy,
        pArcStart.dx,
        pArcStart.dy,
      );
    } else {
      path.lineTo(pOuterStart.dx, pOuterStart.dy);
    }

    // 外弧 + 末端圆角
    final arcEndAngle = effectiveOuterEndDeg - endCornerDeg;
    final actualOuterArcSpan = math.max(0.1, arcEndAngle - arcStartAngle);
    if (endCornerDeg > 0.2) {
      final pArcEnd = polar(rOuter, arcEndAngle);
      final pCornerEndCtrl = polar(rOuter, effectiveOuterEndDeg);
      final pRadialEnd = polar(rOuter - maxEndCorner, effectiveOuterEndDeg);
      path.arcToPoint(
        pArcEnd,
        radius: Radius.circular(rOuter),
        largeArc: actualOuterArcSpan > 180,
        clockwise: true,
      );
      path.quadraticBezierTo(
        pCornerEndCtrl.dx,
        pCornerEndCtrl.dy,
        pRadialEnd.dx,
        pRadialEnd.dy,
      );
      path.lineTo(pInnerEnd.dx, pInnerEnd.dy);
    } else {
      // 外弧直达终点（平切时终点在 x = planeX），再竖直连到内圈
      path.arcToPoint(
        pOuterEnd,
        radius: Radius.circular(rOuter),
        largeArc: actualOuterArcSpan > 180,
        clockwise: true,
      );
      path.lineTo(pInnerEnd.dx, pInnerEnd.dy);
    }

    // 内弧返回起点
    path.arcToPoint(
      pInnerStart,
      radius: Radius.circular(rInner),
      largeArc: innerSpanTotal > 180,
      clockwise: false,
    );
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _ClippedDonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.highlightIndex != highlightIndex ||
        oldDelegate.centerWhole != centerWhole ||
        oldDelegate.centerCents != centerCents ||
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

/// 沿弧扇区描述
class _SliceDesc {
  final int categoryIndex;
  final double startDeg;
  final double endDeg;
  final double rOuter;
  final bool flatRightStart;
  final bool flatRightEnd;
  final double? flatStartDegOverride;
  final double? flatEndDegOverride;
  final double startCornerRadius;
  final double endCornerRadius;
  final bool popped;

  const _SliceDesc({
    required this.categoryIndex,
    required this.startDeg,
    required this.endDeg,
    required this.rOuter,
    required this.flatRightStart,
    required this.flatRightEnd,
    this.flatStartDegOverride,
    this.flatEndDegOverride,
    required this.startCornerRadius,
    required this.endCornerRadius,
    required this.popped,
  });
}

/// 支出分类数据模型
class SpendingCategoryData {
  /// 分类名称（如 'Food'）
  final String label;

  /// 图标
  final IconData icon;

  /// 颜色（甜甜圈扇区 + 图标共用）
  final Color color;

  const SpendingCategoryData({
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// 周期数据集模型
class SpendingPeriodData {
  /// 周期标签（如 'This month'）
  final String label;

  /// 周期总支出（如 3480.00）
  final double total;

  /// 趋势文本（如 '5.1%'），为空时隐藏趋势行
  final String trendText;

  /// 趋势方向（true 上升绿色，false 下降红色）
  final bool trendUp;

  /// 各分类金额（与 categories 对齐，甜甜圈占比由其归一化）
  final List<double> amounts;

  const SpendingPeriodData({
    required this.label,
    required this.total,
    this.trendText = '',
    this.trendUp = true,
    required this.amounts,
  });
}
