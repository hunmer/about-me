import 'dart:async';
import 'dart:io';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart' show StorageFileInfo;
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:super_cupertino_navigation_bar/utils/navigation_bar_static_components.dart';
import 'package:super_cupertino_navigation_bar/utils/persistent_nav_bar.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/core/services/image_compression_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/scripts_center/scripts_center_plugin.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/utils/platform_utils.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_builders.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/multi_filter_bar.dart';

/// 图片选择器底部弹窗（smooth_sheets ModalSheet）
///
/// 结构：PersistentNavigationBar 头部（右侧为 拍照 / 在线URL 入口）+
/// MultiFilterBar 多条件过滤（插件/日期/大小）+ 图片网格。
/// 网格聚合展示应用存储内各插件上传的图片（chat、calendar_album 等），
/// 首格为相册入口：移动端使用 wechat_assets_picker，桌面端走系统文件选择。
class ImagePickerDialog extends StatefulWidget {
  final String? initialUrl;

  /// 图片保存的目录名称，默认为 'app_images'
  final String saveDirectory;

  /// 是否启用图片裁剪功能
  final bool enableCrop;

  /// 裁剪比例，仅在 enableCrop 为 true 时生效
  final double? cropAspectRatio;

  /// 是否允许多图片选择
  final bool multiple;

  /// 是否启用图片压缩（默认关闭）
  final bool enableCompression;

  /// 缩略图保存路径（如果不指定则是保存的文件名+.thumb）
  final String? thumbnailPath;

  /// 压缩质量 0-100（默认 85）
  final int compressionQuality;

  const ImagePickerDialog({
    super.key,
    this.initialUrl,
    this.saveDirectory = 'app_images',
    this.enableCrop = false,
    this.cropAspectRatio,
    this.multiple = false,
    this.enableCompression = false,
    this.thumbnailPath,
    this.compressionQuality = 85,
  });

  /// 以底部弹窗打开图片选择器
  ///
  /// 返回值与旧版 showDialog 一致：
  /// 单选返回 `{'url', 'thumbUrl', 'bytes'}`，多选返回其列表，取消返回 null。
  static Future<T?> show<T>(
    BuildContext context, {
    String? initialUrl,
    String saveDirectory = 'app_images',
    bool enableCrop = false,
    double? cropAspectRatio,
    bool multiple = false,
    bool enableCompression = false,
    String? thumbnailPath,
    int compressionQuality = 85,
  }) {
    return Navigator.of(context).push<T>(
      ModalSheetRoute<T>(
        swipeDismissible: true,
        builder:
            (context) => ImagePickerDialog(
              initialUrl: initialUrl,
              saveDirectory: saveDirectory,
              enableCrop: enableCrop,
              cropAspectRatio: cropAspectRatio,
              multiple: multiple,
              enableCompression: enableCompression,
              thumbnailPath: thumbnailPath,
              compressionQuality: compressionQuality,
            ),
      ),
    );
  }

  @override
  State<ImagePickerDialog> createState() => _ImagePickerDialogState();
}

class _ImagePickerDialogState extends State<ImagePickerDialog> {
  final ImagePicker _picker = ImagePicker();

  /// PersistentNavigationBar 组件 key（GlobalKey 需跨帧稳定，不能每次 build 新建）
  final NavigationBarStaticComponentsKeys _navBarKeys =
      NavigationBarStaticComponentsKeys();

  /// 多条件过滤状态
  final MultiFilterState _filterState = MultiFilterState();

  /// 应用存储内的图片元信息（相对 app_data，如 chat/chat_files/xxx.jpg），
  /// 按修改时间倒序，最多 300 条
  List<StorageFileInfo> _allInfos = [];

  /// 全量图片 key（含 .thumb 缩略图），用于推断 thumbUrl
  Set<String> _imageKeySet = {};

  bool _loading = true;

  /// 多选模式下已选中的图片 key
  final List<String> _selected = [];

  static const _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
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
    'lt100k': '< 100KB',
    'to1m': '100KB - 1MB',
    'to10m': '1MB - 10MB',
    'gt10m': '> 10MB',
  };

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void dispose() {
    _filterState.dispose();
    super.dispose();
  }

  bool _isImageExtension(String key) =>
      _imageExtensions.contains(path.extension(key).toLowerCase());

  /// 汇总应用存储内各目录的图片元信息，最近修改的在前
  Future<void> _loadImages() async {
    try {
      final infos = await globalStorage.listFileInfos('');

      final imageKeys = <String>{};
      final images = <StorageFileInfo>[];
      for (final info in infos) {
        // 统一正斜杠，屏蔽本地(Windows)与远端路径分隔符差异
        final key = info.path.replaceAll(r'\', '/');
        if (!_isImageExtension(key)) {
          continue;
        }
        imageKeys.add(key);
        if (!path.basename(key).contains('.thumb')) {
          images.add(StorageFileInfo(
            path: key,
            size: info.size,
            updatedAt: info.updatedAt,
          ));
        }
      }

      // 按修改时间倒序；无时间信息的排最后
      images.sort(
        (a, b) =>
            (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
      );

      // 上限保护，避免网格过大
      final limited =
          images.length > 300 ? images.sublist(0, 300) : images;

      if (mounted) {
        setState(() {
          _allInfos = limited;
          _imageKeySet = imageKeys;
        });
      }
    } catch (e) {
      debugPrint('加载图片列表失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 图片所属的顶层目录（插件维度），如 chat/chat_files/x.jpg -> chat
  String? _pluginDirOf(String key) {
    final index = key.indexOf('/');
    return index > 0 ? key.substring(0, index) : null;
  }

  /// 插件目录的显示标题：优先取插件翻译键 `<id>_name`
  /// （media_log 的键为 media_name），无翻译时回退目录名
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

  /// 应用过滤条件后的图片列表
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
          case 'lt100k':
            if (s >= 100 * _kb) return false;
          case 'to1m':
            if (s < 100 * _kb || s >= _mb) return false;
          case 'to10m':
            if (s < _mb || s >= 10 * _mb) return false;
          case 'gt10m':
            if (s < 10 * _mb) return false;
        }
      }

      return true;
    }).toList();
  }

  /// 压缩图片的伴生缩略图 key（存在时作为 thumbUrl 返回）
  String? _thumbUrlFor(String key) {
    final dir = path.dirname(key);
    final name = path.basenameWithoutExtension(key);
    final ext = path.extension(key);
    final thumbKey = '$dir/$name.thumb$ext';
    return _imageKeySet.contains(thumbKey) ? './$thumbKey' : null;
  }

  /// 点击网格内已有图片
  Future<void> _selectImage(String key) async {
    if (widget.multiple) {
      setState(() {
        _selected.contains(key) ? _selected.remove(key) : _selected.add(key);
      });
      return;
    }
    final bytes = await ImageUtils.readStorageBytes(key);
    if (mounted) {
      Navigator.of(context).pop(<String, dynamic>{
        'url': './$key',
        'thumbUrl': _thumbUrlFor(key),
        'bytes': bytes,
      });
    }
  }

  Future<void> _confirmMultiple() async {
    final results = <Map<String, dynamic>>[];
    for (final key in _selected) {
      final bytes = await ImageUtils.readStorageBytes(key);
      results.add({
        'url': './$key',
        'thumbUrl': _thumbUrlFor(key),
        'bytes': bytes,
      });
    }
    if (mounted) Navigator.of(context).pop(results);
  }

  /// 处理图片压缩和缩略图生成
  ///
  /// [savedImagePath] 保存后的图片绝对路径
  /// [relativePath] 相对路径
  /// 返回包含原图和缩略图信息的 Map
  Future<Map<String, dynamic>> _processImageCompression(
    String savedImagePath,
    String relativePath,
  ) async {
    if (!widget.enableCompression) {
      // 不压缩，直接返回原图
      return {'url': relativePath, 'thumbUrl': null};
    }

    try {
      // 生成缩略图路径
      String thumbPath;
      if (widget.thumbnailPath != null && widget.thumbnailPath!.isNotEmpty) {
        thumbPath = widget.thumbnailPath!;
      } else {
        // 默认在原文件名后加 .thumb
        final dir = path.dirname(savedImagePath);
        final filename = path.basenameWithoutExtension(savedImagePath);
        final ext = path.extension(savedImagePath);
        thumbPath = path.join(dir, '$filename.thumb$ext');
      }

      // 使用压缩服务生成缩略图
      final compressionService = ImageCompressionService();
      final compressedPath = await compressionService.compressImage(
        sourcePath: savedImagePath,
        targetPath: thumbPath,
        quality: widget.compressionQuality,
      );

      debugPrint('缩略图已生成: $compressedPath');

      // 压缩服务在不支持的平台会返回源路径而不生成文件；
      // heic 降级时输出路径扩展名也可能与 thumbPath 不同，统一以返回路径为准
      if (compressedPath == savedImagePath ||
          !await File(compressedPath).exists()) {
        debugPrint('缩略图未实际生成，跳过thumbUrl');
        return {'url': relativePath, 'thumbUrl': null};
      }

      // 计算缩略图的相对路径
      final thumbRelativePath = await ImageUtils.toRelativePath(compressedPath);

      return {'url': relativePath, 'thumbUrl': thumbRelativePath};
    } catch (e) {
      debugPrint('生成缩略图失败: $e');
      // 失败时返回原图
      return {'url': relativePath, 'thumbUrl': null};
    }
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
            if (widget.multiple) _buildConfirmBar(theme),
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
        // 无返回钮：底部弹窗通过下滑手势或点击遮罩关闭
        userLeading: null,
        automaticallyImplyLeading: false,
        automaticallyImplyTitle: false,
        previousPageTitle: null,
        userMiddle: Text(
          widget.multiple
              ? 'image_picker_selectMultipleImages'.tr
              : 'image_picker_selectImage'.tr,
          style: DsTypography.title.copyWith(color: theme.text),
        ),
        userTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DSIconButton(
              icon: DsIconKind.search,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              tooltip: 'image_picker_searchImage'.tr,
              onPressed: () => _showSearchSheet(),
            ),
            const SizedBox(width: 4),
            DSIconButton(
              icon: DsIconKind.camera,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              tooltip: 'image_picker_takePhoto'.tr,
              onPressed: () => _takePhoto(context),
            ),
            const SizedBox(width: 4),
            DSIconButton(
              icon: DsIconKind.link,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              tooltip: 'image_picker_onlineUrl'.tr,
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
        builder:
            (context) => _UrlInputSheet(initialUrl: widget.initialUrl),
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  /// 弹出图片搜索的二级底部弹窗（调用 scripts_center 的 image_search 脚本），
  /// 选中后连同主弹窗一起返回结果（与在线 URL 入口同构：{'url', 'bytes': null}）
  Future<void> _showSearchSheet() async {
    final result = await Navigator.of(context).push<dynamic>(
      ModalSheetRoute<dynamic>(
        swipeDismissible: true,
        builder: (context) => _ImageSearchSheet(multiple: widget.multiple),
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

  /// 在线 URL 输入由 [_showUrlSheet] 弹出的二级底部弹窗承载

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

    final images = _filteredInfos;

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
            itemCount: images.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _buildAlbumTile(theme);
              return _buildImageTile(theme, images[index - 1]);
            },
          ),
        ),
        if (images.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.xl),
            child: Text(
              _allInfos.isEmpty
                  ? 'image_picker_noImages'.tr
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

  Widget _buildImageTile(AppThemeData theme, StorageFileInfo info) {
    final key = info.path;
    final isSelected = _selected.contains(key);
    final selectedIndex = _selected.indexOf(key) + 1;

    return GestureDetector(
      onTap: () => _selectImage(key),
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
              Image(
                image: ImageUtils.createImageProvider('./$key'),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) => Container(
                      color: theme.stroke,
                      child: Center(
                        child: DsIcon(
                          DsIconKind.image,
                          size: 22,
                          color: theme.textSub,
                        ),
                      ),
                    ),
              ),
              if (widget.multiple)
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
                      child: Text(
                        '$selectedIndex',
                        style: DsTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmBar(AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
      child: Row(
        children: [
          Text(
            _selected.isEmpty
                ? ''
                : 'image_picker_selected'.trParams({
                  'n': '${_selected.length}',
                }),
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          const Spacer(),
          DSButton(
            label: 'app_confirm'.tr,
            size: DSButtonSize.sm,
            onPressed: _selected.isEmpty ? null : _confirmMultiple,
          ),
        ],
      ),
    );
  }

  /// 移动端：wechat_assets_picker 相册选图
  Future<void> _pickFromAssetPicker(BuildContext context) async {
    try {
      final entities = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          requestType: RequestType.image,
          maxAssets: widget.multiple ? 30 : 1,
        ),
      );
      if (entities == null || entities.isEmpty) {
        debugPrint('用户未选择相册图片');
        return;
      }

      final images = <XFile>[];
      for (final entity in entities) {
        final file = await entity.originFile ?? await entity.file;
        if (file != null) {
          images.add(XFile(file.path));
        }
      }
      await _processSelectedImages(context, images);
    } catch (e) {
      debugPrint('相册选择发生异常: $e');
      if (context.mounted) {
        Toast.error('${'image_picker_selectImageFailed'.tr}: $e');
      }
    }
  }

  /// 桌面端/Web：系统文件选择
  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      debugPrint('开始选择图片...');
      final List<XFile> images =
          widget.multiple
              ? (await _picker.pickMultiImage())
              : [
                await _picker.pickImage(source: ImageSource.gallery),
              ].whereType<XFile>().toList();

      debugPrint('图片选择完成，数量: ${images.length}');
      await _processSelectedImages(context, images);
    } catch (e, stackTrace) {
      debugPrint('选择图片发生异常: $e');
      debugPrint('异常堆栈: $stackTrace');
      if (context.mounted) {
        Toast.error('${'image_picker_selectImageFailed'.tr}: $e');
      }
    }
  }

  /// 拍照
  Future<void> _takePhoto(BuildContext context) async {
    try {
      debugPrint('开始调用相机...');
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      debugPrint('相机调用完成: ${photo != null}');

      if (photo == null) {
        debugPrint('用户取消拍照');
        return;
      }
      await _processSelectedImages(context, [photo]);
    } catch (e, stackTrace) {
      debugPrint('拍照过程发生异常: $e');
      debugPrint('异常堆栈: $stackTrace');
      if (context.mounted) {
        Toast.error('${'image_picker_takePhotoFailed'.tr}: $e');
      }
    }
  }

  /// 统一处理选中的图片：保存 → 裁剪(可选) → 压缩缩略图 → 返回结果
  Future<void> _processSelectedImages(
    BuildContext context,
    List<XFile> images,
  ) async {
    try {
      if (images.isEmpty) {
        debugPrint('用户未选择图片');
        return;
      }

      final results = <Map<String, dynamic>>[];

      for (final image in images) {
        try {
          debugPrint('处理图片: ${image.path}');

          // 保存图片并获取相对路径
          final relativePath = await ImageUtils.saveImage(
            File(image.path),
            widget.saveDirectory,
          );
          debugPrint('图片保存完成，相对路径: $relativePath');

          // 获取保存后的文件路径
          final savedImagePath = await ImageUtils.getAbsolutePath(
            relativePath,
          );
          final savedImage = File(savedImagePath);

          // 确认文件是否成功保存
          final fileExists = await savedImage.exists();
          debugPrint('图片保存路径: $savedImagePath, 文件是否存在: $fileExists');

          if (!fileExists) {
            throw Exception('文件保存后检查不存在: $savedImagePath');
          }

          // 读取图片字节数据
          final bytes = await File(image.path).readAsBytes();
          debugPrint('图片字节大小: ${bytes.length}');

          // 如果启用了裁剪功能，显示裁剪对话框
          if (widget.enableCrop && context.mounted) {
            debugPrint('启用裁剪，显示裁剪对话框...');
            final result = await _showCropDialog(
              context,
              bytes,
              savedImage.path,
              relativePath,
            );
            if (result != null) {
              debugPrint('裁剪完成');
              results.add(result);
            } else {
              debugPrint('裁剪被取消');
            }
          } else {
            debugPrint('处理压缩和缩略图...');
            // 处理压缩和缩略图
            final compressionResult = await _processImageCompression(
              savedImagePath,
              relativePath,
            );
            debugPrint('压缩结果: ${compressionResult.keys}');
            results.add({...compressionResult, 'bytes': bytes});
          }
        } catch (e) {
          debugPrint('处理单张图片时发生错误: $e');
          rethrow;
        }
      }

      debugPrint('所有图片处理完成，结果数量: ${results.length}');
      if (results.isNotEmpty && context.mounted) {
        final result = widget.multiple ? results : results.first;
        debugPrint('返回结果，类型: ${widget.multiple ? "多张" : "单张"}');
        Navigator.of(context).pop(result);
      } else {
        debugPrint('警告: 结果为空或上下文未挂载');
      }
    } catch (e) {
      debugPrint('处理图片发生异常: $e');
      if (context.mounted) {
        Toast.error('${'image_picker_selectImageFailed'.tr}: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> _showCropDialog(
    BuildContext context,
    Uint8List imageBytes,
    String originalImagePath,
    String originalRelativePath,
  ) async {
    final cropController = CropController();
    final completer = Completer<Map<String, dynamic>?>();

    if (!context.mounted) {
      return null;
    }

    await showDSDialog<void>(
      context: context,
      barrierDismissible: false,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) {
        final theme = DSThemeBridge.resolve(dialogContext);
        return JellyBox(
          radius: theme.radii.xxl,
          constraints: const BoxConstraints(maxWidth: 360),
          padding: EdgeInsets.all(theme.spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'image_picker_cropImage'.tr,
                style: DsTypography.title.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.md),
              SizedBox(
                width: 300,
                height: 300,
                child: ClipRRect(
                  borderRadius: theme.radii.lg,
                  child: Crop(
                    controller: cropController,
                    image: imageBytes,
                    aspectRatio: widget.cropAspectRatio,
                    onCropped: (result) async {
                      switch (result) {
                        case CropSuccess(:final croppedImage):
                          try {
                            final originalFile = File(originalImagePath);
                            if (await originalFile.exists()) {
                              await originalFile.delete();
                            }

                            final relativePath =
                                await ImageUtils.saveBytesToAppDirectory(
                                  croppedImage,
                                  widget.saveDirectory,
                                );

                            // 处理压缩和缩略图
                            final savedImagePath =
                                await ImageUtils.getAbsolutePath(relativePath);
                            final compressionResult =
                                await _processImageCompression(
                                  savedImagePath,
                                  relativePath,
                                );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                              completer.complete({
                                ...compressionResult,
                                'bytes': croppedImage,
                              });
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              Toast.error(
                                'image_picker_saveCroppedImageFailed'.tr,
                              );
                            }
                            completer.complete(null);
                          }
                        case CropFailure():
                          if (dialogContext.mounted) {
                            Toast.error('image_picker_cropFailed'.tr);
                          }
                          completer.complete(null);
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: theme.spacing.md),
              Row(
                children: [
                  Expanded(
                    child: DSButton(
                      label: 'app_cancel'.tr,
                      variant: DSButtonVariant.outline,
                      size: DSButtonSize.sm,
                      onPressed: () async {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        final relativePath = await ImageUtils.getAbsolutePath(
                          originalImagePath,
                        );
                        completer.complete({
                          'url': relativePath,
                          'bytes': imageBytes,
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DSButton(
                      label: 'app_confirm'.tr,
                      size: DSButtonSize.sm,
                      onPressed: () => cropController.crop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    return completer.future;
  }
}

/// 在线 URL 输入的二级底部弹窗
///
/// 确认时 pop `{'url', 'bytes': null}`，取消/下滑 pop null；
/// 主弹窗收到结果后再以相同结果 pop 交给调用方。
class _UrlInputSheet extends StatefulWidget {
  final String? initialUrl;

  const _UrlInputSheet({this.initialUrl});

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
    _controller = TextEditingController(text: widget.initialUrl);
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
              'image_picker_onlineUrl'.tr,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
            SizedBox(height: theme.spacing.md),
            DSInput(
              controller: _controller,
              label: 'image_picker_onlineUrl'.tr,
              hint: 'https://...',
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

/// 图片搜索的二级底部弹窗
///
/// 调用 scripts_center 的 image_search 内置脚本按关键词搜网络图片（图源可选），
/// 选中单张 pop `{'url', 'bytes': null}`（与在线 URL 入口同构）；
/// multiple 时多选，确认后 pop 同结构列表。
/// 缩略图直连各引擎 CDN（无代理），加载失败时显示占位图标。
class _ImageSearchSheet extends StatefulWidget {
  final bool multiple;

  const _ImageSearchSheet({this.multiple = false});

  @override
  State<_ImageSearchSheet> createState() => _ImageSearchSheetState();
}

class _ImageSearchSheetState extends State<_ImageSearchSheet> {
  /// 图源选项（与 image_search 脚本的 provider 选项保持一致）
  static const _providers = [
    'unsplash',
    'pixabay',
    'google',
    'bing',
    'yahoo',
    'yandex',
  ];

  static const _scriptId = 'image_search';

  late final TextEditingController _controller;
  String _provider = 'unsplash';
  bool _searching = false;
  bool _searched = false;
  String? _error;
  List<Map> _images = [];

  /// 多选模式下已选中的图片下标
  final List<int> _selected = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _searching) return;

    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await ScriptsCenterPlugin
          .instance
          .scriptExecutor
          .execute(
            _scriptId,
            args: {
              'query': query,
              'provider': _provider,
              'perPage': 30,
              // 内嵌场景不弹脚本自带的结果页，仅取返回数据
              'showUi': false,
            },
          );
      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _images = [];
          _selected.clear();
          _searched = true;
          _error = result.error ?? 'image_picker_searchFailed'.tr;
        });
        return;
      }
      // 脚本返回值：{success, message, data: {images: [{url, thumb, ...}]}}
      final data = result.result is Map ? (result.result as Map)['data'] : null;
      final images =
          (data is Map && data['images'] is List)
              ? (data['images'] as List).whereType<Map>().toList()
              : <Map>[];
      setState(() {
        _images = images;
        _selected.clear();
        _searched = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _images = [];
          _selected.clear();
          _searched = true;
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onTapImage(int index) {
    final url = _images[index]['url'] as String? ?? '';
    if (url.isEmpty) return;
    if (!widget.multiple) {
      Navigator.of(context).pop(<String, dynamic>{'url': url, 'bytes': null});
      return;
    }
    setState(() {
      _selected.contains(index)
          ? _selected.remove(index)
          : _selected.add(index);
    });
  }

  void _confirmMultiple() {
    final results = <Map<String, dynamic>>[
      for (final i in _selected)
        if ((_images[i]['url'] as String? ?? '').isNotEmpty)
          {'url': _images[i]['url'], 'bytes': null},
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: theme.spacing.lg),
            Text(
              'image_picker_searchImage'.tr,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
            SizedBox(height: theme.spacing.md),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: DSInput(
                      controller: _controller,
                      hint: 'image_picker_searchHint'.tr,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DSButton(
                    label: 'image_picker_search'.tr,
                    size: DSButtonSize.sm,
                    onPressed: _searching ? null : _search,
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            // 图源横滑选择
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
                children: [
                  for (final p in _providers)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DSChip(
                        label: p,
                        selected: _provider == p,
                        onSelected:
                            (_) => setState(() => _provider = p),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            SizedBox(height: screenHeight * 0.5, child: _buildBody(theme)),
            if (widget.multiple) _buildConfirmBar(theme),
            SafeArea(top: false, child: SizedBox(height: theme.spacing.sm)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppThemeData theme) {
    if (_searching) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
          child: Text(
            '${'image_picker_searchFailed'.tr}\n$_error',
            textAlign: TextAlign.center,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ),
      );
    }
    if (_images.isEmpty) {
      return Center(
        child: Text(
          _searched
              ? 'image_picker_searchEmpty'.tr
              : 'image_picker_searchHint'.tr,
          style: DsTypography.caption.copyWith(color: theme.textSub),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) => _buildResultTile(theme, index),
    );
  }

  Widget _buildResultTile(AppThemeData theme, int index) {
    final img = _images[index];
    final thumb = (img['thumb'] as String? ?? '').isNotEmpty
        ? img['thumb'] as String
        : img['url'] as String? ?? '';
    final isSelected = _selected.contains(index);
    final selectedIndex = _selected.indexOf(index) + 1;

    return GestureDetector(
      onTap: () => _onTapImage(index),
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
              Image.network(
                thumb,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, _, _) => Container(
                      color: theme.stroke,
                      child: Center(
                        child: DsIcon(
                          DsIconKind.image,
                          size: 22,
                          color: theme.textSub,
                        ),
                      ),
                    ),
              ),
              if (widget.multiple)
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
                          isSelected
                              ? null
                              : Border.all(color: Colors.white70),
                    ),
                    child: Center(
                      child: Text(
                        '$selectedIndex',
                        style: DsTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmBar(AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
      child: Row(
        children: [
          Text(
            _selected.isEmpty
                ? ''
                : 'image_picker_selected'.trParams({
                  'n': '${_selected.length}',
                }),
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          const Spacer(),
          DSButton(
            label: 'app_confirm'.tr,
            size: DSButtonSize.sm,
            onPressed: _selected.isEmpty ? null : _confirmMultiple,
          ),
        ],
      ),
    );
  }
}
