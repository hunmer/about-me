# Aboutme 小组件快速参考

> 5 分钟快速为插件添加小组件支持

---

## 🚀 快速开始（4 步完成）

### 1️⃣ 创建 WidgetProvider (Kotlin)

```kotlin
// android/app/src/main/kotlin/.../widget/providers/<Plugin>WidgetProvider.kt
package github.hunmer.aboutme.widget.providers
import github.hunmer.aboutme.widget.BasePluginWidgetProvider

class <Plugin>WidgetProvider : BasePluginWidgetProvider() {
    override val pluginId: String = "<plugin_id>"
    override val widgetSize: WidgetSize = WidgetSize.SIZE_1X1
}

class <Plugin>Widget2x1Provider : BasePluginWidgetProvider() {
    override val pluginId: String = "<plugin_id>"
    override val widgetSize: WidgetSize = WidgetSize.SIZE_2X2
}
```

### 2️⃣ 注册到 AndroidManifest.xml

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<receiver android:name=".widget.providers.<Plugin>WidgetProvider" android:exported="false">
    <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>
    <meta-data android:name="android.appwidget.provider" android:resource="@xml/widget_plugin_1x1_info" />
</receiver>
<receiver android:name=".widget.providers.<Plugin>Widget2x1Provider" android:exported="false">
    <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>
    <meta-data android:name="android.appwidget.provider" android:resource="@xml/widget_plugin_2x1_info" />
</receiver>
```

### 3️⃣ 实现数据同步 (Flutter)

```dart
// lib/core/services/plugin_widget_sync_helper.dart

// A. 添加到 syncAllPlugins()
await Future.wait([
  // ... 其他插件
  sync<Plugin>(),
]);

// B. 实现同步方法
Future<void> sync<Plugin>() async {
  try {
    final plugin = PluginManager.instance.getPlugin('<plugin_id>') as <Plugin>Plugin?;
    if (plugin == null) return;

    final count = await plugin.getSomeCount();

    await _updateWidget(
      pluginId: '<plugin_id>',
      pluginName: '<显示名称>',
      iconCodePoint: Icons.<icon>.codePoint,
      colorValue: Colors.<color>.value,
      stats: [
        WidgetStatItem(id: 'stat1', label: '标签', value: '$count'),
        // 最多 4 个统计项
      ],
    );
  } catch (e) {
    debugPrint('Failed to sync <plugin> widget: $e');
  }
}
```

### 4️⃣ 更新 SystemWidgetService 映射

```dart
// lib/core/services/system_widget_service.dart

// A. updateAllWidgets()
final providers = [
  // ...
  '<Plugin>WidgetProvider',
];

// B. _getProviderName()
final providerMap = {
  // ...
  '<plugin_id>': '<Plugin>WidgetProvider',
};
```

---

## 📊 统计项设计速查

### 推荐格式

```dart
WidgetStatItem(
  id: 'unique_id',           // 唯一标识
  label: '标签',              // 4-6 个字
  value: '123',               // 简洁数值
  highlight: value > 0,       // 条件高亮
  colorValue: Colors.green.value,  // 高亮颜色
)
```

### 颜色速查

| 场景 | 颜色 | 代码 |
|------|------|------|
| ✅ 完成/成功 | 绿色 | `Colors.green.value` |
| ⚠️ 警告/少于 | 红色 | `Colors.red.value` |
| 🏆 成就/连续 | 琥珀 | `Colors.amber.value` |
| 🔥 活跃/新增 | 橙色 | `Colors.deepOrange.value` |

### 数值格式化

```dart
// 大数字
'1234' → '1.2k'
formatCount(int n) => n >= 1000 ? '${(n/1000.0).toStringAsFixed(1)}k' : '$n';

// 时长
'125分钟' → '2.1h'
formatDuration(int min) => '${(min/60.0).toStringAsFixed(1)}h';

// 百分比
'45.678%' → '46%'
formatPercent(double v) => '${v.toStringAsFixed(0)}%';
```

---

## 🔧 常用代码片段

### 插件中暴露统计方法

```dart
// lib/plugins/<plugin>/<plugin>_plugin.dart
class <Plugin>Plugin extends BasePlugin {
  Future<int> getTodayCount() async {
    if (!_isInitialized) return 0;
    // 计算逻辑
    return count;
  }

  Future<int> getTotalCount() async {
    if (!_isInitialized) return 0;
    return total;
  }
}
```

### 在数据变更后触发同步

```dart
// 创建/编辑/删除数据后
await _service.saveData(data);
await PluginWidgetSyncHelper.instance.sync<Plugin>();
```

---

## 🐛 快速排查

| 问题 | 可能原因 | 检查方法 |
|------|---------|---------|
| 显示占位符 | pluginId 不匹配 | `print(plugin.id)` |
| 数据不更新 | 未调用同步 | 手动调用 `sync<Plugin>()` |
| 无法添加小组件 | 未注册 | 检查 AndroidManifest.xml |
| 显示乱码 | iconCodePoint 错误 | 使用 `Icons.xxx.codePoint` |

---

## 📝 完整示例参考

**已实现的插件**:
- `activity` - 4 个统计项（今日活动、时长、剩余、覆盖率）
- `diary` - 3 个统计项（今日字数、本月字数、进度）
- `checkin` - 3 个统计项（今日完成、总签到、最长连续）
- `chat` - 3 个统计项（频道数、消息数、未读）
- `habits` - 2 个统计项（习惯数、技能数）

查看代码：`lib/core/services/plugin_widget_sync_helper.dart`

---

## 📚 详细文档

完整实现指南请参考：[WIDGET_IMPLEMENTATION_GUIDE.md](./WIDGET_IMPLEMENTATION_GUIDE.md)

---

**最后更新**: 2025-01-21
