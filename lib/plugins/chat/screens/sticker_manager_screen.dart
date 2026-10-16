import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/sticker_collection.dart';
import 'package:aboutme/plugins/chat/services/sticker_service.dart';
import 'package:aboutme/utils/image_utils.dart';

import 'package:get/get.dart';

/// 贴图管理界面（手绘风）：合集列表（创建/重命名/删除/添加贴图）
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

  Future<void> _openDetail(String collectionId) async {
    await NavigationHelper.push(
      context,
      StickerCollectionDetailScreen(collectionId: collectionId),
    );
    _reload();
  }

  Future<void> _createCollection() async {
    final name = await _showNameDialog(title: 'chat_stickerNewCollection'.tr);
    if (name == null || name.trim().isEmpty) return;

    try {
      final collection = await StickerService.instance.createCollection(
        name.trim(),
      );
      await _reload();
      if (!mounted) return;
      toastService.showToast(
        'chat_stickerCollectionCreated'.tr,
        type: ToastType.success,
      );
      // 创建后直接引导添加贴图
      await _pickAndAddStickers(collection.id);
    } catch (e) {
      if (mounted) {
        toastService.showToast(
          'chat_stickerCreateFailed'.trParams({'error': '$e'}),
          type: ToastType.error,
        );
      }
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
          'chat_stickerAddedCount'.trParams({
            'count': '${updated.stickerPaths.length}',
          }),
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast(
          'chat_stickerAddFailed'.trParams({'error': '$e'}),
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _renameCollection(StickerCollection collection) async {
    final name = await _showNameDialog(
      title: 'chat_stickerRenameCollection'.tr,
      initial: collection.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await StickerService.instance.renameCollection(collection.id, name.trim());
    await _reload();
  }

  Future<void> _deleteCollection(StickerCollection collection) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      builder:
          (dialogContext) => DSDialog(
            title: 'chat_deleteStickerPack'.tr,
            message: 'chat_stickerDeleteConfirm'.trParams({
              'name': collection.name,
              'count': '${collection.stickerCount}',
            }),
            confirmText: 'app_delete'.tr,
            cancelText: 'app_cancel'.tr,
            confirmVariant: DSButtonVariant.destructive,
          ),
    );
    if (confirmed != true) return;

    try {
      await StickerService.instance.deleteCollection(collection.id);
      await _reload();
      if (mounted) {
        toastService.showToast(
          'chat_stickerCollectionDeleted'.tr,
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast(
          'chat_stickerDeleteFailed'.trParams({'error': '$e'}),
          type: ToastType.error,
        );
      }
    }
  }

  Future<String?> _showNameDialog({
    required String title,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);

    final future = showDSDialog<String>(
      context: context,
      builder:
          (dialogContext) => DSDialog(
            title: title,
            content: DSInput(
              controller: controller,
              hint: 'chat_stickerNameHint'.tr,
            ),
            confirmText: 'app_ok'.tr,
            cancelText: 'app_cancel'.tr,
            onConfirm: () => Navigator.of(dialogContext).pop(controller.text),
          ),
    );
    return future.whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Scaffold(
            backgroundColor: dsScaffoldBackground(theme),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  DSLightHeader(
                    title: 'chat_stickerManager'.tr,
                    trailing: DSIconButton(
                      icon: DsIconKind.plus,
                      size: 38,
                      color: theme.surface,
                      iconColor: theme.text,
                      tooltip: 'chat_stickerNewCollection'.tr,
                      onPressed: _createCollection,
                    ),
                  ),
                  Expanded(
                    child:
                        _loading
                            ? const Center(child: DSLoadingDots())
                            : RefreshIndicator(
                              onRefresh: _reload,
                              child:
                                  _collections.isEmpty
                                      ? ListView(
                                        children: [
                                          const SizedBox(height: 80),
                                          DSEmptyState(
                                            icon: DsIconKind.mood,
                                            title: 'chat_stickerEmptyTitle'.tr,
                                            message:
                                                'chat_stickerEmptyMessage'.tr,
                                            actionLabel:
                                                'chat_stickerNewCollection'.tr,
                                            onAction: _createCollection,
                                          ),
                                        ],
                                      )
                                      : ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          8,
                                          16,
                                          24,
                                        ),
                                        itemCount: _collections.length,
                                        itemBuilder: (context, index) {
                                          final collection =
                                              _collections[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: _buildCollectionCard(
                                              theme,
                                              collection,
                                            ),
                                          );
                                        },
                                      ),
                            ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollectionCard(
    AppThemeData theme,
    StickerCollection collection,
  ) {
    final cover = collection.coverPath ?? collection.stickerPaths.firstOrNull;

    return DSCard(
      onTap: () => _openDetail(collection.id),
      padding: EdgeInsets.all(theme.spacing.md),
      child: Row(
        children: [
          _buildCover(theme, cover),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  collection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                const SizedBox(height: 2),
                Text(
                  'chat_stickerCountDate'.trParams({
                    'count': '${collection.stickerCount}',
                    'date': collection.updatedAt.toString().substring(0, 10),
                  }),
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          _buildCollectionMenu(theme, collection),
        ],
      ),
    );
  }

  /// 合集封面：手绘墨线小容器 + 首张贴图
  Widget _buildCover(AppThemeData theme, String? cover) {
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surfaceAlt,
        radius: theme.radii.md,
      ),
      child:
          cover != null
              ? Image(
                image: ImageUtils.createImageProvider('./$cover'),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) => Center(
                      child: DsIcon(DsIconKind.image, color: theme.textSub),
                    ),
              )
              : Center(child: DsIcon(DsIconKind.mood, color: theme.textSub)),
    );
  }

  /// 合集操作菜单：编辑/添加/重命名/删除（替代 PopupMenuButton）
  Widget _buildCollectionMenu(
    AppThemeData theme,
    StickerCollection collection,
  ) {
    return DSPopover(
      width: 170,
      contentBuilder: (popoverContext, close) {
        final popoverTheme = DSThemeBridge.resolve(popoverContext);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StickerMenuAction(
              icon: DsIconKind.grid,
              label: 'chat_stickerMenuEdit'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                _openDetail(collection.id);
              },
            ),
            _StickerMenuAction(
              icon: DsIconKind.image,
              label: 'chat_stickerMenuAdd'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                _pickAndAddStickers(collection.id);
              },
            ),
            _StickerMenuAction(
              icon: DsIconKind.edit,
              label: 'chat_stickerMenuRename'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                _renameCollection(collection);
              },
            ),
            _StickerMenuAction(
              icon: DsIconKind.trash,
              label: 'chat_stickerMenuDelete'.tr,
              theme: popoverTheme,
              danger: true,
              onTap: () {
                close();
                _deleteCollection(collection);
              },
            ),
          ],
        );
      },
      child: DSIconButton(
        icon: DsIconKind.more,
        size: 34,
        color: theme.surface,
        iconColor: theme.textSub,
      ),
    );
  }
}

/// 菜单操作行（手绘 Popover 内）
class _StickerMenuAction extends StatelessWidget {
  const _StickerMenuAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.danger = false,
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.text;
    return Pressable(
      onPressed: onTap,
      semanticLabel: label,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: pressed ? theme.surfaceAlt : null,
            borderRadius: theme.radii.sm,
          ),
          child: Row(
            children: [
              DsIcon(icon, size: 16, color: accent),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  style: DsTypography.body.copyWith(color: accent),
                ),
              ),
            ],
          ),
        );
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
      if (mounted) {
        toastService.showToast(
          'chat_stickerAddFailed'.trParams({'error': '$e'}),
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _removeSticker(String stickerPath) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      builder:
          (dialogContext) => DSDialog(
            title: 'chat_deleteSticker'.tr,
            message: 'chat_confirmDeleteSticker'.tr,
            confirmText: 'app_delete'.tr,
            cancelText: 'app_cancel'.tr,
            confirmVariant: DSButtonVariant.destructive,
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

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Scaffold(
            backgroundColor: dsScaffoldBackground(theme),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  DSLightHeader(
                    title: collection?.name ?? 'chat_stickerCollectionTitle'.tr,
                    trailing: DSIconButton(
                      icon: DsIconKind.image,
                      size: 38,
                      color: theme.surface,
                      iconColor: theme.text,
                      tooltip: 'chat_stickerMenuAdd'.tr,
                      onPressed: _addStickers,
                    ),
                  ),
                  Expanded(
                    child:
                        collection == null
                            ? const Center(child: DSLoadingDots())
                            : collection.stickerPaths.isEmpty
                            ? Center(
                              child: DSEmptyState(
                                icon: DsIconKind.image,
                                title: 'chat_stickerEmptyGrid'.tr,
                                actionLabel: 'chat_stickerMenuAdd'.tr,
                                onAction: _addStickers,
                              ),
                            )
                            : _buildGrid(theme, collection),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(AppThemeData theme, StickerCollection collection) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 96,
        mainAxisExtent: 96,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: collection.stickerPaths.length,
      itemBuilder: (context, index) {
        final stickerPath = collection.stickerPaths[index];
        return Pressable(
          // 仅长按删除；空 onPressed 会让 Pressable 判定禁用而吞掉长按
          onPressed: () {},
          onLongPress: () => _removeSticker(stickerPath),
          semanticLabel: 'sticker $index',
          builder: (context, states) {
            final pressed = states.contains(WidgetState.pressed);
            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: pressed ? theme.surfaceAlt : theme.surface,
                radius: theme.radii.lg,
              ),
              child: Image(
                image: ImageUtils.createImageProvider('./$stickerPath'),
                fit: BoxFit.contain,
                errorBuilder:
                    (_, _, _) => Center(
                      child: DsIcon(DsIconKind.image, color: theme.textSub),
                    ),
              ),
            );
          },
        );
      },
    );
  }
}
