import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

class AddTagDialog extends StatefulWidget {
  const AddTagDialog({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AddTagDialogState createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<AddTagDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.xl),
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'goods_addTag'.tr,
            textAlign: TextAlign.center,
            style: DsTypography.title.copyWith(color: theme.text),
          ),
          SizedBox(height: theme.spacing.lg),
          DSInput(
            controller: _controller,
            label: 'goods_tagName'.tr,
            hint: 'goods_tagNameHint'.tr,
          ),
          SizedBox(height: theme.spacing.lg),
          Row(
            children: [
              Expanded(
                child: DSButton(
                  label: 'app_cancel'.tr,
                  variant: DSButtonVariant.outline,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: DSButton(
                  label: 'app_ok'.tr,
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      Navigator.of(context).pop(_controller.text);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
