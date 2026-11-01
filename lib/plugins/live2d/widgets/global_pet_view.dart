import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:live2d_flutter/live2d_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screens/jelly_home/live2d_online_models.dart';
import '../../../screens/jelly_home/widgets/jelly_live2d_crop_region.dart';
import '../video/video_pet_import.dart';
import '../video/video_pet_manifest.dart';
import '../video/video_pet_player.dart';

/// 独立的全局悬浮宠物展示组件。
///
/// 与小屋舞台（JellyLive2D）完全解耦：无背景、无随机游走、无内部气泡，
/// 仅按模型画布比例紧贴渲染宠物本体——Live2D 走底层 [Live2DView] +
/// 独立控制器（含 setInteractive 关闭原生吃事件、复用用户裁剪），
/// 视频桌宠走底层 [VideoPetPlayer]（关闭内部交互）。
///
/// 组件盒即展示盒（紧贴可见内容，无舞台空白），由外层悬浮层提供
/// 拖拽手势；组件自身不响应任何手势。
class GlobalPetView extends StatefulWidget {
  const GlobalPetView({
    super.key,
    required this.model,
    required this.size,
    this.opacity = 1.0,
    this.active = true,
    this.onManifestResolved,
  });

  /// 已解析的模型定义（存档 → Live2DModelDefinition）
  final Live2DModelDefinition model;

  /// 宠物盒主尺寸：Live2D=高度（宽=高×[live2dViewportAspectRatio]），
  /// 视频桌宠=宽度（高按画布比例）
  final double size;

  /// 整体不透明度（插件设置 globalPetOpacity）
  final double opacity;

  /// 视频桌宠播放开关（Live2D 恒为渲染态）
  final bool active;

  /// 视频清单解析完成回调（含 model.videoManifest 为空时的
  /// loadDefault 兜底结果）；外层悬浮层用它做区域命中过滤。
  /// 仅视频模型触发；Live2D 不调用。
  final void Function(VideoPetManifest manifest)? onManifestResolved;

  /// Live2D 模型画布宽高比（与小屋舞台一致）
  static const double live2dViewportAspectRatio = 0.5;

  /// 按模型类型计算紧贴内容的宠物盒尺寸
  static Size boxSizeFor(Live2DModelDefinition model, double size) {
    if (model.isVideo) {
      final manifest = model.videoManifest;
      final aspect = manifest != null
          ? manifest.canvasWidth / manifest.canvasHeight
          : 1.0;
      return Size(size, aspect > 0 ? size / aspect : size);
    }
    return Size(size * live2dViewportAspectRatio, size);
  }

  @override
  State<GlobalPetView> createState() => _GlobalPetViewState();
}

class _GlobalPetViewState extends State<GlobalPetView> {
  final Live2DViewController _controller = Live2DViewController();
  JellyLive2DCropRegion _cropRegion = const JellyLive2DCropRegion.full();
  VideoPetPackage? _videoPackage;

  /// 与小屋舞台共用同一份用户裁剪偏好（jelly_live2d.crop.*），
  /// 小屋里裁剪过的模型在全局悬浮下呈现一致取景
  static const String _cropPrefKeyPrefix = 'jelly_live2d.crop.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<JellyLive2DCropRegion> _loadSavedCropRegion(
    Live2DModelDefinition model,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final identity = base64UrlEncode(
        utf8.encode('${model.modelDir}${model.modelFile}'),
      );
      return JellyLive2DCropRegion.parse(
        prefs.getString('$_cropPrefKeyPrefix$identity'),
      );
    } catch (_) {
      return const JellyLive2DCropRegion.full();
    }
  }

  Future<void> _load() async {
    final model = widget.model;
    if (model.isVideo) {
      try {
        final manifest =
            model.videoManifest ??
            (await VideoPetImportService().loadDefault()).manifest;
        final package = await const VideoPetImportService().prepareForPlayback(
          manifest,
          baseUri: model.modelDir,
          resolvedSources: model.videoResolvedSources,
        );
        if (!mounted) return;
        setState(() => _videoPackage = package);
        // 通知外层（区域命中过滤用）：含 loadDefault 兜底解析出的清单
        widget.onManifestResolved?.call(package.manifest);
      } catch (error) {
        // 悬浮层不展示错误 UI：失败时保持空白并打日志
        debugPrint('[Live2D][GlobalPet] 视频桌宠加载失败: $error');
      }
      return;
    }
    try {
      final region = await _loadSavedCropRegion(model);
      if (!mounted) return;
      setState(() => _cropRegion = region);
      final localModel = await Live2DOnlineCatalog.cacheDefinition(model);
      await _controller.whenAttached;
      if (!mounted) return;
      // macOS 的 WKWebView 是真实 NSView，会先于 Flutter 手势竞争吃掉
      // AppKit 鼠标事件；关闭原生命中让事件落到外层悬浮层的拖拽手势
      // （其他平台未实现该命令时静默降级，不影响渲染与动画）
      try {
        await _controller.setInteractive(false);
      } on Live2DException catch (error) {
        debugPrint('[Live2D][GlobalPet] setInteractive 平台未支持: $error');
      }
      if (_controller.value.isLoaded) {
        await _controller.unloadModel();
      }
      await _controller.loadModel(
        modelDir: localModel.modelDir,
        modelFileName: localModel.modelFile,
      );
    } on Live2DException catch (error) {
      debugPrint('[Live2D][GlobalPet] 模型加载失败: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = GlobalPetView.boxSizeFor(widget.model, widget.size);
    // 整棵子树退出命中测试：视频播放器内部即使 interactive=false 仍有
    // opaque Listener/GestureDetector，平台视图（iOS/Android）也经框架
    // 命中参与事件路由——统一屏蔽后，拖拽/点击完全由外层悬浮层接管；
    // macOS WKWebView 是原生 NSView 直接吃 AppKit 事件，靠上面
    // setInteractive(false) 的原生 hitTest 关闭兜底
    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacity,
        child: SizedBox(
          width: box.width,
          height: box.height,
          child: widget.model.isVideo ? _buildVideo() : _buildLive2D(box),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final package = _videoPackage;
    if (package == null) return const SizedBox.shrink();
    return VideoPetPlayer(
      manifest: package.manifest,
      baseUri: package.baseUri,
      resolvedSources: package.resolvedSources,
      active: widget.active,
      // 内部点按/拖拽动画全部关闭：拖拽由外层悬浮层统一处理
      interactive: false,
    );
  }

  /// 与小屋舞台相同的裁剪管线：ClipRect + 平移 + 缩放后交给底层视图
  Widget _buildLive2D(Size viewport) {
    return ClipRect(
      child: Transform.translate(
        offset: _cropRegion.sourceTranslation(viewport),
        child: Transform.scale(
          scale: _cropRegion.zoom,
          alignment: Alignment.topLeft,
          child: Live2DView(controller: _controller),
        ),
      ),
    );
  }
}
