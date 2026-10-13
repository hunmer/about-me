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

/// url → ImageProvider 解析缓存（同 url 只解析一次）
///
/// 提前 [resolve] 后可用 [cached] 同步取用：Hero 飞行首帧即能渲染大图，
/// 缩略图与已加载过的大图也无需再次等待异步解析
class GalleryImageResolver {
  GalleryImageResolver._();

  static final Map<String, Future<ImageProvider?>> _futures = {};
  static final Map<String, ImageProvider?> _resolved = {};

  /// 同步读取已解析的 provider（未解析或解析失败返回 null）
  static ImageProvider? cached(String url) => _resolved[url];

  /// 解析 url（网络 URL / assets 路径 / 本地相对路径），结果写入缓存
  static Future<ImageProvider?> resolve(String url) {
    return _futures.putIfAbsent(url, () async {
      ImageProvider? provider;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        provider = NetworkImage(url);
      } else if (url.startsWith('assets/')) {
        provider = AssetImage(url);
      } else {
        final absolutePath = await ImageUtils.getAbsolutePath(url);
        if (absolutePath.isNotEmpty) {
          final file = File(absolutePath);
          if (file.existsSync()) provider = FileImage(file);
        }
      }
      _resolved[url] = provider;
      return provider;
    });
  }
}

/// 全屏 Gallery 查看器（深色沉浸式）：
/// 顶部标题 + 当前照片日期 + 关闭按钮，中部大图横滑（双指缩放，单击切换沉浸模式），
/// 底部信息行（可点击跳转来源）+ 缩略图联动条；
/// 当前页大图挂 Hero（tag = url），与来源页同 tag 图片形成转场飞行
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

  /// 缩略图外框边长（含描边与内边距）；间距按此推导保持滚动居中计算一致
  static const double _thumbOuter = 56;
  static const double _thumbSpacing = 10;

  /// 描边 2*2 + 内边距 2*2，图片实际为 48×48 正方形（保证圆形不变形）
  static const double _thumbInset = 8;

  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  final ScrollController _thumbController = ScrollController();

  late int _index = widget.initialIndex.clamp(0, widget.photos.length - 1);

  /// 沉浸模式：单击大图隐藏/恢复顶部与底部区域
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    assert(widget.photos.isNotEmpty);
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

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
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
    final itemExtent = _thumbOuter + _thumbSpacing;
    final target = index * itemExtent + _thumbOuter / 2 - viewport / 2;
    _thumbController.animateTo(
      target.clamp(0.0, _thumbController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
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
              _ChromeSection(
                visible: _chromeVisible,
                hiddenOffset: const Offset(0, -1),
                child: _buildHeader(current),
              ),
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
                        final image = _GalleryImage(url: photos[index].url);
                        return PhotoViewGalleryPageOptions.customChild(
                          // 单击大图切换沉浸模式；opaque 让图片周围空白也可点击
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _toggleChrome,
                            // 仅当前页挂 Hero：避免相邻页与来源页出现多重飞行
                            child: index == _index
                                ? Hero(tag: photos[index].url, child: image)
                                : image,
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
              _ChromeSection(
                visible: _chromeVisible,
                hiddenOffset: const Offset(0, 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInfoBar(current),
                    _buildThumbnails(photos),
                    _buildHomeIndicator(),
                  ],
                ),
              ),
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

  /// 缩略图联动条：选中项白描边高亮。
  /// 尺寸链固定为 56 外框 → 描边+内边距 8 → 48×48 正方形，避免被裁成椭圆
  Widget _buildThumbnails(List<GalleryPhoto> photos) {
    return SizedBox(
      height: _thumbOuter,
      child: ListView.separated(
        controller: _thumbController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: photos.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: _thumbSpacing),
        itemBuilder: (context, index) {
          final selected = index == _index;
          return GestureDetector(
            onTap: () => _selectThumb(index),
            child: SizedBox.square(
              dimension: _thumbOuter,
              child: _thumbRing(
                selected,
                _GalleryThumbImage(url: photos[index].url),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 选中白描边环：与图片之间留 2px 缝隙，未选中保留透明占位避免跳动
  Widget _thumbRing(bool selected, Widget image) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: SizedBox.square(
          dimension: _thumbOuter - _thumbInset,
          child: ColoredBox(
            color: Colors.white.withValues(alpha: 0.06),
            child: image,
          ),
        ),
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

/// 顶栏/底部区域的沉浸显隐动画：淡入淡出 + 向屏幕外滑动
class _ChromeSection extends StatelessWidget {
  const _ChromeSection({
    required this.visible,
    required this.hiddenOffset,
    required this.child,
  });

  final bool visible;

  /// 隐藏时的滑出方向（顶栏向上 / 底部向下）
  final Offset hiddenOffset;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 220);
    return AnimatedSlide(
      duration: duration,
      curve: Curves.easeOut,
      offset: visible ? Offset.zero : hiddenOffset,
      child: AnimatedOpacity(
        duration: duration,
        curve: Curves.easeOut,
        opacity: visible ? 1 : 0,
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}

/// 大图渲染：优先同步读取解析缓存（Hero 首帧出图），未命中时异步解析
class _GalleryImage extends StatelessWidget {
  const _GalleryImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final provider = GalleryImageResolver.cached(url);
    if (provider != null) return _buildImage(provider);

    return FutureBuilder<ImageProvider?>(
      future: GalleryImageResolver.resolve(url),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved != null) return _buildImage(resolved);
        if (snapshot.hasError || snapshot.connectionState == ConnectionState.done) {
          // 解析完成但无可用 provider（文件缺失等）
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

  Widget _buildImage(ImageProvider provider) {
    return Image(
      image: provider,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const _GalleryFallback(),
    );
  }
}

/// 缩略图渲染：同一 provider 解析缓存，方形裁圆
class _GalleryThumbImage extends StatelessWidget {
  const _GalleryThumbImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final provider = GalleryImageResolver.cached(url);
    if (provider != null) return _buildImage(provider);

    return FutureBuilder<ImageProvider?>(
      future: GalleryImageResolver.resolve(url),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved != null) return _buildImage(resolved);
        // 未就绪时露出底色占位
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildImage(ImageProvider provider) {
    return Image(
      image: provider,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          const _GalleryFallback(compact: true),
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
