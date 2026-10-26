import 'package:aboutme/plugins/agent_chat/services/tool_config_manager.dart';

/// 工具 Prompt 生成器
///
/// 负责工具列表、工具简要索引、工具详细文档等 Prompt 的生成与后备内容
class ToolPromptBuilder {
  /// 生成工具列表 Prompt（从配置文件）
  /// 保留此方法用于向后兼容，但建议使用两阶段调用
  static Future<String> generateToolListPrompt() async {
    final buffer = StringBuffer();

    buffer.writeln('\n## 🛠️ 可用工具列表');
    buffer.writeln('\n### ⚠️ 重要提示');
    buffer.writeln('\n作为 AI 助手，你**无法直接获取**以下类型的信息：');
    buffer.writeln(
      '1. **当前时间**：你无法感知时间流逝，**绝对禁止**硬编码日期时间字符串（如 "2025-01-15"、"今天是1月15日"）',
    );
    buffer.writeln('2. **用户数据**：所有用户的任务、笔记、日记等数据都存储在本地，必须使用插件工具获取');
    buffer.writeln('\n### 🚫 严格禁止的行为');
    buffer.writeln('1. **禁止硬编码日期时间**：');
    buffer.writeln(
      '   - ❌ 错误：`const date = "2025-01-15"` 或 `const content = "今天是2025年1月15日"`',
    );
    buffer.writeln(
      '   - ✅ 正确：`const date = await Aboutme.system.getCustomDate({format: "yyyy-MM-dd"})`',
    );
    buffer.writeln('2. **禁止使用占位符变量**：');
    buffer.writeln(
      '   - ❌ 错误：`const channelId = "your_channel_id"` 或 `accountId: "请填入账户ID"`',
    );
    buffer.writeln('   - ✅ 正确：先查询获取真实数据，然后使用实际的ID');
    buffer.writeln(
      '   - ✅ 示例：`const channels = await Aboutme.plugins.chat.getChannels(); const firstChannel = channels[0]; await Aboutme.plugins.chat.sendMessage({channelId: firstChannel.id, content: "消息内容"})`',
    );
    buffer.writeln('\n### 系统 API（在 JavaScript 代码中直接调用）');
    buffer.writeln('\n当需要时间或设备信息时，**必须在 JavaScript 代码中调用系统API**，不要作为单独的步骤：');
    buffer.writeln('\n#### 🌟 推荐：getCustomDate（解决时区问题）');
    buffer.writeln(
      '- `await Aboutme.system.getCustomDate(options)` - **推荐使用**，一次调用解决所有日期需求',
    );
    buffer.writeln('  - **options 参数**：');
    buffer.writeln('    - `baseDate`: 基准日期（时间戳或ISO字符串），默认当前时间');
    buffer.writeln('    - `timezone`: "local"（默认）或 "UTC"');
    buffer.writeln(
      '    - `add`: 增加时间 `{days, hours, minutes, seconds, milliseconds}`',
    );
    buffer.writeln(
      '    - `subtract`: 减少时间 `{days, hours, minutes, seconds, milliseconds}`',
    );
    buffer.writeln('    - `relativePosition`: 相对位置，可选值：');
    buffer.writeln('      - `startOfDay` / `endOfDay` - 当天凌晨/结束');
    buffer.writeln('      - `startOfHour` / `endOfHour` - 小时开始/结束');
    buffer.writeln('      - `startOfMonth` / `endOfMonth` - 月初/月末');
    buffer.writeln('      - `startOfWeek` / `endOfWeek` - 周一/周日');
    buffer.writeln('      - `startOfYear` / `endOfYear` - 年初/年末');
    buffer.writeln('    - `format`: 返回格式');
    buffer.writeln(
      '      - `"object"`（默认）: 返回完整对象 `{timestamp, datetime, year, month, day, ...}`',
    );
    buffer.writeln('      - `"timestamp"`: 仅返回时间戳');
    buffer.writeln('      - `"iso"`: 返回 ISO 8601 字符串');
    buffer.writeln('      - `"text"`: 返回相对时间（如"3天前"）');
    buffer.writeln('      - 自定义格式如 `"yyyy-MM-dd HH:mm:ss"`');
    buffer.writeln('\n  **使用示例**：');
    buffer.writeln('  ```javascript');
    buffer.writeln('  // 获取今天凌晨（解决时区问题）');
    buffer.writeln(
      '  const todayStart = await Aboutme.system.getCustomDate({relativePosition: "startOfDay"});',
    );
    buffer.writeln('  ');
    buffer.writeln('  // 获取明天凌晨的时间戳');
    buffer.writeln(
      '  const tomorrowStart = await Aboutme.system.getCustomDate({',
    );
    buffer.writeln('    add: {days: 1},');
    buffer.writeln('    relativePosition: "startOfDay",');
    buffer.writeln('    format: "timestamp"');
    buffer.writeln('  });');
    buffer.writeln('  ');
    buffer.writeln('  // 获取本周一凌晨');
    buffer.writeln(
      '  const weekStart = await Aboutme.system.getCustomDate({relativePosition: "startOfWeek"});',
    );
    buffer.writeln('  ');
    buffer.writeln('  // 获取3天前的日期，格式化输出');
    buffer.writeln(
      '  const threeDaysAgo = await Aboutme.system.getCustomDate({',
    );
    buffer.writeln('    subtract: {days: 3},');
    buffer.writeln('    format: "yyyy-MM-dd"');
    buffer.writeln('  });');
    buffer.writeln('  ```');
    buffer.writeln('\n#### 其他时间 API');
    buffer.writeln(
      '- `await Aboutme.system.getCurrentTime()` - 获取当前时间，返回 `{timestamp, datetime, year, month, day, hour, minute, second, weekday, weekdayName}`',
    );
    buffer.writeln('- `await Aboutme.system.getTimestamp()` - 获取当前时间戳（毫秒）');
    buffer.writeln(
      '- `await Aboutme.system.formatDate(dateInput, format)` - 格式化日期',
    );
    buffer.writeln('\n#### 设备与应用信息');
    buffer.writeln('- `await Aboutme.system.getDeviceInfo()` - 获取设备信息');
    buffer.writeln('- `await Aboutme.system.getAppInfo()` - 获取应用信息');
    buffer.writeln('\n### 步骤间结果传递 API（多步骤协作）\n');
    buffer.writeln('当工具调用包含多个步骤时，可以使用以下 API 在步骤之间传递数据：\n');
    buffer.writeln('#### ⚠️ 强制要求：必须使用对象类型\n');
    buffer.writeln('- **setResult 必须传入对象**：value 参数必须是对象类型 `{}`，不能是原始值或数组');
    buffer.writeln('- **getResult 返回对象**：返回值永远是对象类型，通过属性访问数据\n');
    buffer.writeln('#### API 说明\n');
    buffer.writeln(
      '- `await Aboutme.toolCall.setResult({id?, value})` - 保存结果供后续步骤使用',
    );
    buffer.writeln('  - `id` (可选): 自定义结果 ID，如 "userData"、"taskList"');
    buffer.writeln('  - `value` (必需): **必须是对象** `{key: value}`，不能是数组或原始值');
    buffer.writeln(
      '- `await Aboutme.toolCall.getResult({id?, step?, default?})` - 获取之前步骤的结果',
    );
    buffer.writeln('  - `id` (可选): 结果 ID');
    buffer.writeln('  - `step` (可选): 步骤索引（从 0 开始），如 `{step: 0}` 获取第一个步骤的结果');
    buffer.writeln('  - `default` (可选): 默认值，结果不存在时返回');
    buffer.writeln('  - **返回值**: 永远是对象类型，通过 `result.propertyName` 访问数据');
    buffer.writeln('\n**自动保存**：每个步骤执行成功后，结果会自动保存到 `step_N`（N 为步骤索引）');
    buffer.writeln('\n**🚫 错误示例（禁止）**:');
    buffer.writeln('```javascript');
    buffer.writeln('// ❌ 错误：setResult 传入数组');
    buffer.writeln('const tasks = await Aboutme.plugins.todo.getTasks();');
    buffer.writeln(
      'await Aboutme.toolCall.setResult({value: tasks}); // 错误！tasks 是数组',
    );
    buffer.writeln('');
    buffer.writeln('// ❌ 错误：getResult 当作数组使用');
    buffer.writeln(
      'const tasks = await Aboutme.toolCall.getResult({step: 0});',
    );
    buffer.writeln('if (tasks.length > 0) { ... } // 错误！tasks 是对象不是数组');
    buffer.writeln('```\n');
    buffer.writeln('**✅ 正确示例（必须遵循）**:');
    buffer.writeln('```javascript');
    buffer.writeln('// ✅ 正确：setResult 传入对象，用属性包装数据');
    buffer.writeln('const tasks = await Aboutme.plugins.todo.getTasks();');
    buffer.writeln(
      'await Aboutme.toolCall.setResult({value: {tasks, count: tasks.length}}); // 正确！',
    );
    buffer.writeln('');
    buffer.writeln('// ✅ 正确：getResult 返回对象，通过属性访问');
    buffer.writeln(
      'const result = await Aboutme.toolCall.getResult({step: 0});',
    );
    buffer.writeln(
      'if (result.tasks && result.tasks.length > 0) { ... } // 正确！',
    );
    buffer.writeln('```');
    buffer.writeln(
      '\n优先使用上面列出的专用插件工具。只有没有合适工具，或确实需要用脚本组合操作时，才生成 JavaScript 步骤。',
    );
    buffer.writeln('\n## 📝 工具调用格式\n');
    buffer.writeln('**🚨 重要：必须使用以下 Markdown 格式，不要使用 JSON 格式！**\n');
    buffer.writeln('**严格遵循**:');
    buffer.writeln('1. **仅返回** 以下格式的工具调用');
    buffer.writeln('2. **不要** 任何额外文本或解释');
    buffer.writeln('3. **不要** 使用 JSON 格式（如 `{"steps": [...]}`）');
    buffer.writeln('4. **不要** 在外层包裹 ` ```markdown ` 代码块');
    buffer.writeln('5. **必须** 使用以下格式：\n');
    buffer.writeln('```\n');
    buffer.writeln('# 步骤标题');
    buffer.writeln('## 步骤描述（可选）');
    buffer.writeln('```javascript');
    buffer.writeln('// JavaScript 代码');
    buffer.writeln('```');
    buffer.writeln('```\n');

    // 添加插件别名映射
    buffer.write(ToolConfigManager.generatePluginAliasesPrompt());

    // 从配置加载工具列表
    final allPluginTools = ToolConfigManager.instance.getAllPluginTools();

    if (allPluginTools.isNotEmpty) {
      buffer.writeln('### 📚 可用工具\n');

      allPluginTools.forEach((pluginId, toolSet) {
        // builtin 工具是原生 FC 硬编码实现，JS 模式无对应分发，不进 JS 文档
        if (pluginId == 'builtin') return;
        final enabledTools =
            toolSet.tools.entries.where((e) => e.value.enabled).toList();

        if (enabledTools.isEmpty) return;

        buffer.writeln('**$pluginId**');
        for (final entry in enabledTools) {
          final toolId = entry.key;
          final config = entry.value;
          final signature = config.getSignature(toolId);
          buffer.writeln('  - `$signature` - ${config.getBriefDescription()}');
        }
        buffer.writeln();
      });
    } else {
      buffer.writeln('（暂无可用工具）\n');
    }

    // 使用示例
    buffer.writeln('### 💡 使用示例\n');
    buffer.writeln('**示例 1：查询今天的任务**\n');
    buffer.writeln('```\n');
    buffer.writeln('# 获取今日任务');
    buffer.writeln('查询今天的所有待办任务');
    buffer.writeln('```javascript');
    buffer.writeln(
      'const today = await Aboutme.system.getCustomDate(); const tasks = await Aboutme.plugins.todo.getTodayTasks(); const result = `今天是\${today.month}月\${today.day}日，有 \${tasks.length} 个任务`; setResult(result); return result;',
    );
    buffer.writeln('```');
    buffer.writeln('```\n');
    buffer.writeln('**示例 2：查询并处理数据**\n');
    buffer.writeln('```\n');
    buffer.writeln('# 统计任务情况');
    buffer.writeln('获取并统计今日任务');
    buffer.writeln('```javascript');
    buffer.writeln(
      'const tasks = await Aboutme.plugins.todo.getTodayTasks(); const result = { total: tasks.length, completed: tasks.filter(t => t.completed).length }; setResult(result); return result;',
    );
    buffer.writeln('```');
    buffer.writeln('```\n');
    buffer.writeln('**示例 3：完整的签到流程（查询+执行）**\n');
    buffer.writeln('用户请求"帮我完成签到"时，应该直接执行完整流程：\n');
    buffer.writeln('```\n');
    buffer.writeln('# 执行签到操作');
    buffer.writeln('查找第一个未签到的项目并执行签到');
    buffer.writeln('```javascript');
    final checkinExample =
        '''const items = await Aboutme.plugins.checkin.getCheckinItems(); const target = items.find(i => !i.isCheckedToday); if (!target) { const msg = '所有项目今天都已签到'; setResult(msg); return msg; } const result = await Aboutme.plugins.checkin.checkin(target.id); const msg = result.success ? `签到成功: \${target.name}` : result.message; setResult(msg); return msg;''';
    buffer.writeln(checkinExample);
    buffer.writeln('```');
    buffer.writeln('```\n');
    buffer.writeln('**示例 4：步骤间数据传递（查询→分析→生成报告）**\n');
    buffer.writeln('使用 setResult/getResult 在步骤之间传递数据（⚠️ 必须使用对象类型）：\n');
    buffer.writeln('```\n');
    buffer.writeln('# 查询今日任务');
    buffer.writeln('获取今天的任务列表');
    buffer.writeln('```javascript');
    final step1Example =
        '''const tasks = await Aboutme.plugins.todo.getTodayTasks(); await Aboutme.toolCall.setResult({id: 'todayTasks', value: {tasks, count: tasks.length}}); return `已获取 \${tasks.length} 个任务`;''';
    buffer.writeln(step1Example);
    buffer.writeln('```');
    buffer.writeln('');
    buffer.writeln('# 统计任务情况');
    buffer.writeln('分析任务完成情况');
    buffer.writeln('```javascript');
    final step2Example =
        '''const result = await Aboutme.toolCall.getResult({id: 'todayTasks'}); const tasks = result.tasks; const completed = tasks.filter(t => t.completed).length; const rate = (completed / tasks.length * 100).toFixed(1); return `完成率: \${rate}%`;''';
    buffer.writeln(step2Example);
    buffer.writeln('```');
    buffer.writeln('```\n');
    buffer.writeln('**示例 5：多步骤操作链（查询条件+创建）**\n');
    buffer.writeln('当用户说"创建明天的任务"时，直接完成创建：\n');
    buffer.writeln('```\n');
    buffer.writeln('# 创建明天的任务');
    buffer.writeln('获取明天日期并创建任务');
    buffer.writeln('```javascript');
    final createTaskExample =
        '''const tomorrow = await Aboutme.system.getCustomDate({add: {days: 1}, relativePosition: 'startOfDay', format: 'timestamp'}); const result = await Aboutme.plugins.todo.createTask('New Task', { dueDate: tomorrow }); const msg = result.success ? 'Task created successfully' : 'Failed to create task'; setResult(msg); return msg;''';
    buffer.writeln(createTaskExample);
    buffer.writeln('```');
    buffer.writeln('```\n');

    buffer.writeln('### ⚠️ 注意事项\n');
    buffer.writeln(
      '1. **🚫 绝对禁止硬编码日期时间**：任何涉及日期时间的代码，推荐使用 `await Aboutme.system.getCustomDate(options)` 获取和处理时间',
    );
    buffer.writeln('   - 生成日记内容时，使用系统API获取的真实日期，不要使用你知识中的日期');
    buffer.writeln('   - 创建任务、账单等需要日期的操作，都必须先调用系统API');
    buffer.writeln('2. **🚫 绝对禁止使用占位符**：不允许使用 "your_xxx_id"、"请填入xxx" 等占位符');
    buffer.writeln('   - 如果用户未指定ID，优先遍历已有数据选择合适的（第一个、最近的、符合条件的）');
    buffer.writeln('   - 如果没有数据，应该先创建数据再执行操作，或者返回明确的错误提示');
    buffer.writeln(
      '3. **系统 API 直接调用**: `Aboutme.system.*` API 不需要作为单独的工具步骤，直接在代码中调用',
    );
    buffer.writeln(
      '4. **返回结果**: JavaScript 代码必须先调用 `setResult(result)` 设置返回值，然后 `return result`',
    );
    buffer.writeln('5. **JSON 字符串转义**: data 字段中的 JavaScript 代码需要正确转义引号');
    buffer.writeln('6. **异步操作**: 所有插件方法都是异步的，必须使用 `await`\n');

    return buffer.toString();
  }

  /// 后备工具 Prompt（当初始化失败时使用）
  static String fallbackToolPrompt() {
    return r'''

## 🛠️ 可用工具列表

### ⚠️ 重要提示

作为 AI 助手，你**无法直接获取**以下类型的信息：
1. **当前时间**：你无法感知时间流逝，**绝对禁止**硬编码日期时间字符串（如 "2025-01-15"、"今天是1月15日"）
2. **用户数据**：所有用户的任务、笔记、日记等数据都存储在本地，必须使用插件工具获取

### 🚫 严格禁止的行为
1. **禁止硬编码日期时间**：
   - ❌ 错误：`const date = "2025-01-15"` 或 `const content = "今天是2025年1月15日"`
   - ✅ 正确：`const date = await Aboutme.system.getCustomDate({format: "yyyy-MM-dd"})`
2. **禁止使用占位符变量**：
   - ❌ 错误：`const channelId = "your_channel_id"` 或 `accountId: "请填入账户ID"`
   - ✅ 正确：先查询获取真实数据，然后使用实际的ID
   - ✅ 策略：用户未指定时，优先选择第一个、最近的、或符合条件的数据
   - ✅ 策略：如果没有可用数据，先创建数据再执行操作，或返回明确错误

### 系统 API（在 JavaScript 代码中直接调用）

当需要时间或设备信息时，**必须在 JavaScript 代码中调用系统API**，不要作为单独的步骤：
- `await Aboutme.system.getCustomDate(options)` - **推荐使用**，一次调用解决所有日期需求
  - options: `{baseDate?, timezone?, add?, subtract?, relativePosition?, format?}`
  - relativePosition: "startOfDay"、"endOfDay"、"startOfWeek"、"startOfMonth" 等
  - format: "object"(默认)、"timestamp"、"iso"、"text" 或自定义格式
- `await Aboutme.system.getCurrentTime()` - 获取当前时间，返回 `{timestamp, datetime, year, month, day, ...}`
- `await Aboutme.system.getTimestamp()` - 获取当前时间戳（毫秒）
- `await Aboutme.system.formatDate(dateInput, format)` - 格式化日期
- `await Aboutme.system.getDeviceInfo()` - 获取设备信息
- `await Aboutme.system.getAppInfo()` - 获取应用信息

### 步骤间结果传递 API（多步骤协作）

当工具调用包含多个步骤时，可以使用以下 API 在步骤之间传递数据：

#### ⚠️ 强制要求：必须使用对象类型

- **setResult 必须传入对象**：value 参数必须是对象类型 `{}`，不能是原始值或数组
- **getResult 返回对象**：返回值永远是对象类型，通过属性访问数据

#### API 说明

- `await Aboutme.toolCall.setResult({id?, value})` - 保存结果供后续步骤使用
  - `id` (可选): 自定义结果 ID
  - `value` (必需): **必须是对象** `{key: value}`，不能是数组或原始值
- `await Aboutme.toolCall.getResult({id?, step?, default?})` - 获取之前步骤的结果
  - `id` (可选): 结果 ID
  - `step` (可选): 步骤索引（从 0 开始）
  - `default` (可选): 默认值
  - **返回值**: 永远是对象类型，通过 `result.propertyName` 访问数据

**自动保存**：每个步骤执行成功后，结果会自动保存到 `step_N`

**🚫 错误示例（禁止）**:
```javascript
// ❌ 错误：setResult 传入数组
const tasks = await Aboutme.plugins.todo.getTasks();
await Aboutme.toolCall.setResult({value: tasks}); // 错误！tasks 是数组

// ❌ 错误：getResult 当作数组使用
const tasks = await Aboutme.toolCall.getResult({step: 0});
if (tasks.length > 0) { ... } // 错误！tasks 是对象不是数组
```

**✅ 正确示例（必须遵循）**:
```javascript
// ✅ 正确：setResult 传入对象，用属性包装数据
const tasks = await Aboutme.plugins.todo.getTasks();
await Aboutme.toolCall.setResult({value: {tasks, count: tasks.length}}); // 正确！

// ✅ 正确：getResult 返回对象，通过属性访问
const result = await Aboutme.toolCall.getResult({step: 0});
if (result.tasks && result.tasks.length > 0) { ... } // 正确！
```

### run_js（补充能力）

优先使用上方的专用插件工具。只有没有合适工具或确需组合多个操作时，才使用 JavaScript。

**JavaScript 代码可用于**:
- ✅ 数据查询(调用插件 API 获取数据)
- ✅ 数据修改(执行签到、创建任务、更新数据等操作)
- ✅ 数据处理(过滤、排序、统计、计算等)
- ✅ 数据格式化(转换数据结构、格式化输出等)

**JavaScript 代码不应用于**:
- ❌ 生成建议、分析、总结等自然语言内容
- ❌ 回答用户的"为什么"、"怎么样"等分析性问题
- ❌ 提供指导、意见或评价

**⚠️ 重要原则**:
- 当用户提出明确的操作需求时,应生成完整的操作步骤,直接完成任务
- 不要只查询信息后询问用户确认,应该根据用户意图自动完成完整流程

**正确流程**: JavaScript 返回结构化数据 → AI 基于数据进行分析和建议

## 📝 工具调用格式

**🚨 重要：必须使用 Markdown 格式，不要使用 JSON 格式！**

**严格遵循**:
1. **仅返回** Markdown 格式的工具调用
2. **不要** 任何额外文本或解释
3. **不要** 使用 JSON 格式（如 `{"steps": [...]}`）
4. **必须** 使用以下 Markdown 格式：

```markdown
# 步骤标题
## 步骤描述（可选）
```javascript
// JavaScript 代码
```
```

### 常用插件 API

**todo** (待办任务)
  - `Aboutme.plugins.todo.getTasks(status, priority)` - 获取任务
  - `Aboutme.plugins.todo.getTodayTasks()` - 获取今日任务

**notes** (笔记)
  - `Aboutme.plugins.notes.getNotes(params)` - 获取笔记

**示例**：查询今天的任务
```javascript
const today = await Aboutme.system.getCustomDate();
const tasks = await Aboutme.plugins.todo.getTodayTasks();
const result = `今天是 ${today.month}月${today.day}日，有 ${tasks.length} 个任务`;
setResult(result);
return result;
```

必须先 `setResult(result)` 设置返回值，然后 `return result`。
''';
  }

  /// 生成工具简要索引 Prompt
  static String generateToolBriefPrompt() {
    final toolIndex = ToolConfigManager.instance.getToolIndex(
      enabledOnly: true,
    );

    final buffer = StringBuffer();
    buffer.writeln('\n## 🛠️ 可用工具');
    buffer.writeln('可用工具列表（${toolIndex.length} 个）：\n');

    for (final item in toolIndex) {
      // 跳过系统工具，因为它们不作为独立步骤
      if (item[0].startsWith('system_')) continue;
      // builtin 工具是原生 FC 硬编码实现，不进 JS 索引
      if (item[0].startsWith('builtin_')) continue;
      buffer.writeln('- ${item[0]}: ${item[1]}');
    }

    return buffer.toString();
  }

  /// 后备简要 Prompt
  static String fallbackBriefPrompt() {
    return '''

## 🛠️ 可用工具

可用工具列表：
- **todo_getTasks**: 获取任务列表
- **todo_getTodayTasks**: 获取今日任务
- **notes_getNotes**: 获取笔记列表
''';
  }

  /// 生成工具详细文档；模板修改只需要文档，不附加调用输出格式。
  static Future<String> buildToolDetailPrompt(
    List<String> toolIds, {
    bool includeCallFormat = true,
  }) async {
    if (toolIds.isEmpty) {
      return '';
    }

    final toolsDetails = await ToolConfigManager.instance.getToolsDetails(
      toolIds,
    );

    final buffer = StringBuffer();
    buffer.writeln('\n## 📚 工具详细文档\n');

    // 添加字段过滤机制说明
    buffer.writeln('### ⚙️ 字段过滤机制（减少 Token 消耗）\n');
    buffer.writeln('**所有返回数据的插件方法**都支持以下可选参数来优化返回的数据量：\n');
    buffer.writeln('#### 参数说明\n');
    buffer.writeln('1. **mode** (字符串): 数据模式');
    buffer.writeln('   - `"summary"` 或 `"s"`: 仅返回统计数据（推荐：最省 Token）');
    buffer.writeln('   - `"compact"` 或 `"c"`: 返回简化字段的记录列表（平衡）');
    buffer.writeln('   - `"full"` 或 `"f"`: 返回完整数据（默认）');
    buffer.writeln('');
    buffer.writeln('2. **fields** (数组): 直接指定返回字段（优先级高于 mode）');
    buffer.writeln('   - 示例: `fields: ["id", "title", "start", "end"]`');
    buffer.writeln('   - 只返回指定字段，其他字段忽略\n');
    buffer.writeln('#### 使用建议\n');
    buffer.writeln('- 当只需要统计时，使用 `mode: "summary"`');
    buffer.writeln('- 当需要列表但不需要详细描述时，使用 `mode: "compact"`');
    buffer.writeln('- 当需要特定字段时，使用 `fields: [...]`');
    buffer.writeln('- Token 节省比例：summary(90%) > compact(75%) > full(0%)\n');
    buffer.writeln('#### 使用示例\n');
    buffer.writeln('```javascript');
    buffer.writeln('// 示例1: 使用 mode 参数获取摘要数据（最省 Token）');
    buffer.writeln(
      'const summary = await Aboutme.plugins.activity.getActivities({',
    );
    buffer.writeln('  startDate: "2025-01-01",');
    buffer.writeln('  endDate: "2025-01-31",');
    buffer.writeln('  mode: "summary"  // 仅返回统计数据');
    buffer.writeln('});');
    buffer.writeln('// 返回: { sum: { total: 50, dur: 3600, avg: 72 } }\n');
    buffer.writeln('// 示例2: 使用 fields 参数指定返回字段');
    buffer.writeln(
      'const compactData = await Aboutme.plugins.activity.getActivities({',
    );
    buffer.writeln('  startDate: "2025-01-01",');
    buffer.writeln('  endDate: "2025-01-31",');
    buffer.writeln(
      '  fields: ["id", "title", "start", "end", "dur"]  // 只返回这些字段',
    );
    buffer.writeln('});');
    buffer.writeln('// 返回: { recs: [{ id, title, start, end, dur }, ...] }');
    buffer.writeln('```\n');
    buffer.writeln('---\n');

    buffer.writeln('### 🚫 严格禁止的行为\n');
    buffer.writeln('1. **绝对禁止硬编码日期时间**：');
    buffer.writeln(
      '   - ❌ 错误：`const date = "2025-01-15"` 或 `const content = "今天是2025年1月15日"`',
    );
    buffer.writeln('   - ❌ 错误：在生成日记内容、任务标题等地方使用你知识中的日期');
    buffer.writeln(
      '   - ✅ 正确：`const date = await Aboutme.system.getCustomDate({format: "yyyy-MM-dd"})`',
    );
    buffer.writeln('   - ✅ 正确：在生成的内容中使用系统API返回的真实日期');
    buffer.writeln('2. **绝对禁止使用占位符变量**：');
    buffer.writeln(
      '   - ❌ 错误：`const channelId = "your_channel_id"` 或 `accountId: "请填入账户ID"`',
    );
    buffer.writeln(
      '   - ✅ 正确：`const channels = await Aboutme.plugins.chat.getChannels(); if (channels.length > 0) { const channelId = channels[0].id; ... }`',
    );
    buffer.writeln('   - ✅ 策略：用户未指定时，优先选择第一个、最近的、或符合条件的数据');
    buffer.writeln('   - ✅ 策略：如果没有可用数据，先创建数据再执行操作，或返回明确错误\n');

    buffer.writeln('### 系统 API（始终可用）\n');
    buffer.writeln('在生成的 JavaScript 代码中，你**必须使用**以下系统 API 获取时间信息：\n');
    buffer.writeln(
      '- `await Aboutme.system.getCustomDate(options)` - **推荐使用，解决时区问题**',
    );
    buffer.writeln(
      '  - options: `{baseDate?, timezone?, add?, subtract?, relativePosition?, format?}`',
    );
    buffer.writeln(
      '  - relativePosition: "startOfDay"、"endOfDay"、"startOfWeek"、"startOfMonth" 等',
    );
    buffer.writeln(
      '  - format: "object"、"timestamp"、"iso"、"text" 或自定义格式如 "yyyy-MM-dd"',
    );
    buffer.writeln(
      '  - 示例：`await Aboutme.system.getCustomDate({relativePosition: "startOfDay", format: "timestamp"})`',
    );
    buffer.writeln('- `await Aboutme.system.getCurrentTime()` - 获取当前时间');
    buffer.writeln(
      '  - 返回：`{ timestamp, datetime, year, month, day, hour, minute, second, weekday, weekdayName }`',
    );
    buffer.writeln('- `await Aboutme.system.getTimestamp()` - 获取当前时间戳（毫秒）');
    buffer.writeln(
      '- `await Aboutme.system.formatDate(dateInput, format)` - 格式化日期',
    );
    buffer.writeln('  - dateInput: 时间戳（毫秒）或 ISO 字符串');
    buffer.writeln('  - format: 格式模板，如 "yyyy-MM-dd HH:mm:ss"');
    buffer.writeln('- `await Aboutme.system.getDeviceInfo()` - 获取设备信息');
    buffer.writeln('- `await Aboutme.system.getAppInfo()` - 获取应用信息\n');
    buffer.writeln('⚠️ **重要**：不要将系统 API 作为单独的步骤，而是在需要时直接在代码中调用！\n');
    buffer.writeln('### 步骤间结果传递 API（多步骤数据共享）\n');
    buffer.writeln('当需要在多个步骤之间传递数据时，使用以下 API：\n');
    buffer.writeln('#### ⚠️ 强制要求：必须使用对象类型\n');
    buffer.writeln('- **setResult 必须传入对象**：value 参数必须是对象类型 `{}`，不能是原始值或数组');
    buffer.writeln('- **getResult 返回对象**：返回值永远是对象类型，通过属性访问数据\n');
    buffer.writeln('**设置结果**：');
    buffer.writeln('```javascript');
    buffer.writeln('await Aboutme.toolCall.setResult({');
    buffer.writeln('  id: "myData",    // 可选：自定义 ID');
    buffer.writeln('  value: {data: dataObj}   // 必需：必须是对象，用属性包装数据');
    buffer.writeln('});');
    buffer.writeln('```\n');
    buffer.writeln('**获取结果**：');
    buffer.writeln('```javascript');
    buffer.writeln('// 方式1: 通过自定义 ID');
    buffer.writeln(
      'const result = await Aboutme.toolCall.getResult({id: "myData"});',
    );
    buffer.writeln('const data = result.data; // 通过属性访问');
    buffer.writeln('');
    buffer.writeln('// 方式2: 通过步骤索引（0 = 第一个步骤）');
    buffer.writeln(
      'const prevResult = await Aboutme.toolCall.getResult({step: 0});',
    );
    buffer.writeln('const tasks = prevResult.tasks; // 通过属性访问数组');
    buffer.writeln('');
    buffer.writeln('// 方式3: 带默认值（防止获取失败）');
    buffer.writeln('const config = await Aboutme.toolCall.getResult({');
    buffer.writeln('  id: "config",');
    buffer.writeln('  default: {theme: "light"}');
    buffer.writeln('});');
    buffer.writeln('```\n');
    buffer.writeln('**🚫 错误示例（禁止）**:');
    buffer.writeln('```javascript');
    buffer.writeln('// ❌ 错误：setResult 传入数组');
    buffer.writeln('const tasks = await Aboutme.plugins.todo.getTasks();');
    buffer.writeln(
      'await Aboutme.toolCall.setResult({id: "tasks", value: tasks}); // 错误！tasks 是数组',
    );
    buffer.writeln('');
    buffer.writeln('// ❌ 错误：getResult 当作数组使用');
    buffer.writeln(
      'const tasks = await Aboutme.toolCall.getResult({id: "tasks"});',
    );
    buffer.writeln('if (tasks.length > 0) { ... } // 错误！tasks 是对象不是数组');
    buffer.writeln('```\n');
    buffer.writeln('**✅ 正确示例（必须遵循）**:');
    buffer.writeln('```javascript');
    buffer.writeln('// ✅ 正确：setResult 传入对象，用属性包装数据');
    buffer.writeln('const tasks = await Aboutme.plugins.todo.getTasks();');
    buffer.writeln(
      'await Aboutme.toolCall.setResult({id: "taskData", value: {tasks, count: tasks.length}}); // 正确！',
    );
    buffer.writeln('');
    buffer.writeln('// ✅ 正确：getResult 返回对象，通过属性访问');
    buffer.writeln(
      'const result = await Aboutme.toolCall.getResult({id: "taskData"});',
    );
    buffer.writeln(
      'if (result.tasks && result.tasks.length > 0) { ... } // 正确！',
    );
    buffer.writeln('```\n');
    buffer.writeln('**自动保存**：每个步骤的结果会自动保存到 `step_N`，可直接通过索引获取。\n');

    // 添加插件别名映射
    buffer.write(ToolConfigManager.generatePluginAliasesPrompt());

    buffer.writeln('---\n');
    buffer.writeln('以下是你需要的插件工具的详细使用说明：\n');

    toolsDetails.forEach((toolId, config) {
      buffer.writeln('### `$toolId` - ${config.title}\n');
      buffer.writeln('**描述**: ${config.description}\n');

      // 参数列表
      if (config.parameters.isNotEmpty) {
        buffer.writeln('**参数**:');
        for (final param in config.parameters) {
          final optionalMark = param.optional ? '(可选)' : '(必需)';
          buffer.writeln(
            '- `${param.name}` $optionalMark: ${param.type} - ${param.description}',
          );
        }
        buffer.writeln();
      }

      // 返回值
      buffer.writeln(
        '**返回值**: ${config.returns.type} - ${config.returns.description}\n',
      );

      // 示例代码
      if (config.examples.isNotEmpty) {
        buffer.writeln('**示例**:');
        for (final example in config.examples) {
          buffer.writeln('```javascript');
          buffer.writeln('// ${example.comment}');
          buffer.writeln(example.code);
          buffer.writeln('```\n');
        }
      }

      // 注意事项
      if (config.notes != null && config.notes!.isNotEmpty) {
        buffer.writeln('**注意**: ${config.notes}\n');
      }

      buffer.writeln('---\n');
    });

    if (!includeCallFormat) return buffer.toString();

    // 添加工具调用格式说明
    buffer.writeln(
      '\n优先使用上面列出的专用插件工具。仅当没有合适工具，或确需组合多个操作时，才生成 JavaScript 步骤。\n',
    );
    buffer.writeln('## 📝 生成工具调用\n');
    buffer.writeln('**🚨 重要：必须使用以下 Markdown 格式，不要使用 JSON 格式！**\n');
    buffer.writeln('**严格遵循**:');
    buffer.writeln('1. **仅返回** 以下格式的工具调用');
    buffer.writeln('2. **不要** 任何额外文本或解释');
    buffer.writeln('3. **不要** 使用 JSON 格式（如 `{"steps": [...]}`）');
    buffer.writeln('4. **不要** 在外层包裹 ` ```markdown ` 代码块');
    buffer.writeln('5. **必须** 使用以下格式：\n');
    buffer.writeln('```\n');
    buffer.writeln('# 步骤标题');
    buffer.writeln('## 步骤描述（可选）');
    buffer.writeln('```javascript');
    buffer.writeln('// JavaScript 代码');
    buffer.writeln('```');
    buffer.writeln('```\n');
    buffer.writeln('**正确示例**：');
    buffer.writeln('```\n');
    buffer.writeln('# 获取任务');
    buffer.writeln('查询今日任务');
    buffer.writeln('```javascript');
    buffer.writeln('const tasks = await Aboutme.plugins.todo.getTodayTasks();');
    buffer.writeln('return tasks;');
    buffer.writeln('```');
    buffer.writeln('```\n');
    buffer.writeln('**❌ 错误示例（禁止）**：');
    buffer.writeln('```json');
    buffer.writeln('{"steps": [{"method": "run_js", ...}]}');
    buffer.writeln('```\n');
    buffer.writeln('### 📋 返回结果的标准模式\n');
    buffer.writeln('```javascript');
    buffer.writeln('// 必须遵循以下模式：');
    buffer.writeln('const result = await Aboutme.plugins.xxx.getData();');
    buffer.writeln('setResult(result); // 1. 先设置返回值');
    buffer.writeln('return result;     // 2. 再返回');
    buffer.writeln('```\n');

    return buffer.toString();
  }
}
