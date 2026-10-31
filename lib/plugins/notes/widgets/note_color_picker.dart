import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/constants/app_icons.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/form_fields/circle_icon_picker_field.dart';
import 'package:aboutme/widgets/picker/circle_icon_picker.dart'
    show CircleIconPickerType;

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

/// 手绘风格色板行（无标题）：一排圆形色块，选中项墨线描边加粗 + 对勾
class NoteColorSwatchRow extends StatelessWidget {
  const NoteColorSwatchRow({super.key, this.selected, required this.onChanged});

  /// 当前选中色（null = 默认）
  final Color? selected;

  final ValueChanged<Color?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final choice in kNoteColorChoices) _buildSwatch(theme, choice),
      ],
    );
  }

  Widget _buildSwatch(AppThemeData theme, Color? choice) {
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

/// 手绘风格水印图标选择行（无标题）：
/// 接入 CircleIconPickerField 全量图标库；已设置图标时右上角展示 x 角标，
/// 点击快捷清空（置 null）；新选择存 AppIcons 键名，
/// 旧 DsIconKind 枚举名继续兼容回显
class NoteIconPickerRow extends StatelessWidget {
  const NoteIconPickerRow({
    super.key,
    this.selectedIcon,
    required this.onChanged,
  });

  /// 当前水印图标（DsIconKind 枚举名或 AppIcons 键名）；null = 无
  final String? selectedIcon;

  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return CircleIconPickerField(
      currentIcon: _resolveIconData(),
      currentBackgroundColor: theme.primary,
      supportedTypes: const {CircleIconPickerType.icon},
      hasIcon: selectedIcon != null,
      onClear: () => onChanged(null),
      onValueChanged: (value) {
            final icon = value['icon'] as IconData?;
            // icon == null 是清空事件（右上角 x 角标 / 菜单「清除设置」）
            if (icon == null) {
              onChanged(null);
              return;
            }
            // 反查 AppIcons 键名持久化（与悬浮球/相册标签的既有模式一致）
            for (final entry in AppIcons.predefinedIcons.entries) {
              if (entry.value == icon) {
                onChanged(entry.key);
                return;
              }
            }
          },
    );
  }

  /// 解析当前图标用于回显：DsIconKind 名走手绘图标集，
  /// 其余按 AppIcons 键名查；无值/未命中回退默认心情图标
  IconData _resolveIconData() {
    final name = selectedIcon;
    if (name == null) return DsIconKind.mood.iconData;
    for (final kind in DsIconKind.values) {
      if (kind.name == name) return kind.iconData;
    }
    return AppIcons.predefinedIcons[name] ?? DsIconKind.mood.iconData;
  }
}

/// 手绘风格颜色选择行：一排圆形色块，选中项墨线描边加粗 + 对勾；
/// 传入 [onStyleChanged] 时追加背景填充风格选择行（排线/交叉/点/之字/横线/实底）；
/// 传入 [onIconChanged] 时追加水印图标选择行。
class NoteColorPickerRow extends StatelessWidget {
  const NoteColorPickerRow({
    super.key,
    this.selected,
    required this.onChanged,
    this.selectedStyle,
    this.onStyleChanged,
    this.selectedIcon,
    this.onIconChanged,
  });

  /// 当前选中色（null = 默认）
  final Color? selected;

  final ValueChanged<Color?> onChanged;

  /// 当前背景填充风格（DsSketchFill 下标）；null = 默认（排线）
  final int? selectedStyle;

  /// 背景风格选择回调；非 null 才显示风格行
  final ValueChanged<int>? onStyleChanged;

  /// 当前水印图标（DsIconKind 枚举名）；null = 无
  final String? selectedIcon;

  /// 图标选择回调；非 null 才显示图标行
  final ValueChanged<String?>? onIconChanged;

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
              NoteColorSwatchRow(selected: selected, onChanged: onChanged),
              if (onStyleChanged != null) ...[
                const SizedBox(height: 12),
                DsSketchFillPickerRow(
                  selected: selectedStyle,
                  // 本行不显示「无」选项，回调值恒非空
                  onChanged: (index) => onStyleChanged!(index!),
                ),
              ],
              if (onIconChanged != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DsIcon(DsIconKind.mood, size: 16, color: theme.textSub),
                    const SizedBox(width: 8),
                    Text(
                      'notes_icon'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                NoteIconPickerRow(selectedIcon: selectedIcon, onChanged: onIconChanged!),
              ],
            ],
          );
        },
      ),
    );
  }
}
