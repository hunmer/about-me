import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// 单条每日任务数据
class JellyDailyTask {
  const JellyDailyTask({
    required this.name,
    required this.progress,
    required this.reward,
    required this.leadingIcon,
    required this.leadingColor,
    this.done = false,
  });

  final String name;

  /// 如 1/1、1/2、3 笔
  final String progress;

  /// 奖励星星数（展示为 +N）
  final int reward;

  /// 行首小图标（完成态会被绿色对勾圆替代）
  final DsIconKind leadingIcon;
  final Color leadingColor;

  /// 是否已完成（整行打绿勾）
  final bool done;
}

/// 「每日任务」卡：标题 + 任务清单（名称/进度/星星奖励/跳转）
class JellyDailyTasksCard extends StatelessWidget {
  const JellyDailyTasksCard({super.key, required this.tasks, this.onTaskTap});

  final List<JellyDailyTask> tasks;
  final ValueChanged<int>? onTaskTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return JellyBox(
      radius: theme.radii.xl,
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIcon(DsIconKind.clipboard, size: 15, color: theme.primary),
              SizedBox(width: theme.spacing.sm),
              Text(
                '每日任务',
                style: DsTypography.heading.copyWith(
                  fontSize: 14,
                  color: theme.primaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          for (var i = 0; i < tasks.length; i++) ...[
            _TaskRow(
              task: tasks[i],
              onTap: onTaskTap == null ? null : () => onTaskTap!(i),
            ),
            if (i != tasks.length - 1) SizedBox(height: theme.spacing.sm + 2),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, this.onTap});

  final JellyDailyTask task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: pressed ? 0.8 : 1.0,
          child: Row(
            children: [
              _LeadingMark(task: task),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: task.name,
                        style: DsTypography.body.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                      ),
                      TextSpan(
                        text: '  ${task.progress}',
                        style: DsTypography.caption.copyWith(
                          fontSize: 10,
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: theme.spacing.xs),
              DsIcon(DsIconKind.star, size: 11, color: theme.warning),
              SizedBox(width: theme.spacing.xs),
              Text(
                '+${task.reward}',
                style: DsTypography.label.copyWith(
                  fontSize: 10,
                  color: theme.warning.mixBlack(0.15),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              _ArrowButton(),
            ],
          ),
        );
      },
    );
  }
}

/// 行首标记：完成 = 绿色对勾圆；未完成 = 彩色小图标
class _LeadingMark extends StatelessWidget {
  const _LeadingMark({required this.task});

  final JellyDailyTask task;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    if (task.done) {
      return Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.jellyGradient(theme.success),
            stops: theme.jellyStops,
          ),
          border: Border.all(color: theme.jellyRim(theme.success), width: 1.2),
        ),
        child: DsIcon(DsIconKind.check, size: 11, color: theme.onSuccess),
      );
    }
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: task.leadingColor.withValues(alpha: 0.16),
      ),
      child: DsIcon(task.leadingIcon, size: 12, color: task.leadingColor),
    );
  }
}

/// 行尾小箭头按钮
class _ArrowButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.surfaceAlt,
        border: Border.all(color: theme.stroke, width: 1.2),
      ),
      child: DsIcon(DsIconKind.chevronRight, size: 10, color: theme.textSub),
    );
  }
}
