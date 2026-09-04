import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/home_layout_manager.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_item.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:aboutme/screens/home_screen/widgets/common_widget_selector_page.dart';

/// 添加小组件对话框 - 使用 SuperCupertinoNavigationWrapper 重构版本
class AddWidgetDialog extends StatefulWidget {
  /// 可选的文件夹ID，如果提供则将组件添加到该文件夹
  final String? folderId;

  /// 可选的要替换的小组件ID，如果提供则为替换模式
  final String? replaceWidgetItemId;

  /// 初始搜索关键词（用于替换模式时自动搜索同插件组件）
  final String? initialSearchQuery;

  const AddWidgetDialog({
    super.key,
    this.folderId,
    this.replaceWidgetItemId,
    this.initialSearchQuery,
  });

  @override
  State<AddWidgetDialog> createState() => _AddWidgetDialogState();
}

class _AddWidgetDialogState extends State<AddWidgetDialog> {
  Map<String, List<HomeWidget>> _widgetsByCategory = {};
  List<String> _categories = [];

  // 搜索查询状态
  String _searchQuery = '';

  // 过滤条件值（从 onMultiFilterChanged 回调获取）
  Map<String, dynamic> _filterValues = {};

  @override
  void initState() {
    super.initState();

    // 获取所有小组件并按分类分组
    _widgetsByCategory = HomeWidgetRegistry().getWidgetsByCategory();
    _categories = _widgetsByCategory.keys.toList()..sort();

    // 替换模式：初始化插件过滤器值（通过 initialMultiFilters 参数传递）
    if (widget.initialSearchQuery != null) {
      _filterValues['plugin'] = widget.initialSearchQuery;
    }
  }

  /// 获取所有组件的扁平列表
  List<HomeWidget> get _allWidgets {
    return _widgetsByCategory.values.expand((list) => list).toList();
  }

  /// 获取过滤后的组件列表
  List<HomeWidget> _getFilteredWidgets() {
    var widgets = _allWidgets;

    // 应用搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      widgets =
          widgets.where((widget) {
            final matchesName = widget.name.toLowerCase().contains(query);
            final matchesDescription =
                widget.description?.toLowerCase().contains(query) ?? false;
            final matchesPlugin = widget.pluginId.toLowerCase().contains(query);
            return matchesName || matchesDescription || matchesPlugin;
          }).toList();
    }

    // 应用插件过滤（从 _filterValues 中获取）
    final selectedPlugin = _filterValues['plugin'] as String?;
    if (selectedPlugin != null &&
        selectedPlugin.isNotEmpty &&
        selectedPlugin != '全部插件') {
      widgets = widgets.where((w) => w.pluginId == selectedPlugin).toList();
    }

    // 应用分类过滤（从 _filterValues 中获取）
    final selectedCategory = _filterValues['category'] as String?;
    if (selectedCategory != null &&
        selectedCategory.isNotEmpty &&
        selectedCategory != '全部分类') {
      widgets = widgets.where((w) => w.category == selectedCategory).toList();
    }

    // 应用尺寸过滤（从 _filterValues 中获取）
    final selectedSizes = _filterValues['sizes'] as List<String>?;
    if (selectedSizes != null && selectedSizes.isNotEmpty) {
      widgets =
          widgets.where((widget) {
            return widget.effectiveSupportedSizes.any((size) {
              final sizeKey = '${size.width}×${size.height}';
              return selectedSizes.contains(sizeKey);
            });
          }).toList();
    }

    return widgets;
  }

  /// 构建分类过滤器
  List<FilterItem> _buildFilterItems() {
    // 获取所有插件ID列表
    final allPlugins =
        _allWidgets.map((w) => w.pluginId).toSet().toList()..sort();

    return [
      // 插件过滤器
      FilterItem(
        id: 'plugin',
        title: '插件',
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return _buildPluginFilter(
            allPlugins,
            currentValue as String?,
            (value) => onChanged(value),
          );
        },
        getBadge: (value) {
          if (value == null || value == '全部插件') return null;
          return value as String;
        },
      ),
      // 分类过滤器
      FilterItem(
        id: 'category',
        title: '分类',
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return _buildCategoryFilter(
            currentValue as String?,
            (value) => onChanged(value),
          );
        },
        getBadge: (value) {
          if (value == null || value == '全部分类') return null;
          return value as String;
        },
      ),
      // 尺寸过滤器
      FilterItem(
        id: 'sizes',
        title: '尺寸',
        type: FilterType.tagsMultiple,
        builder: (context, currentValue, onChanged) {
          return _buildSizeFilter(
            currentValue as List<String>?,
            (value) => onChanged(value),
          );
        },
        getBadge: (value) {
          if (value == null) return null;
          final list = value as List;
          if (list.isEmpty) return null;
          return '${list.length}';
        },
      ),
    ];
  }

  /// 构建插件过滤器内容
  Widget _buildPluginFilter(
    List<String> allPlugins,
    String? selectedPlugin,
    ValueChanged<String?> onChanged,
  ) {
    final allOptions = ['全部插件', ...allPlugins];

    // 过滤面板可能经 Overlay 展示在主题树外，包桥保证取到 AppTheme
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children:
                allOptions.map((plugin) {
                  final isSelected = (selectedPlugin ?? '全部插件') == plugin;

                  return DSChip(
                    label: plugin,
                    selected: isSelected,
                    onSelected: (_) {
                      onChanged(plugin == '全部插件' ? null : plugin);
                    },
                  );
                }).toList(),
          );
        },
      ),
    );
  }

  /// 构建分类过滤器内容
  Widget _buildCategoryFilter(
    String? selectedCategory,
    ValueChanged<String?> onChanged,
  ) {
    final allCategories = ['全部分类', ..._categories];

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children:
                allCategories.map((category) {
                  final isSelected = (selectedCategory ?? '全部分类') == category;

                  return DSChip(
                    label: category,
                    selected: isSelected,
                    onSelected: (_) {
                      onChanged(category == '全部分类' ? null : category);
                    },
                  );
                }).toList(),
          );
        },
      ),
    );
  }

  /// 构建尺寸过滤器内容
  Widget _buildSizeFilter(
    List<String>? selectedSizes,
    ValueChanged<List<String>> onChanged,
  ) {
    final sizes = [
      {'label': '1×1', 'size': const SmallSize()},
      {'label': '2×1', 'size': const MediumSize()},
      {'label': '2×2', 'size': const LargeSize()},
    ];

    final selected = selectedSizes ?? [];

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            children:
                sizes.map((item) {
                  final label = item['label'] as String;
                  final isSelected = selected.contains(label);

                  return DSChip(
                    label: label,
                    selected: isSelected,
                    onSelected: (value) {
                      final newSelected = List<String>.from(selected);
                      if (value) {
                        newSelected.add(label);
                      } else {
                        newSelected.remove(label);
                      }
                      onChanged(newSelected);
                    },
                  );
                }).toList(),
          );
        },
      ),
    );
  }

  /// 处理小组件点击
  void _handleWidgetTap(HomeWidget widget) async {
    if (widget.supportsCommonWidgets) {
      // 打开公共小组件选择页面
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => CommonWidgetSelectorPage(
                pluginWidget: widget,
                folderId: this.widget.folderId,
                replaceWidgetItemId: this.widget.replaceWidgetItemId,
              ),
        ),
      );
    } else {
      // 原有逻辑：直接添加
      _addWidget(widget);
    }
  }

  /// 添加小组件或替换现有小组件
  void _addWidget(HomeWidget widget) async {
    final layoutManager = HomeLayoutManager();

    // 替换模式：替换掉原小组件
    if (this.widget.replaceWidgetItemId != null) {
      final oldItem = layoutManager.findItem(this.widget.replaceWidgetItemId!);
      if (oldItem != null && oldItem is HomeWidgetItem) {
        // 保留原小组件的尺寸和配置，只更换 widgetId
        final replacementItem = HomeWidgetItem(
          id: oldItem.id,
          widgetId: widget.id,
          size: oldItem.size,
          config: oldItem.config,
        );
        layoutManager.updateItem(oldItem.id, replacementItem);
        await layoutManager.saveLayout();

        // 关闭对话框
        Navigator.of(context).pop();

        // 显示提示
        Toast.success('已将小组件替换为 ${widget.name}');
        return;
      }
    }

    // 创建小组件实例
    final widgetItem = HomeWidgetItem(
      id: layoutManager.generateId(),
      widgetId: widget.id,
      size: widget.defaultSize,
    );

    // 添加到布局或文件夹
    if (this.widget.folderId != null) {
      // 添加到文件夹
      layoutManager.addItemToFolder(widgetItem, this.widget.folderId!);
    } else {
      // 添加到主页
      layoutManager.addItem(widgetItem);
    }

    await layoutManager.saveLayout();

    // 关闭对话框
    Navigator.of(context).pop();

    // 显示提示
    final location = this.widget.folderId != null ? '文件夹' : '主页';
    Toast.success('已添加 ${widget.name} 到$location');
  }

  /// 构建组件网格视图
  Widget _buildWidgetGrid(List<HomeWidget> widgets) {
    if (widgets.isEmpty) {
      return Center(
        child: DSThemeBridge(
          child: Builder(
            builder: (context) {
              return DSEmptyState(
                emoji: '🔍',
                title: '没有找到匹配的组件',
                actionLabel: 'screens_clearFilterConditions'.tr,
                onAction: () {
                  setState(() {
                    _searchQuery = '';
                    _filterValues.clear();
                  });
                },
              );
            },
          ),
        ),
      );
    }

    // 根据屏幕宽度动态调整列数和宽高比
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 400 ? 1 : 2;
    final childAspectRatio = screenWidth < 400 ? 1.2 : 0.85;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: widgets.length,
      itemBuilder: (context, index) => _buildWidgetPreviewCard(widgets[index]),
    );
  }

  /// 构建小组件预览卡片
  Widget _buildWidgetPreviewCard(HomeWidget widget) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Pressable(
            onPressed: () => _handleWidgetTap(widget),
            builder: (context, states) {
              final pressed = states.contains(WidgetState.pressed);
              return JellyBox(
                radius: theme.radii.lg,
                raised: false,
                color: pressed ? theme.surfaceAlt : theme.surface,
                child: ClipRRect(
                  borderRadius: theme.radii.lg,
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 图标和标题
                          Container(
                            padding: EdgeInsets.all(theme.spacing.lg),
                            color: widget.color?.withValues(alpha: 0.1),
                            child: Column(
                              children: [
                                // 注册表图标为持久化 IconData，保留 Material Icon
                                Icon(
                                  widget.icon,
                                  size: 48,
                                  color: widget.color,
                                ),
                                SizedBox(height: theme.spacing.sm),
                                Text(
                                  widget.name,
                                  style: DsTypography.heading.copyWith(
                                    color: theme.text,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // 描述文本
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(theme.spacing.md),
                              child:
                                  widget.description != null
                                      ? Text(
                                        widget.description!,
                                        style: DsTypography.caption.copyWith(
                                          color: theme.textSub,
                                        ),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                      : const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),

                      // 尺寸标签 - 右上角
                      Positioned(
                        top: theme.spacing.xs,
                        right: theme.spacing.xs,
                        child:
                            widget.effectiveSupportedSizes.length > 2
                                ? _buildBadge(
                                  theme,
                                  '${widget.effectiveSupportedSizes.length}个可用大小',
                                )
                                : Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children:
                                      widget.effectiveSupportedSizes
                                          .map(
                                            (size) => _buildBadge(
                                              theme,
                                              '${size.width}×${size.height}',
                                            ),
                                          )
                                          .toList(),
                                ),
                      ),

                      // 公共小组件适配标签 - 左上角
                      if (widget.supportsCommonWidgets)
                        Positioned(
                          top: theme.spacing.xs,
                          left: theme.spacing.xs,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.success,
                              borderRadius: theme.radii.pill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DsIcon(
                                  DsIconKind.grid,
                                  size: 10,
                                  color: theme.onSuccess,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '适配公共组件',
                                  style: DsTypography.caption.copyWith(
                                    color: theme.onSuccess,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 尺寸角标
  Widget _buildBadge(AppThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.primary.mixWhite(0.86),
        borderRadius: theme.radii.sm,
      ),
      child: Text(
        text,
        style: DsTypography.caption.copyWith(
          color: theme.primary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogHeight = screenSize.height * 0.8;
    // 在小屏幕下使用全宽，否则限制为600
    final dialogWidth =
        screenSize.width < 600 ? screenSize.width * 0.95 : 600.0;

    final filteredWidgets = _getFilteredWidgets();
    // State 的 context 在内部主题桥之上，用 resolve 安全取令牌
    final theme = DSThemeBridge.resolve(context);

    return DSThemeBridge(
      child: JellyBox(
        width: dialogWidth,
        height: dialogHeight,
        radius: theme.radii.xxl,
        child: SuperCupertinoNavigationWrapper(
          // 基本配置
          title: Text(
            widget.replaceWidgetItemId != null
                ? 'screens_replaceWidget'.tr
                : 'screens_addWidget'.tr,
          ),
          largeTitle:
              widget.replaceWidgetItemId != null
                  ? 'screens_replaceWidget'.tr
                  : 'screens_addWidget'.tr,
          enableLargeTitle: true,

          // 主体内容 - 使用相同的过滤后的组件列表
          body: _buildWidgetGrid(filteredWidgets),

          // 搜索配置
          enableSearchBar: true,
          searchPlaceholder: '搜索组件名称、描述...',
          onSearchChanged: (query) {
            setState(() {
              _searchQuery = query;
            });
          },
          // 搜索结果页面 - 使用相同的过滤逻辑
          searchBody: _buildWidgetGrid(filteredWidgets),

          // 多条件过滤配置
          enableMultiFilter: true,
          multiFilterItems: _buildFilterItems(),
          multiFilterBarHeight: 50,
          multiFilterToggleable: true,
          // 设置初始过滤值（替换模式下自动过滤插件）
          initialMultiFilters:
              widget.initialSearchQuery != null
                  ? {'plugin': widget.initialSearchQuery}
                  : null,
          onMultiFilterChanged: (filters) {
            // 保存过滤值并刷新UI
            setState(() {
              _filterValues = filters;
            });
          },

          // 操作按钮：actions 经 Overlay/Hero 重挂载到主题树之外，
          // 每个组件各自包一层 DSThemeBridge
          actions: [
            DSThemeBridge(
              child: Builder(
                builder: (context) {
                  final theme = DSThemeBridge.resolve(context);
                  return DSIconButton(
                    icon: DsIconKind.close,
                    size: 36,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                  );
                },
              ),
            ),
          ],

          // 禁用自动返回按钮
          automaticallyImplyLeading: false,
        ),
      ),
    );
  }
}
