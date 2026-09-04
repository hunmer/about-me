import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';

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

  static const List<String> _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

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
    final target = (index * _itemExtent - viewport / 2 + _itemExtent / 2).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
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
    final dateController = HomeDateController();

    return DSThemeBridge(
      child: AnimatedBuilder(
        animation: dateController,
        builder: (context, _) {
          final theme = DSThemeBridge.resolve(context);
          final selected = dateController.date;
          final isTodaySelected = dateController.isToday;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _buildTodayChip(theme, isTodaySelected),
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
      ),
    );
  }

  /// 「今天」快捷按钮
  Widget _buildTodayChip(AppThemeData theme, bool isTodaySelected) {
    return Pressable(
      onPressed: () => HomeDateController().setDate(DateTime.now()),
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color:
                isTodaySelected
                    ? theme.primary
                    : (pressed ? theme.surfaceAlt : theme.surface),
            borderRadius: theme.radii.md,
            border:
                isTodaySelected
                    ? null
                    : Border.all(color: theme.stroke, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Text(
            'home_today'.tr,
            style: DsTypography.caption.copyWith(
              color: isTodaySelected ? theme.onPrimary : theme.textSub,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  /// 单个日期块
  Widget _buildDateChip(
    AppThemeData theme, {
    required DateTime date,
    required bool isSelected,
    required bool isToday,
    required VoidCallback onTap,
  }) {
    return Center(
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? theme.primary
                      : (pressed ? theme.surfaceAlt : const Color(0x00000000)),
              borderRadius: theme.radii.md,
              border:
                  isSelected
                      ? null
                      : Border.all(
                        color:
                            isToday
                                ? theme.primary.withValues(alpha: 0.6)
                                : theme.stroke.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: DsTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? theme.onPrimary : theme.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _weekdayNames[date.weekday - 1],
                  style: DsTypography.label.copyWith(
                    color:
                        isSelected
                            ? theme.onPrimary.withValues(alpha: 0.9)
                            : theme.textSub,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
