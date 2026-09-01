# 选择器小组件注册指南

> 本文档用于快速为 Aboutme 插件注册数据选择器类型的 HomeWidget

## 概述

选择器小组件允许用户：
1. 在首页添加小组件时显示"点击配置"占位符
2. 点击后打开数据选择器选择插件数据
3. 选择后自动保存并显示自定义内容
4. 再次点击导航到详情页面

## 快速开始清单

完整注册一个选择器小组件需要完成以下步骤：

- [ ] **步骤 1**: 在插件中注册数据选择器 (`SelectorDefinition`)
- [ ] **步骤 2**: 在 `home_widgets.dart` 中注册选择器小组件
- [ ] **步骤 3**: 实现自定义数据渲染函数 (`dataRenderer`)
- [ ] **步骤 4**: 实现导航处理函数 (`navigationHandler`)
- [ ] **步骤 5**: 在 `route.dart` 中注册详情页路由

---

## 步骤 1: 注册数据选择器

**文件位置**: `lib/plugins/[plugin_name]/[plugin_name]_plugin.dart`

在插件的 `initialize()` 方法中调用选择器注册方法：

```dart
@override
Future<void> initialize() async {
  // ... 其他初始化代码 ...
  _registerDataSelectors();
}

void _registerDataSelectors() {
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: '[plugin_id].[selector_name]',  // 例如: 'diary.entry', 'chat.conversation'
      pluginId: '[plugin_id]',            // 例如: 'diary', 'chat'
      name: '[翻译键或显示名称]',           // 例如: 'diary_entrySelectorName'.tr
      selectionMode: SelectionMode.single, // 或 SelectionMode.multiple
      steps: [
        SelectorStep(
          id: 'select_[item]',
          title: '[选择步骤标题]',
          viewType: SelectorViewType.list, // 或 .grid, .tree
          dataLoader: (previousSelections) async {
            // 加载可选数据
            final items = await _loadSelectableItems();
            return items.map((item) => SelectableItem(
              id: item.id,
              title: item.title,
              subtitle: item.subtitle,
              icon: Icons.[icon_name],
              rawData: item.toJson(), // 重要：保存完整数据供后续使用
            )).toList();
          },
          isFinalStep: true,
        ),
      ],
    ),
  );
}
```

### 关键参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `id` | 选择器唯一标识 | `'webview.card'`, `'diary.entry'` |
| `pluginId` | 所属插件 ID | `'webview'`, `'diary'` |
| `selectionMode` | 单选/多选 | `SelectionMode.single` |
| `rawData` | **必须**包含完整数据的 JSON Map | `card.toJson()` |

---

## 步骤 2: 注册选择器小组件

**文件位置**: `lib/plugins/[plugin_name]/home_widgets.dart`

在 `registerWidgets()` 方法中添加：

```dart
import 'package:aboutme/screens/home_screen/widgets/generic_selector_widget.dart';
import 'package:aboutme/screens/home_screen/models/home_widget.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/plugin_data_selector/models/selector_result.dart';

class [PluginName]HomeWidgets {
  static void registerWidgets(HomeWidgetRegistry registry) {
    // ... 其他小组件注册 ...

    registry.register(
      HomeWidget(
        id: '[plugin_id]_[widget_name]_selector',  // 例如: 'diary_entry_selector'
        pluginId: '[plugin_id]',
        name: '[小组件显示名称]'.tr,
        icon: Icons.[icon_name],
        defaultSize: HomeWidgetSize.large,         // 根据需要调整
        supportedSizes: [
          HomeWidgetSize.medium,
          HomeWidgetSize.large,
        ],
        category: 'home_category[Category]'.tr,

        // === 选择器特定字段 ===
        selectorId: '[plugin_id].[selector_name]', // 与步骤1中的id对应
        dataRenderer: _render[Item]Data,           // 自定义渲染函数
        navigationHandler: _navigateTo[Item],      // 导航处理函数

        builder: (context, config) {
          return GenericSelectorWidget(
            widgetDefinition: registry.getWidget('[plugin_id]_[widget_name]_selector')!,
            config: config,
          );
        },
      ),
    );
  }

  // 步骤 3 和 4 的函数实现见下方
}
```

### 关键字段说明

| 字段 | 必填 | 说明 |
|------|------|------|
| `selectorId` | ✅ | 必须与步骤 1 中注册的选择器 ID 完全一致 |
| `dataRenderer` | ✅ | 自定义渲染函数，显示选中的数据 |
| `navigationHandler` | ✅ | 导航函数，点击已配置的小组件时调用 |
| `builder` | ✅ | 固定使用 `GenericSelectorWidget` |

---

## 步骤 3: 实现数据渲染函数

**文件位置**: `lib/plugins/[plugin_name]/home_widgets.dart` (静态方法)

```dart
/// 渲染选中的数据
///
/// 参数:
/// - context: BuildContext
/// - result: SelectorResult (包含选中的数据)
/// - config: Map<String, dynamic> (小组件配置)
static Widget _render[Item]Data(
  BuildContext context,
  SelectorResult result,
  Map<String, dynamic> config,
) {
  // 1. 从 result.data 中提取数据
  final itemData = result.data as Map<String, dynamic>;
  final title = itemData['title'] as String? ?? 'Unknown';
  final subtitle = itemData['subtitle'] as String? ?? '';
  final iconData = itemData['icon'] as String?;

  // 2. 自定义 UI 显示
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                if (iconData != null)
                  Icon(IconData(int.parse(iconData), fontFamily: 'MaterialIcons')),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // 副标题/描述
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // 其他自定义内容（如标签、日期等）
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '点击查看详情',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
```

### 设计建议

- **使用 `result.data`**: 这是步骤 1 中 `rawData` 保存的完整数据
- **适配小组件尺寸**: 根据 `config['size']` 调整显示内容
- **Material Design**: 使用 `Material` + `InkWell` 实现水波纹效果
- **响应式布局**: 使用 `Expanded`、`Flexible` 适配不同屏幕

---

## 步骤 4: 实现导航处理函数

**文件位置**: `lib/plugins/[plugin_name]/home_widgets.dart` (静态方法)

```dart
/// 导航到详情页面
///
/// 参数:
/// - context: BuildContext
/// - result: SelectorResult (包含选中的数据)
static void _navigateTo[Item](
  BuildContext context,
  SelectorResult result,
) {
  // 1. 从 result.data 中提取导航所需参数
  final itemData = result.data as Map<String, dynamic>;
  final itemId = itemData['id'] as String;

  // 可选：提取其他参数
  final title = itemData['title'] as String?;
  final extraParam = itemData['extraParam'] as String?;

  // 2. 导航到详情页
  NavigationHelper.pushNamed(
    context,
    '/[plugin_id]/[detail_screen]',  // 例如: '/diary/entry', '/webview/browser'
    arguments: {
      'id': itemId,
      'title': title,
      'extraParam': extraParam,
      // 根据详情页需要传递参数
    },
  );
}
```

### 导航方式选择

| 方式 | 使用场景 | 示例 |
|------|----------|------|
| `NavigationHelper.pushNamed` | 跨插件导航，需要在 `route.dart` 注册 | `/webview/browser` |
| `Navigator.push` | 简单页面跳转 | `MaterialPageRoute(builder: ...)` |
| 插件内部路由 | 插件有自己的路由系统 | 调用插件的路由方法 |

---

## 步骤 5: 注册详情页路由

**文件位置**: `lib/screens/route.dart`

### 5.1 添加导入

```dart
import 'package:aboutme/plugins/[plugin_name]/screens/[detail_screen].dart';
```

### 5.2 在 `generateRoute` 方法中添加路由

```dart
static Route<dynamic>? generateRoute(RouteSettings settings) {
  debugPrint('导航到: ${settings.name}, 参数: ${settings.arguments}');

  switch (settings.name) {
    // ... 其他路由 ...

    case '/[plugin_id]/[detail_screen]':
    case '[plugin_id]/[detail_screen]':  // 支持无前导斜杠
      // 提取参数
      String? id;
      String? title;
      Map<String, dynamic>? extraData;

      if (settings.arguments is Map<String, dynamic>) {
        final args = settings.arguments as Map<String, dynamic>;
        id = args['id'] as String?;
        title = args['title'] as String?;
        extraData = args['extraData'] as Map<String, dynamic>?;
      }

      debugPrint('打开详情页: id=$id, title=$title');

      return _createRoute(
        [DetailScreen](
          id: id,
          title: title,
          extraData: extraData,
        ),
      );

    // ... 其他路由 ...
  }
}
```

### 路由注册要点

- **双路由支持**: 同时注册 `/path` 和 `path` (无前导斜杠)
- **参数类型检查**: 使用 `as String?` 安全转换
- **调试日志**: 添加 `debugPrint` 方便排查问题
- **使用 `_createRoute`**: 统一路由转场动画

---

## 完整示例: Diary 插件

以下是一个完整的日记插件选择器小组件实现示例。

### 1. 注册选择器 (`diary_plugin.dart`)

```dart
void _registerDataSelectors() {
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'diary.entry',
      pluginId: 'diary',
      name: 'diary_entrySelectorName'.tr,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'select_entry',
          title: 'diary_selectEntry'.tr,
          viewType: SelectorViewType.list,
          dataLoader: (previousSelections) async {
            final entries = await diaryService.getAllEntries();
            return entries.map((entry) => SelectableItem(
              id: entry.id,
              title: entry.title ?? DateFormat.yMd().format(entry.date),
              subtitle: entry.content.substring(0, 100),
              icon: Icons.book,
              rawData: {
                'id': entry.id,
                'title': entry.title,
                'date': entry.date.toIso8601String(),
                'content': entry.content,
                'mood': entry.mood,
              },
            )).toList();
          },
          isFinalStep: true,
        ),
      ],
    ),
  );
}
```

### 2. 注册小组件 (`diary/home_widgets.dart`)

```dart
registry.register(
  HomeWidget(
    id: 'diary_entry_selector',
    pluginId: 'diary',
    name: 'diary_quickAccessWidget'.tr,
    icon: Icons.auto_stories,
    defaultSize: HomeWidgetSize.large,
    supportedSizes: [HomeWidgetSize.medium, HomeWidgetSize.large],
    category: 'home_categoryContent'.tr,

    selectorId: 'diary.entry',
    dataRenderer: _renderEntryData,
    navigationHandler: _navigateToEntry,

    builder: (context, config) {
      return GenericSelectorWidget(
        widgetDefinition: registry.getWidget('diary_entry_selector')!,
        config: config,
      );
    },
  ),
);
```

### 3. 渲染函数

```dart
static Widget _renderEntryData(
  BuildContext context,
  SelectorResult result,
  Map<String, dynamic> config,
) {
  final entryData = result.data as Map<String, dynamic>;
  final title = entryData['title'] as String? ?? 'Untitled';
  final content = entryData['content'] as String? ?? '';
  final dateStr = entryData['date'] as String?;
  final mood = entryData['mood'] as String?;

  final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();

  return Material(
    color: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              Text(
                DateFormat.yMd().format(date),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Spacer(),
              if (mood != null)
                Text(
                  _getMoodEmoji(mood),
                  style: const TextStyle(fontSize: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

static String _getMoodEmoji(String mood) {
  const moodMap = {
    'happy': '😊',
    'sad': '😢',
    'neutral': '😐',
    'excited': '🤩',
  };
  return moodMap[mood] ?? '📝';
}
```

### 4. 导航函数

```dart
static void _navigateToEntry(
  BuildContext context,
  SelectorResult result,
) {
  final entryData = result.data as Map<String, dynamic>;
  final entryId = entryData['id'] as String;

  NavigationHelper.pushNamed(
    context,
    '/diary/entry',
    arguments: {'entryId': entryId},
  );
}
```

### 5. 注册路由 (`route.dart`)

```dart
import 'package:aboutme/plugins/diary/screens/diary_entry_screen.dart';

// 在 generateRoute 中:
case '/diary/entry':
case 'diary/entry':
  String? entryId;

  if (settings.arguments is Map<String, dynamic>) {
    final args = settings.arguments as Map<String, dynamic>;
    entryId = args['entryId'] as String?;
  }

  return _createRoute(
    DiaryEntryScreen(entryId: entryId),
  );
```

---

## 常见问题排查

### 问题 1: 点击小组件没有反应

**检查清单**:
- [ ] `selectorId` 是否与 `SelectorDefinition.id` 完全一致？
- [ ] `dataRenderer` 和 `navigationHandler` 是否都已实现？
- [ ] `GenericSelectorWidget` 的 `widgetDefinition` 是否正确获取？

### 问题 2: 导航后页面一直转圈圈

**原因**: 路由未注册或路由路径不匹配

**解决**:
1. 检查 `route.dart` 中是否已添加路由 case
2. 确认路由路径拼写正确（注意大小写）
3. 检查是否同时注册了 `/path` 和 `path` 两种形式

### 问题 3: 选择后数据丢失

**原因**: `rawData` 未正确保存

**解决**:
- 在 `SelectableItem` 中确保 `rawData` 包含完整的数据
- 使用 `item.toJson()` 而不是手动构造 Map
- 确认数据可以被 JSON 序列化

### 问题 4: 自定义渲染不显示

**原因**: `dataRenderer` 返回的 Widget 有问题

**解决**:
- 确保返回的 Widget 有明确的尺寸
- 检查是否有布局错误（使用 `flutter run` 查看错误）
- 简化 Widget 树逐步调试

---

## 最佳实践

### 1. 数据持久化

```dart
// ✅ 推荐：使用完整的模型 toJson()
rawData: entry.toJson()

// ❌ 避免：手动构造不完整的数据
rawData: {'id': entry.id, 'title': entry.title}
```

### 2. 空值处理

```dart
// ✅ 推荐：使用安全的空值处理
final title = itemData['title'] as String? ?? 'Untitled';
final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();

// ❌ 避免：直接访问可能为 null 的值
final title = itemData['title'] as String;  // 可能抛出异常
```

### 3. UI 响应式

```dart
// ✅ 推荐：使用主题颜色和响应式布局
color: Theme.of(context).colorScheme.primaryContainer
style: Theme.of(context).textTheme.titleMedium

// ❌ 避免：硬编码颜色和字体大小
color: Colors.blue
style: TextStyle(fontSize: 16)
```

### 4. 路由参数验证

```dart
// ✅ 推荐：验证必需参数
if (id == null) {
  debugPrint('错误: 缺少必需参数 id');
  return _createRoute(ErrorScreen(message: '参数错误'));
}

// ❌ 避免：直接使用可能为 null 的参数
return _createRoute(DetailScreen(id: id!));  // 可能崩溃
```

---

## 附录: 类型定义参考

### SelectorResult

```dart
class SelectorResult {
  final String selectorId;        // 选择器 ID
  final dynamic data;             // 选中的数据 (通常是 Map<String, dynamic>)
  final List<String> selectedIds; // 选中的 ID 列表
  final DateTime timestamp;       // 选择时间
}
```

### HomeWidget 选择器相关字段

```dart
class HomeWidget {
  final String? selectorId;                    // 选择器 ID
  final SelectorDataRenderer? dataRenderer;    // 数据渲染函数
  final SelectorNavigationHandler? navigationHandler; // 导航处理函数

  bool get isSelectorWidget => selectorId != null;
}
```

### 函数类型定义

```dart
typedef SelectorDataRenderer = Widget Function(
  BuildContext context,
  SelectorResult result,
  Map<String, dynamic> config,
);

typedef SelectorNavigationHandler = void Function(
  BuildContext context,
  SelectorResult result,
);
```

---

## 快速复制模板

### 插件选择器注册模板

```dart
// 在 [plugin_name]_plugin.dart 中
void _registerDataSelectors() {
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'PLUGIN_ID.SELECTOR_NAME',
      pluginId: 'PLUGIN_ID',
      name: 'TRANSLATION_KEY'.tr,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'select_item',
          title: 'STEP_TITLE'.tr,
          viewType: SelectorViewType.list,
          dataLoader: (previousSelections) async {
            // TODO: 实现数据加载
            return [];
          },
          isFinalStep: true,
        ),
      ],
    ),
  );
}
```

### 小组件注册模板

```dart
// 在 home_widgets.dart 中
registry.register(
  HomeWidget(
    id: 'PLUGIN_ID_WIDGET_NAME_selector',
    pluginId: 'PLUGIN_ID',
    name: 'WIDGET_NAME'.tr,
    icon: Icons.ICON_NAME,
    defaultSize: HomeWidgetSize.large,
    supportedSizes: [HomeWidgetSize.medium, HomeWidgetSize.large],
    category: 'CATEGORY'.tr,

    selectorId: 'PLUGIN_ID.SELECTOR_NAME',
    dataRenderer: _renderData,
    navigationHandler: _navigate,

    builder: (context, config) {
      return GenericSelectorWidget(
        widgetDefinition: registry.getWidget('PLUGIN_ID_WIDGET_NAME_selector')!,
        config: config,
      );
    },
  ),
);

static Widget _renderData(BuildContext context, SelectorResult result, Map<String, dynamic> config) {
  // TODO: 实现渲染逻辑
  return Container();
}

static void _navigate(BuildContext context, SelectorResult result) {
  // TODO: 实现导航逻辑
}
```

### 路由注册模板

```dart
// 在 route.dart 中
case '/PLUGIN_ID/SCREEN_NAME':
case 'PLUGIN_ID/SCREEN_NAME':
  String? itemId;

  if (settings.arguments is Map<String, dynamic>) {
    final args = settings.arguments as Map<String, dynamic>;
    itemId = args['itemId'] as String?;
  }

  debugPrint('打开页面: itemId=$itemId');

  return _createRoute(
    ScreenName(itemId: itemId),
  );
```

---

## 结语

选择器小组件框架遵循以下设计原则：

- **关注点分离**: 显示和交互逻辑分离
- **类型安全**: 使用 typedef 确保函数签名正确
- **通用性**: 任何插件都可以使用
- **可扩展**: 支持自定义渲染和导航逻辑

按照本指南的步骤操作，您可以在 5-10 分钟内为任何插件添加选择器小组件支持。

如有疑问，请参考 WebView 插件的完整实现：
- `lib/plugins/webview/webview_plugin.dart`
- `lib/plugins/webview/home_widgets.dart`
- `lib/screens/route.dart` (搜索 `/webview/browser`)
