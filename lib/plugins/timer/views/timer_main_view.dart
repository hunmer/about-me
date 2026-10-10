import 'package:get/get.dart';
import 'dart:async';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/timer/views/add_timer_task_dialog.dart';
import 'package:aboutme/plugins/timer/views/timer_task_details_page.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/widgets/swipe_action/index.dart';
import 'package:aboutme/plugins/timer/timer_plugin.dart';
import 'package:aboutme/plugins/timer/models/timer_task.dart';
import 'package:collection/collection.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/widgets/common/timer_card_widget.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

class TimerMainView extends StatefulWidget {
  const TimerMainView({super.key});
  @override
  State<TimerMainView> createState() => _TimerMainViewState();
}

class _TimerMainViewState extends State<TimerMainView> {
  List<TimerTask> _tasks = [];
  late TimerPlugin _plugin;
  Map<String, List<TimerTask>> _groupedTasks = {};
  List<TimerTask> _searchResults = [];
  String _currentQuery = '';

  // 多条件过滤参数
  Map<String, dynamic> _multiFilters = {};

  @override
  void initState() {
    super.initState();
    _plugin = PluginManager().getPlugin('timer') as TimerPlugin;
    _updateTasksAndGroups();
    _loadConfig();

    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateRouteContext(_groupLabelFromFilters(_multiFilters));
      }
    });
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前分组
  void _updateRouteContext(String group) {
    RouteHistoryManager.updateCurrentContext(
      pageId: "/timer_main",
      title: '计时器 - $group',
      params: {'group': group},
    );
  }

  void _updateTasksAndGroups() {
    _tasks = _plugin.getTasks();
    _groupedTasks = groupBy(_tasks, (TimerTask task) => task.group);
  }

  /// 执行搜索
  void _searchTasks(String query) {
    setState(() {
      _currentQuery = query;
      if (query.isEmpty) {
        _searchResults = [];
      } else {
        _searchResults =
            _tasks.where((task) {
              final nameMatch = task.name.toLowerCase().contains(
                query.toLowerCase(),
              );
              final groupMatch = task.group.toLowerCase().contains(
                query.toLowerCase(),
              );
              return nameMatch || groupMatch;
            }).toList();
      }
    });
  }

  /// 获取所有分组(用于多条件过滤)
  List<String> get _groups {
    final g = _groupedTasks.keys.toList()..sort();
    return g;
  }

  /// 从过滤参数中解析当前分组显示名
  String _groupLabelFromFilters(Map<String, dynamic> filters) {
    return filters['group'] as String? ?? 'timer_all'.tr;
  }

  /// 应用多条件过滤
  void _applyMultiFilters(Map<String, dynamic> filters) {
    // 使用 addPostFrameCallback 避免在 build 阶段调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _multiFilters = filters;
        });
        // 更新路由上下文，使"询问当前上下文"功能能获取到当前分组
        _updateRouteContext(_groupLabelFromFilters(filters));
      }
    });
  }

  /// 根据多条件过滤获取任务
  List<TimerTask> get _filteredByGroup {
    final group = _multiFilters['group'] as String?;
    if (group == null) {
      return _tasks;
    } else {
      return _groupedTasks[group] ?? [];
    }
  }

  Future<void> _loadConfig() async {
    try {
      // final config = await _plugin.storage.read('configs/${_plugin.id}.json');
    } catch (e) {
      // 如果配置不存在，使用默认值
    }
  }

  /// 构建多条件过滤项
  List<FilterItem> _buildFilterItems() {
    final groups = _groups;
    if (groups.isEmpty) {
      return [];
    }

    final groupOptions = {
      for (final group in groups) group: group,
    };

    return [
      FilterItem(
        id: 'group',
        title: 'timer_group'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildSingleChoiceFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
            options: groupOptions,
            allItemsKey: 'all',
            allItemsLabel: 'timer_all'.tr,
          );
        },
        getBadge: (value) => FilterBuilders.singleChoiceBadge(value, groupOptions),
      ),
    ];
  }

  /// 从底部弹出添加任务 sheet
  void _showAddTaskSheet() async {
    final newTask = await SmoothBottomSheet.show<TimerTask>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: AddTimerTaskDialog(
          groups: _plugin.timerController.getGroups(),
        ),
      ),
    );
    if (newTask != null) {
      await _plugin.addTask(newTask);
      setState(() {
        _tasks = _plugin.getTasks();
        _groupedTasks = groupBy(_tasks, (TimerTask task) => task.group);
      });
    }
  }

  /// 底部弧形圆盘导航栏：subbar 右侧圆钮为添加入口
  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: DSBottomNavigation(
        items: const [DSNavItem(icon: DsIconKind.clock, label: '计时器')],
        currentIndex: 0,
        // 单 tab 无切换需求；null 使 dock 忽略指针，仅保留添加圆钮交互
        onTap: null,
        trailingAction: DsIcon(
          DsIconKind.plus,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTrailingTap: _showAddTaskSheet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text(_plugin.getPluginName(context)!),
      largeTitle: '计时器',
      enableLargeTitle: true,
      // ========== 搜索相关配置 ==========
      enableSearchBar: true,
      searchPlaceholder: 'timer_searchPlaceholder'.tr,
      onSearchChanged: _searchTasks,
      searchBody: _buildSearchResults(),
      // ========== 多条件过滤配置 ==========
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      onMultiFilterChanged: _applyMultiFilters,

      body: Stack(
        children: [
          ListView.separated(
            // 底部留白避开悬浮导航栏
            padding: const EdgeInsets.all(16).copyWith(bottom: 130),
            itemCount: _filteredByGroup.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final task = _filteredByGroup[index];
              // 根据计时器数量决定是否使用网格布局
              final useGridLayout = task.timerItems.length >= 3;

              return SwipeActionWrapper(
                key: ValueKey(task.id),
                trailingActions: [
                  SwipeActionPresets.edit(
                    onTap: () => _editTask(task),
                  ),
                  SwipeActionOption(
                    label: '重置',
                    icon: Icons.replay,
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                    onTap: () => _resetTask(task),
                  ),
                  SwipeActionPresets.delete(
                    onTap: () => _deleteTask(task),
                    showConfirm: false,
                  ),
                ],
                child: TimerCardWidget(
                  task: task,
                  onTap: _showTaskDetails,
                  onEdit: _editTask,
                  onReset: _resetTask,
                  onDelete: _deleteTask,
                  showGroup: true,  // 显示分组名称
                  useGridLayout: useGridLayout,  // 根据计时器数量决定布局
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  void _showTaskDetails(TimerTask task) async {
    await NavigationHelper.push(
      context,
      TimerTaskDetailsPage(taskId: task.id),
    );
    setState(() {
      _updateTasksAndGroups();
    });
  }

  void _editTask(TimerTask task) async {
    final editedTask = await showDialog<TimerTask>(
      context: context,
      builder:
          (context) => AddTimerTaskDialog(
            groups: _plugin.timerController.getGroups(),
            initialTask: task,
          ),
    );

    if (editedTask != null) {
      await _plugin.updateTask(editedTask);
      await _plugin.saveTasks();
      setState(() {
        _updateTasksAndGroups();
      });
    }
  }

  void _resetTask(TimerTask task) {
    task.reset();
    setState(() {});
  }

  /// 构建搜索结果
  Widget _buildSearchResults() {
    if (_currentQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '搜索计时器任务',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '输入任务名称或分组名称',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的任务',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '当前查询：$_currentQuery',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final task = _searchResults[index];
        // 根据计时器数量决定是否使用网格布局
        final useGridLayout = task.timerItems.length >= 3;

        return SwipeActionWrapper(
          key: ValueKey(task.id),
          trailingActions: [
            SwipeActionPresets.edit(
              onTap: () => _editTask(task),
            ),
            SwipeActionOption(
              label: '重置',
              icon: Icons.replay,
              backgroundColor: Colors.orange,
              textColor: Colors.white,
              onTap: () => _resetTask(task),
            ),
            SwipeActionPresets.delete(
              onTap: () => _deleteTask(task),
              showConfirm: false,
            ),
          ],
          child: TimerCardWidget(
            task: task,
            onTap: _showTaskDetails,
            onEdit: _editTask,
            onReset: _resetTask,
            onDelete: _deleteTask,
            showGroup: true,  // 显示分组名称
            useGridLayout: useGridLayout,  // 根据计时器数量决定布局
          ),
        );
      },
    );
  }

  void _deleteTask(TimerTask task) async {
    await _plugin.removeTask(task.id);
    setState(() {
      _updateTasksAndGroups();
    });
  }
}
