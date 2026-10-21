import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';

/// 手绘标签页：文字 + 底部滑动墨线指示条
///
/// 传入 [children] 后，指示条下方渲染可左右滑动的手绘内容页，
/// 点击标签与滑动内容共用同一 PageController，指示条随拖动实时跟手。
/// 激活标签右上角带 12px 手绘小爱心装饰（[showActiveDecoration]），
/// ±10° 摆动循环、相位随标签下标错开，不挡交互。
class DSTabs extends StatefulWidget {
  const DSTabs({
    super.key,
    required this.labels,
    required this.selected,
    this.onChanged,
    this.children,
    this.contentHeight,
    this.showActiveDecoration = true,
  }) : assert(
         children == null || children.length == labels.length,
         'children 数量须与 labels 一致',
       ),
       assert(
         children == null || contentHeight != null,
         '提供 children 时必须同时提供 contentHeight',
       );

  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onChanged;

  /// 可选内容页，提供后启用滑动切换
  final List<Widget>? children;

  /// 内容区固定高度（PageView 需要有界高度）
  final double? contentHeight;

  /// 激活标签右上角的小涂鸦装饰（12px 爱心、主题 primary 低透明度，
  /// ±10° 摆动）。装饰极轻（alpha ≤ 0.5），默认开启以强化手绘观感；
  /// 需要完全复刻旧视觉时传 false 关闭
  final bool showActiveDecoration;

  @override
  State<DSTabs> createState() => _DSTabsState();
}

class _DSTabsState extends State<DSTabs> {
  PageController? _controller;

  @override
  void initState() {
    super.initState();
    _createControllerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant DSTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null) return;
    // 外部 selected 变化（点击标签等）时带动内容页。
    // 滑动触发的 onChanged 回流时 round(page) 已等于 selected，跳过，
    // 避免打断 PageView 自身的惯性吸附。
    final controller = _controller!;
    if (widget.selected != oldWidget.selected &&
        controller.hasClients &&
        controller.page?.round() != widget.selected) {
      controller.animateToPage(
        widget.selected,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _createControllerIfNeeded() {
    if (widget.children != null && _controller == null) {
      _controller = PageController(
        initialPage: widget.selected.clamp(0, widget.labels.length - 1),
      );
    }
  }

  double? get _livePage =>
      _controller?.hasClients == true ? _controller!.page : null;

  @override
  Widget build(BuildContext context) {
    _createControllerIfNeeded();
    final theme = AppTheme.of(context);
    final disabled = widget.onChanged == null;
    final labels = widget.labels;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Pressable(
                  onPressed: disabled ? null : () => widget.onChanged!(i),
                  semanticLabel: labels[i],
                  builder: (context, states) {
                    final hovered = states.contains(WidgetState.hovered);
                    final active = i == widget.selected;
                    Widget label = AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: DsTypography.button.copyWith(
                        fontSize: 14,
                        color: active
                            ? theme.primaryText
                            : theme.textSub.withValues(
                                alpha: hovered ? 0.9 : 0.75,
                              ),
                      ),
                      child: Text(labels[i]),
                    );
                    // 激活标签右上角的小涂鸦：极轻装饰，不裁剪不挡交互
                    if (active && widget.showActiveDecoration) {
                      label = Stack(
                        clipBehavior: Clip.none,
                        children: [
                          label,
                          Positioned(
                            top: -6,
                            right: -8,
                            child: IgnorePointer(
                              child: _TabDoodle(
                                index: i,
                                color: theme.primary.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: theme.spacing.sm + 2,
                        ),
                        child: label,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        _buildIndicator(theme),
        if (widget.children != null)
          SizedBox(
            height: widget.contentHeight,
            child: PageView(
              controller: _controller,
              // 禁用态禁手势，保留程序化翻页
              physics: disabled ? const NeverScrollableScrollPhysics() : null,
              onPageChanged: widget.onChanged,
              children: widget.children!,
            ),
          ),
      ],
    );
  }

  /// 滑动手绘指示条：主色实底胶囊 + 墨线描边。
  /// 挂内容页时随 PageController 实时跟手，纯标签模式用 AnimatedAlign 补间。
  Widget _buildIndicator(AppThemeData theme) {
    final count = widget.labels.length;

    Widget pill() => FractionallySizedBox(
      widthFactor: 1 / count,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 12,
        margin: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
        // （rough 引擎墨迹内收数像素，需比果冻版略高才能画成胶囊）
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.primary,
          radius: theme.radii.pill,
          strokeWidth: 1.2,
        ),
      ),
    );

    Alignment alignmentOf(double page) =>
        Alignment(count <= 1 ? -1 : -1 + 2 * (page / (count - 1)), 0);

    final controller = _controller;
    if (controller == null) {
      return SizedBox(
        height: 12,
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: alignmentOf(widget.selected.toDouble()),
          child: pill(),
        ),
      );
    }

    return SizedBox(
      height: 12,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Align(
          alignment: alignmentOf(_livePage ?? widget.selected.toDouble()),
          child: pill(),
        ),
      ),
    );
  }
}

/// 激活标签右上角的小涂鸦装饰（12px 手绘爱心）
///
/// ±10°（±0.17rad）摆动循环（≈2s），相位随标签下标错开；
/// 动效减弱（context.dsAnimationsDisabled）时静态显示。
class _TabDoodle extends StatefulWidget {
  const _TabDoodle({required this.index, required this.color});

  /// 标签下标（决定摆动相位）
  final int index;

  final Color color;

  @override
  State<_TabDoodle> createState() => _TabDoodleState();
}

class _TabDoodleState extends State<_TabDoodle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 摆动周期（长循环动效，超出 DsMotion 过渡档位的时长）
  static const Duration _swingDuration = Duration(seconds: 2);

  /// 摆幅：±10° ≈ ±0.17rad
  static const double _amplitude = 0.17;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _swingDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 动效减弱：停表退化静态；恢复后自动续跑
    if (context.dsAnimationsDisabled) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doodle = CustomPaint(
      size: const Size.square(12),
      painter: _HeartDoodlePainter(color: widget.color),
    );
    if (context.dsAnimationsDisabled) return doodle;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Transform.rotate(
        // 相位随标签下标错开，正弦式往返摆动（repeat 无跳变）
        angle:
            _amplitude *
            math.sin(
              ((_controller.value + widget.index * 0.25) % 1.0) * 2 * math.pi,
            ),
        child: doodle,
      ),
    );
  }
}

/// 手绘小爱心：两条贝塞尔曲线拼成的细线描边涂鸦
class _HeartDoodlePainter extends CustomPainter {
  // ignore: unused_element_parameter
  const _HeartDoodlePainter({required this.color, this.strokeWidth = 1.3});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.92)
      ..cubicTo(w * 0.05, h * 0.6, w * 0.08, h * 0.08, w * 0.5, h * 0.32)
      ..cubicTo(w * 0.92, h * 0.08, w * 0.95, h * 0.6, w * 0.5, h * 0.92);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_HeartDoodlePainter oldDelegate) =>
      oldDelegate.color != color;
}
