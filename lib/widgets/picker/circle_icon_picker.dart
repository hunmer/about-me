import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../adaptive_image.dart';
import '../form_fields/form_field_wrapper.dart';
import 'app_color_picker.dart';
import 'icon_picker_dialog.dart';
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
      saveDirectory: imageSaveDirectory,
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
