import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:aboutme/constants/app_icons.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/emoji_picker/index.dart';

/// 文件夹贴纸选择 Sheet 内容（配合 SmoothBottomSheet 使用）
///
/// 三个标签页：图标（AppIcons 搜索网格）/ 表情（EmojiPicker）/ 图片（该标签下的图片）。
/// 选中后写入 [TagController] 并关闭抽屉；已设置贴纸时顶部提供移除入口。
class FolderIconSheet extends StatefulWidget {
  const FolderIconSheet({
    super.key,
    required this.tag,
    required this.tagController,
    this.imageUrls = const [],
  });

  final String tag;
  final TagController tagController;

  /// 该标签下的图片（图片贴纸页的数据源）
  final List<String> imageUrls;

  @override
  State<FolderIconSheet> createState() => _FolderIconSheetState();
}

class _FolderIconSheetState extends State<FolderIconSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<MapEntry<String, IconData>> _filtered = [];
  int _tab = 0;

  String? get _currentSticker => widget.tagController.tagIcons[widget.tag];

  @override
  void initState() {
    super.initState();
    _updateFiltered();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _updateFiltered() {
    final entries = AppIcons.predefinedIcons.entries;
    _filtered =
        _query.isEmpty
            ? entries.toList()
            : entries
                .where((e) => e.key.toLowerCase().contains(_query))
                .toList();
  }

  Future<void> _select(String sticker) async {
    await widget.tagController.setTagIcon(widget.tag, sticker);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    await widget.tagController.setTagIcon(widget.tag, null);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 类型切换：图标 / 表情 / 图片
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: DSSegmentedControl(
            options: [
              'calendar_album_sticker_tab_icon'.tr,
              'calendar_album_sticker_tab_emoji'.tr,
              'calendar_album_sticker_tab_image'.tr,
            ],
            selected: _tab,
            onChanged: (index) => setState(() => _tab = index),
          ),
        ),

        // 移除贴纸入口
        if (_currentSticker != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  'calendar_album_folder_icon_current'.tr,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
                const Spacer(),
                DSButton(
                  label: 'calendar_album_remove_folder_icon'.tr,
                  variant: DSButtonVariant.outline,
                  size: DSButtonSize.sm,
                  onPressed: _remove,
                ),
              ],
            ),
          ),

        SizedBox(
          height: 320,
          child:
              _tab == 0
                  ? _buildIconTab(theme)
                  : _tab == 1
                  ? _buildEmojiTab()
                  : _buildImageTab(theme),
        ),
      ],
    );
  }

  /// 图标页：搜索 + 懒加载网格
  Widget _buildIconTab(AppThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DSInput(
            controller: _searchController,
            hint: 'widget_searchIcons'.tr,
            prefix: DsIcon(DsIconKind.search, size: 20, color: theme.textSub),
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                setState(() {
                  _query = value.trim().toLowerCase();
                  _updateFiltered();
                });
              });
            },
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final entry = _filtered[index];
              final isSelected = entry.key == _currentSticker;
              return Pressable(
                onPressed: () => _select(entry.key),
                semanticLabel: entry.key,
                builder: (context, states) {
                  final pressed = states.contains(WidgetState.pressed);
                  return JellyBox(
                    radius: theme.radii.md,
                    color: isSelected ? theme.primary : null,
                    raised: isSelected && !pressed,
                    alignment: Alignment.center,
                    child: Icon(
                      entry.value,
                      size: 22,
                      color: isSelected ? theme.onPrimary : theme.text,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// 表情页：项目内 vendor 的 EmojiPicker（需 ProviderScope）
  Widget _buildEmojiTab() {
    return ProviderScope(
      child: EmojiPicker(
        onSelection: (value, isFreeText) => _select('emoji:$value'),
      ),
    );
  }

  /// 图片页：从该标签下的图片中选一张作为贴图
  Widget _buildImageTab(AppThemeData theme) {
    if (widget.imageUrls.isEmpty) {
      return Center(
        child: Text(
          'calendar_album_folder_no_images'.tr,
          style: DsTypography.body.copyWith(color: theme.textSub),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.imageUrls.length,
      itemBuilder: (context, index) {
        final url = widget.imageUrls[index];
        final isSelected = _currentSticker == 'img:$url';
        return Pressable(
          onPressed: () => _select('img:$url'),
          semanticLabel: 'image $index',
          builder: (context, states) {
            final pressed = states.contains(WidgetState.pressed);
            return Container(
              decoration: BoxDecoration(
                borderRadius: theme.radii.md,
                border: Border.all(
                  color: isSelected ? theme.primary : theme.ink.withValues(alpha: 0.10),
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Opacity(
                opacity: pressed ? 0.7 : 1,
                child: _StickerImage(url: url, theme: theme),
              ),
            );
          },
        );
      },
    );
  }
}

/// 贴纸选择网格中的图片（网络/本地路径自适应）
class _StickerImage extends StatelessWidget {
  const _StickerImage({required this.url, required this.theme});

  final String url;
  final AppThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return FutureBuilder<String>(
      future: ImageUtils.getAbsolutePath(url),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path != null && path.isNotEmpty && File(path).existsSync()) {
          return Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          );
        }
        return _fallback();
      },
    );
  }

  Widget _fallback() {
    return Container(
      color: theme.surfaceAlt,
      child: Center(
        child: DsIcon(
          DsIconKind.image,
          size: 20,
          color: theme.textSub.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
