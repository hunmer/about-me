import 'package:get/get.dart';
import 'dart:async';
import 'package:aboutme/plugins/todo/models/task.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/event_listener_container.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/custom_bottom_bar.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/todo/todo_plugin.dart';
import 'package:aboutme/plugins/todo/controllers/task_controller.dart';
import 'package:aboutme/plugins/todo/widgets/task_form.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/plugins/todo/views/todo_four_quadrant_view.dart';
import 'package:aboutme/plugins/todo/views/todo_week_view.dart';
import 'package:aboutme/plugins/todo/widgets/history_completed_view.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:intl/intl.dart';
import 'todo_item_detail.dart';

class TodoBottomBarView extends StatefulWidget {
  const TodoBottomBarView({super.key});

  @override
  State<TodoBottomBarView> createState() => _TodoBottomBarViewState();
}

class _TodoBottomBarViewState extends State<TodoBottomBarView>
    with SingleTickerProviderStateMixin {
  late TodoPlugin _plugin;
  late TabController _tabController;
  Timer? _timer;
  int _currentPage = 0;

  final GlobalKey _bottomBarKey = GlobalKey();

  // 搜索查询变量
  String _searchQuery = '';

  // 过滤条件状态（由 View 自己管理）
  Map<String, dynamic>? _currentFilter;

  // 获取页面颜色
  List<Color> get _colors => [
    Colors.blue, // 第一个tab的颜色
    Colors.green, // 第二个tab的颜色
  ];

  @override
  void initState() {
    super.initState();
    _plugin = TodoPlugin.instance;
    _tabController = TabController(length: 2, vsync: this);

    // 监听tab切换
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentPage = _tabController.index;
        });
        // 更新路由上下文
        _updateRouteContext();
      }
    });

    // 定时器用于更新计时器显示
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      bool hasActiveTimer = false;
      for (final task in _plugin.taskController.tasks) {
        if (task.status == TaskStatus.inProgress && task.startTime != null) {
          hasActiveTimer = true;
          break;
        }
      }

      if (hasActiveTimer) {
        setState(() {});
      }
    });

    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRouteContext();

      // 检查是否有 action: create 参数，用于从小组件打开新建任务表单
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null && args['action'] == 'create') {
        _openTaskForm();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前页面状态
  void _updateRouteContext() {
    String pageId;
    String title;
    Map<String, dynamic> params = {};

    if (_currentPage == 0) {
      // 待办列表页
      final taskCount = _plugin.taskController.tasks.length;

      if (_searchQuery.isNotEmpty) {
        pageId = '/todo_list_search';
        title = '待办事项 - 搜索: $_searchQuery';
        params['searchQuery'] = _searchQuery;
        params['resultCount'] = taskCount;
      } else {
        pageId = '/todo_list';
        title = '待办事项';
        params['taskCount'] = taskCount;
      }

      params['viewMode'] = _plugin.taskController.viewMode.toString();
      params['sortBy'] = _plugin.taskController.sortBy.toString();
    } else {
      // 历史记录页
      pageId = '/todo_history';
      title = '待办历史记录';
      params['completedCount'] = _plugin.taskController.completedTasks.length;
    }

    RouteHistoryManager.updateCurrentContext(
      pageId: pageId,
      title: title,
      params: params,
    );
  }

  /// 打开新建任务表单
  void _openTaskForm() {
    NavigationHelper.openContainerWithHero(
      context,
      (context) => TaskForm(
        taskController: _plugin.taskController,
        reminderController: _plugin.reminderController,
      ),
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// 构建 FAB
  Widget _buildFab() {
    return Builder(
      builder: (context) {
        final fabColor = _colors[_currentPage];
        return FloatingActionButton(
          backgroundColor: fabColor,
          elevation: 4,
          shape: const CircleBorder(),
          onPressed: () {
            NavigationHelper.openContainerWithHero(
              context,
              (context) => TaskForm(
                taskController: _plugin.taskController,
                reminderController: _plugin.reminderController,
              ),
              transitionDuration: const Duration(milliseconds: 300),
            );
          },
          child: Icon(
            Icons.add,
            color:
                fabColor.computeLuminance() < 0.5 ? Colors.white : Colors.black,
            size: 32,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomBar(
      colors: _colors,
      currentIndex: _currentPage,
      tabController: _tabController,
      bottomBarKey: _bottomBarKey,
      body:
          (context, controller) => TabBarView(
            controller: _tabController,
            dragStartBehavior: DragStartBehavior.down,
            physics: const NeverScrollableScrollPhysics(),
            children: [_buildTabPage(0), _buildTabPage(1)],
          ),
      fab: _buildFab(),
      children: [
        Tab(
          icon: const Icon(Icons.check_box_outlined),
          text: 'todo_todoTab'.tr,
        ),
        Tab(icon: const Icon(Icons.history), text: 'todo_historyTab'.tr),
      ],
    );
  }

  // 构建tab页面
  Widget _buildTabPage(int index) {
    switch (index) {
      case 0:
        // 使用 EventListenerContainer 监听任务事件和同步刷新事件来触发 UI 更新
        // AnimatedBuilder 会监听 taskController 的变化并重建 UI
        return EventListenerContainer(
          events: [
            'task_added',
            'task_updated',
            'task_deleted',
            'task_completed',
            'todo_refresh', // 同步后触发的刷新事件
            'sync_data_updated', // 通用同步数据更新事件
          ],
          onEvent: () {}, // AnimatedBuilder 会处理更新
          child: _buildTaskListView(),
        );
      case 1:
        return _buildHistoryView();
      default:
        return _buildTaskListView();
    }
  }

  /// 构建过滤条件列表
  List<FilterItem> _buildFilterItems() {
    // 获取所有可用标签
    final availableTags = _plugin.taskController.getAllTags();

    return [
      // 0. 排序选项
      FilterItem(
        id: 'sortBy',
        title: 'todo_sortBy'.tr,
        type: FilterType.custom,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildSortFilter(
            context: context,
            currentValue: currentValue,
            onChanged: (value) {
              onChanged(value);
              // 将字符串转换为 SortBy 枚举
              if (value != null) {
                _plugin.taskController.setSortBy(
                  SortBy.values.firstWhere(
                    (e) => e.toString() == value,
                    orElse: () => SortBy.dueDate,
                  ),
                );
              } else {
                _plugin.taskController.setSortBy(SortBy.dueDate);
              }
            },
            options: {
              'SortBy.dueDate': 'todo_sortByDueDate'.tr,
              'SortBy.priority': 'todo_sortByPriority'.tr,
              'SortBy.custom': 'todo_customSort'.tr,
            },
          );
        },
        getBadge: (value) {
          if (value == null) return null;
          final labels = {
            'SortBy.dueDate': 'todo_sortByDueDate'.tr,
            'SortBy.priority': 'todo_sortByPriority'.tr,
            'SortBy.custom': 'todo_customSort'.tr,
          };
          return labels[value.toString()];
        },
        initialValue: 'SortBy.dueDate',
      ),

      // 1. 标签多选过滤
      if (availableTags.isNotEmpty)
        FilterItem(
          id: 'tags',
          title: 'todo_tags'.tr,
          type: FilterType.tagsMultiple,
          builder: (context, currentValue, onChanged) {
            return FilterBuilders.buildTagsFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              availableTags: availableTags,
            );
          },
          getBadge: FilterBuilders.tagsBadge,
        ),

      // 2. 优先级过滤
      FilterItem(
        id: 'priority',
        title: 'todo_priority'.tr,
        type: FilterType.custom,
        builder: (context, currentValue, onChanged) {
          // 优先级语义色（令牌随明暗自适应）
          final theme = DSThemeBridge.resolve(context);
          return FilterBuilders.buildPriorityFilter<TaskPriority>(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
            priorityLabels: {
              TaskPriority.q1: 'todo_q1'.tr,
              TaskPriority.q2: 'todo_q2'.tr,
              TaskPriority.q3: 'todo_q3'.tr,
              TaskPriority.q4: 'todo_q4'.tr,
            },
            priorityColors: {
              TaskPriority.q1: theme.danger,
              TaskPriority.q2: theme.success,
              TaskPriority.q3: theme.warning,
              TaskPriority.q4: theme.primary,
            },
          );
        },
        getBadge:
            (value) => FilterBuilders.priorityBadge(value, {
              TaskPriority.q1: 'todo_q1'.tr,
              TaskPriority.q2: 'todo_q2'.tr,
              TaskPriority.q3: 'todo_q3'.tr,
              TaskPriority.q4: 'todo_q4'.tr,
            }),
      ),

      // 3. 日期范围过滤
      FilterItem(
        id: 'dateRange',
        title: 'todo_dateRange'.tr,
        type: FilterType.dateRange,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildDateRangeFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
          );
        },
        getBadge: FilterBuilders.dateRangeBadge,
      ),

      // 4. 完成状态过滤
      FilterItem(
        id: 'status',
        title: 'todo_status'.tr,
        type: FilterType.checkbox,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildCheckboxFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
            options: {
              'showCompleted': 'todo_showCompleted'.tr,
              'showIncomplete': 'todo_showIncomplete'.tr,
            },
          );
        },
        getBadge: FilterBuilders.checkboxBadge,
        initialValue: const {'showCompleted': true, 'showIncomplete': true},
      ),
    ];
  }

  /// 应用多条件过滤
  void _applyMultiFilters(Map<String, dynamic> filters) {
    // 构建过滤参数
    final filterParams = <String, dynamic>{};

    // 排序选项（不作为过滤条件，只更新 controller）
    if (filters['sortBy'] != null) {
      final sortByValue = filters['sortBy'] as String;
      if (sortByValue.isNotEmpty) {
        _plugin.taskController.setSortBy(
          SortBy.values.firstWhere(
            (e) => e.toString() == sortByValue,
            orElse: () => SortBy.dueDate,
          ),
        );
      }
    }

    // 标签过滤
    if (filters['tags'] != null && (filters['tags'] as List).isNotEmpty) {
      filterParams['tags'] = filters['tags'];
    }

    // 优先级过滤
    if (filters['priority'] != null) {
      filterParams['priority'] = filters['priority'];
    }

    // 日期范围过滤
    if (filters['dateRange'] != null) {
      final range = filters['dateRange'] as DateTimeRange;
      filterParams['startDate'] = range.start;
      filterParams['endDate'] = range.end;
    }

    // 完成状态过滤
    if (filters['status'] != null) {
      final status = filters['status'] as Map<String, bool>;
      filterParams['showCompleted'] = status['showCompleted'] ?? true;
      filterParams['showIncomplete'] = status['showIncomplete'] ?? true;
    }

    // 保存过滤状态到 View 层
    _currentFilter = filterParams.isEmpty ? null : filterParams;

    // 延迟setState到当前帧结束后,避免在构建期间调用setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // 构建任务列表视图（第一个tab）
  Widget _buildTaskListView() {
    return SuperCupertinoNavigationWrapper(
      title: Text('todo_todoTasks'.tr),
      largeTitle: 'todo_todoTasks'.tr,

      enableSearchBar: true,
      searchPlaceholder: 'todo_searchTasksHint'.tr,
      enableSearchFilter: true,
      filterLabels: {
        'title': 'todo_searchTitle'.tr,
        'description': 'todo_searchDescription'.tr,
        'tag': 'todo_searchTag'.tr,
        'subtask': 'todo_searchSubtask'.tr,
      },
      onSearchChanged: (query) {
        // 实时搜索功能
        setState(() {
          _searchQuery = query;
          if (query.isEmpty) {
            _currentFilter = null;
          } else {
            _currentFilter = {'keyword': query};
          }
        });
        // 更新路由上下文
        _updateRouteContext();
      },
      onSearchFilterChanged: (filters) {
        // 处理搜索过滤器变化
        setState(() {
          final currentQuery = _searchQuery;
          if (currentQuery.isNotEmpty) {
            // 保存搜索过滤设置
            _currentFilter = {
              'keyword': currentQuery,
              'searchFilters': filters,
            };
          }
        });
      },
      searchBody: _buildSearchResults(),

      // 启用多条件过滤
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      multiFilterBarHeight: 50,
      onMultiFilterChanged: _applyMultiFilters,

      actions: [
        // 视图切换按钮（SuperCupertino actions 需外包 DSThemeBridge，陷阱 2）
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              // calendar_view_week / dashboard_outlined 无自绘等价物，用 calendar/grid 顶替
              return DSIconButton(
                icon:
                    _plugin.taskController.viewMode == ViewMode.quadrant
                        ? DsIconKind.calendar
                        : DsIconKind.grid,
                size: 40,
                color: theme.surfaceAlt,
                iconColor: theme.text,
                onPressed: _plugin.taskController.toggleViewMode,
                tooltip:
                    _plugin.taskController.viewMode == ViewMode.quadrant
                        ? '切换到周视图'
                        : '切换到四象限视图',
              );
            },
          ),
        ),
      ],
      body: AnimatedBuilder(
        animation: _plugin.taskController,
        builder: (context, _) {
          // 根据 View 的过滤状态决定使用过滤后的结果还是原始数据
          final tasks =
              _currentFilter != null
                  ? _plugin.taskController.filterTasks(_currentFilter!)
                  : _plugin.taskController.tasks;

          return _plugin.taskController.viewMode == ViewMode.quadrant
              ? TodoFourQuadrantView(
                tasks: tasks,
                onTaskTap: (task) => _showTaskDetailDialog(context, task),
                onTaskStatusChanged: (task, status) {
                  _plugin.taskController.updateTaskStatus(task.id, status);
                },
                onAddTask: (priority) {
                  NavigationHelper.openContainerWithHero(
                    context,
                    (context) => TaskForm(
                      taskController: _plugin.taskController,
                      reminderController: _plugin.reminderController,
                      initialPriority: priority,
                    ),
                    transitionDuration: const Duration(milliseconds: 300),
                  );
                },
              )
              : TodoWeekView(
                tasks: tasks,
                onTaskTap: (task) => _showTaskDetailDialog(context, task),
                onTaskStatusChanged: (task, status) {
                  _plugin.taskController.updateTaskStatus(task.id, status);
                },
                onAddTask: (date) {
                  NavigationHelper.openContainerWithHero(
                    context,
                    (context) => TaskForm(
                      taskController: _plugin.taskController,
                      reminderController: _plugin.reminderController,
                      initialStartDate: date,
                    ),
                    transitionDuration: const Duration(milliseconds: 300),
                  );
                },
              );
        },
      ),
    );
  }

  // 构建历史记录视图（第二个tab）
  Widget _buildHistoryView() {
    return SuperCupertinoNavigationWrapper(
      title: Text('todo_historyTitle'.tr),
      largeTitle: 'todo_historyTitle'.tr,

      actions: [
        // 清空历史按钮（SuperCupertino actions 需外包 DSThemeBridge，陷阱 2）
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.trash,
                size: 40,
                color: theme.surfaceAlt,
                iconColor: theme.text,
                onPressed: () async {
                  final confirmed = await showDSDialog<bool>(
                    context: context,
                    theme: DSThemeBridge.resolve(context),
                    builder:
                        (dialogContext) => DSDialog(
                          title: 'todo_clearHistoryTitle'.tr,
                          message: 'todo_clearHistoryMessage'.tr,
                          cancelText: 'todo_cancel'.tr,
                          confirmText: 'todo_clearHistoryAction'.tr,
                          confirmVariant: DSButtonVariant.destructive,
                          onConfirm: () => Navigator.pop(dialogContext, true),
                          onCancel: () => Navigator.pop(dialogContext, false),
                        ),
                  );

                  if (confirmed == true) {
                    _plugin.taskController.clearHistory();
                    setState(() {});
                  }
                },
              );
            },
          ),
        ),
      ],
      body: HistoryCompletedView(
        completedTasks: _plugin.taskController.completedTasks,
        taskController: _plugin.taskController,
      ),
    );
  }

  // 显示任务详情对话框
  void _showTaskDetailDialog(BuildContext context, Task task) {
    SmoothBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => TodoItemDetail(
            task: task,
            taskController: _plugin.taskController,
          ),
    );
  }

  // 构建搜索结果视图
  Widget _buildSearchResults() {
    return DSThemeBridge(
      // SuperCupertino 的搜索体在主题树之外，自备主题桥
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return AnimatedBuilder(
            animation: _plugin.taskController,
            builder: (context, _) {
              // 搜索结果使用 View 的过滤状态
              final searchTasks =
                  _currentFilter != null
                      ? _plugin.taskController.filterTasks(_currentFilter!)
                      : _plugin.taskController.tasks;

              if (_searchQuery.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DsIcon(DsIconKind.search, size: 64, color: theme.textSub),
                      const SizedBox(height: 16),
                      Text(
                        'todo_searchInputHint'.tr,
                        style: DsTypography.body.copyWith(color: theme.text),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'todo_searchSupportHint'.tr,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (searchTasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // inbox 无自绘图标等价物，保留 Material 图标
                      Icon(Icons.inbox, size: 64, color: theme.textSub),
                      const SizedBox(height: 16),
                      Text(
                        'todo_noMatchingTasks'.tr,
                        style: DsTypography.body.copyWith(color: theme.text),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'todo_tryOtherKeywords'.tr,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // 使用简单的列表视图显示搜索结果
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: searchTasks.length,
                separatorBuilder:
                    (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final task = searchTasks[index];
                  return _buildSimpleTaskCard(task);
                },
              );
            },
          );
        },
      ),
    );
  }

  // 构建简单的任务卡片（用于搜索结果）
  Widget _buildSimpleTaskCard(Task task) {
    final theme = DSThemeBridge.resolve(context);
    final isDone = task.status == TaskStatus.done;
    final isOverdue =
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !isDone;

    Color borderColor;
    if (isDone) {
      borderColor = Colors.transparent;
    } else {
      // 优先级语义色（令牌随明暗自适应）
      switch (task.priority) {
        case TaskPriority.q1:
          borderColor = theme.danger;
          break;
        case TaskPriority.q2:
          borderColor = theme.success;
          break;
        case TaskPriority.q3:
          borderColor = theme.warning;
          break;
        case TaskPriority.q4:
          borderColor = theme.primary;
          break;
      }
    }

    return GestureDetector(
      onTap: () => _showTaskDetailDialog(context, task),
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: borderColor, width: 4)),
        ),
        child: Opacity(
          opacity: isDone ? 0.6 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Box
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  // task.icon 为持久化 IconData，保留 Material 图标
                  child: Icon(
                    task.icon ?? Icons.assignment,
                    color: theme.text,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: DsTypography.body.copyWith(
                          fontSize: 16,
                          color: theme.text,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...task.tags.map((tag) => _buildSimpleTag(tag)),
                          if (task.priority == TaskPriority.q1)
                            _buildSimpleTag('todo_q1'.tr, isHighPriority: true),
                          if (isOverdue)
                            _buildSimpleTag('todo_overdue'.tr, isOverdue: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (task.dueDate != null)
                        Text(
                          DateFormat('MMM d').format(task.dueDate!),
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                    ],
                  ),
                ),
                // Checkbox
                SizedBox(
                  width: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final newStatus =
                              isDone ? TaskStatus.todo : TaskStatus.done;
                          _plugin.taskController.updateTaskStatus(
                            task.id,
                            newStatus,
                          );
                        },
                        child: DSCheckbox(
                          value: isDone,
                          onChanged: (value) {
                            final newStatus =
                                value == true
                                    ? TaskStatus.done
                                    : TaskStatus.todo;
                            _plugin.taskController.updateTaskStatus(
                              task.id,
                              newStatus,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建简单的标签
  Widget _buildSimpleTag(
    String text, {
    bool isHighPriority = false,
    bool isOverdue = false,
  }) {
    final theme = DSThemeBridge.resolve(context);
    final Color bg;
    final Color fg;

    if (isOverdue) {
      bg = theme.danger.withValues(alpha: 0.15);
      fg = theme.danger;
    } else if (isHighPriority) {
      bg = theme.secondary.withValues(alpha: 0.15);
      fg = theme.secondary;
    } else {
      bg = theme.surfaceAlt;
      fg = theme.textSub;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: DsTypography.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
