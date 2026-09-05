import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../picker/location_picker.dart';

/// 位置选择器字段组件
///
/// 集成 LocationPicker，提供位置选择功能（LocationPicker 属共享基建）；
/// 触发器为 DS 果冻卡片。
class LocationPickerField extends StatelessWidget {
  /// 当前位置地址
  final String? currentLocation;

  /// 字段标签
  final String? labelText;

  /// 占位提示
  final String? hintText;

  /// 是否启用
  final bool enabled;

  /// 值变化回调
  final ValueChanged<String> onLocationChanged;

  /// 是否为移动端
  final bool isMobile;

  const LocationPickerField({
    super.key,
    required this.onLocationChanged,
    this.currentLocation,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.isMobile = true,
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
          DsIcon(DsIconKind.pin, size: 20, color: theme.primary),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Text(
              currentLocation ?? labelText ?? hintText ?? '选择位置',
              style: DsTypography.body.copyWith(
                color: currentLocation != null ? theme.text : theme.textSub,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                final result = await showDialog<String>(
                  context: context,
                  builder:
                      (context) => LocationPicker(
                        isMobile: isMobile,
                        onLocationSelected: (address) {
                          Navigator.of(context).pop(address);
                        },
                      ),
                );
                if (result != null) {
                  onLocationChanged(result);
                }
              }
              : null,
      child: trigger,
    );
  }
}
