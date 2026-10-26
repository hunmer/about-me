import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/activity/activity_plugin.dart';
import 'package:aboutme/plugins/activity/widgets/activity_form.dart';
import 'package:aboutme/plugins/activity/models/activity_record.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/tags_dialog/models/models.dart';

/// 活动编辑界面
/// 用于创建和编辑活动记录
/// 可作为独立页面或 bottom sheet 内容使用
class ActivityEditScreen extends StatefulWidget {
  final ActivityRecord? activity;
  final DateTime? selectedDate;
  final bool showAsBottomSheet;
  final DateTime? startTime; // 传入预填充的开始时间
  final DateTime? endTime; // 传入预填充的结束时间

  const ActivityEditScreen({
    super.key,
    this.activity,
    this.selectedDate,
    this.showAsBottomSheet = false,
    this.startTime,
    this.endTime,
  });

  @override
  State<ActivityEditScreen> createState() => _ActivityEditScreenState();
}

class _ActivityEditScreenState extends State<ActivityEditScreen> {
  List<String> recentMoods = [];
  List<String> recentTags = [];
  List<TagGroupWithTags> tagGroups = [];
  DateTime? _defaultStartTime;
  DateTime? _defaultEndTime;

  @override
  void initState() {
    super.initState();
    _loadRecentMoodsAndTags();
    _loadTagGroups();
    _initDefaultTimes();
  }

  /// 初始化默认时间
  Future<void> _initDefaultTimes() async {
    // 如果有传入时间，直接使用传入的时间
    if (widget.startTime != null && widget.endTime != null) {
      if (mounted) {
        setState(() {
          _defaultStartTime = widget.startTime;
          _defaultEndTime = widget.endTime;
        });
      }
      return;
    }

    // 编辑模式无需默认时间
    if (widget.activity != null) {
      return;
    }

    try {
      final now = DateTime.now();
      final selected = widget.selectedDate;
      final dayStart = selected == null
          ? DateTime(now.year, now.month, now.day)
          : DateTime(selected.year, selected.month, selected.day);
      final isToday = selected == null ||
          (selected.year == now.year &&
              selected.month == now.month &&
              selected.day == now.day);

      // 空闲区间起点：当天最后一个活动的结束时间
      DateTime startTime;
      if (selected == null) {
        final lastActivity =
            await ActivityPlugin.instance.activityService.getLastActivity();
        startTime = lastActivity?.endTime ?? dayStart;
      } else {
        final activities = await ActivityPlugin.instance.activityService
            .getActivitiesForDate(selected);
        DateTime? lastEndTime;
        for (final activity in activities) {
          if (lastEndTime == null || activity.endTime.isAfter(lastEndTime)) {
            lastEndTime = activity.endTime;
          }
        }
        startTime = lastEndTime ?? dayStart;
      }
      if (startTime.isBefore(dayStart)) {
        startTime = dayStart;
      }

      // 结束时间：今天用当前时刻，其他日期默认1小时，且不超过23:59
      final dayEnd = DateTime(
        dayStart.year,
        dayStart.month,
        dayStart.day,
        23,
        59,
      );
      var endTime = isToday ? now : startTime.add(const Duration(hours: 1));
      if (endTime.isAfter(dayEnd)) {
        endTime = dayEnd;
      }
      if (!endTime.isAfter(startTime)) {
        // 当天已无空闲区间，回退到当天最后1分钟
        startTime = endTime.subtract(const Duration(minutes: 1));
      }

      if (mounted) {
        setState(() {
          _defaultStartTime = startTime;
          _defaultEndTime = endTime;
        });
      }
    } catch (e) {
      debugPrint('初始化默认时间失败: $e');
    }
  }

  Future<void> _loadRecentMoodsAndTags() async {
    try {
      final loadedMoods =
          await ActivityPlugin.instance.activityService.getRecentMoods();
      final loadedTags =
          await ActivityPlugin.instance.activityService.getRecentTags();
      if (mounted) {
        setState(() {
          recentMoods = loadedMoods;
          recentTags = loadedTags;
        });
      }
    } catch (e) {
      debugPrint('加载最近心情和标签失败: $e');
    }
  }

  Future<void> _loadTagGroups() async {
    try {
      final loadedGroups =
          await ActivityPlugin.instance.activityService.getTagGroups();
      if (mounted) {
        setState(() {
          tagGroups = loadedGroups;
        });
      }
    } catch (e) {
      debugPrint('加载标签组失败: $e');
    }
  }

  Future<void> _saveActivity(ActivityRecord activity) async {
    try {
      if (widget.activity != null) {
        // 编辑现有活动
        await ActivityPlugin.instance.activityService.updateActivity(
          widget.activity!,
          activity,
        );
      } else {
        // 创建新活动
        await ActivityPlugin.instance.activityService.saveActivity(activity);
      }

      // 自动保存最近标签
      if (activity.tags.isNotEmpty) {
        await _updateRecentTags(activity.tags);
      }

      // 自动保存最近心情
      if (activity.mood != null && activity.mood!.isNotEmpty) {
        await _updateRecentMood(activity.mood!);
      }

      if (mounted) {
        // 先显示保存成功消息
        toastService.showToast(
          widget.activity != null
              ? 'activity_editActivity'.tr
              : 'activity_addActivity'.tr,
        );
        // 再关闭界面
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('保存失败: $e');
      }
    }
  }

  Future<void> _updateRecentTags(List<String> tags) async {
    try {
      if (tags.isEmpty) return;

      // 获取当前的最近标签
      final recentTags =
          await ActivityPlugin.instance.activityService.getRecentTags();

      // 使用 set 去重并移除新标签中已存在的标签
      final inputTagSet = tags.toSet();
      recentTags.removeWhere(inputTagSet.contains);

      // 将新标签按选择顺序添加到开头
      recentTags.insertAll(0, tags);

      // 限制最多30个
      if (recentTags.length > 30) {
        recentTags.removeRange(30, recentTags.length);
      }

      await ActivityPlugin.instance.activityService.saveRecentTags(recentTags);
    } catch (e) {
      debugPrint('更新最近标签失败: $e');
    }
  }

  Future<void> _updateRecentMood(String mood) async {
    try {
      await ActivityPlugin.instance.activityService.saveRecentMoods([mood]);
    } catch (e) {
      debugPrint('更新最近心情失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有提供 selectedDate，使用今天的日期
    // 但如果提供了 startTime 或 endTime，使用它们的日期
    DateTime selectedDate;
    if (widget.selectedDate != null) {
      selectedDate = widget.selectedDate!;
    } else if (_defaultStartTime != null) {
      // 使用开始时间的日期
      selectedDate = DateTime(
        _defaultStartTime!.year,
        _defaultStartTime!.month,
        _defaultStartTime!.day,
      );
    } else if (_defaultEndTime != null) {
      // 使用结束时间的日期
      selectedDate = DateTime(
        _defaultEndTime!.year,
        _defaultEndTime!.month,
        _defaultEndTime!.day,
      );
    } else {
      // 默认使用今天
      selectedDate = DateTime.now();
    }
    final title =
        widget.activity != null
            ? 'activity_editActivity'.tr
            : 'activity_addActivity'.tr;

    final formContent = ActivityForm(
      activity: widget.activity,
      selectedDate: selectedDate,
      initialStartTime: _defaultStartTime,
      initialEndTime: _defaultEndTime,
      recentMoods: recentMoods,
      recentTags: recentTags,
      tagGroups: tagGroups,
      onSave: _saveActivity,
    );

    // bottom sheet 模式：只返回带标题栏的内容
    if (widget.showAsBottomSheet) {
      final theme = DSThemeBridge.resolve(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: DsTypography.title.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                    ),
                  ),
                ),
                DSThemeBridge(
                  // DSIconButton 内部取 AppTheme，需包桥
                  child: Builder(
                    builder:
                        (_) => DSIconButton(
                          icon: DsIconKind.close,
                          size: 36,
                          color: theme.surfaceAlt,
                          iconColor: theme.textSub,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.stroke),
          // 表单内容
          Expanded(child: formContent),
        ],
      );
    }

    // 完整页面模式：使用 Scaffold
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: formContent,
    );
  }
}
