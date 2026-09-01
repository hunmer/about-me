# Aboutme Widgets

一个基于 `home_widget` 包的 Flutter 插件,用于在 Android 桌面上显示小组件。

## 功能特性

- 📱 **两种小组件类型**:文本小组件和图像小组件
- 🎨 **灵活的数据更新**:通过简单的 API 更新小组件内容
- 🖼️ **Flutter UI 渲染**:将 Flutter Widget 渲染为图像显示在小组件中
- 🔄 **单例模式**:全局唯一的管理器实例,简化使用
- ⚡ **异步支持**:完整的异步 API,性能优秀

## 安装

在你的 `pubspec.yaml` 中添加依赖:

```yaml
dependencies:
  aboutme_widgets:
    path: ../aboutme_widgets  # 或使用 pub.dev 发布后的版本
```

然后运行:

```bash
flutter pub get
```

## 使用方法

### 1. 初始化

在 `main.dart` 中初始化插件:

```dart
import 'package:aboutme_widgets/aboutme_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 获取单例实例
  final manager = MyWidgetManager();

  // 初始化 (Android 不需要 App Group ID,可传 null)
  await manager.init(null);

  runApp(MyApp(manager: manager));
}
```

### 2. 更新文本小组件

```dart
// 保存文本数据
await manager.saveString('text_key', '你好,世界!');

// 更新小组件
await manager.updateWidget();
```

### 3. 更新图像小组件

```dart
// 渲染 Flutter Widget 为图像
final success = await manager.renderFlutterWidget(
  Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.blue, Colors.purple],
      ),
    ),
    child: Center(
      child: Text('Hello Flutter!'),
    ),
  ),
  key: 'image_key',
  logicalSize: Size(300, 300),
  pixelRatio: 2.0,
);

// 更新小组件
if (success) {
  await manager.updateWidget();
}
```

### 4. 注册交互回调

```dart
// 处理小组件点击事件
manager.registerInteractivityCallback((Uri? uri) {
  if (uri != null) {
    print('小组件被点击: $uri');
  }
});
```

## API 参考

### MyWidgetManager

单例类,提供以下方法:

| 方法 | 说明 |
|------|------|
| `init(String?)` | 初始化插件 (iOS 需要 App Group ID) |
| `saveString(String, String)` | 保存字符串数据 |
| `saveInt(String, int)` | 保存整数数据 |
| `saveBool(String, bool)` | 保存布尔数据 |
| `saveDouble(String, double)` | 保存双精度数据 |
| `getData<T>(String)` | 读取数据 |
| `updateWidget({String?})` | 更新小组件 |
| `renderFlutterWidget(Widget, ...)` | 渲染 Flutter UI 为图像 |
| `registerInteractivityCallback(Function)` | 注册交互回调 |
| `getInitialUri()` | 获取初始启动 URI |

## 小组件类型

### 文本小组件

- 显示简单的文本内容
- 最小尺寸: 250dp x 110dp
- 数据键名: `text_key`

### 图像小组件

- 显示渲染的 Flutter UI 图像
- 最小尺寸: 250dp x 250dp
- 数据键名: `image_key`

## 测试应用

插件包含一个完整的测试应用,位于 `example/` 目录:

```bash
cd example
flutter run -d android
```

## 在桌面添加小组件

1. 长按 Android 桌面空白区域
2. 选择"小组件"
3. 找到"文本小组件"或"图像小组件"
4. 拖动到桌面
5. 在应用中更新数据,小组件会自动刷新

## 平台支持

- ✅ Android
- ⚠️ iOS (需要额外配置 WidgetKit Extension)
- ❌ Web
- ❌ Desktop

## 依赖

- [home_widget](https://pub.dev/packages/home_widget) ^0.6.0
- Flutter SDK >= 3.3.0
- Dart SDK >= 3.10.0

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request!
