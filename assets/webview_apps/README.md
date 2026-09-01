# Aboutme JavaScript Bridge Mock

这个目录包含了用于开发和测试 Aboutme WebView JavaScript Bridge 的独立模拟环境。

## 文件说明

### 1. `aboutme_mock.js`
独立的 JavaScript 文件，模拟了 Aboutme 的完整 JavaScript API 环境。

**功能特性：**
- ✅ 完整的 `window.Aboutme` 全局对象
- ✅ 插件系统代理（支持动态插件调用）
- ✅ 系统 API 模拟（时间、设备信息、应用信息等）
- ✅ UI API 模拟（Toast、Alert、Dialog）
- ✅ 存储 API 模拟（localStorage 持久化存储）
- ✅ Ready 回调机制
- ✅ 调试工具函数

**使用方法：**
```html
<script src="aboutme_mock.js"></script>
<script>
  Aboutme.ready(() => {
    console.log('Aboutme 已准备就绪！');
  });

  // 调用 API
  Aboutme.ui.toast('Hello World!');
  Aboutme.storage.write('key', 'value');
</script>
```

### 2. `test_aboutme_mock.html`
完整的测试页面，提供图形界面来测试和演示 Aboutme 的 JavaScript API。

**功能特性：**
- 📊 实时状态监控
- 🧪 API 测试按钮
- 📝 日志输出窗口
- 💾 存储状态查看
- 🎨 现代化的 UI 设计

**使用方法：**
直接在浏览器中打开 `test_aboutme_mock.html` 文件即可开始测试。

## API 文档

### 系统 API

```javascript
// 获取当前时间
await Aboutme.system.getCurrentTime();

// 获取设备信息
await Aboutme.system.getDeviceInfo();

// 获取应用信息
await Aboutme.system.getAppInfo();

// 格式化日期
await Aboutme.system.formatDate({
  date: '2024-01-01',
  format: 'YYYY-MM-DD HH:mm:ss'
});

// 获取时间戳
await Aboutme.system.getTimestamp();

// 获取自定义日期（相对天数）
await Aboutme.system.getCustomDate({ days: 7 });
```

### UI API

```javascript
// 显示 Toast 消息
await Aboutme.ui.toast('消息内容', {
  duration: 3000  // 持续时间（毫秒）
});

// 显示 Alert 警告
await Aboutme.ui.alert('警告消息');

// 显示对话框
const result = await Aboutme.ui.dialog({
  title: '标题',
  message: '消息内容',
  showCancel: true  // 是否显示取消按钮
});
```

### 存储 API

```javascript
// 写入数据（支持任意类型）
await Aboutme.storage.write('key', {
  name: '张三',
  age: 30,
  data: [1, 2, 3]
});

// 读取数据
const data = await Aboutme.storage.read('key');

// 删除数据
await Aboutme.storage.delete('key');

// 清空所有存储
await Aboutme.storage.clear();

// 获取所有键
const keys = await Aboutme.storage.keys();
```

### 插件 API

```javascript
// 调用插件方法（任意插件）
await Aboutme.plugins.diary.createEntry({
  title: '新日记',
  content: '日记内容'
});

await Aboutme.plugins.notes.createNote({
  title: '新笔记',
  content: '笔记内容'
});

// 自定义插件调用
await Aboutme.plugins.customPlugin.customMethod({
  param1: 'value1',
  param2: 'value2'
});
```

### 工具函数

```javascript
// 获取存储状态
const state = Aboutme.utils.getStorageState();

// 重置存储
await Aboutme.utils.resetStorage();

// 日志记录
Aboutme.utils.log('日志消息');
Aboutme.utils.error('错误消息');
Aboutme.utils.warn('警告消息');
```

## 在项目中使用

### 方法 1：直接引入

将 `aboutme_mock.js` 文件复制到你的项目中：

```html
<script src="path/to/aboutme_mock.js"></script>
```

### 方法 2：CDN 引入

你可以将文件上传到 CDN，然后通过 URL 引入：

```html
<script src="https://your-cdn.com/aboutme_mock.js"></script>
```

### 方法 3：模块化引入

如果使用模块系统：

```javascript
// 方式 1：通过动态导入
const script = document.createElement('script');
script.src = 'aboutme_mock.js';
document.head.appendChild(script);

// 方式 2：复制代码
// 将 aboutme_mock.js 的代码直接嵌入到你的项目中
```

## 调试技巧

1. **打开浏览器控制台**：在测试页面中按 `F12` 或右键选择"检查元素"

2. **查看日志**：测试页面的底部有实时日志输出窗口

3. **存储状态**：页面底部显示当前存储的所有数据

4. **全局访问**：在控制台中直接访问 `window.Aboutme` 对象

5. **API 测试**：使用页面上的按钮快速测试各种 API

## 注意事项

⚠️ **重要提醒：**

1. 这是一个**模拟环境**，所有 API 调用都是同步的或返回模拟数据
2. 存储使用 **localStorage** 实现，页面刷新后数据会保留
3. 存储键名前缀为 `AboutmeMock_`，避免与其他脚本冲突
4. UI 组件（Toast、Alert、Dialog）是**浏览器原生实现**，可能与实际应用有差异
5. 适用于**开发和测试**，不建议在生产环境使用

## 与实际环境的差异

| 功能 | 实际环境 | Mock 环境 |
|------|----------|-----------|
| 插件调用 | 通过 Flutter 插件处理 | 返回模拟数据 |
| 系统 API | 调用原生 Flutter 代码 | 返回模拟数据 |
| UI 组件 | 原生 Flutter UI | 浏览器原生组件 |
| 存储 | 原生持久化存储 | localStorage（持久化） |

## 示例代码

```javascript
// 示例：创建一个日记条目
Aboutme.ready(async () => {
  // 1. 显示欢迎消息
  Aboutme.ui.toast('欢迎使用 Aboutme！');

  // 2. 获取当前时间
  const now = await Aboutme.system.getCurrentTime();

  // 3. 创建日记条目
  const entry = await Aboutme.plugins.diary.createEntry({
    title: `今日日记 - ${now}`,
    content: '这是通过 JavaScript 创建的日记',
    tags: ['JavaScript', 'Mock']
  });

  // 4. 保存到本地存储
  await Aboutme.storage.write('lastEntry', entry);

  // 5. 显示成功消息
  Aboutme.ui.toast('日记创建成功！');
});
```

## 许可证

本模拟环境遵循与 Aboutme 主项目相同的许可证。

## 贡献

如果你发现了 bug 或有改进建议，欢迎提交 Issue 或 Pull Request。
