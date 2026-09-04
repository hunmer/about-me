import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/home_layout_manager.dart';
import 'package:aboutme/screens/home_screen/models/layout_config.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 主页主题设置页面
class BackgroundSettingsPage extends StatefulWidget {
  const BackgroundSettingsPage({super.key});

  @override
  State<BackgroundSettingsPage> createState() => _BackgroundSettingsPageState();
}

class _BackgroundSettingsPageState extends State<BackgroundSettingsPage> {
  final HomeLayoutManager _layoutManager = HomeLayoutManager();
  List<LayoutConfig> _layouts = [];
  bool _isLoading = true;

  // 全局背景图设置
  String? _globalBackgroundPath;
  BoxFit _globalBackgroundFit = BoxFit.cover;
  double _globalBackgroundBlur = 0.0;

  // 全局小组件透明度 (0-1) - 影响整个小组件
  double _globalWidgetOpacity = 1.0;

  // 全局小组件背景颜色透明度 (0-1) - 仅影响背景颜色
  double _globalWidgetBackgroundOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      // 加载所有布局
      final layouts = await _layoutManager.getSavedLayouts();

      // 加载全局背景设置
      final globalConfig = await _layoutManager.getGlobalBackgroundConfig();

      if (mounted) {
        setState(() {
          _layouts = layouts;
          _globalBackgroundPath =
              globalConfig['backgroundImagePath'] as String?;
          _globalBackgroundFit = LayoutConfig.boxFitFromString(
            globalConfig['backgroundFit'] as String?,
          );
          _globalBackgroundBlur =
              (globalConfig['backgroundBlur'] as num?)?.toDouble() ?? 0.0;
          _globalWidgetOpacity =
              (globalConfig['widgetOpacity'] as num?)?.toDouble() ?? 1.0;
          _globalWidgetBackgroundOpacity =
              (globalConfig['widgetBackgroundOpacity'] as num?)?.toDouble() ??
              1.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载背景设置失败: $e');
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
  Future<void> _saveGlobalBackground() async {
    try {
      await _layoutManager.saveGlobalBackgroundConfig({
        'backgroundImagePath': _globalBackgroundPath,
        'backgroundFit': LayoutConfig.boxFitToString(_globalBackgroundFit),
        'backgroundBlur': _globalBackgroundBlur,
        'widgetOpacity': _globalWidgetOpacity,
        'widgetBackgroundOpacity': _globalWidgetBackgroundOpacity,
      });

      if (mounted) {
        toastService.showToast('主题设置已保存');
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('保存失败：$e');
      }
    }
  }

  /// 更新布局背景
  Future<void> _updateLayoutBackground(
    LayoutConfig layout,
    String? imagePath,
    BoxFit fit,
    double blur,
  ) async {
    try {
      final updatedLayout = layout.copyWith(
        backgroundImagePath: imagePath,
        clearBackgroundImage: imagePath == null,
        backgroundFit: fit,
        backgroundBlur: blur,
        updatedAt: DateTime.now(),
      );

      final layouts = await _layoutManager.getSavedLayouts();
      final index = layouts.indexWhere((l) => l.id == layout.id);

      if (index != -1) {
        layouts[index] = updatedLayout;
        await _layoutManager.saveLayoutConfigs(layouts);
        await _loadSettings();

        if (mounted) {
          toastService.showToast('布局"${layout.name}"的背景已更新');
        }
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('更新失败：$e');
      }
    }
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
  void _showGlobalBackgroundDialog() {
    String? tempPath = _globalBackgroundPath;
    BoxFit tempFit = _globalBackgroundFit;
    double tempBlur = _globalBackgroundBlur;

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
                                          _globalBackgroundPath = tempPath;
                                          _globalBackgroundFit = tempFit;
                                          _globalBackgroundBlur = tempBlur;
                                        });
                                        _saveGlobalBackground();
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

  /// 显示布局背景设置对话框
  void _showLayoutBackgroundDialog(LayoutConfig layout) {
    String? tempPath = layout.backgroundImagePath;
    BoxFit tempFit = layout.backgroundFit;
    double tempBlur = layout.backgroundBlur;

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
                                'screens_layoutBackgroundSettings'.trParams({
                                  'layoutName': layout.name,
                                }),
                                textAlign: TextAlign.center,
                                style: DsTypography.title.copyWith(
                                  color: theme.text,
                                ),
                              ),
                              SizedBox(height: theme.spacing.lg),

                              // 提示信息
                              Container(
                                padding: EdgeInsets.all(theme.spacing.md),
                                decoration: BoxDecoration(
                                  color: theme.primary.withValues(alpha: 0.08),
                                  borderRadius: theme.radii.sm,
                                ),
                                child: Row(
                                  children: [
                                    DsIcon(
                                      DsIconKind.info,
                                      size: 20,
                                      color: theme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'screens_customBackgroundHasPriority'
                                            .tr,
                                        style: DsTypography.caption.copyWith(
                                          color: theme.textSub,
                                        ),
                                      ),
                                    ),
                                  ],
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
                                      tooltip:
                                          'screens_clearUseGlobalBackground'.tr,
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
                                        _updateLayoutBackground(
                                          layout,
                                          tempPath,
                                          tempFit,
                                          tempBlur,
                                        );
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
                    // 全局背景设置卡片
                    DSListItem(
                      leading: DsIcon(
                        DsIconKind.image,
                        size: 22,
                        color: theme.primary,
                      ),
                      title: 'screens_globalBackgroundImage'.tr,
                      subtitle:
                          _globalBackgroundPath != null
                              ? 'screens_backgroundImageSet'.tr
                              : 'screens_backgroundImageNotSet'.tr,
                      showChevron: true,
                      onTap: _showGlobalBackgroundDialog,
                    ),

                    SizedBox(height: theme.spacing.lg),

                    // 全局小组件透明度设置卡片
                    _buildOpacityCard(
                      theme,
                      icon: DsIconKind.drop,
                      title: 'screens_widgetOverallOpacity'.tr,
                      description: 'screens_widgetOverallOpacityDescription'.tr,
                      value: _globalWidgetOpacity,
                      onChanged: (value) {
                        setState(() {
                          _globalWidgetOpacity = value;
                        });
                      },
                      onChangeEnd: (_) => _saveGlobalBackground(),
                    ),

                    SizedBox(height: theme.spacing.lg),

                    // 全局小组件背景颜色透明度设置卡片
                    _buildOpacityCard(
                      theme,
                      icon: DsIconKind.palette,
                      title: 'screens_backgroundColorOpacity'.tr,
                      description:
                          'screens_backgroundColorOpacityDescription'.tr,
                      value: _globalWidgetBackgroundOpacity,
                      onChanged: (value) {
                        setState(() {
                          _globalWidgetBackgroundOpacity = value;
                        });
                      },
                      onChangeEnd: (_) => _saveGlobalBackground(),
                    ),

                    SizedBox(height: theme.spacing.xxl),

                    // 布局背景设置标题
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'screens_layoutBackgroundSettingsTitle'.tr,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 提示信息
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'screens_layoutBackgroundSettingsDescription'.tr,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ),

                    SizedBox(height: theme.spacing.lg),

                    // 布局列表
                    if (_layouts.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: DSEmptyState(
                            emoji: '🗂️',
                            title: 'screens_noSavedLayouts'.tr,
                            message: 'screens_saveLayoutFirst'.tr,
                          ),
                        ),
                      )
                    else
                      ...List.generate(_layouts.length, (index) {
                        final layout = _layouts[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: theme.spacing.sm),
                          child: DSListItem(
                            leading: JellyBox(
                              width: 36,
                              height: 36,
                              radius: theme.radii.circle,
                              color: theme.primary,
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: DsTypography.label.copyWith(
                                  color: theme.onPrimary,
                                ),
                              ),
                            ),
                            title: layout.name,
                            subtitle:
                                layout.backgroundImagePath != null
                                    ? 'screens_customBackgroundImage'.tr
                                    : 'screens_useGlobalBackgroundImage'.tr,
                            showChevron: true,
                            onTap: () => _showLayoutBackgroundDialog(layout),
                          ),
                        );
                      }),
                  ],
                );
          },
        ),
      ),
    );
  }

  /// 构建透明度设置卡片
  Widget _buildOpacityCard(
    AppThemeData theme, {
    required DsIconKind icon,
    required String title,
    required String description,
    required double value,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return JellyBox(
      radius: theme.radii.lg,
      raised: false,
      padding: EdgeInsets.all(theme.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIcon(icon, size: 22, color: theme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: DsTypography.heading.copyWith(color: theme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 16),
          DSSlider(
            value: value,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'screens_zeroPercentFullyTransparent'.tr,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
              Text(
                'screens_oneHundredPercentOpaque'.tr,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
