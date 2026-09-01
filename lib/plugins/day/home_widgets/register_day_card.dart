/// 纪念日插件 - 纪念日日卡小组件注册（按日期聚合）
///
/// 展示主页选中日当天到期的纪念日（倒计时天数）；
/// hasDateData 语义 = 当天有纪念日（严格同日，"临近 N 天"策略后续可扩展）。
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/home_screen/widgets/day_card_header.dart';
import 'package:aboutme/widgets/event_listener_container.dart';
import 'package:aboutme/plugins/day/models/memorial_day.dart';
import 'package:aboutme/plugins/day/widgets/memorial_day_edit_flow.dart';

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 获取指定日期到期的纪念日（重读存储保证与插件页一致）
Future<List<MemorialDay>> _memorialsForDate(DateTime date) async {
  final controller = sharedDayController();
  await controller.reloadData();
  return controller.memorialDays
      .where((memorial) => _isSameDay(memorial.targetDate, date))
      .toList();
}

/// 注册纪念日日卡小组件（展示主页选中日期到期的纪念日）
void registerDayCardWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'day_day_card',
      pluginId: 'day',
      name: 'day_dayCardName'.tr,
      description: 'day_dayCardDesc'.tr,
      icon: Icons.celebration,
      color: Colors.deepOrange,
      defaultSize: const LargeSize(),
      supportedSizes: const [
        LargeSize(),
        Large3Size(),
        Wide2Size(),
        Wide3Size(),
      ],
      category: 'home_categoryRecord'.tr,
      isDateDriven: true,
      hasDateData: (date) async {
        try {
          return (await _memorialsForDate(date)).isNotEmpty;
        } catch (_) {
          return false;
        }
      },
      builder: (context, config) => const _MemorialDayCardHomeWidget(),
    ),
  );
}

/// 纪念日日卡内容：读取主页选中日期的到期纪念日并渲染
class _MemorialDayCardHomeWidget extends StatefulWidget {
  const _MemorialDayCardHomeWidget();

  @override
  State<_MemorialDayCardHomeWidget> createState() =>
      _MemorialDayCardHomeWidgetState();
}

class _MemorialDayCardHomeWidgetState extends State<_MemorialDayCardHomeWidget> {
  List<MemorialDay> _memorials = [];
  DateTime? _loadingFor;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    HomeDateController().addListener(_loadMemorials);
    _loadMemorials();
  }

  @override
  void dispose() {
    HomeDateController().removeListener(_loadMemorials);
    super.dispose();
  }

  Future<void> _loadMemorials() async {
    final date = HomeDateController().date;
    _loadingFor = date;
    try {
      final memorials = await _memorialsForDate(date);
      if (!mounted || _loadingFor != date) return;
      setState(() {
        _memorials = memorials;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _loadingFor != date) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 注意：不监听 memorial_day_cache_updated（reloadData 会广播它，避免循环刷新）
    return EventListenerContainer(
      events: const [
        'memorial_day_added',
        'memorial_day_updated',
        'memorial_day_deleted',
      ],
      onEvent: _loadMemorials,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final date = HomeDateController().date;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DayCardHeader(
            color: Colors.deepOrange,
            date: date,
            count: _memorials.length,
            onAdd: () => openMemorialDayEditor(
              context,
              prefilled: MemorialDay(title: '', targetDate: date),
            ),
          ),
          Expanded(
            child:
                _memorials.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.celebration_outlined,
                            size: 32,
                            color: theme.disabledColor.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'day_dayCardEmpty'.tr,
                            style: TextStyle(
                              color: theme.disabledColor.withValues(
                                alpha: 0.4,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: _memorials.length,
                      itemBuilder: (context, index) {
                        return _buildMemorialItem(
                          context,
                          _memorials[index],
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  /// 单条纪念日行：图标 + 标题 + 倒计时
  Widget _buildMemorialItem(BuildContext context, MemorialDay memorial) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => openMemorialDayEditor(context, existing: memorial),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: memorial.backgroundColor.withValues(alpha: 0.2),
              child:
                  memorial.icon != null
                      ? Icon(
                        memorial.icon,
                        size: 16,
                        color: memorial.iconColor ?? memorial.backgroundColor,
                      )
                      : Text(
                        memorial.title.isNotEmpty ? memorial.title[0] : '纪',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              memorial.iconColor ?? memorial.backgroundColor,
                        ),
                      ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                memorial.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _countdownText(memorial),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: _countdownColor(context, memorial),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 倒计时文本（今天/还剩N天/已过N天，与插件一致）
  String _countdownText(MemorialDay memorial) {
    if (memorial.isToday) return 'day_daysRemaining_zero'.tr;
    if (memorial.isExpired) {
      return 'day_daysPassed'.trParams({'count': '${memorial.daysPassed}'});
    }
    return 'day_daysRemaining'.trParams({
      'count': '${memorial.daysRemaining}',
    });
  }

  Color _countdownColor(BuildContext context, MemorialDay memorial) {
    if (memorial.isToday) return Colors.deepOrange;
    if (memorial.isExpired) {
      return Theme.of(context).disabledColor;
    }
    return Theme.of(context).colorScheme.primary;
  }
}
