import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'icon_picker_dialog.dart';

class CircleIconPicker extends StatelessWidget {
  final IconData currentIcon;
  final Color backgroundColor;
  final Function(IconData) onIconSelected;
  final Function(Color) onColorSelected;

  const CircleIconPicker({
    super.key,
    required this.currentIcon,
    required this.backgroundColor,
    required this.onIconSelected,
    required this.onColorSelected,
  });

  /// 弹出背景色选择（flutter_colorpicker 的 ColorPicker 为第三方保留项）
  Future<void> _pickBackgroundColor(BuildContext context) async {
    final theme = DSThemeBridge.resolve(context);
    await showDSDialog<void>(
      context: context,
      theme: theme,
      builder:
          (dialogContext) => DSDialog(
            title: 'app_selectBackgroundColor'.tr,
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: backgroundColor,
                onColorChanged: onColorSelected,
                showLabel: true,
                pickerAreaHeightPercent: 0.8,
              ),
            ),
            confirmText: 'app_ok'.tr,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Center(
      child: GestureDetector(
        onTap: () async {
          final IconData? result = await showIconPickerDialog(
            context,
            currentIcon,
          );
          if (result != null) {
            onIconSelected(result);
          }
        },
        child: Stack(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
                border: Border.all(
                  color: theme.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Icon(currentIcon, size: 32, color: Colors.white),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => _pickBackgroundColor(context),
                child: JellyBox(
                  width: 24,
                  height: 24,
                  radius: theme.radii.circle,
                  alignment: Alignment.center,
                  child: DsIcon(
                    DsIconKind.palette,
                    size: 13,
                    color: theme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
