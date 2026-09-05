import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/tracker/models/goal.dart';
import 'package:aboutme/plugins/tracker/models/record.dart';
import 'package:aboutme/plugins/tracker/controllers/tracker_controller.dart';
import 'package:aboutme/plugins/tracker/widgets/timer_dialog.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  final TrackerController controller;
  final VoidCallback onTap;

  const GoalCard({
    super.key,
    required this.goal,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // 卡片可能渲染在第三方导航容器内，DS 组件先过桥
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final progress = controller.calculateProgress(goal);
          final isCompleted = progress >= 1.0;
          final remainingDays =
              goal.dateSettings.endDate?.difference(DateTime.now()).inDays;

          return SizedBox(
            height: 180, // 为卡片添加固定高度
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: theme.radii.xl,
                  boxShadow: theme.shadows.soft,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        constraints: const BoxConstraints.expand(),
                        child:
                            goal.imagePath != null && goal.imagePath!.isNotEmpty
                                ? AdaptiveImage(
                                  imagePath: goal.imagePath,
                                  fit: BoxFit.cover,
                                  borderRadius: 12,
                                )
                                : _buildBackgroundContainer(
                                  context,
                                  isCompleted,
                                ),
                      ),
                    ),
                    Pressable(
                      onPressed: onTap,
                      builder:
                          (context, states) => Opacity(
                            opacity:
                                states.contains(WidgetState.pressed)
                                    ? 0.85
                                    : 1.0,
                            child: Container(
                              constraints: const BoxConstraints.expand(),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.7),
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildIconContainer(
                                              context,
                                              isCompleted,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                goal.name,
                                                style: DsTypography.title
                                                    .copyWith(
                                                      fontSize: 16,
                                                      decoration:
                                                          isCompleted
                                                              ? TextDecoration
                                                                  .lineThrough
                                                              : null,
                                                      color: Colors.white,
                                                      shadows: [
                                                        Shadow(
                                                          offset: const Offset(
                                                            1.0,
                                                            1.0,
                                                          ),
                                                          blurRadius: 3.0,
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            DSIconButton(
                                              icon: DsIconKind.plus,
                                              size: 40,
                                              color: theme.surface,
                                              iconColor: theme.text,
                                              onPressed:
                                                  () => _showQuickRecordDialog(
                                                    context,
                                                  ),
                                            ),
                                            DSIconButton(
                                              // DS 无计时器图标，用时钟顶替
                                              icon: DsIconKind.clock,
                                              size: 40,
                                              color: theme.surface,
                                              iconColor: theme.text,
                                              onPressed:
                                                  () => _startTimer(context),
                                            ),
                                            DSCheckbox(
                                              value: isCompleted,
                                              onChanged: (value) {
                                                final newValue = value ?? false;
                                                controller.updateGoal(
                                                  goal.id,
                                                  goal.copyWith(
                                                    currentValue:
                                                        newValue
                                                            ? goal.targetValue
                                                            : 0,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    const SizedBox(height: 12),
                                    DSLinearProgress(
                                      value: progress,
                                      height: 8,
                                      color:
                                          isCompleted
                                              ? theme.success
                                              : goal.progressColor != null
                                              ? Color(goal.progressColor!)
                                              : theme.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${goal.currentValue.toInt()}/${goal.targetValue.toInt()}',
                                          style: DsTypography.caption.copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (remainingDays != null)
                                          Text(
                                            remainingDays > 0
                                                ? '剩余$remainingDays天'
                                                : '已过期',
                                            style: DsTypography.caption
                                                .copyWith(
                                                  color:
                                                      remainingDays <= 0
                                                          ? theme.danger
                                                          : Colors.white,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _startTimer(BuildContext context) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => TimerDialog(goal: goal, controller: controller),
    );
  }

  Widget _buildIconContainer(BuildContext context, bool isCompleted) {
    final theme = DSThemeBridge.resolve(context);
    final tint = isCompleted ? theme.success : theme.primary;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: tint, width: 3), // 加粗边框增强可见度
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2), // 加深阴影增强对比
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        // goal.icon 为持久化 codePoint 字符串，保留 Material IconData
        child: Icon(
          dynamicIconData(int.parse(goal.icon), fontFamily: 'MaterialIcons'),
          size: 20,
          color: tint,
        ),
      ),
    );
  }

  Widget _buildBackgroundContainer(BuildContext context, bool isCompleted) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      decoration: BoxDecoration(
        color: (isCompleted ? theme.success : theme.primary).withValues(
          alpha: 0.15,
        ),
      ),
    );
  }

  void _showQuickRecordDialog(BuildContext context) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => _QuickRecordDialog(goal: goal, controller: controller),
    );
  }
}

/// 快速记录对话框：输入要增加的数值
class _QuickRecordDialog extends StatefulWidget {
  final Goal goal;
  final TrackerController controller;

  const _QuickRecordDialog({required this.goal, required this.controller});

  @override
  State<_QuickRecordDialog> createState() => _QuickRecordDialogState();
}

class _QuickRecordDialogState extends State<_QuickRecordDialog> {
  final _recordController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _recordController.dispose();
    super.dispose();
  }

  void _save() {
    final text = _recordController.text;
    if (text.isEmpty) {
      setState(() => _errorText = '请输入记录值');
      return;
    }
    final recordValue = double.tryParse(text);
    if (recordValue == null) {
      setState(() => _errorText = '请输入有效的数字');
      return;
    }

    widget.controller.addRecord(
      Record(
        id: const Uuid().v4(),
        goalId: widget.goal.id,
        value: recordValue,
        recordedAt: DateTime.now(),
        note: null,
      ),
      widget.goal,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${'tracker_quickRecord'.tr} - ${widget.goal.name}',
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),
                DSInput(
                  controller: _recordController,
                  errorText: _errorText,
                  hint:
                      '${'tracker_recordValue'.tr} (${widget.goal.unitType}) - 请输入要增加的数值',
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _save(),
                ),
                SizedBox(height: theme.spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: DSButton(
                        label: 'app_cancel'.tr,
                        variant: DSButtonVariant.outline,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: DSButton(label: 'app_save'.tr, onPressed: _save),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
