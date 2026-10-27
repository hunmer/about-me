import 'package:get/get.dart';
import 'package:aboutme/plugins/database/widgets/record_edit_widget.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/plugins/database/controllers/database_controller.dart';
import 'package:aboutme/plugins/database/models/database_model.dart';
import 'package:aboutme/plugins/database/widgets/database_edit_widget.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/widgets/form_fields/form_builder_wrapper.dart';
import 'package:aboutme/widgets/form_fields/config.dart';
import 'package:aboutme/widgets/form_fields/types.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/event/event_manager.dart';
import '../models/record.dart' as record_model;

/// 记录排序选项
enum RecordSortOption {
  /// 更新时间降序（最新的在前）
  updatedDesc,

  /// 更新时间升序
  updatedAsc,

  /// 创建时间降序
  createdDesc,

  /// 创建时间升序
  createdAsc,
}

class DatabaseDetailWidget extends StatefulWidget {
  final DatabaseController controller;
  final String databaseId;

  const DatabaseDetailWidget({
    super.key,
    required this.controller,
    required this.databaseId,
  });

  @override
  State<DatabaseDetailWidget> createState() => _DatabaseDetailWidgetState();
}

class _DatabaseDetailWidgetState extends State<DatabaseDetailWidget> {
  late Future<void> _loadingFuture;

  /// 所有记录列表
  List<record_model.Record> _allRecords = [];

  /// 过滤后的记录列表
  List<record_model.Record> _filteredRecords = [];

  /// 当前搜索关键词
  String _searchKeyword = '';

  /// 多条件过滤状态
  final MultiFilterState _multiFilterState = MultiFilterState();

  /// 数据是否需要重新加载
  bool _needsReload = true;

  /// 记录数据 Future 缓存（避免任意 setState 都回到 loading 态）
  Future<List<record_model.Record>>? _recordsFuture;

  /// 已同步进列表的 future（identity 比较，避免复用缓存时重复同步）
  Future<List<record_model.Record>>? _consumedFuture;

  /// 上一次的过滤状态（用于避免重复触发）
  Map<String, dynamic>? _lastFilterState;

  @override
  void initState() {
    super.initState();
    EventManager.instance.subscribe('database_refresh', _onDatabaseRefresh);
    _loadingFuture = widget.controller.loadDatabase(widget.databaseId);
    // 加载完成后上报路由上下文，供"询问当前上下文"识别
    _loadingFuture.then((_) {
      if (!mounted) return;
      RouteHistoryManager.updateCurrentContext(
        pageId: '/database_detail',
        title: widget.controller.currentDatabase?.name ?? 'database_name'.tr,
        params: {
          'databaseId': widget.databaseId,
          'databaseName': widget.controller.currentDatabase?.name ?? '',
          'recordCount': _allRecords.length,
        },
      );
    });
  }

  @override
  void dispose() {
    EventManager.instance.unsubscribe('database_refresh', _onDatabaseRefresh);
    _multiFilterState.dispose();
    super.dispose();
  }

  /// 同步服务完成数据库或记录变更后，丢弃缓存并重新读取详情数据。
  Future<void> _onDatabaseRefresh(EventArgs _) async {
    if (!mounted) return;
    try {
      await widget.controller.loadDatabase(widget.databaseId);
    } catch (_) {
      if (mounted) {
        Navigator.of(context).maybePop();
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _needsReload = true;
      _recordsFuture = null;
      _consumedFuture = null;
    });
  }

  /// 构建多条件过滤项
  List<FilterItem> _buildFilterItems() {
    return [
      // 1. 日期范围过滤（基于更新时间）
      FilterItem(
        id: 'dateRange',
        title: 'database_filter_date_range'.tr,
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

      // 2. 排序方式
      FilterItem(
        id: 'sort',
        title: 'database_filter_sort'.tr,
        type: FilterType.custom,
        builder: (context, currentValue, onChanged) {
          return _buildSortFilter(context, currentValue, onChanged);
        },
        getBadge: (value) {
          if (value == null) return null;
          return _sortLabel(value as RecordSortOption);
        },
        initialValue: RecordSortOption.updatedDesc,
      ),
    ];
  }

  /// 排序选项文案
  String _sortLabel(RecordSortOption option) {
    return switch (option) {
      RecordSortOption.updatedDesc => 'database_sort_updated_desc'.tr,
      RecordSortOption.updatedAsc => 'database_sort_updated_asc'.tr,
      RecordSortOption.createdDesc => 'database_sort_created_desc'.tr,
      RecordSortOption.createdAsc => 'database_sort_created_asc'.tr,
    };
  }

  /// 构建排序选择器
  Widget _buildSortFilter(
    BuildContext context,
    dynamic currentValue,
    ValueChanged<dynamic> onChanged,
  ) {
    final option =
        currentValue as RecordSortOption? ?? RecordSortOption.updatedDesc;
    const options = RecordSortOption.values;

    // 过滤面板经 Overlay 展示，DS 组件需自带 DSThemeBridge（design.md §8）
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'database_sortMethod'.tr,
                style: DsTypography.heading.copyWith(
                  color: DSThemeBridge.resolve(context).text,
                ),
              ),
              const SizedBox(height: 12),
              DSSegmentedControl(
                options: [for (final o in options) _sortLabel(o)],
                selected: options.indexOf(option),
                onChanged: (index) => onChanged(options[index]),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 处理多条件过滤变更
  void _onMultiFilterChanged(Map<String, dynamic> filters) {
    // 检查过滤状态是否真的改变了（避免重复触发）
    if (_mapsEqual(_lastFilterState, filters)) {
      return; // 状态未改变，直接返回
    }

    // 保存当前状态
    _lastFilterState = Map<String, dynamic>.unmodifiable(filters);

    // 使用 addPostFrameCallback 避免 build 阶段调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _applyFilters(filters, _searchKeyword);
      }
    });
  }

  /// 比较两个 Map 是否相等
  bool _mapsEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    for (var key in a.keys) {
      if (!b.containsKey(key)) return false;
      final aValue = a[key];
      final bValue = b[key];

      // 处理 List 类型的比较
      if (aValue is List && bValue is List) {
        if (!_listsEqual(aValue, bValue)) return false;
      } else if (aValue != bValue) {
        return false;
      }
    }
    return true;
  }

  /// 比较两个 List 是否相等（忽略顺序）
  bool _listsEqual(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    final aSet = a.toSet();
    final bSet = b.toSet();
    return aSet.union(bSet).length == aSet.length &&
        aSet.intersection(bSet).length == aSet.length;
  }

  /// 处理搜索
  void _onSearchChanged(String keyword) {
    setState(() {
      _searchKeyword = keyword;
      _applyFilters(_multiFilterState.getAllValues(), keyword);
    });
  }

  /// 计算过滤后的记录列表（不调用setState）
  List<record_model.Record> _computeFilteredRecords(
    List<record_model.Record> records,
    Map<String, dynamic> filters,
    String keyword,
  ) {
    var result = List<record_model.Record>.from(records);

    // 关键词过滤 - 搜索所有字段值
    if (keyword.isNotEmpty) {
      final lowerKeyword = keyword.toLowerCase();
      result = result.where((record) {
        // 搜索 title 字段
        if (record.fields['title']?.toString().toLowerCase().contains(
              lowerKeyword,
            ) ==
            true) {
          return true;
        }
        // 搜索所有其他字段值
        return record.fields.values.any(
          (value) =>
              value?.toString().toLowerCase().contains(lowerKeyword) == true,
        );
      }).toList();
    }

    // 日期范围过滤（基于 updatedAt）
    if (filters['dateRange'] != null) {
      final range = filters['dateRange'] as DateTimeRange;
      result = result
          .where(
            (record) =>
                !record.updatedAt.isBefore(range.start) &&
                !record.updatedAt.isAfter(range.end),
          )
          .toList();
    }

    // 排序
    final sortOption =
        filters['sort'] as RecordSortOption? ?? RecordSortOption.updatedDesc;

    switch (sortOption) {
      case RecordSortOption.updatedDesc:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case RecordSortOption.updatedAsc:
        result.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      case RecordSortOption.createdDesc:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case RecordSortOption.createdAsc:
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return result;
  }

  /// 应用过滤条件（调用setState）
  void _applyFilters(Map<String, dynamic> filters, String keyword) {
    final newFilteredRecords = _computeFilteredRecords(
      _allRecords,
      filters,
      keyword,
    );

    // 检查结果是否真的改变了（通过比较 ID 列表）
    final oldIds = _filteredRecords.map((r) => r.id).toSet();
    final newIds = newFilteredRecords.map((r) => r.id).toSet();

    if (oldIds.length != newIds.length ||
        !oldIds.every((id) => newIds.contains(id))) {
      // 结果改变了，才调用 setState
      _filteredRecords = newFilteredRecords;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 加载态处于 wrapper（自带 Scaffold 背景）之外，先垫一层
    // 与 wrapper 一致的页面背景，避免路由过渡期透出黑色底层
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          return Container(
            color: dsScaffoldBackground(DSThemeBridge.resolve(context)),
            child: FutureBuilder(
              future: _loadingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: DSLoadingDots());
                }

                final database = widget.controller.currentDatabase!;

                // 仅在需要重载时重新拉取记录：任意 setState 复用缓存
                // Future，避免每次重建都回到 loading 态并重播卡片动画
                if (_needsReload || _recordsFuture == null) {
                  _needsReload = false;
                  _recordsFuture = widget.controller.getRecords(database.id);
                }

                // 加载记录数据
                return FutureBuilder<List<record_model.Record>>(
                  future: _recordsFuture,
                  builder: (context, recordSnapshot) {
                    if (recordSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(child: DSLoadingDots());
                    }

                    final records = recordSnapshot.data ?? [];

                    // 仅新拉取的 future 才同步数据：复用缓存 future 的
                    // 普通 setState 跳过（保留删除等本地修改，不重播动画）
                    if (_allRecords.isEmpty ||
                        !identical(_consumedFuture, _recordsFuture)) {
                      _consumedFuture = _recordsFuture;
                      _allRecords = records;
                      // 直接计算过滤结果，不调用setState
                      _filteredRecords = _computeFilteredRecords(
                        _allRecords,
                        _multiFilterState.getAllValues(),
                        _searchKeyword,
                      );
                    }

                    return _buildSuperCupertinoContent(database);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuperCupertinoContent(DatabaseModel database) {
    return SuperCupertinoNavigationWrapper(
      title: Text(database.name),
      largeTitle: database.name,
      automaticallyImplyLeading: true,

      // 顶部操作按钮（actions 经 Overlay 渲染，DS 组件需自带 DSThemeBridge）
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              return DSIconButton(
                icon: DsIconKind.edit,
                size: 40,
                tooltip: 'database_edit_database_title'.tr,
                onPressed: () => _showDatabaseEditor(database),
              );
            },
          ),
        ),
      ],

      // 启用搜索栏
      enableSearchBar: true,
      searchPlaceholder: 'database_search_records'.tr,
      onSearchChanged: _onSearchChanged,

      // 启用多条件过滤
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      multiFilterBarHeight: 50,
      onMultiFilterChanged: _onMultiFilterChanged,

      // 主体内容（包含浮动按钮）；卡片等 DS 组件统一经桥接取手绘主题
      body: DSThemeBridge(
        child: Stack(
          children: [
            // 主要内容
            _filteredRecords.isEmpty
                ? _buildEmptyState()
                : _buildMasonryView(database),

            // 浮动操作按钮
            Positioned(
              right: 16,
              bottom: 16,
              child: DSThemeBridge(
                // DSFab 内部取 AppTheme，需包桥
                child: DSFab(
                  onPressed: () => _showRecordEditor(database, null),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final hasFilters =
        _multiFilterState.hasAnyFilter || _searchKeyword.isNotEmpty;

    return Center(
      child: DSEmptyState(
        icon: hasFilters ? DsIconKind.close : DsIconKind.inbox,
        title: hasFilters
            ? 'database_no_matching_records'.tr
            : 'database_no_records_yet'.tr,
        message: hasFilters ? 'database_try_adjust_filters'.tr : null,
      ),
    );
  }

  /// 构建瀑布流视图
  Widget _buildMasonryView(DatabaseModel database) {
    return MasonryGridView.count(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final record = _filteredRecords[index];
        // 手绘便签倾斜 + 贴条（角度由记录 id 哈希确定），
        // 挂载即播墨线描画入场（design.md §10/§11）
        return HandDrawnStickyItem(
          tiltKey: record.id,
          child: WiredDraw(child: _buildRecordCard(database, record)),
        );
      },
    );
  }

  /// 构建记录卡片
  Widget _buildRecordCard(DatabaseModel database, record_model.Record record) {
    final theme = DSThemeBridge.resolve(context);
    // 获取需要显示在预览中的字段
    final previewFields = database.fields
        .where((f) => f.showInPreview)
        .toList();

    // 长按弹圆盘快捷菜单（编辑/删除；tap 由 DSCard 内部 Pressable 处理）
    return ArcContextMenu.actions(
      actions: [
        ArcMenuItem(
          icon: DsIconKind.edit,
          label: 'database_edit'.tr,
          onTap: () => _editRecord(context, record),
        ),
        ArcMenuItem(
          icon: DsIconKind.trash,
          label: 'database_delete'.tr,
          destructive: true,
          onTap: () async {
            final shouldDelete = await _confirmDelete(context, record);
            if (shouldDelete) {
              await _deleteRecord(record);
            }
          },
        ),
      ],
      showMore: () => _showRecordMenu(context, record),
      child: DSCard(
        onTap: () => _showRecordEditor(database, record),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 预览字段信息 - 使用 FormBuilderWrapper
                if (previewFields.isNotEmpty) ...[
                  FormBuilderWrapper(
                    config: FormConfig(
                      fields: previewFields.map((field) {
                        return FormFieldConfig(
                          name: field.name,
                          type: _mapFieldType(field.type),
                          labelText: field.name,
                          initialValue: record.fields[field.name],
                          enabled: false, // 禁止编辑
                        );
                      }).toList(),
                      onSubmit: (_) {}, // 空回调，不会触发
                      showSubmitButton: false,
                      showResetButton: false,
                      fieldSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // 更新时间
                Text(
                  'database_record_updated_at'.trParams({
                    'time': _formatDateTime(record.updatedAt),
                  }),
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 将数据库字段类型映射到表单字段类型
  FormFieldType _mapFieldType(String fieldType) {
    switch (fieldType) {
      case 'Text':
        return FormFieldType.text;
      case 'Long Text':
        return FormFieldType.textArea;
      case 'Integer':
        return FormFieldType.number;
      case 'Checkbox':
        return FormFieldType.switchField;
      case 'Date':
        return FormFieldType.date;
      case 'Time':
        return FormFieldType.time;
      case 'Date/Time':
        return FormFieldType.date;
      case 'Image':
        return FormFieldType.imagePicker;
      case 'Password':
        return FormFieldType.password;
      default:
        return FormFieldType.text;
    }
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final hhmm =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (difference.inDays == 0) {
      return '${'database_time_today'.tr} $hhmm';
    } else if (difference.inDays == 1) {
      return '${'database_time_yesterday'.tr} $hhmm';
    } else if (difference.inDays < 7) {
      return 'database_time_days_ago'.trParams({
        'n': difference.inDays.toString(),
      });
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    record_model.Record record,
  ) {
    return showDSDialog<bool>(
      context: context,
      builder: (context) => DSDialog(
        title: 'database_delete_record_title'.tr,
        message: 'database_delete_record_message'.trParams({
          'name': record.fields['title'] ?? 'database_untitled_record'.tr,
        }),
        confirmText: 'database_delete'.tr,
        cancelText: 'database_cancel'.tr,
        confirmVariant: DSButtonVariant.destructive,
      ),
    ).then((value) => value ?? false);
  }

  Future<void> _deleteRecord(record_model.Record record) async {
    await widget.controller.deleteRecord(record.id);
    _allRecords.removeWhere((r) => r.id == record.id);
    _applyFilters(_multiFilterState.getAllValues(), _searchKeyword);
  }

  /// 长按快捷菜单项（圆盘与底部 sheet 共用）
  List<ArcMenuItem> _recordActions(
    BuildContext context,
    record_model.Record record,
  ) => [
        ArcMenuItem(
          icon: DsIconKind.edit,
          label: 'database_edit'.tr,
          onTap: () => _editRecord(context, record),
        ),
        ArcMenuItem(
          icon: DsIconKind.trash,
          label: 'database_delete'.tr,
          destructive: true,
          onTap: () async {
            final shouldDelete = await _confirmDelete(context, record);
            if (shouldDelete) {
              await _deleteRecord(record);
            }
          },
        ),
      ];

  void _showRecordMenu(BuildContext context, record_model.Record record) {
    SmoothBottomSheet.showActionList(
      context: context,
      actions: _recordActions(context, record),
    );
  }

  void _editRecord(BuildContext context, record_model.Record record) {
    _showRecordEditor(widget.controller.currentDatabase!, record);
  }

  /// 记录新建/编辑：smooth_sheets 底部弹层
  Future<void> _showRecordEditor(
    DatabaseModel database,
    record_model.Record? record,
  ) async {
    VoidCallback? submitRecord;
    final result = await SmoothBottomSheet.showForm<record_model.Record>(
      context: context,
      title: 'database_edit_record_title'.tr,
      child: RecordEditWidget(
        controller: widget.controller,
        database: database,
        record: record,
        embedInSheet: true,
        onReady: (submit) => submitRecord = submit,
      ),
      onSave: () => submitRecord?.call(),
    );
    // 仅真正保存了记录（返回非 null）才刷新列表；
    // 直接关闭弹层不触发列表更新与重绘动画
    if (mounted && result != null) {
      setState(() => _needsReload = true);
    }
  }

  /// 数据库编辑：全页展示（design.md §5 平台路由转场）
  Future<void> _showDatabaseEditor(DatabaseModel database) async {
    await NavigationHelper.pushAnimated<bool>(
      context,
      DatabaseEditWidget(
        controller: widget.controller,
        database: database,
      ),
      routeName: '/database_edit',
    );
    if (mounted) setState(() {});
  }
}
