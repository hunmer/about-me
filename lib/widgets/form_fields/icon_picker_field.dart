import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../picker/icon_picker_dialog.dart';

/// 图标选择器字段组件
///
/// 集成 IconPickerDialog，提供图标选择功能；
/// 触发器为 DS 果冻卡片（IconPickerDialog 属共享基建，保持原有弹窗）。
class IconPickerField extends StatelessWidget {
  /// 当前选中的图标（持久化 IconData）
  final IconData currentIcon;

  /// 字段标签
  final String? labelText;

  /// 是否启用
  final bool enabled;

  /// 值变化回调
  final ValueChanged<IconData> onIconChanged;

  /// 是否启用图标转图片功能
  final bool enableIconToImage;

  const IconPickerField({
    super.key,
    required this.currentIcon,
    required this.onIconChanged,
    this.labelText,
    this.enabled = true,
    this.enableIconToImage = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    Widget trigger = JellyBox(
      height: 50,
      radius: theme.radii.lg,
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
      child: Row(
        children: [
          Icon(currentIcon, size: 24, color: theme.text),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Text(
              labelText ?? '选择图标',
              style: DsTypography.body.copyWith(color: theme.text),
            ),
          ),
          if (enabled)
            DsIcon(DsIconKind.chevronDown, size: 18, color: theme.primary),
        ],
      ),
    );
    if (!enabled) {
      trigger = Opacity(opacity: 0.55, child: IgnorePointer(child: trigger));
    }

    return Pressable(
      onPressed:
          enabled
              ? () async {
                final result = await showDialog<dynamic>(
                  context: context,
                  builder:
                      (context) => IconPickerDialog(
                        currentIcon: currentIcon,
                        enableIconToImage: enableIconToImage,
                      ),
                );
                if (result != null) {
                  if (result is IconData) {
                    onIconChanged(result);
                  } else if (result is Map && result['icon'] is IconData) {
                    onIconChanged(result['icon'] as IconData);
                  }
                }
              }
              : null,
      child: trigger,
    );
  }
}
