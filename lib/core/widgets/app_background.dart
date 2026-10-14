import 'dart:io';
import 'dart:ui';

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
class AppBackground extends StatefulWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  final AppBackgroundController _controller = AppBackgroundController();

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
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = _controller.backgroundPath;
    final color = _controller.backgroundColor;
    final gridIndex = _controller.backgroundGridIndex;

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
        // 网格背景层：手绘填充纹理铺满全屏（主题淡彩，跟随色板/深浅色）
        if (gridIndex != null)
          DecoratedBox(
            decoration: dsSketchDecoration(
              theme: dsTheme,
              fillStyle: DsSketchFill.values[gridIndex],
              // 实底给主题淡彩；其余传 null 让排线/点画走主题淡彩
              fillColor: gridIndex == DsSketchFill.solid.index
                  ? dsTheme.hatch
                  : null,
              // 整屏纹理不要边框描边
              stroke: DsColors.transparent,
              seed: 7,
            ),
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
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: const ColoredBox(color: Color(0x00000000)),
          ),
        widget.child,
      ],
    );
  }
}
