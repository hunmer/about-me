import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';
import 'package:aboutme/plugins/checkin/screens/checkin_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/plugins/checkin/checkin_plugin.dart';
import 'package:aboutme/plugins/checkin/services/group_sort_service.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 本地 TagGroup 类（用于分组管理对话框）
class TagGroup {
  final String name;
  final List<String> tags;

  TagGroup({required this.name, required this.tags});

  TagGroup copyWith({String? name, List<String>? tags}) {
    return TagGroup(
      name: name ?? this.name,
      tags: tags ?? List.from(this.tags),
    );
  }
}

class CheckinListController {
  final BuildContext context;
  final Function() onStateChanged;

  GroupSortType currentSortType = GroupSortType.upcoming;
  bool isReversed = false;

  String selectedGroup = '全部'; // 当前选中的分组

  // ========== 搜索相关状态 ==========
  String searchQuery = ''; // 搜索文本
  bool get isSearching => searchQuery.isNotEmpty;

  // 动态获取最新的 checkinItems
  List<CheckinItem> get checkinItems => CheckinPlugin.instance.checkinItems;

  CheckinListController({
    required this.context,
    required this.onStateChanged,
    // required this.expandedGroups, // Remove this parameter
  });

  // 获取所有分组 (用于过滤栏)
  List<String> get groups {
    final g = checkinItems.map((item) => item.group).toSet().toList()..sort();
    return ['全部', ...g];
  }

  // 应用多条件过滤栏的过滤条件（分组 + 排序）
  Future<void> applyFilters(Map<String, dynamic> values) async {
    selectedGroup = (values['group'] as String?) ?? '全部';

    final sort = values['sort'];
    if (sort is Map) {
      currentSortType = GroupSortType.values[
        sort['type'] as int? ?? GroupSortType.upcoming.index
      ];
      isReversed = sort['reversed'] as bool? ?? false;
    } else {
      currentSortType = GroupSortType.upcoming;
      isReversed = false;
    }

    // 持久化排序设置
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastSortType', currentSortType.index);
      await prefs.setBool('isReversed', isReversed);
    } catch (e) {
      print('保存排序设置失败: $e');
    }

    onStateChanged();
  }

  // ========== 搜索功能 ==========

  /// 处理搜索文本变化
  void onSearchChanged(String query) {
    searchQuery = query;
    onStateChanged();
  }

  /// 清除搜索
  void clearSearch() {
    searchQuery = '';
    onStateChanged();
  }

  /// 获取搜索结果（按名称和分组搜索）
  List<CheckinItem> getSearchResults() {
    if (searchQuery.isEmpty) return [];

    final query = searchQuery.toLowerCase();
    return checkinItems.where((item) {
      // 搜索名称和分组
      final nameMatch = item.name.toLowerCase().contains(query);
      final groupMatch = item.group.toLowerCase().contains(query);
      return nameMatch || groupMatch;
    }).toList();
  }

  // ========== 原有过滤逻辑 ==========

  /// 获取过滤后的打卡项目（普通视图，按当前排序设置排序）
  List<CheckinItem> get filteredItems {
    List<CheckinItem> items;
    if (selectedGroup == '全部') {
      items = List.from(checkinItems);
    } else {
      items =
          checkinItems.where((item) => item.group == selectedGroup).toList();
    }

    return GroupSortService.sortItems(items, currentSortType, isReversed);
  }

  // 更新卡片风格
  Future<void> updateCardStyle(CheckinItem item, CheckinCardStyle style) async {
    item.cardStyle = style;
    // 通过 UseCase 保存变更
    await CheckinPlugin.instance.checkinUseCase.updateItem({
      'id': item.id,
      'cardStyle': style.index,
    });
    await CheckinPlugin.shared.triggerSave();
    onStateChanged();
  }

  // 按分组获取打卡项目 (用于统计或旧逻辑兼容)
  Map<String, List<CheckinItem>> get groupedItems {
    final grouped = <String, List<CheckinItem>>{};
    for (var item in checkinItems) {
      final group = item.group;
      if (!grouped.containsKey(group)) {
        grouped[group] = [];
      }
      grouped[group]!.add(item);
    }
    return grouped;
  }

  // 获取统计信息
  Map<String, dynamic> getStatistics() {
    final groupStats = <String, Map<String, int>>{};
    // Use actual groups from items, not including 'All'
    final actualGroups =
        checkinItems.map((item) => item.group).toSet().toList()..sort();

    for (var group in actualGroups) {
      final items = groupedItems[group] ?? [];
      final completed = items.where((item) => item.isCheckedToday()).length;
      groupStats[group] = {'total': items.length, 'completed': completed};
    }

    int totalItems = checkinItems.length;
    int completedItems =
        checkinItems.where((item) => item.isCheckedToday()).length;
    double completionRate =
        totalItems > 0 ? completedItems / totalItems * 100 : 0;

    // 计算今日总打卡次数
    int todayCheckins = 0;
    for (var item in checkinItems) {
      todayCheckins += item.getTodayRecords().length;
    }

    return {
      'groupStats': groupStats,
      'totalItems': totalItems,
      'completedItems': completedItems,
      'completionRate': completionRate,
      'todayCheckins': todayCheckins,
    };
  }

  // 获取今日打卡记录总数
  int getTotalRecordsToday() {
    int totalRecords = 0;
    for (var item in checkinItems) {
      totalRecords += item.getTodayRecords().length;
    }
    return totalRecords;
  }

  // 恢复最后一次排序设置
  Future<void> restoreLastSortSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSortTypeIndex = prefs.getInt('lastSortType');
      final lastIsReversed = prefs.getBool('isReversed');

      if (lastSortTypeIndex != null) {
        currentSortType = GroupSortType.values[lastSortTypeIndex];
      }
      if (lastIsReversed != null) {
        isReversed = lastIsReversed;
      }
    } catch (e) {
      print('恢复排序设置失败: $e');
      // 使用默认排序设置
      currentSortType = GroupSortType.upcoming;
      isReversed = false;
    }
  }

  // 切换编辑模式
  // 检查日期是否为今天
  bool isToday(DateTime? date) {
    if (date == null) return false;
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  // 检查打卡项是否已完成
  bool isCompleted(CheckinItem item) {
    return item.isCheckedToday();
  }

  // 切换打卡状态
  // 发送事件通知
  void notifyEvent(String action, CheckinItem item) {
    final eventArgs = ItemEventArgs(
      eventName: 'checkin_$action',
      itemId: item.id,
      title: item.name,
      action: action,
    );
    EventManager.instance.broadcast('checkin_$action', eventArgs);
  }

  /// 切换打卡状态（打卡或取消今日最新记录）
  Future<void> toggleCheckin(CheckinItem item) async {
    try {
      if (item.isCheckedToday()) {
        // 取消今天的最新打卡记录
        final todayRecords = item.getTodayRecords();
        if (todayRecords.isNotEmpty) {
          await item.cancelCheckinRecord(todayRecords.first.checkinTime);
          notifyEvent('cancelled', item);
        }
      } else {
        // 执行打卡
        final now = DateTime.now();
        final record = CheckinRecord(
          startTime: now,
          endTime: now,
          checkinTime: now,
          note: '快速打卡',
        );
        await item.addCheckinRecord(record);
        notifyEvent('completed', item);
      }
      onStateChanged();
    } catch (e) {
      ToastService.instance.showToast('操作失败: $e');
    }
  }

  /// 取消指定的打卡记录
  Future<void> cancelCheckinRecord(
    CheckinItem item,
    DateTime recordTime,
  ) async {
    try {
      await item.cancelCheckinRecord(recordTime);
      notifyEvent('cancelled', item);
      onStateChanged();
    } catch (e) {
      ToastService.instance.showToast('取消打卡失败: $e');
    }
  }

  // 显示编辑打卡项页面
  void showEditItemDialog(CheckinItem item) {
    NavigationHelper.push<CheckinItem>(
      context,
      CheckinFormScreen(initialItem: item),
    ).then((updatedItem) async {
      if (updatedItem != null) {
        // 通过 UseCase 更新数据到存储
        final result = await CheckinPlugin.instance.checkinUseCase.updateItem(
          updatedItem.toJson(),
        );
        if (result.isSuccess) {
          // 保存成功后，重新加载数据
          await CheckinPlugin.shared.triggerSave();
          onStateChanged();
        } else {
          // 显示错误信息
          final error = result.errorOrNull;
          ToastService.instance.showToast(error?.message ?? '保存失败');
        }
      }
    });
  }

  // 删除打卡项
  void deleteItem(CheckinItem item) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSDialog(
            title: 'checkin_deleteCheckinItemTitle'.tr,
            message: '${'checkin_deleteConfirmMessage'.tr}"${item.name}"?',
            cancelText: 'app_cancel'.tr,
            confirmText: 'app_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () async {
              Navigator.pop(context);
              // 发送删除事件
              notifyEvent('deleted', item);
              // 使用正确的删除方法
              await CheckinPlugin.instance.removeCheckinItem(item);
              onStateChanged();
            },
          ),
    );
  }

  // 显示打卡项目操作菜单
  void showItemOptionsDialog(CheckinItem item) {
    SmoothBottomSheet.show(
      context: context,
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SmoothSheetAction(
                      icon: DsIconKind.layers,
                      label: 'checkin_modifyCardDisplayStyle'.tr,
                      onTap: () {
                        Navigator.pop(context);
                        _showCardStyleDialog(item);
                      },
                    ),
                    SmoothSheetAction(
                      icon: DsIconKind.edit,
                      label: 'checkin_editCheckinItem'.tr,
                      onTap: () {
                        Navigator.pop(context);
                        _editCheckinItem(item);
                      },
                    ),
                    SmoothSheetAction(
                      icon: DsIconKind.refresh,
                      label: 'checkin_resetCheckinRecords'.tr,
                      onTap: () {
                        Navigator.pop(context);
                        _showResetConfirmDialog(item);
                      },
                    ),
                    SmoothSheetAction(
                      icon: DsIconKind.trash,
                      label: 'app_delete'.tr,
                      destructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmDialog(item);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
    );
  }

  void _showCardStyleDialog(CheckinItem item) {
    showDSDialog(
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
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'checkin_selectCardStyle'.tr,
                        textAlign: TextAlign.center,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      DSButton(
                        label: 'checkin_sevenDayDisplay'.tr,
                        variant: DSButtonVariant.outline,
                        expand: true,
                        onPressed: () {
                          Navigator.pop(context);
                          updateCardStyle(item, CheckinCardStyle.weekly);
                        },
                      ),
                      SizedBox(height: theme.spacing.sm),
                      DSButton(
                        label: 'checkin_smallCardStyle'.tr,
                        variant: DSButtonVariant.outline,
                        expand: true,
                        onPressed: () {
                          Navigator.pop(context);
                          updateCardStyle(item, CheckinCardStyle.small);
                        },
                      ),
                      SizedBox(height: theme.spacing.sm),
                      DSButton(
                        label: 'checkin_calendarStyle'.tr,
                        variant: DSButtonVariant.outline,
                        expand: true,
                        onPressed: () {
                          Navigator.pop(context);
                          updateCardStyle(item, CheckinCardStyle.calendar);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }

  // 编辑打卡项目
  void _editCheckinItem(CheckinItem item) {
    NavigationHelper.push<CheckinItem>(
      context,
      CheckinFormScreen(initialItem: item),
    ).then((editedItem) async {
      if (editedItem != null) {
        // 通过 UseCase 更新数据到存储
        final result = await CheckinPlugin.instance.checkinUseCase.updateItem(
          editedItem.toJson(),
        );
        if (result.isSuccess) {
          // 保存成功后，重新加载数据
          await CheckinPlugin.shared.triggerSave();
          onStateChanged();
        } else {
          // 显示错误信息
          final error = result.errorOrNull;
          ToastService.instance.showToast(error?.message ?? '保存失败');
        }
      }
    });
  }

  // 显示重置确认对话框
  void _showResetConfirmDialog(CheckinItem item) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSDialog(
            title: 'checkin_resetCheckinRecordsTitle'.tr,
            message: '${'checkin_resetCheckinRecordsMessage'.tr}"${item.name}"',
            cancelText: 'app_cancel'.tr,
            confirmText: 'checkin_confirmReset'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () async {
              Navigator.pop(context);
              await item.resetRecords();
              // 广播重置记录事件
              notifyEvent('reset', item);
              onStateChanged();
              ToastService.instance.showToast(
                'checkin_resetSuccessMessage'.trParams({'name': item.name}),
              );
            },
          ),
    );
  }

  // 显示删除确认对话框
  void _showDeleteConfirmDialog(CheckinItem item) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSDialog(
            title: 'checkin_deleteCheckinItemTitle'.tr,
            message: '${'checkin_deleteConfirmMessage'.tr}"${item.name}"?',
            cancelText: 'app_cancel'.tr,
            confirmText: 'checkin_confirmDelete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () async {
              Navigator.pop(context);
              // 发送删除事件
              notifyEvent('deleted', item);
              // 使用正确的删除方法
              await CheckinPlugin.instance.removeCheckinItem(item);
              onStateChanged();
              ToastService.instance.showToast(
                'checkin_deleteSuccessMessage'.trParams({'name': item.name}),
              );
            },
          ),
    );
  }

  // 显示打卡成功对话框
  void showCheckinSuccessDialog(CheckinItem item, CheckinRecord record) {
    final streak = item.getConsecutiveDays();
    final timeFormat = DateFormat('HH:mm');

    showDSDialog(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DsIcon(DsIconKind.check, color: theme.success),
                          const SizedBox(width: 8),
                          Text(
                            'checkin_checkinSuccessTitle'.tr,
                            style: DsTypography.title.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacing.md),
                      Text(
                        '${'checkin_checkinSuccessTitle'.tr} ${item.name}',
                        style: DsTypography.body.copyWith(color: theme.text),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${'checkin_timeRangeLabel'.tr}: ${timeFormat.format(record.startTime)} - ${timeFormat.format(record.endTime)}',
                        style: DsTypography.body.copyWith(color: theme.text),
                      ),
                      if (record.note != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${'checkin_noteLabel'.tr}: ${record.note}',
                          style: DsTypography.body.copyWith(color: theme.text),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (streak > 1)
                        Text(
                          '${'checkin_consecutiveDaysLabel'.tr}: $streak',
                          style: DsTypography.body.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.warning,
                          ),
                        ),
                      SizedBox(height: theme.spacing.lg),
                      DSButton(
                        label: 'app_ok'.tr,
                        expand: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }

  // 显示分组管理对话框
  void showGroupManagementDialog() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => TagManagerDialog(
            groups: getCurrentTagGroups(),
            onRename: (oldName, newName) => renameGroup(oldName, newName),
            onDelete: (name, deleteItems) =>
                deleteGroup(name, deleteItems: deleteItems),
            onRefreshData: () async => getCurrentTagGroups(),
          ),
    ).then((_) {
      // 关闭对话框后刷新界面
      onStateChanged();
    });
  }

  /// 获取当前分组快照（用于分组管理对话框）
  List<TagGroup> getCurrentTagGroups() {
    final groups =
        checkinItems.map((item) => item.group).toSet().toList()..sort();
    return groups.map((group) {
      final items = groupedItems[group] ?? [];
      return TagGroup(
        name: group,
        tags: items.map((item) => item.name).toList(),
      );
    }).toList();
  }

  /// 重命名分组：更新组内所有项目的分组字段
  Future<void> renameGroup(String oldName, String newName) async {
    if (newName.isEmpty || newName == oldName) return;
    // 重名检查
    if (groups.contains(newName)) {
      ToastService.instance.showToast('checkin_groupNameExistsError'.tr);
      return;
    }
    for (var item in checkinItems) {
      if (item.group == oldName) item.group = newName;
    }
    // 同步当前选中分组
    if (selectedGroup == oldName) selectedGroup = newName;
    await CheckinPlugin.shared.triggerSave();
    onStateChanged();
  }

  /// 删除分组
  /// [deleteItems] 为 true 时同时删除组内打卡项目，否则将项目移至"默认分组"
  Future<void> deleteGroup(String name, {required bool deleteItems}) async {
    final items = checkinItems.where((item) => item.group == name).toList();
    if (deleteItems) {
      for (var item in items) {
        await CheckinPlugin.instance.removeCheckinItem(item);
      }
    } else {
      for (var item in items) {
        item.group = '默认分组';
      }
      await CheckinPlugin.shared.triggerSave();
    }
    // 当前选中的分组被删除时回到"全部"
    if (selectedGroup == name) selectedGroup = '全部';
    onStateChanged();
  }

  // 更新指定分组中项目的顺序
  Future<void> updateItemsOrder(
    String group,
    List<CheckinItem> newOrder,
  ) async {
    // 找到当前分组在 checkinItems 中的起始和结束索引
    int startIndex = -1;
    int endIndex = -1;

    for (int i = 0; i < checkinItems.length; i++) {
      if (checkinItems[i].group == group) {
        if (startIndex == -1) startIndex = i;
        endIndex = i;
      } else if (startIndex != -1) {
        // 已经找到了分组的所有项目，可以跳出循环
        break;
      }
    }

    if (startIndex != -1 && endIndex != -1) {
      // 替换原有的项目顺序
      checkinItems.removeRange(startIndex, endIndex + 1);
      checkinItems.insertAll(startIndex, newOrder);
      await CheckinPlugin.shared.triggerSave();
      onStateChanged();
    }
  }

  // 释放资源
  void dispose() {
    // 清理资源
  }
}


/// 分组管理对话框：展示分组列表，支持重命名与删除分组
class TagManagerDialog extends StatefulWidget {
  final List<TagGroup> groups;

  /// 重命名分组回调 (旧名, 新名)
  final Future<void> Function(String oldName, String newName)? onRename;

  /// 删除分组回调 (分组名, 是否同时删除组内打卡项目)
  final Future<void> Function(String name, bool deleteItems)? onDelete;

  /// 操作完成后拉取最新分组数据
  final Future<List<TagGroup>> Function()? onRefreshData;

  const TagManagerDialog({
    super.key,
    required this.groups,
    this.onRename,
    this.onDelete,
    this.onRefreshData,
  });

  @override
  State<TagManagerDialog> createState() => _TagManagerDialogState();
}

class _TagManagerDialogState extends State<TagManagerDialog> {
  late List<TagGroup> _groups;

  /// 当前正在行内编辑的分组索引
  int? _editingIndex;
  final TextEditingController _editingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _groups = List.from(widget.groups);
  }

  @override
  void dispose() {
    _editingController.dispose();
    super.dispose();
  }

  /// 操作完成后重新拉取最新分组列表
  Future<void> _refresh() async {
    final updated = await widget.onRefreshData?.call();
    if (updated != null && mounted) {
      setState(() {
        _groups = updated;
        _editingIndex = null;
      });
    }
  }

  void _startEdit(int index) {
    setState(() {
      _editingIndex = index;
      _editingController.text = _groups[index].name;
    });
  }

  Future<void> _confirmRename() async {
    final index = _editingIndex;
    if (index == null) return;
    final oldName = _groups[index].name;
    final newName = _editingController.text.trim();
    setState(() => _editingIndex = null);
    if (newName.isNotEmpty && newName != oldName) {
      await widget.onRename?.call(oldName, newName);
      await _refresh();
    }
  }

  /// 删除分组确认对话框（可选同时删除组内打卡项目）
  void _confirmDelete(TagGroup group) {
    bool deleteItems = false;
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return DSThemeBridge(
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
                            'checkin_deleteGroupTitle'.tr,
                            textAlign: TextAlign.center,
                            style: DsTypography.title.copyWith(
                              color: theme.text,
                            ),
                          ),
                          SizedBox(height: theme.spacing.md),
                          Text(
                            'checkin_deleteGroupMessage'.trParams({
                              'name': group.name,
                              'count': '${group.tags.length}',
                            }),
                            style: DsTypography.body.copyWith(color: theme.text),
                          ),
                          SizedBox(height: theme.spacing.md),
                          // 同时删除组内打卡项目
                          InkWell(
                            onTap:
                                () => setDialogState(
                                  () => deleteItems = !deleteItems,
                                ),
                            child: Row(
                              children: [
                                DSCheckbox(
                                  value: deleteItems,
                                  onChanged:
                                      (v) => setDialogState(
                                        () => deleteItems = v ?? false,
                                      ),
                                ),
                                Expanded(
                                  child: Text(
                                    'checkin_deleteItemsWithGroup'.tr,
                                    style: DsTypography.body.copyWith(
                                      color: theme.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: theme.spacing.xs),
                          Text(
                            'checkin_itemsMoveHint'.tr,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: DSButton(
                                  label: 'app_delete'.tr,
                                  variant: DSButtonVariant.destructive,
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await widget.onDelete?.call(
                                      group.name,
                                      deleteItems,
                                    );
                                    await _refresh();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 600,
              height: 500,
              child: Column(
                children: [
                  // 标题栏
                  Row(
                    children: [
                      Text(
                        'checkin_manageGroupsTitle'.tr,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      const Spacer(),
                      DSIconButton(
                        icon: DsIconKind.close,
                        size: 36,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Divider(
                    height: 1,
                    color: theme.stroke.withValues(
                      alpha: theme.isDark ? 0.2 : 0.8,
                    ),
                  ),

                  // 分组列表
                  Expanded(
                    child:
                        _groups.isEmpty
                            ? Center(
                              child: Text(
                                'checkin_emptyData'.tr,
                                style: DsTypography.body.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                            )
                            : ListView.builder(
                              itemCount: _groups.length,
                              itemBuilder:
                                  (context, index) => _buildGroupRow(
                                    context,
                                    index,
                                  ),
                            ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建单个分组行（展示态 / 行内重命名编辑态）
  Widget _buildGroupRow(BuildContext context, int index) {
    final group = _groups[index];
    final theme = DSThemeBridge.resolve(context);
    final isEditing = _editingIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child:
                isEditing
                    ? TextField(
                      controller: _editingController,
                      autofocus: true,
                      style: DsTypography.body.copyWith(color: theme.text),
                      decoration: InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => _confirmRename(),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: DsTypography.body.copyWith(color: theme.text),
                        ),
                        Text(
                          'checkin_groupItemCount'.trParams({
                            'count': '${group.tags.length}',
                          }),
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                      ],
                    ),
          ),
          if (isEditing) ...[
            DSIconButton(
              icon: DsIconKind.check,
              size: 32,
              color: theme.surfaceAlt,
              iconColor: theme.success,
              onPressed: _confirmRename,
            ),
            DSIconButton(
              icon: DsIconKind.close,
              size: 32,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              onPressed: () => setState(() => _editingIndex = null),
            ),
          ] else ...[
            DSIconButton(
              icon: DsIconKind.edit,
              size: 32,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              tooltip: 'checkin_renameGroup'.tr,
              onPressed: () => _startEdit(index),
            ),
            DSIconButton(
              icon: DsIconKind.trash,
              size: 32,
              color: theme.surfaceAlt,
              iconColor: theme.danger,
              tooltip: 'app_delete'.tr,
              onPressed: () => _confirmDelete(group),
            ),
          ],
        ],
      ),
    );
  }
}
