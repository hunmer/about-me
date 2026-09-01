# Siri Shortcuts 插件方法调用指南

## 概述

通过 **CallPluginMethodIntent**,你可以在 Siri Shortcuts 中调用 Aboutme 任意插件的 JavaScript API,无需为每个功能编写专用的 AppIntent。

## 架构说明

```
Siri/Shortcuts → CallPluginMethodIntent (iOS) → IntelligencePlugin
   → ShortcutsHandlerService (Dart) → JSBridgeManager
   → 插件 JavaScript API → 插件 Dart 方法
```

**优势:**
- ✅ **代码复用**: 直接使用现有的 `tools/*.json` API 定义
- ✅ **动态扩展**: 新增插件方法后自动支持,无需修改 Shortcuts 代码
- ✅ **统一维护**: 只需维护一套 JavaScript API
- ✅ **灵活参数**: 支持复杂的 JSON 参数传递

---

## 快速开始

### 1. 在 Xcode 中添加 AppIntent

确保 `ios/Runner/CallPluginMethodIntent.swift` 已包含在你的 Xcode 项目中。

**检查步骤:**
1. 打开 Xcode 项目
2. 在左侧文件列表中找到 `Runner/CallPluginMethodIntent.swift`
3. 确保该文件已勾选 Target Membership: `Runner`

### 2. 构建 iOS 应用

```bash
cd ios
pod install
cd ..
flutter build ios
```

### 3. 在 iPhone 的"快捷指令" App 中创建

打开 iPhone 的"快捷指令" App:

1. 点击右上角 **+** 创建新快捷指令
2. 点击 **添加操作**
3. 搜索 **"调用插件方法"** (或 "Call Plugin Method")
4. 配置参数:
   - **插件ID**: 例如 `todo`
   - **方法名**: 例如 `createTodo`
   - **参数**: JSON 格式,例如 `{"title":"买菜","priority":"high"}`

---

## 使用示例

### 示例 1: 创建待办事项

**快捷指令配置:**
```
动作: 调用插件方法
插件ID: todo
方法名: createTodo
参数: {"title":"买菜","priority":"high","dueDate":"2025-12-31"}
```

**效果:**
调用 `Aboutme.plugins.todo.createTodo({...})`,创建一条新的待办事项。

---

### 示例 2: 查询今日日记

**快捷指令配置:**
```
动作: 调用插件方法
插件ID: diary
方法名: getDiaryByDate
参数: {"date":"2025-12-25"}
```

**效果:**
返回指定日期的日记内容。

---

### 示例 3: 记录账单

**快捷指令配置:**
```
动作: 调用插件方法
插件ID: bill
方法名: createBill
参数: {"amount":50.5,"category":"餐饮","note":"午餐"}
```

**效果:**
记录一笔新的账单。

---

### 示例 4: 调用无参数方法

**快捷指令配置:**
```
动作: 调用插件方法
插件ID: todo
方法名: getTodos
参数: (留空)
```

**效果:**
获取所有待办事项列表。

---

## 参数说明

### 必填参数

| 参数名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| **插件ID** | String | 插件的唯一标识符 | `todo`, `diary`, `bill` |
| **方法名** | String | 要调用的 JavaScript API 方法名 | `createTodo`, `getDiaryByDate` |

### 可选参数

| 参数名 | 类型 | 说明 | 默认值 |
|--------|------|------|--------|
| **参数** | JSON String | 方法参数,必须是合法的 JSON 对象 | `{}` |
| **后台执行** | Boolean | 是否在后台执行(不打开 App) | `false` |

---

## JSON 参数格式

参数必须是**合法的 JSON 对象**,支持以下类型:

### 基本类型
```json
{
  "title": "买菜",           // 字符串
  "amount": 50.5,            // 数字
  "completed": false,        // 布尔值
  "tags": null               // null
}
```

### 嵌套对象
```json
{
  "user": {
    "name": "张三",
    "age": 25
  }
}
```

### 数组
```json
{
  "tags": ["工作", "重要"],
  "participants": [1, 2, 3]
}
```

### 日期时间
```json
{
  "dueDate": "2025-12-31",
  "createdAt": "2025-12-25T10:30:00Z"
}
```

---

## 如何查找可用的插件和方法?

### 方法 1: 查看 tools/*.json 文件

每个插件的可用方法定义在 `lib/plugins/agent_chat/tools/{插件ID}.json` 文件中。

**示例: `lib/plugins/agent_chat/tools/todo.json`**
```json
{
  "plugin_id": "todo",
  "tools": [
    {
      "method": "createTodo",
      "title": "创建待办事项",
      "parameters": [
        {"name": "title", "type": "string", "required": true},
        {"name": "priority", "type": "string", "enum": ["low","medium","high"]},
        {"name": "dueDate", "type": "string"}
      ]
    },
    {
      "method": "getTodos",
      "title": "获取待办事项列表",
      "parameters": []
    }
  ]
}
```

### 方法 2: 在 App 的"工具管理"界面查看

1. 打开 Aboutme App
2. 进入 **Agent Chat** 插件
3. 点击右上角 **工具管理**
4. 浏览所有可用的插件和方法

---

## 调试技巧

### 1. 查看日志

运行 App 时,打开 Xcode 的控制台查看日志:

```
[ShortcutsHandler] 收到 Shortcut 数据: {"action":"call_plugin_method",...}
[ShortcutsHandler] 调用插件方法: todo.createTodo
[ShortcutsHandler] 参数: {"title":"买菜"}
[ShortcutsHandler] 生成的 JS 代码: (async function() { ... })();
[ShortcutsHandler] 执行结果: {"success":true,"data":{...}}
```

### 2. 测试 JSON 参数

在创建快捷指令前,先在 JSON 验证工具中验证参数格式:
- https://jsonlint.com/

### 3. 常见错误

| 错误信息 | 原因 | 解决方法 |
|----------|------|----------|
| `插件ID 为空` | 未填写插件ID | 检查快捷指令配置 |
| `方法名 为空` | 未填写方法名 | 检查快捷指令配置 |
| `JS Bridge 未初始化` | App 未完全启动 | 等待几秒后重试 |
| `参数 JSON 解析失败` | JSON 格式错误 | 使用 jsonlint.com 验证 |
| `执行错误: ...` | 方法不存在或参数错误 | 检查 tools/*.json 中的方法定义 |

---

## 高级用法

### 1. 在快捷指令中使用变量

**场景**: 创建"快速记账"快捷指令,弹出输入框要求输入金额

```
快捷指令步骤:
1. "要求输入" → 提示文本: "请输入金额" → 保存到变量: amount
2. "调用插件方法"
   - 插件ID: bill
   - 方法名: createBill
   - 参数: {"amount": [变量 amount], "category": "餐饮"}
```

**注意**: 在参数 JSON 中引用变量时,需要使用快捷指令的变量语法。

### 2. 组合多个操作

**场景**: 创建"每日总结"快捷指令

```
快捷指令步骤:
1. "调用插件方法" → 获取今日待办
   - 插件ID: todo
   - 方法名: getTodos
   - 参数: {"completed":true}

2. "调用插件方法" → 获取今日日记
   - 插件ID: diary
   - 方法名: getDiaryByDate
   - 参数: {"date":"[今天日期]"}

3. "显示结果" → 展示汇总信息
```

### 3. 配合 Siri 语音识别

**场景**: 通过语音创建待办事项

```
快捷指令配置:
1. 启用"询问时运行"
2. "听写文本" → 保存到变量: taskTitle
3. "调用插件方法"
   - 插件ID: todo
   - 方法名: createTodo
   - 参数: {"title": [变量 taskTitle]}
```

**使用**: 对 Siri 说 "运行[快捷指令名称]" → Siri 会要求你说出待办事项 → 自动创建

---

## 性能优化建议

### 1. 减少不必要的数据传输

使用 `mode` 和 `fields` 参数过滤返回数据:

```json
{
  "mode": "summary",
  "fields": ["id", "title", "completed"]
}
```

### 2. 后台执行

对于不需要显示结果的操作,启用"后台执行":

```
后台执行: 是
```

这样快捷指令会立即返回,不会等待 App 打开。

---

## 故障排查

### Q: 快捷指令中找不到"调用插件方法"动作

**A**: 检查以下几点:
1. 确认 `CallPluginMethodIntent.swift` 已加入 Xcode 项目
2. 重新构建并安装 iOS App
3. 在"快捷指令" App 中下拉刷新可用动作列表

### Q: 执行时提示"JS Bridge 未初始化"

**A**: 这是因为 App 启动时间较长,JS Bridge 尚未完成初始化。
- 解决方法: 在快捷指令中添加"等待 2 秒"步骤
- 或者使用 `evaluateWhenReady` 方法(已在代码中实现)

### Q: 参数传递不正确

**A**: 确保 JSON 格式完全正确:
- 字符串必须用**双引号** `"` (不能用单引号 `'`)
- 键名必须用双引号
- 最外层必须是对象 `{}`

**错误示例:**
```json
{'title': '买菜'}  // ❌ 单引号
{title: "买菜"}     // ❌ 键名未加引号
["title"]           // ❌ 最外层是数组
```

**正确示例:**
```json
{"title": "买菜"}   // ✅
```

---

## 扩展开发

### 添加新的专用 AppIntent

对于高频使用的功能,可以创建专用的 AppIntent 以获得更好的 Siri 体验:

**示例: 创建专用的"快速记账" Intent**

```swift
// ios/Runner/QuickBillIntent.swift
struct QuickBillIntent: AppIntent {
    static var title: LocalizedStringResource = "快速记账"

    @Parameter(title: "金额")
    var amount: Double

    @Parameter(title: "分类")
    var category: String

    @Parameter(title: "备注")
    var note: String?

    func perform() async throws -> some IntentResult {
        let params = [
            "amount": amount,
            "category": category,
            "note": note ?? ""
        ]

        let data = [
            "action": "call_plugin_method",
            "pluginId": "bill",
            "methodName": "createBill",
            "params": params
        ] as [String: Any]

        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            IntelligencePlugin.notifier.push(jsonString)
        }

        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("记账 \(\.$amount) 元 分类 \(\.$category)")
    }
}
```

**优势:**
- Siri 可以直接识别"记账 50 元,分类餐饮"这样的自然语言
- 参数类型安全(不需要手写 JSON)
- 更好的用户体验

**何时使用专用 Intent vs 通用 Intent:**

| 场景 | 推荐方案 |
|------|---------|
| 高频功能 (每天使用多次) | 专用 Intent |
| 需要自然语言识别 | 专用 Intent |
| 低频功能 (偶尔使用) | 通用 Intent |
| 复杂参数 (嵌套对象/数组) | 通用 Intent |
| 测试新功能 | 通用 Intent |

---

## 总结

通过 **CallPluginMethodIntent**,你可以:
- ✅ 无需编写 Swift 代码即可让 Siri 调用插件功能
- ✅ 复用现有的 JavaScript API 定义
- ✅ 支持所有插件的所有方法
- ✅ 灵活传递复杂参数

开始创建你的第一个快捷指令吧! 🚀

---

**相关文件:**
- iOS Intent: `ios/Runner/CallPluginMethodIntent.swift`
- Dart 处理器: `lib/plugins/agent_chat/services/shortcuts_handler_service.dart`
- API 定义: `lib/plugins/agent_chat/tools/*.json`
