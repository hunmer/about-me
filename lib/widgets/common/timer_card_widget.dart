import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'dart:async';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/plugins/timer/models/timer_task.dart';
import 'package:aboutme/plugins/timer/models/timer_item.dart';
import 'package:aboutme/core/services/timer/models/timer_state.dart';
import 'package:aboutme/plugins/timer/views/timer_task_details_page.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';

/// 计时器任务卡片小组件（手绘纸墨风）
///
/// 视觉风格：任务色实底 + 墨线抖动描边（dsSketchDecoration）+
/// 大号手写体时间数字 + 手绘圆形播放按钮 + 墨线勾勒胶囊徽章 +
/// 背景幽灵涂鸦图标。
///
/// 特性：
/// - 显示任务图标、类型徽章和名称
/// - 大号字体显示当前计时器时间
/// - 支持播放/暂停/重置控制
/// - 支持长按显示操作菜单
/// - 支持点击进入详情页
/// - 自定义颜色和样式
/// - 响应式布局适配
class TimerCardWidget extends StatefulWidget {
  /// 计时器任务数据
  final TimerTask task;

  /// 卡片点击回调
  final Function(TimerTask)? onTap;

  /// 编辑回调
  final Function(TimerTask)? onEdit;

  /// 重置回调
  final Function(TimerTask)? onReset;

  /// 删除回调
  final Function(TimerTask)? onDelete;

  /// 自定义卡片主色（可选），未指定时使用任务颜色
  final Color? borderColor;

  /// 自定义背景颜色（可选），透明时回退到主色
  final Color? backgroundColor;

  /// 自定义文字颜色（可选），未指定时根据背景亮度自动取纸色/墨色
  final Color? textColor;

  /// 是否显示操作按钮
  final bool showActionButtons;

  /// 小组件尺寸
  final HomeWidgetSize size;

  /// 是否显示分组名称
  final bool showGroup;

  /// 是否使用网格布局（当计时器数量 >= 3 时）
  final bool useGridLayout;

  /// 是否启用 Hero 转场（与详情页焦点卡片共享 tag）；
  /// 同一路由可能渲染多个相同任务卡片时（首页小组件）应保持 false
  final bool enableHero;

  const TimerCardWidget({
    super.key,
    required this.task,
    this.onTap,
    this.onEdit,
    this.onReset,
    this.onDelete,
    this.borderColor,
    this.backgroundColor,
    this.textColor,
    this.showActionButtons = true,
    this.size = const MediumSize(),
    this.showGroup = false,
    this.useGridLayout = false,
    this.enableHero = false,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory TimerCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    // 如果 task 是 JSON 数据，需要解析
    TimerTask task;
    if (props['task'] is Map<String, dynamic>) {
      task = TimerTask.fromJson(props['task']);
    } else {
      // 假设 task 是 TimerTask 对象
      task = props['task'];
    }

    return TimerCardWidget(
      task: task,
      onTap:
          props['onTap'] != null
              ? (task) => (props['onTap'] as Function)(task)
              : null,
      onEdit:
          props['onEdit'] != null
              ? (task) => (props['onEdit'] as Function)(task)
              : null,
      onReset:
          props['onReset'] != null
              ? (task) => (props['onReset'] as Function)(task)
              : null,
      onDelete:
          props['onDelete'] != null
              ? (task) => (props['onDelete'] as Function)(task)
              : null,
      borderColor:
          props['borderColor'] != null
              ? Color(props['borderColor'] as int)
              : null,
      backgroundColor:
          props['backgroundColor'] != null
              ? Color(props['backgroundColor'] as int)
              : null,
      textColor:
          props['textColor'] != null ? Color(props['textColor'] as int) : null,
      showActionButtons: props['showActionButtons'] as bool? ?? true,
      size: size,
      showGroup: props['showGroup'] as bool? ?? false,
      useGridLayout: props['useGridLayout'] as bool? ?? false,
    );
  }

  @override
  State<TimerCardWidget> createState() => _TimerCardWidgetState();
}

class _TimerCardWidgetState extends State<TimerCardWidget> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // 每秒刷新一次UI，以更新计时器显示
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ===== 颜色体系 =====

  /// 卡片主色：非透明背景色优先，否则取边框色/任务色
  Color get _cardColor {
    final bg = widget.backgroundColor;
    if (bg != null && bg.alpha > 8) return bg;
    return widget.borderColor ?? widget.task.color;
  }

  bool get _cardIsDark => _cardColor.computeLuminance() < 0.5;

  /// 卡片上的前景色（文字/图标），优先自定义文字色，
  /// 否则按卡片底色亮度取纸色/墨色（design_system 语义色板）
  Color get _onCard =>
      widget.textColor ?? (_cardIsDark ? DsColors.white : DsColors.text);

  /// 卡片墨迹 seed：按任务 id 稳定，各卡片墨线略有差异且 rebuild 不抖变
  int get _seed => widget.task.id.hashCode & 0x7FFFFFFF;

  /// 主计时器：优先正在运行的，否则取当前索引的
  TimerItem? get _primaryTimer {
    final items = widget.task.timerItems;
    if (items.isEmpty) return null;
    for (final timer in items) {
      if (timer.isRunning) return timer;
    }
    final index = widget.task.getCurrentIndex();
    return items[index.clamp(0, items.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final size = widget.size;
    final isMini = size.category == SizeCategory.mini;
    final radius = switch (size.category) {
      SizeCategory.mini => 14.0,
      SizeCategory.small => 18.0,
      SizeCategory.medium => 22.0,
      SizeCategory.large => 26.0,
      SizeCategory.xlarge => 28.0,
    };
    final padding = size.getPadding();

    // 高度自适应：不设最小高度约束，完全由内容撑开。
    // 手绘风：任务色实底 + 墨线描边，无柔影
    Widget card = Container(
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: _cardColor,
        radius: BorderRadius.circular(radius),
        strokeWidth: 2.0,
        seed: _seed,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Pressable(
          onPressed: () async {
            if (widget.onTap != null) {
              widget.onTap!(widget.task);
            } else {
              await NavigationHelper.push(
                context,
                TimerTaskDetailsPage(taskId: widget.task.id),
              );
              setState(() {});
            }
          },
          builder: (context, states) {
            final pressed = states.contains(WidgetState.pressed);
            return Transform.scale(
              scale: pressed ? 0.97 : 1.0,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 装饰层用 Positioned.fill 作为定位子节点，不参与尺寸计算，
                  // 保证卡片高度只由内容决定
                  if (!isMini)
                    Positioned.fill(
                      child: IgnorePointer(child: _buildDecorations(theme)),
                    ),
                  Padding(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isMini) ...[
                          _buildHeaderRow(theme),
                          SizedBox(height: size.getSmallSpacing() * 2),
                        ],
                        _buildFocalRow(theme, isMini),
                        if (!isMini) ...[
                          SizedBox(height: size.getSmallSpacing() * 2),
                          if (widget.useGridLayout)
                            _buildGridLayout()
                          else
                            _buildFooter(theme),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    final plainCard = card;
    if (widget.enableHero) {
      card = Hero(
        tag: 'timer_task_card_${widget.task.id}',
        child: card,
      );
    }
    // 长按弹圆盘快捷菜单（3 项以内全量进圆盘）；浮层预览用无 Hero 版本避免 tag 冲突
    return ArcContextMenu.actions(
      actions: _menuActions(widget.task),
      showMore: () => _showContextMenu(context, widget.task),
      preview: plainCard,
      child: card,
    );
  }

  // ===== 装饰层：环境圆 + 背景幽灵涂鸦图标 =====

  Widget _buildDecorations(AppThemeData theme) {
    final bigSize = switch (widget.size.category) {
      SizeCategory.small => 110.0,
      SizeCategory.medium => 160.0,
      SizeCategory.large => 210.0,
      SizeCategory.xlarge => 250.0,
      _ => 90.0,
    };
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            right: bigSize * 0.45,
            top: -bigSize * 0.3,
            child: Container(
              width: bigSize * 0.55,
              height: bigSize * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _onCard.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: -bigSize * 0.15,
            bottom: -bigSize * 0.15,
            child: WiredIcon(
              icon: widget.task.icon,
              size: bigSize,
              color: _onCard.withValues(alpha: 0.10),
              drawConfig: theme.wired.drawConfig,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 顶部徽章行 =====

  Widget _buildHeaderRow(AppThemeData theme) {
    final size = widget.size;
    final labelFontSize = (size.getSubtitleFontSize() * 0.85).clamp(9.0, 14.0);
    final primary = _primaryTimer;
    final badgeLabel =
        primary != null ? _typeLabel(primary.type) : widget.task.name;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: size.getSmallSpacing() * 3,
            vertical: size.getSmallSpacing() * 1.2,
          ),
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: _onCard.withValues(alpha: 0.15),
            stroke: _onCard.withValues(alpha: 0.5),
            strokeWidth: 1.2,
            radius: DsRadii.pill,
            seed: _seed + 1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WiredIcon(
                icon: widget.task.icon,
                size: labelFontSize * 1.2,
                color: _onCard,
                drawConfig: theme.wired.drawConfig,
              ),
              SizedBox(width: size.getSmallSpacing() * 1.5),
              Text(
                badgeLabel,
                style: DsTypography.label.copyWith(
                  fontSize: labelFontSize,
                  color: _onCard,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        ..._buildTrailingBadge(theme, labelFontSize),
      ],
    );
  }

  /// 右上角徽章：完成状态 > 任务重复轮数 > 番茄钟循环数
  List<Widget> _buildTrailingBadge(AppThemeData theme, double labelFontSize) {
    final task = widget.task;
    final primary = _primaryTimer;

    String? label;
    DsIconKind? icon;
    if (task.isCompleted) {
      label = 'timer_completed'.tr;
      icon = DsIconKind.check;
    } else if (task.repeatCount > 1) {
      label = 'timer_roundsBadge'.trParams({
        'cur': task.remainingRepeatCount.toString(),
        'total': task.repeatCount.toString(),
      });
    } else if (primary != null &&
        primary.type == TimerType.pomodoro &&
        (primary.cycles ?? 0) > 1) {
      label = 'timer_cyclesBadge'.trParams({
        'cur': (primary.currentCycle ?? 1).toString(),
        'total': primary.cycles.toString(),
      });
    }
    if (label == null) return const [];

    return [
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: labelFontSize * 0.9,
          vertical: labelFontSize * 0.35,
        ),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: _onCard.withValues(alpha: 0.18),
          stroke: _onCard.withValues(alpha: 0.5),
          strokeWidth: 1.2,
          radius: DsRadii.pill,
          seed: _seed + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              DsIcon(icon, size: labelFontSize, color: _onCard),
              SizedBox(width: 3),
            ] else ...[
              Container(
                width: labelFontSize * 0.5,
                height: labelFontSize * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _onCard,
                ),
              ),
              SizedBox(width: 4),
            ],
            Text(
              label,
              style: DsTypography.label.copyWith(
                fontSize: labelFontSize * 0.9,
                color: _onCard,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ===== 主视觉区：大号时间 + 名称 + 播放按钮 =====

  Widget _buildFocalRow(AppThemeData theme, bool isMini) {
    final size = widget.size;
    final primary = _primaryTimer;
    final timeFont =
        isMini ? size.getLargeFontSize() * 0.8 : size.getLargeFontSize();
    final timeText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        _focalTime(primary),
        style: DsTypography.display.copyWith(
          fontSize: timeFont,
          height: 1.05,
          letterSpacing: -timeFont * 0.02,
          color: _onCard,
        ),
      ),
    );

    if (isMini) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(size.getIconSize() * 0.3),
                decoration: dsSketchDecoration(
                  theme: theme,
                  circle: true,
                  fillColor: _onCard.withValues(alpha: 0.15),
                  stroke: _onCard.withValues(alpha: 0.5),
                  strokeWidth: 1.2,
                  seed: _seed + 3,
                ),
                child: WiredIcon(
                  icon: widget.task.icon,
                  size: size.getIconSize() * 0.8,
                  color: _onCard,
                  drawConfig: theme.wired.drawConfig,
                ),
              ),
              SizedBox(width: size.getSmallSpacing() * 2),
              Expanded(
                child: Text(
                  widget.task.name,
                  style: DsTypography.heading.copyWith(
                    fontSize: size.getTitleFontSize(),
                    color: _onCard,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: size.getSmallSpacing() * 2),
          Row(
            children: [
              Expanded(child: timeText),
              _buildControlButton(theme, primary),
            ],
          ),
        ],
      );
    }

    final nameFont = (timeFont * 0.3).clamp(11.0, 18.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              timeText,
              SizedBox(height: size.getSmallSpacing()),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      widget.task.name,
                      style: DsTypography.label.copyWith(
                        fontSize: nameFont,
                        color: _onCard,
                      ),
                    ),
                    if (widget.showGroup && widget.task.group.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${widget.task.group}',
                        style: DsTypography.caption.copyWith(
                          fontSize: nameFont * 0.75,
                          color: _onCard.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: size.getSmallSpacing() * 3),
        _buildControlButton(theme, primary),
      ],
    );
  }

  /// 主计时器的展示时间：倒计时/番茄钟显示剩余，正计时运行中显示已计时
  String _focalTime(TimerItem? timer) {
    if (timer == null) return '00:00';
    if (timer.isCompleted) return _formatDuration(timer.duration);
    switch (timer.type) {
      case TimerType.countDown:
      case TimerType.pomodoro:
        return _formatDuration(timer.remainingDuration);
      case TimerType.countUp:
        return timer.isRunning
            ? _formatDuration(timer.completedDuration)
            : _formatDuration(timer.duration);
    }
  }

  // ===== 底部信息区 =====

  Widget _buildFooter(AppThemeData theme) {
    final size = widget.size;
    final pillFont = (size.getSubtitleFontSize() * 0.85).clamp(9.0, 14.0);
    final pills = <Widget>[];

    final dots = _buildSessionDots(pillFont);
    if (dots != null) pills.add(dots);

    for (final timer in widget.task.timerItems) {
      pills.add(_buildTimerPill(theme, timer, pillFont));
    }

    // 番茄钟休息提示
    final primary = _primaryTimer;
    if (primary != null &&
        primary.type == TimerType.pomodoro &&
        (primary.breakDuration?.inMinutes ?? 0) > 0) {
      pills.add(
        _buildIconPill(
          theme,
          DsIconKind.coffee,
          'timer_breakPill'.trParams({
            'min': primary.breakDuration!.inMinutes.toString(),
          }),
          pillFont,
        ),
      );
    }

    if (pills.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: size.getSmallSpacing() * 2,
      runSpacing: size.getSmallSpacing() * 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: pills,
    );
  }

  /// 会话进度圆点（任务重复轮数或番茄钟循环），无轮次信息时返回 null
  Widget? _buildSessionDots(double font) {
    final task = widget.task;
    final primary = _primaryTimer;

    int total = 0;
    int current = 0;
    String label = '';
    if (task.repeatCount > 1) {
      total = task.repeatCount;
      current = task.remainingRepeatCount.clamp(1, total);
      label = 'timer_roundProgress'.trParams({
        'cur': current.toString(),
        'total': total.toString(),
      });
    } else if (primary != null &&
        primary.type == TimerType.pomodoro &&
        (primary.cycles ?? 0) > 1) {
      total = primary.cycles!;
      current = (primary.currentCycle ?? 1).clamp(1, total);
      label = 'timer_stageProgress'.trParams({
        'cur': current.toString(),
        'total': total.toString(),
      });
    } else {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 轮次过多时不画圆点，只显示文字
        if (total <= 6)
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _onCard.withValues(alpha: i < current ? 1.0 : 0.35),
              ),
            ),
          ],
        const SizedBox(width: 6),
        Text(
          label,
          style: DsTypography.caption.copyWith(
            fontSize: font,
            color: _onCard.withValues(alpha: 0.85),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  /// 单个计时器胶囊，运行中的使用实心前景色；进度条叠加在胶囊底部，不改变胶囊尺寸
  Widget _buildTimerPill(AppThemeData theme, TimerItem timer, double font) {
    final running = timer.isRunning;
    final fg = running ? _cardColor : _onCard.withValues(alpha: 0.95);
    final progress =
        timer.duration.inSeconds > 0
            ? (timer.completedDuration.inSeconds / timer.duration.inSeconds)
                .clamp(0.0, 1.0)
            : 0.0;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: running ? _onCard : _onCard.withValues(alpha: 0.15),
        stroke: _onCard.withValues(alpha: 0.5),
        strokeWidth: 1.2,
        radius: DsRadii.pill,
        seed: _seed + 5,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(_typeIcon(timer.type), size: font * 1.05, color: fg),
          const SizedBox(width: 4),
          Text(
            timer.name,
            style: DsTypography.label.copyWith(
              fontSize: font,
              color: fg,
            ),
          ),
          if (timer.repeatCount > 1) ...[
            const SizedBox(width: 4),
            Text(
              '×${timer.getCurrentRepeatCount()}',
              style: DsTypography.label.copyWith(
                fontSize: font * 0.9,
                color: fg,
              ),
            ),
          ],
          const SizedBox(width: 6),
          Text(
            _formatTimerDisplay(timer),
            style: DsTypography.label.copyWith(
              fontSize: font,
              color: fg,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (running && progress > 0) {
      return Stack(
        children: [
          pill,
          Positioned(
            left: 10,
            right: 10,
            bottom: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 2,
                color: _cardColor.withValues(alpha: 0.25),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(color: _cardColor),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return pill;
  }

  Widget _buildIconPill(
    AppThemeData theme,
    DsIconKind icon,
    String label,
    double font,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: _onCard.withValues(alpha: 0.12),
        stroke: _onCard.withValues(alpha: 0.5),
        strokeWidth: 1.2,
        radius: DsRadii.pill,
        seed: _seed + 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(icon, size: font, color: _onCard.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            label,
            style: DsTypography.caption.copyWith(
              fontSize: font,
              color: _onCard.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 控制按钮 =====

  Widget _buildControlButton(AppThemeData theme, TimerItem? primary) {
    if (!widget.showActionButtons || primary == null) {
      return const SizedBox.shrink();
    }

    final task = widget.task;
    final diameter = (widget.size.getIconSize() * 2.6).clamp(40.0, 68.0);
    final icon =
        task.isCompleted
            ? DsIconKind.replay
            : (task.isRunning ? DsIconKind.pause : DsIconKind.play);

    Widget circle = Pressable(
      onPressed: () {
        if (task.isRunning) {
          task.pause();
          if (widget.onReset != null) {
            widget.onReset!(task);
          }
        } else if (task.isCompleted) {
          task.reset();
          if (widget.onReset != null) {
            widget.onReset!(task);
          }
        } else {
          task.start();
        }
        setState(() {});
      },
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.scale(
          scale: pressed ? 0.9 : 1.0,
          child: Container(
            width: diameter,
            height: diameter,
            alignment: Alignment.center,
            decoration: dsSketchDecoration(
              theme: theme,
              circle: true,
              fillColor: _onCard,
              strokeWidth: 2.0,
              seed: _seed + 7,
            ),
            child: DsIcon(icon, size: diameter * 0.5, color: _cardColor),
          ),
        );
      },
    );

    // 运行中：外圈淡墨手绘光环（叠层绘制，不占布局空间，避免切换时高度抖动）
    if (task.isRunning) {
      circle = Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: dsSketchDecoration(
                  theme: theme,
                  circle: true,
                  stroke: _onCard.withValues(alpha: 0.4),
                  strokeWidth: 2,
                  seed: _seed + 8,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return circle;
  }

  // ===== 网格布局（多计时器） =====

  Widget _buildGridLayout() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: widget.size.getSmallSpacing() * 2,
      mainAxisSpacing: widget.size.getSmallSpacing() * 2,
      childAspectRatio: 1.6,
      children:
          widget.task.timerItems.map((item) => _buildGridItem(item)).toList(),
    );
  }

  Widget _buildGridItem(TimerItem item) {
    final theme = DSThemeBridge.resolve(context);
    final progress =
        item.duration.inSeconds > 0
            ? item.completedDuration.inSeconds / item.duration.inSeconds
            : 0.0;

    return Container(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    color: _onCard.withValues(alpha: 0.15),
                    strokeWidth: 6,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CircularProgressIndicator(
                    value: progress > 0 ? progress : 0.001,
                    color: _onCard,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      style: DsTypography.heading.copyWith(
                        fontSize: widget.size.getSubtitleFontSize() * 0.8,
                        color: _onCard,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimerDisplay(item),
                      style: DsTypography.caption.copyWith(
                        fontSize: widget.size.getSubtitleFontSize() * 0.7,
                        color: _onCard.withValues(alpha: 0.85),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: _onCard.withValues(alpha: 0.15),
              stroke: _onCard.withValues(alpha: 0.5),
              strokeWidth: 1.2,
              radius: DsRadii.pill,
              seed: _seed + 9,
            ),
            child: Text(
              item.type == TimerType.pomodoro
                  ? (item.isWorkPhase == true ? 'timer_work'.tr : 'timer_rest'.tr)
                  : (item.name.contains('Break') ? 'timer_rest'.tr : 'timer_work'.tr),
              style: DsTypography.label.copyWith(
                fontSize: widget.size.getSubtitleFontSize() * 0.6,
                color: _onCard,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 工具方法 =====

  String _typeLabel(TimerType type) {
    switch (type) {
      case TimerType.countUp:
        return 'timer_countUpTimer'.tr;
      case TimerType.countDown:
        return 'timer_countDownTimer'.tr;
      case TimerType.pomodoro:
        return 'timer_pomodoroTimer'.tr;
    }
  }

  DsIconKind _typeIcon(TimerType type) {
    switch (type) {
      case TimerType.countUp:
        return DsIconKind.speed;
      case TimerType.countDown:
        return DsIconKind.hourglass;
      case TimerType.pomodoro:
        return DsIconKind.timer;
    }
  }

  /// 长按快捷菜单项（圆盘与底部 sheet 共用）
  List<ArcMenuItem> _menuActions(TimerTask task) => [
        ArcMenuItem(
          icon: DsIconKind.edit,
          label: 'app_edit'.tr,
          onTap: () => widget.onEdit?.call(task),
        ),
        ArcMenuItem(
          icon: DsIconKind.refresh,
          label: 'timer_reset'.tr,
          onTap: () => widget.onReset?.call(task),
        ),
        ArcMenuItem(
          icon: DsIconKind.trash,
          label: 'app_delete'.tr,
          destructive: true,
          onTap: () => widget.onDelete?.call(task),
        ),
      ];

  void _showContextMenu(BuildContext context, TimerTask task) {
    if (!widget.showActionButtons) return;
    SmoothBottomSheet.showActionList(
      context: context,
      title: task.name,
      actions: _menuActions(task),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _formatTimerDisplay(TimerItem timer) {
    if (timer.type == TimerType.countDown) {
      return _formatDuration(timer.remainingDuration);
    } else if (timer.isRunning) {
      return '${_formatDuration(timer.completedDuration)}/${_formatDuration(timer.duration)}';
    } else {
      return _formatDuration(timer.duration);
    }
  }
}
