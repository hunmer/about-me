import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/constants/app_icons.dart';
import '../adaptive_image.dart';
import '../custom_dialog.dart';
import '../form_fields/form_field_wrapper.dart';
import 'app_color_picker.dart';
import 'image_picker_dialog.dart';

/// 圆形选择器支持的选择类型
enum CircleIconPickerType { color, icon, image }

/// 圆形图标/头像选择器
///
/// 点击弹出 Popover 菜单，按 [supportedTypes] 显示「选择颜色/选择图标/选择图片」；
/// 展示优先级：头像图片 [avatarUrl] > 图标 [currentIcon]。
class CircleIconPicker extends StatelessWidget {
  final IconData currentIcon;
  final Color backgroundColor;

  /// 头像图片地址（非空时优先于图标展示）
  final String? avatarUrl;

  /// 直径
  final double size;

  /// 支持的选择类型，默认仅图标 + 颜色
  final Set<CircleIconPickerType> supportedTypes;

  /// 图片保存目录（仅支持图片选择时使用）
  final String imageSaveDirectory;

  final Function(IconData) onIconSelected;
  final Function(Color) onColorSelected;

  /// 图片选择/移除回调，空串表示移除图片（恢复显示图标）
  final Function(String)? onImageSelected;

  const CircleIconPicker({
    super.key,
    required this.currentIcon,
    required this.backgroundColor,
    required this.onIconSelected,
    required this.onColorSelected,
    this.avatarUrl,
    this.size = 64,
    this.supportedTypes = const {
      CircleIconPickerType.icon,
      CircleIconPickerType.color,
    },
    this.imageSaveDirectory = 'openai/agent_avatars',
    this.onImageSelected,
  });

  /// 弹出背景色选择（AppColorPicker：预设色 + 常规取色器）
  Future<void> _pickBackgroundColor(BuildContext context) async {
    final theme = DSThemeBridge.resolve(context);
    await showDSDialog<void>(
      context: context,
      theme: theme,
      builder:
          (dialogContext) => DSDialog(
            title: 'app_selectBackgroundColor'.tr,
            content: SingleChildScrollView(
              child: AppColorPicker(
                selectedColor: backgroundColor,
                onColorChanged: onColorSelected,
              ),
            ),
            confirmText: 'app_ok'.tr,
          ),
    );
  }

  Future<void> _pickIcon(BuildContext context) async {
    final result = await showIconPickerDialog(
      context,
      currentIcon,
      enableIconToImage: false,
    );
    if (result is IconData) {
      onIconSelected(result);
    }
  }

  Future<void> _pickImage(BuildContext context) async {
    final result = await ImagePickerDialog.show<Map<String, dynamic>>(
      context,
      initialUrl: avatarUrl,
      enableCrop: true,
      cropAspectRatio: 1.0,
    );
    if (result != null && result['url'] != null) {
      onImageSelected?.call(result['url'] as String);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final hasImage = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Center(
      child: DSPopover(
        width: 170,
        contentBuilder: (popoverContext, close) {
          final popoverTheme = DSThemeBridge.resolve(popoverContext);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (supportedTypes.contains(CircleIconPickerType.color))
                _PickerMenuAction(
                  icon: DsIconKind.palette,
                  label: 'app_selectColor'.tr,
                  theme: popoverTheme,
                  onTap: () {
                    close();
                    _pickBackgroundColor(context);
                  },
                ),
              if (supportedTypes.contains(CircleIconPickerType.icon))
                _PickerMenuAction(
                  icon: DsIconKind.mood,
                  label: 'app_selectIcon'.tr,
                  theme: popoverTheme,
                  onTap: () {
                    close();
                    _pickIcon(context);
                  },
                ),
              if (supportedTypes.contains(CircleIconPickerType.image)) ...[
                _PickerMenuAction(
                  icon: DsIconKind.photoLibrary,
                  label: 'app_selectImage'.tr,
                  theme: popoverTheme,
                  onTap: () {
                    close();
                    _pickImage(context);
                  },
                ),
                if (hasImage)
                  _PickerMenuAction(
                    icon: DsIconKind.trash,
                    label: 'app_removeImage'.tr,
                    theme: popoverTheme,
                    danger: true,
                    onTap: () {
                      close();
                      onImageSelected?.call('');
                    },
                  ),
              ],
            ],
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasImage ? null : backgroundColor,
            border: Border.all(
              color: theme.primary.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child:
              hasImage
                  ? AdaptiveImage(
                    imagePath: avatarUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    shape: BoxShape.circle,
                  )
                  : Icon(currentIcon, size: size / 2, color: Colors.white),
        ),
      ),
    );
  }
}

/// Popover 菜单项
class _PickerMenuAction extends StatelessWidget {
  const _PickerMenuAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.danger = false,
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.text;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: pressed ? theme.surfaceAlt : null,
            borderRadius: theme.radii.sm,
          ),
          child: Row(
            children: [
              DsIcon(icon, size: 16, color: accent),
              SizedBox(width: theme.spacing.sm),
              Text(label, style: DsTypography.caption.copyWith(color: accent)),
            ],
          ),
        );
      },
    );
  }
}

/// 图标头像字段（融合自 icon_avatar_row_field.dart）
///
/// 单个圆形选择器同时支持图标、背景色、头像图片；
/// 值格式为 Map {'icon': IconData, 'iconColor': Color, 'avatarUrl': String?}
class IconAvatarRowField extends StatefulWidget {
  /// 字段名称
  final String name;

  /// 初始图标
  final IconData? initialIcon;

  /// 初始图标背景色
  final Color? initialIconColor;

  /// 初始头像 URL
  final String? initialAvatarUrl;

  /// 是否启用
  final bool enabled;

  /// 头像保存目录
  final String avatarSaveDirectory;

  /// 值变化回调 - 返回 Map {'icon': IconData, 'iconColor': Color, 'avatarUrl': String?}
  final ValueChanged<Map<String, dynamic>>? onChanged;

  const IconAvatarRowField({
    super.key,
    required this.name,
    this.initialIcon,
    this.initialIconColor,
    this.initialAvatarUrl,
    this.enabled = true,
    this.avatarSaveDirectory = 'openai/agent_avatars',
    this.onChanged,
  });

  @override
  State<IconAvatarRowField> createState() => _IconAvatarRowFieldState();
}

class _IconAvatarRowFieldState extends State<IconAvatarRowField> {
  late IconData _selectedIcon;
  late Color _selectedIconColor;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.initialIcon ?? Icons.smart_toy;
    _selectedIconColor = widget.initialIconColor ?? DsColors.primary;
    _avatarUrl = widget.initialAvatarUrl;
  }

  /// 获取当前值
  Map<String, dynamic> getValue() {
    return {
      'icon': _selectedIcon,
      'iconColor': _selectedIconColor,
      'avatarUrl': _avatarUrl,
    };
  }

  /// 重置为初始值
  void reset() {
    setState(() {
      _selectedIcon = widget.initialIcon ?? Icons.smart_toy;
      _selectedIconColor = widget.initialIconColor ?? DsColors.primary;
      _avatarUrl = widget.initialAvatarUrl;
    });
  }

  void _notifyChanged() {
    widget.onChanged?.call(getValue());
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircleIconPicker(
        currentIcon: _selectedIcon,
        backgroundColor: _selectedIconColor,
        avatarUrl: _avatarUrl,
        supportedTypes: const {
          CircleIconPickerType.color,
          CircleIconPickerType.icon,
          CircleIconPickerType.image,
        },
        imageSaveDirectory: widget.avatarSaveDirectory,
        onIconSelected:
            widget.enabled
                ? (icon) {
                  setState(() {
                    _selectedIcon = icon;
                  });
                  _notifyChanged();
                }
                : (_) {},
        onColorSelected:
            widget.enabled
                ? (color) {
                  setState(() {
                    _selectedIconColor = color;
                  });
                  _notifyChanged();
                }
                : (_) {},
        onImageSelected:
            widget.enabled
                ? (url) {
                  setState(() {
                    _avatarUrl = url.isEmpty ? null : url;
                  });
                  _notifyChanged();
                }
                : (_) {},
      ),
    );
  }
}

/// WrappedFormField 版本的图标头像字段
class WrappedIconAvatarRowField extends StatefulWidget {
  /// 字段名称
  final String name;

  /// 初始值
  final Map<String, dynamic>? initialValue;

  /// 是否启用
  final bool enabled;

  /// 值变化回调
  final ValueChanged<Map<String, dynamic>>? onChanged;

  /// 头像保存目录
  final String avatarSaveDirectory;

  const WrappedIconAvatarRowField({
    super.key,
    required this.name,
    this.initialValue,
    this.enabled = true,
    this.onChanged,
    this.avatarSaveDirectory = 'openai/agent_avatars',
  });

  @override
  State<WrappedIconAvatarRowField> createState() =>
      _WrappedIconAvatarRowFieldState();
}

class _WrappedIconAvatarRowFieldState extends State<WrappedIconAvatarRowField> {
  final GlobalKey<_IconAvatarRowFieldState> _fieldKey =
      GlobalKey<_IconAvatarRowFieldState>();

  @override
  Widget build(BuildContext context) {
    final initialValue =
        widget.initialValue ??
        {'icon': Icons.smart_toy, 'iconColor': Colors.blue, 'avatarUrl': null};

    return WrappedFormField(
      name: widget.name,
      initialValue: initialValue,
      enabled: widget.enabled,
      onReset: () => _fieldKey.currentState?.reset(),
      onChanged: (v) => widget.onChanged?.call(v as Map<String, dynamic>),
      builder: (context, value, setValue) {
        return IconAvatarRowField(
          key: _fieldKey,
          name: widget.name,
          initialIcon: value['icon'] as IconData?,
          initialIconColor: value['iconColor'] as Color?,
          initialAvatarUrl: value['avatarUrl'] as String?,
          enabled: widget.enabled,
          avatarSaveDirectory: widget.avatarSaveDirectory,
          onChanged: (v) => setValue(v),
        );
      },
    );
  }
}

/// 完整图标选择对话框（融合自 icon_picker_dialog.dart）
///
/// 支持搜索、分页浏览、图标转图片。
class IconPickerDialog extends StatefulWidget {
  final IconData currentIcon;
  final bool enableIconToImage; // 是否启用图标转图片功能
  final bool forceConvertToImage; // 是否强制转换为图片（不可取消）

  const IconPickerDialog({
    super.key,
    required this.currentIcon,
    this.enableIconToImage = true,
    this.forceConvertToImage = false,
  });

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  late IconData selectedIcon;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  int _currentPage = 0;
  static const int _iconsPerPage = 200;
  List<IconData> _cachedFilteredIcons = [];
  late List<String> _iconNames;
  late List<IconData> _iconData;
  bool _convertToImage = false; // 是否转换为图片

  // 使用预定义的图标映射表中的图标（持久化 IconData）
  late List<IconData> allIcons;

  @override
  void initState() {
    super.initState();
    selectedIcon = widget.currentIcon;
    // 从AppIcons中获取所有预定义图标
    allIcons = AppIcons.predefinedIcons.values.toList();
    _iconNames = AppIcons.predefinedIcons.keys.toList();
    _iconData = AppIcons.predefinedIcons.values.toList();
    // 如果强制转换为图片，则初始化为 true
    if (widget.forceConvertToImage) {
      _convertToImage = true;
    }
    _updateFilteredIcons();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // 过滤图标列表
  List<IconData> get filteredIcons => _cachedFilteredIcons;

  void _updateFilteredIcons() {
    List<IconData> result;
    if (searchQuery.isEmpty) {
      result = _iconData;
    } else {
      // 先过滤名称列表
      final filteredIndices =
          _iconNames
              .asMap()
              .entries
              .where((entry) {
                return entry.value.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                );
              })
              .map((entry) => entry.key)
              .toList();

      // 转换为对应的图标数据
      result = filteredIndices.map((index) => _iconData[index]).toList();
    }

    // 重置页码当过滤结果变化时
    if (_currentPage > 0 && _currentPage * _iconsPerPage >= result.length) {
      _currentPage = 0;
    }

    _cachedFilteredIcons = result;
  }

  // 获取当前页的图标
  List<IconData> get _currentPageIcons {
    final start = _currentPage * _iconsPerPage;
    final end = start + _iconsPerPage;
    return filteredIcons.sublist(
      start.clamp(0, filteredIcons.length),
      end.clamp(0, filteredIcons.length),
    );
  }

  // 总页数
  int get _totalPages {
    return (filteredIcons.length / _iconsPerPage).ceil();
  }

  /// 将图标转换为图片
  Future<Map<String, dynamic>?> _convertIconToImage(IconData icon) async {
    try {
      // 创建测试环境来渲染图标
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 设置画布大小
      const size = 100.0;

      // 绘制图标
      final iconPainter = IconPainter(
        icon: icon,
        size: 80.0,
        color: Colors.black,
      );
      iconPainter.paint(canvas, const Size(100, 100));

      // 结束录制
      final picture = recorder.endRecording();

      // 转换为图片
      final img = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes != null) {
        return {'bytes': bytes, 'icon': icon};
      }
      return null;
    } catch (e) {
      print('图标转图片失败: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return CustomDialog(
      title: 'widget_selectIcon'.tr,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 搜索框
          DSInput(
            controller: _searchController,
            hint: 'widget_searchIcons'.tr,
            prefix: DsIcon(DsIconKind.search, size: 20, color: theme.textSub),
            onChanged: (value) {
              if (_debounceTimer?.isActive ?? false) {
                _debounceTimer?.cancel();
              }
              _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                setState(() {
                  searchQuery = value;
                  _updateFilteredIcons();
                });
              });
            },
          ),
          const SizedBox(height: 16),

          // 图标转图片选项
          if (widget.enableIconToImage)
            Row(
              children: [
                DSCheckbox(
                  value: _convertToImage,
                  onChanged:
                      widget.forceConvertToImage
                          ? null
                          : (value) {
                            setState(() {
                              _convertToImage = value ?? false;
                            });
                          },
                ),
                Expanded(
                  child: Text(
                    'widget_convertIconToImage'.tr,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                ),
                Pressable(
                  onPressed: _showConvertHelp,
                  semanticLabel: 'widget_whatIsIconToImage'.tr,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: DsIcon(
                      DsIconKind.info,
                      size: 18,
                      color: theme.textSub,
                    ),
                  ),
                ),
              ],
            ),

          if (widget.enableIconToImage) const SizedBox(height: 16),

          // 图标网格（果冻单元承载持久化 IconData）
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _currentPageIcons.length,
              itemBuilder: (context, index) {
                final icon = _currentPageIcons[index];
                final isSelected = icon == selectedIcon;
                return Pressable(
                  onPressed: () {
                    setState(() {
                      selectedIcon = icon;
                    });
                  },
                  semanticLabel: 'icon',
                  builder: (context, states) {
                    final pressed = states.contains(WidgetState.pressed);
                    return JellyBox(
                      radius: theme.radii.md,
                      color: isSelected ? theme.primary : null,
                      raised: isSelected && !pressed,
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        size: 24,
                        color: isSelected ? theme.onPrimary : theme.text,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_totalPages > 1) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageButton(
                  icon: DsIconKind.chevronLeft,
                  enabled: _currentPage > 0,
                  onPressed: () => setState(() => _currentPage--),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${_currentPage + 1}/$_totalPages',
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),
                ),
                _buildPageButton(
                  icon: DsIconKind.chevronRight,
                  enabled: _currentPage < _totalPages - 1,
                  onPressed: () => setState(() => _currentPage++),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        DSButton(
          label: 'widget_cancel'.tr,
          variant: DSButtonVariant.outline,
          size: DSButtonSize.sm,
          onPressed: () => Navigator.pop(context),
        ),
        DSButton(
          label: 'widget_confirm'.tr,
          size: DSButtonSize.sm,
          onPressed: () async {
            if (_convertToImage) {
              final result = await _convertIconToImage(selectedIcon);
              Navigator.pop(context, result);
            } else {
              Navigator.pop(context, selectedIcon);
            }
          },
        ),
      ],
    );
  }

  /// 翻页按钮
  Widget _buildPageButton({
    required DsIconKind icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: enabled ? onPressed : null,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return JellyBox(
          width: 36,
          height: 36,
          radius: theme.radii.md,
          raised: enabled && !pressed,
          alignment: Alignment.center,
          child: DsIcon(
            icon,
            size: 18,
            color:
                enabled
                    ? theme.primaryText
                    : theme.textSub.withValues(alpha: 0.5),
          ),
        );
      },
    );
  }

  /// 图标转图片功能说明
  void _showConvertHelp() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSDialog(
            title: 'widget_iconToImage'.tr,
            message: 'widget_iconToImageDescription'.tr,
            confirmText: 'widget_confirm'.tr,
          ),
    );
  }
}

/// 图标绘制器
class IconPainter extends CustomPainter {
  final IconData icon;
  final double size;
  final Color color;

  IconPainter({required this.icon, required this.size, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 居中绘制图标
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: this.size,
          fontFamily: icon.fontFamily,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final offset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 显示图标选择器对话框的工具方法
Future<dynamic> showIconPickerDialog(
  BuildContext context,
  IconData currentIcon, {
  bool enableIconToImage = true,
  bool forceConvertToImage = false,
}) {
  // 使用原生showDialog，但确保使用rootNavigator以保证在最上层显示
  return showDialog<dynamic>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    useSafeArea: true,
    useRootNavigator: true, // 确保在根Navigator上显示，这样会在所有其他对话框之上
    builder:
        (context) => IconPickerDialog(
          currentIcon: currentIcon,
          enableIconToImage: enableIconToImage,
          forceConvertToImage: forceConvertToImage,
        ),
  );
}
