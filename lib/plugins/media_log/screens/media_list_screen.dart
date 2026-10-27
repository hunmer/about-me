import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/widgets/swipe_action/swipe_action_wrapper.dart';

import '../media_log_plugin.dart';
import '../models/media_item.dart';
import '../screens/media_detail_screen.dart';
import '../widgets/media_bookshelf_view.dart';
import '../widgets/media_item_card.dart';
import '../widgets/media_item_form.dart';
import '../widgets/media_item_list_tile.dart';

/// 视图模式：瀑布流网格 / 单列列表 / 手绘书架
enum _MediaViewMode { grid, list, shelf }

extension _MediaViewModeX on _MediaViewMode {
  String get persistedName => name;

  static _MediaViewMode fromName(String? name) => switch (name) {
    'grid' => _MediaViewMode.grid,
    'list' => _MediaViewMode.list,
    _ => _MediaViewMode.shelf,
  };
}

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

  _MediaViewMode _viewMode = _MediaViewMode.shelf;

  /// 切换按钮的下一档（网格 → 列表 → 书架 → 网格循环）
  _MediaViewMode get _nextViewMode => switch (_viewMode) {
    _MediaViewMode.grid => _MediaViewMode.list,
    _MediaViewMode.list => _MediaViewMode.shelf,
    _MediaViewMode.shelf => _MediaViewMode.grid,
  };

  void _cycleViewMode() {
    setState(() => _viewMode = _nextViewMode);
    MediaLogPlugin.instance.setViewMode(_viewMode.persistedName);
    _updateRouteContext();
  }

  @override
  void initState() {
    super.initState();
    // 恢复持久化的视图偏好（plugin 初始化先于页面构建完成）
    _viewMode = _MediaViewModeX.fromName(
      MediaLogPlugin.instance.viewMode,
    );
    MediaLogPlugin.instance.addListener(_onDataChanged);
    // 上报路由上下文（/plugin/media_log 打开时归一化为 /media_log），
    // 供"询问当前上下文"识别
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateRouteContext());
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到列表状态
  void _updateRouteContext() {
    if (!mounted) return;
    RouteHistoryManager.updateCurrentContext(
      pageId: '/media_log',
      title: 'media_name'.tr,
      params: {
        'itemCount': MediaLogPlugin.instance.items.length,
        'viewMode': _viewMode.persistedName,
      },
    );
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
    final MediaKind? kind = await SmoothBottomSheet.showWithTitle<MediaKind>(
      context: context,
      title: 'media_add'.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SmoothSheetAction(
            icon: DsIconKind.book,
            label: 'media_addReading'.tr,
            onTap: () => Navigator.pop(context, MediaKind.reading),
          ),
          SmoothSheetAction(
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
    // 表单 sheet 为无名路由，手动上报表单上下文，关闭后恢复列表上下文
    final isEdit = initial != null;
    RouteHistoryManager.updateCurrentContext(
      pageId: isEdit ? '/media_log/form_edit' : '/media_log/form_new',
      title: isEdit ? 'media_editItem'.tr : 'media_newItem'.tr,
      params: isEdit
          ? {
              'title': initial.title,
              'kind': initial.kind == MediaKind.reading
                  ? 'media_reading'.tr
                  : 'media_watching'.tr,
            }
          : null,
    );
    final result = await SmoothBottomSheet.showWithTitle<MediaItem>(
      context: context,
      title: initial == null ? 'media_newItem'.tr : 'media_editItem'.tr,
      child: MediaItemForm(
        kind: kind ?? MediaKind.reading,
        initial: initial,
        availableTags: _getAllTags(),
      ),
    );
    if (mounted) _updateRouteContext();
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
  /// 长按快捷菜单项（圆盘与底部 sheet 共用）
  List<ArcMenuItem> _itemActions(MediaItem item) => [
        ArcMenuItem(
          icon: DsIconKind.edit,
          label: 'media_edit'.tr,
          onTap: () => _openItemForm(initial: item),
        ),
        ArcMenuItem(
          icon: DsIconKind.trash,
          label: 'media_delete'.tr,
          destructive: true,
          onTap: () => _confirmDelete(item),
        ),
      ];

  Future<void> _showItemActions(MediaItem item) {
    return SmoothBottomSheet.showActionList(
      context: context,
      title: item.title,
      actions: _itemActions(item),
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
      // 视图切换（actions 经 Overlay 渲染，DS 组件需 DSThemeBridge 包裹）
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: switch (_nextViewMode) {
                  _MediaViewMode.grid => DsIconKind.grid,
                  _MediaViewMode.list => DsIconKind.list,
                  _MediaViewMode.shelf => DsIconKind.shelf,
                },
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: switch (_nextViewMode) {
                  _MediaViewMode.grid => 'media_viewAsGrid'.tr,
                  _MediaViewMode.list => 'media_viewAsList'.tr,
                  _MediaViewMode.shelf => 'media_viewAsShelf'.tr,
                },
                onPressed: _cycleViewMode,
              );
            },
          ),
        ),
      ],
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
          else if (_viewMode == _MediaViewMode.shelf)
            // 手绘书架：items 已过滤排序，不符合条件的书直接不上架；
            // 长按书脊弹圆盘快捷菜单（与瀑布流卡片一致）
            MediaBookshelfView(
              items: items,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              onTap: (item) => NavigationHelper.pushHero(
                context,
                MediaDetailScreen(itemId: item.id),
              ),
              arcActions: _itemActions,
              onMore: _showItemActions,
            )
          else if (_viewMode == _MediaViewMode.grid)
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
                // 挂载即播墨线描画入场（design.md §10）
                return WiredDraw(
                  child: Padding(
                    padding: EdgeInsets.only(top: column == 1 ? 18 : 0),
                    // 长按弹圆盘快捷菜单（编辑/删除）
                    child: ArcContextMenu.actions(
                      actions: _itemActions(item),
                      showMore: () => _showItemActions(item),
                      // 浮层预览用无 Hero 副本避免 tag 冲突
                      preview: MediaItemCard(
                        item: item,
                        seed: column * 31 + index + 1,
                        rotation: ((column + index) % 2 == 0) ? -0.025 : 0.02,
                        onTap: () {},
                        enableHero: false,
                      ),
                      child: MediaItemCard(
                        item: item,
                        seed: column * 31 + index + 1,
                        rotation: ((column + index) % 2 == 0) ? -0.025 : 0.02,
                        onTap: () => NavigationHelper.pushHero(
                          context,
                          MediaDetailScreen(itemId: item.id),
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          else
            // 单列列表：右滑编辑 / 左滑删除（与点评卡交互一致）
            ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                // 挂载即播墨线描画入场（design.md §10）
                return WiredDraw(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: index < items.length - 1 ? 12 : 0,
                    ),
                    child: SwipeActionWrapper(
                      key: ValueKey(item.id),
                      deleteConfirmContent: 'media_deleteConfirmMessage'.tr,
                      leadingActions: [
                        SwipeActionPresets.edit(
                          label: 'media_edit'.tr,
                          onTap: () => _openItemForm(initial: item),
                        ),
                      ],
                      trailingActions: [
                        SwipeActionPresets.delete(
                          label: 'media_delete'.tr,
                          // 滑动已有嵌套二次确认，直接删除；菜单入口走 _confirmDelete
                          onTap: () =>
                              MediaLogPlugin.instance.deleteItem(item.id),
                        ),
                      ],
                      child: MediaItemListTile(
                        item: item,
                        seed: index + 1,
                        onTap: () => NavigationHelper.pushHero(
                          context,
                          MediaDetailScreen(itemId: item.id),
                        ),
                      ),
                    ),
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
