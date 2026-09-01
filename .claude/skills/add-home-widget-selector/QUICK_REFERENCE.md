# HomeWidget Selector 快速参考

## 🚀 快速开始（5步）

### 1. 注册数据选择器（在 plugin 文件中）

```dart
void _registerDataSelectors() {
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'PLUGIN_ID.SELECTOR_NAME',
      pluginId: 'PLUGIN_ID',
      name: 'SELECTOR_NAME'.tr,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'select_item',
          title: 'SELECT_TITLE'.tr,
          viewType: SelectorViewType.list,
          dataLoader: (previousSelections) async {
            final items = await _loadItems();
            return items.map((item) => SelectableItem(
              id: item.id,
              title: item.title,
              subtitle: item.subtitle,
              icon: Icons.icon_name,
              rawData: item.toJson(),  // 必须包含完整数据
            )).toList();
          },
          isFinalStep: true,
        ),
      ],
    ),
  );
}
```

### 2. 创建 home_widgets.dart

```dart
import 'package:aboutme/screens/home_screen/widgets/generic_selector_widget.dart';
import 'package:aboutme/core/services/plugin_data_selector/models/selector_result.dart';

class PluginNameHomeWidgets {
  static void register(HomeWidgetRegistry registry) {
    registry.register(
      HomeWidget(
        id: 'PLUGIN_ID_widget_name',
        pluginId: 'PLUGIN_ID',
        name: 'WIDGET_NAME'.tr,
        icon: Icons.ICON_NAME,
        defaultSize: HomeWidgetSize.large,
        supportedSizes: [HomeWidgetSize.medium, HomeWidgetSize.large],
        category: 'CATEGORY'.tr,

        selectorId: 'PLUGIN_ID.SELECTOR_NAME',
        dataRenderer: _renderData,
        navigationHandler: _navigateToDetail,

        builder: (context, config) {
          return GenericSelectorWidget(
            widgetDefinition: registry.getWidget('PLUGIN_ID_widget_name')!,
            config: config,
          );
        },
      ),
    );
  }
}
```

### 3. 实现 dataSelector（提取必要数据）

```dart
/// 从选择器数据中提取必要字段（保存到本地存储）
static Map<String, dynamic> _extractWidgetData(List<dynamic> dataArray) {
  final itemData = dataArray[0] as Map<String, dynamic>;
  return {
    'id': itemData['id'] as String,        // 必须保存 id
    'title': itemData['title'] as String?,
    // 只保存必要数据，不要保存大字段
  };
}
```

### 4. 实现 dataRenderer（获取最新数据）

```dart
/// 渲染小组件数据（通过 controller 获取最新数据）
static Widget _renderData(
  BuildContext context,
  SelectorResult result,
  Map<String, dynamic> config,
) {
  final savedData = result.data is Map<String, dynamic>
      ? result.data as Map<String, dynamic>
      : {};
  final itemId = savedData['id'] as String? ?? '';

  return FutureBuilder<Item?>(
    future: _loadLatestData(itemId),  // ✅ 关键：通过 controller 获取最新数据
    builder: (context, snapshot) {
      final data = snapshot.data ?? savedData;
      return _buildWidgetUI(context, data);
    },
  );
}

/// 从 controller 加载最新数据
static Future<Item?> _loadLatestData(String itemId) async {
  try {
    final plugin = PluginManager.instance.getPlugin('PLUGIN_ID') as PluginClass?;
    return await plugin?.controller.getItemById(itemId);
  } catch (e) {
    debugPrint('加载数据失败: $e');
    return null;
  }
}
```

### 5. 实现 navigationHandler（导航到详情页）

```dart
static void _navigateToDetail(BuildContext context, SelectorResult result) {
  final data = result.data is Map<String, dynamic>
      ? result.data as Map<String, dynamic>
      : {};
  final itemId = data['id'] as String?;

  NavigationHelper.pushNamed(
    context,
    '/PLUGIN_ID/detail',
    arguments: {'id': itemId},
  );
}
```

---

## 📋 常用模板

### 基础小组件模板

```dart
class PluginNameHomeWidgets {
  static void register(HomeWidgetRegistry registry) {
    registry.register(
      HomeWidget(
        id: 'PLUGIN_ID_selector',
        pluginId: 'PLUGIN_ID',
        name: 'WIDGET_NAME'.tr,
        icon: Icons.ICON_NAME,
        color: Colors.PRIMARY_COLOR,
        defaultSize: HomeWidgetSize.large,
        supportedSizes: [HomeWidgetSize.medium, HomeWidgetSize.large],
        category: 'CATEGORY'.tr,

        selectorId: 'PLUGIN_ID.SELECTOR_NAME',
        dataRenderer: _renderData,
        navigationHandler: _navigateToDetail,

        builder: (context, config) {
          return GenericSelectorWidget(
            widgetDefinition: registry.getWidget('PLUGIN_ID_selector')!,
            config: config,
          );
        },
      ),
    );
  }

  static Map<String, dynamic> _extractData(List<dynamic> dataArray) {
    final item = dataArray[0] as Map<String, dynamic>;
    return {'id': item['id'] as String, 'title': item['title'] as String?};
  }

  static Widget _renderData(BuildContext context, SelectorResult result, Map<String, dynamic> config) {
    final savedData = result.data as Map<String, dynamic>;
    final id = savedData['id'] as String? ?? '';

    return FutureBuilder<Item?>(
      future: _loadLatestData(id),
      builder: (context, snapshot) {
        final item = snapshot.data;
        final title = item?.title ?? savedData['title'] ?? 'Unknown';
        final subtitle = item?.subtitle ?? savedData['subtitle'] ?? '';

        return _buildUI(context, title, subtitle);
      },
    );
  }

  static Future<Item?> _loadLatestData(String id) async {
    final plugin = PluginManager.instance.getPlugin('PLUGIN_ID') as PluginClass?;
    return id.isNotEmpty ? await plugin?.controller.getItemById(id) : null;
  }

  static Widget _buildUI(BuildContext context, String title, String subtitle) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void _navigateToDetail(BuildContext context, SelectorResult result) {
    final data = result.data as Map<String, dynamic>;
    final id = data['id'] as String?;
    NavigationHelper.pushNamed(context, '/PLUGIN_ID/detail', arguments: {'id': id});
  }
}
```

---

## 🔧 关键概念

### dataSelector vs dataRenderer

| 函数 | 作用 | 数据来源 |
|------|------|---------|
| `dataSelector` | 提取必要字段保存到存储 | 选择器返回的 `rawData` |
| `dataRenderer` | 获取最新数据并渲染 UI | 通过 controller 传递 id 获取 |

### 为什么必须用 controller 获取最新数据？

```dart
// ❌ 错误：只使用保存的数据
static Widget _renderData(...) {
  final data = result.data as Map<String, dynamic>;  // 使用旧数据
  return _buildWidgetUI(context, data);
}

// ✅ 正确：通过 controller 获取最新数据
static Widget _renderData(...) {
  final savedData = result.data as Map<String, dynamic>;
  final id = savedData['id'] as String? ?? '';

  return FutureBuilder<Item?>(
    future: plugin.controller.getItemById(id),  // 获取最新数据
    builder: (context, snapshot) {
      final latestData = snapshot.data ?? savedData;
      return _buildWidgetUI(context, latestData);
    },
  );
}
```

---

## 🌍 国际化字符串

### 中文 (zh)

```dart
'PLUGIN_ID_widgetName': '小组件名称',
'PLUGIN_ID_widgetDescription': '小组件描述',
'PLUGIN_ID_selectTitle': '选择项目',
'PLUGIN_ID_clickToConfigure': '点击配置',
'PLUGIN_ID_clickToView': '点击查看详情',
```

### 英文 (en)

```dart
'PLUGIN_ID_widgetName': 'Widget Name',
'PLUGIN_ID_widgetDescription': 'Widget description',
'PLUGIN_ID_selectTitle': 'Select Item',
'PLUGIN_ID_clickToConfigure': 'Tap to configure',
'PLUGIN_ID_clickToView': 'Tap to view details',
```

---

## ✅ 检查清单

- [ ] 在插件中注册了 `SelectorDefinition`
- [ ] 小组件的 `selectorId` 与选择器 ID 一致
- [ ] `dataSelector` 只保存必要字段（包含 `id`）
- [ ] `dataRenderer` 通过 controller 获取最新数据
- [ ] `navigationHandler` 正确导航到详情页
- [ ] 在 `route.dart` 中注册了详情页路由
- [ ] 添加了所有国际化字符串
- [ ] 运行 `flutter analyze` 无错误

---

## 🐛 常见问题

### Q: 小组件显示的数据是旧的？

确保 `dataRenderer` 使用 `FutureBuilder` 调用 controller 获取最新数据。

### Q: 选择后数据丢失？

检查 `dataSelector` 是否返回了正确的 `Map<String, dynamic>`，且包含 `id` 字段。

### Q: 点击小组件没反应？

检查 `navigationHandler` 是否已实现，以及路由是否注册。

### Q: 如何支持多选？

在 `SelectorDefinition` 中设置 `selectionMode: SelectionMode.multiple`，并更新 `dataSelector` 处理数组。

---

## 📚 更多信息

- 完整文档：`SKILL.md`
- 选择器指南：`docs/SELECTOR_WIDGET_GUIDE.md`
- 账单插件示例：`lib/plugins/bill/home_widgets.dart`
- WebView 插件示例：`lib/plugins/webview/home_widgets.dart`
