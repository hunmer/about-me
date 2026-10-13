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
/// - 手绘墨盒单元格（选中主题色实底，未选中淡底墨线框）
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

  /// 手绘墨盒选项单元格（选中主题色实底，未选中淡底墨线框）
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
    final isSelected = selectedId == option.id;
    final accent = primaryColor ?? theme.primary;
    final fg = isSelected ? theme.onPrimary : theme.textSub;

    return Pressable(
      onPressed: () => onSelectionChanged(option.id),
      semanticLabel: option.label,
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: dsSketchDecoration(
          theme: theme,
          radius: theme.radii.lg,
          fillColor: isSelected ? accent : theme.surfaceAlt,
          stroke: isSelected ? theme.ink : theme.textSub.withValues(alpha: 0.45),
          strokeWidth: 1.4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (option.useTextAsIcon)
              Text(option.label, style: TextStyle(fontSize: iconSize, color: fg))
            else if (option.icon != null)
              Icon(option.icon, size: iconSize, color: fg),
            if (!option.useTextAsIcon) ...[
              SizedBox(height: gap),
              Text(
                option.label,
                style: DsTypography.caption.copyWith(
                  fontSize: fontSize,
                  color: isSelected ? theme.onPrimary : theme.text,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
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
