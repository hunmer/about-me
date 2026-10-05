# Handoff: 脚本中心 AI 图片生成 + JS Bridge 能力补齐 + 执行记录系统

- 日期: 2026-10-05
- 仓库: `/Users/Zhuanz/Documents/Aboutme`(Flutter macOS 桌面端为主, branch: `main`)
- 验证基线: `flutter analyze lib/plugins/scripts_center lib/core/js_bridge lib/widgets/form_fields lib/core/utils/network.dart lib/screens/json_dynamic_screen` 全部 **No issues found**
- 会话脉络: 参考 `agent_spaces` 的 ai-image 插件模板, 在脚本中心实现 AI 图片生成脚本 → 补齐 JS Bridge 基础能力(网络/文件/UI) → 内置脚本机制 → 连续修复 4 个链路 bug(表单取值/配置保存/桌面 toast/系统代理) → 执行记录系统(含图片展示/运行中状态/终止机制)
- 用户环境关键事实: **macOS + 系统代理 127.0.0.1:7890(Clash 类), 目标 API 域名直连被墙**。多个问题的根源都与此相关。

## 一、新增 JS Bridge API(全脚本可用)

全部在 `lib/core/js_bridge/js_bridge_manager.dart`, 移动端 QuickJS 环境(无 fetch/setTimeout):

| JS API | 说明 |
|---|---|
| `Aboutme.http.request({url, method, headers, body, timeout(秒), responseType:'base64', proxy})` | 网络请求, 返回 `{statusCode, headers, body}` 或 `bodyBase64`; **自动走系统代理**(见坑3), proxy 可显式指定 |
| `Aboutme.system.sleep(ms)` | 轮询等待(QuickJS 的 setTimeout 不可靠) |
| `Aboutme.system.saveFile({path, base64})` | base64 落盘(相对 app_data), 返回 `{path, absolutePath, size}` |
| `Aboutme.plugins.ui.showJsonScreen(json, {title})` | json_dynamic_widget 全屏渲染; **无 UI 上下文返回 `{success:false, reason:'no_context'}` 不 reject**(后台降级) |
| `Aboutme.plugins.ui.toast/alert/dialog` | 原有, toast 不依赖 Get.context |

配套: `JSEngine.evaluate(code, {timeout})` 支持自定义超时(默认 60s), `ScriptExecutor` 用 **5 分钟**; `JSBridgeManager.requestAbort()` 终止执行。

## 二、ai_image 内置脚本

- 位置: `assets/scripts/ai_image/`(打包真源) + `online/scripts/ai_image/`(源码副本, 改完必须 cp 同步); 当前 **v1.2.1**
- 功能: 文生图(OpenAI 兼容异步任务轮询) → 代理下载保存到 `app_data/scripts/ai_image/` → memory_image 渲染结果页 → 后台触发自动降级
- 配置项: apiKey(password)/baseUrl/model/aspectRatio/n/proxy(可选)/showUi
- **内置脚本机制**(`script_loader.dart`): `builtInScriptIds = ['ai_image']`; 启动时比较 assets 与本地版本号, **assets 更高自动升级覆盖**(代码+元数据), 相同跳过, 缺失恢复; 删除三层拦截(metadata `builtIn:true` → UI 长按菜单隐藏删除 + Loader/Manager 抛错)
- 商城清单 `online/scripts/scripts.json` 已移除 ai_image(单一来源, 避免与内置升级互覆盖)
- **关键约定**: 脚本返回 `result.data.localPaths`(本地图片路径数组) → 执行记录提取展示图片; 图片展示用 memory_image(base64 在手), 不用 network_image(不走代理, 见坑3)

## 三、执行记录系统

| 文件 | 要点 |
|---|---|
| `services/script_execution_logger.dart` | ChangeNotifier; 内存 200 条 + 持久化 `configs/scripts_center/execution_log.json`; Entry 含 images(本地路径)/trigger/error/resultSummary(500 字符截断, 自动把 result.data.images 的 base64 数组替换为占位); `startRun/endRun` 维护运行中列表 |
| `services/script_executor.dart` | execute 开始上报运行中、结束 record(成功/失败/触发方式/耗时/图片); `_resolveTrigger(args)`: calledFrom==runScript→互调 / event→事件 / trigger=='auto'→自动 / 其余手动; `terminateRunning()` 终止 |
| `screens/script_execution_log_screen.dart` | 入口: 脚本中心 AppBar 时钟图标(全部) + 长按脚本(单脚本过滤); 运行中条目(转圈+每秒计时+终止按钮); 详情: 图片网格(Image.file, 点击全屏缩放)/错误/结果; 仅失败过滤+脚本筛选+清空 |
| 终止机制 | `MobileJSEngine.requestAbortAll()`: reject JS 所有 `__PENDING_CALLS__` + evaluate 轮询检测 abort 标记 50ms 内退出, 返回"脚本已被用户终止"→ 走失败路径自动记录并移除运行中 |

## 四、本会话修复的链路 bug(重要的坑, 勿回退)

1. **flutter_form_builder 10.3.0 语义变化**(花费最多轮次): `FormBuilderState.value` 只返回 **save() 之后**的快照(`_savedValue`); 用户输入实时在 `instantValue`。`form_builder_wrapper.dart` 的 `_collectValues()` 已改读 `fbState.instantValue`, 并对 disabled 字段用 initialValue 兜底。若表单取值又变空, 先查这里。
2. **配置保存链路**: 编辑屏(script_edit_screen)配置 Tab 用 `_configLoaded` 门(加载完成前显示 loading, 完成后才构建表单); 配置实时同步 `FormConfig.onValuesChanged`(新增字段, 透传 FormBuilder.onChanged)→`_currentConfig`, 不依赖保存瞬间跨 Tab 取值。
3. **系统代理**: Dart http 包与 Flutter NetworkImage 均不走系统代理。`lib/core/utils/network.dart` 已重写: `detectSystemProxyUrl()`(环境变量 → macOS scutil 解析, 缓存 30s), `createClientWithSystemProxy({proxyUrl})`; `Aboutme.http.request` 已接入。**Flutter 原生 Image.network 仍未解决**(影响非脚本场景), 方案候选: 全局 HttpOverrides。
4. **桌面 toast 崩溃**: `Fluttertoast.cancel()/showToast()` 返回 Future, macOS 无插件实现异步抛 MissingPluginException; toast_service.dart 两处已加 `.catchError((_) => false)`。
5. **storage.read 语义**: 文件不存在返回**空 Map 而非 null**(MobileStorage.loadJson defaultValue 行为), 判断"无配置"要用 isEmpty 不能用 null 判断。

## 五、其他已知问题/技术债

- `form_builder_wrapper.dart` 的 `_fieldKeys` 是 `GlobalKey<WrappedFormFieldState>` 却挂在 FormBuilderField 上(state 类型不符), WrappedFormField 合并分支实际永远取 null —— 现靠 instantValue 兜住, 建议后续统一字段注册机制
- 终止是引擎级(并发多脚本会一并终止); 密集同步计算段无法立即打断(QuickJS 限制)
- Windows 系统代理只支持环境变量/脚本 proxy 字段(注册表读取需平台通道)
- ai_image UI JSON 用到的组件名已验证: list_view/network_image/memory_image/clip_rrect(`borderRadius:{type:'circular',radius}`)/sized_box/text(style fontSize/fontWeight:'bold')

## 六、待用户验收(按顺序)

1. **v1.2.1 图片展示**: 重编译后启动日志应见 `内置脚本已升级: ai_image 1.2.0 -> 1.2.1`, 生成结果页图片用 memory_image 正常显示(用户上次跑的还是旧版)
2. **执行记录增强**: 运行中条目实时计时; 详情显示生成图片缩略图+全屏
3. **终止机制**: 运行中点停止 → 数秒内条目消失 + "脚本已被用户终止"失败记录

## 七、收尾清理(验收通过后)

- 全局搜索删除 `[ScriptConfigDebug]` 调试日志(script_edit_screen/form_builder_wrapper/script_manager/script_executor 共约 15 处, 是排查配置保存时加的)
- form_builder_wrapper 的 dispose 诊断日志一并删

## Suggested Skills

- 无必须 skill; 纯 Flutter/Dart 迭代, 继续用 CodeGraph mcp 导航, 改 JS 桥/核心层后需重新编译(macOS: `flutter run -d macos`), 微小 UI 改动热重载即可
- 用户偏好: 验证由用户手动进行(需真实网络环境与 API key), agent 不要自动跑 app 验证
