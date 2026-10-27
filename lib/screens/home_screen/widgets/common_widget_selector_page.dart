import 'dart:convert';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/plugin_data_selector/models/selectable_item.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:skribble/skribble.dart' show WiredDraw;
import 'package:aboutme/core/services/plugin_data_selector/plugin_data_selector_service.dart';
import 'package:aboutme/core/services/plugin_data_selector/models/selector_result.dart';
import 'package:aboutme/screens/home_screen/managers/home_layout_manager.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_item.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/home_screen/widgets/selector_widget_types.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/common_widgets.dart';

import 'package:get/get.dart';
/// 公共小组件选择页面
///
/// 用于让用户选择插件数据，然后选择一个公共小组件样式
class CommonWidgetSelectorPage extends StatefulWidget {
  /// 插件小组件定义
  final HomeWidget pluginWidget;

  /// 可选的文件夹ID，如果提供则将组件添加到该文件夹
  final String? folderId;

  /// 可选的要替换的小组件ID，如果提供则为替换模式
  final String? replaceWidgetItemId;

  /// 可选的初始选中的公共小组件ID
  final String? initialCommonWidgetId;

  /// 可选的初始选择器配置（用于恢复之前选择的数据）
  final SelectorWidgetConfig? initialSelectorConfig;

  /// 可选的原有小组件大小（用于替换时保留大小）
  final HomeWidgetSize? originalSize;

  /// 可选的原有小组件配置（用于保留自定义尺寸等信息）
  final Map<String, dynamic>? originalConfig;

  const CommonWidgetSelectorPage({
    super.key,
    required this.pluginWidget,
    this.folderId,
    this.replaceWidgetItemId,
    this.initialCommonWidgetId,
    this.initialSelectorConfig,
    this.originalSize,
    this.originalConfig,
  });

  @override
  State<CommonWidgetSelectorPage> createState() =>
      _CommonWidgetSelectorPageState();
}

class _CommonWidgetSelectorPageState extends State<CommonWidgetSelectorPage> {
  /// 当前选中的组件样式 tab 下标
  int _selectedTabIndex = 0;

  /// 当前选择的数据（经过 dataSelector 转换后的）
  Map<String, dynamic>? _selectedData;

  /// 原始的 SelectorResult（用于保存完整的配置信息）
  SelectorResult? _originalSelectorResult;

  /// 可用的公共小组件列表
  Map<String, Map<String, dynamic>> _availableCommonWidgets = {};

  @override
  void initState() {
    super.initState();

    // 如果小组件不需要选择数据，直接加载公共小组件
    if (widget.pluginWidget.selectorId == null) {
      _loadCommonWidgetsDirectly();
    }
    // 如果有初始选择器配置，自动恢复数据
    else if (widget.initialSelectorConfig != null) {
      Future.microtask(() => _restoreFromInitialConfig());
    }
  }

  /// 直接加载公共小组件（不需要选择数据的情况）
  void _loadCommonWidgetsDirectly() {
    // 先尝试刷新缓存，然后加载组件
    _refreshAndLoadWidgets();
  }

  /// 刷新缓存并加载组件
  Future<void> _refreshAndLoadWidgets() async {
    // 不需要选择数据，直接传入空数据
    final data = <String, dynamic>{};

    // 如果是 activity 插件，先刷新缓存
    final activityPlugin =
        widget.pluginWidget.pluginId == 'activity'
            ? PluginManager.instance.getPlugin('activity')
            : null;

    if (activityPlugin != null) {
      try {
        // 调用 ActivityPlugin 的刷新缓存方法
        await (activityPlugin as dynamic).refreshTodayActivitiesCache();
      } catch (e) {
        debugPrint('[CommonWidgetSelectorPage] 刷新缓存失败: $e');
      }
    }

    // 调用 commonWidgetsProvider 获取可用组件
    Map<String, Map<String, dynamic>> availableWidgets = {};
    if (widget.pluginWidget.commonWidgetsProvider != null) {
      try {
        debugPrint(
          '[CommonWidgetSelectorPage] 传入 commonWidgetsProvider 的数据: $data',
        );
        final result = await widget.pluginWidget.commonWidgetsProvider!(data);
        // 验证返回值类型并过滤无效配置
        availableWidgets = result;
      } catch (e) {
        debugPrint('[CommonWidgetSelectorPage] 加载组件失败: $e');
        availableWidgets = {};
      }
    }

    // 计算初始选中索引
    int initialIndex = 0;
    if (widget.initialCommonWidgetId != null) {
      final widgetIds = availableWidgets.keys.toList();
      initialIndex = widgetIds.indexOf(widget.initialCommonWidgetId!);
      if (initialIndex < 0) initialIndex = 0;
    }

    setState(() {
      _selectedData = data;
      _availableCommonWidgets = availableWidgets;
      // 自动选中指定的组件或第一个组件
      _selectedTabIndex = initialIndex;
    });
  }

  /// 从初始配置恢复数据
  Future<void> _restoreFromInitialConfig() async {
    final config = widget.initialSelectorConfig!;
    final selectedDataMap = config.selectedData;

    if (selectedDataMap == null) return;

    // 手动从 Map 恢复 SelectorResult（用于后续保存）
    final pluginId = selectedDataMap['plugin'] as String? ?? '';
    final selectorId = selectedDataMap['selector'] as String? ?? '';
    final pathData = selectedDataMap['path'] as List<dynamic>?;

    // 重建 SelectionPathItem 列表
    final List<SelectionPathItem> path = [];
    if (pathData != null) {
      for (final item in pathData) {
        if (item is Map<String, dynamic>) {
          path.add(
            SelectionPathItem(
              stepId: item['stepId'] as String? ?? '',
              stepTitle: item['stepTitle'] as String? ?? '',
              selectedItem: SelectableItem(
                id: item['selectedItemId'] as String? ?? '',
                title: item['selectedItemTitle'] as String? ?? '',
              ),
            ),
          );
        }
      }
    }

    // 重建 SelectorResult
    _originalSelectorResult = SelectorResult(
      pluginId: pluginId,
      selectorId: selectorId,
      path: path,
      data: selectedDataMap['data'],
    );

    // 转换数据格式
    Map<String, dynamic> data;
    final resultData = _originalSelectorResult!.data;
    if (resultData is SelectableItem) {
      // 单选：SelectableItem 对象，调用 toMap() 序列化
      data = resultData.toMap();
    } else if (resultData is Map) {
      final rawMap = resultData;
      data = {};
      rawMap.forEach((key, value) {
        data[key.toString()] = value;
      });
    } else if (resultData is List) {
      if (widget.pluginWidget.dataSelector != null) {
        // 使用自定义数据选择器
        data = widget.pluginWidget.dataSelector!(resultData);
      } else {
        // 传入原始数据，让 commonWidgetsProvider 处理
        data = {'data': resultData};
      }
    } else {
      data = {'data': resultData};
    }

    // 调用 commonWidgetsProvider 获取可用组件
    Map<String, Map<String, dynamic>> availableWidgets = {};
    if (widget.pluginWidget.commonWidgetsProvider != null) {
      try {
        debugPrint(
          '[CommonWidgetSelectorPage] 传入 commonWidgetsProvider 的数据: $data',
        );
        final result = await widget.pluginWidget.commonWidgetsProvider!(data);
        // 验证返回值类型并过滤无效配置
        availableWidgets = result;
      } catch (e) {
        debugPrint('[CommonWidgetSelectorPage] 加载组件失败: $e');
        availableWidgets = {};
      }
    }

    // 计算初始选中索引
    int initialIndex = 0;
    if (widget.initialCommonWidgetId != null) {
      final widgetIds = availableWidgets.keys.toList();
      initialIndex = widgetIds.indexOf(widget.initialCommonWidgetId!);
      if (initialIndex < 0) initialIndex = 0;
    }

    setState(() {
      _selectedData = data;
      _availableCommonWidgets = availableWidgets;
      // 自动选中指定的组件或第一个组件
      _selectedTabIndex = initialIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            backgroundColor: dsScaffoldBackground(theme),
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    DSLightHeader(
                      title: 'screens_selectCommonWidgetStyle'.tr,
                      trailing: DSIconButton(
                        icon: DsIconKind.check,
                        size: 38,
                        tooltip: 'app_confirm'.tr,
                        onPressed:
                            _availableCommonWidgets.isNotEmpty
                                ? _confirmSelection
                                : null,
                      ),
                    ),

                    // 数据选择器区域
                    _buildDataSelectorSection(context, theme),

                    Divider(height: 1, color: theme.stroke),

                    // 公共小组件预览区域 - 占据剩余空间
                    Expanded(child: _buildCommonWidgetsSection(context, theme)),
                  ],
                ),
              ),
          );
        },
      ),
    );
  }

  /// 构建数据选择器区域
  Widget _buildDataSelectorSection(BuildContext context, AppThemeData theme) {
    // 如果不需要选择数据，隐藏此区域
    if (widget.pluginWidget.selectorId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: _selectedData != null
                      ? theme.success
                      : theme.textSub,
                  circle: true,
                ),
                alignment: Alignment.center,
                child: Text(
                  '1',
                  style: TextStyle(
                    color: theme.onSuccess,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'screens_commonWidgetSelectData'.tr,
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: DSButton(
              label: 'screens_commonWidgetTapToSelect'.tr,
              onPressed: _selectedData == null ? _openDataSelector : null,
            ),
          ),
          if (_selectedData != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.success.withValues(alpha: 0.1),
                radius: theme.radii.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 100,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          const JsonEncoder.withIndent(
                            '  ',
                          ).convert(_selectedData),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSub,
                          ),
                        ),
                      ),
                    ),
                  ),
                  DSIconButton(
                    icon: DsIconKind.close,
                    size: 28,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    onPressed: () {
                      setState(() {
                        _selectedData = null;
                        _originalSelectorResult = null;
                        _availableCommonWidgets = {};
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建公共小组件区域
  Widget _buildCommonWidgetsSection(BuildContext context, AppThemeData theme) {
    // 如果需要选择数据但还没有选择，显示提示
    if (_selectedData == null && widget.pluginWidget.selectorId != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(DsIconKind.chevronUp, size: 48, color: theme.disabled),
            const SizedBox(height: 16),
            Text(
              'screens_commonWidgetSelectDataFirst'.tr,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          ],
        ),
      );
    }

    if (_availableCommonWidgets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(DsIconKind.block, size: 48, color: theme.warning),
            const SizedBox(height: 16),
            Text(
              'screens_commonWidgetNoAvailable'.tr,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: theme.success,
                  circle: true,
                ),
                alignment: Alignment.center,
                child: Text(
                  '2',
                  style: TextStyle(
                    color: theme.onSuccess,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'screens_commonWidgetSelectStyleCount'.trParams({
                  'count': _availableCommonWidgets.length.toString(),
                }),
                style: DsTypography.heading.copyWith(color: theme.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            // 组件样式区在数据选定后新挂载，WiredDraw 触发墨线描画入场
            child: WiredDraw(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final widgetIds = _availableCommonWidgets.keys.toList();
                  return DSTabs(
                    labels: [
                      for (final id in widgetIds)
                        CommonWidgetsRegistry.getMetadata(
                          _resolveCommonWidgetId(id),
                        ).name,
                    ],
                    selected: _selectedTabIndex,
                    onChanged: (index) =>
                        setState(() => _selectedTabIndex = index),
                    // PageView 需有界高度，取剩余空间
                    contentHeight: constraints.maxHeight,
                    children: [
                      for (final id in widgetIds)
                        _buildCommonWidgetPreviews(
                          theme,
                          CommonWidgetsRegistry.getMetadata(
                            _resolveCommonWidgetId(id),
                          ),
                          id,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 安全地查找 widgetId 对应的 CommonWidgetId，未匹配时回落默认值
  CommonWidgetId _resolveCommonWidgetId(String widgetId) {
    return CommonWidgetId.values.firstWhere(
      (e) => e.name == widgetId,
      orElse: () {
        debugPrint(
          '[CommonWidgetSelectorPage] 未找到匹配的 CommonWidgetId: $widgetId',
        );
        return CommonWidgetId.activityProgressCard;
      },
    );
  }

  /// 构建公共小组件预览（多个尺寸）
  Widget _buildCommonWidgetPreviews(
    AppThemeData theme,
    CommonWidgetMetadata metadata,
    String widgetId,
  ) {
    final props = _availableCommonWidgets[widgetId];

    // 验证 props 是否为有效的 Map
    if (props == null) {
      debugPrint('[CommonWidgetSelectorPage] 未找到组件配置: $widgetId');
      return Center(child: Text('screens_commonWidgetConfigError'.tr));
    }

    final matchingWidget = _resolveCommonWidgetId(widgetId);

    // 构建小组件预览的辅助方法
    Widget buildWidgetPreview(HomeWidgetSize size) {
      return Center(
        child: CommonWidgetBuilder.build(
          context,
          matchingWidget,
          props,
          size,
          inline: false,
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        // 底部操作区已上移至 header，滚动内容自行补底部安全区
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(theme, 'screens_commonWidgetSizeSmall'.tr),
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: buildWidgetPreview(const SmallSize()),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(theme, 'screens_commonWidgetSizeMedium'.tr),
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 220,
                height: 200,
                child: buildWidgetPreview(const MediumSize()),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(theme, 'screens_commonWidgetSizeLarge'.tr),
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 300,
                height: 280,
                child: buildWidgetPreview(const LargeSize()),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(theme, 'screens_commonWidgetSizeWide'.tr),
            const SizedBox(height: 8),
            SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              height: 280,
              child: buildWidgetPreview(const WideSize()),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(theme, 'screens_commonWidgetSizeWide2'.tr),
            const SizedBox(height: 8),
            SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              height: 350,
              child: buildWidgetPreview(const Wide2Size()),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建章节标题
  Widget _buildSectionTitle(AppThemeData theme, String title) {
    return Text(
      title,
      style: DsTypography.caption.copyWith(color: theme.textSub),
    );
  }

  /// 数据选择完成回调
  Future<void> _onDataSelected(SelectorResult? result) async {
    if (result == null) return;

    // 保存原始的 SelectorResult
    _originalSelectorResult = result;

    // 转换数据格式
    Map<String, dynamic> data;
    if (result.data is SelectableItem) {
      // 单选：SelectableItem 对象，调用 toMap() 序列化
      data = (result.data as SelectableItem).toMap();
    } else if (result.data is Map) {
      // 安全地转换 Map，确保键为 String 类型
      final rawMap = result.data as Map;
      data = {};
      rawMap.forEach((key, value) {
        data[key.toString()] = value;
      });
    } else if (result.data is List) {
      if (widget.pluginWidget.dataSelector != null) {
        // 使用自定义数据选择器
        data = widget.pluginWidget.dataSelector!(result.data);
      } else {
        // 传入原始数据，让 commonWidgetsProvider 处理
        data = {'data': result.data};
      }
    } else {
      data = {'data': result.data};
    }

    // 调用 commonWidgetsProvider 获取可用组件
    Map<String, Map<String, dynamic>> availableWidgets = {};
    if (widget.pluginWidget.commonWidgetsProvider != null) {
      try {
        debugPrint(
          '[CommonWidgetSelectorPage] 传入 commonWidgetsProvider 的数据: $data',
        );
        final result = await widget.pluginWidget.commonWidgetsProvider!(data);
        debugPrint(
          '[CommonWidgetSelectorPage] commonWidgetsProvider 返回的类型: ${result.runtimeType}',
        );
        debugPrint(
          '[CommonWidgetSelectorPage] commonWidgetsProvider 返回的键: ${result.keys.toList()}',
        );
        // 验证返回值类型并过滤无效配置
        availableWidgets = result;
      } catch (e) {
        debugPrint('[CommonWidgetSelectorPage] 加载组件失败: $e');
        availableWidgets = {};
      }
    }

    // 计算初始选中索引
    int initialIndex = 0;
    if (widget.initialCommonWidgetId != null) {
      final widgetIds = availableWidgets.keys.toList();
      initialIndex = widgetIds.indexOf(widget.initialCommonWidgetId!);
      if (initialIndex < 0) initialIndex = 0;
    }

    setState(() {
      _selectedData = data;
      _availableCommonWidgets = availableWidgets;
      // 自动选中指定的组件或第一个组件
      _selectedTabIndex = initialIndex;
    });
  }

  /// 打开数据选择器
  Future<void> _openDataSelector() async {
    final selectorId = widget.pluginWidget.selectorId;
    if (selectorId == null) return;

    try {
      final result = await pluginDataSelectorService.showSelector(
        context,
        selectorId,
      );
      _onDataSelected(result);
    } catch (e) {
      debugPrint('[CommonWidgetSelectorPage] 数据选择失败: $e');
    }
  }

  /// 确认选择
  Future<void> _confirmSelection() async {
    // 验证条件
    if (_availableCommonWidgets.isEmpty) {
      return;
    }
    if (widget.pluginWidget.selectorId != null &&
        (_selectedData == null || _originalSelectorResult == null)) {
      return;
    }

    // 从当前激活的 tab 获取选中的 widgetId
    final widgetId = _availableCommonWidgets.keys.elementAt(_selectedTabIndex);

    final layoutManager = HomeLayoutManager();

    // 创建基础配置
    final config = <String, dynamic>{};

    // 如果需要选择数据，保存 selectorConfig
    if (widget.pluginWidget.selectorId != null &&
        _originalSelectorResult != null) {
      // 使用原始 SelectorResult 的 toMap() 来保存完整的配置信息
      final selectorConfig = SelectorWidgetConfig(
        selectedData: _originalSelectorResult!.toMap(),
        lastUpdated: DateTime.now(),
        commonWidgetId: widgetId,
        commonWidgetProps: _availableCommonWidgets[widgetId],
      );
      config['selectorWidgetConfig'] = selectorConfig.toJson();
    } else {
      // 不需要选择数据，只保存公共小组件配置
      config['selectorWidgetConfig'] = {
        'commonWidgetId': widgetId,
        'commonWidgetProps': _availableCommonWidgets[widgetId],
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }

    // 如果有原有配置，合并自定义尺寸等信息
    if (widget.originalConfig != null) {
      // 保留 customWidth 和 customHeight（如果是自定义尺寸）
      if (widget.originalSize == const CustomSize(width: -1, height: -1)) {
        if (widget.originalConfig!.containsKey('customWidth')) {
          config['customWidth'] = widget.originalConfig!['customWidth'];
        }
        if (widget.originalConfig!.containsKey('customHeight')) {
          config['customHeight'] = widget.originalConfig!['customHeight'];
        }
      }
    }

    // 创建小组件实例，使用原有大小或默认大小
    final widgetItem = HomeWidgetItem(
      id: widget.replaceWidgetItemId ?? layoutManager.generateId(),
      widgetId: widget.pluginWidget.id,
      size: widget.originalSize ?? widget.pluginWidget.defaultSize,
      config: config,
    );

    // 替换或添加
    if (widget.replaceWidgetItemId != null) {
      layoutManager.updateItem(widget.replaceWidgetItemId!, widgetItem);
    } else if (widget.folderId != null) {
      layoutManager.addItemToFolder(widgetItem, widget.folderId!);
    } else {
      layoutManager.addItem(widgetItem);
    }

    // 等待布局保存完成，确保配置正确写入后再刷新界面
    await layoutManager.saveLayout();
    // 强制通知监听器刷新，确保新创建的小组件能正确读取配置
    layoutManager.notifyUpdate();

    Navigator.of(context).pop();

    Toast.success(
      widget.replaceWidgetItemId != null
          ? 'screens_commonWidgetReplaced'.tr
          : 'screens_commonWidgetAdded'.tr,
    );
  }
}
