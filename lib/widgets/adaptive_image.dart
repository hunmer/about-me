import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 自适应图片组件
///
/// 支持网络图片、本地图片与 SVG 矢量图（按 .svg 扩展名分流到 flutter_svg））
/// 的显示，自动处理相对路径转绝对路径。
/// 特点：高度自适应，支持圆形裁剪，适用于列表项、图片卡片、头像等场景。
/// 加载状态和错误状态有对应的占位显示。
///
/// 路径解析 Future 在 State 中缓存（path 不变不重新解析），
/// 避免父级高频 rebuild（如鼠标悬浮态）时 FutureBuilder 反复进入
/// loading 态导致图片闪烁。
class AdaptiveImage extends StatefulWidget {
  /// 图片路径（网络 URL 或本地相对路径）
  final String? imagePath;

  /// 宽度约束（可选）
  final double? width;

  /// 高度约束（可选）
  final double? height;

  /// 填充模式
  final BoxFit fit;

  /// 边框半径
  final double borderRadius;

  /// 形状（用于圆形头像等场景）
  final BoxShape shape;

  /// 错误状态显示的图片（默认显示破损图标）
  final Widget? errorImage;

  /// 空图片时显示的默认图片
  final Widget? defaultImage;

  /// 加载状态指示器颜色
  final Color? loadingColor;

  const AdaptiveImage({
    super.key,
    this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
    this.errorImage,
    this.defaultImage,
    this.loadingColor,
  });

  /// 判断是否为网络图片
  static bool isNetworkImage(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  /// 判断是否为 SVG 矢量图（按扩展名）
  static bool isSvgImage(String path) {
    return path.toLowerCase().endsWith('.svg');
  }

  @override
  State<AdaptiveImage> createState() => _AdaptiveImageState();
}

/// 本地路径解析结果：绝对路径 + 文件存在性（异步检查，随 Future 缓存）
typedef _ResolvedLocalImage = ({String absolutePath, bool exists});

class _AdaptiveImageState extends State<AdaptiveImage> {
  /// 缓存的本地路径解析 Future（避免每次 rebuild 重新解析与存在性 IO）
  Future<_ResolvedLocalImage>? _resolveFuture;

  /// 当前 Future 对应的 imagePath（变化时重新解析）
  String? _resolvedFor;

  Future<_ResolvedLocalImage>? _resolveFutureFor(String? path) {
    if (path == null || path.isEmpty) return null;
    if (AdaptiveImage.isNetworkImage(path) || path.startsWith('assets/')) {
      return null;
    }
    if (_resolveFuture == null || _resolvedFor != path) {
      _resolvedFor = path;
      _resolveFuture = ImageUtils.getAbsolutePath(path).then(
        (absolutePath) async {
          // 异步检查文件存在性（解析期间文件被删除时不构造 Image.file）
          final exists = absolutePath.isNotEmpty &&
              await File(absolutePath).exists();
          return (absolutePath: absolutePath, exists: exists);
        },
      );
    }
    return _resolveFuture;
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = widget.imagePath;

    // 空图片路径时显示默认图片或占位
    if (imagePath == null || imagePath.isEmpty) {
      return _buildDefaultOrError();
    }

    // 网络图片直接加载（SVG 走矢量渲染）
    if (AdaptiveImage.isNetworkImage(imagePath)) {
      if (AdaptiveImage.isSvgImage(imagePath)) {
        return _buildImageWidget(
          SvgPicture.network(
            imagePath,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
          ),
        );
      }
      return _buildNetworkImage(imagePath);
    }

    // 内置资源图片（assets/ 前缀）直接加载（SVG 走矢量渲染）
    if (imagePath.startsWith('assets/')) {
      if (AdaptiveImage.isSvgImage(imagePath)) {
        return _buildImageWidget(
          SvgPicture.asset(
            imagePath,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
          ),
        );
      }
      return _buildImageWidget(
        Image.asset(
          imagePath,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
        ),
      );
    }

    // 本地图片需要转换路径（含异步存在性检查，结果随 Future 缓存）
    return FutureBuilder<_ResolvedLocalImage>(
      future: _resolveFutureFor(imagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final resolved = snapshot.data;
          if (resolved != null && resolved.exists) {
            if (AdaptiveImage.isSvgImage(imagePath)) {
              return _buildImageWidget(
                SvgPicture.file(
                  File(resolved.absolutePath),
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildErrorImage(),
                ),
              );
            }
            return _buildLocalImage(resolved.absolutePath);
          }
          return _buildDefaultOrError();
        }
        return _buildLoadingIndicator();
      },
    );
  }

  /// 构建网络图片
  Widget _buildNetworkImage(String path) {
    return _buildImageWidget(
      Image.network(
        path,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildLoadingIndicator();
        },
        errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
      ),
    );
  }

  /// 构建本地图片（存在性已在解析 Future 中异步判定，失败走 errorBuilder）
  Widget _buildLocalImage(String path) {
    return _buildImageWidget(
      Image.file(
        File(path),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
      ),
    );
  }

  /// 构建图片 Widget（应用形状和裁剪）
  Widget _buildImageWidget(Widget imageWidget) {
    if (widget.shape == BoxShape.circle) {
      return ClipOval(child: imageWidget);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: imageWidget,
    );
  }

  /// 加载指示器
  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: widget.height,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: widget.loadingColor != null
                ? AlwaysStoppedAnimation<Color>(widget.loadingColor!)
                : null,
          ),
        ),
      ),
    );
  }

  /// 错误状态图片
  Widget _buildErrorImage() {
    return widget.errorImage ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey.shade200,
          child: Center(
            child: Icon(
              Icons.broken_image,
              size: (widget.width ?? widget.height ?? 50).clamp(20.0, 50.0),
              color: Colors.grey.shade400,
            ),
          ),
        );
  }

  /// 默认图片或占位
  Widget _buildDefaultOrError() {
    if (widget.defaultImage != null) {
      return widget.defaultImage!;
    }
    return _buildErrorImage();
  }
}
