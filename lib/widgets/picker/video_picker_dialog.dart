import 'dart:typed_data';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart' show StorageFileInfo;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:super_cupertino_navigation_bar/utils/navigation_bar_static_components.dart';
import 'package:super_cupertino_navigation_bar/utils/persistent_nav_bar.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/data/sdk_media_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/utils/platform_utils.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_builders.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/multi_filter_bar.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 视频选择器底部弹窗（结构与 ImagePickerDialog 一致的视频版）
///
/// 结构：PersistentNavigationBar 头部（右侧为 录像 / 在线URL 入口）+
/// MultiFilterBar 多条件过滤（插件/日期/大小）+ 视频网格。
/// 网格聚合展示应用存储内各插件保存的视频文件，
/// 首格为相册入口：移动端使用 wechat_assets_picker，桌面端走系统文件选择。
///
/// 返回值：单选 `{'url', 'bytes': null}`，多选返回其列表，取消返回 null；
/// url 为 './' 相对路径（相册/录像选择已在选择器内落盘）或在线 URL。
class VideoPickerDialog extends StatefulWidget {
  /// 视频保存的目录名称，默认为 'app_videos'
  final String saveDirectory;

  /// 是否允许多视频选择
  final bool multiple;

  const VideoPickerDialog({
    super.key,
    this.saveDirectory = 'app_videos',
    this.multiple = false,
  });

  /// 以底部弹窗打开视频选择器
  static Future<T?> show<T>(
    BuildContext context, {
    String saveDirectory = 'app_videos',
    bool multiple = false,
  }) {
    return Navigator.of(context).push<T>(
      ModalSheetRoute<T>(
        swipeDismissible: true,
        builder:
            (context) => VideoPickerDialog(
              saveDirectory: saveDirectory,
              multiple: multiple,
            ),
      ),
    );
  }

  @override
  State<VideoPickerDialog> createState() => _VideoPickerDialogState();
}

class _VideoPickerDialogState extends State<VideoPickerDialog> {
  final ImagePicker _picker = ImagePicker();

  /// PersistentNavigationBar 组件 key（GlobalKey 需跨帧稳定，不能每次 build 新建）
  final NavigationBarStaticComponentsKeys _navBarKeys =
      NavigationBarStaticComponentsKeys();

  /// 多条件过滤状态
  final MultiFilterState _filterState = MultiFilterState();

  /// 应用存储内的视频元信息（相对 app_data），按修改时间倒序，最多 300 条
  List<StorageFileInfo> _allInfos = [];

  /// 全量文件 key（含 .thumb.jpg 伴生缩略图），用于推断视频缩略图
  Set<String> _allKeys = {};

  /// 缩略图生成中的视频 key（防重复请求）
  final Set<String> _thumbGenerating = {};
  final Map<String, Uint8List> _thumbImages = {};

  bool _loading = true;

  /// 多选模式下已选中的视频 key
  final List<String> _selected = [];

  /// 运行时多选状态：初始取 widget.multiple，
  /// 单选模式下长按视频可切换为多选（与图片选择器交互一致）
  late bool _multiple = widget.multiple;

  static const _videoExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.3gp',
    '.m4v',
  };

  static const _kb = 1024;
  static const _mb = 1024 * 1024;

  /// 日期过滤选项（key -> 显示文本）
  Map<String, String> get _dateFilterOptions => {
    'today': 'image_picker_date_today'.tr,
    'week': 'image_picker_date_week'.tr,
    'month': 'image_picker_date_month'.tr,
    'quarter': 'image_picker_date_quarter'.tr,
    'older': 'image_picker_date_older'.tr,
  };

  /// 大小过滤选项（key -> 显示文本）
  static const Map<String, String> _sizeFilterOptions = {
    'lt1m': '< 1MB',
    'to10m': '1MB - 10MB',
    'to100m': '10MB - 100MB',
    'gt100m': '> 100MB',
  };

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _filterState.dispose();
    super.dispose();
  }

  bool _isVideoExtension(String key) =>
      _videoExtensions.contains(path.extension(key).toLowerCase());

  /// 汇总应用存储内各目录的视频元信息，最近修改的在前
  Future<void> _loadVideos() async {
    try {
      final infos = [...await globalStorage.listFileInfos(''),
        ...await SdkMediaService.listMedia('video/')];

      final allKeys = <String>{};
      final videos = <StorageFileInfo>[];
      for (final info in infos) {
        final key = info.path.replaceAll(r'\', '/');
        // 两个来源（应用存储 / SDK 资源）同 key 只保留一条
        if (!allKeys.add(key)) continue;
        if (ImageUtils.sdkAssetId(key) == null && !_isVideoExtension(key)) continue;
        videos.add(
          StorageFileInfo(
            path: key,
            size: info.size,
            updatedAt: info.updatedAt,
          ),
        );
      }

      videos.sort(
        (a, b) =>
            (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
      );

      final limited = videos.length > 300 ? videos.sublist(0, 300) : videos;

      if (mounted) {
        setState(() {
          _allInfos = limited;
          _allKeys = allKeys;
        });
      }
    } catch (e) {
      debugPrint('加载视频列表失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 视频的伴生缩略图 key（沿用图片 `<name>.thumb` 命名约定，视频统一 jpg）
  String _thumbKeyFor(String key) {
    if (ImageUtils.sdkAssetId(key) != null) return '$key#thumb';
    final dir = path.dirname(key);
    final name = path.basenameWithoutExtension(key);
    return '$dir/$name.thumb.jpg';
  }

  /// 移动端为无缩略图的视频懒生成首帧缩略图
  /// （video_thumbnail 仅支持 iOS/Android，桌面端跳过由占位图标兜底）
  Future<void> _ensureThumb(String key) async {
    if (!PlatformUtils.isMobile || _thumbGenerating.contains(key)) return;
    final thumbKey = _thumbKeyFor(key);
    if (_allKeys.contains(thumbKey)) return;
    _thumbGenerating.add(key);
    try {
      final videoAbs = await ImageUtils.getAbsolutePath('./$key');
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoAbs,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 220,
        quality: 60,
      );
      if (bytes == null) return;
      if (mounted) {
        setState(() { _allKeys.add(thumbKey); _thumbImages[thumbKey] = bytes; });
      }
    } catch (e) {
      debugPrint('生成视频缩略图失败 $key: $e');
    } finally {
      _thumbGenerating.remove(key);
    }
  }

  /// 视频所属的顶层目录（插件维度），如 chat/chat_files/x.mp4 -> chat
  String? _pluginDirOf(String key) {
    if (ImageUtils.sdkAssetId(key) != null) return null;
    final index = key.indexOf('/');
    return index > 0 ? key.substring(0, index) : null;
  }

  /// 插件目录的显示标题：优先取插件翻译键 `<id>_name`
  String _pluginTitleOf(String dir) {
    final key = dir == 'media_log' ? 'media_name' : '${dir}_name';
    final translated = key.tr;
    return translated == key ? dir : translated;
  }

  /// 可选的插件（顶层目录）列表
  List<String> get _pluginDirs {
    final dirs = <String>{};
    for (final info in _allInfos) {
      final dir = _pluginDirOf(info.path);
      if (dir != null) dirs.add(dir);
    }
    return dirs.toList()..sort();
  }

  /// 应用过滤条件后的视频列表
  List<StorageFileInfo> get _filteredInfos {
    if (!_filterState.hasAnyFilter) return _allInfos;

    final values = _filterState.getAllValues();
    final plugins = (values['plugin'] as List?)?.cast<String>().toList();
    final date = values['date'] as String?;
    final size = values['size'] as String?;

    final now = DateTime.now();
    final DateTime? minDate = switch (date) {
      'today' => DateTime(now.year, now.month, now.day),
      'week' => now.subtract(const Duration(days: 7)),
      'month' => now.subtract(const Duration(days: 30)),
      'quarter' => now.subtract(const Duration(days: 90)),
      _ => null,
    };
    final bool olderOnly = date == 'older';
    final DateTime olderCutoff = now.subtract(const Duration(days: 90));

    return _allInfos.where((info) {
      // 插件过滤
      if (plugins != null && plugins.isNotEmpty) {
        final dir = _pluginDirOf(info.path);
        if (dir == null || !plugins.contains(dir)) return false;
      }

      // 日期过滤
      if (olderOnly) {
        final updated = info.updatedAt;
        if (updated == null || !updated.isBefore(olderCutoff)) return false;
      } else if (minDate != null) {
        final updated = info.updatedAt;
        if (updated == null || !updated.isAfter(minDate)) return false;
      }

      // 大小过滤
      if (size != null) {
        final s = info.size;
        if (s == null) return false;
        switch (size) {
          case 'lt1m':
            if (s >= _mb) return false;
          case 'to10m':
            if (s < _mb || s >= 10 * _mb) return false;
          case 'to100m':
            if (s < 10 * _mb || s >= 100 * _mb) return false;
          case 'gt100m':
            if (s < 100 * _mb) return false;
        }
      }

      return true;
    }).toList();
  }

  /// 点击网格内已有视频
  void _selectVideo(String key) {
    if (_multiple) {
      setState(() {
        _selected.contains(key) ? _selected.remove(key) : _selected.add(key);
      });
      return;
    }
    Navigator.of(context).pop(<String, dynamic>{'url': ImageUtils.sdkAssetId(key) != null ? key : './$key', 'bytes': null});
  }

  /// 长按视频：单选模式切入多选并选中该视频；已是多选则忽略
  void _longPressVideo(String key) {
    if (_multiple) return;
    setState(() {
      _multiple = true;
      _selected.add(key);
    });
  }

  /// 取消多选：退回单选模式并清空已选
  void _cancelMultiple() {
    setState(() {
      _multiple = false;
      _selected.clear();
    });
  }

  Future<void> _confirmMultiple() async {
    final results = <Map<String, dynamic>>[
      for (final key in _selected) {'url': ImageUtils.sdkAssetId(key) != null ? key : './$key', 'bytes': null},
    ];
    if (results.isNotEmpty) Navigator.of(context).pop(results);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Sheet(
      // 网格滚到顶后再向下拖才会收起弹窗
      scrollConfiguration: const SheetScrollConfiguration(),
      decoration: MaterialSheetDecoration(
        size: SheetSize.fit,
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, theme),
            if (_allInfos.isNotEmpty)
              MultiFilterBar(
                filterItems: _buildFilterItems(),
                filterState: _filterState,
                onFilterChanged: (_) => setState(() {}),
              ),
            SizedBox(height: screenHeight * 0.5, child: _buildGrid(theme)),
            if (_multiple) _buildConfirmBar(theme),
            SafeArea(
              top: false,
              child: SizedBox(height: theme.spacing.sm),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部导航：嵌入式 PersistentNavigationBar（super_cupertino_navigation_bar）
  Widget _buildHeader(BuildContext context, AppThemeData theme) {
    return PersistentNavigationBar(
      components: NavigationBarStaticComponents(
        keys: _navBarKeys,
        route: null,
        // 单选：无返回钮（下滑或点遮罩关闭）；多选：左侧为取消按钮
        userLeading:
            _multiple
                ? TextButton(
                    onPressed: _cancelMultiple,
                    child: Text(
                      'app_cancel'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  )
                : null,
        automaticallyImplyLeading: false,
        automaticallyImplyTitle: false,
        previousPageTitle: null,
        userMiddle: Text(
          _multiple
              ? 'video_picker_selectMultipleVideos'.tr
              : 'video_picker_selectVideo'.tr,
          style: DsTypography.title.copyWith(color: theme.text),
        ),
        userTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DSIconButton(
              icon: DsIconKind.video,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              tooltip: 'video_picker_takeVideo'.tr,
              onPressed: () => _takeVideo(context),
            ),
            const SizedBox(width: 4),
            DSIconButton(
              icon: DsIconKind.link,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              tooltip: 'video_picker_onlineVideo'.tr,
              onPressed: () => _showUrlSheet(),
            ),
          ],
        ),
        userLargeTitle: null,
        largeTitleActions: null,
        appbarBottom: null,
        padding: null,
        // 嵌入式小导航（底部弹窗），非大标题模式
        large: false,
      ),
    );
  }

  /// 弹出在线 URL 输入的二级底部弹窗，确认后连同主弹窗一起返回结果
  Future<void> _showUrlSheet() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      ModalSheetRoute<Map<String, dynamic>>(
        swipeDismissible: true,
        builder: (context) => _UrlInputSheet(),
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  /// 多条件过滤项：插件 / 日期 / 大小
  List<FilterItem> _buildFilterItems() {
    final dirs = _pluginDirs;

    return [
      // 1. 插件（顶层目录）多选过滤，标签显示插件标题
      if (dirs.isNotEmpty)
        FilterItem(
          id: 'plugin',
          title: 'image_picker_filter_plugin'.tr,
          type: FilterType.tagsMultiple,
          builder: (context, currentValue, onChanged) {
            final selected = (currentValue as List<String>?) ?? [];
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final dir in dirs)
                  DSChip(
                    label: _pluginTitleOf(dir),
                    selected: selected.contains(dir),
                    onSelected: (isSelected) {
                      final newDirs = List<String>.from(selected);
                      if (isSelected) {
                        newDirs.add(dir);
                      } else {
                        newDirs.remove(dir);
                      }
                      onChanged(newDirs);
                    },
                  ),
              ],
            );
          },
          getBadge: FilterBuilders.tagsBadge,
        ),

      // 2. 日期单选过滤
      FilterItem(
        id: 'date',
        title: 'image_picker_filter_date'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildSingleChoiceFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
            options: _dateFilterOptions,
            allItemsKey: 'all',
            allItemsLabel: 'image_picker_filter_all'.tr,
          );
        },
        getBadge: (value) =>
            FilterBuilders.singleChoiceBadge(value, _dateFilterOptions),
      ),

      // 3. 大小单选过滤
      FilterItem(
        id: 'size',
        title: 'image_picker_filter_size'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildSingleChoiceFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
            options: _sizeFilterOptions,
            allItemsKey: 'all',
            allItemsLabel: 'image_picker_filter_all'.tr,
          );
        },
        getBadge: (value) =>
            FilterBuilders.singleChoiceBadge(value, _sizeFilterOptions),
      ),
    ];
  }

  Widget _buildGrid(AppThemeData theme) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final videos = _filteredInfos;

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 110,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: videos.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildAlbumTile(theme);
              return _buildVideoTile(theme, videos[index - 1]);
            },
          ),
        ),
        if (videos.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.xl),
            child: Text(
              _allInfos.isEmpty
                  ? 'video_picker_noVideos'.tr
                  : 'image_picker_noMatches'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ),
      ],
    );
  }

  /// 首格：相册入口（移动端 wechat_assets_picker / 桌面端系统文件选择）
  Widget _buildAlbumTile(AppThemeData theme) {
    final isMobile = PlatformUtils.isMobile;
    return Material(
      color: theme.primary.mixWhite(0.9),
      borderRadius: theme.radii.md,
      child: InkWell(
        borderRadius: theme.radii.md,
        onTap:
            () => isMobile
                ? _pickFromAssetPicker(context)
                : _pickFromGallery(context),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsIcon(DsIconKind.photoLibrary, color: theme.primary, size: 26),
              const SizedBox(height: 4),
              Text(
                'image_picker_chooseFromGallery'.tr,
                style: DsTypography.caption.copyWith(color: theme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoTile(AppThemeData theme, StorageFileInfo info) {
    final key = info.path;
    final isSelected = _selected.contains(key);
    final selectedIndex = _selected.indexOf(key) + 1;
    final sizeText =
        info.size == null
            ? ''
            : info.size! >= _mb
            ? '${(info.size! / _mb).toStringAsFixed(1)}MB'
            : '${(info.size! / _kb).toStringAsFixed(0)}KB';
    final thumbKey = _thumbKeyFor(key);
    final hasThumb = _allKeys.contains(thumbKey);

    return GestureDetector(
      onTap: () => _selectVideo(key),
      onLongPress: () => _longPressVideo(key),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: theme.radii.md,
          border:
              isSelected ? Border.all(color: theme.primary, width: 2) : null,
        ),
        child: ClipRRect(
          borderRadius: theme.radii.md,
          child: Stack(
            fit: StackFit.expand,
            children: [
              hasThumb
                  ? _buildThumbContent(theme, thumbKey, sizeText)
                  : _buildVideoPlaceholder(theme, info, sizeText),
              if (_multiple)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isSelected
                              ? theme.primary
                              : Colors.black.withValues(alpha: 0.25),
                      border:
                          isSelected ? null : Border.all(color: Colors.white70),
                    ),
                    child: Center(
                      // 未选中时角标为空圈，不显示序号（避免 indexOf(-1)+1 显示 0）
                      child:
                          isSelected
                              ? Text(
                                '$selectedIndex',
                                style: DsTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 缩略图内容：首帧铺满 + 半透明播放角标 + 右下大小角标
  Widget _buildThumbContent(
    AppThemeData theme,
    String thumbKey,
    String sizeText,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: _thumbImages[thumbKey] == null ? ImageUtils.createImageProvider('./$thumbKey') : MemoryImage(_thumbImages[thumbKey]!),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _videoFallback(theme),
        ),
        Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.35),
            ),
            child: const Center(
              child: DsIcon(DsIconKind.play, size: 20, color: Colors.white),
            ),
          ),
        ),
        if (sizeText.isNotEmpty)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                sizeText,
                style: DsTypography.caption.copyWith(
                  color: Colors.white,
                  fontSize: 9,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 无缩略图占位：图标 + 文件名 + 大小，并触发移动端懒生成
  Widget _buildVideoPlaceholder(
    AppThemeData theme,
    StorageFileInfo info,
    String sizeText,
  ) {
    // 幂等：已有/生成中直接跳过，成功后 setState 刷新为缩略图
    _ensureThumb(info.path);
    return _videoFallbackBody(theme, info.path, sizeText);
  }

  Widget _videoFallbackBody(
    AppThemeData theme,
    String key,
    String sizeText,
  ) {
    return Container(
      color: theme.primary.mixWhite(0.85),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DsIcon(DsIconKind.video, size: 26, color: theme.primary),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              path.basename(key),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.caption.copyWith(
                color: theme.primary,
                fontSize: 9,
              ),
            ),
          ),
          if (sizeText.isNotEmpty)
            Text(
              sizeText,
              style: DsTypography.caption.copyWith(
                color: theme.primary.withValues(alpha: 0.7),
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }

  /// 缩略图解码失败时回退占位（不重复触发懒生成，避免解码失败循环）
  Widget _videoFallback(AppThemeData theme) {
    return Container(
      color: theme.primary.mixWhite(0.85),
      child: Center(child: DsIcon(DsIconKind.video, size: 26, color: theme.primary)),
    );
  }

  /// 多选确认栏：左侧已选缩略图横滑条（右上 × 移除、长按拖拽排序）
  /// + 右侧确认按钮
  Widget _buildConfirmBar(AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 60,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 2,
                ),
                itemCount: _selected.length,
                onReorder: _onReorderSelected,
                itemBuilder: (context, index) {
                  final key = _selected[index];
                  return _buildSelectedThumb(
                    theme,
                    key,
                    index,
                    keyId: ValueKey(key),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          DSButton(
            label: 'app_confirm'.tr,
            size: DSButtonSize.sm,
            onPressed: _selected.isEmpty ? null : _confirmMultiple,
          ),
        ],
      ),
    );
  }

  /// 拖拽排序回调：调整已选顺序
  void _onReorderSelected(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, item);
    });
  }

  /// 已选视频缩略图：右上 × 移除，左下序号（无首帧缩略图时用图标占位）
  Widget _buildSelectedThumb(
    AppThemeData theme,
    String key,
    int index, {
    required ValueKey<String> keyId,
  }) {
    final thumbKey = _thumbKeyFor(key);
    final hasThumb = _allKeys.contains(thumbKey);
    return Padding(
      key: keyId,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: theme.radii.sm,
            child: SizedBox(
              width: 48,
              height: 48,
              child:
                  hasThumb
                      ? Image(
                        image: _thumbImages[thumbKey] == null ? ImageUtils.createImageProvider('./$thumbKey') : MemoryImage(_thumbImages[thumbKey]!),
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, _, _) => _selectedThumbFallback(theme),
                      )
                      : _selectedThumbFallback(theme),
            ),
          ),
          // 左下序号
          Positioned(
            left: 2,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${index + 1}',
                style: DsTypography.caption.copyWith(
                  color: Colors.white,
                  fontSize: 9,
                ),
              ),
            ),
          ),
          // 右上取消图标（点 × 移除该视频）
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () => setState(() => _selected.remove(key)),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.text,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: DsIcon(
                    DsIconKind.close,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedThumbFallback(AppThemeData theme) {
    return Container(
      color: theme.primary.mixWhite(0.85),
      child: Center(
        child: DsIcon(DsIconKind.video, size: 18, color: theme.primary),
      ),
    );
  }

  /// 移动端：wechat_assets_picker 相册选视频
  Future<void> _pickFromAssetPicker(BuildContext context) async {
    try {
      final entities = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          requestType: RequestType.video,
          maxAssets: _multiple ? 30 : 1,
        ),
      );
      if (entities == null || entities.isEmpty) {
        debugPrint('用户未选择相册视频');
        return;
      }

      final videos = <XFile>[];
      for (final entity in entities) {
        final file = await entity.originFile;
        if (file != null) {
          videos.add(XFile(file.path));
        }
      }
      await _processSelectedVideos(context, videos);
    } catch (e) {
      debugPrint('相册选择发生异常: $e');
      if (context.mounted) {
        Toast.error('${'chat_videoSelectionFailed'.tr}: $e');
      }
    }
  }

  /// 桌面端/Web：系统文件选择（image_picker 桌面端为单选）
  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (video == null) {
        debugPrint('用户未选择视频');
        return;
      }
      await _processSelectedVideos(context, [video]);
    } catch (e, stackTrace) {
      debugPrint('选择视频发生异常: $e');
      debugPrint('异常堆栈: $stackTrace');
      if (context.mounted) {
        Toast.error('${'chat_videoSelectionFailed'.tr}: $e');
      }
    }
  }

  /// 录像
  Future<void> _takeVideo(BuildContext context) async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
      if (video == null) {
        debugPrint('用户取消录像');
        return;
      }
      await _processSelectedVideos(context, [video]);
    } catch (e, stackTrace) {
      debugPrint('录像过程发生异常: $e');
      debugPrint('异常堆栈: $stackTrace');
      if (context.mounted) {
        Toast.error('${'chat_videoSelectionFailed'.tr}: $e');
      }
    }
  }

  /// 统一处理选中的视频：保存到应用存储后返回相对路径
  /// （ImageUtils.saveImage 为 uuid 重命名 + 纯拷贝，视频同样适用）
  Future<void> _processSelectedVideos(
    BuildContext context,
    List<XFile> videos,
  ) async {
    try {
      if (videos.isEmpty) return;

      final results = <Map<String, dynamic>>[];
      for (final video in videos) {
        final relativePath = (await SdkMediaService.importPicked(video)).reference;
        debugPrint('视频保存完成，相对路径: $relativePath');
        results.add({'url': relativePath, 'bytes': null});
      }

      if (results.isNotEmpty && context.mounted) {
        final result = _multiple ? results : results.first;
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      debugPrint('处理视频发生异常: $e');
      if (context.mounted) {
        Toast.error('${'chat_videoProcessingFailed'.tr}: $e');
      }
    }
  }
}

/// 在线视频 URL 输入的二级底部弹窗
///
/// 确认时 pop `{'url', 'bytes': null}`，取消/下滑 pop null；
/// 主弹窗收到结果后再以相同结果 pop 交给调用方。
class _UrlInputSheet extends StatefulWidget {
  const _UrlInputSheet();

  @override
  State<_UrlInputSheet> createState() => _UrlInputSheetState();
}

class _UrlInputSheetState extends State<_UrlInputSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _validate(_controller.text);
    // 打开即聚焦弹键盘
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _validate(String url) {
    final valid =
        url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  void _confirm() {
    if (!_isValid) return;
    Navigator.of(context).pop(<String, dynamic>{
      'url': _controller.text,
      'bytes': null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Sheet(
      decoration: MaterialSheetDecoration(
        size: SheetSize.fit,
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: theme.spacing.lg),
            Text(
              'video_picker_onlineVideo'.tr,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
            SizedBox(height: theme.spacing.md),
            DSInput(
              controller: _controller,
              label: 'video_picker_onlineVideo'.tr,
              hint: 'https://...mp4',
              focusNode: _focusNode,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _confirm(),
              onChanged: _validate,
            ),
            SizedBox(height: theme.spacing.md),
            Row(
              children: [
                Expanded(
                  child: DSButton(
                    label: 'app_cancel'.tr,
                    variant: DSButtonVariant.outline,
                    size: DSButtonSize.sm,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DSButton(
                    label: 'app_confirm'.tr,
                    size: DSButtonSize.sm,
                    onPressed: _isValid ? _confirm : null,
                  ),
                ),
              ],
            ),
            SafeArea(top: false, child: SizedBox(height: theme.spacing.md)),
          ],
        ),
      ),
    );
  }
}
