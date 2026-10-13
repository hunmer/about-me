import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/chat/models/sticker_collection.dart';
import 'package:aboutme/plugins/chat/services/sticker_service.dart';
import 'package:aboutme/utils/image_utils.dart';

import 'package:get/get.dart';
/// 贴图管理界面：合集列表（创建/重命名/删除/添加贴图）
class StickerManagerScreen extends StatefulWidget {
  const StickerManagerScreen({super.key});

  @override
  State<StickerManagerScreen> createState() => _StickerManagerScreenState();
}

class _StickerManagerScreenState extends State<StickerManagerScreen> {
  List<StickerCollection> _collections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final collections = await StickerService.instance.listCollections();
    if (!mounted) return;
    setState(() {
      _collections = collections;
      _loading = false;
    });
  }

  Future<void> _createCollection() async {
    final name = await _showNameDialog(title: '新建贴图合集');
    if (name == null || name.trim().isEmpty) return;

    try {
      final collection = await StickerService.instance.createCollection(
        name.trim(),
      );
      await _reload();
      if (!mounted) return;
      toastService.showToast('合集已创建，可继续添加贴图', type: ToastType.success);
      // 创建后直接引导添加贴图
      await _pickAndAddStickers(collection.id);
    } catch (e) {
      if (mounted) toastService.showToast('创建失败: $e', type: ToastType.error);
    }
  }

  Future<void> _pickAndAddStickers(String collectionId) async {
    try {
      final files = await ImagePicker().pickMultiImage();
      if (files.isEmpty) return;
      final paths = files.map((f) => f.path).toList();
      final updated = await StickerService.instance.addStickers(
        collectionId,
        paths,
      );
      await _reload();
      if (!mounted) return;
      if (updated != null) {
        toastService.showToast(
          '已添加 ${updated.stickerPaths.length} 张贴图',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) toastService.showToast('添加贴图失败: $e', type: ToastType.error);
    }
  }

  Future<void> _renameCollection(StickerCollection collection) async {
    final name = await _showNameDialog(
      title: '重命名合集',
      initial: collection.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await StickerService.instance.renameCollection(collection.id, name.trim());
    await _reload();
  }

  Future<void> _deleteCollection(StickerCollection collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('chat_deleteStickerPack'.tr),
            content: Text(
              '确定删除「${collection.name}」吗？将同时删除 ${collection.stickerCount} 张贴图文件，此操作不可恢复。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('app_cancel'.tr),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('app_delete'.tr),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await StickerService.instance.deleteCollection(collection.id);
      await _reload();
      if (mounted) toastService.showToast('合集已删除', type: ToastType.success);
    } catch (e) {
      if (mounted) toastService.showToast('删除失败: $e', type: ToastType.error);
    }
  }

  Future<String?> _showNameDialog({
    required String title,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '请输入合集名称',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('app_cancel'.tr),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text('app_ok'.tr),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('chat_stickerManager'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建合集',
            onPressed: _createCollection,
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _reload,
                child:
                    _collections.isEmpty
                        ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Icon(
                              Icons.emoji_emotions_outlined,
                              size: 56,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                '还没有贴图合集\n点击右上角 + 创建，或用脚本中心下载 LINE 贴图',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ],
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _collections.length,
                          itemBuilder: (context, index) {
                            final collection = _collections[index];
                            return _buildCollectionTile(
                              context,
                              collection,
                            );
                          },
                        ),
              ),
    );
  }

  Widget _buildCollectionTile(
    BuildContext context,
    StickerCollection collection,
  ) {
    final theme = Theme.of(context);
    final cover = collection.coverPath ?? collection.stickerPaths.firstOrNull;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading:
          cover != null
              ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image(
                  image: ImageUtils.createImageProvider('./$cover'),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, _, _) => Container(
                        width: 56,
                        height: 56,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                ),
              )
              : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_emotions_outlined),
              ),
      title: Text(
        collection.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${collection.stickerCount} 张 · '
        '${collection.updatedAt.toString().substring(0, 10)}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) {
          switch (action) {
            case 'edit':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => StickerCollectionDetailScreen(
                        collectionId: collection.id,
                      ),
                ),
              ).then((_) => _reload());
            case 'rename':
              _renameCollection(collection);
            case 'add':
              _pickAndAddStickers(collection.id);
            case 'delete':
              _deleteCollection(collection);
          }
        },
        itemBuilder:
            (context) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑贴图')),
              PopupMenuItem(value: 'add', child: Text('添加贴图')),
              PopupMenuItem(value: 'rename', child: Text('重命名')),
              PopupMenuItem(value: 'delete', child: Text('删除合集')),
            ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => StickerCollectionDetailScreen(collectionId: collection.id),
          ),
        ).then((_) => _reload());
      },
    );
  }
}

/// 贴图合集详情：网格查看/删除单张贴图，重命名/添加
class StickerCollectionDetailScreen extends StatefulWidget {
  final String collectionId;

  const StickerCollectionDetailScreen({super.key, required this.collectionId});

  @override
  State<StickerCollectionDetailScreen> createState() =>
      _StickerCollectionDetailScreenState();
}

class _StickerCollectionDetailScreenState
    extends State<StickerCollectionDetailScreen> {
  StickerCollection? _collection;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final collections = await StickerService.instance.listCollections();
    if (!mounted) return;
    setState(() {
      _collection = collections
          .where((c) => c.id == widget.collectionId)
          .firstOrNull;
    });
  }

  Future<void> _addStickers() async {
    try {
      final files = await ImagePicker().pickMultiImage();
      if (files.isEmpty) return;
      await StickerService.instance.addStickers(
        widget.collectionId,
        files.map((f) => f.path).toList(),
      );
      await _reload();
    } catch (e) {
      if (mounted) toastService.showToast('添加贴图失败: $e', type: ToastType.error);
    }
  }

  Future<void> _removeSticker(String stickerPath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('chat_deleteSticker'.tr),
            content: Text('chat_confirmDeleteSticker'.tr),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('app_cancel'.tr),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('app_delete'.tr),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await StickerService.instance.removeSticker(
      widget.collectionId,
      stickerPath,
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final collection = _collection;
    return Scaffold(
      appBar: AppBar(
        title: Text(collection?.name ?? '贴图合集'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: '添加贴图',
            onPressed: _addStickers,
          ),
        ],
      ),
      body:
          collection == null
              ? const Center(child: CircularProgressIndicator())
              : collection.stickerPaths.isEmpty
              ? Center(
                child: Text(
                  '暂无贴图，点击右上角添加',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              )
              : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 96,
                  mainAxisExtent: 96,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: collection.stickerPaths.length,
                itemBuilder: (context, index) {
                  final stickerPath = collection.stickerPaths[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onLongPress: () => _removeSticker(stickerPath),
                    child: Image(
                      image: ImageUtils.createImageProvider(
                        './$stickerPath',
                      ),
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, _, _) => const Icon(Icons.broken_image_outlined),
                    ),
                  );
                },
              ),
    );
  }
}
