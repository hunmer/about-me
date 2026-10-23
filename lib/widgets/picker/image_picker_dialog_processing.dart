part of 'image_picker_dialog.dart';

/// 图片按字节裁剪/转换后一次上传，返回稳定资源引用。
extension _ImagePickerDialogProcessingExt on _ImagePickerDialogState {
  Future<void> _processSelectedImages(
    BuildContext context,
    List<_PickedImage> images,
  ) async {
    try {
      final results = <Map<String, dynamic>>[];
      for (final picked in images) {
        var bytes = await SdkMediaService.readPicked(picked.image);
        var name = picked.image.name;
        if (widget.enableCrop) {
          if (!context.mounted) return;
          final cropped = await _showCropDialog(context, bytes);
          if (cropped == null) {
            continue;
          }
          bytes = cropped;
          name = '${path.basenameWithoutExtension(name)}.png';
        }
        final result = await SdkMediaService.saveImage(
          bytes,
          fileName: name,
          enableCompression: widget.enableCompression,
          quality: widget.compressionQuality,
        );
        if (picked.liveVideo != null) {
          final video = await SdkMediaService.importPicked(picked.liveVideo!);
          result['liveVideoUrl'] = video.reference;
        }
        results.add(result);
      }
      if (results.isNotEmpty && context.mounted) {
        Navigator.of(context).pop(_multiple ? results : results.first);
      }
    } catch (error) {
      debugPrint('处理图片失败: $error');
      if (context.mounted) {
        Toast.error('${'image_picker_selectImageFailed'.tr}: $error');
      }
    }
  }

  Future<Uint8List?> _showCropDialog(
    BuildContext context,
    Uint8List imageBytes,
  ) async {
    final cropController = CropController();

    if (!context.mounted) {
      return null;
    }

    return showDSDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) {
        final theme = DSThemeBridge.resolve(dialogContext);
        return JellyBox(
          radius: theme.radii.xxl,
          constraints: const BoxConstraints(maxWidth: 360),
          padding: EdgeInsets.all(theme.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'image_picker_cropImage'.tr,
                style: DsTypography.title.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.md),
              SizedBox(
                width: 300,
                height: 300,
                child: ClipRRect(
                  borderRadius: theme.radii.lg,
                  child: Crop(
                    controller: cropController,
                    image: imageBytes,
                    aspectRatio: widget.cropAspectRatio,
                    onCropped: (result) async {
                      switch (result) {
                        case CropSuccess(:final croppedImage):
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(croppedImage);
                          }
                        case CropFailure():
                          if (dialogContext.mounted) {
                            Toast.error('image_picker_cropFailed'.tr);
                          }
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: theme.spacing.md),
              Row(
                children: [
                  Expanded(
                    child: DSButton(
                      label: 'app_cancel'.tr,
                      variant: DSButtonVariant.outline,
                      size: DSButtonSize.sm,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DSButton(
                      label: 'app_confirm'.tr,
                      size: DSButtonSize.sm,
                      onPressed: () => cropController.crop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
