import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../design_system.dart';

/// 手绘填充风格选择行：一排预览块演示排线/交叉/点/之字/横线/实底效果，
/// 选中项墨线描边加粗。
///
/// 需在 [AppTheme] 作用域内使用（Material 页面请外层包 DSThemeBridge）。
///
/// [selected] 为 [DsSketchFill] 下标：
/// - [allowNone] 为 false（笔记场景）：null 视为默认排线，下标 0 选中；
/// - [allowNone] 为 true（全局设置场景）：追加「无」选项，null = 选中「无」。
class DsSketchFillPickerRow extends StatelessWidget {
  const DsSketchFillPickerRow({
    super.key,
    required this.onChanged,
    this.selected,
    this.allowNone = false,
    this.labelKey = 'notes_bgStyle',
  });

  /// 选择回调；点「无」选项时回调 null
  final ValueChanged<int?> onChanged;

  /// 当前选中下标（见类注释的 null 语义）
  final int? selected;

  /// 是否追加「无」选项
  final bool allowNone;

  /// 标题文案键；null 时隐藏标题行
  final String? labelKey;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelKey != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsIcon(DsIconKind.grid, size: 16, color: theme.textSub),
              const SizedBox(width: 8),
              Text(
                labelKey!.tr,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (allowNone) _buildNoneSwatch(theme),
            for (var i = 0; i < DsSketchFill.values.length; i++)
              _buildStyleSwatch(theme, DsSketchFill.values[i], i),
          ],
        ),
      ],
    );
  }

  /// 「无」选项：中空墨线块 + close 图标，选中描边加粗
  Widget _buildNoneSwatch(AppThemeData theme) {
    final isSelected = allowNone && selected == null;
    return GestureDetector(
      onTap: () => onChanged(null),
      child: Container(
        width: 46,
        height: 46,
        decoration: dsSketchDecoration(
          theme: theme,
          radius: BorderRadius.circular(10),
          strokeWidth: isSelected ? 2.6 : 1.6,
          seed: 90,
        ),
        child: Center(
          child: DsIcon(
            DsIconKind.close,
            size: 18,
            color: isSelected ? theme.primary : theme.textSub,
          ),
        ),
      ),
    );
  }

  /// 风格预览块：用主题淡彩演示该填充效果，选中描边加粗
  Widget _buildStyleSwatch(AppThemeData theme, DsSketchFill style, int index) {
    final isSelected = allowNone ? index == selected : index == (selected ?? 0);
    return GestureDetector(
      onTap: () => onChanged(index),
      child: Container(
        width: 46,
        height: 46,
        decoration: dsSketchDecoration(
          theme: theme,
          // 实底给淡彩演示；其余传 null 让排线/点画走主题淡彩（传纸色会看不见）
          fillColor: style == DsSketchFill.solid ? theme.hatch : null,
          fillStyle: style,
          radius: BorderRadius.circular(10),
          strokeWidth: isSelected ? 2.6 : 1.6,
          seed: 100 + index,
        ),
      ),
    );
  }
}
