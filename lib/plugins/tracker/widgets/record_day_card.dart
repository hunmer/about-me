import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/widgets/day_card_header.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';

/// 追踪单日卡片 - 展示某一天的目标记录
///
/// 供主页追踪日卡使用：目标名/数值/时间，
/// 点击记录进入目标详情（与插件页一致）。
class RecordDayCard extends StatelessWidget {
  /// 卡片对应的日期
  final DateTime date;

  /// 该日的记录列表（由调用方按日期过滤并排序）
  final List<Record> records;

  /// 目标查找表（goalId → Goal）
  final Map<String, Goal> goalById;

  /// 点击记录回调（进入目标详情）
  final Function(Goal goal) onRecordTap;

  /// 新建记录回调，为 null 时不显示 ＋ 按钮
  final VoidCallback? onAddRecord;

  /// 头部主题色
  final Color color;

  const RecordDayCard({
    super.key,
    required this.date,
    required this.records,
    required this.goalById,
    required this.onRecordTap,
    this.onAddRecord,
    this.color = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 过滤掉目标已被删除的记录
    final visible =
        records.where((record) => goalById.containsKey(record.goalId)).toList();

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
            color: color,
            date: date,
            count: visible.length,
            onAdd: onAddRecord,
          ),
          Expanded(
            child:
                visible.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 32,
                            color: theme.disabledColor.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'tracker_dayCardEmpty'.tr,
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
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        return _buildRecordItem(context, visible[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  /// 单条记录行：目标图标 + 目标名/时间 + 数值
  Widget _buildRecordItem(BuildContext context, Record record) {
    final theme = Theme.of(context);
    final goal = goalById[record.goalId]!;

    return InkWell(
      onTap: () => onRecordTap(goal),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            _buildGoalIcon(context, goal),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(record.recordedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.disabledColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${_formatValue(record.value)}${goal.unitType}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: goal.progressColor != null
                    ? Color(goal.progressColor!)
                    : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 目标图标（icon 为 codePoint 字符串，与目标卡片解析方式一致）
  Widget _buildGoalIcon(BuildContext context, Goal goal) {
    final codePoint = int.tryParse(goal.icon);
    if (codePoint == null) {
      return const Icon(Icons.flag_outlined, size: 18);
    }
    final color =
        goal.iconColor != null
            ? Color(goal.iconColor!)
            : Theme.of(context).colorScheme.primary;
    return Icon(
      IconData(codePoint, fontFamily: 'MaterialIcons'),
      size: 18,
      color: color,
    );
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// 打开「添加记录」流程：多目标时先选目标，再打开记录弹窗（预填日期）
///
/// 供日卡 ＋ 按钮与主页快速新建共用。
Future<void> openRecordCreateFlow(BuildContext context, DateTime date) async {
  final controller = TrackerPlugin.instance.controller;
  final goals = controller.goals;

  if (goals.isEmpty) {
    Toast.success('tracker_noGoals'.tr);
    return;
  }

  Goal goal;
  if (goals.length == 1) {
    goal = goals.first;
  } else {
    final selected = await showDialog<Goal>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('tracker_addRecord'.tr),
        children: [
          for (final g in goals)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, g),
              child: Row(
                children: [
                  Expanded(child: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text(
                    '${_displayValue(g.currentValue)}/${_displayValue(g.targetValue)}${g.unitType}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null) return;
    goal = selected;
  }

  if (!context.mounted) return;

  // 记录弹窗的日期选择器不允许选择未来，未来日期回退为当前时刻
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final recordedAt =
      date.isAfter(today)
          ? now
          : DateTime(date.year, date.month, date.day, now.hour, now.minute);

  await showDialog(
    context: context,
    builder: (context) =>
        RecordDialog(goal: goal, controller: controller, initialRecordedAt: recordedAt),
  );
}

String _displayValue(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
