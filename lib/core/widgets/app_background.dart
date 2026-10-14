import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:aboutme/core/services/app_background_controller.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 全局主题背景容器
///
/// 垫在根 Navigator 之下：设置背景图、纯色背景或网格背景后，所有透明背景的
/// 界面（Scaffold 背景已被置为透明）都会透出该背景。
/// 层级：底色（纯色或默认）在底、网格纹理在其上、背景图（叠加
/// BackdropFilter 模糊）再上，内容绘制在最上层保持清晰。
///
/// 网格纹理预渲染成位图：rough 手绘几何只在参数变化时计算一次，
/// 逐帧渲染成本与普通背景图相同。全分辨率位图经异步 [ui.Picture.toImage]
/// 生成，等待期用低分辨率占位图或旧图拉伸过渡；拖拽调整窗口大小时
/// 防抖重渲染。
class AppBackground extends StatefulWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

/// 一次网格位图渲染的完整输入（同时也是缓存匹配键）
class _GridRenderArgs {
  _GridRenderArgs({
    required this.theme,
    required this.gridIndex,
    required this.size,
    required this.dpr,
    required this.gap,
  }) : hatch = theme.hatch;

  final AppThemeData theme;
  final int gridIndex;
  final Size size;
  final double dpr;
  final double gap;

  /// 以下为派生比较键（theme 实例每次派生可能不同，按值比较）
  final Color hatch;
  int get inkLevel => DsInkStyle.index;

  bool matchesCache(
    ui.Image? image,
    int? cachedIndex,
    int cachedInkLevel,
    Color? cachedHatch,
    Size? cachedSize,
    double cachedDpr,
    double cachedGap,
  ) {
    return image != null &&
        cachedIndex == gridIndex &&
        cachedInkLevel == inkLevel &&
        cachedHatch == hatch &&
        cachedSize == size &&
        cachedDpr == dpr &&
        cachedGap == gap;
  }
}

class _AppBackgroundState extends State<AppBackground> {
  final AppBackgroundController _controller = AppBackgroundController();

  // 网格纹理位图缓存（连同生成参数；参数变化时重渲染）
  ui.Image? _gridImage;
  int? _gridImageIndex;
  int _gridImageInkLevel = -1;
  Color? _gridImageHatch;
  Size? _gridImageSize;
  double _gridImageDpr = 1;
  double _gridImageGap = 18;
  Timer? _gridRenderDebounce;

  // 在途异步渲染（世代号递增使过期结果作废，避免覆盖新参数）
  _GridRenderArgs? _pendingRender;
  int _gridRenderGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    // 兜底初始化：正常流程已在 AppInitializer 中完成，此处保证不遗漏
    _controller.initialize();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _gridRenderDebounce?.cancel();
    _gridImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = _controller.backgroundPath;
    final color = _controller.backgroundColor;
    final gridIndex = _controller.backgroundGridIndex;

    if (gridIndex == null) {
      // 网格已清除：释放位图（无渲染副作用，可在 build 中进行）
      _disposeGridImage();
    }

    if (path == null && color == null && gridIndex == null) {
      return widget.child;
    }

    final blur = _controller.backgroundBlur;
    final scaffoldBg = ThemeData(
      brightness: Theme.of(context).brightness,
    ).scaffoldBackgroundColor;
    final dsTheme = DSThemeBridge.resolve(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 底色层：纯色背景与当前深浅色的默认背景色合成出不透明颜色，
        // 避免半透明颜色直接与窗口底色（黑色）混合导致偏暗；
        // 仅设网格时也铺默认底色兜底，避免透明 Scaffold 透出窗口底色
        if (color != null || gridIndex != null)
          ColoredBox(
            color: color != null
                ? Color.alphaBlend(color, scaffoldBg)
                : scaffoldBg,
          ),
        // 网格背景层：预渲染位图铺满全屏（主题淡彩，跟随色板/深浅色）
        if (gridIndex != null)
          LayoutBuilder(
            builder: (context, constraints) {
              _ensureGridImage(
                dsTheme,
                gridIndex,
                constraints.biggest,
                MediaQuery.devicePixelRatioOf(context),
              );
              return RawImage(image: _gridImage, fit: BoxFit.fill);
            },
          ),
        if (path != null)
          Image.file(
            File(path),
            fit: _controller.backgroundFit,
            // 背景图不参与语义树
            excludeFromSemantics: true,
          ),
        if (path != null && blur > 0)
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: const ColoredBox(color: Color(0x00000000)),
          ),
        widget.child,
      ],
    );
  }

  /// 释放网格位图与待渲染任务
  void _disposeGridImage() {
    _gridRenderDebounce?.cancel();
    _gridRenderDebounce = null;
    _gridImage?.dispose();
    _gridImage = null;
    _gridImageIndex = null;
    _gridImageSize = null;
    _pendingRender = null;
  }

  bool _gridImageMatches(_GridRenderArgs args) => args.matchesCache(
        _gridImage,
        _gridImageIndex,
        _gridImageInkLevel,
        _gridImageHatch,
        _gridImageSize,
        _gridImageDpr,
        _gridImageGap,
      );

  /// 确保网格位图与当前风格/主题/间距/尺寸匹配：
  /// - 位图已匹配 → 直接复用（日常路径，零成本）
  /// - 相同目标的渲染已在途 → 等它完成
  /// - 已有旧图且仅尺寸变化（拖拽窗口）→ 防抖等稳定后重渲染，
  ///   期间 RawImage 拉伸旧图过渡
  /// - 其余（首次/风格/主题/间距变化）→ 先上占位再异步渲染
  void _ensureGridImage(
    AppThemeData theme,
    int gridIndex,
    Size size,
    double dpr,
  ) {
    if (size.isEmpty || !size.isFinite) return;
    final args = _GridRenderArgs(
      theme: theme,
      gridIndex: gridIndex,
      size: size,
      dpr: dpr,
      gap: _controller.backgroundGridGap,
    );
    if (_gridImageMatches(args)) return;

    final pending = _pendingRender;
    if (pending != null &&
        pending.gridIndex == args.gridIndex &&
        pending.hatch == args.hatch &&
        pending.inkLevel == args.inkLevel &&
        pending.size == args.size &&
        pending.dpr == args.dpr &&
        pending.gap == args.gap) {
      return;
    }

    if (_gridImage != null && _gridImageSize != size) {
      _gridRenderDebounce?.cancel();
      _gridRenderDebounce = Timer(const Duration(milliseconds: 200), () {
        _gridRenderDebounce = null;
        if (!mounted || _gridImageMatches(args)) return;
        _startGridRender(args);
      });
      return;
    }

    _startGridRender(args);
  }

  /// 发起一次网格位图渲染：几何只录制一次（逻辑坐标），同一 picture
  /// 先同步光栅化出 1/4 尺寸占位图立即上屏（避免异步等待期闪空白），
  /// 再异步光栅化全分辨率版本完成后替换
  Future<void> _startGridRender(_GridRenderArgs args) async {
    if (_gridImageMatches(args)) return;
    _gridRenderDebounce?.cancel();
    _gridRenderDebounce = null;

    final generation = ++_gridRenderGeneration;
    _pendingRender = args;

    final picture = _recordGridPicture(args);
    if (_gridImage == null) {
      final placeholder = picture.toImageSync(
        (args.size.width / 4).ceil().clamp(1, 1 << 20),
        (args.size.height / 4).ceil().clamp(1, 1 << 20),
      );
      _applyGridImage(placeholder, args);
    }

    final image = await picture.toImage(
      (args.size.width * args.dpr).ceil().clamp(1, 1 << 20),
      (args.size.height * args.dpr).ceil().clamp(1, 1 << 20),
    );
    picture.dispose();
    _pendingRender = null;
    if (generation != _gridRenderGeneration || !mounted) {
      // 已被更新的渲染请求取代，或组件已销毁
      image.dispose();
      return;
    }
    setState(() {
      _applyGridImage(image, args);
    });
  }

  void _applyGridImage(ui.Image image, _GridRenderArgs args) {
    final old = _gridImage;
    _gridImage = image;
    _gridImageIndex = args.gridIndex;
    _gridImageInkLevel = args.inkLevel;
    _gridImageHatch = args.hatch;
    _gridImageSize = args.size;
    _gridImageDpr = args.dpr;
    _gridImageGap = args.gap;
    old?.dispose();
  }

  /// 全屏 rough 手绘纹理画进 picture（逻辑坐标，一次性几何计算；
  /// 光栅化分辨率由 toImage/toImageSync 的目标尺寸决定）
  ui.Picture _recordGridPicture(_GridRenderArgs args) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    dsSketchDecoration(
      theme: args.theme,
      fillStyle: DsSketchFill.values[args.gridIndex],
      // 实底给主题淡彩；其余传 null 让排线/点画走主题淡彩
      fillColor: args.gridIndex == DsSketchFill.solid.index
          ? args.theme.hatch
          : null,
      // 整屏纹理不要边框描边
      stroke: DsColors.transparent,
      hachureGap: args.gap,
      seed: 7,
    ).createBoxPainter().paint(
          canvas,
          Offset.zero,
          ImageConfiguration(size: args.size),
        );
    return recorder.endRecording();
  }
}
