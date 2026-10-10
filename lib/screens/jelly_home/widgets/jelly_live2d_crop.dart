part of 'jelly_live2d.dart';

const String _cropPrefKeyPrefix = 'jelly_live2d.crop.';

/// 裁剪功能：显示区域裁剪的持久化、模型截图、裁剪编辑器入口
extension _JellyLive2DCrop on _JellyLive2DState {
  String _cropPrefKey(Live2DModelDefinition model) {
    final identity = base64UrlEncode(
      utf8.encode('${model.modelDir}${model.modelFile}'),
    );
    return '$_cropPrefKeyPrefix$identity';
  }

  Future<void> _loadSavedCropRegion(Live2DModelDefinition model) async {
    final prefs = await SharedPreferences.getInstance();
    final region = JellyLive2DCropRegion.parse(
      prefs.getString(_cropPrefKey(model)),
    );
    if (!mounted || _isSameModel(model, _selectedModel)) return;
    setState(() => _cropRegion = region);
  }

  Future<void> _saveCropRegion(JellyLive2DCropRegion region) async {
    setState(() => _cropRegion = region);
    final prefs = await SharedPreferences.getInstance();
    final key = _cropPrefKey(_selectedModel);
    if (region.isFull) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, region.encode());
    }
  }

  Future<({Uint8List bytes, Size size})> _captureFullModel() async {
    if (!_controller.value.isLoaded || _isSwitchingModel) {
      throw StateError('screens_jellyLive2dModelNotLoaded'.tr);
    }

    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _modelCaptureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('screens_jellyLive2dCaptureUnavailable'.tr);
    }

    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = rgba?.buffer.asUint8List();
      if (pixels == null || !_containsVisiblePixel(pixels)) {
        throw StateError('screens_jellyLive2dCaptureUnsupported'.tr);
      }
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw StateError('screens_jellyLive2dCaptureEncodeFailed'.tr);
      }
      return (
        bytes: png.buffer.asUint8List(),
        size: Size(image.width.toDouble(), image.height.toDouble()),
      );
    } finally {
      image.dispose();
    }
  }

  bool _containsVisiblePixel(Uint8List rgba) {
    const pixelStride = 4;
    const sampleStride = pixelStride * 16;
    for (var i = 3; i < rgba.length; i += sampleStride) {
      if (rgba[i] > 8) return true;
    }
    return false;
  }

  Future<void> _openCropEditor(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final capture = await _captureFullModel();
      if (!mounted) return;
      final region = await showJellyLive2DCropDialog(
        context: context,
        image: capture.bytes,
        imageSize: capture.size,
        initialRegion: _cropRegion,
      );
      if (region != null && mounted) await _saveCropRegion(region);
    } catch (error) {
      if (!mounted) return;
      await showDSDialog<void>(
        context: context,
        builder: (dialogContext) => DSDialog(
          title: 'screens_jellyLive2dCropErrorTitle'.tr,
          message: error.toString().replaceFirst('Bad state: ', ''),
          confirmText: 'screens_jellyLive2dGotIt'.tr,
          onConfirm: () => Navigator.of(dialogContext).pop(),
        ),
      );
    }
  }
}
