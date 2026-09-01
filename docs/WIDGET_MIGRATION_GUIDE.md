# Memento 小组件新架构使用指南

> **版本**: 2.0
> **更新日期**: 2025-11-30
> **适用范围**: Memento 2.0+ (基于 memento_widgets 插件)

## 目录

- [架构概述](#架构概述)
- [快速开始](#快速开始)
- [小组件注册](#小组件注册)
- [数据更新 API](#数据更新-api)
- [数据模型](#数据模型)
- [完整示例](#完整示例)
- [迁移指南](#迁移指南)
- [常见问题](#常见问题)
- [最佳实践](#最佳实践)

---

## 架构概述

### 1.1 整体架构

Memento 2.0 采用**插件化小组件架构**，所有 Android 小组件代码已迁移到独立的 `memento_widgets` Flutter 插件中。

```
┌─────────────────────────────────────────────────┐
│          Memento 主应用 (Flutter)                │
│  ┌───────────────────────────────────────┐      │
│  │   SystemWidgetService                 │      │
│  │   - updateWidgetData()                │      │
│  │   - updateWidget()                    │      │
│  │   - updateAllWidgets()                │      │
│  └────────────┬──────────────────────────┘      │
│               │ 调用                             │
│               ▼                                  │
│  ┌───────────────────────────────────────┐      │
│  │   PluginWidgetSyncHelper              │      │
│  │   - syncTodo()                        │      │
│  │   - syncDiary()                       │      │
│  │   - sync[PluginName]()                │      │
│  └────────────┬──────────────────────────┘      │
└───────────────┼──────────────────────────────────┘
                │
                │ 依赖
                ▼
┌─────────────────────────────────────────────────┐
│       memento_widgets 插件 (Flutter)             │
│  ┌───────────────────────────────────────┐      │
│  │   MyWidgetManager (Dart API)          │      │
│  │   - updatePluginWidgetData()          │      │
│  │   - updatePluginWidget()              │      │
│  │   - updateAllPluginWidgets()          │      │
│  └────────────┬──────────────────────────┘      │
│               │ 通过 SharedPreferences           │
│               ▼                                  │
│  ┌───────────────────────────────────────┐      │
│  │   Android 原生代码 (Kotlin)            │      │
│  │   - BasePluginWidgetProvider          │      │
│  │   - 40 个插件 Provider                 │      │
│  │   - 2 个快速小组件                     │      │
│  └───────────────────────────────────────┘      │
└─────────────────────────────────────────────────┘
                │
                │ 渲染到
                ▼
        Android 系统桌面小组件
```

### 1.2 关键组件

| 组件 | 位置 | 职责 |
|------|------|------|
| **SystemWidgetService** | `lib/core/services/` | 主应用统一入口，提供简化的 API |
| **PluginWidgetSyncHelper** | `lib/core/services/` | 各插件数据同步逻辑集中管理 |
| **MyWidgetManager** | `packages/memento_widgets/lib/` | Flutter 插件 API，封装 home_widget |
| **PluginWidgetData** | `packages/memento_widgets/lib/models/` | 小组件数据模型 |
| **WidgetStatItem** | `packages/memento_widgets/lib/models/` | 统计项数据模型 |
| **BasePluginWidgetProvider** | `memento_widgets/android/` | Kotlin 小组件基类 |

### 1.3 数据流

```
插件数据更新
    ↓
调用 SystemWidgetService.updateWidgetData()
    ↓
调用 MyWidgetManager.updatePluginWidgetData()
    ↓
保存到 SharedPreferences ("HomeWidgetPreferences")
    ↓
触发 BasePluginWidgetProvider.onUpdate()
    ↓
从 SharedPreferences 读取数据
    ↓
渲染 RemoteViews
    ↓
更新系统桌面小组件
```

---

## 快速开始

### 2.1 添加依赖

在插件中引入 memento_widgets：

```dart
// 在插件文件顶部导入
import 'package:memento_widgets/memento_widgets.dart';
```

### 2.2 基础使用

```dart
// 1. 创建小组件数据
final widgetData = PluginWidgetData(
  pluginId: 'todo',
  pluginName: '待办事项',
  iconCodePoint: Icons.check_box.codePoint,
  colorValue: Colors.blue.value,
  stats: [
    WidgetStatItem(id: 'total', label: '总任务', value: '10'),
    WidgetStatItem(id: 'incomplete', label: '未完成', value: '3'),
  ],
);

// 2. 更新小组件
await SystemWidgetService.instance.updateWidgetData('todo', widgetData);
```

### 2.3 三行代码更新小组件

```dart
import 'package:memento_widgets/memento_widgets.dart';

final data = PluginWidgetData(/* ... */);
await SystemWidgetService.instance.updateWidgetData('your_plugin_id', data);
```

---

## 小组件注册

### 3.1 已注册的插件小组件

以下 20 个插件已自动注册小组件支持（每个插件包含 1x1 和 2x2 两种尺寸）：

| 插件 ID | 插件名称 | Provider 类名 |
|---------|---------|--------------|
| `todo` | 待办事项 | TodoWidgetProvider |
| `timer` | 计时器 | TimerWidgetProvider |
| `bill` | 账单 | BillWidgetProvider |
| `calendar` | 日历 | CalendarWidgetProvider |
| `activity` | 活动 | ActivityWidgetProvider |
| `tracker` | 目标追踪 | TrackerWidgetProvider |
| `habits` | 习惯 | HabitsWidgetProvider |
| `diary` | 日记 | DiaryWidgetProvider |
| `checkin` | 签到 | CheckinWidgetProvider |
| `nodes` | 节点 | NodesWidgetProvider |
| `database` | 数据库 | DatabaseWidgetProvider |
| `contact` | 联系人 | ContactWidgetProvider |
| `day` | 纪念日 | DayWidgetProvider |
| `goods` | 物品管理 | GoodsWidgetProvider |
| `notes` | 笔记 | NotesWidgetProvider |
| `store` | 商店 | StoreWidgetProvider |
| `openai` | AI助手 | OpenaiWidgetProvider |
| `agent_chat` | AI对话 | AgentChatWidgetProvider |
| `calendar_album` | 日记相册 | CalendarAlbumWidgetProvider |
| `chat` | 聊天 | ChatWidgetProvider |

### 3.2 插件 ID 映射

插件 ID 到 Provider 名称的映射在 `MyWidgetManager._getProviderName()` 中定义：

```dart
// packages/memento_widgets/lib/memento_widgets.dart
String? _getProviderName(String pluginId) {
  const providerMap = {
    'todo': 'TodoWidgetProvider',
    'timer': 'TimerWidgetProvider',
    // ... 其他 18 个映射
  };
  return providerMap[pluginId];
}
```

### 3.3 添加新插件小组件

如果需要为新插件添加小组件支持，需要以下步骤：

#### 步骤 1: 创建 Provider 类

在 `memento_widgets/android/src/main/kotlin/github/hunmer/memento/widgets/providers/` 创建：

```kotlin
// YourPluginWidgetProvider.kt
package github.hunmer.memento.widgets.providers

import github.hunmer.memento.widgets.BasePluginWidgetProvider

class YourPluginWidgetProvider : BasePluginWidgetProvider() {
    override val pluginId: String = "your_plugin"
    override val widgetSize: WidgetSize = WidgetSize.SIZE_1X1
}

class YourPluginWidget2x1Provider : BasePluginWidgetProvider() {
    override val pluginId: String = "your_plugin"
    override val widgetSize: WidgetSize = WidgetSize.SIZE_2X2
}
```

#### 步骤 2: 注册 Receiver

在 `memento_widgets/android/src/main/AndroidManifest.xml` 添加：

```xml
<!-- 1x1 小组件 -->
<receiver
    android:name="github.hunmer.memento.widgets.providers.YourPluginWidgetProvider"
    android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/widget_plugin_1x1_info" />
</receiver>

<!-- 2x2 小组件 -->
<receiver
    android:name="github.hunmer.memento.widgets.providers.YourPluginWidget2x1Provider"
    android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/widget_plugin_2x1_info" />
</receiver>
```

#### 步骤 3: 添加插件 ID 映射

在 `packages/memento_widgets/lib/memento_widgets.dart` 的 `_getProviderName()` 中添加：

```dart
String? _getProviderName(String pluginId) {
  const providerMap = {
    // ... 现有映射
    'your_plugin': 'YourPluginWidgetProvider',
  };
  return providerMap[pluginId];
}
```

#### 步骤 4: 添加到所有 Provider 列表

在 `_getAllProviderNames()` 中添加：

```dart
List<String> _getAllProviderNames() {
  return [
    // ... 现有 Provider
    'YourPluginWidgetProvider',
  ];
}
```

#### 步骤 5: 在主应用中添加同步逻辑

在 `lib/core/services/plugin_widget_sync_helper.dart` 中添加：

```dart
/// 同步您的插件
Future<void> syncYourPlugin() async {
  try {
    final plugin = PluginManager.instance.getPlugin('your_plugin') as YourPlugin?;
    if (plugin == null) return;

    // 获取统计数据
    final stat1 = plugin.getStat1();
    final stat2 = plugin.getStat2();

    await _updateWidget(
      pluginId: 'your_plugin',
      pluginName: '您的插件',
      iconCodePoint: Icons.your_icon.codePoint,
      colorValue: Colors.yourColor.value,
      stats: [
        WidgetStatItem(id: 'stat1', label: '标签1', value: '$stat1'),
        WidgetStatItem(id: 'stat2', label: '标签2', value: '$stat2'),
      ],
    );
  } catch (e) {
    debugPrint('Failed to sync your_plugin widget: $e');
  }
}
```

并在 `syncAllPlugins()` 中调用：

```dart
Future<void> syncAllPlugins() async {
  await Future.wait([
    // ... 现有同步
    syncYourPlugin(),
  ]);
}
```

---

## 数据更新 API

### 4.1 SystemWidgetService API

**主应用统一入口**，推荐使用的 API。

#### 4.1.1 更新单个插件数据

```dart
Future<void> updateWidgetData(String pluginId, PluginWidgetData data)
```

**参数**:
- `pluginId`: 插件唯一标识符（如 'todo', 'diary'）
- `data`: PluginWidgetData 对象

**示例**:
```dart
final widgetData = PluginWidgetData(
  pluginId: 'todo',
  pluginName: '待办事项',
  iconCodePoint: Icons.check_box.codePoint,
  colorValue: Colors.blue.value,
  stats: [
    WidgetStatItem(id: 'total', label: '总任务', value: '10'),
  ],
);

await SystemWidgetService.instance.updateWidgetData('todo', widgetData);
```

#### 4.1.2 更新指定插件小组件

```dart
Future<void> updateWidget(String pluginId)
```

**说明**: 不更新数据，只触发小组件重新渲染。

**示例**:
```dart
await SystemWidgetService.instance.updateWidget('todo');
```

#### 4.1.3 更新所有插件小组件

```dart
Future<void> updateAllWidgets()
```

**说明**: 触发所有已注册插件的小组件重新渲染。

**示例**:
```dart
await SystemWidgetService.instance.updateAllWidgets();
```

### 4.2 MyWidgetManager API

**底层插件 API**，高级用户或特殊场景使用。

#### 4.2.1 更新插件小组件数据

```dart
Future<void> updatePluginWidgetData(String pluginId, PluginWidgetData data)
```

**示例**:
```dart
await MyWidgetManager().updatePluginWidgetData('todo', widgetData);
```

#### 4.2.2 更新指定插件小组件

```dart
Future<void> updatePluginWidget(String pluginId)
```

**示例**:
```dart
await MyWidgetManager().updatePluginWidget('todo');
```

#### 4.2.3 更新所有插件小组件

```dart
Future<void> updateAllPluginWidgets()
```

**示例**:
```dart
await MyWidgetManager().updateAllPluginWidgets();
```

### 4.3 PluginWidgetSyncHelper API

**批量同步工具**，用于一次性更新所有或特定插件。

#### 4.3.1 同步所有插件

```dart
Future<void> syncAllPlugins()
```

**说明**: 自动从各插件获取最新数据并更新小组件。

**示例**:
```dart
await PluginWidgetSyncHelper.instance.syncAllPlugins();
```

#### 4.3.2 同步单个插件

```dart
Future<void> syncTodo()
Future<void> syncDiary()
Future<void> syncActivity()
// ... 每个插件都有对应的 sync 方法
```

**示例**:
```dart
await PluginWidgetSyncHelper.instance.syncTodo();
await PluginWidgetSyncHelper.instance.syncDiary();
```

### 4.4 API 选择建议

| 场景 | 推荐 API | 原因 |
|------|---------|------|
| 插件数据变更时更新 | `SystemWidgetService.updateWidgetData()` | 简洁易用，自动处理平台检查 |
| 批量更新所有插件 | `PluginWidgetSyncHelper.syncAllPlugins()` | 自动获取数据，无需手动构造 |
| 应用启动时刷新 | `SystemWidgetService.updateAllWidgets()` | 快速刷新所有小组件 |
| 高级自定义场景 | `MyWidgetManager` API | 直接访问底层功能 |

---

## 数据模型

### 5.1 PluginWidgetData

**小组件数据模型**，包含插件的基本信息和统计数据。

```dart
class PluginWidgetData {
  /// 插件唯一标识符
  final String pluginId;

  /// 插件显示名称
  final String pluginName;

  /// 图标 Unicode code point (使用 Icons.xxx.codePoint)
  final int iconCodePoint;

  /// 主题色值 (使用 Colors.xxx.value)
  final int colorValue;

  /// 统计项列表 (最多支持 4 个)
  final List<WidgetStatItem> stats;

  /// 最后更新时间 (自动生成)
  final DateTime lastUpdated;
}
```

**构造示例**:
```dart
final data = PluginWidgetData(
  pluginId: 'todo',
  pluginName: '待办事项',
  iconCodePoint: Icons.check_box.codePoint,  // Material Icons
  colorValue: Colors.blue.value,              // Material Colors
  stats: [
    WidgetStatItem(id: 'total', label: '总任务', value: '10'),
    WidgetStatItem(id: 'incomplete', label: '未完成', value: '3'),
  ],
  lastUpdated: DateTime.now(),  // 可选，默认为当前时间
);
```

### 5.2 WidgetStatItem

**统计项数据模型**，表示小组件中的单个统计指标。

```dart
class WidgetStatItem {
  /// 统计项唯一 ID
  final String id;

  /// 显示标签
  final String label;

  /// 统计值（字符串格式，支持单位）
  final String value;

  /// 是否高亮显示
  final bool highlight;

  /// 自定义颜色值 (可选)
  final int? colorValue;
}
```

**构造示例**:
```dart
// 基础统计项
WidgetStatItem(
  id: 'total',
  label: '总任务',
  value: '10',
)

// 高亮统计项（带自定义颜色）
WidgetStatItem(
  id: 'urgent',
  label: '紧急任务',
  value: '3',
  highlight: true,
  colorValue: Colors.red.value,
)

// 带单位的统计项
WidgetStatItem(
  id: 'progress',
  label: '完成率',
  value: '75%',
)
```

### 5.3 小组件尺寸与统计项显示

| 小组件尺寸 | 显示规则 | 示例 |
|-----------|---------|------|
| **1x1** | 仅显示第 1 个统计项 | value + label |
| **2x2** | 显示前 2 个统计项 | 两列布局 |

**建议**:
- 最多提供 4 个统计项
- 第 1 个统计项最重要（1x1 尺寸只显示它）
- 前 2 个统计项用于 2x2 尺寸

### 5.4 颜色与图标

#### 图标 Code Point 获取

```dart
// Material Icons
Icons.check_box.codePoint        // ✅ 待办
Icons.timer.codePoint            // ⏱️ 计时
Icons.book.codePoint             // 📖 日记
Icons.calendar_today.codePoint   // 📅 日历
Icons.timeline.codePoint         // 📊 活动
Icons.track_changes.codePoint    // 🎯 目标
```

#### 颜色值获取

```dart
// Material Colors
Colors.blue.value           // 蓝色
Colors.red.value            // 红色
Colors.green.value          // 绿色
Colors.orange.value         // 橙色
Colors.purple.value         // 紫色

// 自定义颜色
Color(0xFF5C6BC0).value     // 自定义色值
```

---

## 完整示例

### 6.1 待办插件示例

```dart
// lib/plugins/todo/todo_plugin.dart
import 'package:flutter/material.dart';
import 'package:memento_widgets/memento_widgets.dart';
import '../../core/services/system_widget_service.dart';

class TodoPlugin extends PluginBase {
  @override
  String get id => 'todo';

  // 任务数据变更时调用
  Future<void> updateTaskWidget() async {
    // 1. 获取统计数据
    final totalTasks = taskController.getTotalTaskCount();
    final incompleteTasks = taskController.getIncompleteTaskCount();
    final completedToday = taskController.getTodayCompletedCount();

    // 2. 构造小组件数据
    final widgetData = PluginWidgetData(
      pluginId: 'todo',
      pluginName: '待办事项',
      iconCodePoint: Icons.check_box.codePoint,
      colorValue: Colors.blue.value,
      stats: [
        WidgetStatItem(
          id: 'total',
          label: '总任务',
          value: '$totalTasks',
        ),
        WidgetStatItem(
          id: 'incomplete',
          label: '未完成',
          value: '$incompleteTasks',
          highlight: incompleteTasks > 0,
          colorValue: incompleteTasks > 0 ? Colors.orange.value : null,
        ),
        WidgetStatItem(
          id: 'completed_today',
          label: '今日完成',
          value: '$completedToday',
          highlight: completedToday > 0,
          colorValue: Colors.green.value,
        ),
      ],
    );

    // 3. 更新小组件
    await SystemWidgetService.instance.updateWidgetData('todo', widgetData);
  }

  // 在数据变更时调用更新
  Future<void> addTask(Task task) async {
    tasks.add(task);
    await saveData();
    await updateTaskWidget();  // 更新小组件
  }

  Future<void> completeTask(String taskId) async {
    final task = tasks.firstWhere((t) => t.id == taskId);
    task.isCompleted = true;
    await saveData();
    await updateTaskWidget();  // 更新小组件
  }
}
```

### 6.2 日记插件示例

```dart
// lib/plugins/diary/diary_plugin.dart
import 'package:flutter/material.dart';
import 'package:memento_widgets/memento_widgets.dart';
import '../../core/services/system_widget_service.dart';

class DiaryPlugin extends PluginBase {
  @override
  String get id => 'diary';

  Future<void> updateDiaryWidget() async {
    // 获取统计
    final todayWordCount = await getTodayWordCount();
    final monthWordCount = await getMonthWordCount();
    final (completedDays, totalDays) = await getMonthProgress();

    final widgetData = PluginWidgetData(
      pluginId: 'diary',
      pluginName: '日记',
      iconCodePoint: Icons.book.codePoint,
      colorValue: Colors.brown.value,
      stats: [
        WidgetStatItem(
          id: 'today',
          label: '今日字数',
          value: '$todayWordCount',
          highlight: todayWordCount > 0,
          colorValue: todayWordCount > 0 ? Colors.deepOrange.value : null,
        ),
        WidgetStatItem(
          id: 'month',
          label: '本月字数',
          value: '$monthWordCount',
        ),
        WidgetStatItem(
          id: 'progress',
          label: '本月进度',
          value: '$completedDays/$totalDays',
          highlight: completedDays == totalDays,
          colorValue: completedDays == totalDays ? Colors.green.value : null,
        ),
      ],
    );

    await SystemWidgetService.instance.updateWidgetData('diary', widgetData);
  }

  // 保存日记时更新
  Future<void> saveDiary(DiaryEntry entry) async {
    await storage.write('diary_${entry.id}', entry.toJson());
    await updateDiaryWidget();
  }
}
```

### 6.3 批量更新示例

```dart
// lib/main.dart 或应用启动时
import 'package:memento/core/services/plugin_widget_sync_helper.dart';

// 应用启动时同步所有小组件
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... 初始化插件管理器等

  // 同步所有插件小组件
  await PluginWidgetSyncHelper.instance.syncAllPlugins();

  runApp(MyApp());
}
```

### 6.4 条件更新示例

```dart
// 仅在数据显著变化时更新小组件
class SmartUpdatePlugin extends PluginBase {
  int _lastUpdateValue = 0;

  Future<void> onDataChange(int newValue) async {
    // 仅当变化超过 10% 时更新
    if ((newValue - _lastUpdateValue).abs() / _lastUpdateValue > 0.1) {
      await updateWidget();
      _lastUpdateValue = newValue;
    }
  }

  Future<void> updateWidget() async {
    final data = PluginWidgetData(/* ... */);
    await SystemWidgetService.instance.updateWidgetData(id, data);
  }
}
```

---

## 迁移指南

### 7.1 从旧版本迁移

**旧版代码** (Memento 1.x):
```dart
// 直接使用 home_widget
await HomeWidget.saveWidgetData<String>('todo_data', jsonData);
await HomeWidget.updateWidget(name: 'TodoWidgetProvider');
```

**新版代码** (Memento 2.0):
```dart
// 使用统一 API
final widgetData = PluginWidgetData(/* ... */);
await SystemWidgetService.instance.updateWidgetData('todo', widgetData);
```

### 7.2 数据模型迁移

**旧版** (自定义 JSON):
```dart
final jsonData = jsonEncode({
  'pluginName': '待办事项',
  'iconCodePoint': Icons.check_box.codePoint,
  'colorValue': Colors.blue.value,
  'stats': [
    {'label': '总任务', 'value': '10'},
  ],
});
```

**新版** (类型安全):
```dart
final widgetData = PluginWidgetData(
  pluginId: 'todo',
  pluginName: '待办事项',
  iconCodePoint: Icons.check_box.codePoint,
  colorValue: Colors.blue.value,
  stats: [
    WidgetStatItem(id: 'total', label: '总任务', value: '10'),
  ],
);
```

### 7.3 迁移检查清单

- [ ] 替换 `HomeWidget.saveWidgetData()` 为 `SystemWidgetService.updateWidgetData()`
- [ ] 替换自定义 JSON 为 `PluginWidgetData` 对象
- [ ] 移除手动 JSON 编码/解码
- [ ] 添加 `import 'package:memento_widgets/memento_widgets.dart';`
- [ ] 测试小组件更新是否正常
- [ ] 验证点击跳转功能

---

## 常见问题

### 8.1 Q: 小组件不显示更新的数据？

**A**: 检查以下几点：

1. **确认数据已保存**:
```dart
final success = await SystemWidgetService.instance.updateWidgetData('todo', data);
debugPrint('Widget update success: $success');
```

2. **检查 pluginId 是否正确**:
```dart
// 必须与 Provider 中的 pluginId 一致
const pluginId = 'todo';  // ✅
const pluginId = 'TODO';  // ❌ 大小写敏感
```

3. **手动触发刷新**:
```dart
await SystemWidgetService.instance.updateWidget('todo');
```

### 8.2 Q: 小组件点击无反应？

**A**: 确认主应用的 DeepLink 配置正确：

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="memento"
        android:host="widget" />
</intent-filter>
```

并在 MainActivity 中处理 URI：

```dart
// lib/main.dart
SystemWidgetService.instance.getInitialUri().then((uri) {
  if (uri != null) {
    handleWidgetUri(uri);
  }
});
```

### 8.3 Q: 如何支持动态统计项数量？

**A**: 使用条件列表：

```dart
final stats = <WidgetStatItem>[];

// 总是显示总数
stats.add(WidgetStatItem(id: 'total', label: '总数', value: '$total'));

// 条件添加
if (incomplete > 0) {
  stats.add(WidgetStatItem(id: 'incomplete', label: '未完成', value: '$incomplete'));
}

if (urgent > 0) {
  stats.add(WidgetStatItem(id: 'urgent', label: '紧急', value: '$urgent', highlight: true));
}

final widgetData = PluginWidgetData(/* ... */, stats: stats);
```

### 8.4 Q: 如何优化小组件更新频率？

**A**: 避免频繁更新，使用防抖策略：

```dart
import 'dart:async';

class ThrottledWidgetUpdater {
  Timer? _updateTimer;
  final Duration throttleDuration;

  ThrottledWidgetUpdater({this.throttleDuration = const Duration(seconds: 2)});

  void scheduleUpdate(String pluginId, PluginWidgetData data) {
    _updateTimer?.cancel();
    _updateTimer = Timer(throttleDuration, () {
      SystemWidgetService.instance.updateWidgetData(pluginId, data);
    });
  }

  void dispose() {
    _updateTimer?.cancel();
  }
}
```

### 8.5 Q: 小组件数据持久化在哪里？

**A**: 数据保存在 SharedPreferences 中：

```
键名格式: {pluginId}_widget_data
存储位置: "HomeWidgetPreferences"
数据格式: JSON 字符串
```

可以通过以下方式读取：

```dart
final prefs = await SharedPreferences.getInstance();
final jsonData = prefs.getString('todo_widget_data');
```

---

## 最佳实践

### 9.1 何时更新小组件

✅ **推荐更新时机**:
- 关键数据变更时（新增、删除、完成任务）
- 统计数据显著变化时（变化 > 10%）
- 用户主动刷新时
- 应用启动时（一次性同步）

❌ **避免更新时机**:
- 每次数据读取时
- 快速连续操作时（使用防抖）
- 后台轮询时（浪费资源）

### 9.2 统计项设计原则

1. **优先级排序**: 最重要的统计项放在第一位（1x1 小组件只显示它）
2. **简洁明了**: label 不超过 4 个字，value 不超过 6 个字符
3. **突出重点**: 使用 `highlight` 和 `colorValue` 标记重要数据
4. **动态适应**: 根据数据状态动态添加/移除统计项

### 9.3 错误处理

```dart
Future<void> safeUpdateWidget(String pluginId, PluginWidgetData data) async {
  try {
    await SystemWidgetService.instance.updateWidgetData(pluginId, data);
  } catch (e, stackTrace) {
    debugPrint('Failed to update widget $pluginId: $e');
    debugPrint('Stack trace: $stackTrace');

    // 可选：上报错误
    // FirebaseCrashlytics.instance.recordError(e, stackTrace);
  }
}
```

### 9.4 平台检查

```dart
import 'package:universal_platform/universal_platform.dart';

Future<void> updateWidgetIfSupported(String pluginId, PluginWidgetData data) async {
  // SystemWidgetService 已内置平台检查，但如果需要自定义逻辑：
  if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
    await SystemWidgetService.instance.updateWidgetData(pluginId, data);
  } else {
    debugPrint('Widgets not supported on ${UniversalPlatform.operatingSystem}');
  }
}
```

### 9.5 测试建议

```dart
// test/widget_update_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:memento_widgets/memento_widgets.dart';

void main() {
  group('PluginWidgetData', () {
    test('should serialize to JSON correctly', () {
      final data = PluginWidgetData(
        pluginId: 'todo',
        pluginName: '待办事项',
        iconCodePoint: 0xE876,
        colorValue: 0xFF2196F3,
        stats: [
          WidgetStatItem(id: 'total', label: '总任务', value: '10'),
        ],
      );

      final json = data.toJson();

      expect(json['pluginId'], 'todo');
      expect(json['pluginName'], '待办事项');
      expect(json['stats'], hasLength(1));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'pluginId': 'todo',
        'pluginName': '待办事项',
        'iconCodePoint': 0xE876,
        'colorValue': 0xFF2196F3,
        'stats': [
          {'id': 'total', 'label': '总任务', 'value': '10', 'highlight': false}
        ],
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      final data = PluginWidgetData.fromJson(json);

      expect(data.pluginId, 'todo');
      expect(data.stats, hasLength(1));
    });
  });
}
```

---

## 附录

### A. 完整 API 参考

**SystemWidgetService**:
```dart
class SystemWidgetService {
  static SystemWidgetService get instance;

  Future<void> updateWidgetData(String pluginId, PluginWidgetData data);
  Future<void> updateWidget(String pluginId);
  Future<void> updateAllWidgets();
  Future<Uri?> getInitialUri();
  Stream<Uri?> get widgetClicked;
  bool isWidgetSupported();
}
```

**MyWidgetManager**:
```dart
class MyWidgetManager {
  factory MyWidgetManager();

  Future<void> updatePluginWidgetData(String pluginId, PluginWidgetData data);
  Future<void> updatePluginWidget(String pluginId);
  Future<void> updateAllPluginWidgets();
}
```

**PluginWidgetSyncHelper**:
```dart
class PluginWidgetSyncHelper {
  static PluginWidgetSyncHelper get instance;

  Future<void> syncAllPlugins();
  Future<void> syncTodo();
  Future<void> syncTimer();
  Future<void> syncBill();
  // ... 每个插件一个 sync 方法
}
```

### B. 相关文件

| 文件路径 | 说明 |
|---------|------|
| `lib/core/services/system_widget_service.dart` | 主应用 API 入口 |
| `lib/core/services/plugin_widget_sync_helper.dart` | 批量同步工具 |
| `packages/memento_widgets/lib/memento_widgets.dart` | 插件主 API |
| `packages/memento_widgets/lib/models/plugin_widget_data.dart` | 数据模型 |
| `memento_widgets/android/src/main/kotlin/.../BasePluginWidgetProvider.kt` | Kotlin 基类 |
| `memento_widgets/android/src/main/AndroidManifest.xml` | Receiver 注册 |

### C. 更新历史

| 版本 | 日期 | 变更内容 |
|------|------|---------|
| 2.0.0 | 2025-11-30 | 完整迁移到 memento_widgets 插件 |
| 1.0.0 | - | 原始版本（主应用内实现） |

---

**文档维护**: Memento 开发团队
**反馈渠道**: [GitHub Issues](https://github.com/hunmer/Memento/issues)
**最后更新**: 2025-11-30
