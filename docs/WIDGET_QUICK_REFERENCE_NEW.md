# 小组件快速参考 (新版)

> **版本**: Aboutme 2.0+
> **完整文档**: 见 [WIDGET_MIGRATION_GUIDE.md](./WIDGET_MIGRATION_GUIDE.md)

## 三步更新小组件

### 1️⃣ 导入

```dart
import 'package:aboutme_widgets/aboutme_widgets.dart';
```

### 2️⃣ 创建数据

```dart
final widgetData = PluginWidgetData(
  pluginId: 'your_plugin_id',
  pluginName: '插件名称',
  iconCodePoint: Icons.your_icon.codePoint,
  colorValue: Colors.yourColor.value,
  stats: [
    WidgetStatItem(id: 'stat1', label: '标签1', value: '值1'),
    WidgetStatItem(id: 'stat2', label: '标签2', value: '值2'),
  ],
);
```

### 3️⃣ 更新

```dart
await SystemWidgetService.instance.updateWidgetData('your_plugin_id', widgetData);
```

---

## 常用 API

### 更新单个插件

```dart
await SystemWidgetService.instance.updateWidgetData(pluginId, data);
```

### 刷新小组件（不更新数据）

```dart
await SystemWidgetService.instance.updateWidget(pluginId);
```

### 批量同步所有插件

```dart
await PluginWidgetSyncHelper.instance.syncAllPlugins();
```

---

## 数据模型速查

### PluginWidgetData

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| pluginId | String | 插件 ID | `'todo'` |
| pluginName | String | 显示名称 | `'待办事项'` |
| iconCodePoint | int | 图标代码 | `Icons.check_box.codePoint` |
| colorValue | int | 主题色 | `Colors.blue.value` |
| stats | List\<WidgetStatItem\> | 统计项 | 见下表 |

### WidgetStatItem

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| id | String | 唯一 ID | `'total'` |
| label | String | 标签 | `'总任务'` |
| value | String | 值 | `'10'` / `'75%'` |
| highlight | bool | 是否高亮 | `true` |
| colorValue | int? | 自定义色 | `Colors.red.value` |

---

## 完整示例

```dart
import 'package:flutter/material.dart';
import 'package:aboutme_widgets/aboutme_widgets.dart';

class MyPlugin extends PluginBase {
  Future<void> updateMyWidget() async {
    final widgetData = PluginWidgetData(
      pluginId: 'my_plugin',
      pluginName: '我的插件',
      iconCodePoint: Icons.star.codePoint,
      colorValue: Colors.amber.value,
      stats: [
        WidgetStatItem(
          id: 'count',
          label: '总数',
          value: '42',
        ),
        WidgetStatItem(
          id: 'active',
          label: '活跃',
          value: '10',
          highlight: true,
          colorValue: Colors.green.value,
        ),
      ],
    );

    await SystemWidgetService.instance.updateWidgetData('my_plugin', widgetData);
  }
}
```

---

## 常见图标与颜色

### 图标

```dart
Icons.check_box.codePoint        // ✅ 待办
Icons.timer.codePoint            // ⏱️ 计时
Icons.book.codePoint             // 📖 日记
Icons.calendar_today.codePoint   // 📅 日历
Icons.timeline.codePoint         // 📊 活动
Icons.track_changes.codePoint    // 🎯 目标
Icons.auto_awesome.codePoint     // ✨ 习惯
Icons.check_circle.codePoint     // ⭕ 签到
Icons.account_tree.codePoint     // 🌲 节点
Icons.contacts.codePoint         // 👥 联系人
```

### 颜色

```dart
Colors.blue.value           // 蓝色
Colors.red.value            // 红色
Colors.green.value          // 绿色
Colors.orange.value         // 橙色
Colors.purple.value         // 紫色
Colors.amber.value          // 琥珀色
Colors.teal.value           // 青色
Colors.pink.value           // 粉色
Colors.brown.value          // 棕色
```

---

## 小组件尺寸

| 尺寸 | 显示内容 |
|------|---------|
| 1x1 | 图标 + 第 1 个统计项 |
| 2x2 | 图标 + 前 2 个统计项 |

**建议**: 将最重要的统计项放在第一位

---

## 更新时机

✅ **推荐更新**:
- 数据新增/删除/修改时
- 统计值显著变化时（变化 > 10%）
- 用户主动刷新时

❌ **避免更新**:
- 频繁读取时
- 后台轮询时
- 每次 UI 刷新时

---

## 常见问题

**Q: 小组件不更新？**
```dart
// 手动触发刷新
await SystemWidgetService.instance.updateWidget('plugin_id');
```

**Q: 如何添加高亮统计项？**
```dart
WidgetStatItem(
  id: 'urgent',
  label: '紧急',
  value: '5',
  highlight: true,
  colorValue: Colors.red.value,
)
```

**Q: 支持多少个统计项？**
- 最多 4 个
- 1x1 小组件显示 1 个
- 2x2 小组件显示 2 个

---

## 已支持的插件

20 个插件已注册小组件支持：

| 插件 ID | 名称 |
|---------|------|
| todo | 待办事项 |
| timer | 计时器 |
| bill | 账单 |
| calendar | 日历 |
| activity | 活动 |
| tracker | 目标追踪 |
| habits | 习惯 |
| diary | 日记 |
| checkin | 签到 |
| nodes | 节点 |
| database | 数据库 |
| contact | 联系人 |
| day | 纪念日 |
| goods | 物品管理 |
| notes | 笔记 |
| store | 商店 |
| openai | AI助手 |
| agent_chat | AI对话 |
| calendar_album | 日记相册 |
| chat | 聊天 |

---

**查看完整文档**: [WIDGET_MIGRATION_GUIDE.md](./WIDGET_MIGRATION_GUIDE.md)
