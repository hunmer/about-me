import 'dart:io';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/utils/blob_url.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';

/// Gallery 查看器媒体数据项：展示文案由调用方格式化，组件只负责渲染
class GalleryPhoto {
  const GalleryPhoto({
    required this.url,
    this.dateText,
    this.caption,
    this.subText,
    this.isVideo = false,
    this.thumbUrl,
  });

  /// 媒体地址（网络 URL / assets 路径 / 本地相对路径；图片或视频）
  final String url;

  /// 是否为视频（页面渲染内嵌播放器，单击播放/暂停）
  final bool isVideo;

  /// 视频缩略图地址（封面），优先于 url 解析；图片项忽略
  final String? thumbUrl;

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
/// 顶部标题 + 当前照片日期 + 关闭按钮，中部媒体横滑
/// （图片双指缩放、单击切换沉浸模式；视频内嵌播放、单击播放/暂停），
/// 底部信息行（可点击跳转来源）+ 缩略图联动条；
/// 当前页大图挂 Hero（tag = url），与来源页同 tag 图片形成转场飞行
class GalleryViewer extends StatefulWidget {
  const GalleryViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.title = 'Gallery',
    this.onInfoTap,
    this.entranceAnimation = false,
    this.showHeader = true,
  });

  final List<GalleryPhoto> photos;
  final int initialIndex;

  /// 左上角标题
  final String title;

  /// 点击底部信息区（携带当前索引，可用于跳转照片来源）
  final void Function(int index)? onInfoTap;

  /// 打开时大图区域缩放淡入入场（无 Hero 飞行的入口使用，
  /// 与 Hero 转场同开会产生飞行结束后二次跳变）
  final bool entranceAnimation;

  /// 是否显示自带顶栏（嵌入已有 AppBar 的宿主屏时可关闭，
  /// 关闭后返回依赖宿主屏的导航）
  final bool showHeader;

  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer>
    with SingleTickerProviderStateMixin {
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

  /// 入场动画（仅 entranceAnimation 时创建）：缩放 0.72→1 + 淡入
  AnimationController? _entranceController;
  Animation<double>? _entranceScale;
  Animation<double>? _entranceOpacity;

  @override
  void initState() {
    super.initState();
    assert(widget.photos.isNotEmpty);
    if (widget.entranceAnimation) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 360),
      )..forward();
      _entranceController = controller;
      _entranceScale = Tween<double>(
        begin: 0.72,
        end: 1,
      ).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
      );
      _entranceOpacity = CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      );
    }
    // 初始缩略图滚动到选中项（首帧布局完成后才有 viewport）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbTo(_index);
    });
  }

  @override
  void dispose() {
    _entranceController?.dispose();
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
              if (widget.showHeader)
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
                    child: FadeTransition(
                      opacity: _entranceOpacity ?? const AlwaysStoppedAnimation(1),
                      child: ScaleTransition(
                        scale: _entranceScale ?? const AlwaysStoppedAnimation(1),
                        child: PhotoViewGallery.builder(
                          itemCount: photos.length,
                          pageController: _pageController,
                          onPageChanged: _onPageChanged,
                          builder: (context, index) {
                            // 视频页：内嵌播放器（禁用缩放手势，单击播放/暂停；
                            // 不挂 Hero，视频控件飞行转场体验差）
                            if (photos[index].isVideo) {
                              return PhotoViewGalleryPageOptions.customChild(
                                child: _GalleryVideo(
                                  url: photos[index].url,
                                  isActive: index == _index,
                                ),
                                disableGestures: true,
                              );
                            }
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
          final photo = photos[index];
          return GestureDetector(
            onTap: () => _selectThumb(index),
            child: SizedBox.square(
              dimension: _thumbOuter,
              child: _thumbRing(
                selected,
                _GalleryThumbImage(
                  // 视频缩略图优先用封面，无封面时不解析视频本体（图标占位）
                  url: photo.isVideo ? (photo.thumbUrl ?? '') : photo.url,
                  isVideo: photo.isVideo,
                ),
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

/// 缩略图渲染：同一 provider 解析缓存，方形裁圆；
/// 视频无封面（url 为空）时以视频图标占位
class _GalleryThumbImage extends StatelessWidget {
  const _GalleryThumbImage({required this.url, this.isVideo = false});

  final String url;

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _videoIconPlaceholder();

    final provider = GalleryImageResolver.cached(url);
    if (provider != null) return _buildImage(provider);

    return FutureBuilder<ImageProvider?>(
      future: GalleryImageResolver.resolve(url),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved != null) return _buildImage(resolved);
        // 未就绪时露出底色占位
        return isVideo ? _videoIconPlaceholder() : const SizedBox.shrink();
      },
    );
  }

  Widget _videoIconPlaceholder() {
    return const Center(
      child: Icon(Icons.videocam_outlined, color: Colors.white38, size: 18),
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

/// 视频页渲染：video_player 内嵌播放器（本地走文件、Web 走 blob URL，
/// 远端模式经 ImageUtils 物化到本地临时文件），
/// 单击播放/暂停 + 暂停时居中播放按钮，底部深色进度条；
/// 切走页面（isActive=false）自动暂停，页面销毁时释放控制器与 blob
class _GalleryVideo extends StatefulWidget {
  const _GalleryVideo({required this.url, this.isActive = true});

  final String url;

  /// 是否为当前可见页（非当前页暂停播放）
  final bool isActive;

  @override
  State<_GalleryVideo> createState() => _GalleryVideoState();
}

class _GalleryVideoState extends State<_GalleryVideo> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(_GalleryVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    // PageView 相邻页保活时，非当前页暂停避免多路声音/后台耗电
    if (!widget.isActive && _controller?.value.isPlaying == true) {
      _controller?.pause();
    }
  }

  Future<void> _initializePlayer() async {
    try {
      final VideoPlayerController controller;
      if (kIsWeb) {
        // Web 无本地文件系统：经存储读取字节(远端=HTTP解密/Web=IndexedDB)
        // 后包装为 blob URL 交给 video 元素播放
        final bytes = await ImageUtils.readStorageBytes(widget.url);
        if (bytes == null || bytes.isEmpty) {
          throw Exception('存储中不存在视频：${widget.url}');
        }
        _blobUrl = createBlobUrl(bytes, _guessMimeType(widget.url));
        controller = VideoPlayerController.networkUrl(Uri.parse(_blobUrl!));
      } else {
        final absolutePath = await ImageUtils.getAbsolutePath(widget.url);
        if (absolutePath.isEmpty) {
          throw Exception('无法获取视频文件的绝对路径');
        }
        final videoFile = File(absolutePath);
        if (!await videoFile.exists()) {
          throw Exception('视频文件不存在：$absolutePath');
        }
        controller = VideoPlayerController.file(videoFile);
      }
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.addListener(_onControllerUpdate);
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('视频初始化错误: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString());
        Toast.error('${'app_videoLoadFailed'.tr}: $e');
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  /// 根据扩展名推断视频 MIME 类型（浏览器 blob 播放需要）
  String _guessMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return switch (ext) {
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'ogg' || 'ogv' => 'video/ogg',
      _ => 'video/mp4',
    };
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_blobUrl != null) revokeBlobUrl(_blobUrl!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.white38,
              ),
              const SizedBox(height: 16),
              Text(
                'file_preview_videoLoadFailed'.tr,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'app_loadingVideo'.tr,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  _GalleryVideoTapOverlay(controller: controller),
                ],
              ),
            ),
          ),
        ),
        _GalleryVideoProgressBar(controller: controller),
      ],
    );
  }
}

/// 视频单击交互层：暂停时半透明遮罩 + 居中播放按钮，单击切换播放/暂停
class _GalleryVideoTapOverlay extends StatelessWidget {
  const _GalleryVideoTapOverlay({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = controller.value.isPlaying;
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child:
              isPlaying
                  ? const SizedBox.shrink()
                  : Container(color: Colors.black26),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
          },
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        if (!isPlaying)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white70),
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 34,
            ),
          ),
      ],
    );
  }
}

/// 视频底部深色进度条：滑块拖拽 seek + 播放/暂停按钮 + 时间
class _GalleryVideoProgressBar extends StatelessWidget {
  const _GalleryVideoProgressBar({required this.controller});

  final VideoPlayerController controller;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds'
        : '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final position = controller.value.position;
    final duration = controller.value.duration;
    final bool isPlaying = controller.value.isPlaying;
    final maxMs = duration.inMilliseconds.toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
              trackHeight: 2.5,
            ),
            child: Slider(
              value: position.inMilliseconds
                  .toDouble()
                  .clamp(0.0, maxMs <= 0 ? 1.0 : maxMs),
              max: maxMs <= 0 ? 1.0 : maxMs,
              onChanged:
                  maxMs <= 0
                      ? null
                      : (value) => controller.seekTo(
                        Duration(milliseconds: value.toInt()),
                      ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                color: Colors.white,
                iconSize: 28,
                onPressed: () {
                  if (isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
