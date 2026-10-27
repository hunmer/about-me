import 'dart:math' as math;

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 照片日历某天的展示信息（标题 + 图片路径列表）
class PhotoCalendarDayInfo {
  final String title;
  final List<String> photos;

  const PhotoCalendarDayInfo({required this.title, this.photos = const []});
}

/// 照片日历视图：垂直滚动的月份列表，样式参考 `PhotoCalendarCard`：
/// - 深色卡片 + 周表头 + 日期数字打底
/// - 有图片的日期展示徽章（白边圆角 + 轻微倾斜 + 阴影），入场时逐日错峰弹出
/// - 点击徽章在日期行上方展开横向图片条（其余格子变暗，当前格显示关闭按钮），
///   点击图片条内图片触发 [onPhotoTap]，点击空白或关闭按钮收起
///
/// 与业务数据解耦：[dayInfoBuilder] 按月提供数据（内部按月缓存），
/// [dataListenable] 变化时自动清空缓存重新构建。
class PhotoCalendarView extends StatefulWidget {
  /// 按月构建每天展示信息，key 为日期(年月日)，只返回该月有数据的日期
  final Map<DateTime, PhotoCalendarDayInfo> Function(DateTime month)
  dayInfoBuilder;

  /// 数据源监听（如 ChangeNotifier），变化时清空缓存
  final Listenable? dataListenable;

  /// 选中的日期（无图日期高亮底、徽章描边）
  final DateTime? selectedDate;

  /// 点击无图片的日期回调
  final ValueChanged<DateTime>? onDateSelected;

  /// 长按任意日期回调（有图片的日期无法点选，通过长按触发选中）
  final ValueChanged<DateTime>? onDayLongPressed;

  /// 月份标题点击回调
  final ValueChanged<DateTime>? onHeaderTapped;

  /// 点击展开图片条中的某张图片
  final void Function(DateTime day, String photo)? onPhotoTap;

  /// 月份标题格式化，默认 `yyyy年MM月`
  final String Function(DateTime month)? monthTitleBuilder;

  /// 星期标题，默认周日开头
  final List<String>? weekdayLabels;

  /// 可加载的最早月份，默认 2010-01
  final DateTime? minMonth;

  /// 滚动到底部时每次追加的月份数
  final int loadBatchSize;

  /// 初始渲染的月份数（从当前月往前）
  final int initialMonthCount;

  const PhotoCalendarView({
    super.key,
    required this.dayInfoBuilder,
    this.dataListenable,
    this.selectedDate,
    this.onDateSelected,
    this.onDayLongPressed,
    this.onHeaderTapped,
    this.onPhotoTap,
    this.monthTitleBuilder,
    this.weekdayLabels,
    this.minMonth,
    this.loadBatchSize = 3,
    this.initialMonthCount = 3,
  });

  @override
  State<PhotoCalendarView> createState() => _PhotoCalendarViewState();
}

class _PhotoCalendarViewState extends State<PhotoCalendarView>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  final List<DateTime> _months = [];
  final Map<String, Map<DateTime, PhotoCalendarDayInfo>> _cachedDayData = {};
  bool _isLoading = false;

  /// 展开图片条的日期（跨月份唯一）
  DateTime? _expandedDay;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeMonths();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    widget.dataListenable?.addListener(_onDataChanged);
  }

  @override
  void didUpdateWidget(PhotoCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 注意：不比较 dayInfoBuilder（调用方每次 build 传新闭包），
    // 数据失效统一走 dataListenable 通知
    if (oldWidget.dataListenable != widget.dataListenable) {
      oldWidget.dataListenable?.removeListener(_onDataChanged);
      widget.dataListenable?.addListener(_onDataChanged);
      _onDataChanged();
    }
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {
        _cachedDayData.clear();
        _expandedDay = null;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    widget.dataListenable?.removeListener(_onDataChanged);
    super.dispose();
  }

  /// 初始化月份列表（从当前月份开始，从大到小显示）
  void _initializeMonths() {
    _months.clear();
    final now = DateTime.now();
    for (int i = 0; i < widget.initialMonthCount; i++) {
      _months.add(DateTime(now.year, now.month - i, 1));
    }
  }

  /// 加载更多月份（向下滚动时加载更早的月份）
  bool _loadMorePreviousMonths() {
    if (_months.isEmpty || _isLoading) return false;

    setState(() => _isLoading = true);

    final addedMonths = <DateTime>[];
    final earliestMonth = _months.last;
    final minMonth = widget.minMonth ?? DateTime(2010, 1, 1);
    var currentMonth = DateTime(earliestMonth.year, earliestMonth.month - 1, 1);

    for (int i = 0; i < widget.loadBatchSize; i++) {
      if (currentMonth.isBefore(minMonth)) break;
      _months.add(currentMonth);
      addedMonths.add(currentMonth);
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
    }

    setState(() => _isLoading = false);

    for (final added in addedMonths) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getMonthDayData(added);
      });
    }

    return addedMonths.isNotEmpty;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoading) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || _isLoading) return;

      const threshold = 200.0;
      final position = _scrollController.position;

      if (position.maxScrollExtent > 0 &&
          (position.maxScrollExtent - position.pixels) <= threshold) {
        _loadMorePreviousMonths();
      }
    });
  }

  String _getMonthKey(DateTime month) {
    return 'photo_${month.year}_${month.month}';
  }

  /// 获取指定月份每天的数据（带缓存）
  Map<DateTime, PhotoCalendarDayInfo> _getMonthDayData(DateTime month) {
    final monthKey = _getMonthKey(month);
    if (_cachedDayData.containsKey(monthKey)) {
      return _cachedDayData[monthKey]!;
    }

    final dayData = widget.dayInfoBuilder(month);
    _cachedDayData[monthKey] = dayData;
    return dayData;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = DSThemeBridge.resolve(context);

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  0,
                  16,
                  0,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: _months.length,
                itemBuilder: (context, index) {
                  final month = _months[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _MonthCard(
                      key: ValueKey('photo_${_getMonthKey(month)}'),
                      month: month,
                      dayData: _getMonthDayData(month),
                      selectedDate: widget.selectedDate,
                      expandedDay: _expandedDay,
                      onExpandedChanged: (day) =>
                          setState(() => _expandedDay = day),
                      onDateSelected: widget.onDateSelected,
                      onDayLongPressed: widget.onDayLongPressed,
                      onHeaderTapped: widget.onHeaderTapped,
                      onPhotoTap: widget.onPhotoTap,
                      monthTitle:
                          widget.monthTitleBuilder?.call(month) ??
                          DateFormat('yyyy年MM月').format(month),
                      weekdayLabels:
                          widget.weekdayLabels ??
                          const ['日', '一', '二', '三', '四', '五', '六'],
                    ),
                  );
                },
              ),
              if (_isLoading)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(child: DSLoadingDots(color: theme.textSub)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 单个月份卡片：深色底 + 日期格子 + 可展开图片条
class _MonthCard extends StatefulWidget {
  final DateTime month;
  final Map<DateTime, PhotoCalendarDayInfo> dayData;
  final DateTime? selectedDate;
  final DateTime? expandedDay;
  final ValueChanged<DateTime?> onExpandedChanged;
  final ValueChanged<DateTime>? onDateSelected;
  final ValueChanged<DateTime>? onDayLongPressed;
  final ValueChanged<DateTime>? onHeaderTapped;
  final void Function(DateTime day, String photo)? onPhotoTap;
  final String monthTitle;
  final List<String> weekdayLabels;

  const _MonthCard({
    super.key,
    required this.month,
    required this.dayData,
    required this.selectedDate,
    required this.expandedDay,
    required this.onExpandedChanged,
    required this.onDateSelected,
    required this.onDayLongPressed,
    required this.onHeaderTapped,
    required this.onPhotoTap,
    required this.monthTitle,
    required this.weekdayLabels,
  });

  @override
  State<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends State<_MonthCard>
    with SingleTickerProviderStateMixin {
  static const _spring = Cubic(0.34, 1.56, 0.64, 1);

  static const double _cellH = 62;
  static const double _rowGap = 10;
  static const double _badgeSize = 58;
  static const double _stripH = 74;
  static const Color _accent = Color(0xFF38BDF8);

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final dayData = widget.dayData;
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // 周日开头，与 SyncfusionCalendarWidget（firstDayOfWeek=7）一致
    final leadingBlanks = firstDay.weekday % 7;

    // 按周分行
    final rows = <List<DateTime?>>[];
    var currentRow = List<DateTime?>.filled(
      leadingBlanks,
      null,
      growable: true,
    );
    for (var day = 1; day <= daysInMonth; day++) {
      currentRow.add(DateTime(month.year, month.month, day));
      if (currentRow.length == 7) {
        rows.add(currentRow);
        currentRow = <DateTime?>[];
      }
    }
    if (currentRow.isNotEmpty) {
      currentRow.addAll(List<DateTime?>.filled(7 - currentRow.length, null));
      rows.add(currentRow);
    }

    // 展开图片条的定位：贴在目标日期所在行上方，从点击列弹出
    final expanded = widget.expandedDay;
    final expandedInfo = expanded == null ? null : dayData[expanded];
    final expandedInMonth =
        expanded != null &&
        expanded.month == month.month &&
        (expandedInfo?.photos.isNotEmpty ?? false);
    double? stripTop;
    if (expandedInMonth) {
      final cellIndex = leadingBlanks + expanded.day - 1;
      stripTop =
          ((cellIndex ~/ 7) * (_cellH + _rowGap) - 76)
              .clamp(-18.0, 9999.0)
              .toDouble();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 60,
            offset: const Offset(0, 30),
            spreadRadius: -15,
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onHeaderTapped?.call(month),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  widget.monthTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF4F4F6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final label in widget.weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A8A8E),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            // 点击空白区域收起图片条
            onTap: () => widget.onExpandedChanged(null),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    for (var r = 0; r < rows.length; r++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final day in rows[r])
                            Expanded(
                              child: day == null
                                  ? const SizedBox(height: _cellH)
                                  : _buildDayCell(day, dayData[day]),
                            ),
                        ],
                      ),
                      if (r < rows.length - 1)
                        const SizedBox(height: _rowGap),
                    ],
                  ],
                ),
                if (expandedInMonth)
                  Positioned(
                    left: -14,
                    right: -14,
                    top: stripTop,
                    height: _stripH,
                    child: _buildPhotoStrip(expanded, expandedInfo!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime day, PhotoCalendarDayInfo? info) {
    final hasPhotos = (info?.photos.isNotEmpty) ?? false;
    final isActive = widget.expandedDay != null && _isSameDay(widget.expandedDay!, day);
    final dimByStrip = widget.expandedDay != null && !isActive;
    final isToday = _isSameDay(day, DateTime.now());
    final isSelected =
        widget.selectedDate != null &&
        _isSameDay(widget.selectedDate!, day);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isActive) return;
        if (hasPhotos) {
          widget.onExpandedChanged(day);
        } else {
          widget.onExpandedChanged(null);
          widget.onDateSelected?.call(day);
        }
      },
      onLongPress: () => widget.onDayLongPressed?.call(day),
      child: SizedBox(
        height: _cellH,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: dimByStrip ? 0.26 : 1,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _buildDateNumber(day, hasPhotos, isActive, isToday, isSelected),
              if (hasPhotos)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: isActive ? 0 : 1,
                  child: IgnorePointer(
                    child: _buildEntrance(
                      day: day.day,
                      child: _buildPhotoBadge(day, info!, isSelected),
                    ),
                  ),
                ),
              if (isActive) _buildCloseButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateNumber(
    DateTime day,
    bool covered,
    bool hiddenByStrip,
    bool isToday,
    bool isSelected,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: _spring,
      width: 46,
      height: 46,
      transformAlignment: Alignment.center,
      transform: Matrix4.identity()
        ..scale(covered && !hiddenByStrip ? 0.5 : (isSelected && !covered ? 1.1 : 1.0)),
      decoration: BoxDecoration(
        color: isSelected && !covered
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: hiddenByStrip ? 0 : 1,
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: covered ? 13 : 22,
            fontWeight: covered
                ? FontWeight.w600
                : (isToday || isSelected ? FontWeight.w700 : FontWeight.w400),
            color: covered
                ? Colors.white.withValues(alpha: 0.55)
                : (isToday ? _accent : const Color(0xFFF4F4F6)),
          ),
        ),
      ),
    );
  }

  /// 徽章入场：按日期错峰 弹性淡入 + 上移 + 放大
  Widget _buildEntrance({required int day, required Widget child}) {
    final start = (0.15 + day * 0.02).clamp(0.0, 0.8).toDouble();
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, _) {
        final t = CurvedAnimation(
          parent: _entrance,
          curve: Interval(start, 1, curve: _spring),
        ).value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - t)),
            child: Transform.scale(scale: 0.3 + 0.7 * t, child: child),
          ),
        );
      },
    );
  }

  /// 图片徽章：白边圆角 + 按日期哈希取稳定倾角 + 阴影
  Widget _buildPhotoBadge(
    DateTime day,
    PhotoCalendarDayInfo info,
    bool isSelected,
  ) {
    const tilts = [-6.0, -3.0, 3.0, 6.0];
    final rot = tilts[(day.day * 31 + day.month * 7) % tilts.length];
    return Container(
      width: _badgeSize,
      height: _badgeSize,
      transformAlignment: Alignment.center,
      transform: Matrix4.identity()..rotateZ(rot * math.pi / 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isSelected ? _accent : Colors.white.withValues(alpha: 0.55),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13.5),
        // Web/远端存储下 File 路径不可用，统一走 createImageProvider
        // （内部按 network/asset/file/存储分发，含 StorageImageProvider 解密）
        child: Image(
          image: ImageUtils.createImageProvider(info.photos.first),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF2A2A2E),
            alignment: Alignment.center,
            child: DsIcon(
              DsIconKind.image,
              size: 16,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: () => widget.onExpandedChanged(null),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.close,
          size: 16,
          color: Colors.white70,
        ),
      ),
    );
  }

  /// 展开的横向图片条：贴在目标行上方，从点击列弹性放大弹出
  Widget _buildPhotoStrip(DateTime day, PhotoCalendarDayInfo info) {
    final cellIndex =
        DateTime(day.year, day.month, 1).weekday % 7 + day.day - 1;
    final col = cellIndex % 7;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: _spring,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform(
          alignment: Alignment(((col + 0.5) / 7) * 2 - 1, 1),
          transform: Matrix4.identity()
            ..translate(0.0, 24 * (1 - t))
            ..scale(0.22 + 0.78 * t, 0.5 + 0.5 * t),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF2E2C2A).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.88),
              blurRadius: 50,
              offset: const Offset(0, 26),
              spreadRadius: -10,
            ),
          ],
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: info.photos.length,
          itemBuilder: (context, index) {
            final photo = info.photos[index];
            return GestureDetector(
              onTap: () => widget.onPhotoTap?.call(day, photo),
              child: Container(
                width: _stripH - 12,
                height: _stripH - 12,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image(
                    image: ImageUtils.createImageProvider(photo),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF2A2A2E),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
