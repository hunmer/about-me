import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/home_date_controller.dart';

/// 主页日期横条
///
/// 横向展示今天前后一段日期，点击切换主页当前选中日期，
/// 所有按日期聚合的卡片（待办日卡、日记日卡等）会自动跟随刷新。
///
/// 选中的日期统一存放在 [HomeDateController]，卡片自身不提供切换。
class HomeDateBar extends StatefulWidget {
  const HomeDateBar({super.key});

  @override
  State<HomeDateBar> createState() => _HomeDateBarState();
}

class _HomeDateBarState extends State<HomeDateBar> {
  static const int _pastDays = 7;
  static const int _futureDays = 21;
  static const double _itemExtent = 56.0;

  static const List<String> _weekdayNames = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  late final List<DateTime> _dates;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _dates = List.generate(
      _pastDays + _futureDays + 1,
      (index) => today.add(Duration(days: index - _pastDays)),
    );
    // 首帧后把今天滚动到可视区中间偏左
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollToIndex(_pastDays, animate: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动让指定索引的日期可见（居中）
  void _scrollToIndex(int index, {bool animate = true}) {
    final viewport = _scrollController.position.viewportDimension;
    final target =
        (index * _itemExtent - viewport / 2 + _itemExtent / 2)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateController = HomeDateController();

    return AnimatedBuilder(
      animation: dateController,
      builder: (context, _) {
        final selected = dateController.date;
        final isTodaySelected = dateController.isToday;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _buildTodayChip(context, theme, isTodaySelected),
              const SizedBox(width: 4),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    itemExtent: _itemExtent,
                    itemCount: _dates.length,
                    itemBuilder: (context, index) {
                      final date = _dates[index];
                      return _buildDateChip(
                        context,
                        theme,
                        date: date,
                        isSelected: _isSameDay(date, selected),
                        isToday: index == _pastDays,
                        onTap: () {
                          dateController.setDate(date);
                          _scrollToIndex(index);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 「今天」快捷按钮
  Widget _buildTodayChip(
    BuildContext context,
    ThemeData theme,
    bool isTodaySelected,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => HomeDateController().setDate(DateTime.now()),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isTodaySelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          'home_today'.tr,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isTodaySelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 单个日期块
  Widget _buildDateChip(
    BuildContext context,
    ThemeData theme, {
    required DateTime date,
    required bool isSelected,
    required bool isToday,
    required VoidCallback onTap,
  }) {
    final primary = theme.colorScheme.primary;

    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? null
                : Border.all(
                    color: isToday
                        ? primary.withValues(alpha: 0.6)
                        : theme.dividerColor.withValues(alpha: 0.5),
                  ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _weekdayNames[date.weekday - 1],
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: isSelected
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.9)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
