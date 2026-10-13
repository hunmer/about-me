import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/plugins/calendar_album/screens/entry_detail_screen.dart';
import 'package:aboutme/plugins/calendar_album/screens/entry_editor_screen.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:provider/provider.dart';
import 'package:skribble/skribble.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:io';
import 'package:aboutme/plugins/calendar_album/controllers/calendar_controller.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// 照片与其所属日记条目的关联记录（过滤/排序/搜索均基于条目元数据）
class _PhotoRecord {
  final String url;
  final CalendarEntry entry;

  const _PhotoRecord({required this.url, required this.entry});
}

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, this.initialTags});

  /// 初始标签过滤（如从标签文件夹进入）
  final List<String>? initialTags;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  // 多条件过滤参数
  Map<String, dynamic> _multiFilters = {};
  String _searchQuery = '';
  String _sortBy = 'newest'; // newest, oldest

  @override
  void initState() {
    super.initState();
    final initialTags = widget.initialTags;
    if (initialTags != null && initialTags.isNotEmpty) {
      _multiFilters = {'tags': List<String>.from(initialTags)};
    }
  }

  /// 上次路由上下文记录的照片数，避免每次 build 重复更新
  int? _lastContextCount;

  /// 心情/天气存储值转显示文案：优先取翻译键，缺失时回退原值
  /// （历史数据可能直接存中文或 emoji）
  String _enumLabel(String kind, String value) {
    final key = 'calendar_album_${kind}_${value.toLowerCase()}';
    final label = key.tr;
    return label == key ? value : label;
  }

  /// 收集日记条目中实际出现的心情/天气取值
  List<String> _getDistinctEntryValues(
    CalendarController controller,
    String? Function(CalendarEntry) pick,
  ) {
    final values = <String>{};
    for (final entries in controller.entries.values) {
      for (final entry in entries) {
        final value = pick(entry);
        if (value != null && value.isNotEmpty) values.add(value);
      }
    }
    return values.toList()..sort();
  }

  /// 构建照片记录列表（按日记日期倒序，同一条目的 imageUrls + markdown 内联图）
  List<_PhotoRecord> _buildPhotoRecords(CalendarController controller) {
    final records = <_PhotoRecord>[];
    final seen = <String>{};
    final dates = controller.entries.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final date in dates) {
      final entries = controller.entries[date]!;
      final sorted = List<CalendarEntry>.from(entries)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (final entry in sorted) {
        final urls = [...entry.imageUrls, ...entry.extractImagesFromMarkdown()];
        for (final url in urls) {
          if (url.isEmpty || !seen.add(url)) continue;
          records.add(_PhotoRecord(url: url, entry: entry));
        }
      }
    }
    return records;
  }

  /// 构建多条件过滤项
  List<FilterItem> _buildFilterItems(CalendarController controller) {
    final availableTags = controller.getAllTags();
    final moods = _getDistinctEntryValues(controller, (e) => e.mood);
    final weathers = _getDistinctEntryValues(controller, (e) => e.weather);

    return [
      // 1. 标签多选
      if (availableTags.isNotEmpty)
        FilterItem(
          id: 'tags',
          title: 'calendar_album_tag'.tr,
          type: FilterType.tagsMultiple,
          initialValue: widget.initialTags,
          builder: (context, currentValue, onChanged) {
            return FilterBuilders.buildTagsFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              availableTags: availableTags,
            );
          },
          getBadge: FilterBuilders.tagsBadge,
        ),

      // 2. 日期范围（按日记创建日期过滤）
      FilterItem(
        id: 'dateRange',
        title: 'calendar_album_date_range'.tr,
        type: FilterType.dateRange,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildDateRangeFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
          );
        },
        getBadge: FilterBuilders.dateRangeBadge,
      ),

      // 3. 心情单选
      if (moods.isNotEmpty)
        FilterItem(
          id: 'mood',
          title: 'calendar_album_mood'.tr,
          type: FilterType.tagsSingle,
          builder: (context, currentValue, onChanged) {
            return _buildEnumSingleFilter(
              values: moods,
              labelOf: (v) => _enumLabel('mood', v),
              currentValue: currentValue,
              onChanged: onChanged,
            );
          },
          getBadge: (value) => value is String ? _enumLabel('mood', value) : null,
        ),

      // 4. 天气单选
      if (weathers.isNotEmpty)
        FilterItem(
          id: 'weather',
          title: 'calendar_album_weather'.tr,
          type: FilterType.tagsSingle,
          builder: (context, currentValue, onChanged) {
            return _buildEnumSingleFilter(
              values: weathers,
              labelOf: (v) => _enumLabel('weather', v),
              currentValue: currentValue,
              onChanged: onChanged,
            );
          },
          getBadge: (value) =>
              value is String ? _enumLabel('weather', value) : null,
        ),
    ];
  }

  /// 枚举单选过滤器（心情/天气）：选中后自动返回第一层
  Widget _buildEnumSingleFilter({
    required List<String> values,
    required String Function(String) labelOf,
    required dynamic currentValue,
    required FilterItemChanged onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          DSChip(
            label: labelOf(value),
            selected: currentValue == value,
            onSelected: (selected) =>
                onChanged(selected ? value : null, done: true),
          ),
      ],
    );
  }

  /// 应用多条件过滤
  void _applyMultiFilters(Map<String, dynamic> filters) {
    // 使用 addPostFrameCallback 避免在 build 阶段调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _multiFilters = filters;
        });
      }
    });
  }

  /// 检查照片是否通过所有多条件过滤（基于所属日记条目）
  bool _passesMultiFilters(_PhotoRecord record) {
    final entry = record.entry;

    // 1. 标签过滤（任一命中即通过）
    final selectedTags = _multiFilters['tags'];
    if (selectedTags is List && selectedTags.isNotEmpty) {
      final hasAnyTag = entry.tags.any((tag) => selectedTags.contains(tag));
      if (!hasAnyTag) return false;
    }

    // 2. 日期范围过滤（按日记创建日期）
    final range = _multiFilters['dateRange'];
    if (range is DateTimeRange) {
      final end = range.end.add(const Duration(days: 1));
      if (entry.createdAt.isBefore(range.start) || entry.createdAt.isAfter(end)) {
        return false;
      }
    }

    // 3. 心情过滤
    final mood = _multiFilters['mood'];
    if (mood is String && entry.mood != mood) return false;

    // 4. 天气过滤
    final weather = _multiFilters['weather'];
    if (weather is String && entry.weather != weather) return false;

    return true;
  }

  /// 搜索匹配：日记标题/标签/内容
  bool _matchesSearch(_PhotoRecord record) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    final entry = record.entry;
    if (entry.title.toLowerCase().contains(query)) return true;
    if (entry.tags.any((tag) => tag.toLowerCase().contains(query))) return true;
    if (entry.content.toLowerCase().contains(query)) return true;
    return false;
  }

  /// 数据链路：原始列表 → 多条件过滤 → 排序 → 搜索
  List<_PhotoRecord> _getVisiblePhotos(List<_PhotoRecord> all) {
    var photos = all.where(_passesMultiFilters).toList();

    photos.sort((a, b) =>
        _sortBy == 'oldest'
            ? a.entry.createdAt.compareTo(b.entry.createdAt)
            : b.entry.createdAt.compareTo(a.entry.createdAt));

    if (_searchQuery.isNotEmpty) {
      photos = photos.where(_matchesSearch).toList();
    }
    return photos;
  }

  /// 排序按钮（多条件过滤栏尾部，DSPopover 经根 Overlay 展示需 DSThemeBridge 包裹）
  Widget _buildSortButton() {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return DSPopover(
            width: 160,
            contentBuilder: (popoverContext, close) {
              final popoverTheme = DSThemeBridge.resolve(popoverContext);
              Widget menuRow(String value, String label) {
                return Pressable(
                  onPressed: () {
                    close();
                    setState(() => _sortBy = value);
                  },
                  builder: (context, states) {
                    final pressed = states.contains(WidgetState.pressed);
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: popoverTheme.spacing.sm,
                        vertical: popoverTheme.spacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: pressed ? popoverTheme.surfaceAlt : null,
                        borderRadius: popoverTheme.radii.sm,
                      ),
                      child: Row(
                        children: [
                          DsIcon(
                            _sortBy == value ? DsIconKind.check : DsIconKind.sort,
                            size: 18,
                            color: popoverTheme.text,
                          ),
                          SizedBox(width: popoverTheme.spacing.sm),
                          Text(
                            label,
                            style: DsTypography.body.copyWith(
                              color: popoverTheme.text,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  menuRow('newest', 'calendar_album_sort_newest'.tr),
                  menuRow('oldest', 'calendar_album_sort_oldest'.tr),
                ],
              );
            },
            child: JellyBox(
              width: 36,
              height: 36,
              radius: theme.radii.circle,
              color: theme.surfaceAlt,
              child: Center(
                child: DsIcon(
                  DsIconKind.sort,
                  size: 18,
                  color: theme.textSub,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到相册信息
  void _updateRouteContext(int photoCount) {
    if (_lastContextCount == photoCount) return;
    _lastContextCount = photoCount;
    RouteHistoryManager.updateCurrentContext(
      pageId: '/calendar_album_album',
      title: 'calendar_album_route_title_album'.trParams({
        'count': photoCount.toString(),
      }),
      params: {
        'photoCount': photoCount.toString(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarController>(
      builder: (context, calendarController, child) {
        final allPhotos = _buildPhotoRecords(calendarController);
        final photos = _getVisiblePhotos(allPhotos);

        _updateRouteContext(allPhotos.length);

        return SuperCupertinoNavigationWrapper(
          // tab 内嵌页：嵌套 wrapper 必须关闭路由 hero 转场，避免 Hero tag 冲突
          transitionBetweenRoutes: false,
          title: Text('${'calendar_album_all_photos'.tr} (${photos.length})'),
          largeTitle: 'calendar_album_all_photos'.tr,
          enableLargeTitle: true,
          // ===== 搜索 =====
          enableSearchBar: true,
          searchPlaceholder: 'calendar_album_search_photos_placeholder'.tr,
          onSearchChanged: (query) {
            setState(() => _searchQuery = query);
          },
          // ===== 多条件过滤 =====
          enableMultiFilter: true,
          multiFilterItems: _buildFilterItems(calendarController),
          onMultiFilterChanged: _applyMultiFilters,
          multiFilterBarTrailing: _buildSortButton(),
          body: photos.isEmpty
              ? Center(
                  child: DSThemeBridge(
                    child: DSEmptyState(
                      emoji: allPhotos.isEmpty ? '📷' : '🔍',
                      title: allPhotos.isEmpty
                          ? 'calendar_album_no_photos'.tr
                          : 'calendar_album_no_matching_photos'.tr,
                      message: allPhotos.isEmpty
                          ? null
                          : 'calendar_album_try_other_keywords'.tr,
                    ),
                  ),
                )
              : MasonryGridView.count(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final record = photos[index];
                    void openViewer() {
                      NavigationHelper.push(
                        context,
                        _PhotoViewScreen(
                          images: photos.map((r) => r.url).toList(),
                          initialIndex: index,
                        ),
                      );
                    }

                    void editEntry() {
                      NavigationHelper.push<void>(
                        context,
                        MultiProvider(
                          providers: [
                            ChangeNotifierProvider<CalendarController>.value(
                              value: calendarController,
                            ),
                            ChangeNotifierProvider<TagController>.value(
                              value: context.read<TagController>(),
                            ),
                          ],
                          child: EntryEditorScreen(
                            entry: record.entry,
                            isEditing: true,
                          ),
                        ),
                      );
                    }

                    return ArcContextMenu(
                      onTap: openViewer,
                      preview: _PhotoCell.buildPlainImage(
                        context,
                        record.url,
                      ),
                      items: [
                        ArcMenuItem(
                          icon: DsIconKind.image,
                          label: 'calendar_album_view_photo'.tr,
                          onTap: openViewer,
                        ),
                        ArcMenuItem(
                          icon: DsIconKind.edit,
                          label: 'calendar_album_edit_entry'.tr,
                          onTap: editEntry,
                        ),
                      ],
                      child: _PhotoCell(imageUrl: record.url),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// 拍立得式照片格：随机微旋转 + 墨线描边纸框 + 圆角 + contain 完整显示，
/// 挂载时入场放大（easeOutBack）并描画墨线（WiredDraw）
class _PhotoCell extends StatefulWidget {
  const _PhotoCell({required this.imageUrl});

  final String imageUrl;

  @override
  State<_PhotoCell> createState() => _PhotoCellState();

  /// 无框纯图渲染（ArcContextMenu.preview 复用）。
  /// 在瀑布流的无限高约束下由 Image 按固有比例撑高度，contain 无留白；
  /// 占位兜底 1:1，避免图片未解码时格子高度塌陷
  static Widget buildPlainImage(BuildContext context, String imageUrl) {
    final theme = DSThemeBridge.resolve(context);

    Widget placeholder() => AspectRatio(
      aspectRatio: 1,
      child: Container(
        color: theme.backgroundAlt,
        alignment: Alignment.center,
        child: DsIcon(DsIconKind.image, size: 28, color: theme.textSub),
      ),
    );

    if (imageUrl.isEmpty) return placeholder();

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading network image: $error');
          return placeholder();
        },
      );
    }
    return FutureBuilder<String>(
      future: ImageUtils.getAbsolutePath(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final file = File(snapshot.data!);
          if (file.existsSync()) {
            return Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading local image: $error');
                return placeholder();
              },
            );
          }
        }
        return placeholder();
      },
    );
  }
}

class _PhotoCellState extends State<_PhotoCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  /// 0.6 → 1，easeOutBack 轻微过冲的果冻感
  late final Animation<double> _scale = Tween<double>(
    begin: 0.6,
    end: 1.0,
  ).animate(_scaleController.drive(CurveTween(curve: Curves.easeOutBack)));

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 遵守 WiredMotion 边界与系统"减弱动态效果"：禁用时跳过入场
    if (!WiredMotion.enabledOf(context)) {
      _scaleController.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _scaleController.forward();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  /// 图片 url 哈希 → ±1 确定性随机值：过滤/排序重排后同图角度不变
  static double _unitRandom(String source) {
    final h = source.hashCode & 0x7fffffff;
    return (h % 1000 - 500) / 500;
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final angle = _unitRandom(widget.imageUrl) * 0.045; // ±2.6° 微旋转
    final seed = widget.imageUrl.hashCode & 0x7fffffff;

    // WiredDraw 让纸框墨线在挂载时描画出来，与放大入场同步
    return WiredDraw(
      duration: const Duration(milliseconds: 500),
      child: ScaleTransition(
        scale: _scale,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            // 纸边：墨线框与照片之间的留白（描边贴容器边界，padding 只作用于内容）
            padding: const EdgeInsets.all(7),
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: theme.paper,
              radius: BorderRadius.circular(14),
              seed: seed,
              progress: WiredDrawTransition.progressOf(context),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Hero(
                tag: widget.imageUrl,
                child: _PhotoCell.buildPlainImage(context, widget.imageUrl),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoViewScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _PhotoViewScreen({required this.images, required this.initialIndex});

  @override
  State<_PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<_PhotoViewScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.note),
            onPressed: () {
              final currentImage =
                  widget.images[_pageController.page?.round() ??
                      widget.initialIndex];
              final entry = Provider.of<CalendarController>(
                context,
                listen: false,
              ).getDiaryEntryForImage(currentImage);
              if (entry != null) {
                NavigationHelper.push(context, EntryDetailScreen(entry: entry),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: PhotoViewGallery.builder(
          itemCount: widget.images.length,
          builder: (context, index) {
            return PhotoViewGalleryPageOptions.customChild(
              child: FutureBuilder<String>(
                future: ImageUtils.getAbsolutePath(widget.images[index]),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    final file = File(snapshot.data!);
                    if (file.existsSync()) {
                      return Image.file(file, fit: BoxFit.contain);
                    }
                  }
                  return Image.asset(
                    'assets/images/image_not_found.png',
                    fit: BoxFit.contain,
                  );
                },
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              initialScale: PhotoViewComputedScale.contained,
              heroAttributes: PhotoViewHeroAttributes(
                tag: widget.images[index],
              ),
            );
          },
          scrollPhysics: const NeverScrollableScrollPhysics(),
          pageController: _pageController,
          loadingBuilder:
              (context, event) => Center(
                child: CircularProgressIndicator(
                  value:
                      event == null || event.expectedTotalBytes == null
                          ? 0
                          : event.cumulativeBytesLoaded /
                              event.expectedTotalBytes!,
                  color: Colors.white,
                ),
              ),
        ),
      ),
    );
  }
}
