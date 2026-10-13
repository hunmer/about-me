import 'dart:io';

import 'package:aboutme/utils/image_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// Gallery 查看器照片数据项：展示文案由调用方格式化，组件只负责渲染
class GalleryPhoto {
  const GalleryPhoto({
    required this.url,
    this.dateText,
    this.caption,
    this.subText,
  });

  /// 图片地址（网络 URL / assets 路径 / 本地相对路径）
  final String url;

  /// 顶部标题下方日期（如 2026/09/06），随当前照片切换
  final String? dateText;

  /// 底部主文案（如相册名 / 条目标题）
  final String? caption;

  /// 底部副文案（如 Added 2 hours ago），随当前照片切换
  final String? subText;
}

/// 全屏 Gallery 查看器（深色沉浸式）：
/// 顶部标题 + 当前照片日期 + 关闭按钮，中部大图横滑（支持双指缩放），
/// 底部信息行（可点击跳转来源）+ 缩略图联动条
class GalleryViewer extends StatefulWidget {
  const GalleryViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.title = 'Gallery',
    this.onInfoTap,
  });

  final List<GalleryPhoto> photos;
  final int initialIndex;

  /// 左上角标题
  final String title;

  /// 点击底部信息区（携带当前索引，可用于跳转照片来源）
  final void Function(int index)? onInfoTap;

  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer> {
  /// 沉浸式近黑底色（固定深色，不随主题切换）
  static const Color _bgColor = Color(0xFF0B0B0D);
  static const double _thumbSize = 56;

  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  final ScrollController _thumbController = ScrollController();

  /// url → provider 解析缓存，避免来回滑动重复解析本地路径
  final Map<String, Future<ImageProvider?>> _providerCache = {};

  late int _index = widget.initialIndex.clamp(0, widget.photos.length - 1);

  @override
  void initState() {
    super.initState();
    // 初始缩略图滚动到选中项（首帧布局完成后才有 viewport）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbTo(_index);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _scrollThumbTo(index);
  }

  void _selectThumb(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// 缩略图滚动到选中项居中
  void _scrollThumbTo(int index) {
    if (!_thumbController.hasClients) return;
    final viewport = _thumbController.position.viewportDimension;
    final itemExtent = _thumbSize + 10;
    final target = index * itemExtent + _thumbSize / 2 - viewport / 2;
    _thumbController.animateTo(
      target.clamp(0.0, _thumbController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<ImageProvider?> _resolveProvider(String url) {
    return _providerCache.putIfAbsent(url, () async {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return NetworkImage(url);
      }
      if (url.startsWith('assets/')) return AssetImage(url);
      final absolutePath = await ImageUtils.getAbsolutePath(url);
      if (absolutePath.isEmpty) return null;
      final file = File(absolutePath);
      if (!file.existsSync()) return null;
      return FileImage(file);
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final current = photos[_index];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(current),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: PhotoViewGallery.builder(
                      itemCount: photos.length,
                      pageController: _pageController,
                      onPageChanged: _onPageChanged,
                      builder: (context, index) {
                        return PhotoViewGalleryPageOptions.customChild(
                          child: _GalleryImage(
                            url: photos[index].url,
                            resolveProvider: _resolveProvider,
                          ),
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 2,
                          initialScale: PhotoViewComputedScale.contained,
                        );
                      },
                    ),
                  ),
                ),
              ),
              _buildInfoBar(current),
              _buildThumbnails(photos),
              _buildHomeIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶栏：标题 + 当前照片日期 + 关闭按钮
  Widget _buildHeader(GalleryPhoto current) {
    final dateText = current.dateText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (dateText != null && dateText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      dateText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.close, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  /// 信息行：相机图标 + 主文案 / 副文案；右侧当前计数
  Widget _buildInfoBar(GalleryPhoto current) {
    final caption = current.caption;
    final subText = current.subText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: widget.onInfoTap == null
                  ? null
                  : () => widget.onInfoTap!(_index),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.photo_camera_outlined,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            caption ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subText != null && subText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 21),
                        child: Text(
                          subText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_index + 1} / ${widget.photos.length}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 缩略图联动条：选中项白描边高亮
  Widget _buildThumbnails(List<GalleryPhoto> photos) {
    return SizedBox(
      height: _thumbSize + 8,
      child: ListView.separated(
        controller: _thumbController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: photos.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final selected = index == _index;
          return GestureDetector(
            onTap: () => _selectThumb(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_thumbSize / 2),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: _GalleryThumbImage(
                  url: photos[index].url,
                  resolveProvider: _resolveProvider,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Center(
        child: Container(
          width: 120,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// 大图渲染：解析 url 为 ImageProvider 后交给 PhotoView 缩放容器
class _GalleryImage extends StatelessWidget {
  const _GalleryImage({
    required this.url,
    required this.resolveProvider,
  });

  final String url;
  final Future<ImageProvider?> Function(String url) resolveProvider;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider?>(
      future: resolveProvider(url),
      builder: (context, snapshot) {
        final provider = snapshot.data;
        if (provider != null) {
          return PhotoView(
            imageProvider: provider,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            initialScale: PhotoViewComputedScale.contained,
            backgroundDecoration: const BoxDecoration(color: Colors.transparent),
            errorBuilder: (context, error, stackTrace) =>
                const _GalleryFallback(),
          );
        }
        if (snapshot.hasError ||
            (snapshot.hasData && snapshot.data == null)) {
          return const _GalleryFallback();
        }
        return const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white70,
            ),
          ),
        );
      },
    );
  }
}

/// 缩略图渲染：同一 provider 解析缓存，方形裁圆
class _GalleryThumbImage extends StatelessWidget {
  const _GalleryThumbImage({
    required this.url,
    required this.resolveProvider,
  });

  final String url;
  final Future<ImageProvider?> Function(String url) resolveProvider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _GalleryViewerState._thumbSize,
      height: _GalleryViewerState._thumbSize,
      color: Colors.white.withValues(alpha: 0.06),
      child: FutureBuilder<ImageProvider?>(
        future: resolveProvider(url),
        builder: (context, snapshot) {
          final provider = snapshot.data;
          if (provider == null) {
            return const SizedBox.shrink();
          }
          return Image(
            image: provider,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const _GalleryFallback(compact: true),
          );
        },
      ),
    );
  }
}

/// 图片缺失兜底
class _GalleryFallback extends StatelessWidget {
  const _GalleryFallback({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/image_not_found.png',
      fit: compact ? BoxFit.cover : BoxFit.contain,
    );
  }
}
