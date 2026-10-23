part of 'image_picker_dialog.dart';

/// 相册网格（按功能从主文件拆出）：
/// 应用存储图片加载 / 多条件过滤（插件/日期/大小） / 网格与磁贴 /
/// 长按菜单（编辑/删除/多选） / 多选确认栏
extension _ImagePickerDialogAlbumExt on _ImagePickerDialogState {
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

  bool _isImageExtension(String key) =>
      _imageExtensions.contains(path.extension(key).toLowerCase());

  /// 汇总应用存储内各目录的图片元信息，最近修改的在前
  Future<void> _loadImages() async {
    try {
      final infos = [
        ...await globalStorage.listFileInfos(''),
        ...await SdkMediaService.listMedia('image/'),
      ];

      final imageKeys = <String>{};
      final images = <StorageFileInfo>[];
      for (final info in infos) {
        // 统一正斜杠，屏蔽本地(Windows)与远端路径分隔符差异
        final key = info.path.replaceAll(r'\', '/');
        if (ImageUtils.sdkAssetId(key) == null && !_isImageExtension(key)) {
          continue;
        }
        imageKeys.add(key);
        if (!path.basename(key).contains('.thumb')) {
          images.add(
            StorageFileInfo(
              path: key,
              size: info.size,
              updatedAt: info.updatedAt,
            ),
          );
        }
      }

      // 按修改时间倒序；无时间信息的排最后
      images.sort(
        (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );

      // 上限保护，避免网格过大
      final limited = images.length > 300 ? images.sublist(0, 300) : images;

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
    if (ImageUtils.sdkAssetId(key) != null) return null;
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
    if (ImageUtils.sdkAssetId(key) != null) return null;
    final dir = path.dirname(key);
    final name = path.basenameWithoutExtension(key);
    final ext = path.extension(key);
    final thumbKey = '$dir/$name.thumb$ext';
    return _imageKeySet.contains(thumbKey) ? './$thumbKey' : null;
  }

  /// 点击网格内已有图片
  Future<void> _selectImage(String key) async {
    if (_multiple) {
      setState(() {
        _selected.contains(key) ? _selected.remove(key) : _selected.add(key);
      });
      return;
    }
    final bytes = await ImageUtils.readStorageBytes(key);
    if (mounted) {
      Navigator.of(context).pop(<String, dynamic>{
        'url': ImageUtils.sdkAssetId(key) != null ? key : './$key',
        'thumbUrl': _thumbUrlFor(key),
        'bytes': bytes,
      });
    }
  }

  /// 取消多选：退回单选模式并清空已选
  void _cancelMultiple() {
    setState(() {
      _multiple = false;
      _selected.clear();
    });
  }

  Future<void> _confirmMultiple() async {
    final results = <Map<String, dynamic>>[];
    for (final key in _selected) {
      final bytes = await ImageUtils.readStorageBytes(key);
      results.add({
        'url': ImageUtils.sdkAssetId(key) != null ? key : './$key',
        'thumbUrl': _thumbUrlFor(key),
        'bytes': bytes,
      });
    }
    if (mounted) Navigator.of(context).pop(results);
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
        onTap: () => isMobile
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

    // 点击选图；长按弹菜单（编辑 / 删除）
    return GestureDetector(
      onTap: () => _selectImage(key),
      child: DSPopover(
        activateOnLongPress: true,
        width: 168,
        contentBuilder: (popoverContext, close) =>
            _imageMenu(popoverContext, close, [key]),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: theme.radii.md,
            border: isSelected
                ? Border.all(color: theme.primary, width: 2)
                : null,
          ),
          child: ClipRRect(
            borderRadius: theme.radii.md,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: ImageUtils.createImageProvider('./$key'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
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
                if (_multiple)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? theme.primary
                            : Colors.black.withValues(alpha: 0.25),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.white70),
                      ),
                      child: Center(
                        // 未选中时角标为空圈，不显示序号（避免 indexOf(-1)+1 显示 0）
                        child: isSelected
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
      ),
    );
  }

  /// 图片长按 / 多选 dots 菜单：编辑图片（批量进编辑器）/ 删除图片
  Widget _imageMenu(
    BuildContext popoverContext,
    VoidCallback close,
    List<String> keys,
  ) {
    final theme = DSThemeBridge.resolve(popoverContext);
    final batch = keys.length > 1;

    Widget menuRow(
      String label,
      DsIconKind icon,
      VoidCallback onTap, {
      Color? color,
    }) {
      return Pressable(
        onPressed: () {
          close();
          onTap();
        },
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm,
            ),
            color: pressed ? theme.surfaceAlt.withValues(alpha: 0.7) : null,
            child: Row(
              children: [
                DsIcon(icon, size: 18, color: color ?? theme.text),
                SizedBox(width: theme.spacing.sm),
                Text(
                  label,
                  style: DsTypography.body.copyWith(color: color ?? theme.text),
                ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 单选模式下的单张菜单提供"多选"入口（原长按切多选由菜单承接）
        if (!batch && !_multiple)
          menuRow(
            'image_picker_multiSelect'.tr,
            DsIconKind.check,
            () => setState(() {
              _multiple = true;
              _selected.addAll(keys);
            }),
          ),
        menuRow(
          batch
              ? '${'image_picker_editImage'.tr} (${keys.length})'
              : 'image_picker_editImage'.tr,
          DsIconKind.edit,
          () => _editImages(keys),
        ),
        menuRow(
          'image_picker_deleteImage'.tr,
          DsIconKind.trash,
          () => _deleteImages(keys),
          color: theme.danger,
        ),
      ],
    );
  }

  /// 编辑图片：单张直接进编辑器，多张批量进（缩略图条切换）；
  /// 资源图写回原引用；旧目录图片没有可写回的稳定引用，
  /// 编辑产物保存为新资源，完成后失效缓存并刷新网格
  Future<void> _editImages(List<String> keys) async {
    final urls = [
      for (final k in keys) ImageUtils.sdkAssetId(k) != null ? k : './$k',
    ];
    if (urls.length == 1) {
      await showPhotoEditor(
        context,
        imageUrl: urls.first,
        savePath: ImageUtils.sdkAssetId(keys.first) != null ? urls.first : null,
      );
    } else {
      await showPhotoEditorList(
        context,
        items: [
          for (var i = 0; i < urls.length; i++)
            PhotoEditorItem(
              url: urls[i],
              savePath: ImageUtils.sdkAssetId(keys[i]) != null ? urls[i] : null,
            ),
        ],
      );
    }
    for (final u in urls) {
      try {
        await ImageUtils.createImageProvider(u).evict();
      } catch (_) {}
    }
    if (mounted) _loadImages();
  }

  /// 删除图片（连同伴生缩略图），从网格与已选中移除
  Future<void> _deleteImages(List<String> keys) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('image_picker_deleteImage'.tr),
        content: Text(
          keys.length > 1
              ? 'image_picker_deleteBatchConfirm'.trParams({
                  'n': '${keys.length}',
                })
              : 'image_picker_deleteConfirm'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('app_cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('app_confirm'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleted = <String>[];
    for (final key in keys) {
      try {
        final id = ImageUtils.sdkAssetId(key);
        if (id == null) throw UnsupportedError('旧图片需要先迁移，暂不支持从资源库删除');
        await AboutmeDataService.instance.data.assets.remove(id);
        deleted.add(key);
      } catch (e) {
        debugPrint('删除图片失败: $key, $e');
        if (mounted) Toast.error('删除失败：$e');
      }
    }
    if (!mounted) return;
    setState(() {
      _allInfos.removeWhere((e) => deleted.contains(e.path));
      _imageKeySet.removeAll(deleted);
      _selected.removeWhere(deleted.contains);
    });
    if (deleted.isNotEmpty) Toast.success('image_picker_deleted'.tr);
  }

  /// 多选确认栏：左侧已选缩略图横滑条（右上 × 移除、长按拖拽排序）
  /// + 右侧 dots 菜单（批量编辑 / 删除）+ 确认按钮
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
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
          // 批量操作菜单：编辑全部已选 / 删除全部已选
          DSPopover(
            width: 168,
            contentBuilder: (popoverContext, close) =>
                _imageMenu(popoverContext, close, List<String>.of(_selected)),
            child: DSIconButton(
              icon: DsIconKind.dots,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              tooltip: 'image_picker_batchActions'.tr,
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

  /// 已选缩略图：右上 × 移除，左下序号（与网格勾选序号一致）
  Widget _buildSelectedThumb(
    AppThemeData theme,
    String key,
    int index, {
    required ValueKey<String> keyId,
  }) {
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
              child: Image(
                image: ImageUtils.createImageProvider('./$key'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: theme.stroke,
                  child: Center(
                    child: DsIcon(
                      DsIconKind.image,
                      size: 18,
                      color: theme.textSub,
                    ),
                  ),
                ),
              ),
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
          // 右上取消图标（点 × 移除该图）
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
}
