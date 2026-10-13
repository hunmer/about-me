import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';

import '../media_log_plugin.dart';
import '../models/media_item.dart';
import '../screens/media_detail_screen.dart';
import '../widgets/media_item_card.dart';
import '../widgets/media_item_form.dart';

/// 媒体记录列表页：瀑布流封面网格 + 多条件过滤 + 搜索 + 排序
///
/// UI 迁移自 ai_picks_demo 首页（双列错落瀑布流）。
class MediaListScreen extends StatefulWidget {
  const MediaListScreen({super.key});

  @override
  State<MediaListScreen> createState() => _MediaListScreenState();
}

class _MediaListScreenState extends State<MediaListScreen> {
  final Map<String, dynamic> _multiFilters = {};
  String _searchQuery = '';
  String _sortBy = 'default'; // default, title, rating, finished

  @override
  void initState() {
    super.initState();
    MediaLogPlugin.instance.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    MediaLogPlugin.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  List<String> _getAllTags() => MediaLogPlugin.instance.getAllTags();

  /// 构建多条件过滤项：类型 / 标签 / 评分 / 完成时间范围
  List<FilterItem> _buildFilterItems() {
    final kindOptions = {
      'reading': 'media_reading'.tr,
      'watching': 'media_watching'.tr,
    };
    final ratingOptions = {
      '3': 'media_rating3Plus'.tr,
      '4': 'media_rating4Plus'.tr,
    };
    final availableTags = _getAllTags();

    return [
      FilterItem(
        id: 'kind',
        title: 'media_kind'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildSingleChoiceFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
            options: kindOptions,
            allItemsKey: 'all',
            allItemsLabel: 'media_allKinds'.tr,
          );
        },
        getBadge: (value) =>
            FilterBuilders.singleChoiceBadge(value, kindOptions),
      ),
      if (availableTags.isNotEmpty)
        FilterItem(
          id: 'tags',
          title: 'media_tags'.tr,
          type: FilterType.tagsMultiple,
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
      FilterItem(
        id: 'rating',
        title: 'media_rating'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildSingleChoiceFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
            options: ratingOptions,
            allItemsKey: 'all',
            allItemsLabel: 'media_ratingAll'.tr,
          );
        },
        getBadge: (value) =>
            FilterBuilders.singleChoiceBadge(value, ratingOptions),
      ),
      FilterItem(
        id: 'finishedRange',
        title: 'media_filterFinishedRange'.tr,
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
    ];
  }

  void _applyMultiFilters(Map<String, dynamic> filters) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _multiFilters
            ..clear()
            ..addAll(filters);
        });
      }
    });
  }

  bool _passesMultiFilters(MediaItem item) {
    // 1. 类型过滤
    final kind = _multiFilters['kind'] as String?;
    if (kind != null && item.kind.name != kind) return false;

    // 2. 标签过滤（任一命中）
    final tags = _multiFilters['tags'] as List?;
    if (tags != null && tags.isNotEmpty) {
      final selected = tags.cast<String>();
      if (!item.tags.any(selected.contains)) return false;
    }

    // 3. 评分过滤
    final rating = _multiFilters['rating'] as String?;
    if (rating != null) {
      final minRating = double.tryParse(rating);
      if (minRating != null && (item.rating ?? 0) < minRating) return false;
    }

    // 4. 完成时间范围过滤
    final range = _multiFilters['finishedRange'] as DateTimeRange?;
    if (range != null) {
      if (item.finishedAt == null) return false;
      if (item.finishedAt!.isBefore(range.start) ||
          item.finishedAt!.isAfter(range.end.add(const Duration(days: 1)))) {
        return false;
      }
    }

    return true;
  }

  List<MediaItem> _getVisibleItems() {
    final query = _searchQuery.toLowerCase();
    final items = MediaLogPlugin.instance.items.where((item) {
      if (query.isNotEmpty) {
        final inTitle = item.title.toLowerCase().contains(query);
        final inAuthor =
            item.author?.toLowerCase().contains(query) ?? false;
        final inTags = item.tags.any(
          (tag) => tag.toLowerCase().contains(query),
        );
        if (!inTitle && !inAuthor && !inTags) return false;
      }
      return _passesMultiFilters(item);
    }).toList();

    switch (_sortBy) {
      case 'title':
        items.sort((a, b) => a.title.compareTo(b.title));
      case 'rating':
        items.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      case 'finished':
        items.sort(
          (a, b) => (b.finishedAt ?? DateTime(1970))
              .compareTo(a.finishedAt ?? DateTime(1970)),
        );
      default:
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return items;
  }

  /// 排序按钮（多条件过滤栏尾部圆形按钮，DSPopover 经根 Overlay 展示需 DSThemeBridge 包裹）
  Widget _buildSortButton() {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return DSPopover(
            width: 200,
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
                            _sortBy == value
                                ? DsIconKind.check
                                : DsIconKind.sort,
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
                  menuRow('default', 'media_sortDefault'.tr),
                  menuRow('title', 'media_sortTitle'.tr),
                  menuRow('rating', 'media_sortRating'.tr),
                  menuRow('finished', 'media_sortFinished'.tr),
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

  /// 新建入口：先弹类型选择 sheet，再进表单
  Future<void> _addItem() async {
    final MediaKind? kind = await showDSBottomSheet<MediaKind>(
      context: context,
      title: 'media_add'.tr,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DSSheetAction(
            icon: DsIconKind.book,
            label: 'media_addReading'.tr,
            onTap: () => Navigator.pop(context, MediaKind.reading),
          ),
          DSSheetAction(
            icon: DsIconKind.video,
            label: 'media_addWatching'.tr,
            onTap: () => Navigator.pop(context, MediaKind.watching),
          ),
        ],
      ),
    );
    if (kind == null || !mounted) return;
    await _openItemForm(kind: kind);
  }

  Future<void> _openItemForm({MediaKind? kind, MediaItem? initial}) async {
    final result = await showDSBottomSheet<MediaItem>(
      context: context,
      title: initial == null ? 'media_newItem'.tr : 'media_editItem'.tr,
      builder: (context) => MediaItemForm(
        kind: kind ?? MediaKind.reading,
        initial: initial,
        availableTags: _getAllTags(),
      ),
    );
    if (result == null || !mounted) return;
    if (result.id.isEmpty) {
      await MediaLogPlugin.instance.saveItem(
        result.copyWith(id: MediaLogPlugin.newId()),
      );
    } else {
      await MediaLogPlugin.instance.saveItem(result);
    }
  }

  /// 长按卡片：编辑 / 删除
  Future<void> _showItemActions(MediaItem item) async {
    await showDSBottomSheet(
      context: context,
      title: item.title,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DSSheetAction(
            icon: DsIconKind.edit,
            label: 'media_edit'.tr,
            onTap: () {
              Navigator.pop(context);
              _openItemForm(initial: item);
            },
          ),
          DSSheetAction(
            icon: DsIconKind.trash,
            label: 'media_delete'.tr,
            destructive: true,
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(item);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(MediaItem item) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSDialog(
        title: 'media_deleteConfirm'.tr,
        message: 'media_deleteConfirmMessage'.tr,
        confirmText: 'media_delete'.tr,
        cancelText: 'media_cancel'.tr,
        confirmVariant: DSButtonVariant.destructive,
      ),
    );
    if (confirmed != true) return;
    await MediaLogPlugin.instance.deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final items = _getVisibleItems();

    return SuperCupertinoNavigationWrapper(
      title: Text('${'media_name'.tr} (${items.length})'),
      largeTitle: 'media_name'.tr,
      enableLargeTitle: true,
      // ===== 搜索 =====
      enableSearchBar: true,
      searchPlaceholder: 'media_searchPlaceholder'.tr,
      onSearchChanged: (query) => setState(() => _searchQuery = query),
      // ===== 多条件过滤 =====
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      onMultiFilterChanged: _applyMultiFilters,
      multiFilterBarTrailing: _buildSortButton(),
      body: Stack(
        children: [
          if (items.isEmpty)
            Center(
              child: DSEmptyState(
                emoji: '📚',
                title: 'media_noItems'.tr,
              ),
            )
          else
            MasonryGridView.count(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                // 双列错落：偶数项左列轻微左倾、奇数项右列下移右倾（迁移自 demo）
                final column = index % 2;
                return Padding(
                  padding: EdgeInsets.only(top: column == 1 ? 18 : 0),
                  child: MediaItemCard(
                    item: item,
                    seed: column * 31 + index + 1,
                    rotation: ((column + index) % 2 == 0) ? -0.025 : 0.02,
                    onTap: () => NavigationHelper.push(
                      context,
                      MediaDetailScreen(itemId: item.id),
                    ),
                    onLongPress: () => _showItemActions(item),
                  ),
                );
              },
            ),
          // 新建 FAB
          Positioned(
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: DSFab(onPressed: _addItem),
          ),
        ],
      ),
    );
  }
}
