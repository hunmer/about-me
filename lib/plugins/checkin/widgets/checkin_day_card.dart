import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/widgets/day_card_header.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';

/// 签到单日卡片 - 展示某一天各签到项的签到状态
///
/// 供主页签到日卡使用：点击签到项即切换该日的签到状态（与插件页一致）。
/// [items] 应为该日排班的签到项，[recordsFor] 提供各项当日的记录。
class CheckinDayCard extends StatelessWidget {
  /// 卡片对应的日期
  final DateTime date;

  /// 该日排班的签到项
  final List<CheckinItem> items;

  /// 点击签到项回调（切换该日签到状态）
  final Function(CheckinItem item) onItemTap;

  /// 头部主题色
  final Color color;

  const CheckinDayCard({
    super.key,
    required this.date,
    required this.items,
    required this.onItemTap,
    this.color = Colors.teal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final checkedCount = items.where(_isChecked).length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DayCardHeader(
              color: color,
              date: date,
              count: items.isEmpty ? null : checkedCount,
              summary: items.isEmpty ? null : '$checkedCount/${items.length}',
            ),
            Expanded(
              child:
                  items.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DsIcon(
                              DsIconKind.check,
                              size: 32,
                              color: theme.textSub.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'checkin_dayCardEmpty'.tr,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
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
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _buildItemRow(context, items[index]);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// 该项在卡片日期当天是否已签到
  bool _isChecked(CheckinItem item) {
    return item.getDateRecords(date).isNotEmpty;
  }

  /// 单条签到项行：图标 + 名称 + 签到状态
  Widget _buildItemRow(BuildContext context, CheckinItem item) {
    final theme = DSThemeBridge.resolve(context);
    final checked = _isChecked(item);
    final recordCount = item.getDateRecords(date).length;

    return InkWell(
      onTap: () => onItemTap(item),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: item.color.withValues(alpha: 0.2),
              child: Icon(item.icon, size: 16, color: item.color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.name,
                style: DsTypography.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: checked ? theme.text : theme.textSub,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (checked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: item.color.withValues(alpha: 0.2),
                  radius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DsIcon(DsIconKind.check, size: 12, color: item.color),
                    if (recordCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          '$recordCount',
                          style: DsTypography.caption.copyWith(
                            fontSize: 11,
                            color: item.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                size: 16,
                color: theme.textSub.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}
