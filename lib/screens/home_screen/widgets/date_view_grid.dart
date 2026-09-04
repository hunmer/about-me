import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/widgets/event_listener_container.dart';

/// 日期视图网格
///
/// 展示所有标记为日期驱动（isDateDriven）的小组件，
/// 只显示当前选中日期已有数据（hasDateData 通过）的卡片，不展示空占位。
///
/// 数据增删（如新建待办/写日记）或切换日期时自动重新检查。
/// 新插件注册日期卡片后会自动出现在这里。
class HomeDateViewGrid extends StatefulWidget {
  /// 网格列数（与主页默认网格一致，4 列可容纳 2/4 宽的卡片）
  final int crossAxisCount;

  const HomeDateViewGrid({super.key, this.crossAxisCount = 4});

  @override
  State<HomeDateViewGrid> createState() => _HomeDateViewGridState();
}

class _HomeDateViewGridState extends State<HomeDateViewGrid> {
  /// 有数据的日期卡片（null 表示尚未检查完成）
  List<HomeWidget>? _visibleWidgets;

  /// 防止过期结果覆盖（日期快速切换时）
  DateTime? _checkingFor;

  @override
  void initState() {
    super.initState();
    _checkVisibleWidgets();
  }

  /// 检查各日期卡片在当前选中日期是否有数据
  Future<void> _checkVisibleWidgets() async {
    final date = HomeDateController().date;
    _checkingFor = date;

    final candidates =
        HomeWidgetRegistry()
            .getAllWidgets()
            .where((w) => w.isDateDriven)
            .toList();

    final results = await Future.wait(
      candidates.map((w) async {
        final checker = w.hasDateData;
        if (checker == null) return true;
        try {
          return await checker(date);
        } catch (_) {
          return false;
        }
      }),
    );

    // 检查期间日期已变化，丢弃本次结果
    if (!mounted || _checkingFor != date) return;

    setState(() {
      _visibleWidgets = [
        for (var i = 0; i < candidates.length; i++)
          if (results[i]) candidates[i],
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    // 日期变化或数据增删后重新检查可见卡片
    //
    // 各日期卡插件的数据事件（与各自卡片的刷新事件保持一致）。
    // 注意：不要加入会在 hasDateData 检查过程中被广播的事件（如
    // memorial_day_cache_updated，day 的检查会 reloadData 并广播它），避免循环刷新。
    return EventListenerContainer(
      events: const [
        // todo / diary
        'task_added',
        'task_deleted',
        'task_completed',
        'diary_entry_created',
        'diary_entry_updated',
        'diary_entry_deleted',
        // calendar
        'calendar_event_added',
        'calendar_event_updated',
        'calendar_event_deleted',
        'calendar_event_completed',
        // bill
        'bill_added',
        'bill_deleted',
        'account_added',
        'account_deleted',
        // activity
        'activity_added',
        'activity_updated',
        'activity_deleted',
        // tracker
        'onRecordAdded',
        'tracker_cache_updated',
        // checkin
        'checkin_completed',
        'checkin_cancelled',
        'checkin_reset',
        'checkin_deleted',
        // habits
        'habit_completion_record_saved',
        'habit_data_changed',
        'habits_cache_updated',
        // day（memorial_day_cache_updated 除外，见上）
        'memorial_day_added',
        'memorial_day_updated',
        'memorial_day_deleted',
        // notes
        'note_added',
        'note_updated',
        'note_deleted',
        // calendar_album
        'calendar_entry_added',
        'calendar_entry_updated',
        'calendar_entry_deleted',
      ],
      onEvent: _checkVisibleWidgets,
      child: _DateControllerListener(
        onChanged: _checkVisibleWidgets,
        child: DSThemeBridge(child: Builder(builder: _buildContent)),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final dateWidgets =
        HomeWidgetRegistry()
            .getAllWidgets()
            .where((w) => w.isDateDriven)
            .toList();

    // 未注册任何日期卡片
    if (dateWidgets.isEmpty) {
      return _buildHint(
        theme,
        icon: DsIconKind.calendar,
        message: 'home_dateViewEmpty'.tr,
      );
    }

    final visible = _visibleWidgets;
    if (visible == null) {
      return Center(child: DSLoadingDots(color: theme.textSub));
    }

    // 该日期没有可展示的数据
    if (visible.isEmpty) {
      return _buildHint(
        theme,
        icon: DsIconKind.block,
        message: 'home_dateViewNoData'.tr,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: StaggeredGrid.count(
        crossAxisCount: widget.crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children:
            visible.map((widgetDef) {
              return StaggeredGridTile.count(
                crossAxisCellCount: _clampCells(widgetDef.defaultSize.width, 2),
                mainAxisCellCount: _clampCells(widgetDef.defaultSize.height, 2),
                child: _buildCard(context, theme, widgetDef),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildHint(
    AppThemeData theme, {
    required DsIconKind icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DsIcon(icon, size: 48, color: theme.disabled.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text(
            message,
            style: DsTypography.body.copyWith(color: theme.disabled),
          ),
        ],
      ),
    );
  }

  /// 网格数归一化：自定义尺寸(-1)回退到 fallback，并限制不超过列数
  int _clampCells(int value, int fallback) {
    var cells = value < 1 ? fallback : value;
    if (cells > widget.crossAxisCount) cells = widget.crossAxisCount;
    return cells;
  }

  /// 构建单个日期卡片（带与主页卡片一致的圆角外观）
  Widget _buildCard(
    BuildContext context,
    AppThemeData theme,
    HomeWidget widgetDef,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: theme.radii.md,
      ),
      clipBehavior: Clip.antiAlias,
      child: widgetDef.build(context, const {}, widgetDef.defaultSize),
    );
  }
}

/// 监听主页日期控制器变化（日期或排序变化时重新检查）
class _DateControllerListener extends StatefulWidget {
  final VoidCallback onChanged;
  final Widget child;

  const _DateControllerListener({required this.onChanged, required this.child});

  @override
  State<_DateControllerListener> createState() =>
      _DateControllerListenerState();
}

class _DateControllerListenerState extends State<_DateControllerListener> {
  @override
  void initState() {
    super.initState();
    HomeDateController().addListener(widget.onChanged);
  }

  @override
  void dispose() {
    HomeDateController().removeListener(widget.onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
