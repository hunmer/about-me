import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar/models/event.dart';

/// 活动详情卡片（经 showDSDialog 展示）
///
/// 手绘纸墨面板：纸底 + 墨线框，随弹窗描画动画入场；
/// 未完成活动提供 编辑/完成/删除，已完成活动仅提供 删除。
class EventDetailCard extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const EventDetailCard({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onComplete,
    required this.onDelete,
  });

  String _getReminderText(int minutes) {
    if (minutes >= 1440) {
      return 'calendar_reminderAheadDays'.trParams({
        'days': '${minutes ~/ 1440}',
      });
    } else if (minutes >= 60) {
      return 'calendar_reminderAheadHours'.trParams({
        'hours': '${minutes ~/ 60}',
      });
    } else {
      return 'calendar_reminderAheadMinutes'.trParams({
        'minutes': '$minutes',
      });
    }
  }

  String _getEventTimeText() {
    final start = DateFormat('yyyy-MM-dd HH:mm').format(event.startTime);
    if (event.endTime == null) return start;
    return '$start ${'calendar_until'.tr} ${DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(event.endTime!)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final isCompleted = event.completedTime != null;
    final canManage = event.source == 'default';

    return DsSketchPanel(
      theme: theme,
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.xl),
      // showDSDialog 外层包了 WiredDraw，面板墨线随描画动画入场
      progress: WiredDrawTransition.progressOf(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题行：图标徽章 + 标题
          Row(
            children: [
              _buildIconBadge(theme),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: Text(
                  event.title,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.lg),

          // 时间信息
          _buildInfoRow(theme, DsIconKind.clock, _getEventTimeText()),
          if (event.reminderMinutes != null) ...[
            SizedBox(height: theme.spacing.md),
            _buildInfoRow(
              theme,
              DsIconKind.bell,
              '${'calendar_reminderSettings'.tr}：${_getReminderText(
                event.reminderMinutes!,
              )}',
            ),
          ],
          if (event.description.isNotEmpty) ...[
            SizedBox(height: theme.spacing.md),
            _buildInfoRow(theme, DsIconKind.info, event.description),
          ],
          if (isCompleted) ...[
            SizedBox(height: theme.spacing.md),
            _buildInfoRow(
              theme,
              DsIconKind.check,
              'calendar_completedAt'.trParams({
                'time': DateFormat('yyyy-MM-dd HH:mm').format(
                  event.completedTime!,
                ),
              }),
            ),
          ],

          // 操作按钮（仅本插件创建的活动可管理）
          if (canManage) ...[
            SizedBox(height: theme.spacing.xl),
            Row(
              children: [
                if (!isCompleted) ...[
                  Expanded(
                    child: DSButton(
                      label: 'calendar_edit'.tr,
                      variant: DSButtonVariant.outline,
                      onPressed: onEdit,
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: DSButton(
                      label: 'calendar_complete'.tr,
                      onPressed: onComplete,
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                ],
                Expanded(
                  child: DSButton(
                    label: 'calendar_delete'.tr,
                    variant: DSButtonVariant.destructive,
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(AppThemeData theme, DsIconKind icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsIcon(icon, size: 18, color: theme.textSub),
        SizedBox(width: theme.spacing.md),
        Expanded(
          child: Text(
            text,
            style: DsTypography.body.copyWith(
              color: theme.textSub,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// 活动图标徽章：墨线圆底 + 手绘图标本体（活动自带动态 IconData，走 WiredIcon）
  Widget _buildIconBadge(AppThemeData theme) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      // 小控件分档：纯色实底 + 墨线抖动描边
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: event.color.withValues(alpha: 0.2),
        radius: BorderRadius.circular(999),
        strokeWidth: 1.2,
        seed: event.id.hashCode,
      ),
      child: WiredIcon(
        icon: event.icon,
        size: 22,
        color: event.color,
        drawConfig: theme.wired.drawConfig,
      ),
    );
  }
}
