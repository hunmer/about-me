import 'dart:async';
import 'dart:io';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/utils/blob_url.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/photo_editor_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:video_player/video_player.dart';

/// Gallery 查看器媒体数据项：展示文案由调用方格式化，组件只负责渲染
class GalleryPhoto {
  const GalleryPhoto({
    required this.url,
    this.dateText,
    this.caption,
    this.subText,
    this.isVideo = false,
    this.isAudio = false,
    this.liveVideoUrl,
    this.thumbUrl,
    this.isFile = false,
    this.fileSize,
    this.mimeType,
  });

  /// 媒体地址（网络 URL / assets 路径 / 本地相对路径；图片或视频）
  final String url;

  /// 是否为视频（页面渲染内嵌播放器，单击播放/暂停）
  final bool isVideo;

  /// 是否为音频（页面渲染内嵌播放器，audioplayers）
  final bool isAudio;

  /// Live Photo 配对视频路径；存在时在查看器中按视频播放。
  final String? liveVideoUrl;

  /// 视频缩略图地址（封面），优先于 url 解析；图片项忽略
  final String? thumbUrl;

  /// 是否为非媒体文件（页面渲染文件信息卡，缩略图条显示文件图标）
  final bool isFile;

  /// 文件大小（字节，文件页展示用）
  final int? fileSize;

  /// MIME 类型（文件页展示/图标用）
  final String? mimeType;

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
    this.showFileActions = false,
    this.showEditAction = true,
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

  /// 顶栏是否显示文件操作按钮（分享 / 定位本地文件），
  /// 操作针对当前页媒体，仅需传入媒体路径即可执行
  final bool showFileActions;

  /// 顶栏是否显示编辑照片入口（仅图片页显示，编辑结果写回原位，
  /// 无法写回的网络/Asset 图片保存副本到应用存储）
  final bool showEditAction;

  /// 单文件预览便捷入口（替代原 FilePreviewScreen）：
  /// 按 mimeType/扩展名自动判定图片、视频（推导伴生封面 `<name>.thumb.jpg`）
  /// 或普通文件（文件信息卡），以全屏 GalleryViewer 打开
  static Future<T?> showFilePreview<T>(
    BuildContext context, {
    required String filePath,
    String? fileName,
    String? mimeType,
    int fileSize = 0,
  }) {
    final displayName = fileName ?? path.basename(filePath);
    final ext = path.extension(filePath).toLowerCase();
    final mime = mimeType ?? '';

    final isVideo = mime.startsWith('video/') || _videoExtensions.contains(ext);
    final isAudio = mime.startsWith('audio/') || _audioExtensions.contains(ext);
    final isImage = mime.startsWith('image/') || _imageExtensions.contains(ext);

    final GalleryPhoto photo;
    if (isVideo) {
      photo = GalleryPhoto(
        url: filePath,
        caption: displayName,
        isVideo: true,
        thumbUrl: _companionThumbPath(filePath),
      );
    } else if (isAudio) {
      photo = GalleryPhoto(
        url: filePath,
        caption: displayName,
        isAudio: true,
        fileSize: fileSize > 0 ? fileSize : null,
      );
    } else if (isImage) {
      photo = GalleryPhoto(url: filePath, caption: displayName);
    } else {
      photo = GalleryPhoto(
        url: filePath,
        caption: displayName,
        isFile: true,
        fileSize: fileSize,
        mimeType: mimeType,
      );
    }

    return NavigationHelper.push<T>(
      context,
      GalleryViewer(
        title: displayName,
        showFileActions: true,
        entranceAnimation: true,
        photos: [photo],
      ),
    );
  }

  static const _videoExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.3gp',
    '.m4v',
  };

  static const _audioExtensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.wav',
    '.ogg',
    '.flac',
    '.opus',
    '.wma',
  };

  static const _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
  };

  /// 本地视频的伴生首帧缩略图路径（`<name>.thumb.jpg` 命名约定），
  /// 在线 URL 无伴生缩略图返回 null
  static String? _companionThumbPath(String filePath) {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return null;
    }
    final dir = path.dirname(filePath);
    final name = path.basenameWithoutExtension(filePath);
    return '$dir/$name.thumb.jpg';
  }

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
      _entranceScale = Tween<double>(begin: 0.72, end: 1).animate(
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
                      opacity:
                          _entranceOpacity ?? const AlwaysStoppedAnimation(1),
                      child: ScaleTransition(
                        scale:
                            _entranceScale ?? const AlwaysStoppedAnimation(1),
                        child: PhotoViewGallery.builder(
                          itemCount: photos.length,
                          pageController: _pageController,
                          onPageChanged: _onPageChanged,
                          builder: (context, index) {
                            final photo = photos[index];
                            // 非媒体文件页：文件信息卡（无缩放手势）
                            if (photo.isFile) {
                              return PhotoViewGalleryPageOptions.customChild(
                                child: _GalleryFilePage(photo: photo),
                                disableGestures: true,
                              );
                            }
                            // 视频页：内嵌播放器（禁用缩放手势，单击播放/暂停；
                            // 不挂 Hero，视频控件飞行转场体验差）
                            if (photo.isVideo) {
                              return PhotoViewGalleryPageOptions.customChild(
                                child: _GalleryVideo(
                                  url: photo.url,
                                  isActive: index == _index,
                                ),
                                disableGestures: true,
                              );
                            }
                            if (photo.liveVideoUrl != null &&
                                photo.liveVideoUrl!.isNotEmpty) {
                              return PhotoViewGalleryPageOptions.customChild(
                                child: _GalleryVideo(
                                  url: photo.liveVideoUrl!,
                                  isActive: index == _index,
                                ),
                                disableGestures: true,
                              );
                            }
                            // 音频页：内嵌播放器（audioplayers，同样禁用缩放手势）
                            if (photo.isAudio) {
                              return PhotoViewGalleryPageOptions.customChild(
                                child: _GalleryAudio(
                                  url: photo.url,
                                  isActive: index == _index,
                                ),
                                disableGestures: true,
                              );
                            }
                            final image = _GalleryImage(url: photo.url);
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

  /// 顶栏：标题 + 当前照片日期 + 文件操作（分享/定位）+ 关闭按钮
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
          // 编辑照片入口：仅图片页显示（视频/音频/文件/Live Photo 不可编辑）
          if (_isEditablePhoto(current)) ...[
            _buildHeaderIconButton(
              Icons.edit,
              'app_editPhoto'.tr,
              () => _openPhotoEditor(current),
            ),
            const SizedBox(width: 8),
          ],
          // 文件操作：仅传媒体路径即可分享 / 保存 / 定位（针对当前页）
          if (widget.showFileActions) ...[
            _buildHeaderIconButton(
              Icons.ios_share,
              'file_preview_share_file'.tr,
              () => GalleryFileActions.share(
                context,
                current.url,
                text: current.caption,
              ),
            ),
            const SizedBox(width: 8),
            // 保存图片：移动端存系统相册，桌面端弹出保存文件对话框
            if (!kIsWeb &&
                !current.isVideo &&
                !current.isAudio &&
                !current.isFile) ...[
              _buildHeaderIconButton(
                UniversalPlatform.isAndroid || UniversalPlatform.isIOS
                    ? Icons.photo_library_outlined
                    : Icons.download,
                UniversalPlatform.isAndroid || UniversalPlatform.isIOS
                    ? 'app_saveToAlbum'.tr
                    : 'app_saveToFile'.tr,
                () => GalleryFileActions.saveToAlbum(context, current.url),
              ),
              const SizedBox(width: 8),
            ],
            if (!kIsWeb) ...[
              _buildHeaderIconButton(
                Icons.folder_open,
                'file_preview_open_file_location'.tr,
                () => GalleryFileActions.locate(
                  context,
                  current.url,
                  fileName: current.caption,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
          _buildCloseButton(),
        ],
      ),
    );
  }

  /// 是否可进入照片编辑器：仅普通图片页（视频/音频/文件/Live Photo 排除）
  bool _isEditablePhoto(GalleryPhoto photo) =>
      widget.showEditAction &&
      !photo.isVideo &&
      !photo.isAudio &&
      !photo.isFile &&
      (photo.liveVideoUrl == null || photo.liveVideoUrl!.isEmpty);

  /// 打开照片编辑器；编辑结果写回原位时 url 不变，
  /// evict 图片缓存后重建当前页以显示新内容
  Future<void> _openPhotoEditor(GalleryPhoto current) async {
    final edited = await showPhotoEditor(context, imageUrl: current.url);
    if (edited == null || !mounted) return;
    await GalleryImageResolver.cached(current.url)?.evict();
    if (mounted) setState(() {});
  }

  Widget _buildCloseButton() {
    return _buildHeaderIconButton(
      Icons.close,
      'app_close'.tr,
      () => Navigator.of(context).maybePop(),
    );
  }

  /// 顶栏圆形图标按钮（深底白字半透明，与关闭按钮同款）
  Widget _buildHeaderIconButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
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
                  isAudio: photo.isAudio,
                  isFile: photo.isFile,
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
        if (snapshot.hasError ||
            snapshot.connectionState == ConnectionState.done) {
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
/// 视频无封面（url 为空）时以视频图标占位，文件以文件类型图标占位
class _GalleryThumbImage extends StatelessWidget {
  const _GalleryThumbImage({
    required this.url,
    this.isVideo = false,
    this.isAudio = false,
    this.isFile = false,
  });

  final String url;

  final bool isVideo;

  final bool isAudio;

  final bool isFile;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || isFile) {
      return _iconPlaceholder(
        isFile ? _fileIcon(null) : Icons.videocam_outlined,
      );
    }
    if (isAudio) {
      return _iconPlaceholder(Icons.audiotrack_outlined);
    }

    final provider = GalleryImageResolver.cached(url);
    if (provider != null) return _buildImage(provider);

    return FutureBuilder<ImageProvider?>(
      future: GalleryImageResolver.resolve(url),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved != null) return _buildImage(resolved);
        // 未就绪时露出底色占位
        return isVideo
            ? _iconPlaceholder(Icons.videocam_outlined)
            : const SizedBox.shrink();
      },
    );
  }

  Widget _iconPlaceholder(IconData icon) {
    return Center(child: Icon(icon, color: Colors.white38, size: 18));
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
              const Icon(Icons.error_outline, size: 64, color: Colors.white38),
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

  void _togglePlayback() {
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = controller.value.isPlaying;
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: isPlaying
              ? const SizedBox.shrink()
              : Container(color: Colors.black26),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlayback,
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        if (!isPlaying)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlayback,
            child: Container(
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
              value: position.inMilliseconds.toDouble().clamp(
                0.0,
                maxMs <= 0 ? 1.0 : maxMs,
              ),
              max: maxMs <= 0 ? 1.0 : maxMs,
              onChanged: maxMs <= 0
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

/// 音频页渲染：audioplayers 内嵌播放器（本地文件走 DeviceFileSource，
/// 打开即自动播放），居中音符视觉 + 播放/暂停大按钮 + 底部进度条
/// （样式与视频页一致）；切走页面（isActive=false）自动暂停，
/// 页面销毁时释放播放器
class _GalleryAudio extends StatefulWidget {
  const _GalleryAudio({required this.url, this.isActive = true});

  final String url;

  /// 是否为当前可见页（非当前页暂停播放）
  final bool isActive;

  @override
  State<_GalleryAudio> createState() => _GalleryAudioState();
}

class _GalleryAudioState extends State<_GalleryAudio> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(_GalleryAudio oldWidget) {
    super.didUpdateWidget(oldWidget);
    // PageView 相邻页保活时，非当前页暂停避免后台继续出声
    if (!widget.isActive && _isPlaying) {
      _player?.pause();
    }
  }

  Future<void> _initializePlayer() async {
    try {
      final player = AudioPlayer();
      _player = player;
      _subs.add(
        player.onPositionChanged.listen((p) {
          if (mounted) setState(() => _position = p);
        }),
      );
      _subs.add(
        player.onDurationChanged.listen((d) {
          if (mounted) setState(() => _duration = d);
        }),
      );
      _subs.add(
        player.onPlayerStateChanged.listen((s) {
          if (mounted) {
            setState(() => _isPlaying = s == PlayerState.playing);
          }
        }),
      );
      _subs.add(
        player.onPlayerComplete.listen((_) {
          // 播完归零，下一次 resume 从头播放（resume 对 stopped 态同样有效）
          player.seek(Duration.zero);
          if (mounted) setState(() => _position = Duration.zero);
        }),
      );
      // 打开即自动播放
      await player.play(DeviceFileSource(widget.url));
    } catch (e) {
      debugPrint('音频初始化错误: $e');
      if (mounted) {
        setState(() => _hasError = true);
        Toast.error('${'app_audioLoadFailed'.tr}: $e');
      }
    }
  }

  void _togglePlay() {
    final player = _player;
    if (player == null) return;
    if (_isPlaying) {
      player.pause();
    } else {
      player.resume();
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

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
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              Text(
                'app_audioLoadFailed'.tr,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 播放中音符轻微放大，模拟律动
                AnimatedScale(
                  scale: _isPlaying ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: const Icon(
                    Icons.music_note,
                    size: 80,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                _buildPlayPauseButton(),
              ],
            ),
          ),
        ),
        _buildProgressBar(),
      ],
    );
  }

  /// 播放/暂停大按钮（样式对齐视频页播放遮罩按钮）
  Widget _buildPlayPauseButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.18),
          border: Border.all(color: Colors.white70),
        ),
        child: Icon(
          _isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 38,
        ),
      ),
    );
  }

  /// 底部进度条（样式对齐视频页进度条）
  Widget _buildProgressBar() {
    final maxMs = _duration.inMilliseconds.toDouble();

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
              value: _position.inMilliseconds.toDouble().clamp(
                0.0,
                maxMs <= 0 ? 1.0 : maxMs,
              ),
              max: maxMs <= 0 ? 1.0 : maxMs,
              onChanged: maxMs <= 0
                  ? null
                  : (value) =>
                        _player?.seek(Duration(milliseconds: value.toInt())),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                color: Colors.white,
                iconSize: 28,
                onPressed: _togglePlay,
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 按扩展名推断文件图标（非媒体文件页与缩略图条共用）
IconData _fileIcon(String? mimeType) {
  final mime = (mimeType ?? '').toLowerCase();
  if (mime.contains('pdf')) return Icons.picture_as_pdf;
  if (mime.contains('word') || mime.contains('document')) {
    return Icons.description;
  }
  if (mime.contains('sheet') || mime.contains('excel')) {
    return Icons.table_chart;
  }
  if (mime.contains('presentation') || mime.contains('powerpoint')) {
    return Icons.slideshow;
  }
  if (mime.contains('zip') || mime.contains('compressed')) {
    return Icons.folder_zip;
  }
  if (mime.contains('audio')) return Icons.audiotrack;
  if (mime.contains('text')) return Icons.article;
  return Icons.insert_drive_file;
}

/// 非媒体文件页：深色居中卡片展示图标、文件名、大小与类型，
/// 分享/定位等操作由顶栏按钮承载
class _GalleryFilePage extends StatelessWidget {
  const _GalleryFilePage({required this.photo});

  final GalleryPhoto photo;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final size = photo.fileSize;
    final mime = photo.mimeType ?? path.extension(photo.url);
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_fileIcon(photo.mimeType), size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              photo.caption ?? path.basename(photo.url),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            if (size != null && size > 0)
              Text(
                _formatFileSize(size),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            Text(
              mime,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// GalleryViewer 内置的文件操作（分享 / 定位本地文件），
/// 仅需传入媒体路径（'./' 相对路径 / 绝对路径 / http URL）即可执行，
/// 顶栏按钮与 showFilePreview 等调用方共用同一实现
class GalleryFileActions {
  GalleryFileActions._();

  static bool _isHttpUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  /// 分享媒体：本地/相对路径（远端模式自动物化）走系统文件分享，
  /// 在线 URL 降级分享链接文本
  static Future<void> share(
    BuildContext context,
    String url, {
    String? text,
  }) async {
    try {
      String localPath = url;
      if (!_isHttpUrl(url)) {
        localPath = await ImageUtils.getAbsolutePath(url);
      }
      final file = File(localPath);
      if (await file.exists()) {
        await Share.shareXFiles([XFile(localPath)], text: text);
      } else if (_isHttpUrl(url)) {
        await Share.share(url, subject: text);
      } else {
        if (context.mounted) Toast.error('file_preview_fileNotExist'.tr);
      }
    } catch (e) {
      if (context.mounted) {
        Toast.error(
          '${'file_preview_errorFilePreviewFailed'.tr}${e.toString()}',
        );
      }
    }
  }

  /// 保存图片到系统相册：移动端经 photo_manager 写入相册（自动申请权限），
  /// 桌面端弹出保存文件对话框；在线 URL 先下载字节
  static Future<void> saveToAlbum(BuildContext context, String url) async {
    try {
      Uint8List? bytes;
      var name = path.basename(url.split('?').first);
      if (_isHttpUrl(url)) {
        final res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) {
          throw Exception('HTTP ${res.statusCode}');
        }
        bytes = res.bodyBytes;
      } else {
        final absolutePath = await ImageUtils.getAbsolutePath(url);
        final file = File(absolutePath);
        if (!await file.exists()) {
          if (context.mounted) Toast.error('file_preview_fileNotExist'.tr);
          return;
        }
        bytes = await file.readAsBytes();
        name = path.basename(absolutePath);
      }
      if (bytes.isEmpty) {
        if (context.mounted) Toast.error('file_preview_fileNotExist'.tr);
        return;
      }

      if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
        final state = await PhotoManager.requestPermissionExtend();
        if (!state.hasAccess) {
          if (context.mounted) Toast.error('app_stickerNoPermission'.tr);
          return;
        }
        await PhotoManager.editor.saveImage(bytes, filename: name, title: name);
        if (context.mounted) Toast.success('app_stickerSavedAlbum'.tr);
      } else {
        final String? savePath = await FilePicker.platform.saveFile(
          fileName: name,
          type: FileType.image,
        );
        if (savePath == null) return; // 用户取消
        final ext = path.extension(name);
        final file = File(
          savePath.toLowerCase().endsWith(ext) ? savePath : '$savePath$ext',
        );
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          Toast.success('${'app_saveToFile'.tr}: ${file.path}');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Toast.error(
          '${'file_preview_errorFilePreviewFailed'.tr}${e.toString()}',
        );
      }
    }
  }

  /// 定位本地文件：桌面端打开资源管理器并选中（Win `explorer /select`、
  /// macOS `open -R`、Linux 打开所在目录），移动端弹文件信息对话框，
  /// 在线 URL 无本地文件仅提示
  static Future<void> locate(
    BuildContext context,
    String url, {
    String? fileName,
  }) async {
    try {
      if (_isHttpUrl(url)) {
        if (context.mounted) Toast.error('在线文件没有本地位置');
        return;
      }
      final absolutePath = await ImageUtils.getAbsolutePath(url);
      final file = File(absolutePath);
      if (!await file.exists()) {
        if (context.mounted) Toast.error('file_preview_fileNotExist'.tr);
        return;
      }

      if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
        final size = await file.length();
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('file_preview_name'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${'file_preview_name'.tr}: ${fileName ?? path.basename(absolutePath)}',
                ),
                Text(absolutePath),
                Text('${'file_preview_fileSize'.tr}: ${_formatFileSize(size)}'),
                Text(
                  '${'file_preview_fileType'.tr}: ${path.extension(absolutePath)}',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('app_ok'.tr),
              ),
            ],
          ),
        );
      } else if (UniversalPlatform.isWindows) {
        await Process.run('explorer', ['/select,', absolutePath]);
      } else if (UniversalPlatform.isMacOS) {
        await Process.run('open', ['-R', absolutePath]);
      } else {
        await Process.run('xdg-open', [path.dirname(absolutePath)]);
      }
    } catch (e) {
      if (context.mounted) Toast.error(e.toString());
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
