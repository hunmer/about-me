import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../primitives/haptics.dart';
import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';
import 'button.dart';
import 'icons.dart';
import 'input.dart';
import 'jelly_box.dart';
import 'select.dart';

/// 可搜索下拉（Combobox）：面板顶部带过滤输入框（浮层为纸底+淡排线手绘面板）
class DSCombobox<T> extends StatefulWidget {
  const DSCombobox({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.searchHint,
    this.enabled = true,
    this.width,
  });

  final List<DSSelectItem<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;

  /// 占位文案；null 时用 l10n 的 ds_selectHint
  final String? hint;

  /// 搜索框占位；null 时用 l10n 的 ds_searchHint
  final String? searchHint;
  final bool enabled;
  final double? width;

  @override
  State<DSCombobox<T>> createState() => _DSComboboxState<T>();
}

class _DSComboboxState<T> extends State<DSCombobox<T>> {  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _openUpward = false;

  /// 是否正在播退场动画（关闭路径防重入）
  bool _closing = false;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _toggle() {
    _open ? _close() : _insertEntry();
    setState(() {});
  }

  void _insertEntry() {
    _closing = false;
    DsHaptics.popup();
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final top = box.localToGlobal(Offset.zero).dy;
    final below = MediaQuery.sizeOf(context).height - top - size.height;
    _openUpward = below < 320 && top > 320;

    final theme = AppTheme.of(context);
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: _openUpward
                ? Alignment.topLeft
                : Alignment.bottomLeft,
            followerAnchor: _openUpward
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            offset: Offset(0, _openUpward ? -8 : 8),
            child: AppTheme(
              data: theme,
              child: SizedBox(
                width: size.width,
                child: _ComboPanel<T>(
                  items: widget.items,
                  value: widget.value,
                  searchHint: widget.searchHint ?? 'ds_searchHint'.tr,
                  alignTop: _openUpward,
                  closing: _closing,
                  onSelect: (item) {
                    // 回调保持在选中瞬间，浮层退场后再移除
                    _close();
                    setState(() {});
                    widget.onChanged?.call(item.value);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  /// 关闭收敛入口：barrier 点击 / 选中条目 / 触发器再点都走这里；
  /// 先播退场（缩小淡出）再延迟移除浮层，动效减弱时直接移除。
  void _close() {
    if (_closing) return;
    _closing = true;
    if (!mounted) return;
    if (context.dsAnimationsDisabled) {
      _removeEntry();
      setState(() {});
      return;
    }
    // 通知浮层重绘退场帧（tween 目标切到 0）
    _entry?.markNeedsBuild();
    setState(() {});
    Future.delayed(DsMotion.fast, _removeEntry);
  }

  void _removeEntry() {
    // 延迟回调触发时浮层可能已被外部移除，remove 前确认仍挂载
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final hint = widget.hint ?? 'ds_selectHint'.tr;
    final selected = widget.items
        .where((e) => e.value == widget.value)
        .firstOrNull;

    return CompositedTransformTarget(
      link: _link,
      child: Pressable(
        onPressed: widget.enabled ? _toggle : null,
        semanticLabel: selected?.label ?? hint,
        builder: (context, states) {
          return SizedBox(
            width: widget.width,
            child: JellyBox(
              height: 46,
              radius: theme.radii.lg,
              raised: !_open,
              // 描边对齐 DSInput：静止淡墨线、展开（等同聚焦）主题色
              strokeColor: _open
                  ? theme.primary
                  : theme.textSub.withValues(alpha: 0.45),
              borderWidth: 1.6,
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
              child: Row(
                children: [
                  DsIcon(DsIconKind.search, size: 18, color: theme.textSub),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      selected?.label ?? hint,
                      style: DsTypography.body.copyWith(
                        color: selected != null
                            ? theme.text
                            : theme.textSub.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: _open ? 0.5 : 0,
                    child: DsIcon(
                      DsIconKind.chevronDown,
                      size: 18,
                      color: theme.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComboPanel<T> extends StatefulWidget {
  const _ComboPanel({
    required this.items,
    required this.value,
    required this.searchHint,
    required this.alignTop,
    this.closing = false,
    required this.onSelect,
  });

  final List<DSSelectItem<T>> items;
  final T? value;
  final String searchHint;
  final bool alignTop;

  /// 是否处于退场中（面板反向缩小淡出，由宿主组件驱动）
  final bool closing;
  final ValueChanged<DSSelectItem<T>> onSelect;

  @override
  State<_ComboPanel<T>> createState() => _ComboPanelState<T>();
}

class _ComboPanelState<T> extends State<_ComboPanel<T>> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final q = _query.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items.where((e) => e.label.toLowerCase().contains(q)).toList();

    return IgnorePointer(
      // 退场期间禁点，防止误触条目与搜索框
      ignoring: widget.closing,
      child: TweenAnimationBuilder<double>(
        // t=1 为完整态：入场 0→1 放大淡入，退场 1→0 缩小淡出（同一映射双向复用）
        tween: Tween(begin: 0.0, end: widget.closing ? 0.0 : 1.0),
        duration: DsMotion.fast,
        curve: widget.closing ? DsMotion.curve : DsMotion.enter,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(
            scale: 0.85 + 0.15 * t,
            alignment: widget.alignTop
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            child: child,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320, maxWidth: 320),
          child: DsSketchPanel(
            theme: theme,
            radius: theme.radii.lg,
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DSInput(
                  controller: _query,
                  hint: widget.searchHint,
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: theme.spacing.sm),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (filtered.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: theme.spacing.md,
                            ),
                            child: Text(
                              'ds_noMatch'.tr,
                              textAlign: TextAlign.center,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ),
                        for (final item in filtered)
                          _ComboRow(
                            item: item,
                            selected: item.value == widget.value,
                            onTap: () => widget.onSelect(item),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComboRow extends StatelessWidget {
  const _ComboRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DSSelectItem<dynamic> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final pressed = states.contains(WidgetState.pressed);
        if (selected) {
          return JellyBox(
            radius: theme.radii.md,
            color: theme.primary,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm + 2,
            ),
            child: Row(
              children: [
                DsIcon(DsIconKind.check, size: 16, color: theme.onPrimary),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Text(
                    item.label,
                    style: DsTypography.body.copyWith(color: theme.onPrimary),
                  ),
                ),
              ],
            ),
          );
        }
        // 悬停/按压：淡紫实底高亮 + 主题墨线描边；静止态全透明保持行内轻量
        final active = pressed || hovered;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm + 2,
          ),
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: active ? theme.surfaceAlt : DsColors.transparent,
            stroke: active
                ? theme.ink.withValues(alpha: 0.55)
                : DsColors.transparent,
            radius: theme.radii.md,
          ),
          child: Text(
            item.label,
            style: DsTypography.body.copyWith(color: theme.text),
          ),
        );
      },
    );
  }
}

/// 可搜索多选下拉（Multi Combobox）：面板交互复用 [DSCombobox] 的浮层 /
/// 搜索 / 退场机制；点击条目切换选中且**不关闭面板**，触发器显示已选
/// 标签摘要（超出 [maxLabels] 折叠为 +n）。
class DSMultiCombobox<T> extends StatefulWidget {
  const DSMultiCombobox({
    super.key,
    required this.items,
    required this.values,
    required this.onChanged,
    this.hint,
    this.searchHint,
    this.enabled = true,
    this.width,
    this.maxLabels = 2,
    this.allowCreate = false,
  });

  final List<DSSelectItem<T>> items;
  final List<T> values;
  final ValueChanged<List<T>> onChanged;

  /// 占位文案；null 时用 l10n 的 ds_selectHint
  final String? hint;

  /// 搜索框占位；null 时用 l10n 的 ds_searchHint
  final String? searchHint;
  final bool enabled;
  final double? width;

  /// 触发器最多直接显示的已选标签数，其余折叠为「+n」
  final int maxLabels;

  /// 允许在搜索框输入不存在的新选项（仅 T 为 String 时有意义），
  /// 面板出现「新建「xxx」」行，点击后追加到已选值
  final bool allowCreate;

  @override
  State<DSMultiCombobox<T>> createState() => _DSMultiComboboxState<T>();
}

class _DSMultiComboboxState<T> extends State<DSMultiCombobox<T>> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _openUpward = false;
  bool _closing = false;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  @override
  void didUpdateWidget(DSMultiCombobox<T> old) {
    super.didUpdateWidget(old);
    // 浮层开着时 values/items 被外部改变（如页面别处重置已选），
    // 同样要标脏 entry 让面板同步刷新
    if (_entry != null && !_closing) _entry?.markNeedsBuild();
  }

  void _toggle() {
    _open ? _close() : _insertEntry();
    setState(() {});
  }

  void _insertEntry() {
    _closing = false;
    DsHaptics.popup();
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final top = box.localToGlobal(Offset.zero).dy;
    final below = MediaQuery.sizeOf(context).height - top - size.height;
    _openUpward = below < 320 && top > 320;

    final theme = AppTheme.of(context);
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: _openUpward
                ? Alignment.topLeft
                : Alignment.bottomLeft,
            followerAnchor: _openUpward
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            offset: Offset(0, _openUpward ? -8 : 8),
            child: AppTheme(
              data: theme,
              child: SizedBox(
                width: size.width,
                child: _MultiComboPanel<T>(
                  items: widget.items,
                  values: widget.values,
                  searchHint: widget.searchHint ?? 'ds_searchHint'.tr,
                  alignTop: _openUpward,
                  closing: _closing,
                  allowCreate: widget.allowCreate,
                  // 浮层挂在根 Overlay 上、不在本组件子树中：父级 setState 只
                  // 会重建触发器，必须主动标脏 entry 才能让面板行内的选中
                  // 态随最新 values 刷新
                  onToggle: (item) {
                    final next = [...widget.values];
                    next.contains(item.value)
                        ? next.remove(item.value)
                        : next.add(item.value);
                    widget.onChanged(next);
                    _entry?.markNeedsBuild();
                  },
                  onSelectAll: () {
                    widget.onChanged(
                      widget.items.map((e) => e.value).toList(),
                    );
                    _entry?.markNeedsBuild();
                  },
                  onClear: () {
                    widget.onChanged(const []);
                    _entry?.markNeedsBuild();
                  },
                  onCreate: widget.allowCreate
                      ? (label) {
                          widget.onChanged([
                            ...widget.values,
                            label as T,
                          ]);
                          _entry?.markNeedsBuild();
                        }
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    if (!mounted) return;
    if (context.dsAnimationsDisabled) {
      _removeEntry();
      setState(() {});
      return;
    }
    _entry?.markNeedsBuild();
    setState(() {});
    Future.delayed(DsMotion.fast, _removeEntry);
  }

  void _removeEntry() {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 已选值优先用 items 的标签展示；不在 items 里的值（如用户新建的）
    // 直接用 toString() 展示，避免下拉外选中的值在触发器上消失
    final selected = widget.values.map((v) {
      for (final item in widget.items) {
        if (item.value == v) return item.label;
      }
      return v.toString();
    }).toList();
    final hint = widget.hint ?? 'ds_selectHint'.tr;
    final summary = selected.isEmpty
        ? hint
        : [
            ...selected.take(widget.maxLabels),
            if (selected.length > widget.maxLabels)
              '+${selected.length - widget.maxLabels}',
          ].join('、');

    return CompositedTransformTarget(
      link: _link,
      child: Pressable(
        onPressed: widget.enabled ? _toggle : null,
        semanticLabel: summary,
        builder: (context, states) {
          return SizedBox(
            width: widget.width,
            child: JellyBox(
              height: 46,
              radius: theme.radii.lg,
              raised: !_open,
              strokeColor: _open
                  ? theme.primary
                  : theme.textSub.withValues(alpha: 0.45),
              borderWidth: 1.6,
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
              child: Row(
                children: [
                  DsIcon(DsIconKind.search, size: 18, color: theme.textSub),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.body.copyWith(
                        color: selected.isNotEmpty
                            ? theme.text
                            : theme.textSub.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: _open ? 0.5 : 0,
                    child: DsIcon(
                      DsIconKind.chevronDown,
                      size: 18,
                      color: theme.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 多选面板：与单选 [_ComboPanel] 同构，点击切换选中且不关闭。
class _MultiComboPanel<T> extends StatefulWidget {
  const _MultiComboPanel({
    required this.items,
    required this.values,
    required this.searchHint,
    required this.alignTop,
    this.closing = false,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClear,
    this.allowCreate = false,
    this.onCreate,
  });

  final List<DSSelectItem<T>> items;
  final List<T> values;
  final String searchHint;
  final bool alignTop;
  final bool closing;
  final ValueChanged<DSSelectItem<T>> onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  /// 是否展示「新建」行（搜索词不在选项中时）
  final bool allowCreate;

  /// 点击「新建「xxx」」时回调，由宿主把新值追加进已选
  final ValueChanged<String>? onCreate;

  @override
  State<_MultiComboPanel<T>> createState() => _MultiComboPanelState<T>();
}

class _MultiComboPanelState<T> extends State<_MultiComboPanel<T>> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final q = _query.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items.where((e) => e.label.toLowerCase().contains(q)).toList();
    // 新建行：开启 allowCreate、有搜索词且无完全同名选项时展示
    final queryText = _query.text.trim();
    final canCreate =
        widget.allowCreate &&
        widget.onCreate != null &&
        queryText.isNotEmpty &&
        !widget.items.any(
          (e) => e.label.toLowerCase() == queryText.toLowerCase(),
        );

    return IgnorePointer(
      ignoring: widget.closing,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: widget.closing ? 0.0 : 1.0),
        duration: DsMotion.fast,
        curve: widget.closing ? DsMotion.curve : DsMotion.enter,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(
            scale: 0.85 + 0.15 * t,
            alignment: widget.alignTop
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            child: child,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320, maxWidth: 320),
          child: DsSketchPanel(
            theme: theme,
            radius: theme.radii.lg,
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DSInput(
                  controller: _query,
                  hint: widget.searchHint,
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: theme.spacing.sm),
                // 已选计数 + 全选 / 清空快捷操作
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ds_selectedCount'.trArgs([
                            widget.values.length.toString(),
                            widget.items.length.toString(),
                          ]),
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ),
                    DSButton(
                      label: 'ds_selectAll'.tr,
                      variant: DSButtonVariant.ghost,
                      size: DSButtonSize.sm,
                      onPressed: widget.onSelectAll,
                    ),
                    DSButton(
                      label: 'ds_clear'.tr,
                      variant: DSButtonVariant.ghost,
                      size: DSButtonSize.sm,
                      onPressed: widget.onClear,
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.sm),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (filtered.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: theme.spacing.md,
                            ),
                            child: Text(
                              'ds_noMatch'.tr,
                              textAlign: TextAlign.center,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ),
                        if (canCreate)
                          _ComboRow(
                            item: DSSelectItem(
                              label: 'ds_createNew'.trArgs([queryText]),
                              value: queryText,
                            ),
                            selected: false,
                            onTap: () {
                              widget.onCreate!(queryText);
                              // 新建后清空搜索词，避免重复创建同一项
                              _query.clear();
                              setState(() {});
                            },
                          ),
                        for (final item in filtered)
                          _ComboRow(
                            item: item,
                            selected: widget.values.contains(item.value),
                            onTap: () => widget.onToggle(item),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
