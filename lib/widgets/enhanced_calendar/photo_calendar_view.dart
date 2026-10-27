import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skribble/skribble.dart';

/// 照片日历某天的展示信息（标题 + 首图路径）
class PhotoCalendarDayInfo {
  final String title;
  final String? imagePath;

  const PhotoCalendarDayInfo({required this.title, this.imagePath});
}

/// 照片日历视图：垂直滚动的月份列表，每天格子以拍立得样式展示首图 + 日期角标
/// （白色圆角边框、轻微倾斜），与业务数据解耦：
/// - [dayInfoBuilder] 按月提供每天的数据（组件内部按月缓存）
/// - [dataListenable] 变化时自动清空缓存重新构建
class PhotoCalendarView extends StatefulWidget {
  /// 按月构建每天展示信息，key 为日期(年月日)，只返回该月有数据的日期
  final Map<DateTime, PhotoCalendarDayInfo> Function(DateTime month)
  dayInfoBuilder;

  /// 数据源监听（如 ChangeNotifier），变化时清空缓存
  final Listenable? dataListenable;

  /// 选中的日期
  final DateTime? selectedDate;

  /// 日期点击回调
  final ValueChanged<DateTime>? onDateSelected;

  /// 月份标题点击回调
  final ValueChanged<DateTime>? onHeaderTapped;

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
    this.onHeaderTapped,
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

  /// 每行统一行高（有图片的行高；无图片的行留白保持同高）
  static const double _photoRowHeight = 132;

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
    if (oldWidget.dataListenable != widget.dataListenable) {
      oldWidget.dataListenable?.removeListener(_onDataChanged);
      widget.dataListenable?.addListener(_onDataChanged);
      _onDataChanged();
    } else if (oldWidget.dayInfoBuilder != widget.dayInfoBuilder) {
      _onDataChanged();
    }
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {
        _cachedDayData.clear();
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _imageFallback(AppThemeData theme) => Container(
    width: 36,
    height: 36,
    color: theme.surfaceAlt,
    child: DsIcon(DsIconKind.image, size: 16, color: theme.textSub),
  );

  /// 首图缩略图：白底 + 左右随机小角度倾斜（拍立得效果）。
  /// 倾斜角按日期哈希稳定取值，同一格 rebuild 不抖变
  Widget _buildTiltedImage(
    String imagePath,
    DateTime day,
    AppThemeData theme,
  ) => _buildTiledSlot(
    // Web/远端存储下 File 路径不可用，统一走 createImageProvider
    // （内部按 network/asset/file/存储分发，含 StorageImageProvider 解密）
    Image(
      image: ImageUtils.createImageProvider(imagePath),
      width: 36,
      height: 36,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _imageFallback(theme),
    ),
    day,
    theme,
  );

  /// 有数据但无图时的占位：同样走拍立得墨盒外框，中间为图片图标
  Widget _buildTiledPlaceholder(DateTime day, AppThemeData theme) =>
      _buildTiledSlot(_imageFallback(theme), day, theme);

  Widget _buildTiledSlot(Widget child, DateTime day, AppThemeData theme) {
    const tilts = [-0.10, -0.05, 0.05, 0.10];
    final angle = tilts[(day.day * 31 + day.month * 7) % tilts.length];
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.all(2),
        // 纯色实底白边，无描边
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(6), child: child),
      ),
    );
  }

  Widget _buildMonthGrid(DateTime month) {
    final theme = DSThemeBridge.resolve(context);
    final dayData = _getMonthDayData(month);
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // 周日开头，与 SyncfusionCalendarWidget（firstDayOfWeek=7）一致
    final leadingBlanks = firstDay.weekday % 7;

    // 按周分行；所有行统一行高，无图片的格子留白不缩行
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

    Widget buildDayCell(DateTime day, PhotoCalendarDayInfo? info) {
      final isToday = _isSameDay(day, DateTime.now());
      final isSelected =
          widget.selectedDate != null &&
          _isSameDay(day, widget.selectedDate!);

      return SizedBox(
        height: _photoRowHeight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onDateSelected?.call(day),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
            child: Column(
              children: [
                // 顶部区域始终占满剩余高度：无数据时留空占位，保证日期固定贴底
                Expanded(
                  child: (info != null)
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: info.imagePath != null
                              ? _buildTiltedImage(info.imagePath!, day, theme)
                              : _buildTiledPlaceholder(day, theme),
                        )
                      : const SizedBox.shrink(),
                ),
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: isToday
                      ? BoxDecoration(color: theme.text, shape: BoxShape.circle)
                      : isSelected
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.primary, width: 1.5),
                        )
                      : null,
                  child: Text(
                    '${day.day}',
                    style: DsTypography.caption.copyWith(
                      color: isToday ? theme.surface : theme.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final weekdayLabels =
        widget.weekdayLabels ?? const ['日', '一', '二', '三', '四', '五', '六'];
    final monthTitle =
        widget.monthTitleBuilder?.call(month) ??
        DateFormat('yyyy年MM月').format(month);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // 挂载即描画入场：墨线 + 贴纸一起动画（与垂直视图一致）
      child: WiredDraw(
        child: Builder(
          builder: (context) {
            final progress = WiredDrawTransition.progressOf(context);
            // 大容器走手绘面板：纸底 + 淡排线 + 墨线框（与垂直视图一致）
            return DsSketchPanel(
              theme: theme,
              radius: theme.radii.xl,
              padding: const EdgeInsets.all(8),
              seed: month.year * 12 + month.month,
              progress: progress,
              // 相机贴纸：压在边框右上角外侧，小倾斜增加手账感
              stickers: const [
                DsSketchSticker(
                  alignment: Alignment.topRight,
                  offset: Offset(10, -30),
                  size: 52,
                  rotation: 0.18,
                  svg: 'assets/icons/svg/camera.svg',
                ),
              ],
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onHeaderTapped?.call(month),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          monthTitle,
                          style: DsTypography.heading.copyWith(
                            color: theme.text,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: weekdayLabels
                        .map(
                          (label) => Expanded(
                            child: Center(
                              child: Text(
                                label,
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  for (final row in rows)
                    Row(
                      children: [
                        for (final day in row)
                          Expanded(
                            child: day == null
                                ? const SizedBox(height: _photoRowHeight)
                                : buildDayCell(day, dayData[day]),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: KeyedSubtree(
                      key: ValueKey('photo_${_getMonthKey(month)}'),
                      child: _buildMonthGrid(month),
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
