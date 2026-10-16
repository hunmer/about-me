import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/services/app_background_controller.dart';
import 'package:aboutme/core/services/ds_ink_style_controller.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/picker/app_color_picker.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_tile.dart';

/// 全局主题背景设置页面
///
/// 复刻主页的主题设置页面（background_settings_page）中的全局背景设置，
/// 但作用于应用内所有界面：设置背景图或纯色背景后，
/// 所有界面的默认纯色背景将被其替代。
/// 不包含小组件透明度与主页布局背景设置。
class ThemeBackgroundSettingsScreen extends StatefulWidget {
  const ThemeBackgroundSettingsScreen({super.key});

  @override
  State<ThemeBackgroundSettingsScreen> createState() =>
      _ThemeBackgroundSettingsScreenState();
}

class _ThemeBackgroundSettingsScreenState
    extends State<ThemeBackgroundSettingsScreen> {
  final AppBackgroundController _controller = AppBackgroundController();

  bool _isLoading = true;

  // 全局背景图设置
  String? _backgroundPath;
  BoxFit _backgroundFit = BoxFit.cover;
  double _backgroundBlur = 0.0;

  // 全局纯色背景
  Color? _backgroundColor;

  // 全局网格背景（DsSketchFill 下标；null = 未启用）
  int? _gridIndex;

  // 网格纹理间距（逻辑像素）
  double _gridGap = 18;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      await _controller.initialize();

      if (mounted) {
        setState(() {
          _backgroundPath = _controller.backgroundPath;
          _backgroundFit = _controller.backgroundFit;
          _backgroundBlur = _controller.backgroundBlur;
          _backgroundColor = _controller.backgroundColor;
          _gridIndex = _controller.backgroundGridIndex;
          _gridGap = _controller.backgroundGridGap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载主题背景设置失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 选择图片
  Future<String?> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files.first.path;
      }
    } catch (e) {
      debugPrint('选择图片失败: $e');
      if (mounted) {
        toastService.showToast('选择图片失败：$e');
      }
    }
    return null;
  }

  /// 保存全局背景设置
  Future<void> _saveBackground() async {
    try {
      await _controller.save(
        backgroundPath: _backgroundPath,
        backgroundFit: _backgroundFit,
        backgroundBlur: _backgroundBlur,
      );

      if (mounted) {
        toastService.showToast('主题设置已保存');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('保存失败：$e');
      }
    }
  }

  /// 保存纯色背景设置（null 表示清除，恢复系统默认背景）
  Future<void> _saveBackgroundColor(Color? color) async {
    try {
      await _controller.saveBackgroundColor(color);

      if (mounted) {
        toastService.showToast(color != null ? '主题设置已保存' : '已恢复默认背景');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('保存失败：$e');
      }
    }
  }

  /// 应用纯色背景
  void _applyBackgroundColor(Color? color) {
    setState(() {
      _backgroundColor = color;
    });
    _saveBackgroundColor(color);
  }

  /// 保存网格背景设置（null 表示清除，恢复默认背景）
  Future<void> _applyGrid(int? index, double gap) async {
    setState(() {
      _gridIndex = index;
      _gridGap = gap;
    });
    try {
      await _controller.saveBackgroundGrid(index, gap);
      if (mounted) {
        toastService.showToast(index != null ? '主题设置已保存' : '已恢复默认背景');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('保存失败：$e');
      }
    }
  }

  /// 网格间距可选范围
  static const double _gridGapMin = 6;
  static const double _gridGapMax = 48;

  /// 显示网格背景选择对话框（复用笔记的手绘填充风格选择组件）
  void _showGridDialog() {
    int? tempIndex = _gridIndex;
    double tempGap = _gridGap;

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => DSThemeBridge(
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'screens_gridBackgroundSettings'.tr,
                                textAlign: TextAlign.center,
                                style: DsTypography.title.copyWith(
                                  color: theme.text,
                                ),
                              ),
                              SizedBox(height: theme.spacing.lg),

                              // 网格风格选择（含「无」选项，确定后生效）
                              DsSketchFillPickerRow(
                                selected: tempIndex,
                                allowNone: true,
                                labelKey: 'screens_gridBackgroundStyle',
                                onChanged:
                                    (index) => setDialogState(() {
                                      tempIndex = index;
                                    }),
                              ),
                              SizedBox(height: theme.spacing.xl),

                              // 网格间距
                              Text(
                                'screens_gridGap'.tr,
                                style: DsTypography.heading.copyWith(
                                  color: theme.text,
                                ),
                              ),
                              SizedBox(height: theme.spacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: DSSlider(
                                      value:
                                          (tempGap - _gridGapMin) /
                                          (_gridGapMax - _gridGapMin),
                                      onChanged: (value) {
                                        setDialogState(() {
                                          tempGap =
                                              _gridGapMin +
                                              value *
                                                  (_gridGapMax - _gridGapMin);
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 50,
                                    child: Text(
                                      tempGap.round().toString(),
                                      style: DsTypography.body.copyWith(
                                        color: theme.text,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: theme.spacing.lg),

                              // 操作按钮
                              Row(
                                children: [
                                  Expanded(
                                    child: DSButton(
                                      label: 'screens_cancel'.tr,
                                      variant: DSButtonVariant.outline,
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                  SizedBox(width: theme.spacing.md),
                                  Expanded(
                                    child: DSButton(
                                      label: 'screens_save'.tr,
                                      onPressed: () {
                                        _applyGrid(tempIndex, tempGap);
                                        Navigator.pop(context);
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
          ),
    );
  }

  /// 填充方式选项
  static final List<DSSelectItem<BoxFit>> _fitItems = [
    DSSelectItem(value: BoxFit.cover, label: 'screens_cover'.tr),
    DSSelectItem(value: BoxFit.contain, label: 'screens_contain'.tr),
    DSSelectItem(value: BoxFit.fill, label: 'screens_fill'.tr),
    DSSelectItem(value: BoxFit.fitWidth, label: 'screens_fitWidth'.tr),
    DSSelectItem(value: BoxFit.fitHeight, label: 'screens_fitHeight'.tr),
    DSSelectItem(value: BoxFit.none, label: 'screens_none'.tr),
    DSSelectItem(value: BoxFit.scaleDown, label: 'screens_scaleDown'.tr),
  ];

  /// 显示全局背景设置对话框
  void _showBackgroundDialog() {
    String? tempPath = _backgroundPath;
    BoxFit tempFit = _backgroundFit;
    double tempBlur = _backgroundBlur;

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => DSThemeBridge(
                  child: Builder(
                    builder: (context) {
                      final theme = DSThemeBridge.resolve(context);
                      return JellyBox(
                        radius: theme.radii.xxl,
                        padding: EdgeInsets.all(theme.spacing.xl),
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'screens_globalBackgroundSettings'.tr,
                                textAlign: TextAlign.center,
                                style: DsTypography.title.copyWith(
                                  color: theme.text,
                                ),
                              ),
                              SizedBox(height: theme.spacing.lg),

                              // 背景图预览
                              if (tempPath != null)
                                _buildPreview(
                                  theme,
                                  tempPath!,
                                  tempFit,
                                  tempBlur,
                                ),

                              // 选择图片按钮
                              Row(
                                children: [
                                  Expanded(
                                    child: DSButton(
                                      label: 'screens_selectImage'.tr,
                                      icon: DsIconKind.image,
                                      onPressed: () async {
                                        final path = await _pickImage();
                                        if (path != null) {
                                          setDialogState(() {
                                            tempPath = path;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  if (tempPath != null) ...[
                                    SizedBox(width: theme.spacing.sm),
                                    DSIconButton(
                                      icon: DsIconKind.close,
                                      size: 40,
                                      color: theme.surfaceAlt,
                                      iconColor: theme.textSub,
                                      onPressed: () {
                                        setDialogState(() {
                                          tempPath = null;
                                        });
                                      },
                                      tooltip: 'screens_clear'.tr,
                                    ),
                                  ],
                                ],
                              ),

                              SizedBox(height: theme.spacing.xl),

                              // 填充方式
                              Text(
                                'screens_fillMode'.tr,
                                style: DsTypography.heading.copyWith(
                                  color: theme.text,
                                ),
                              ),
                              SizedBox(height: theme.spacing.sm),
                              DSSelect<BoxFit>(
                                items: _fitItems,
                                value: tempFit,
                                onChanged: (value) {
                                  setDialogState(() {
                                    tempFit = value;
                                  });
                                },
                              ),

                              SizedBox(height: theme.spacing.xl),

                              // 模糊程度
                              Text(
                                'screens_blurLevel'.tr,
                                style: DsTypography.heading.copyWith(
                                  color: theme.text,
                                ),
                              ),
                              SizedBox(height: theme.spacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: DSSlider(
                                      value: tempBlur / 10,
                                      onChanged: (value) {
                                        setDialogState(() {
                                          tempBlur = value * 10;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 50,
                                    child: Text(
                                      tempBlur.toStringAsFixed(1),
                                      style: DsTypography.body.copyWith(
                                        color: theme.text,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: theme.spacing.lg),

                              // 操作按钮
                              Row(
                                children: [
                                  Expanded(
                                    child: DSButton(
                                      label: 'screens_cancel'.tr,
                                      variant: DSButtonVariant.outline,
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                  SizedBox(width: theme.spacing.md),
                                  Expanded(
                                    child: DSButton(
                                      label: 'screens_save'.tr,
                                      onPressed: () {
                                        setState(() {
                                          _backgroundPath = tempPath;
                                          _backgroundFit = tempFit;
                                          _backgroundBlur = tempBlur;
                                        });
                                        _saveBackground();
                                        Navigator.pop(context);
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
          ),
    );
  }

  /// 背景图预览（带模糊叠层）
  Widget _buildPreview(
    AppThemeData theme,
    String path,
    BoxFit fit,
    double blur,
  ) {
    return Container(
      height: 200,
      width: double.infinity,
      margin: EdgeInsets.only(bottom: theme.spacing.lg),
      decoration: BoxDecoration(
        borderRadius: theme.radii.sm,
        border: Border.all(color: theme.stroke),
      ),
      child: ClipRRect(
        borderRadius: theme.radii.sm,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(path), fit: fit),
            if (blur > 0)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(color: const Color(0x00000000)),
              ),
          ],
        ),
      ),
    );
  }

  /// 显示纯色背景选择对话框（预设颜色 + 自定义颜色）
  void _showSolidColorDialog() {
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
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'screens_solidBackgroundColorSettings'.tr,
                          textAlign: TextAlign.center,
                          style: DsTypography.title.copyWith(color: theme.text),
                        ),
                        SizedBox(height: theme.spacing.lg),

                        // 预设颜色网格
                        Text(
                          'screens_presetColors'.tr,
                          style: DsTypography.heading.copyWith(
                            color: theme.text,
                          ),
                        ),
                        SizedBox(height: theme.spacing.sm),
                        Wrap(
                          spacing: theme.spacing.sm,
                          runSpacing: theme.spacing.sm,
                          children:
                              _predefinedColors.map((color) {
                                final isSelected = _backgroundColor == color;
                                return GestureDetector(
                                  onTap: () {
                                    _applyBackgroundColor(color);
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
                          label: 'screens_customColorWithTransparency'.tr,
                          icon: DsIconKind.palette,
                          variant: DSButtonVariant.outline,
                          expand: true,
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showAdvancedColorPicker(
                              _backgroundColor ?? Colors.blue,
                            );
                          },
                        ),

                        // 恢复默认背景（清除纯色设置）
                        if (_backgroundColor != null) ...[
                          SizedBox(height: theme.spacing.md),
                          DSButton(
                            label: 'screens_restoreDefaultBackground'.tr,
                            icon: DsIconKind.close,
                            variant: DSButtonVariant.ghost,
                            expand: true,
                            onPressed: () {
                              _applyBackgroundColor(null);
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                        SizedBox(height: theme.spacing.md),
                        DSButton(
                          label: 'screens_cancel'.tr,
                          variant: DSButtonVariant.ghost,
                          expand: true,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }

  /// 显示高级颜色选择器（支持透明通道）
  void _showAdvancedColorPicker(Color initialColor) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) {
        // pickerColor 需在 StatefulBuilder 外声明，避免重建时被重置
        Color pickerColor = initialColor;
        return StatefulBuilder(
          builder:
              (context, setDialogState) => DSThemeBridge(
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
                              'screens_solidBackgroundColorSettings'.tr,
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

                            SizedBox(height: theme.spacing.lg),

                            // 颜色选择器：预设颜色 + 常规取色器（支持透明通道）
                            AppColorPicker(
                              selectedColor: pickerColor,
                              onColorChanged: (Color color) {
                                setDialogState(() {
                                  pickerColor = color;
                                });
                              },
                              presets: _predefinedColors,
                              enableAlpha: true,
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
                                      _applyBackgroundColor(pickerColor);
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

  /// 墨线档位文案（下标与 DsInkStyle.labels 对应）
  static const List<String> _inkStyleKeys = [
    'screens_inkStyleGentle',
    'screens_inkStylePlayful',
    'screens_inkStyleExpressive',
  ];

  /// 完整主题选择：色板 × 墨线档位成套切换，点击即全局生效
  Widget _buildThemePicker() {
    final theme = DSThemeBridge.resolve(context);

    return ListenableBuilder(
      // 主题 = 配色 + 墨线，两个控制器合并监听选中态
      listenable: Listenable.merge([
        DsThemeColorController(),
        DsInkStyleController(),
      ]),
      builder: (context, _) {
        final paletteId = DsThemeColorController().paletteId;
        final inkIndex = DsInkStyle.index;
        final customStyleId = DsInkStyleController().customStyleId;
        return Wrap(
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.md,
          children:
              DsThemePresets.all.map((preset) {
                // 自选描边风格时不比对墨线（预设只换配色），
                // 同色板的不同预设以 presetId 区分
                final selected =
                    preset.palette.id == paletteId &&
                    (customStyleId != null
                        ? preset.id == DsInkStyleController().presetId
                        : (preset.inkIndex == inkIndex &&
                              preset.strokeWidth == DsInkStyle.strokeWidth));
                return GestureDetector(
                  onTap: () {
                    DsThemeColorController().setPalette(preset.palette.id);
                    // 自选描边风格时预设不改墨线（自选优先）
                    DsInkStyleController().applyPreset(preset);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 双层圆点：外圈主色、内芯背景色，直观预览主题观感
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: preset.palette.primary,
                          border: Border.all(
                            color: selected
                                ? preset.palette.text
                                : DsColors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: preset.palette.background,
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check,
                                    size: 16,
                                    color: preset.palette.primary,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'screens_themePreset_${preset.id}'.tr,
                        style: DsTypography.caption.copyWith(
                          color: selected ? theme.text : theme.textSub,
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                      ),
                      // 墨线档位标注：同配色不同墨线的主题以此区分
                      Text(
                        _inkStyleKeys[preset.inkIndex].tr,
                        style: DsTypography.caption.copyWith(
                          fontSize: 10,
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  /// 描边线风格选择：自选优先于主题预设默认值
  ///
  /// 「跟随主题」= 套用当前主题预设自带的基础墨线（默认态）；
  /// 点任意风格 chip 即自选，此后切主题预设只换配色不改墨线。
  Widget _buildStrokeStylePicker() {
    final theme = DSThemeBridge.resolve(context);

    return ListenableBuilder(
      listenable: DsInkStyleController(),
      builder: (context, _) {
        final controller = DsInkStyleController();
        return Wrap(
          spacing: theme.spacing.md,
          runSpacing: theme.spacing.sm,
          children: [
            _buildFollowThemeChip(theme, controller.customStyleId == null),
            for (var i = 0; i < DsStrokeStyles.all.length; i++)
              _buildStrokeStyleChip(
                theme,
                DsStrokeStyles.all[i],
                i,
                controller.customStyleId == DsStrokeStyles.all[i].id,
              ),
          ],
        );
      },
    );
  }

  /// 「跟随主题」选项：回落主题预设默认墨线
  Widget _buildFollowThemeChip(AppThemeData theme, bool selected) {
    return GestureDetector(
      onTap: () => DsInkStyleController().clearCustom(),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: dsSketchDecoration(
          theme: theme,
          radius: BorderRadius.circular(12),
          stroke: selected ? theme.primary : theme.ink,
          strokeWidth: selected ? 2.6 : 1.6,
          seed: 80,
        ),
        child: Text(
          'screens_strokeFollowTheme'.tr,
          style: DsTypography.caption.copyWith(
            color: selected ? theme.text : theme.textSub,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }

  /// 风格选项：chip 的墨线即用该风格绘制，点击直观预览
  Widget _buildStrokeStyleChip(
    AppThemeData theme,
    DsStrokeStyle style,
    int index,
    bool selected,
  ) {
    return GestureDetector(
      onTap: () => DsInkStyleController().setCustomStyle(style.id),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: dsSketchDecoration(
          theme: theme,
          radius: BorderRadius.circular(12),
          stroke: selected ? theme.primary : theme.ink,
          strokeWidth: style.strokeWidth,
          drawConfig: style.drawConfig,
          seed: 81 + index,
        ),
        child: Text(
          style.labelKey.tr,
          style: DsTypography.caption.copyWith(
            color: selected ? theme.text : theme.textSub,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('screens_themeSettings'.tr)),
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return _isLoading
                ? Center(child: DSLoadingDots(color: theme.textSub))
                : ListView(
                  padding: EdgeInsets.all(theme.spacing.lg),
                  children: [
                    // 主题风格：配色 × 墨线成套选择，点击全局即时生效
                    SettingsGroup(
                      title: 'screens_themeStyle'.tr,
                      children: [_buildThemePicker()],
                    ),

                    SizedBox(height: theme.spacing.lg),

                    // 描边线风格：自选优先于主题预设默认墨线
                    SettingsGroup(
                      title: 'screens_strokeStyle'.tr,
                      children: [_buildStrokeStylePicker()],
                    ),

                    SizedBox(height: theme.spacing.lg),

                    // 全局背景设置卡片
                    SettingsTile(
                      icon: Icons.image,
                      iconColor: DsAccentColors.emerald,
                      title: 'screens_globalBackgroundImage'.tr,
                      subtitle:
                          _backgroundPath != null
                              ? 'screens_backgroundImageSet'.tr
                              : 'screens_backgroundImageNotSet'.tr,
                      onTap: _showBackgroundDialog,
                    ),

                    SizedBox(height: theme.spacing.lg),

                    // 纯色背景设置卡片
                    SettingsTile(
                      icon: Icons.palette,
                      iconColor: DsAccentColors.violet,
                      title: 'screens_solidBackgroundColor'.tr,
                      subtitle:
                          _backgroundColor != null
                              ? 'screens_solidBackgroundSet'.tr
                              : 'screens_solidBackgroundNotSet'.tr,
                      onTap: _showSolidColorDialog,
                    ),

                    SizedBox(height: theme.spacing.lg),

                    // 网格背景设置卡片
                    SettingsTile(
                      icon: Icons.grid_on,
                      iconColor: DsAccentColors.amber,
                      title: 'screens_gridBackground'.tr,
                      subtitle:
                          _gridIndex != null
                              ? 'screens_gridBackgroundSet'.tr
                              : 'screens_gridBackgroundNotSet'.tr,
                      onTap: _showGridDialog,
                    ),

                    SizedBox(height: theme.spacing.lg),

                    // 提示信息
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'screens_themeBackgroundDescription'.tr,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ),
                  ],
                );
          },
        ),
      ),
    );
  }
}
