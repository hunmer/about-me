import 'dart:io';

import 'package:flutter/material.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 手绘软糖标签（design.md §9.1：dsSketchDecoration 实底 + 墨线抖动描边）
class InterestPill extends StatelessWidget {
  final String label;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;
  final double fontSize;
  final EdgeInsets padding;

  const InterestPill({
    super.key,
    required this.label,
    this.leading,
    this.selected = false,
    this.onTap,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: selected ? theme.primary : theme.surfaceAlt,
          stroke: theme.ink.withValues(alpha: selected ? 0.75 : 0.45),
          radius: BorderRadius.circular(999),
          seed: label.hashCode & 0x7fffffff,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(
                  size: fontSize + 2,
                  color: selected ? theme.onPrimary : theme.textSub,
                ),
                child: leading!,
              ),
              const SizedBox(width: 4.5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? theme.onPrimary : theme.textSub,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 标签软糖（emoji + 标签名）
class TagPill extends StatelessWidget {
  final MomentTag tag;
  final bool selected;
  final VoidCallback? onTap;
  final double fontSize;
  final EdgeInsets padding;

  const TagPill({
    super.key,
    required this.tag,
    this.selected = false,
    this.onTap,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
  });

  @override
  Widget build(BuildContext context) {
    return InterestPill(
      label: '${tag.emoji} ${tag.label}',
      selected: selected,
      onTap: onTap,
      fontSize: fontSize,
      padding: padding,
    );
  }
}

/// 用户「我」头像：主题色实底墨线圆 + 白色人像
class UserAvatar extends StatelessWidget {
  final double size;

  const UserAvatar({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.primary,
        stroke: theme.ink.withValues(alpha: 0.6),
        circle: true,
      ),
      child: Center(
        child: DsIcon(
          DsIconKind.user,
          size: size * 0.55,
          color: theme.onPrimary,
        ),
      ),
    );
  }
}

/// 主页背景封面图（无路径时返回空组件）
class MomentsCover extends StatelessWidget {
  final String? path;
  final double height;
  final VoidCallback? onLongPress;
  final Widget? overlay;

  const MomentsCover({
    super.key,
    required this.path,
    this.height = 230,
    this.onLongPress,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onLongPress: onLongPress,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MomentImage(path: path!),
            if (overlay != null)
              Positioned(
                bottom: 12,
                right: 16,
                child: overlay!,
              ),
          ],
        ),
      ),
    );
  }
}

/// 朋友圈本地相对路径图片（等比裁切填充，失败显示占位）
class MomentImage extends StatelessWidget {
  final String path;
  final double? height;
  final BoxFit fit;

  const MomentImage({
    super.key,
    required this.path,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return FutureBuilder<String>(
      future: ImageUtils.getAbsolutePath(path),
      builder: (context, snapshot) {
        Widget child = Container(
          color: theme.surfaceAlt,
          alignment: Alignment.center,
          child: DsIcon(DsIconKind.image, size: 26, color: theme.textSub),
        );
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final file = File(snapshot.data!);
          if (file.existsSync()) {
            child = Image.file(
              file,
              fit: fit,
              errorBuilder: (_, __, ___) => child,
            );
          }
        }
        return SizedBox(width: double.infinity, height: height, child: child);
      },
    );
  }
}
