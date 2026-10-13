import 'dart:async';

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
/// - 激活项带延迟拖尾的墨迹动画（旧项余韵退场 + 新项延迟弹性绽放）
/// - 适用于分类、状态等选择场景
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

  /// 手绘墨盒选项单元格（选中主题色实底，未选中透明底墨线框）
  Widget _buildOptionCell(
    AppThemeData theme,
    OptionItem option, {
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    double iconSize = 32,
    double fontSize = 12,
    double gap = 8,
  }) {
    return _InkOptionCell(
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
      primaryColor: primaryColor,
    );
  }

  Widget _buildHorizontalScroll(AppThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildOptionCell(
                theme,
                option,
                width: optionWidth,
                height: optionHeight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridLayout(AppThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (gridColumns - 1) * 8) / gridColumns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              _buildOptionCell(
                theme,
                option,
                width: itemWidth,
                padding: const EdgeInsets.symmetric(vertical: 12),
                iconSize: 24,
                fontSize: 10,
                gap: 4,
              ),
          ],
        );
      },
    );
  }
}

/// 手绘墨盒单元格（带延迟拖尾的激活动画）
///
/// 切换选中时的错峰节奏：旧项墨色放慢退场（余韵留在原地），
/// 新项延迟片刻再以弹性曲线绽放主题色实底并轻微回弹放大——
/// 一退一进的时差形成「墨迹拖尾」感。
class _InkOptionCell extends StatefulWidget {
  const _InkOptionCell({
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
    this.primaryColor,
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
  final Color? primaryColor;

  @override
  State<_InkOptionCell> createState() => _InkOptionCellState();
}

class _InkOptionCellState extends State<_InkOptionCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    reverseDuration: const Duration(milliseconds: 480),
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    // 首帧已选中的项不播动画，直接呈实底
    if (widget.isSelected) _ink.value = 1;
  }

  @override
  void didUpdateWidget(covariant _InkOptionCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected == oldWidget.isSelected) return;
    _delay?.cancel();
    if (widget.isSelected) {
      // 延迟绽放：等旧项开始退场再进场，形成拖尾错峰
      _delay = Timer(const Duration(milliseconds: 150), () {
        if (mounted) _ink.forward();
      });
    } else {
      _ink.reverse();
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _ink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final option = widget.option;
    final accent = widget.primaryColor ?? theme.primary;

    return AnimatedBuilder(
      animation: _ink,
      builder: (context, _) {
        final t = _ink.value;
        final fillT = Curves.easeOutCubic.transform(t);
        final fg = Color.lerp(theme.textSub, theme.onPrimary, fillT)!;
        final stroke = Color.lerp(
          theme.textSub.withValues(alpha: 0.45),
          theme.ink,
          fillT,
        )!;
        return Transform.scale(
          // easeOutBack 回弹：进场时轻微放大再收回
          scale: 1 + 0.05 * Curves.easeOutBack.transform(t),
          child: Pressable(
            onPressed: widget.onPressed,
            semanticLabel: option.label,
            child: Container(
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: dsSketchDecoration(
                theme: theme,
                radius: theme.radii.lg,
                fillColor: fillT > 0 ? accent.withValues(alpha: fillT) : null,
                stroke: stroke,
                strokeWidth: 1.4,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (option.useTextAsIcon)
                    Text(
                      option.label,
                      style: TextStyle(fontSize: widget.iconSize, color: fg),
                    )
                  else if (option.icon != null)
                    Icon(option.icon, size: widget.iconSize, color: fg),
                  if (!option.useTextAsIcon) ...[
                    SizedBox(height: widget.gap),
                    Text(
                      option.label,
                      style: DsTypography.caption.copyWith(
                        fontSize: widget.fontSize,
                        color: Color.lerp(theme.text, theme.onPrimary, fillT)!,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
