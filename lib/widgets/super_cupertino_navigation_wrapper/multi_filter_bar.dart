import 'package:flutter/material.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'filter_models.dart';

/// 多条件过滤栏组件
class MultiFilterBar extends StatefulWidget {
  /// 过滤条件列表
  final List<FilterItem> filterItems;

  /// 过滤状态
  final MultiFilterState filterState;

  /// 过滤条件变更回调
  final ValueChanged<Map<String, dynamic>>? onFilterChanged;

  /// 高度
  final double height;

  const MultiFilterBar({
    super.key,
    required this.filterItems,
    required this.filterState,
    this.onFilterChanged,
    this.height = 50,
  });

  @override
  State<MultiFilterBar> createState() => _MultiFilterBarState();
}

class _MultiFilterBarState extends State<MultiFilterBar> {
  /// 当前选中的过滤项索引（null表示在第一层）
  int? _selectedFilterIndex;

  /// 是否显示详情层
  bool get _isDetailView => _selectedFilterIndex != null;

  @override
  void initState() {
    super.initState();
    // 监听过滤状态变化
    widget.filterState.addListener(_onFilterStateChanged);

    // 初始化过滤值：推迟到首帧之后，避免 notifyListeners
    // 在 build 阶段触发父级 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (var item in widget.filterItems) {
        if (item.initialValue != null &&
            !widget.filterState.hasFilter(item.id)) {
          widget.filterState.setValue(item.id, item.initialValue);
        }
      }
    });
  }

  @override
  void dispose() {
    widget.filterState.removeListener(_onFilterStateChanged);
    super.dispose();
  }

  /// 过滤状态变更回调
  void _onFilterStateChanged() {
    widget.onFilterChanged?.call(widget.filterState.getAllValues());
  }

  /// 清空所有过滤
  void _clearAllFilters() {
    widget.filterState.clearAll();
    setState(() {
      _selectedFilterIndex = null;
    });
  }

  /// 选择过滤项
  void _selectFilter(int index) {
    setState(() {
      _selectedFilterIndex = index;
    });
  }

  /// 返回第一层
  void _backToList() {
    setState(() {
      _selectedFilterIndex = null;
    });
  }

  /// 构建过滤项的badge文本
  String? _buildBadge(FilterItem item) {
    final value = widget.filterState.getValue(item.id);
    if (item.getBadge != null) {
      return item.getBadge!(value);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.12),
            width: 0.5,
          ),
        ),
      ),
      child: _isDetailView ? _buildDetailView() : _buildListView(),
    );
  }

  /// 构建第一层：过滤项列表
  Widget _buildListView() {
    final ds = AppTheme.of(context);
    return Row(
      children: [
        // 过滤项列表（可滚动）
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: widget.filterItems.length,
            itemBuilder: (context, index) {
              final item = widget.filterItems[index];
              final badge = _buildBadge(item);
              final hasBadge = badge != null && badge.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                child: DSChip(
                  label: item.title,
                  badge: hasBadge ? badge : null,
                  selected: hasBadge,
                  onSelected: (_) => _selectFilter(index),
                ),
              );
            },
          ),
        ),

        // 清空所有按钮
        if (widget.filterState.hasAnyFilter)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DSIconButton(
              icon: DsIconKind.close,
              size: 36,
              color: ds.surfaceAlt,
              iconColor: ds.danger,
              onPressed: _clearAllFilters,
              tooltip: '清空过滤',
            ),
          ),
      ],
    );
  }

  /// 构建第二层：过滤详情
  Widget _buildDetailView() {
    if (_selectedFilterIndex == null ||
        _selectedFilterIndex! >= widget.filterItems.length) {
      return const SizedBox.shrink();
    }

    final item = widget.filterItems[_selectedFilterIndex!];
    final ds = AppTheme.of(context);

    return Row(
      children: [
        // 返回按钮
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: DSIconButton(
            icon: DsIconKind.chevronLeft,
            size: 36,
            color: ds.surfaceAlt,
            iconColor: ds.textSub,
            onPressed: _backToList,
          ),
        ),

        // 内容区域（可滚动）
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 12),
            child: item.builder(
              context,
              widget.filterState.getValue(item.id),
              (value, {bool? done}) {
                widget.filterState.setValue(item.id, value);
                setState(() {}); // 更新UI
                // 选择完成（如单选）时自动返回第一层
                if (done == true) _backToList();
              },
            ),
          ),
        ),

        // 固定在详情层最右侧的尾部部件
        if (item.trailing != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: item.trailing,
          ),
      ],
    );
  }
}
