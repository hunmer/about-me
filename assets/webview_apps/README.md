# Aboutme JavaScript Bridge Mock

这个目录包含了用于开发和测试 Aboutme WebView JavaScript Bridge 的独立模拟环境。

模拟对象（同步来源）：
- `lib/plugins/webview/screens/webview_browser_screen.dart` / `lib/plugins/webview/widgets/embedded_webview.dart` 的 `_createAboutmeUserScript`（注入的 JS API 面）
- `lib/plugins/webview/services/js_bridge_injector.dart`（handler 行为）
- `lib/core/js_bridge/js_bridge_manager.dart`（system API 实现）

## 文件说明

### 1. `aboutme_mock.js`
独立的 JavaScript 文件，模拟了 Aboutme 的 WebView JavaScript API 环境。

**功能特性：**
- ✅ 完整的 `window.Aboutme` 全局对象
- ✅ 插件系统代理（支持动态插件调用，结果直接返回）
- ✅ 系统 API 模拟（时间、设备信息、应用信息等）
- ✅ UI API 模拟（Toast、Alert、Dialog）
- ✅ 存储 API 模拟（localStorage 持久化存储）
- ✅ Ready 回调机制
- ✅ 调试工具函数（仅 Mock 环境）

**使用方法：**
```html
<script src="aboutme_mock.js"></script>
<script>
  Aboutme.ready(() => {
    console.log('Aboutme 已准备就绪！');
  });

  // 调用 API
  Aboutme.ui.toast('Hello World!');
  Aboutme.storage.write('key', { a: 1 });
</script>
```

### 2. `test_aboutme_mock.html`
完整的测试页面，提供图形界面来测试和演示 Aboutme 的 JavaScript API。

**使用方法：**
直接在浏览器中打开 `test_aboutme_mock.html` 文件即可开始测试。

## API 文档

### 系统 API

```javascript
// 获取当前时间（返回时间对象，含 weekdayName 中文星期）
const time = await Aboutme.system.getCurrentTime();
// { timestamp, datetime, year, month, day, hour, minute, second,
//   weekday, weekdayName }

// 获取设备信息
await Aboutme.system.getDeviceInfo();
// { platform, platformVersion, deviceModel, isPhysicalDevice }

// 获取应用信息
await Aboutme.system.getAppInfo();
// { appName: 'Aboutme', version, buildNumber, packageName: 'github.hunmer.aboutme' }

// 格式化日期：dateInput 为日期字符串或毫秒时间戳
// 占位符：yyyy MM dd HH hh mm ss E（E 为中文星期，注意是小写 yyyy）
await Aboutme.system.formatDate(Date.now(), 'yyyy-MM-dd HH:mm:ss');

// 获取当前毫秒时间戳
await Aboutme.system.getTimestamp();

// 获取自定义日期（推荐使用，解决时区问题）
await Aboutme.system.getCustomDate({
  baseDate?: number | string,   // 基准日期，默认当前时间
  timezone?: 'local' | 'UTC',
  add?: { days, hours, minutes, seconds, milliseconds },      // 增加时间
  subtract?: { days, hours, minutes, seconds, milliseconds }, // 减少时间
  relativePosition?: 'startOfDay' | 'endOfDay' | 'startOfHour' | 'endOfHour'
                   | 'startOfMinute' | 'endOfMinute' | 'startOfMonth' | 'endOfMonth'
                   | 'startOfWeek' | 'endOfWeek' | 'startOfYear' | 'endOfYear',
  format?: 'object' | 'timestamp' | 'iso' | 'text' | 'yyyy-MM-dd'  // 默认 'object'
});

// 示例：7 天后
await Aboutme.system.getCustomDate({ add: { days: 7 }, format: 'yyyy-MM-dd' });
```

### UI API

```javascript
// 显示 Toast 消息
await Aboutme.ui.toast('消息内容', {
  duration: 3000  // 毫秒数（真实 WebView 环境为固定时长 SnackBar）
});

// 显示 Alert（返回 boolean，true=点击确定）
const confirmed = await Aboutme.ui.alert('警告消息', {
  title: '提示',
  confirmText: '确定'
});

// 显示对话框（返回 boolean|null：true=确定，false=取消，null=关闭）
const result = await Aboutme.ui.dialog({
  title: '标题',
  content: '内容',
  confirmText: '确定',
  cancelText: '取消',
  showCancel: true
});
```

### 存储 API

真实环境后端为统一数据 SDK 的 webview 域 KV 存储，仅有三个方法：

```javascript
// 写入数据（支持任意 JSON 类型），成功返回 true
await Aboutme.storage.write('key', { name: '张三', age: 30 });

// 读取数据，不存在返回 null
const data = await Aboutme.storage.read('key');

// 删除数据，成功返回 true
await Aboutme.storage.delete('key');
```

### 插件 API

```javascript
// 调用插件方法（任意插件），结果直接返回（无 success/data 包装）
const result = await Aboutme.plugins.diary.someMethod({ param1: 'value1' });

// 错误契约：失败时 resolve 一个 { error: '...' } 对象
// 未注册插件：{ error: 'Plugin "xxx" is not registered. Available plugins: ...' }
```

### 工具函数（仅 Mock 环境）

```javascript
// 获取存储状态
const state = Aboutme.utils.getStorageState();

// 重置存储
await Aboutme.utils.resetStorage();

// 日志记录
Aboutme.utils.log('日志消息');
```

## 调试技巧

1. **打开浏览器控制台**：在测试页面中按 `F12` 或右键选择"检查元素"
2. **查看日志**：测试页面的底部有实时日志输出窗口
3. **存储状态**：页面底部显示当前存储的所有数据
4. **全局访问**：在控制台中直接访问 `window.Aboutme` 对象
5. **API 测试**：使用页面上的按钮快速测试各种 API

## 注意事项

⚠️ **重要提醒：**

1. 这是一个**模拟环境**，所有 API 均返回模拟数据
2. 存储使用 **localStorage** 实现（键前缀 `AboutmeMock_`），真实环境为服务端 KV 存储
3. `Aboutme.utils.*` 为 Mock 专用调试工具，真实环境不存在
4. UI 组件为 DOM 模拟，与真实应用的 SnackBar / DSDialog 有差异
5. 本 Mock 仅覆盖 **WebView 环境**；QuickJS 脚本环境的额外命名空间
   （`Aboutme.http` / `Aboutme.events` / `Aboutme.toolCall` / `Aboutme.tools`）不在注入范围内

## 与实际环境的差异

| 功能 | 实际环境 | Mock 环境 |
|------|----------|-----------|
| 插件调用 | 统一数据 SDK / 批处理执行器 | 返回模拟数据（结果直接返回，形状一致） |
| 系统 API | 调用原生 Flutter 代码 | 浏览器实现的同构返回值 |
| UI 组件 | SnackBar / DSDialog | DOM 模拟组件 |
| 存储 | webview 域 KV 存储（服务端） | localStorage（持久化） |

## 许可证

本模拟环境遵循与 Aboutme 主项目相同的许可证。
