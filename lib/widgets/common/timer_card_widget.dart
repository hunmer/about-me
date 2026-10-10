import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/plugins/timer/models/timer_task.dart';
import 'package:aboutme/plugins/timer/models/timer_item.dart';
import 'package:aboutme/core/services/timer/models/timer_state.dart';
import 'package:aboutme/plugins/timer/views/timer_task_details_page.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 计时器任务卡片小组件（高饱和纯色风格）
///
/// 视觉风格：高饱和任务色卡片背景 + 大号时间数字 + 白色圆形播放按钮 +
/// 半透明胶囊徽章 + 背景环境圆环装饰。
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

  /// 自定义文字颜色（可选），未指定时根据背景亮度自动取黑/白
  final Color? textColor;

  /// 是否显示操作按钮
  final bool showActionButtons;

  /// 小组件尺寸
  final HomeWidgetSize size;

  /// 是否显示分组名称
  final bool showGroup;

  /// 是否使用网格布局（当计时器数量 >= 3 时）
  final bool useGridLayout;

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

  /// 卡片上的前景色（文字/图标），优先自定义文字色
  Color get _onCard =>
      widget.textColor ?? (_cardIsDark ? Colors.white : const Color(0xFF2C2825));

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

    // 高度自适应：不设最小高度约束，完全由内容撑开
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: _cardColor.withValues(alpha: 0.36),
            offset: const Offset(0, 14),
            blurRadius: 30,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
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
            onLongPress: () => _showContextMenu(context, widget.task),
            splashColor: Colors.white.withValues(alpha: 0.15),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 装饰层用 Positioned.fill 作为定位子节点，不参与尺寸计算，
                // 保证卡片高度只由内容决定
                if (!isMini)
                  Positioned.fill(
                    child: IgnorePointer(child: _buildDecorations()),
                  ),
                Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMini) ...[
                        _buildHeaderRow(),
                        SizedBox(height: size.getSmallSpacing() * 2),
                      ],
                      _buildFocalRow(isMini),
                      if (!isMini) ...[
                        SizedBox(height: size.getSmallSpacing() * 2),
                        if (widget.useGridLayout)
                          _buildGridLayout()
                        else
                          _buildFooter(),
                      ],
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

  // ===== 装饰层：环境圆环 + 背景大图标 =====

  Widget _buildDecorations() {
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
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            right: -bigSize * 0.15,
            bottom: -bigSize * 0.15,
            child: Icon(
              widget.task.icon,
              size: bigSize,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 顶部徽章行 =====

  Widget _buildHeaderRow() {
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: _onCard.withValues(alpha: 0.15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.task.icon, size: labelFontSize * 1.2, color: _onCard),
              SizedBox(width: size.getSmallSpacing() * 1.5),
              Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w600,
                  color: _onCard,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        ..._buildTrailingBadge(labelFontSize),
      ],
    );
  }

  /// 右上角徽章：完成状态 > 任务重复轮数 > 番茄钟循环数
  List<Widget> _buildTrailingBadge(double labelFontSize) {
    final task = widget.task;
    final primary = _primaryTimer;

    String? label;
    IconData? icon;
    if (task.isCompleted) {
      label = '已完成';
      icon = Icons.check_circle;
    } else if (task.repeatCount > 1) {
      label = '${task.remainingRepeatCount}/${task.repeatCount} 轮';
    } else if (primary != null &&
        primary.type == TimerType.pomodoro &&
        (primary.cycles ?? 0) > 1) {
      label = '${primary.currentCycle ?? 1}/${primary.cycles} 循环';
    }
    if (label == null) return const [];

    return [
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: labelFontSize * 0.9,
          vertical: labelFontSize * 0.35,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: _onCard.withValues(alpha: 0.18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: labelFontSize, color: _onCard),
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
              style: TextStyle(
                fontSize: labelFontSize * 0.9,
                fontWeight: FontWeight.w500,
                color: _onCard,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ===== 主视觉区：大号时间 + 名称 + 播放按钮 =====

  Widget _buildFocalRow(bool isMini) {
    final size = widget.size;
    final primary = _primaryTimer;
    final timeFont =
        isMini ? size.getLargeFontSize() * 0.8 : size.getLargeFontSize();
    final timeText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        _focalTime(primary),
        style: TextStyle(
          fontSize: timeFont,
          height: 1.05,
          fontWeight: FontWeight.w700,
          letterSpacing: -timeFont * 0.02,
          color: _onCard,
          shadows: [
            Shadow(
              color: _onCard.withValues(alpha: 0.25),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _onCard.withValues(alpha: 0.15),
                ),
                child: Icon(
                  widget.task.icon,
                  size: size.getIconSize() * 0.8,
                  color: _onCard,
                ),
              ),
              SizedBox(width: size.getSmallSpacing() * 2),
              Expanded(
                child: Text(
                  widget.task.name,
                  style: TextStyle(
                    fontSize: size.getTitleFontSize(),
                    fontWeight: FontWeight.bold,
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
              _buildControlButton(primary),
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
                      style: TextStyle(
                        fontSize: nameFont,
                        fontWeight: FontWeight.w600,
                        color: _onCard,
                      ),
                    ),
                    if (widget.showGroup && widget.task.group.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${widget.task.group}',
                        style: TextStyle(
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
        _buildControlButton(primary),
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

  Widget _buildFooter() {
    final size = widget.size;
    final pillFont = (size.getSubtitleFontSize() * 0.85).clamp(9.0, 14.0);
    final pills = <Widget>[];

    final dots = _buildSessionDots(pillFont);
    if (dots != null) pills.add(dots);

    for (final timer in widget.task.timerItems) {
      pills.add(_buildTimerPill(timer, pillFont));
    }

    // 番茄钟休息提示
    final primary = _primaryTimer;
    if (primary != null &&
        primary.type == TimerType.pomodoro &&
        (primary.breakDuration?.inMinutes ?? 0) > 0) {
      pills.add(
        _buildIconPill(
          Icons.local_cafe,
          '${primary.breakDuration!.inMinutes}m 休息',
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
      label = '第 $current / $total 轮';
    } else if (primary != null &&
        primary.type == TimerType.pomodoro &&
        (primary.cycles ?? 0) > 1) {
      total = primary.cycles!;
      current = (primary.currentCycle ?? 1).clamp(1, total);
      label = '第 $current / $total 阶段';
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
          style: TextStyle(
            fontSize: font,
            color: _onCard.withValues(alpha: 0.85),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  /// 单个计时器胶囊，运行中的使用实心前景色；进度条叠加在胶囊底部，不改变胶囊尺寸
  Widget _buildTimerPill(TimerItem timer, double font) {
    final running = timer.isRunning;
    final fg = running ? _cardColor : _onCard.withValues(alpha: 0.95);
    final progress =
        timer.duration.inSeconds > 0
            ? (timer.completedDuration.inSeconds / timer.duration.inSeconds)
                .clamp(0.0, 1.0)
            : 0.0;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: running ? _onCard : _onCard.withValues(alpha: 0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_typeIcon(timer.type), size: font * 1.05, color: fg),
          const SizedBox(width: 4),
          Text(
            timer.name,
            style: TextStyle(
              fontSize: font,
              fontWeight: running ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
          if (timer.repeatCount > 1) ...[
            const SizedBox(width: 4),
            Text(
              '×${timer.getCurrentRepeatCount()}',
              style: TextStyle(
                fontSize: font * 0.9,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
          ],
          const SizedBox(width: 6),
          Text(
            _formatTimerDisplay(timer),
            style: TextStyle(
              fontSize: font,
              fontWeight: FontWeight.w700,
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

  Widget _buildIconPill(IconData icon, String label, double font) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: _onCard.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: font, color: _onCard.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: font,
              color: _onCard.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 控制按钮 =====

  Widget _buildControlButton(TimerItem? primary) {
    if (!widget.showActionButtons || primary == null) {
      return const SizedBox.shrink();
    }

    final task = widget.task;
    final diameter = (widget.size.getIconSize() * 2.6).clamp(40.0, 68.0);
    final icon =
        task.isCompleted
            ? Icons.replay
            : (task.isRunning ? Icons.pause : Icons.play_arrow);

    Widget circle = Material(
      color: _onCard,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
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
        child: Padding(
          padding: EdgeInsets.all(diameter * 0.26),
          child: Icon(icon, size: diameter * 0.5, color: _cardColor),
        ),
      ),
    );

    // 运行中：外圈光环用前景装饰绘制，不占布局空间，避免切换时高度抖动
    if (task.isRunning) {
      circle = Container(
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _onCard.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
        child: circle,
      );
    }

    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x30000000),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: circle,
    );
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: widget.size.getSubtitleFontSize() * 0.8,
                        color: _onCard,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimerDisplay(item),
                      style: TextStyle(
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: _onCard.withValues(alpha: 0.15),
            ),
            child: Text(
              item.type == TimerType.pomodoro
                  ? (item.isWorkPhase == true ? '工作' : '休息')
                  : (item.name.contains('Break') ? '休息' : '工作'),
              style: TextStyle(
                fontSize: widget.size.getSubtitleFontSize() * 0.6,
                fontWeight: FontWeight.bold,
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
        return '正计时';
      case TimerType.countDown:
        return '倒计时';
      case TimerType.pomodoro:
        return '番茄钟';
    }
  }

  IconData _typeIcon(TimerType type) {
    switch (type) {
      case TimerType.countUp:
        return Icons.speed;
      case TimerType.countDown:
        return Icons.hourglass_top;
      case TimerType.pomodoro:
        return Icons.timer;
    }
  }

  void _showContextMenu(BuildContext context, TimerTask task) {
    if (!widget.showActionButtons) return;

    SmoothBottomSheet.show(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text('app_edit'.tr),
              onTap: () {
                Navigator.pop(context);
                if (widget.onEdit != null) {
                  widget.onEdit!(task);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text('timer_reset'.tr),
              onTap: () {
                Navigator.pop(context);
                if (widget.onReset != null) {
                  widget.onReset!(task);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text('app_delete'.tr),
              onTap: () {
                Navigator.pop(context);
                if (widget.onDelete != null) {
                  widget.onDelete!(task);
                }
              },
            ),
          ],
        );
      },
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
