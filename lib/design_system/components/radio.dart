import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import 'focus_ring.dart';
import 'ink_splash.dart';

/// 手绘单选框
///
/// - 选中时中心白心弹性缩放弹出（0 → 1），取消时缩没
/// - 选中瞬间在元素外围播一次墨点扩散（取消选中不播）
/// - 键盘聚焦时外圈显示圆形虚线焦点环
class DSRadio<T> extends StatelessWidget {
  const DSRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.semanticLabel,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final selected = value == groupValue;
    final disabled = onChanged == null;

    // 选中 → 主色实底；未选中 → 纸面 + 淡墨描边；禁用 → 灰
    final Color fill = disabled
        ? theme.disabled
        : selected
            ? theme.primary
            : theme.surface;

    return Pressable(
      onPressed: disabled ? null : () => onChanged?.call(value),
      semanticLabel: semanticLabel,
      builder: (context, states) {
        return Semantics(
          checked: selected,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: DsFocusRing(
              show: states.contains(WidgetState.focused),
              radius: theme.radii.circle,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      circle: true,
                      fillColor: fill,
                      stroke:
                          !selected || disabled
                          ? theme.textSub.withValues(alpha: disabled ? 0.3 : 0.6)
                          : null,
                    ),
                    // 中心白心：常驻挂载，选中时弹出 / 取消时缩没
                    //（墨线层静止，动效只作用在可补间的 Transform 上）
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: DsMotion.fast,
                      curve: DsMotion.enter,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: disabled ? theme.textSub : theme.onPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  // 选中瞬间的一次性墨点扩散（取消选中不播；禁用不播）
                  Positioned.fill(
                    child: _SelectedSplash(
                      active: selected,
                      color: disabled ? null : theme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 选中瞬间的一次性墨点扩散门控
///
/// [DsInkSplash] 的 trigger 只要变化就会重播，这里用生成计数把它
/// 收窄为「仅 [active] 由假变真（选中瞬间）时重播一次」，
/// 取消选中不播；禁用时 color 为 null 自然不播。
class _SelectedSplash extends StatefulWidget {
  const _SelectedSplash({required this.active, this.color});

  final bool active;
  final Color? color;

  @override
  State<_SelectedSplash> createState() => _SelectedSplashState();
}

class _SelectedSplashState extends State<_SelectedSplash> {
  int _generation = 0;

  @override
  void didUpdateWidget(_SelectedSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _generation++;
    }
  }

  @override
  Widget build(BuildContext context) =>
      DsInkSplash(trigger: _generation, color: widget.color);
}
