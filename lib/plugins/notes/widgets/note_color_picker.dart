import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 可选标记色板（内容数据，非主题色）：首位 null = 默认（跟随主题）
const List<Color?> kNoteColorChoices = <Color?>[
  null,
  Color(0xFFE07856), // 赤陶
  Color(0xFFE8B04B), // 芥黄
  Color(0xFF7CA65C), // 橄榄
  Color(0xFF5B8DB8), // 群青
  Color(0xFF8A7CB8), // 紫藤
  Color(0xFFC96B98), // 蔷薇
  Color(0xFF6B9C8F), // 青瓷
  Color(0xFF8C8C8C), // 炭灰
];

/// 手绘风格颜色选择行：一排圆形色块，选中项墨线描边加粗 + 对勾
class NoteColorPickerRow extends StatelessWidget {
  const NoteColorPickerRow({
    super.key,
    this.selected,
    required this.onChanged,
  });

  /// 当前选中色（null = 默认）
  final Color? selected;

  final ValueChanged<Color?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsIcon(DsIconKind.palette, size: 16, color: theme.textSub),
                  const SizedBox(width: 8),
                  Text(
                    'notes_color'.tr,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final choice in kNoteColorChoices)
                    _buildSwatch(context, theme, choice),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSwatch(
    BuildContext context,
    AppThemeData theme,
    Color? choice,
  ) {
    final isSelected = choice == selected;
    // 默认项画中空墨线圆，其余画实色圆；选中后加粗描边并画对勾
    final checkColor = choice == null || choice.computeLuminance() > 0.55
        ? theme.ink
        : theme.paper;
    return GestureDetector(
      onTap: () => onChanged(choice),
      child: Container(
        width: 26,
        height: 26,
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: choice,
          circle: true,
          strokeWidth: isSelected ? 2.6 : 1.6,
          seed: choice?.value ?? 0,
        ),
        child: isSelected
            ? Center(
                child: DsIcon(
                  DsIconKind.check,
                  size: 14,
                  color: checkColor,
                ),
              )
            : null,
      ),
    );
  }
}
