import 'package:flutter/material.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 选项数据模型
class OptionItem {
  /// 选项ID
  final String id;

  /// 显示图标（当 useTextAsIcon 为 false 时使用）
  final IconData? icon;

  /// 显示标签
  final String label;

  /// 显示文本（当 useTextAsIcon 为 true 时使用，可以是 emoji）
  final String? subtitle;

  /// 是否使用文本代替图标
  final bool useTextAsIcon;

  const OptionItem({
    required this.id,
    this.icon,
    required this.label,
    this.subtitle,
    this.useTextAsIcon = false,
  });
}

/// 选项选择组件
///
/// 功能特性：
/// - 支持单选功能
/// - 支持多种布局方式（水平滚动或网格）
/// - 手绘墨盒单元格（选中主题色实底，未选中透明底墨线框）
/// - 激活高亮块以延迟拖尾的位移动画滑向新选中项
class OptionSelectorField extends StatelessWidget {
  /// 选项列表
  final List<OptionItem> options;

  /// 当前选中的选项ID
  final String? selectedId;

  /// 选择变更回调
  final Function(String optionId) onSelectionChanged;

  /// 标签文本
  final String? labelText;

  /// 布局方式
  final bool useHorizontalScroll;

  /// 选项卡片宽度（水平滚动模式下使用）
  final double optionWidth;

  /// 选项卡片高度（水平滚动模式下使用）
  final double optionHeight;

  /// 网格列数（网格模式下使用）
  final int gridColumns;

  /// 主题色（未传时取 DS 主题主色）
  final Color? primaryColor;

  const OptionSelectorField({
    super.key,
    required this.options,
    this.selectedId,
    required this.onSelectionChanged,
    this.labelText,
    this.useHorizontalScroll = true,
    this.optionWidth = 96,
    this.optionHeight = 96,
    this.gridColumns = 4,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              labelText!,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ),
        ],
        if (useHorizontalScroll)
          _buildHorizontalScroll(theme)
        else
          _buildGridLayout(theme),
      ],
    );
  }

  /// 手绘墨盒选项单元格（墨线框，主题色实底由底层滑块提供）
  Widget _buildOptionCell(
    AppThemeData theme,
    OptionItem option, {
    Key? key,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    double iconSize = 32,
    double fontSize = 12,
    double gap = 8,
  }) {
    return _InkOptionCell(
      key: key,
      theme: theme,
      option: option,
      isSelected: selectedId == option.id,
      onPressed: () => onSelectionChanged(option.id),
      width: width,
      height: height,
      padding: padding,
      iconSize: iconSize,
      fontSize: fontSize,
      gap: gap,
    );
  }

  Widget _buildHorizontalScroll(AppThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: _InkSelectorTrack(
        theme: theme,
        options: options,
        selectedId: selectedId,
        primaryColor: primaryColor,
        content: (cellKeys) => Row(
          children: [
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildOptionCell(
                  theme,
                  option,
                  key: cellKeys[option.id],
                  width: optionWidth,
                  height: optionHeight,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridLayout(AppThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (gridColumns - 1) * 8) / gridColumns;
        return _InkSelectorTrack(
          theme: theme,
          options: options,
          selectedId: selectedId,
          primaryColor: primaryColor,
          content: (cellKeys) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _buildOptionCell(
                  theme,
                  option,
                  key: cellKeys[option.id],
                  width: itemWidth,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  iconSize: 24,
                  fontSize: 10,
                  gap: 4,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 滑动高亮轨道：底层一块主题色实底滑块位移到选中单元格下方
///
/// 切换时主滑块延迟片刻启动、滑向新位置，另一块半透明尾块更晚
/// 启动、更慢追赶，形成「墨迹拖尾」的位移感。滑块与单元格同处
/// 一个 Stack，经 GlobalKey 测量定位，横向滚动/网格两种布局通用。
class _InkSelectorTrack extends StatefulWidget {
  const _InkSelectorTrack({
    required this.theme,
    required this.options,
    required this.selectedId,
    required this.primaryColor,
    required this.content,
  });

  final AppThemeData theme;
  final List<OptionItem> options;
  final String? selectedId;
  final Color? primaryColor;

  /// 单元格内容层（用 [cellKeys] 给各单元格挂 Key 供测量）
  final Widget Function(Map<String, GlobalKey> cellKeys) content;

  @override
  State<_InkSelectorTrack> createState() => _InkSelectorTrackState();
}

class _InkSelectorTrackState extends State<_InkSelectorTrack>
    with SingleTickerProviderStateMixin {
  final _stackKey = GlobalKey();
  final Map<String, GlobalKey> _cellKeys = {};

  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// 静止位置（动画终点）；null = 无选中项，不画滑块
  Rect? _idle;

  /// 本轮位移动画的起点/终点；两者非空且动画中才插值
  Rect? _from;
  Rect? _to;

  static const _mainCurve = Interval(0.08, 0.6, curve: Curves.easeInOutCubic);
  static const _trailCurve = Interval(0.3, 1.0, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    _scheduleLocate(animate: false);
  }

  @override
  void didUpdateWidget(covariant _InkSelectorTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != oldWidget.selectedId ||
        !identical(widget.options, oldWidget.options)) {
      // 布局帧后测量目标单元格位置再起动画
      _scheduleLocate(animate: true);
    }
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  void _scheduleLocate({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _locate(animate: animate);
    });
  }

  Rect? _measure(String? id) {
    if (id == null) return null;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final cell = _cellKeys[id]?.currentContext?.findRenderObject()
        as RenderBox?;
    if (stack == null || cell == null || !stack.attached || !cell.attached) {
      return null;
    }
    return Rect.fromPoints(
      cell.localToGlobal(Offset.zero, ancestor: stack),
      cell.localToGlobal(cell.size.bottomRight(Offset.zero), ancestor: stack),
    );
  }

  void _locate({required bool animate}) {
    final target = _measure(widget.selectedId);
    // 起点取滑块当前视觉位置：动画中再次切换也能从原处续飞
    final from = _currentMainRect() ?? _idle;
    setState(() {
      _from = (animate && from != null && from != target) ? from : null;
      _to = _from == null ? null : target;
      _idle = target;
    });
    if (_from != null) _move.forward(from: 0);
  }

  Rect? _currentMainRect() {
    final from = _from, to = _to;
    if (from == null || to == null || !_move.isAnimating) return null;
    return Rect.lerp(from, to, _mainCurve.transform(_move.value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final accent = widget.primaryColor ?? theme.primary;

    return AnimatedBuilder(
      animation: _move,
      child: widget.content(_cellKeys),
      builder: (context, cells) {
        Rect? mainRect = _idle;
        Rect? trailRect;
        final from = _from, to = _to;
        if (from != null && to != null && _move.isAnimating) {
          mainRect = Rect.lerp(from, to, _mainCurve.transform(_move.value));
          trailRect = Rect.lerp(from, to, _trailCurve.transform(_move.value));
        }
        return Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            // 底层滑块：尾块先画（更慢追赶），主块覆盖其上
            if (trailRect != null)
              Positioned.fromRect(
                rect: trailRect,
                child: IgnorePointer(
                  child: _highlightBox(theme, accent.withValues(alpha: 0.35)),
                ),
              ),
            if (mainRect != null)
              Positioned.fromRect(
                rect: mainRect,
                child: IgnorePointer(child: _highlightBox(theme, accent)),
              ),
            cells!,
          ],
        );
      },
    );
  }

  /// 手绘实底滑块（描边透明：墨线框由单元格层负责）
  Widget _highlightBox(AppThemeData theme, Color color) {
    return DecoratedBox(
      decoration: dsSketchDecoration(
        theme: theme,
        radius: theme.radii.lg,
        fillColor: color,
        stroke: const Color(0x00000000),
        strokeWidth: 0,
      ),
    );
  }
}

/// 手绘墨盒单元格：透明底墨线框 + 内容
///
/// 主题色实底填充由 [_InkSelectorTrack] 的滑动滑块提供，
/// 单元格只负责墨线框与内容颜色随选中态平滑过渡。
class _InkOptionCell extends StatelessWidget {
  const _InkOptionCell({
    super.key,
    required this.theme,
    required this.option,
    required this.isSelected,
    required this.onPressed,
    this.width,
    this.height,
    this.padding,
    this.iconSize = 32,
    this.fontSize = 12,
    this.gap = 8,
  });

  final AppThemeData theme;
  final OptionItem option;
  final bool isSelected;
  final VoidCallback onPressed;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double iconSize;
  final double fontSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final theme = this.theme;
    final option = this.option;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: isSelected ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final fg = Color.lerp(theme.textSub, theme.onPrimary, t)!;
        return Pressable(
          onPressed: onPressed,
          semanticLabel: option.label,
          child: Container(
            width: width,
            height: height,
            padding: padding,
            decoration: dsSketchDecoration(
              theme: theme,
              radius: theme.radii.lg,
              stroke: Color.lerp(
                theme.textSub.withValues(alpha: 0.45),
                theme.ink,
                t,
              )!,
              strokeWidth: 1.4,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (option.useTextAsIcon)
                  Text(
                    option.label,
                    style: TextStyle(fontSize: iconSize, color: fg),
                  )
                else if (option.icon != null)
                  Icon(option.icon, size: iconSize, color: fg),
                if (!option.useTextAsIcon) ...[
                  SizedBox(height: gap),
                  Text(
                    option.label,
                    style: DsTypography.caption.copyWith(
                      fontSize: fontSize,
                      color: Color.lerp(theme.text, theme.onPrimary, t)!,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
