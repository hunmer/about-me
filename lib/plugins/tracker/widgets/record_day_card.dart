import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cutout_stat_grid_card.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

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
    final theme = DSThemeBridge.resolve(context);
    // 过滤掉目标已被删除的记录
    final visible =
        records.where((record) => goalById.containsKey(record.goalId)).toList();

    // 切角纸卡容器（整卡数据色 + 左上切角徽章）+ 自定义内容
    return CutoutStatGridCardWidget(
      inline: true,
      accentColor: color,
      icon: Icons.flag,
      header: CutoutDayCardHeader(
        color: color,
        date: date,
        count: visible.length,
        onAdd: onAddRecord,
      ),
      child:
          visible.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // DS 无旗帜图标，用图钉顶替
                    DsIcon(
                      DsIconKind.pin,
                      size: 32,
                      color: theme.disabled,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'tracker_dayCardEmpty'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.disabled,
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  return _buildRecordItem(context, visible[index]);
                },
              ),
    );
  }

  /// 单条记录行：目标图标 + 目标名/时间 + 数值
  Widget _buildRecordItem(BuildContext context, Record record) {
    final theme = DSThemeBridge.resolve(context);
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
                    style: DsTypography.caption.copyWith(color: theme.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(record.recordedAt),
                    style: DsTypography.caption.copyWith(
                      fontSize: 11,
                      color: theme.textSub,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${_formatValue(record.value)}${goal.unitType}',
              style: DsTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color:
                    goal.progressColor != null
                        ? Color(goal.progressColor!)
                        : theme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 目标图标（icon 为 codePoint 字符串，与目标卡片解析方式一致）
  Widget _buildGoalIcon(BuildContext context, Goal goal) {
    return _goalMaterialIcon(
      goal,
      DSThemeBridge.resolve(context).primary,
      size: 18,
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

/// 目标图标（goal.icon 为持久化 codePoint 字符串，保留 Material IconData）
///
/// 解析失败回退为旗帜图标，与解析成功的 Material 图标保持一致。
Widget _goalMaterialIcon(Goal goal, Color fallbackColor, {double size = 18}) {
  final codePoint = int.tryParse(goal.icon);
  if (codePoint == null) {
    return Icon(Icons.flag_outlined, size: size);
  }
  return Icon(
    dynamicIconData(codePoint, fontFamily: 'MaterialIcons'),
    size: size,
    color: goal.iconColor != null ? Color(goal.iconColor!) : fallbackColor,
  );
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
    final selected = await _showGoalPicker(context, goals);
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

  await showDSDialog(
    context: context,
    theme: DSThemeBridge.resolve(context),
    builder:
        (context) => TrackerRecordForm(
          goal: goal,
          controller: controller,
          initialRecordedAt: recordedAt,
        ),
  );
}

/// 目标选择对话框：目标图标 + 名称 + 当前进度
Future<Goal?> _showGoalPicker(BuildContext context, List<Goal> goals) {
  return showDSDialog<Goal>(
    context: context,
    theme: DSThemeBridge.resolve(context),
    builder:
        (_) => DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return JellyBox(
                radius: theme.radii.xxl,
                padding: EdgeInsets.all(theme.spacing.xl),
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'tracker_addRecord'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.md),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final g in goals)
                              Pressable(
                                onPressed: () => Navigator.pop(context, g),
                                builder: (context, states) {
                                  final pressed = states.contains(
                                    WidgetState.pressed,
                                  );
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: theme.spacing.md,
                                      vertical: theme.spacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          pressed
                                              ? theme.surfaceAlt.withValues(
                                                alpha: 0.6,
                                              )
                                              : DsColors.transparent,
                                      borderRadius: theme.radii.lg,
                                    ),
                                    child: Row(
                                      children: [
                                        _goalMaterialIcon(
                                          g,
                                          theme.primary,
                                          size: 20,
                                        ),
                                        SizedBox(width: theme.spacing.md),
                                        Expanded(
                                          child: Text(
                                            g.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: DsTypography.body.copyWith(
                                              color: theme.text,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: theme.spacing.sm),
                                        Text(
                                          '${_displayValue(g.currentValue)}/${_displayValue(g.targetValue)}${g.unitType}',
                                          style: DsTypography.caption.copyWith(
                                            color: theme.textSub,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
  );
}

String _displayValue(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
