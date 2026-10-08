import 'package:flutter/widgets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 日期卡片通用头部
///
/// 供各插件按日期聚合的日卡复用：左侧周几+日期，
/// 右侧可选摘要文本、计数徽标和＋新建按钮。
/// 视觉与待办日卡（TodoDayCard）头部保持一致。
class DayCardHeader extends StatelessWidget {
  /// 主题色（头部背景/文字由此派生）
  final Color color;

  /// 卡片对应日期
  final DateTime date;

  /// 计数徽标（null 时不显示）
  final int? count;

  /// 右侧摘要文本（如收支汇总，null 时不显示）
  final String? summary;

  /// ＋新建回调（null 时不显示按钮）
  final VoidCallback? onAdd;

  const DayCardHeader({
    super.key,
    required this.color,
    required this.date,
    this.count,
    this.summary,
    this.onAdd,
  });

  static const List<String> _dayNames = [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final titleColor = theme.isDark ? color.withOpacity(0.8) : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dayNames[date.weekday - 1],
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '${date.month}/${date.day}',
                style: TextStyle(color: theme.textSub, fontSize: 11),
              ),
            ],
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (summary != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 6),
                      child: Text(
                        summary!,
                        style: TextStyle(color: titleColor, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (count != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (onAdd != null)
                  GestureDetector(
                    onTap: onAdd,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: DsIcon(
                        DsIconKind.plus,
                        size: 18,
                        color: titleColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
