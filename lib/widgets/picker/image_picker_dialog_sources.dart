part of 'image_picker_dialog.dart';

/// 拾取的图片（含可选的实况照片视频轨道）
class _PickedImage {
  const _PickedImage(this.image, {this.liveVideo});

  final XFile image;
  final XFile? liveVideo;
}

/// 图片来源入口（按功能从主文件拆出）：
/// 移动端相册（wechat_assets_picker）/ 桌面端系统文件选择 / 拍照
extension _ImagePickerDialogSourcesExt on _ImagePickerDialogState {
  /// 移动端：wechat_assets_picker 相册选图
  Future<void> _pickFromAssetPicker(BuildContext context) async {
    try {
      final entities = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          requestType: RequestType.image,
          enableLivePhoto: true,
          maxAssets: _multiple ? 30 : 1,
        ),
      );
      if (entities == null || entities.isEmpty) {
        debugPrint('用户未选择相册图片');
        return;
      }

      final livePhotoCount = entities
          .where((entity) => entity.isLivePhoto)
          .length;
      final useLivePhotos = livePhotoCount == 0
          ? false
          : await _confirmLivePhotoChoice(context, livePhotoCount);
      if (useLivePhotos == null) return;

      final images = <_PickedImage>[];
      for (final entity in entities) {
        final file = await entity.originFile ?? await entity.file;
        if (file != null) {
          final liveVideo = useLivePhotos && entity.isLivePhoto
              ? await entity.originFileWithSubtype
              : null;
          images.add(
            _PickedImage(
              XFile(file.path),
              liveVideo: liveVideo == null ? null : XFile(liveVideo.path),
            ),
          );
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

  /// 统一决定本次选择中的 Live Photo 是否保留动态视频。
  /// 多选时只弹一次，避免逐张打断用户选择流程。
  Future<bool?> _confirmLivePhotoChoice(
    BuildContext context,
    int livePhotoCount,
  ) {
    final countText = '$livePhotoCount 张实况照片';
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('检测到实况照片'),
        content: Text('本次选择包含 $countText，请决定导入方式。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('使用普通照片'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('使用实况照片'),
          ),
        ],
      ),
    );
  }

  /// 桌面端/Web：系统文件选择
  ///
  /// image_picker 桌面端的扩展名白名单硬编码且不含 heic/heif，
  /// 改用 file_picker 自定义扩展过滤（对齐相册网格支持的图片格式）
  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      debugPrint('开始选择图片...');
      final selected = await FilePicker.platform.pickFiles(
        allowMultiple: _multiple,
        withData: kIsWeb,
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'bmp',
          'heic',
          'heif',
        ],
      );
      final List<_PickedImage> images = [
        for (final file in selected?.files ?? <PlatformFile>[])
          if (kIsWeb && file.bytes != null)
            _PickedImage(XFile.fromData(file.bytes!, name: file.name))
          else if (file.path != null) _PickedImage(XFile(file.path!)),
      ];

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
      await _processSelectedImages(context, [_PickedImage(photo)]);
    } catch (e, stackTrace) {
      debugPrint('拍照过程发生异常: $e');
      debugPrint('异常堆栈: $stackTrace');
      if (context.mounted) {
        Toast.error('${'image_picker_takePhotoFailed'.tr}: $e');
      }
    }
  }
}
