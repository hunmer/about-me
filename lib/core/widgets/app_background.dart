import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:aboutme/core/services/app_background_controller.dart';

/// 全局主题背景容器
///
/// 垫在根 Navigator 之下：设置背景图或纯色背景后，所有透明背景的界面
/// （Scaffold 背景已被置为透明）都会透出该背景。
/// 层级：纯色背景在底、背景图（叠加 BackdropFilter 模糊）在其上，
/// 内容绘制在最上层保持清晰。
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

    if (path == null && color == null) {
      return widget.child;
    }

    final blur = _controller.backgroundBlur;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 纯色背景层：与当前深浅色的默认背景色合成出不透明颜色，
        // 避免半透明颜色直接与窗口底色（黑色）混合导致偏暗
        if (color != null)
          ColoredBox(
            color: Color.alphaBlend(
              color,
              ThemeData(
                brightness: Theme.of(context).brightness,
              ).scaffoldBackgroundColor,
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
