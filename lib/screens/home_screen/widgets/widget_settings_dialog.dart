import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:aboutme/screens/home_screen/models/plugin_widget_config.dart';

/// 小组件设置对话框
class WidgetSettingsDialog extends StatefulWidget {
  /// 当前配置
  final PluginWidgetConfig initialConfig;

  /// 可用的统计项
  final List<StatItemData> availableItems;

  const WidgetSettingsDialog({
    super.key,
    required this.initialConfig,
    required this.availableItems,
  });

  @override
  State<WidgetSettingsDialog> createState() => _WidgetSettingsDialogState();
}

class _WidgetSettingsDialogState extends State<WidgetSettingsDialog> {
  late PluginWidgetConfig _config;
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _selectedIds = Set.from(_config.selectedItemIds);

    // 如果没有选中任何项，默认选中所有
    if (_selectedIds.isEmpty) {
      _selectedIds = widget.availableItems.map((e) => e.id).toSet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'homeScreen_widgetSettings'.tr,
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.lg),

                  // 显示风格选择
                  Text(
                    '显示风格',
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  DSSegmentedControl(
                    options: [
                      'homeScreen_oneColumn'.tr,
                      'homeScreen_twoColumns'.tr,
                    ],
                    selected:
                        _config.displayStyle ==
                                PluginWidgetDisplayStyle.twoColumns
                            ? 1
                            : 0,
                    onChanged: (index) {
                      setState(() {
                        _config = _config.copyWith(
                          displayStyle:
                              index == 1
                                  ? PluginWidgetDisplayStyle.twoColumns
                                  : PluginWidgetDisplayStyle.oneColumn,
                        );
                      });
                    },
                  ),

                  SizedBox(height: theme.spacing.lg),

                  // 显示项目选择
                  Text(
                    '显示项目',
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.xs),
                  ...widget.availableItems.map(
                    (item) => _buildCheckRow(theme, item),
                  ),

                  SizedBox(height: theme.spacing.lg),

                  // 外观设置
                  Text(
                    '外观设置',
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.xs),

                  // 背景图片
                  _SettingsRow(
                    icon: DsIconKind.image,
                    title: 'homeScreen_backgroundImage'.tr,
                    subtitle:
                        _config.backgroundImagePath != null
                            ? 'homeScreen_alreadySet'.tr
                            : 'homeScreen_notSet'.tr,
                    theme: theme,
                    trailing:
                        _config.backgroundImagePath != null
                            ? _ClearButton(
                              theme: theme,
                              onPressed: () {
                                setState(() {
                                  _config = _config.copyWith(
                                    clearBackgroundImage: true,
                                  );
                                });
                              },
                            )
                            : null,
                    onTap: () async {
                      final result =
                          await ImagePickerDialog.show<Map<String, dynamic>>(
                            context,
                            saveDirectory: 'widget_backgrounds',
                            enableCrop: true,
                            cropAspectRatio: 16 / 9, // 卡片比例
                          );

                      if (result != null && mounted) {
                        setState(() {
                          _config = _config.copyWith(
                            backgroundImagePath: result['url'] as String,
                          );
                        });
                      }
                    },
                  ),

                  // 图标颜色
                  _SettingsRow(
                    icon: DsIconKind.palette,
                    title: 'homeScreen_iconColor'.tr,
                    subtitle:
                        _config.iconColor != null
                            ? 'homeScreen_customized'.tr
                            : 'homeScreen_useDefault'.tr,
                    theme: theme,
                    trailing: _ColorChipRow(
                      theme: theme,
                      color: _config.iconColor,
                      onClear: () {
                        setState(() {
                          _config = _config.copyWith(clearIconColor: true);
                        });
                      },
                    ),
                    onTap:
                        () => _showColorPicker(
                          context,
                          '选择图标颜色',
                          _config.iconColor,
                          (color) {
                            setState(() {
                              _config = _config.copyWith(iconColor: color);
                            });
                          },
                        ),
                  ),

                  // 背景颜色
                  _SettingsRow(
                    icon: DsIconKind.drop,
                    title: 'homeScreen_backgroundColor'.tr,
                    subtitle: 'homeScreen_effectWhenNoBackgroundImage'.tr,
                    theme: theme,
                    trailing: _ColorChipRow(
                      theme: theme,
                      color: _config.backgroundColor,
                      onClear: () {
                        setState(() {
                          _config = _config.copyWith(
                            clearBackgroundColor: true,
                          );
                        });
                      },
                    ),
                    onTap:
                        () => _showColorPicker(
                          context,
                          '选择背景颜色',
                          _config.backgroundColor,
                          (color) {
                            setState(() {
                              _config = _config.copyWith(
                                backgroundColor: color,
                              );
                            });
                          },
                        ),
                  ),

                  SizedBox(height: theme.spacing.lg),

                  // 操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          label: 'screens_cancel'.tr,
                          variant: DSButtonVariant.outline,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(width: theme.spacing.md),
                      Expanded(
                        child: DSButton(
                          label: 'screens_confirm'.tr,
                          onPressed: () {
                            final finalConfig = _config.copyWith(
                              selectedItemIds: _selectedIds.toList(),
                            );
                            Navigator.of(context).pop(finalConfig);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建显示项目勾选行
  Widget _buildCheckRow(AppThemeData theme, StatItemData item) {
    final checked = _selectedIds.contains(item.id);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs / 2),
      child: Row(
        children: [
          DSCheckbox(
            value: checked,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedIds.add(item.id);
                } else {
                  _selectedIds.remove(item.id);
                }
              });
            },
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              item.label,
              style: DsTypography.body.copyWith(color: theme.text),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示颜色选择器
  void _showColorPicker(
    BuildContext context,
    String title,
    Color? currentColor,
    ValueChanged<Color> onColorSelected,
  ) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.lg),

                      // 预设颜色网格
                      Text(
                        'homeScreen_presetColors'.tr,
                        style: DsTypography.heading.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.sm),
                      Wrap(
                        spacing: theme.spacing.sm,
                        runSpacing: theme.spacing.sm,
                        children:
                            _predefinedColors.map((color) {
                              final isSelected = currentColor == color;
                              return GestureDetector(
                                onTap: () {
                                  onColorSelected(color);
                                  Navigator.of(context).pop();
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? theme.primary
                                              : theme.stroke,
                                      width: isSelected ? 3 : 1.4,
                                    ),
                                  ),
                                  child:
                                      isSelected
                                          ? const Center(
                                            child: DsIcon(
                                              DsIconKind.check,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                          )
                                          : null,
                                ),
                              );
                            }).toList(),
                      ),
                      SizedBox(height: theme.spacing.lg),

                      // 自定义颜色按钮
                      DSButton(
                        label: 'homeScreen_customColorWithTransparency'.tr,
                        icon: DsIconKind.palette,
                        variant: DSButtonVariant.outline,
                        expand: true,
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showAdvancedColorPicker(
                            context,
                            title,
                            currentColor ?? Colors.blue,
                            onColorSelected,
                          );
                        },
                      ),
                      SizedBox(height: theme.spacing.md),
                      DSButton(
                        label: 'app_cancel'.tr,
                        variant: DSButtonVariant.ghost,
                        expand: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }

  /// 显示高级颜色选择器（支持透明通道）
  void _showAdvancedColorPicker(
    BuildContext context,
    String title,
    Color initialColor,
    ValueChanged<Color> onColorSelected,
  ) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) {
        // pickerColor 需在 StatefulBuilder 外声明，避免重建时被重置
        Color pickerColor = initialColor;
        return StatefulBuilder(
          builder:
              (context, setState) => DSThemeBridge(
                child: Builder(
                  builder: (context) {
                    final theme = DSThemeBridge.resolve(context);
                    return JellyBox(
                      radius: theme.radii.xxl,
                      padding: EdgeInsets.all(theme.spacing.xl),
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: DsTypography.title.copyWith(
                                color: theme.text,
                              ),
                            ),
                            SizedBox(height: theme.spacing.lg),

                            // 颜色预览
                            Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                color: pickerColor,
                                borderRadius: theme.radii.md,
                                border: Border.all(color: theme.stroke),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _formatColorInfo(pickerColor),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      pickerColor.computeLuminance() > 0.5
                                          ? Colors.black
                                          : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            SizedBox(height: theme.spacing.lg),

                            // 快速应用预设颜色
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'homeScreen_quickSelectPresetColors'.tr,
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                            ),
                            SizedBox(height: theme.spacing.sm),
                            SizedBox(
                              height: 40,
                              width: double.infinity,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _predefinedColors.length,
                                separatorBuilder:
                                    (_, __) =>
                                        SizedBox(width: theme.spacing.sm),
                                itemBuilder: (context, index) {
                                  final color = _predefinedColors[index];
                                  return GestureDetector(
                                    onTap: () {
                                      // 应用预设颜色到选择器
                                      setState(() {
                                        pickerColor = color;
                                      });
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: theme.stroke),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: theme.spacing.lg),

                            // 颜色选择器（支持透明通道）
                            SizedBox(
                              width: double.infinity,
                              child: ColorPicker(
                                pickerColor: pickerColor,
                                onColorChanged: (Color color) {
                                  setState(() {
                                    pickerColor = color;
                                  });
                                },
                                enableAlpha: true, // 启用透明通道
                                displayThumbColor: true,
                                labelTypes: const [
                                  ColorLabelType.rgb,
                                  ColorLabelType.hsv,
                                ],
                                pickerAreaHeightPercent: 0.7,
                              ),
                            ),
                            SizedBox(height: theme.spacing.md),

                            // 操作按钮
                            Row(
                              children: [
                                Expanded(
                                  child: DSButton(
                                    label: 'app_cancel'.tr,
                                    variant: DSButtonVariant.outline,
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                  ),
                                ),
                                SizedBox(width: theme.spacing.md),
                                Expanded(
                                  child: DSButton(
                                    label: 'app_confirm'.tr,
                                    onPressed: () {
                                      onColorSelected(pickerColor);
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        );
      },
    );
  }

  /// 格式化颜色信息（使用新的 API）
  String _formatColorInfo(Color color) {
    final a = (color.a * 255.0).round().clamp(0, 255);
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    final hex = ((a << 24) | (r << 16) | (g << 8) | b)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(8, '0');
    return 'ARGB: $a, $r, $g, $b\n#$hex';
  }

  /// 预定义颜色
  static final List<Color> _predefinedColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];
}

/// 设置行：果冻底座 + 图标 + 标题/副标题 + 尾部控件
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
    this.trailing,
    this.onTap,
  });

  final DsIconKind icon;
  final String title;
  final String subtitle;
  final AppThemeData theme;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return JellyBox(
            radius: theme.radii.lg,
            raised: false,
            color: pressed ? theme.surfaceAlt.withValues(alpha: 0.6) : null,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm,
            ),
            child: Row(
              children: [
                DsIcon(icon, size: 20, color: theme.primary),
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: DsTypography.body.copyWith(color: theme.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: theme.spacing.sm),
                  trailing!,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 颜色小圆点 + 清除按钮（未设置自定义色时不显示）
class _ColorChipRow extends StatelessWidget {
  const _ColorChipRow({
    required this.theme,
    required this.color,
    required this.onClear,
  });

  final AppThemeData theme;
  final Color? color;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (color == null) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: theme.stroke),
          ),
        ),
        SizedBox(width: theme.spacing.xs),
        _ClearButton(theme: theme, onPressed: onClear),
      ],
    );
  }
}

/// 清除按钮
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.theme, required this.onPressed});

  final AppThemeData theme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DSIconButton(
      icon: DsIconKind.close,
      size: 32,
      color: theme.surfaceAlt,
      iconColor: theme.textSub,
      onPressed: onPressed,
    );
  }
}
