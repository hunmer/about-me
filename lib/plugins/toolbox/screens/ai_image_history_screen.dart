import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/toolbox/services/ai_image_service.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// AI 图片生成图库：按生成记录分组展示历史产物
///
/// 记录头部：时间 + 模型/比例/参考图数 + prompt + 删除按钮；
/// 图片行：横滑缩略图，点击进 GalleryViewer 大图。
class AiImageHistoryScreen extends StatefulWidget {
  const AiImageHistoryScreen({super.key});

  @override
  State<AiImageHistoryScreen> createState() => _AiImageHistoryScreenState();
}

class _AiImageHistoryScreenState extends State<AiImageHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  final Map<String, Future<dynamic>> _bytesCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await AiImageService.instance.getHistory();
    if (!mounted) return;
    setState(() {
      _history = history;
      _loading = false;
    });
  }

  Future<dynamic> _bytesOf(String relPath) {
    // 同一路径只发起一次读取，未完成的 future 复用（避免重建风暴）
    return _bytesCache.putIfAbsent(
      relPath,
      () => ImageUtils.readStorageBytes(relPath),
    );
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    await AiImageService.instance.deleteHistoryEntry(entry);
    Toast.success('toolbox_historyDeleted'.tr);
    await _load();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('toolbox_clearHistory'.tr),
        content: Text('toolbox_aiImage_clearConfirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('app_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('app_confirm'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AiImageService.instance.clearHistory();
    Toast.success('toolbox_historyCleared'.tr);
    await _load();
  }

  void _openViewer(Map<String, dynamic> entry, int imageIndex) {
    final images = (entry['images'] as List).cast<String>();
    NavigationHelper.push(
      context,
      GalleryViewer(
        title: 'toolbox_ai_image_name'.tr,
        photos: [
          for (final rel in images) GalleryPhoto(url: rel, caption: rel),
        ],
        initialIndex: imageIndex,
        entranceAnimation: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SuperCupertinoNavigationWrapper(
      title: Text('toolbox_aiImage_history'.tr),
      largeTitle: 'toolbox_aiImage_history'.tr,
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.trash,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'toolbox_clearHistory'.tr,
                onPressed: _history.isEmpty ? null : _clearAll,
              );
            },
          ),
        ),
      ],
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _history.isEmpty
            ? DSEmptyState(
                emoji: '🎨',
                title: 'toolbox_aiImage_historyEmpty'.tr,
              )
            : ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.lg,
                  vertical: theme.spacing.sm,
                ),
                itemCount: _history.length,
                itemBuilder: (context, index) =>
                    _buildEntry(theme, _history[index]),
              ),
      ),
    );
  }

  Widget _buildEntry(AppThemeData theme, Map<String, dynamic> entry) {
    final ts = entry['ts'] is int ? entry['ts'] as int : 0;
    final time = ts > 0
        ? DateTime.fromMillisecondsSinceEpoch(ts).toString().substring(0, 16)
        : '';
    final model = entry['model'] as String? ?? '';
    final ratio = entry['aspectRatio'] as String? ?? '';
    final refCount = entry['refCount'] is int ? entry['refCount'] as int : 0;
    final prompt = entry['prompt'] as String? ?? '';
    final images = (entry['images'] as List).cast<String>();

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.md),
      child: DSCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    time,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ),
                // 重新生成：携带该条记录返回生成页回填表单
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pop<Map<String, dynamic>>(entry),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(Icons.refresh, size: 20, color: theme.primary),
                  ),
                ),
                GestureDetector(
                  onTap: () => _deleteEntry(entry),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: theme.danger,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.xs),
            GestureDetector(
              onTap: () =>
                  Navigator.of(context).pop<Map<String, dynamic>>(entry),
              child: Text(
                prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DsTypography.body.copyWith(color: theme.text),
              ),
            ),
            SizedBox(height: 4),
            Text(
              [
                model,
                if (ratio.isNotEmpty) ratio,
                if (refCount > 0) '${refCount}ref',
                '${images.length}p',
              ].join(' · '),
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
            SizedBox(height: theme.spacing.sm),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) =>
                    _buildThumb(theme, entry, images[i], i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb(
    AppThemeData theme,
    Map<String, dynamic> entry,
    String relPath,
    int index,
  ) {
    return GestureDetector(
      onTap: () => _openViewer(entry, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 96,
          height: 96,
          child: FutureBuilder<dynamic>(
            future: _bytesOf(relPath),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Container(color: theme.surfaceAlt);
              }
              final bytes = snapshot.data;
              if (bytes == null) {
                return Icon(Icons.broken_image, color: theme.textSub);
              }
              return Image.memory(bytes, fit: BoxFit.cover);
            },
          ),
        ),
      ),
    );
  }
}
