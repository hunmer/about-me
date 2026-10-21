import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';
import 'button.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 手绘分页器：上一页/下一页圆钮 + JellyBox 胶囊页码 + 首尾省略
///
/// - 总页数 `pages = ceil(total / pageSize)`；`total <= 0` 时不渲染
/// - `pages <= 7` 时全部显示，否则恒显 1 与 pages，
///   中间显示 `current ± siblingCount`，缺口用不可点的「…」占位
/// - 页码胶囊（36×36）：当前页 primary 实底 + 反色字，
///   其余纸面 + 墨线，hover/press 变 surfaceAlt，按压 AnimatedScale 微弹
/// - 翻页按钮复用 [DSIconButton]（chevron 图标）：
///   首页禁用上一页、末页禁用下一页
class DsPagination extends StatelessWidget {
  const DsPagination({
    super.key,
    required this.total,
    this.pageSize = 10,
    required this.current,
    required this.onChanged,
    this.siblingCount = 1,
  });

  /// 总条数
  final int total;

  /// 每页条数
  final int pageSize;

  /// 当前页（1 起）
  final int current;

  final ValueChanged<int> onChanged;

  /// 当前页两侧各多显示几页
  final int siblingCount;

  /// 胶囊边长（宽=高）
  static const double _pillExtent = 36;

  /// 页码序列：int = 页码，'…' = 省略占位
  List<Object> _pageItems(int pages) {
    if (pages <= 7) {
      return [for (var i = 1; i <= pages; i++) i];
    }
    final shown = <int>{1, pages};
    for (var i = current - siblingCount; i <= current + siblingCount; i++) {
      if (i > 1 && i < pages) shown.add(i);
    }
    final sorted = shown.toList()..sort();
    final items = <Object>[];
    var prev = 0;
    for (final p in sorted) {
      if (prev != 0 && p - prev > 1) items.add('…');
      items.add(p);
      prev = p;
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final pages = total <= 0 ? 0 : (total / pageSize).ceil();
    if (pages <= 0) return const SizedBox.shrink();

    final children = <Widget>[
      DSIconButton(
        icon: DsIconKind.chevronLeft,
        size: _pillExtent,
        tooltip: '上一页',
        onPressed: current > 1 ? () => onChanged(current - 1) : null,
      ),
      SizedBox(width: theme.spacing.xs),
    ];
    for (final item in _pageItems(pages)) {
      children.add(
        item is int ? _buildPagePill(theme, item) : _buildEllipsis(theme),
      );
      children.add(SizedBox(width: theme.spacing.xs));
    }
    children.add(
      DSIconButton(
        icon: DsIconKind.chevronRight,
        size: _pillExtent,
        tooltip: '下一页',
        onPressed: current < pages ? () => onChanged(current + 1) : null,
      ),
    );

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  /// 单个页码胶囊
  Widget _buildPagePill(AppThemeData theme, int page) {
    final isCurrent = page == current;
    return Pressable(
      onPressed: isCurrent ? null : () => onChanged(page),
      semanticLabel: '第 $page 页',
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        final hovered = states.contains(WidgetState.hovered);
        return AnimatedScale(
          scale: pressed ? 0.94 : 1.0,
          duration: DsMotion.fast,
          curve: DsMotion.curve,
          child: JellyBox(
            width: _pillExtent,
            height: _pillExtent,
            radius: theme.radii.pill,
            color: isCurrent
                ? theme.primary
                : (hovered || pressed ? theme.surfaceAlt : theme.surface),
            alignment: Alignment.center,
            child: Text(
              '$page',
              style: DsTypography.button.copyWith(
                fontSize: 13,
                color: isCurrent ? theme.onPrimary : theme.text,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 省略占位：不可点的「…」文本
  Widget _buildEllipsis(AppThemeData theme) => SizedBox(
    width: theme.spacing.xxl,
    height: _pillExtent,
    child: Center(
      child: Text(
        '…',
        style: DsTypography.caption.copyWith(color: theme.textSub),
      ),
    ),
  );
}
