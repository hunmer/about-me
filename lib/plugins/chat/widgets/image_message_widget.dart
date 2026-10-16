import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import '../../../../utils/image_utils.dart';

/// 图片消息渲染：本地 './' 相对路径解析为绝对路径后 Image.file 展示，
/// http(s) URL 直接 Image.network 引用。
///
/// 路径解析 future 在 State 内缓存：父级重建（如卡片堆切卡的层重建）
/// 不会重跑解析导致图片闪 loading 重载；仅 imagePath / message 变化时重解析。
class ImageMessageWidget extends StatefulWidget {
  final Message message;
  final bool isOutgoing;

  /// 覆盖展示的图片路径（默认取 fileInfo['path']；
  /// 多图卡片堆复用同一 message 时按卡指定）
  final String? imagePath;

  const ImageMessageWidget({
    super.key,
    required this.message,
    this.isOutgoing = false,
    this.imagePath,
  });

  @override
  State<ImageMessageWidget> createState() => _ImageMessageWidgetState();
}

class _ImageMessageWidgetState extends State<ImageMessageWidget> {
  /// 路径解析 future（缓存，避免父级重建时重跑导致图片闪 loading）
  late Future<Widget> _future;

  Map<String, dynamic>? get fileInfo =>
      widget.message.metadata?[Message.metadataKeyFileInfo]
          as Map<String, dynamic>?;

  @override
  void initState() {
    super.initState();
    _future = _buildImageWidget();
  }

  @override
  void didUpdateWidget(ImageMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅图片源变化时重新解析（切卡等纯重建不触发重载）
    if (widget.imagePath != oldWidget.imagePath ||
        widget.message != oldWidget.message) {
      _future = _buildImageWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (fileInfo == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: DSLoadingDots(color: DSThemeBridge.resolve(context).textSub),
          );
        }
        return snapshot.data ?? _buildErrorWidget(context, '未命名文件');
      },
    );
  }

  Future<Widget> _buildImageWidget() async {
    if (fileInfo == null) {
      return const SizedBox.shrink();
    }

    final filePath = widget.imagePath ?? (fileInfo!['path'] as String? ?? '');
    final fileName = fileInfo!['name'] as String? ?? '未命名文件';

    if (filePath.isEmpty) {
      return _buildErrorWidget(context, fileName);
    }

    final theme = _resolveTheme(context);

    // 网络图片直接 URL 引用（图片搜索/在线图片入口），Image.file 只支持本地文件
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return _buildFrame(
        context,
        theme,
        Image.network(
          filePath,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) =>
                  _buildErrorWidget(context, fileName),
        ),
      );
    }

    String absolutePath;
    try {
      absolutePath = await ImageUtils.getAbsolutePath(filePath);
    } catch (e) {
      debugPrint('获取绝对路径失败: $e');
      return _buildErrorWidget(context, fileName);
    }

    final file = File(absolutePath);
    if (!await file.exists()) {
      return _buildErrorWidget(context, fileName);
    }

    return _buildFrame(
      context,
      theme,
      Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) => _buildErrorWidget(context, fileName),
      ),
    );
  }

  /// 图片消息外框（网络图与本地图共用）
  Widget _buildFrame(BuildContext context, AppThemeData theme, Widget image) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
        maxHeight: 200,
      ),
      decoration: BoxDecoration(
        color:
            widget.isOutgoing
                ? theme.primary.withValues(alpha: 0.1)
                : theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.stroke.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: image,
      ),
    );
  }

  AppThemeData _resolveTheme(BuildContext context) =>
      DSThemeBridge.resolve(context);

  Widget _buildErrorWidget(BuildContext context, String fileName) {
    final theme = _resolveTheme(context);
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIcon(DsIconKind.image, size: 32, color: theme.disabled),
          const SizedBox(height: 8),
          Text(
            '无法加载图片\n$fileName',
            textAlign: TextAlign.center,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }
}
