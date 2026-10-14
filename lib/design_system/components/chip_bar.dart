import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'jelly_box.dart';

/// 手绘 chip 组：横向滚动、变宽 chip，
/// 激活药丸以弹簧物理在 chip 间滑动（参考 radial_disc_bottom_bar 的滑动药丸）
class DSChipBar extends StatefulWidget {
  const DSChipBar({
    super.key,
    required this.labels,
    required this.selected,
    this.onChanged,
    this.spacing = 8,
    this.stiffness = 420,
    this.damping = 34,
  });

  final List<String> labels;

  /// 激活项下标（越界时自动钳制）
  final int selected;

  /// 点击 chip 回调；为 null 时整组只读不交互
  final ValueChanged<int>? onChanged;

  /// chip 间距
  final double spacing;

  /// 激活药丸的弹簧刚度
  final double stiffness;

  /// 激活药丸的弹簧阻尼
  final double damping;

  @override
  State<DSChipBar> createState() => _DSChipBarState();
}

class _DSChipBarState extends State<DSChipBar> {
  final GlobalKey _rowKey = GlobalKey();
  List<GlobalKey> _itemKeys = const [];

  /// 各 chip 相对 Row 内容原点的矩形，首帧布局后测得
  List<Rect> _rects = const [];

  @override
  Widget build(BuildContext context) {
    if (_itemKeys.length != widget.labels.length) {
      _itemKeys = List.generate(widget.labels.length, (_) => GlobalKey());
      _rects = const [];
    }
    // 文案 / 语言 / 字号变化都会改变 chip 尺寸，逐帧测量并按需刷新
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final theme = AppTheme.of(context);
    final disabled = widget.onChanged == null;
    final selected = widget.labels.isEmpty
        ? 0
        : widget.selected.clamp(0, widget.labels.length - 1);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 弹簧滑动药丸：对激活下标插值，Rect 在相邻 chip 间连续过渡
          _SpringBuilder(
            value: selected.toDouble(),
            stiffness: widget.stiffness,
            damping: widget.damping,
            builder: (context, t) {
              final rect = _rectAt(t);
              if (rect == null) return const SizedBox.shrink();
              return Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: JellyBox(
                    color: disabled ? theme.disabled : theme.primary,
                    radius: theme.radii.pill,
                  ),
                ),
              );
            },
          ),
          Row(
            key: _rowKey,
            spacing: widget.spacing,
            children: [
              for (var i = 0; i < widget.labels.length; i++)
                _buildChip(context, i, selected, disabled, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    int index,
    int selected,
    bool disabled,
    AppThemeData theme,
  ) {
    final active = index == selected;
    final pressedScale = 0.94;

    return KeyedSubtree(
      key: _itemKeys[index],
      child: Pressable(
        onPressed: disabled ? null : () => widget.onChanged?.call(index),
        semanticLabel: widget.labels[index],
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return AnimatedScale(
            scale: pressed ? pressedScale : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: DsTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: active
                      ? (disabled ? theme.surface : theme.onPrimary)
                      : theme.textSub,
                ),
                child: Text(widget.labels[index], maxLines: 1),
              ),
            ),
          );
        },
      ),
    );
  }

  Rect? _rectAt(double t) {
    if (_rects.isEmpty) return null;
    final i = t.floor().clamp(0, _rects.length - 1);
    final j = t.ceil().clamp(0, _rects.length - 1);
    if (i == j) return _rects[i];
    return Rect.lerp(_rects[i], _rects[j], t - i);
  }

  void _measure() {
    if (!mounted) return;
    final rowBox = _rowKey.currentContext?.findRenderObject();
    if (rowBox is! RenderBox || !rowBox.attached || rowBox.size == Size.zero) {
      return;
    }
    final next = <Rect>[];
    for (final key in _itemKeys) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) return;
      final offset = box.localToGlobal(Offset.zero, ancestor: rowBox);
      next.add(
        Rect.fromLTWH(offset.dx, offset.dy, box.size.width, box.size.height),
      );
    }
    var dirty = next.length != _rects.length;
    if (!dirty) {
      for (var i = 0; i < next.length; i++) {
        if (next[i] != _rects[i]) {
          dirty = true;
          break;
        }
      }
    }
    if (dirty) setState(() => _rects = next);
  }
}

/// 弹簧驱动的隐式动画组件
///
/// 目标值 [value] 变化时携带当前速度弹向新目标
/// （移植自 radial_disc_bottom_bar 的 SpringBuilder）
class _SpringBuilder extends StatefulWidget {
  const _SpringBuilder({
    required this.value,
    required this.builder,
    this.stiffness = 420,
    this.damping = 34,
  });

  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final double stiffness;
  final double damping;

  @override
  State<_SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<_SpringBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this)..value = widget.value;
  Simulation? _simulation;

  @override
  void didUpdateWidget(_SpringBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _simulation = SpringSimulation(
        SpringDescription(
          mass: 1,
          stiffness: widget.stiffness,
          damping: widget.damping,
        ),
        _controller.value,
        widget.value,
        _currentVelocity,
      );
      _controller.animateWith(_simulation!);
    }
  }

  double get _currentVelocity {
    final elapsed = _controller.lastElapsedDuration;
    final simulation = _simulation;
    if (elapsed == null || simulation == null) return 0;
    return simulation.dx(
      elapsed.inMicroseconds / Duration.microsecondsPerSecond,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _controller.value),
    );
  }
}
