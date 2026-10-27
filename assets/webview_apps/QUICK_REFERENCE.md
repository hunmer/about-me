# Aboutme JavaScript Bridge Mock - 快速参考

## 🚀 快速开始

### 1. 在 HTML 中引入
```html
<script src="aboutme_mock.js"></script>
<script>
  Aboutme.ready(() => {
    // Aboutme 已准备就绪
  });
</script>
```

### 2. 在浏览器中测试
直接在浏览器中打开 `test_aboutme_mock.html`

## 📋 常用代码片段

### 获取系统信息
```javascript
// 当前时间（对象，含中文星期 weekdayName）
const time = await Aboutme.system.getCurrentTime();

// 设备信息
const device = await Aboutme.system.getDeviceInfo();

// 时间戳（毫秒）
const timestamp = await Aboutme.system.getTimestamp();

// 格式化日期（小写 yyyy，E=星期）
await Aboutme.system.formatDate(Date.now(), 'yyyy-MM-dd HH:mm:ss 星期E');
```

### 自定义日期
```javascript
// 7 天后（注意：add 是嵌套对象，不是 { days: 7 }）
await Aboutme.system.getCustomDate({ add: { days: 7 }, format: 'yyyy-MM-dd' });

// 本月最后一天（时间对象）
await Aboutme.system.getCustomDate({ relativePosition: 'endOfMonth' });

// 本周一 00:00 的时间戳
await Aboutme.system.getCustomDate({
  relativePosition: 'startOfWeek',
  format: 'timestamp'
});
```

### UI 交互
```javascript
// 短消息
Aboutme.ui.toast('操作成功！');

// Alert（返回 boolean）
const confirmed = await Aboutme.ui.alert('确认删除吗？', { title: '警告' });

// 对话框（返回 true / false / null，字段是 content 不是 message）
const result = await Aboutme.ui.dialog({
  title: '确认',
  content: '是否继续？',
  showCancel: true
});
```

### 数据存储
```javascript
// 保存（使用 localStorage 模拟，真实环境为 webview 域 KV 存储）
await Aboutme.storage.write('user', { name: '张三' });  // -> true

// 读取（不存在返回 null）
const user = await Aboutme.storage.read('user');

// 删除
await Aboutme.storage.delete('user');  // -> true
```

### 调用插件
```javascript
// 结果直接返回（无 success/data 包装），失败时 resolve { error: '...' }
await Aboutme.plugins.openai.someMethod({ data: 'value' });
```

## 🔧 调试工具（仅 Mock 环境）

```javascript
// 查看所有存储
Aboutme.utils.getStorageState();

// 清空存储
await Aboutme.utils.resetStorage();

// 日志记录
Aboutme.utils.log('调试信息');
```

## ⚠️ 注意事项

1. **Mock 环境**：这是模拟环境，不是真实的 Flutter 插件调用
2. **localStorage 存储**：数据持久化保存在浏览器中（键前缀 `AboutmeMock_`）
3. **返回值形状与真实环境一致**：`formatDate` 参数是 `(dateInput, format)`；`getCustomDate` 用 `add/subtract` 嵌套对象；`alert` 返回 boolean；`storage` 只有 read/write/delete
4. **异步操作**：所有 API 都是异步的，需要使用 `await` 或 `.then()`
5. **QuickJS 专属 API 不可用**：`Aboutme.http/events/toolCall/tools` 不在 WebView 注入范围内

## 📁 文件位置

- `aboutme_mock.js` - 核心 Mock 库
- `test_aboutme_mock.html` - 测试页面
- `README.md` - 完整文档
- `QUICK_REFERENCE.md` - 本文件

## 💡 提示

- 按 `F12` 打开浏览器控制台查看详细日志
- 在测试页面中查看实时 API 测试和存储状态
- 所有 API 返回的都是模拟数据，仅供开发测试使用
