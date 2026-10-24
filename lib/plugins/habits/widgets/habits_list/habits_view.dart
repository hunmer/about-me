import 'package:get/get.dart';

import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/habits/habits_plugin.dart';
import 'package:aboutme/plugins/habits/models/habit.dart';
import 'package:aboutme/plugins/habits/widgets/habit_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/habits/controllers/habit_controller.dart';
import 'package:aboutme/plugins/habits/widgets/habits_list/habit_card.dart';
import 'package:aboutme/plugins/habits/controllers/timer_controller.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:aboutme/plugins/habits/widgets/habit_action_sheet.dart';
import 'package:aboutme/plugins/habits/screens/habit_monthly_list_screen.dart';
import 'package:aboutme/plugins/habits/models/completion_record.dart';
import 'package:aboutme/plugins/habits/widgets/timer_dialog.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/habit_heatmap_card.dart';

/// 搜索结果Widget
class HabitSearchResultsWidget extends StatelessWidget {
  final List<Habit> habits;
  final HabitController controller;
  final Function(Habit)? onHabitTap;
  final Function(Habit)? onHabitLongPress;

  const HabitSearchResultsWidget({
    super.key,
    required this.habits,
    required this.controller,
    this.onHabitTap,
    this.onHabitLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final habitsPlugin =
        PluginManager.instance.getPlugin('habits') as HabitsPlugin?;
    final skillController = habitsPlugin?.getSkillController();

    return MasonryGridView.count(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      crossAxisCount: 2,
      // ≥ 贴条出血,避免上一行贴条压盖
      mainAxisSpacing: 16,
      crossAxisSpacing: 8,
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final skill =
            habit.skillId != null
                ? skillController?.getSkillById(habit.skillId!)
                : null;

        // 手绘便签:随机倾斜 + 贴条(角度由 habit.id 哈希确定)
        return HandDrawnStickyItem(
          tiltKey: habit.id,
          child: HabitCard(
            key: ValueKey('${habit.id}_search'),
            habit: habit,
            skill: skill,
            controller: controller,
            onTap: () => onHabitTap?.call(habit),
            onLongPress: () => onHabitLongPress?.call(habit),
          ),
        );
      },
    );
  }
}

class CombinedHabitsView extends StatefulWidget {
  final HabitController controller;
  final String? habitId;

  const CombinedHabitsView({super.key, required this.controller, this.habitId});

  @override
  State<CombinedHabitsView> createState() => _CombinedHabitsViewState();
}

class _CombinedHabitsViewState extends State<CombinedHabitsView> {
  List<Habit> _habits = [];
  List<Habit> _filteredHabits = []; // 搜索过滤后的习惯列表
  final Map<String, bool> _timingStatus = {};
  final int _refreshKey = 0; // 用于强制刷新 HabitCard
  String _selectedGroup = '全部'; // 当前选中的分组
  bool _isHeatmapView = false; // false=卡片网格视图, true=热力图视图
  final Map<String, List<CompletionRecord>> _records = {}; // 各习惯完成记录（热力图数据源）

  @override
  void initState() {
    super.initState();
    final habitsPlugin =
        PluginManager.instance.getPlugin('habits') as HabitsPlugin?;
    widget.controller.addTimerModeListener(_onTimerModeChanged);
    final activeTimers = habitsPlugin!.timerController.getActiveTimers();
    _timingStatus.addAll(activeTimers);
    EventManager.instance.subscribe('habit_timer_started', _onTimerStarted);
    EventManager.instance.subscribe('habit_timer_stopped', _onTimerStopped);
    EventManager.instance.subscribe(
      'habit_completion_record_saved',
      _onRecordSaved,
    );
    // 习惯增删改后刷新列表（创建入口在 FAB，不在本组件内）
    EventManager.instance.subscribe(
      'habits_cache_updated',
      _onHabitsCacheUpdated,
    );
    _loadHabits();
    _loadViewMode();

    // 设置路由上下文
    _updateRouteContext();

    // 如果有 habitId，在加载完成后显示习惯详情
    if (widget.habitId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showHabitDetailById(widget.habitId!);
      });
    }
  }

  @override
  void dispose() {
    EventManager.instance.unsubscribe('habit_timer_started', _onTimerStarted);
    EventManager.instance.unsubscribe('habit_timer_stopped', _onTimerStopped);
    EventManager.instance.unsubscribe(
      'habit_completion_record_saved',
      _onRecordSaved,
    );
    EventManager.instance.unsubscribe(
      'habits_cache_updated',
      _onHabitsCacheUpdated,
    );
    super.dispose();
  }

  /// 习惯数据变更（创建/编辑/删除）后重新加载列表
  void _onHabitsCacheUpdated(EventArgs args) {
    if (mounted) {
      _loadHabits();
      if (_isHeatmapView) _loadRecords();
    }
  }

  void _onTimerStarted(EventArgs args) {
    if (args is HabitTimerEventArgs) {
      setState(() {
        _timingStatus[args.habitId] = args.isRunning;
      });
    }
  }

  void _onTimerStopped(EventArgs args) {
    if (args is HabitTimerEventArgs) {
      setState(() {
        _timingStatus[args.habitId] = args.isRunning;
      });
    }
  }

  void _onTimerModeChanged(String habitId, bool isCountdown) {
    if (mounted) {
      setState(() {});
    }
  }

  /// 打卡记录变更时刷新热力图数据
  void _onRecordSaved(EventArgs args) {
    if (mounted && _isHeatmapView) {
      _loadRecords();
    }
  }

  /// 切换卡片网格/热力图视图
  void _toggleView() {
    setState(() => _isHeatmapView = !_isHeatmapView);
    _saveViewMode();
    if (_isHeatmapView) {
      _loadRecords();
    }
  }

  /// 恢复持久化的视图模式
  Future<void> _loadViewMode() async {
    final res = await AboutmeDataService.instance.get(
      'habits', 'getSettings',
    );
    final data = res['success'] == true ? res['data'] : null;
    if (mounted && data is Map && data['heatmapView'] == true) {
      setState(() => _isHeatmapView = true);
      _loadRecords();
    }
  }

  /// 持久化视图模式
  Future<void> _saveViewMode() async {
    await AboutmeDataService.instance.call('habits', 'updateSettings', {
      'heatmapView': _isHeatmapView,
    });
  }

  /// 加载所有习惯的完成记录
  Future<void> _loadRecords() async {
    final habitsPlugin =
        PluginManager.instance.getPlugin('habits') as HabitsPlugin?;
    final recordController = habitsPlugin?.getRecordController();
    if (recordController == null) return;

    final records = <String, List<CompletionRecord>>{};
    for (final habit in _habits) {
      records[habit.id] = await recordController.getHabitCompletionRecords(
        habit.id,
      );
    }
    if (mounted) {
      setState(() => _records.addAll(records));
    }
  }

  /// 将完成记录转为 7x10 热力图矩阵（最近70天，值1-3按当日打卡次数分档，今日未打卡为4）
  List<List<int>> _buildHeatmapCells(List<CompletionRecord> records) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final countByDay = <DateTime, int>{};
    for (final record in records) {
      final day = DateTime(record.date.year, record.date.month, record.date.day);
      countByDay[day] = (countByDay[day] ?? 0) + 1;
    }

    final cells = List.generate(7, (_) => List.filled(10, 0));
    for (var i = 0; i < 70; i++) {
      final date = today.subtract(Duration(days: 69 - i));
      final count = countByDay[date] ?? 0;
      cells[i ~/ 10][i % 10] =
          count > 0 ? count.clamp(1, 3) : (date == today ? 4 : 0);
    }
    return cells;
  }

  /// 今日打卡次数
  int _todayCheckInCount(List<CompletionRecord> records) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return records
        .where(
          (r) => DateTime(r.date.year, r.date.month, r.date.day) == today,
        )
        .length;
  }

  /// 打开开始习惯计时弹窗（与 HabitCard 的开始按钮一致）
  Future<void> _showTimerDialog(Habit habit) async {
    final habitsPlugin =
        PluginManager.instance.getPlugin('habits') as HabitsPlugin?;
    final timerController = habitsPlugin?.timerController;
    if (timerController == null) return;

    await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => TimerDialog(
            habit: habit,
            controller: widget.controller,
            initialTimerData: timerController.getTimerData(habit.id),
          ),
    );
  }

  Future<void> _loadHabits() async {
    // 启动自动进入本页时，controller 首次数据加载可能尚未完成
    await widget.controller.initialized;
    final habits = widget.controller.getHabits();
    if (mounted) {
      setState(() {
        _habits = habits;
        _filteredHabits = habits; // 初始化时显示所有习惯
      });
    }
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前页面状态
  void _updateRouteContext() {
    RouteHistoryManager.updateCurrentContext(
      pageId: '/habits_list',
      title: '习惯列表',
      params: {},
    );
  }

  /// 根据搜索关键词过滤习惯
  void _filterHabits(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredHabits = _habits;
      });
    } else {
      setState(() {
        _filteredHabits =
            _habits
                .where(
                  (habit) =>
                      habit.title.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      });
    }
  }

  /// 获取所有分组(用于过滤栏)
  List<String> get _groups {
    final g =
        _habits.map((habit) => habit.group ?? '未分组').toSet().toList()..sort();
    return ['全部', ...g];
  }

  /// 选择分组
  void _selectGroup(String group) {
    setState(() {
      _selectedGroup = group;
    });
    // 更新路由上下文
    _updateRouteContext();
  }

  /// 根据 ID 显示习惯详情（用于从小组件跳转）
  Future<void> _showHabitDetailById(String habitId) async {
    // 等待习惯数据加载完成
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final habit = _habits.cast<Habit?>().firstWhere(
      (h) => h?.id == habitId,
      orElse: () => null,
    );

    if (habit != null && mounted) {
      _showHabitForm(context, habit);
    }
  }

  /// 根据选中的分组过滤习惯
  List<Habit> get _filteredByGroup {
    if (_selectedGroup == '全部') {
      return _habits;
    } else {
      return _habits
          .where((habit) => (habit.group ?? '未分组') == _selectedGroup)
          .toList();
    }
  }

  Future<void> _showHabitForm(BuildContext context, [Habit? habit]) async {
    await HabitFormSheet.show(
      context,
      habit: habit,
      onSave: (updated) async {
        await widget.controller.saveHabit(updated);
        _loadHabits();
      },
      onDelete: (habit) async {
        await widget.controller.deleteHabit(habit.id);
        _loadHabits();
      },
    );
  }

  /// 点击习惯卡片，进入习惯月份列表视图
  void _onHabitTap(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => HabitMonthlyListScreen(
              habitId: habit.id,
              habitTitle: habit.title,
            ),
      ),
    );
  }

  /// 长按习惯卡片，显示操作抽屉
  void _onHabitLongPress(Habit habit) async {
    await HabitActionSheet.show(
      context: context,
      onEdit: () => _showHabitForm(context, habit),
      onDelete: () async {
        final confirmed = await showDSDialog<bool>(
          context: context,
          theme: DSThemeBridge.resolve(context),
          builder:
              (context) => DSDialog(
                title: 'habits_confirmDelete'.tr,
                message: 'habits_confirmDeleteHabit'.tr,
                cancelText: 'habits_cancel'.tr,
                confirmText: 'habits_delete'.tr,
                confirmVariant: DSButtonVariant.destructive,
                onConfirm: () => Navigator.of(context).pop(true),
              ),
        );

        if (confirmed == true) {
          await widget.controller.deleteHabit(habit.id);
          _loadHabits();
        }
      },
    );
  }

  Widget _buildCardView(List<Habit> habits) {
    final habitsPlugin =
        PluginManager.instance.getPlugin('habits') as HabitsPlugin?;
    final skillController = habitsPlugin?.getSkillController();

    return MasonryGridView.count(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      crossAxisCount: 2,
      // ≥ 贴条出血,避免上一行贴条压盖
      mainAxisSpacing: 16,
      crossAxisSpacing: 8,
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final skill =
            habit.skillId != null
                ? skillController?.getSkillById(habit.skillId!)
                : null;

        // 手绘便签:随机倾斜 + 贴条(角度由 habit.id 哈希确定)
        return HandDrawnStickyItem(
          tiltKey: habit.id,
          child: HabitCard(
            key: ValueKey('${habit.id}_$_refreshKey'),
            habit: habit,
            skill: skill,
            controller: widget.controller,
            onTap: () => _onHabitTap(habit),
            onLongPress: () => _onHabitLongPress(habit),
          ),
        );
      },
    );
  }

  /// 热力图视图色板（按习惯 id 稳定分配）
  static const _heatmapThemes = [
    HabitHeatmapTheme.drinkWater,
    HabitHeatmapTheme.journaling,
    HabitHeatmapTheme.playDog,
    HabitHeatmapTheme.read,
  ];

  Widget _buildHeatmapView(List<Habit> habits) {
    return MasonryGridView.count(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 8,
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final records = _records[habit.id] ?? const [];
        final codePoint = int.tryParse(habit.icon ?? '');

        return AspectRatio(
          aspectRatio: 0.82,
          child: HabitHeatmapCard(
            key: ValueKey('heatmap_${habit.id}_$_refreshKey'),
            inline: true,
            title: habit.title,
            icon:
                codePoint != null
                    ? dynamicIconData(codePoint, fontFamily: 'MaterialIcons')
                    : Icons.auto_awesome,
            cells: _buildHeatmapCells(records),
            checkInCount: _todayCheckInCount(records),
            theme: _heatmapThemes[habit.id.hashCode % _heatmapThemes.length],
            size: const Large3Size(scale: 0.8),
            onCheckIn: () => _showTimerDialog(habit),
          ),
        );
      },
    );
  }

  /// 构建分组过滤栏
  Widget _buildFilterBar() {
    final groups = _groups;
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DSThemeBridge(
            child: DSChipBar(
              labels: groups,
              selected: groups.indexOf(_selectedGroup).clamp(
                0,
                groups.length - 1,
              ),
              onChanged: (index) => _selectGroup(groups[index]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ds = AppTheme.of(context);
    return SuperCupertinoNavigationWrapper(
      title: Text('habits_habits'.tr),
      largeTitle: 'habits_habits'.tr,
      enableLargeTitle: true,

      // ========== 搜索相关配置 ==========
      enableSearchBar: true, // 启用搜索栏
      searchPlaceholder: 'habits_searchHabitPlaceholder'.tr, // 搜索栏占位符
      onSearchChanged: (query) {
        // 实时搜索，无需等待用户提交
        _filterHabits(query);
      },
      onSearchSubmitted: (query) {
        // 搜索提交时的回调（可选）
        _filterHabits(query);
      },
      searchBody: HabitSearchResultsWidget(
        habits: _filteredHabits,
        controller: widget.controller,
        onHabitTap: _onHabitTap,
        onHabitLongPress: _onHabitLongPress,
      ), // 搜索结果页面
      // ========== 过滤栏配置 ==========
      enableFilterBar: true,
      filterBarChild: _buildFilterBar(),
      actions: [
        DSIconButton(
          icon: _isHeatmapView ? DsIconKind.grid : DsIconKind.chart,
          size: 36,
          color: ds.surfaceAlt,
          iconColor: _isHeatmapView ? ds.primary : ds.textSub,
          tooltip: _isHeatmapView ? '切换为卡片视图' : '切换为热力图视图',
          onPressed: _toggleView,
        ),
      ],
      body:
          _isHeatmapView
              ? _buildHeatmapView(_filteredByGroup)
              : _buildCardView(_filteredByGroup),
    );
  }
}
