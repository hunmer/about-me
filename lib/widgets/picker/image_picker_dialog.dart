import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/services/image_compression_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/utils/platform_utils.dart';

/// 图片选择器底部弹窗（smooth_sheets ModalSheet）
///
/// 结构：DSLightHeader（右侧为 拍照 / 在线URL 入口）+ 图片网格。
/// 网格聚合展示应用存储内各插件上传的图片（chat、calendar_album 等），
/// 首格为相册入口：移动端使用 wechat_assets_picker，桌面端走系统文件选择。
class ImagePickerDialog extends StatefulWidget {
  final String? initialUrl;

  /// 图片保存的目录名称，默认为 'app_images'
  final String saveDirectory;

  /// 是否启用图片裁剪功能
  final bool enableCrop;

  /// 裁剪比例，仅在 enableCrop 为 true 时生效
  final double? cropAspectRatio;

  /// 是否允许多图片选择
  final bool multiple;

  /// 是否启用图片压缩（默认关闭）
  final bool enableCompression;

  /// 缩略图保存路径（如果不指定则是保存的文件名+.thumb）
  final String? thumbnailPath;

  /// 压缩质量 0-100（默认 85）
  final int compressionQuality;

  const ImagePickerDialog({
    super.key,
    this.initialUrl,
    this.saveDirectory = 'app_images',
    this.enableCrop = false,
    this.cropAspectRatio,
    this.multiple = false,
    this.enableCompression = false,
    this.thumbnailPath,
    this.compressionQuality = 85,
  });

  /// 以底部弹窗打开图片选择器
  ///
  /// 返回值与旧版 showDialog 一致：
  /// 单选返回 `{'url', 'thumbUrl', 'bytes'}`，多选返回其列表，取消返回 null。
  static Future<T?> show<T>(
    BuildContext context, {
    String? initialUrl,
    String saveDirectory = 'app_images',
    bool enableCrop = false,
    double? cropAspectRatio,
    bool multiple = false,
    bool enableCompression = false,
    String? thumbnailPath,
    int compressionQuality = 85,
  }) {
    return Navigator.of(context).push<T>(
      ModalSheetRoute<T>(
        swipeDismissible: true,
        builder:
            (context) => ImagePickerDialog(
              initialUrl: initialUrl,
              saveDirectory: saveDirectory,
              enableCrop: enableCrop,
              cropAspectRatio: cropAspectRatio,
              multiple: multiple,
              enableCompression: enableCompression,
              thumbnailPath: thumbnailPath,
              compressionQuality: compressionQuality,
            ),
      ),
    );
  }

  @override
  State<ImagePickerDialog> createState() => _ImagePickerDialogState();
}

class _ImagePickerDialogState extends State<ImagePickerDialog> {
  final ImagePicker _picker = ImagePicker();
  late TextEditingController _urlController;
  bool _isValidUrl = false;
  bool _showUrlInput = false;

  /// 应用存储内的图片 key（相对 app_data，如 chat/chat_files/xxx.jpg）
  List<String> _images = [];
  Set<String> _keySet = {};
  bool _loading = true;

  /// 多选模式下已选中的图片 key
  final List<String> _selected = [];

  static const _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
  };

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _validateUrl(_urlController.text);
    _loadImages();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _validateUrl(String url) {
    setState(() {
      _isValidUrl =
          url.isNotEmpty &&
          (url.startsWith('http://') || url.startsWith('https://'));
    });
  }

  bool _isImageKey(String key) {
    if (!_imageExtensions.contains(path.extension(key).toLowerCase())) {
      return false;
    }
    // 排除压缩生成的缩略图（name.thumb.ext）
    return !path.basename(key).contains('.thumb');
  }

  /// 汇总应用存储内各目录的图片，最近修改的在前
  Future<void> _loadImages() async {
    try {
      final keys = await globalStorage.getKeysWithPrefix('');
      var images = keys.where(_isImageKey).toList();

      // 本地存储按修改时间倒序；远端返回顺序与服务端一致
      if (!kIsWeb && !globalStorage.isRemote) {
        final withTime = <(String, DateTime)>[];
        for (final key in images) {
          try {
            final absolute = await ImageUtils.getAbsolutePath('./$key');
            final stat = await File(absolute).stat();
            withTime.add((key, stat.modified));
          } catch (_) {
            withTime.add((key, DateTime.fromMillisecondsSinceEpoch(0)));
          }
        }
        withTime.sort((a, b) => b.$2.compareTo(a.$2));
        images = withTime.map((e) => e.$1).toList();
      }

      // 上限保护，避免网格过大
      if (images.length > 300) {
        images = images.sublist(0, 300);
      }

      if (mounted) {
        setState(() {
          _images = images;
          _keySet = images.toSet();
        });
      }
    } catch (e) {
      debugPrint('加载图片列表失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 压缩图片的伴生缩略图 key（存在时作为 thumbUrl 返回）
  String? _thumbUrlFor(String key) {
    final dir = path.dirname(key);
    final name = path.basenameWithoutExtension(key);
    final ext = path.extension(key);
    final thumbKey = '$dir/$name.thumb$ext';
    return _keySet.contains(thumbKey) ? './$thumbKey' : null;
  }

  /// 点击网格内已有图片
  Future<void> _selectImage(String key) async {
    if (widget.multiple) {
      setState(() {
        _selected.contains(key) ? _selected.remove(key) : _selected.add(key);
      });
      return;
    }
    final bytes = await ImageUtils.readStorageBytes(key);
    if (mounted) {
      Navigator.of(context).pop(<String, dynamic>{
        'url': './$key',
        'thumbUrl': _thumbUrlFor(key),
        'bytes': bytes,
      });
    }
  }

  Future<void> _confirmMultiple() async {
    final results = <Map<String, dynamic>>[];
    for (final key in _selected) {
      final bytes = await ImageUtils.readStorageBytes(key);
      results.add({
        'url': './$key',
        'thumbUrl': _thumbUrlFor(key),
        'bytes': bytes,
      });
    }
    if (mounted) Navigator.of(context).pop(results);
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

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Sheet(
      // 网格滚到顶后再向下拖才会收起弹窗
      scrollConfiguration: const SheetScrollConfiguration(),
      decoration: MaterialSheetDecoration(
        size: SheetSize.fit,
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DSLightHeader(
              title:
                  widget.multiple
                      ? 'image_picker_selectMultipleImages'.tr
                      : 'image_picker_selectImage'.tr,
              trailingWidth: 80,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DSIconButton(
                    icon: DsIconKind.camera,
                    size: 38,
                    color: theme.surface,
                    iconColor: theme.text,
                    tooltip: 'image_picker_takePhoto'.tr,
                    onPressed: () => _takePhoto(context),
                  ),
                  const SizedBox(width: 4),
                  DSIconButton(
                    icon: DsIconKind.link,
                    size: 38,
                    color: theme.surface,
                    iconColor: theme.text,
                    tooltip: 'image_picker_onlineUrl'.tr,
                    onPressed: () => setState(() => _showUrlInput = !_showUrlInput),
                  ),
                ],
              ),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            if (_showUrlInput) _buildUrlInput(theme),
            SizedBox(height: screenHeight * 0.5, child: _buildGrid(theme)),
            if (widget.multiple) _buildConfirmBar(theme),
            SafeArea(
              top: false,
              child: SizedBox(height: theme.spacing.sm),
            ),
          ],
        ),
      ),
    );
  }

  /// 在线 URL 输入区（由 Header 右侧链接按钮展开）
  Widget _buildUrlInput(AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DSInput(
            controller: _urlController,
            label: 'image_picker_onlineUrl'.tr,
            hint: 'https://...',
            onChanged: _validateUrl,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DSButton(
                  label: 'app_cancel'.tr,
                  variant: DSButtonVariant.outline,
                  size: DSButtonSize.sm,
                  onPressed:
                      () => setState(() => _showUrlInput = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DSButton(
                  label: 'app_confirm'.tr,
                  size: DSButtonSize.sm,
                  onPressed:
                      _isValidUrl
                          ? () => Navigator.of(context).pop({
                            'url': _urlController.text,
                            'bytes': null,
                          })
                          : null,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
        ],
      ),
    );
  }

  Widget _buildGrid(AppThemeData theme) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 110,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _images.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildAlbumTile(theme);
              return _buildImageTile(theme, index - 1);
            },
          ),
        ),
        if (_images.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.xl),
            child: Text(
              'image_picker_noImages'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ),
      ],
    );
  }

  /// 首格：相册入口（移动端 wechat_assets_picker / 桌面端系统文件选择）
  Widget _buildAlbumTile(AppThemeData theme) {
    final isMobile = PlatformUtils.isMobile;
    return Material(
      color: theme.primary.mixWhite(0.9),
      borderRadius: theme.radii.md,
      child: InkWell(
        borderRadius: theme.radii.md,
        onTap:
            () => isMobile
                ? _pickFromAssetPicker(context)
                : _pickFromGallery(context),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsIcon(DsIconKind.photoLibrary, color: theme.primary, size: 26),
              const SizedBox(height: 4),
              Text(
                'image_picker_chooseFromGallery'.tr,
                style: DsTypography.caption.copyWith(color: theme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageTile(AppThemeData theme, int index) {
    final key = _images[index];
    final isSelected = _selected.contains(key);
    final selectedIndex = _selected.indexOf(key) + 1;

    return GestureDetector(
      onTap: () => _selectImage(key),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: theme.radii.md,
          border:
              isSelected
                  ? Border.all(color: theme.primary, width: 2)
                  : null,
        ),
        child: ClipRRect(
          borderRadius: theme.radii.md,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: ImageUtils.createImageProvider('./$key'),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) => Container(
                      color: theme.stroke,
                      child: Center(
                        child: DsIcon(
                          DsIconKind.image,
                          size: 22,
                          color: theme.textSub,
                        ),
                      ),
                    ),
              ),
              if (widget.multiple)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isSelected
                              ? theme.primary
                              : Colors.black.withValues(alpha: 0.25),
                      border:
                          isSelected
                              ? null
                              : Border.all(color: Colors.white70),
                    ),
                    child: Center(
                      child: Text(
                        '$selectedIndex',
                        style: DsTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmBar(AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
      child: Row(
        children: [
          Text(
            _selected.isEmpty
                ? ''
                : 'image_picker_selected'.trParams({'n': '${_selected.length}'}),
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          const Spacer(),
          DSButton(
            label: 'app_confirm'.tr,
            size: DSButtonSize.sm,
            onPressed: _selected.isEmpty ? null : _confirmMultiple,
          ),
        ],
      ),
    );
  }

  /// 移动端：wechat_assets_picker 相册选图
  Future<void> _pickFromAssetPicker(BuildContext context) async {
    try {
      final entities = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          requestType: RequestType.image,
          maxAssets: widget.multiple ? 30 : 1,
        ),
      );
      if (entities == null || entities.isEmpty) {
        debugPrint('用户未选择相册图片');
        return;
      }

      final images = <XFile>[];
      for (final entity in entities) {
        final file = await entity.originFile ?? await entity.file;
        if (file != null) {
          images.add(XFile(file.path));
        }
      }
      await _processSelectedImages(context, images);
    } catch (e) {
      debugPrint('相册选择发生异常: $e');
      if (context.mounted) {
        Toast.error('${'image_picker_selectImageFailed'.tr}: $e');
      }
    }
  }

  /// 桌面端/Web：系统文件选择
  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      debugPrint('开始选择图片...');
      final List<XFile> images =
          widget.multiple
              ? (await _picker.pickMultiImage())
              : [
                await _picker.pickImage(source: ImageSource.gallery),
              ].whereType<XFile>().toList();

      debugPrint('图片选择完成，数量: ${images.length}');
      await _processSelectedImages(context, images);
    } catch (e, stackTrace) {
      debugPrint('选择图片发生异常: $e');
      debugPrint('异常堆栈: $stackTrace');
      if (context.mounted) {
        Toast.error('${'image_picker_selectImageFailed'.tr}: $e');
      }
    }
  }

  /// 拍照
  Future<void> _takePhoto(BuildContext context) async {
    try {
      debugPrint('开始调用相机...');
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      debugPrint('相机调用完成: ${photo != null}');

      if (photo == null) {
        debugPrint('用户取消拍照');
        return;
      }
      await _processSelectedImages(context, [photo]);
    } catch (e, stackTrace) {
      debugPrint('拍照过程发生异常: $e');
      debugPrint('异常堆栈: $stackTrace');
      if (context.mounted) {
        Toast.error('${'image_picker_takePhotoFailed'.tr}: $e');
      }
    }
  }

  /// 统一处理选中的图片：保存 → 裁剪(可选) → 压缩缩略图 → 返回结果
  Future<void> _processSelectedImages(
    BuildContext context,
    List<XFile> images,
  ) async {
    try {
      if (images.isEmpty) {
        debugPrint('用户未选择图片');
        return;
      }

      final results = <Map<String, dynamic>>[];

      for (final image in images) {
        try {
          debugPrint('处理图片: ${image.path}');

          // 保存图片并获取相对路径
          final relativePath = await ImageUtils.saveImage(
            File(image.path),
            widget.saveDirectory,
          );
          debugPrint('图片保存完成，相对路径: $relativePath');

          // 获取保存后的文件路径
          final savedImagePath = await ImageUtils.getAbsolutePath(
            relativePath,
          );
          final savedImage = File(savedImagePath);

          // 确认文件是否成功保存
          final fileExists = await savedImage.exists();
          debugPrint('图片保存路径: $savedImagePath, 文件是否存在: $fileExists');

          if (!fileExists) {
            throw Exception('文件保存后检查不存在: $savedImagePath');
          }

          // 读取图片字节数据
          final bytes = await File(image.path).readAsBytes();
          debugPrint('图片字节大小: ${bytes.length}');

          // 如果启用了裁剪功能，显示裁剪对话框
          if (widget.enableCrop && context.mounted) {
            debugPrint('启用裁剪，显示裁剪对话框...');
            final result = await _showCropDialog(
              context,
              bytes,
              savedImage.path,
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
            results.add({...compressionResult, 'bytes': bytes});
          }
        } catch (e) {
          debugPrint('处理单张图片时发生错误: $e');
          rethrow;
        }
      }

      debugPrint('所有图片处理完成，结果数量: ${results.length}');
      if (results.isNotEmpty && context.mounted) {
        final result = widget.multiple ? results : results.first;
        debugPrint('返回结果，类型: ${widget.multiple ? "多张" : "单张"}');
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

                            final relativePath =
                                await ImageUtils.saveBytesToAppDirectory(
                                  croppedImage,
                                  widget.saveDirectory,
                                );

                            // 处理压缩和缩略图
                            final savedImagePath =
                                await ImageUtils.getAbsolutePath(relativePath);
                            final compressionResult =
                                await _processImageCompression(
                                  savedImagePath,
                                  relativePath,
                                );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                              completer.complete({
                                ...compressionResult,
                                'bytes': croppedImage,
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
