part of 'image_picker_dialog.dart';

/// 图片处理管线（按功能从主文件拆出）：
/// 统一处理选中图片：保存 → 裁剪(可选) → 压缩缩略图 → 返回结果
extension _ImagePickerDialogProcessingExt on _ImagePickerDialogState {
  /// 非 gif 主图统一转 webp（gif 可能含动画，保留原格式）。
  ///
  /// [savedImagePath] 已保存主图的本地绝对路径（远程存储=物化临时文件）
  /// [relativePath] 对应的存储相对路径（'./' 前缀）
  /// 返回转换后的 (相对路径, 绝对路径)；转换失败（如 Web 平台不支持）原样返回
  Future<(String, String)> _convertToWebpIfNeeded(
    String savedImagePath,
    String relativePath,
  ) async {
    final ext = path.extension(savedImagePath).toLowerCase();
    if (ext == '.gif' || ext == '.webp') return (relativePath, savedImagePath);

    try {
      final webpPath =
          '${savedImagePath.substring(0, savedImagePath.length - ext.length)}.webp';
      final converted = await ImageCompressionService().compressImage(
        sourcePath: savedImagePath,
        targetPath: webpPath,
        quality: widget.compressionQuality,
        format: CompressFormat.webp,
      );

      // 压缩服务在不支持的平台返回源路径；产物不存在视为失败，回退原格式
      if (converted == savedImagePath || !await File(converted).exists()) {
        final half = File(webpPath);
        if (await half.exists()) await half.delete();
        return (relativePath, savedImagePath);
      }
      debugPrint('主图已转 webp: $savedImagePath -> $converted');

      if (globalStorage.isRemote) {
        // 远程存储：webp 重新入库，并删除远端原格式 key
        final newRelative = await ImageUtils.saveBytesToAppDirectory(
          await File(converted).readAsBytes(),
          widget.saveDirectory,
          extension: '.webp',
        );
        try {
          await globalStorage.deleteFile(
            relativePath.startsWith('./')
                ? relativePath.substring(2)
                : relativePath,
          );
        } catch (_) {}
        return (newRelative, converted);
      }

      // 本地存储：删除原格式文件
      await File(savedImagePath).delete();
      return (await ImageUtils.toRelativePath(converted), converted);
    } catch (e) {
      debugPrint('转换 webp 失败，保留原格式: $e');
      return (relativePath, savedImagePath);
    }
  }

  /// 统一处理选中的图片：保存 → 裁剪(可选) → 压缩缩略图 → 返回结果
  Future<void> _processSelectedImages(
    BuildContext context,
    List<_PickedImage> images,
  ) async {
    try {
      if (images.isEmpty) {
        debugPrint('用户未选择图片');
        return;
      }

      final results = <Map<String, dynamic>>[];

      for (final picked in images) {
        try {
          final image = picked.image;
          debugPrint('处理图片: ${image.path}');

          // 保存图片并获取相对路径
          var relativePath = await ImageUtils.saveImage(
            File(image.path),
            widget.saveDirectory,
          );
          debugPrint('图片保存完成，相对路径: $relativePath');

          // 获取保存后的文件路径
          var savedImagePath = await ImageUtils.getAbsolutePath(relativePath);

          // 确认文件是否成功保存
          final fileExists = await File(savedImagePath).exists();
          debugPrint('图片保存路径: $savedImagePath, 文件是否存在: $fileExists');

          if (!fileExists) {
            throw Exception('文件保存后检查不存在: $savedImagePath');
          }

          // 非 gif 主图统一转 webp（gif 可能含动画，保留原格式）
          final webp = await _convertToWebpIfNeeded(
            savedImagePath,
            relativePath,
          );
          relativePath = webp.$1;
          savedImagePath = webp.$2;

          // 读取图片字节数据（与最终保存的格式一致）
          final bytes = await File(savedImagePath).readAsBytes();
          debugPrint('图片字节大小: ${bytes.length}');

          // 如果启用了裁剪功能，显示裁剪对话框
          if (widget.enableCrop && context.mounted) {
            debugPrint('启用裁剪，显示裁剪对话框...');
            final result = await _showCropDialog(
              context,
              bytes,
              savedImagePath,
              relativePath,
            );
            if (result != null) {
              debugPrint('裁剪完成');
              results.add(result);
            } else {
              debugPrint('裁剪被取消');
            }
          } else {
            debugPrint('处理压缩和缩略图...');
            // 处理压缩和缩略图
            final compressionResult = await _processImageCompression(
              savedImagePath,
              relativePath,
            );
            debugPrint('压缩结果: ${compressionResult.keys}');
            final result = {...compressionResult, 'bytes': bytes};
            if (picked.liveVideo != null) {
              final liveVideoUrl = await ImageUtils.saveImage(
                File(picked.liveVideo!.path),
                widget.saveDirectory,
              );
              result['liveVideoUrl'] = liveVideoUrl;
            }
            results.add(result);
          }
        } catch (e) {
          debugPrint('处理单张图片时发生错误: $e');
          rethrow;
        }
      }

      debugPrint('所有图片处理完成，结果数量: ${results.length}');
      if (results.isNotEmpty && context.mounted) {
        final result = _multiple ? results : results.first;
        debugPrint('返回结果，类型: ${_multiple ? "多张" : "单张"}');
        Navigator.of(context).pop(result);
      } else {
        debugPrint('警告: 结果为空或上下文未挂载');
      }
    } catch (e) {
      debugPrint('处理图片发生异常: $e');
      if (context.mounted) {
        Toast.error('${'image_picker_selectImageFailed'.tr}: $e');
      }
    }
  }

  /// 处理图片压缩和缩略图生成
  ///
  /// [savedImagePath] 保存后的图片绝对路径
  /// [relativePath] 相对路径
  /// 返回包含原图和缩略图信息的 Map
  Future<Map<String, dynamic>> _processImageCompression(
    String savedImagePath,
    String relativePath,
  ) async {
    if (!widget.enableCompression) {
      // 不压缩，直接返回原图
      return {'url': relativePath, 'thumbUrl': null};
    }

    try {
      // 生成缩略图路径
      String thumbPath;
      if (widget.thumbnailPath != null && widget.thumbnailPath!.isNotEmpty) {
        thumbPath = widget.thumbnailPath!;
      } else {
        // 默认在原文件名后加 .thumb
        final dir = path.dirname(savedImagePath);
        final filename = path.basenameWithoutExtension(savedImagePath);
        final ext = path.extension(savedImagePath);
        thumbPath = path.join(dir, '$filename.thumb$ext');
      }

      // 使用压缩服务生成缩略图
      final compressionService = ImageCompressionService();
      final compressedPath = await compressionService.compressImage(
        sourcePath: savedImagePath,
        targetPath: thumbPath,
        quality: widget.compressionQuality,
      );

      debugPrint('缩略图已生成: $compressedPath');

      // 压缩服务在不支持的平台会返回源路径而不生成文件；
      // heic 降级时输出路径扩展名也可能与 thumbPath 不同，统一以返回路径为准
      if (compressedPath == savedImagePath ||
          !await File(compressedPath).exists()) {
        debugPrint('缩略图未实际生成，跳过thumbUrl');
        return {'url': relativePath, 'thumbUrl': null};
      }

      // 计算缩略图的相对路径
      final thumbRelativePath = await ImageUtils.toRelativePath(compressedPath);

      return {'url': relativePath, 'thumbUrl': thumbRelativePath};
    } catch (e) {
      debugPrint('生成缩略图失败: $e');
      // 失败时返回原图
      return {'url': relativePath, 'thumbUrl': null};
    }
  }

  Future<Map<String, dynamic>?> _showCropDialog(
    BuildContext context,
    Uint8List imageBytes,
    String originalImagePath,
    String originalRelativePath,
  ) async {
    final cropController = CropController();
    final completer = Completer<Map<String, dynamic>?>();

    if (!context.mounted) {
      return null;
    }

    await showDSDialog<void>(
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
                          try {
                            final originalFile = File(originalImagePath);
                            if (await originalFile.exists()) {
                              await originalFile.delete();
                            }

                            var relativePath =
                                await ImageUtils.saveBytesToAppDirectory(
                                  croppedImage,
                                  widget.saveDirectory,
                                );
                            var savedImagePath =
                                await ImageUtils.getAbsolutePath(relativePath);

                            // 裁剪产物同样统一转 webp
                            final webp = await _convertToWebpIfNeeded(
                              savedImagePath,
                              relativePath,
                            );
                            relativePath = webp.$1;
                            savedImagePath = webp.$2;

                            // 处理压缩和缩略图
                            final compressionResult =
                                await _processImageCompression(
                                  savedImagePath,
                                  relativePath,
                                );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                              completer.complete({
                                ...compressionResult,
                                'bytes': await File(
                                  savedImagePath,
                                ).readAsBytes(),
                              });
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              Toast.error(
                                'image_picker_saveCroppedImageFailed'.tr,
                              );
                            }
                            completer.complete(null);
                          }
                        case CropFailure():
                          if (dialogContext.mounted) {
                            Toast.error('image_picker_cropFailed'.tr);
                          }
                          completer.complete(null);
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
                      onPressed: () async {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        final relativePath = await ImageUtils.getAbsolutePath(
                          originalImagePath,
                        );
                        completer.complete({
                          'url': relativePath,
                          'bytes': imageBytes,
                        });
                      },
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

    return completer.future;
  }
}
