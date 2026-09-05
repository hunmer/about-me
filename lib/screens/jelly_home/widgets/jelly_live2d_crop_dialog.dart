import 'dart:math' as math;
import 'dart:typed_data';

import 'package:aboutme/design_system/design_system.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'jelly_live2d_crop_region.dart';

Future<JellyLive2DCropRegion?> showJellyLive2DCropDialog({
  required BuildContext context,
  required Uint8List image,
  required Size imageSize,
  required JellyLive2DCropRegion initialRegion,
}) {
  return showDSDialog<JellyLive2DCropRegion>(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => _JellyLive2DCropDialog(
          image: image,
          imageSize: imageSize,
          initialRegion: initialRegion,
        ),
  );
}

class _JellyLive2DCropDialog extends StatefulWidget {
  const _JellyLive2DCropDialog({
    required this.image,
    required this.imageSize,
    required this.initialRegion,
  });

  final Uint8List image;
  final Size imageSize;
  final JellyLive2DCropRegion initialRegion;

  @override
  State<_JellyLive2DCropDialog> createState() => _JellyLive2DCropDialogState();
}

class _JellyLive2DCropDialogState extends State<_JellyLive2DCropDialog> {
  late JellyLive2DCropRegion _region = widget.initialRegion;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final editorHeight = math.min(
      480.0,
      MediaQuery.sizeOf(context).height * 0.55,
    );

    return DSDialog(
      title: 'screens_jellyLive2dSetCropRegion'.tr,
      confirmText: 'screens_jellyLive2dApply'.tr,
      cancelText: 'screens_cancel'.tr,
      onConfirm: () => Navigator.of(context).pop(_region),
      onCancel: () => Navigator.of(context).pop(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: editorHeight,
            child: Crop(
              image: widget.image,
              aspectRatio: widget.imageSize.width / widget.imageSize.height,
              initialRectBuilder: InitialRectBuilder.withArea(
                widget.initialRegion.toImageRect(widget.imageSize),
              ),
              baseColor: theme.backgroundAlt,
              maskColor: theme.text.withValues(alpha: 0.42),
              progressIndicator: const Center(child: DSLoadingDots(size: 8)),
              cornerDotBuilder: (_, _) => DotControl(color: theme.primary),
              onMoved: (_, imageRect) {
                _region = JellyLive2DCropRegion.fromImageRect(
                  imageRect,
                  widget.imageSize,
                );
              },
              onCropped: (_) {},
            ),
          ),
          SizedBox(height: theme.spacing.md),
          DSButton(
            label: 'screens_jellyLive2dResetCrop'.tr,
            icon: DsIconKind.refresh,
            size: DSButtonSize.sm,
            variant: DSButtonVariant.outline,
            onPressed:
                () => Navigator.of(
                  context,
                ).pop(const JellyLive2DCropRegion.full()),
          ),
        ],
      ),
    );
  }
}
