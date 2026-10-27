---
name: webview-jsapi-data-select
description: 在 aboutme webview app（网页）里通过 Aboutme JSAPI 调起原生数据选择器（如聊天消息/图片多选）并把选中数据展示到网页中。Use whenever the user asks to 让网页选择 app 内数据、网页调起选择器、jsapi 选消息/图片/头像、webview app 里展示 aboutme 数据、把 HTML 转成 webview app，或排查这类页面"图片不显示 / 气泡超出 / 不满宽 / JSAPI 调用无效"等问题。
---

# webview app + JSAPI 数据选择展示（实战沉淀）

完整链路（全部经真实代码验证，来源 2026-10 祝福墙项目）：

```
网页 Aboutme.plugins.<pluginId>.<method>(params)
  → 注入脚本 callHandler('Aboutme_plugin_call', {pluginId, method, params})
  → js_bridge_injector.dart: Aboutme_plugin_call handler
  → BatchRequestExecutor._executeSingleRequest: plugin.defineJSAPI()[method](params) 直接 await
  → Dart 函数弹原生选择器（pluginDataSelectorService.showSelector）等用户操作
  → 返回 JSON 字符串 → 注入脚本自动 JSON.parse → 前端拿到对象
```

## 一、Dart 侧（三步）

### 1. 注册数据选择器（插件的 xxx_data_selectors.dart）

```dart
pluginDataSelectorService.registerSelector(SelectorDefinition(
  id: 'chat.messages',                    // 格式 pluginId.selectorName
  pluginId: ChatPlugin.instance.id,
  name: '选择多条消息',
  steps: [                                // 多级：第一级选频道（单选推进），最终级多选
    SelectorStep(id: 'channel', ..., isFinalStep: false, dataLoader: (_) async {...}),
    SelectorStep(id: 'message', ..., isFinalStep: true, dataLoader: (prev) {...}),
  ],
  selectionMode: SelectionMode.multiple,  // 多选关键参数
));
```

### 2. 定义 JSAPI（插件的 xxx_js_api.dart，加入 buildChatJSAPI 同款表）

```dart
Future<String> _jsSelectMessages(Map<String, dynamic> params) async {
  final context = Get.context;
  if (context == null) return '{"error": "无可用 UI 上下文"}';
  final result = await pluginDataSelectorService.showSelector(
    context, 'chat.messages', config: const SelectorConfig(title: '选择消息'));
  if (result == null || result.cancelled) {    // 下滑关闭返回 null
    return '{"cancelled": true, "messages": []}';
  }
  // 多选结果取 selectedItems（不是 result.data），rawData 是原始模型对象
  final items = result is MultiSelectorResult ? result.selectedItems : const [];
  ... // 映射成纯 Map 列表后 jsonEncode
}
```

批处理执行器直接调用并 await Dart Future，用户慢慢选不会超时。
返回值会被前端自动 JSON.parse；**错误契约是 resolve `{error: '...'}` 对象，不 reject**。

### 3. 改完 Dart 必须重新编译运行应用

正在运行的旧进程没有新 JSAPI，前端会收到
`{error: 'Method not found: <pluginId>.<method>'}` ——用户反馈"改了没效果"时先想到这个。

## 二、媒体路径转 HTTP（最大的坑群）

网页只能加载 `http://localhost:<port>/...`。消息里的媒体/头像路径有四种形态，逐个处理：

| 形态 | 例子 | 转法 |
|------|------|------|
| 相对路径（相对 app_data） | `./scrapbook/images/x.png` | 直接 → `http://localhost:<port>/scrapbook/images/x.png` |
| 绝对路径 | `C:\Users\...\app_data\...` | `FilePathConverter.toRelativePath()` 先转相对 |
| `asset://<uuid>` | 统一数据 SDK 资源化媒体 | 见下，必须物化 |
| http(s) | 网络图 | 原样返回 |

踩过的坑：

1. **fileInfo 字段名**：老消息路径存 `path`，新消息存 `filePath`。读的时候必须
   `fileInfo['filePath'] ?? fileInfo['path']`（`FileMessage.fromJson` 自己都做了这个兼容）。
2. **asset:// 不是磁盘文件**：内容 base64 编码后存在 `app_data/assets/<uuid>.json` 的
   `content` 字段里，HTTP 服务器 GET 不到。用
   `AboutmeDataService.instance.data.assets.materialize(id)` 物化成临时文件，
   复制到 `app_data/webview/.assets_cache/<id><ext>`，再返回该路径的 http URL。
3. **相对路径基准不一致**：`FilePathConverter.toRelativePath` 相对的是 **Documents 目录**
   （返回 `./app_data/xxx`），而 HTTP 服务器 root 是 **app_data**——先去掉 `./app_data/` 段再拼 URL。
   `ImageUtils.sdkAssetId()` 可识别 `asset://` 与 `./asset://` 两种写法。
4. **端口不要写死 8899**：`WebViewPlugin.instance.localHttpServer.port`（绑定失败会 +1 漂移），
   且先判 `localHttpServer.isRunning`。
5. **头像**：只有当前用户有——SharedPreferences `user_avatar_path`（AvatarPicker 存
   `./avatars/...` 相对路径，数据源同 profile_screen）。**User 模型没有头像字段**，
   其他用户让前端按 username 哈希生成固定头像。视频消息 `<img>` 显示不了，取
   `fileInfo['thumbPath'] ?? filePath`。

现成参考实现：`lib/plugins/chat/chat_js_api.dart` 的 `_localPathToHttpUrl` / `_assetRefToHttpUrl` / `_jsSelectMessages`。

## 三、网页侧模板

```js
async function pickFromAboutme() {
  if (!window.Aboutme || !Aboutme.plugins) { /* 不在 webview 环境，降级提示 */ return; }
  try {
    const res = await Aboutme.plugins.chat.selectMessages({});
    if (res && res.error) { Aboutme.ui.toast('选择失败: ' + res.error); return; }
    if (!res || res.cancelled || !Array.isArray(res.messages)) return;
    // ...把 res.messages 映射进页面状态并重渲染
  } catch (e) { console.error(e); }
}
```

页面经本地 HTTP 服务器加载时图片与页面同源，html2canvas 导出无 CORS 问题。

## 四、部署为 webview app

| 位置 | 路径 |
|------|------|
| 仓库源码 | `assets/webview_apps/<project>/index.html` |
| 运行目录 | `<Documents>/app_data/webview/http_server/<project>/index.html` |
| 访问 URL | `http://localhost:8899/webview/http_server/<project>/index.html` |
| 卡片入口 | `app_data/webview/cards.json`，url 字段 `./webview/http_server/<project>/index.html`，type `localFile` |

- 应用运行中直接写 cards.json：重启后才显示，且旧实例保存卡片会覆盖——稳妥做法是部署文件 + 告知用户在 WebView 插件里"添加→本地文件"一键加卡片。
- **webview 有页面缓存**：改了 http_server 下的文件，运行中的 webview 可能仍显示旧页，让用户关掉页面重开。

## 五、网页通用坑（固定画布类页面）

1. **固定尺寸画布放进 flex 容器必须 `flex-shrink: 0`**。否则画布布局宽被压缩到容器宽，
   transform scale 再乘一次 → 海报不满宽；画布内按原始坐标系排布的元素（气泡）右侧被
   `overflow: hidden` 裁掉，症状是"气泡超出宽度"，根因其实是画布被压。
2. **resize 事件在部分 webview 不可靠**（改视口不触发），用 `ResizeObserver` 监听容器兜底
   （回调里 rAF 防抖）。
3. **img 禁止原生拖拽**：`img.draggable = false` + CSS `-webkit-user-drag: none` +
   `pointer-events: none`，否则浏览器原生拖图会抢掉自定义拖拽事件。
4. **中文文本宽度估算**：全角/emoji 按 ~10.5px、半角按 ~5.5px（10.6px 字号），按
   `字符数 × 固定值` 估中文会严重偏窄。

## 六、验证清单（按顺序）

1. Dart 改动：`flutter analyze lib/plugins/<插件>` 零 issue。
2. 内联脚本语法：node 提取 `<script>` 内容 `new Function(s)` 校验。
3. URL 可达：`curl -o /dev/null -w "%{http_code}" http://localhost:8899/...`（服务器
   随应用启动，应用没跑则跳过）。
4. 媒体 URL：把转换结果直接 curl，200 且 size 与消息记录的 size 一致。
5. 布局实测：browser-use 打开页面，`getBoundingClientRect()` 量画布/容器宽度是否相等、
   遍历元素检查 `right <= 画布 right`（比截图更精确）。
6. 重新编译运行应用后再验收交互链路。
