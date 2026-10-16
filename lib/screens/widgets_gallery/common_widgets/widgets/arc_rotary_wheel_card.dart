/// 弧形圆盘选择卡片（手绘风）
///
/// 由 arc_rotary_wheel_selector.html 转换：选项沿右侧大圆弧排布
/// （圆心在卡片外远处），垂直拖拽 / 惯性甩动 / 点击选择，
/// 弹簧吸附到最近档位；圆弧轨道与居中指针由 skribble rough
/// 引擎手绘，选项胶囊为墨线抖动描边。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 圆盘选项数据
class ArcWheelItemData {
  const ArcWheelItemData({
    this.id,
    required this.label,
    this.icon,
    this.color,
    this.value,
  });

  /// 稳定标识（数据绑定用，可为空）
  final String? id;

  /// 选项文字
  final String label;

  /// 选项图标（Material IconData，与插件图标同源）
  final IconData? icon;

  /// 选项主题色（激活态胶囊底色）
  final Color? color;

  /// 附带数据（选择回调透传）
  final dynamic value;
}

/// 弧形圆盘选择器（无卡片外壳的原生交互组件）
///
/// 选项沿右侧同心圆弧排布：中心选项放大高亮，远离中心的选项
/// 沿径向倾斜、缩小并淡出。支持拖拽、惯性甩动、鼠标滚轮与点击选择。
class ArcRotaryWheelSelector extends StatefulWidget {
  const ArcRotaryWheelSelector({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.height = 400,
    this.onSelect,
    this.onItemTap,
  });

  /// 选项列表（至少 2 项才有交互意义）
  final List<ArcWheelItemData> items;

  /// 初始选中下标
  final int initialIndex;

  /// 组件高度（宽度由父容器决定，几何按宽度等比缩放）
  final double height;

  /// 吸附档位变化回调
  final ValueChanged<int>? onSelect;

  /// 点击选项回调（转轮同时旋转到该选项）
  final ValueChanged<int>? onItemTap;

  @override
  State<ArcRotaryWheelSelector> createState() =>
      _ArcRotaryWheelSelectorState();
}

class _ArcRotaryWheelSelectorState extends State<ArcRotaryWheelSelector>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);

  // 弹簧物理状态（单位：选项下标）
  double _target = 0;
  double _current = 0;
  double _velocity = 0;
  double _trackVelocity = 0;
  double _pointerPulse = 0;

  bool _dragging = false;
  bool _hasInteracted = false;
  double _dragStartIndex = 0;
  double _dragAccum = 0;
  DateTime _lastMoveTime = DateTime.now();
  int _lastSnapped = -1;
  Duration? _lastElapsed;
  Timer? _scrollSettleTimer;

  _WheelGeometry? _geo;

  int get _maxIndex => widget.items.length - 1;

  @override
  void initState() {
    super.initState();
    _target = widget.initialIndex.clamp(0, math.max(0, _maxIndex)).toDouble();
    // 入场从下方旋入
    _current = _target + 2.2;
    _startTicker();
  }

  @override
  void didUpdateWidget(ArcRotaryWheelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length ||
        widget.initialIndex != oldWidget.initialIndex) {
      _target = widget.initialIndex.clamp(0, math.max(0, _maxIndex)).toDouble();
      _current = _target;
      _velocity = 0;
      _startTicker();
    }
  }

  @override
  void dispose() {
    _scrollSettleTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  // ===== 弹簧物理循环 =====

  void _startTicker() {
    _lastElapsed = null;
    if (!_ticker.isActive) _ticker.start();
  }

  bool get _animating =>
      _dragging ||
      _pointerPulse > 0.001 ||
      _current != _target ||
      _velocity != 0;

  void _onTick(Duration elapsed) {
    final last = _lastElapsed;
    _lastElapsed = elapsed;
    if (last == null) return;

    final dtMs = (elapsed - last).inMicroseconds / 1000.0;
    final step = (dtMs / 16.667).clamp(0.25, 3.0).toDouble();

    if (!_dragging) {
      // 与 HTML 版一致的弹簧参数（stiffness 0.14 / damping 0.76 @60fps），
      // 按 dt 折算保证高刷新率下手感一致
      _velocity =
          (_velocity + (_target - _current) * 0.14 * step) *
          math.pow(0.76, step).toDouble();
      _current += _velocity * step;
      if ((_target - _current).abs() < 0.0008 && _velocity.abs() < 0.0008) {
        _current = _target;
        _velocity = 0;
      }
    }
    if (_pointerPulse > 0.001) {
      _pointerPulse *= math.pow(0.86, step).toDouble();
    } else {
      _pointerPulse = 0;
    }

    _handleSnapChanged();

    if (!_animating) {
      _ticker.stop();
      _lastElapsed = null;
    }
    if (mounted) setState(() {});
  }

  /// 越过整数档位时触发指针回弹与选中回调
  void _handleSnapChanged() {
    final nearest = _current.round();
    if (nearest < 0 || nearest > _maxIndex) return;
    if (nearest == _lastSnapped) return;
    _lastSnapped = nearest;
    _pointerPulse = 1;
    if (_hasInteracted) {
      HapticFeedback.selectionClick();
    }
    widget.onSelect?.call(nearest);
  }

  // ===== 交互 =====

  void _selectIndex(int index) {
    _hasInteracted = true;
    final clamped = index.clamp(0, math.max(0, _maxIndex));
    if (clamped != _target) {
      _target = clamped.toDouble();
      _startTicker();
    }
  }

  void _onItemTap(int index) {
    if (widget.items.isEmpty) return;
    _selectIndex(index);
    widget.onItemTap?.call(index.clamp(0, _maxIndex));
  }

  void _onDragStart() {
    _hasInteracted = true;
    _dragging = true;
    _velocity = 0;
    _trackVelocity = 0;
    _dragStartIndex = _current;
    _dragAccum = 0;
    _lastMoveTime = DateTime.now();
    _startTicker();
  }

  void _onDragUpdate(double primaryDelta) {
    final geo = _geo;
    if (geo == null || !_dragging) return;
    _dragAccum += primaryDelta;
    // 向下拖 → 下标减小（上方选项落进中心），与 HTML 版一致
    final raw = _dragStartIndex - _dragAccum / geo.pixelsPerStep;
    if (raw < 0) {
      _current = raw * 0.32; // 顶部橡皮筋
    } else if (raw > _maxIndex) {
      _current = _maxIndex + (raw - _maxIndex) * 0.32; // 底部橡皮筋
    } else {
      _current = raw;
    }

    final now = DateTime.now();
    final dt = math.max(1, now.difference(_lastMoveTime).inMilliseconds);
    _trackVelocity = (-primaryDelta / geo.pixelsPerStep) * (16 / dt);
    _lastMoveTime = now;
  }

  void _onDragEnd() {
    if (!_dragging) return;
    _dragging = false;
    // 按甩动速度投影吸附目标
    final projected = _current + _trackVelocity * 4.5;
    _target = projected.round().clamp(0, math.max(0, _maxIndex)).toDouble();
    _velocity = _trackVelocity * 0.45;
    _trackVelocity = 0;
    _startTicker();
  }

  void _onScroll(double scrollDelta) {
    if (widget.items.isEmpty) return;
    _hasInteracted = true;
    final deltaSteps = scrollDelta / 120 * 0.65;
    _target = (_target + deltaSteps).clamp(0.0, _maxIndex.toDouble());
    // 停止滚动 140ms 后吸附到整数档
    _scrollSettleTimer?.cancel();
    _scrollSettleTimer = Timer(const Duration(milliseconds: 140), () {
      _target = _target.roundToDouble().clamp(0.0, _maxIndex.toDouble());
      _startTicker();
    });
    _startTicker();
  }

  // ===== 渲染 =====

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final geo = _geo = _WheelGeometry(
            Size(constraints.maxWidth, widget.height),
          );
          final theme = AppTheme.of(context);

          final children = <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _WheelBackdropPainter(
                  geo: geo,
                  theme: theme,
                  pulse: _pointerPulse,
                  progress: WiredDrawTransition.progressOf(context),
                ),
              ),
            ),
            for (var i = 0; i < widget.items.length; i++)
              if (_buildItemRow(context, theme, geo, i)
                  case final Widget row)
                row,
          ];

          return ClipRect(
            child: SizedBox(
              height: widget.height,
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent &&
                      event.scrollDelta.dy != 0) {
                    _onScroll(event.scrollDelta.dy);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => _onDragStart(),
                  onVerticalDragUpdate: (d) =>
                      _onDragUpdate(d.primaryDelta ?? 0),
                  onVerticalDragEnd: (_) => _onDragEnd(),
                  onVerticalDragCancel: _onDragEnd,
                  child: Stack(clipBehavior: Clip.none, children: children),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建单个选项行（标签 + 图标胶囊），沿圆弧定位并径向倾斜
  Widget? _buildItemRow(
    BuildContext context,
    AppThemeData theme,
    _WheelGeometry geo,
    int index,
  ) {
    final offset = _current - index;
    final absOffset = offset.abs();
    if (absOffset > 5.4) return null;

    final item = widget.items[index];
    final itemColor = item.color ?? theme.primary;

    // 激活度：offset=0 时为 1，|offset|>=0.85 时为 0（smoothstep 平滑）
    final activeP = (1 - absOffset / 0.75).clamp(0.0, 1.0);
    final smooth = activeP * activeP * (3 - 2 * activeP);

    final iconCenter = geo.iconCenter(offset);
    final tilt = geo.tilt(offset);
    final scale = _lerp(1.0, 0.93, math.min(1.0, absOffset / 4));

    // 以图标胶囊中心（行内锚点）为变换原点：平移到圆弧位置 → 旋转 → 缩放
    final transform =
        Matrix4.identity()
          ..translate(iconCenter.dx, iconCenter.dy)
          ..rotateZ(tilt)
          ..scale(scale)
          ..translate(-geo.anchor.dx, -geo.anchor.dy);

    // 标签：激活后套手绘纸签，远处淡出只留图标
    final labelFade =
        absOffset > 3.1
            ? math.max(0.0, 1 - (absOffset - 3.1) / 0.55)
            : 1.0;
    final label = Opacity(
      opacity: labelFade,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14 * geo.unit,
          vertical: 5 * geo.unit,
        ),
        decoration:
            smooth > 0.08
                ? dsSketchDecoration(
                    theme: theme,
                    fillColor: theme.surface,
                    stroke: theme.ink.withValues(alpha: smooth),
                    radius: theme.radii.pill,
                    seed: index + 1,
                  )
                : null,
        child: Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DsTypography.body.copyWith(
            color: Color.lerp(theme.textSub, theme.text, smooth),
            fontSize: 15.5 * geo.unit,
          ),
        ),
      ),
    );

    // 图标胶囊：普通态次级表面 + 淡墨描边，激活态选项色实底 + 选项色描边
    final pill = Container(
      width: _lerp(geo.pillW0, geo.pillW1, smooth),
      height: _lerp(geo.pillH0, geo.pillH1, smooth),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: Color.lerp(theme.surfaceAlt, itemColor, smooth),
        stroke: Color.lerp(
          theme.ink.withValues(alpha: 0.3),
          itemColor,
          smooth,
        ),
        radius: theme.radii.pill,
        seed: index * 7 + 3,
      ),
      child: Icon(
        item.icon ?? Icons.extension,
        size: _lerp(22, 26, smooth) * geo.unit,
        color: Color.lerp(theme.textSub, theme.onPrimary, smooth),
      ),
    );

    final row = SizedBox(
      width: geo.rowW,
      height: geo.rowH,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(child: label),
          SizedBox(width: 15 * geo.unit),
          SizedBox(
            width: geo.pillW1,
            child: Center(child: pill),
          ),
        ],
      ),
    );

    return Positioned(
      left: 0,
      top: 0,
      child: Opacity(
        opacity: _rowOpacity(offset),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onItemTap(index),
          child: Transform(transform: transform, child: row),
        ),
      ),
    );
  }

  /// 行不透明度衰减（复刻 HTML 版的分段曲线，底部略柔于顶部）
  double _rowOpacity(double offset) {
    final a = offset.abs();
    if (a <= 1) return _lerp(1.0, 0.9, a);
    if (a <= 2) return _lerp(0.9, 0.74, a - 1);
    if (a <= 3) return _lerp(0.74, offset < 0 ? 0.34 : 0.56, a - 2);
    if (a <= 4.3) {
      return _lerp(offset < 0 ? 0.34 : 0.56, 0.16, (a - 3) / 1.3);
    }
    return math.max(0.0, _lerp(0.16, 0.0, (a - 4.3) / 0.9));
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// 圆弧几何：以 HTML 参考稿（375 宽设计稿）为基准按实际宽度等比缩放
class _WheelGeometry {
  _WheelGeometry(Size size)
    : width = size.width,
      height = size.height,
      unit = size.width / 375;

  final double width;
  final double height;
  final double unit;

  /// 同心圆心（位于卡片右侧远处）
  double get cx => 2.4133 * width;

  double get cy => height / 2;

  /// 轨道线半径
  double get trackR => 1.6267 * width;

  /// 图标胶囊中心半径
  double get iconR => 1.8133 * width;

  /// 相邻选项的圆心角（弧度），由 85px 视觉步距换算
  double get stepAngle => (85 * unit) / iconR;

  /// 径向倾斜角相对圆心角的夸张比例（9.6°/7.25°）
  static const double tiltRatio = 9.6 / 7.25;

  /// 拖拽灵敏度：每档对应的像素
  double get pixelsPerStep => 85 * unit;

  double get rowW => 280 * unit;
  double get rowH => 60 * unit;

  /// 行内变换原点（图标胶囊中心）
  Offset get anchor => Offset(241 * unit, 30 * unit);

  double get pillW0 => 68 * unit;
  double get pillW1 => 78 * unit;
  double get pillH0 => 48 * unit;
  double get pillH1 => 56 * unit;

  double get pointerW => 44 * unit;
  double get pointerH => 18 * unit;

  /// 选项在圆弧上的中心点（offset 为相对选中档的步数，正值为上方）
  Offset iconCenter(double offset) => Offset(
    cx - iconR * math.cos(offset * stepAngle),
    cy - iconR * math.sin(offset * stepAngle),
  );

  double tilt(double offset) => offset * stepAngle * tiltRatio;
}

/// 背景层：右侧大圆弧墨线轨道 + 跨在轨道上的左尖指针
class _WheelBackdropPainter extends CustomPainter {
  _WheelBackdropPainter({
    required this.geo,
    required this.theme,
    required this.pulse,
    this.progress,
  }) : super(repaint: progress);

  final _WheelGeometry geo;
  final AppThemeData theme;

  /// 指针回弹脉冲（0~1，吸附档位时置 1 后指数衰减）
  final double pulse;

  /// 环境墨线描画进度（WiredDraw 注入；null = 立即全画）
  final Animation<double>? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final drawConfig = theme.wired.drawConfig;
    final ink =
        Paint()
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = math.max(1.4, 2.0 * geo.unit);

    // 圆弧轨道：只画视口内的弧段（圆心角在 π 附近，即大圆最左侧）
    final halfAngle = math.asin(
      math.min(1.0, (size.height / 2 + 30 * geo.unit) / geo.trackR),
    );
    drawConfig.randomizer.reset();
    final trackGen = Generator(drawConfig, NoFiller());
    RoughDrawing(
      trackGen.arc(
        geo.cx,
        geo.cy,
        geo.trackR * 2,
        geo.trackR * 2,
        math.pi - halfAngle,
        math.pi + halfAngle,
      ),
      ink..color = theme.ink.withValues(alpha: 0.35),
      ink,
    ).paint(canvas, progress: progress?.value ?? 1, pressure: 0);

    // 指针：吸附时向左回弹一下
    final nudge = -3.5 * math.sin(pulse * math.pi) * geo.unit;
    final originX = geo.cx - geo.trackR + nudge - geo.pointerW / 2;
    final originY = geo.cy - geo.pointerH / 2;
    const local = <(double, double)>[
      (2, 9),
      (8.5, 4),
      (14, 1.6),
      (24, 0.6),
      (34, 1.6),
      (40.5, 5),
      (43.5, 9),
      (40.5, 13),
      (34, 16.4),
      (24, 17.4),
      (14, 16.4),
      (8.5, 14),
    ];
    final points = [
      for (final (x, y) in local)
        PointD(originX + x * geo.unit, originY + y * geo.unit),
    ];
    drawConfig.randomizer.reset();
    final pointerGen = Generator(drawConfig, NoFiller());
    final fill =
        Paint()
          ..style = PaintingStyle.fill
          ..isAntiAlias = true
          ..color = theme.ink;
    RoughDrawing(
      pointerGen.polygon(points),
      ink..color = theme.ink,
      fill,
    ).paint(canvas, progress: progress?.value ?? 1, pressure: 0);
  }

  @override
  bool shouldRepaint(_WheelBackdropPainter oldDelegate) =>
      oldDelegate.geo.width != geo.width ||
      oldDelegate.geo.height != geo.height ||
      oldDelegate.pulse != pulse ||
      oldDelegate.theme != theme;
}

/// 弧形圆盘选择卡片：手绘纸面板 + 标题/选中项 + 圆盘选择器
///
/// 仅一个默认尺寸（2x3），几何随实际宽度等比缩放。
class ArcRotaryWheelCardWidget extends StatefulWidget {
  /// 卡片标题（如 '今日运动'），为 null 时不显示
  final String? title;

  /// 选项列表
  final List<ArcWheelItemData> items;

  /// 初始选中下标
  final int initialIndex;

  /// 是否为内联模式（内联模式宽度撑满，非内联为固定宽）
  final bool inline;

  /// 组件尺寸（仅一个默认大小，scale 参与宽度缩放）
  final HomeWidgetSize size;

  /// 选中档位变化回调
  final ValueChanged<int>? onSelect;

  /// 点击选项回调
  final ValueChanged<int>? onItemTap;

  const ArcRotaryWheelCardWidget({
    super.key,
    this.title,
    required this.items,
    this.initialIndex = 0,
    this.inline = false,
    this.size = const Large3Size(),
    this.onSelect,
    this.onItemTap,
  });

  /// 从 props 创建实例
  factory ArcRotaryWheelCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    Color parseColor(dynamic colorValue) {
      if (colorValue == null) return const Color(0xFF7BDCC5);
      if (colorValue is Color) return colorValue;
      if (colorValue is int) return Color(colorValue);
      if (colorValue is String) {
        try {
          if (colorValue.startsWith('#')) {
            return Color(
              int.parse(colorValue.substring(1), radix: 16) + 0xFF000000,
            );
          }
          if (colorValue.startsWith('0x')) {
            return Color(int.parse(colorValue.substring(2), radix: 16));
          }
        } catch (_) {
          // 解析失败走默认色
        }
      }
      return const Color(0xFF7BDCC5);
    }

    List<ArcWheelItemData> parseItems(dynamic itemsData) {
      if (itemsData is! List) return const [];
      return [
        for (final entry in itemsData)
          if (entry is Map<String, dynamic>)
            ArcWheelItemData(
              id: entry['id'] as String?,
              label: entry['label'] as String? ?? '',
              icon:
                  entry['icon'] is IconData
                      ? entry['icon'] as IconData
                      : dynamicIconData(
                        (entry['icon'] as num?)?.toInt() ??
                            Icons.extension.codePoint,
                        fontFamily: 'MaterialIcons',
                      ),
              color: parseColor(entry['color']),
              value: entry['value'],
            ),
      ];
    }

    return ArcRotaryWheelCardWidget(
      title: props['title'] as String?,
      items: parseItems(props['items']),
      initialIndex: (props['initialIndex'] as num?)?.toInt() ?? 0,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<ArcRotaryWheelCardWidget> createState() =>
      _ArcRotaryWheelCardWidgetState();
}

class _ArcRotaryWheelCardWidgetState extends State<ArcRotaryWheelCardWidget> {
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = AppTheme.of(context);
          final width =
              widget.inline ? double.maxFinite : 384.0 * widget.size.scale;
          final hasSelection =
              widget.items.isNotEmpty &&
              _selected >= 0 &&
              _selected < widget.items.length;
          final selectedItem =
              hasSelection ? widget.items[_selected] : null;

          return SizedBox(
            width: width,
            child: WiredDraw(
              child: DsSketchPanel(
                theme: theme,
                radius: theme.radii.xxl,
                hachure: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
                      child: Row(
                        children: [
                          if (widget.title != null)
                            Expanded(
                              child: Text(
                                widget.title!,
                                style: DsTypography.title.copyWith(
                                  color: theme.text,
                                ),
                              ),
                            ),
                          if (selectedItem != null)
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                selectedItem.label,
                                key: ValueKey(_selected),
                                style: DsTypography.heading.copyWith(
                                  color:
                                      selectedItem.color ?? theme.primaryText,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ArcRotaryWheelSelector(
                      items: widget.items,
                      initialIndex: widget.initialIndex,
                      height: 400,
                      onSelect: (index) {
                        setState(() => _selected = index);
                        widget.onSelect?.call(index);
                      },
                      onItemTap: widget.onItemTap,
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
