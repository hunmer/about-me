import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cutout_stat_grid_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/illustrated_metric_card.dart';
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

  /// 隐藏的卡片类型 id（日程页多条件过滤栏筛选出的取消项）
  final Set<String> hiddenWidgetIds;

  const HomeDateViewGrid({
    super.key,
    this.crossAxisCount = 4,
    this.hiddenWidgetIds = const {},
  });

  @override
  State<HomeDateViewGrid> createState() => _HomeDateViewGridState();
}

class _HomeDateViewGridState extends State<HomeDateViewGrid> {
  /// 有数据的日期卡片（null 表示尚未检查完成）
  List<HomeWidget>? _visibleWidgets;

  /// 各卡片的当日统计（供公共展示组件渲染；无条目的卡片回退自身 builder）
  Map<String, List<DateStatItem>> _statsById = {};

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

    final candidates = HomeWidgetRegistry()
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

    // 拉取各卡片当日统计（公共展示组件的数据来源）
    final statsResults = await Future.wait(
      candidates.map((w) async {
        final provider = w.dateStatsProvider;
        if (provider == null) return null;
        try {
          return await provider(date);
        } catch (_) {
          return null;
        }
      }),
    );

    // 检查期间日期已变化，丢弃本次结果
    if (!mounted || _checkingFor != date) return;

    setState(() {
      _statsById = {
        for (var i = 0; i < candidates.length; i++)
          if (statsResults[i] != null && statsResults[i]!.isNotEmpty)
            candidates[i].id: statsResults[i]!,
      };
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
        'task_updated',
        'task_deleted',
        'task_completed',
        // 任务列表加载完成（首载/远端同步重载）后重查
        'todo_cache_updated',
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
    final dateWidgets = HomeWidgetRegistry()
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

    // 应用卡片类型筛选（日程页多条件过滤栏）
    final shown = widget.hiddenWidgetIds.isEmpty
        ? visible
        : visible.where((w) => !widget.hiddenWidgetIds.contains(w.id)).toList();

    // 全部被筛掉时提示与"该日期无数据"区分开
    if (shown.isEmpty) {
      return _buildHint(
        theme,
        icon: DsIconKind.block,
        message: visible.isEmpty
            ? 'home_dateViewNoData'.tr
            : 'home_dateViewEmpty'.tr,
      );
    }

    return SingleChildScrollView(
      // 顶部留贴条出血(自包滚动容器需手动保证,见 design.md §11)
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      child: StaggeredGrid.count(
        crossAxisCount: widget.crossAxisCount,
        // ≥ 贴条出血,避免上一行贴条压盖
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        children: [
          for (var index = 0; index < shown.length; index++)
            StaggeredGridTile.count(
              crossAxisCellCount: _tileWidth(shown[index]),
              mainAxisCellCount: _tileHeight(shown[index]),
              // 手绘便签:随机倾斜 + 小号贴条(4 列窄卡片,§11.2)
              child: HandDrawnStickyItem(
                tiltKey: shown[index].id,
                tapeWidth: 56,
                tapeHeight: 18,
                child: _buildCard(context, theme, shown[index], index),
              ),
            ),
        ],
      ),
    );
  }

  /// 是否用插画指标卡展示（否则用切角统计卡）；按 id 稳定交替，两种组件都会出现
  bool _useIllustrated(HomeWidget widgetDef) => widgetDef.id.hashCode.isEven;

  /// 公共展示卡（插画指标卡）占整行，切角统计卡半行；无统计时用默认尺寸
  int _tileWidth(HomeWidget widgetDef) {
    if (_statsById[widgetDef.id] == null) {
      return _clampCells(widgetDef.defaultSize.width, 2);
    }
    return _useIllustrated(widgetDef) ? widget.crossAxisCount : 2;
  }

  int _tileHeight(HomeWidget widgetDef) {
    if (_statsById[widgetDef.id] == null) {
      return _clampCells(widgetDef.defaultSize.height, 2);
    }
    return 2;
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

  /// 构建单个日期卡片
  ///
  /// 提供了当日统计的小组件用公共展示组件渲染：
  /// 插画指标卡（单指标 + 插画）/ 切角统计卡（多指标竖排）；
  /// 未提供统计的回退小组件自身的 builder（手绘墨线底，见 design.md §9）
  Widget _buildCard(
    BuildContext context,
    AppThemeData theme,
    HomeWidget widgetDef,
    int index,
  ) {
    final stats = _statsById[widgetDef.id];
    if (stats == null || stats.isEmpty) {
      return WiredDraw(
        child: ClipRRect(
          borderRadius: theme.radii.md,
          child: Container(
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: theme.surfaceAlt,
              radius: theme.radii.md,
              // 列表项传唯一 seed 让墨迹有变化(§9.4)
              seed: widgetDef.id.hashCode & 0x7fffffff,
            ),
            child: widgetDef.build(context, const {}, widgetDef.defaultSize),
          ),
        ),
      );
    }

    final color = widgetDef.color ?? theme.primary;
    // 窄屏（列数减少）时同步缩小公共展示卡的内部布局
    final cardScale = ((widget.crossAxisCount / 4).clamp(0.6, 1.0) * 0.85)
        .toDouble();
    return _useIllustrated(widgetDef)
        ? _buildIllustratedCard(theme, widgetDef, stats.first, color, cardScale)
        : _buildCutoutCard(theme, widgetDef, stats, color, cardScale);
  }

  /// 插画指标卡：插件主题色纸底 + 手绘图标插画 + 首条统计（占整行）
  Widget _buildIllustratedCard(
    AppThemeData theme,
    HomeWidget widgetDef,
    DateStatItem stat,
    Color color,
    double cardScale,
  ) {
    return IllustratedMetricCardWidget(
      inline: true,
      showAction: false,
      size: WideSize(scale: cardScale),
      data: IllustratedMetricData(
        title: widgetDef.name,
        value: stat.value,
        unit: stat.unit,
        icon: widgetDef.icon,
        backgroundColor: color.withValues(alpha: 0.2),
        illustrationBackgroundColor: color.withValues(alpha: 0.4),
        iconColor: _darken(color),
      ),
    );
  }

  /// 切角统计卡：各统计项竖排（窄半行卡片），插件图标徽章点缀
  Widget _buildCutoutCard(
    AppThemeData theme,
    HomeWidget widgetDef,
    List<DateStatItem> stats,
    Color color,
    double cardScale,
  ) {
    return CutoutStatGridCardWidget(
      inline: true,
      direction: Axis.vertical,
      size: LargeSize(scale: cardScale),
      title: widgetDef.name,
      backgroundColor: color.withValues(alpha: 0.12),
      items: [
        for (final stat in stats.take(2))
          CutoutStatItemData(
            label: stat.label,
            value: stat.value,
            unit: stat.unit,
            icon: widgetDef.icon,
            backgroundColor: color.withValues(alpha: 0.28),
            iconBackgroundColor: color.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  /// 加深颜色（图标在浅色底上保持可读）
  Color _darken(Color color, [double amount = 0.35]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
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
