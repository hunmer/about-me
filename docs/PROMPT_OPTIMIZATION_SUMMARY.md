# Prompt 优化总结

本次更新主要针对 AI Agent 工具调用的 Prompt 进行了三项重要优化，以解决代码生成中的常见问题。

## 📝 改动概述

### 1. ✅ 增加插件别名关键词映射

**改动文件**：`lib/plugins/agent_chat/services/tool_config_manager.dart`

**新增内容**：
- 添加了 `_pluginAliases` 静态常量，包含18个插件的中文别名映射
- 添加了 `getPluginAliases()` 方法获取别名映射
- 添加了 `generatePluginAliasesPrompt()` 方法生成别名说明

**别名映射示例**：
```dart
'bill': ['账单', '记账', '账本', '财务', '消费', '支出', '收入', '花销'],
'chat': ['聊天', '频道', '消息', '对话', '会话'],
'diary': ['日记', '日志', '记录'],
'todo': ['任务', '待办', '清单', '事项', '计划'],
// ... 更多插件
```

**效果**：
- 用户说"帮我记一笔账" → AI 自动识别为 `bill` 插件
- 用户说"查看今天的任务" → AI 自动识别为 `todo` 插件
- 用户说"给频道发消息" → AI 自动识别为 `chat` 插件

---

### 2. ✅ 优化 Prompt，增强禁止硬编码日期的说明

**改动文件**：`lib/plugins/agent_chat/services/tool_service.dart`

**新增/修改的 Prompt 内容**：

#### 在重要提示部分：
```markdown
### ⚠️ 重要提示
1. **当前时间**：你无法感知时间流逝，**绝对禁止**硬编码日期时间字符串（如 "2025-01-15"、"今天是1月15日"）

### 🚫 严格禁止的行为
1. **禁止硬编码日期时间**：
   - ❌ 错误：`const date = "2025-01-15"` 或 `const content = "今天是2025年1月15日"`
   - ✅ 正确：`const time = await Aboutme.system.getCurrentTime(); const date = \`${time.year}-${String(time.month).padStart(2, '0')}-${String(time.day).padStart(2, '0')}\``
```

#### 在系统 API 部分：
```markdown
### 系统 API（在 JavaScript 代码中直接调用）
- `await Aboutme.system.getCurrentTime()` - **必须使用此API获取当前时间**
  返回 `{timestamp, datetime, year, month, day, hour, minute, second, weekday, weekdayName}`
```

#### 在注意事项部分：
```markdown
1. **🚫 绝对禁止硬编码日期时间**：任何涉及日期时间的代码，必须使用 `await Aboutme.system.getCurrentTime()` 获取当前时间
   - 生成日记内容时，使用系统API获取的真实日期，不要使用你知识中的日期
   - 创建任务、账单等需要日期的操作，都必须先调用系统API
```

**效果**：
- 防止AI在生成日记内容时使用错误的日期
- 确保所有涉及日期的操作都使用实时获取的系统时间
- 避免出现 "今天是2025年1月15日" 这样的硬编码日期

---

### 3. ✅ 禁止占位符变量，优先遍历已有数据

**改动文件**：`lib/plugins/agent_chat/services/tool_service.dart`

**新增的 Prompt 规则**：

```markdown
### 🚫 严格禁止的行为
2. **禁止使用占位符变量**：
   - ❌ 错误：`const channelId = "your_channel_id"` 或 `accountId: "请填入账户ID"`
   - ✅ 正确：先查询获取真实数据，然后使用实际的ID
   - ✅ 示例：`const channels = await Aboutme.plugins.chat.getChannels(); const firstChannel = channels[0]; await Aboutme.plugins.chat.sendMessage({channelId: firstChannel.id, content: "消息内容"})`
```

**处理策略**：
```markdown
2. **🚫 绝对禁止使用占位符**：不允许使用 "your_xxx_id"、"请填入xxx" 等占位符
   - 如果用户未指定ID，优先遍历已有数据选择合适的（第一个、最近的、符合条件的）
   - 如果没有数据，应该先创建数据再执行操作，或者返回明确的错误提示
```

**效果**：
- 不再生成 `channelId: "your_channel_id"` 这样的占位符代码
- 自动遍历已有数据，选择第一个或最合适的
- 如果没有数据，会先创建或返回明确错误

---

## 🔄 修改的文件清单

1. **lib/plugins/agent_chat/services/tool_config_manager.dart**
   - 添加 `_pluginAliases` 常量（47-67行）
   - 添加 `getPluginAliases()` 方法（561-564行）
   - 添加 `generatePluginAliasesPrompt()` 方法（566-582行）

2. **lib/plugins/agent_chat/services/tool_service.dart**
   - 修改 `_generateToolListPrompt()` 方法
     - 增强日期禁止说明（204-224行）
     - 添加插件别名映射（255行）
     - 更新注意事项（343-353行）
   - 修改 `_getFallbackToolPrompt()` 方法（358-441行）
   - 修改 `getToolDetailPrompt()` 方法
     - 添加严格禁止规则（541-551行）
     - 添加插件别名映射（567行）

3. **test/tool_service_prompt_test.dart**（新建）
   - 添加单元测试验证所有改动

---

## ✅ 测试验证

创建了完整的测试套件，所有测试通过：
```bash
flutter test test/tool_service_prompt_test.dart
# 结果：7个测试全部通过 ✓
```

测试覆盖：
- ✅ 插件别名映射包含所有主要插件
- ✅ 插件别名Prompt格式正确
- ✅ Prompt包含禁止硬编码日期的警告
- ✅ Prompt包含正确和错误的示例
- ✅ 详细工具Prompt包含插件别名映射
- ✅ Prompt强调系统API的使用
- ✅ Prompt包含避免占位符的策略

---

## 📖 使用示例

### 示例1：生成日记（正确使用系统时间）

**用户输入**："帮我写一篇日记"

**AI生成的代码**（正确）：
```javascript
const time = await Aboutme.system.getCurrentTime();
const date = `${time.year}-${String(time.month).padStart(2, '0')}-${String(time.day).padStart(2, '0')}`;
const content = `今天是${time.year}年${time.month}月${time.day}日，星期${time.weekdayName}...`;
const diary = await Aboutme.plugins.diary.createEntry({
  date: date,
  content: content
});
setResult(`日记已创建：${date}`);
return `日记已创建：${date}`;
```

### 示例2：发送消息（自动选择频道）

**用户输入**："给频道发个消息说测试"

**AI生成的代码**（正确）：
```javascript
const channels = await Aboutme.plugins.chat.getChannels();
if (channels.length === 0) {
  setResult('错误：没有可用频道');
  return '错误：没有可用频道';
}
const firstChannel = channels[0];
const message = await Aboutme.plugins.chat.sendMessage({
  channelId: firstChannel.id,
  content: '测试'
});
setResult(`消息已发送到频道：${firstChannel.name}`);
return `消息已发送到频道：${firstChannel.name}`;
```

### 示例3：记账（自动选择账户）

**用户输入**："帮我记一笔支出，吃饭花了50块"

**AI生成的代码**（正确）：
```javascript
const time = await Aboutme.system.getCurrentTime();
const today = `${time.year}-${String(time.month).padStart(2, '0')}-${String(time.day).padStart(2, '0')}`;
const accounts = await Aboutme.plugins.bill.getAccounts({});
if (accounts.length === 0) {
  setResult('错误：没有可用账户，请先创建账户');
  return '错误：没有可用账户，请先创建账户';
}
const firstAccount = accounts[0];
const bill = await Aboutme.plugins.bill.createBill({
  accountId: firstAccount.id,
  amount: -50,
  category: '餐饮',
  title: '吃饭',
  date: today
});
setResult(`已记录支出：50元，账户：${firstAccount.title}`);
return `已记录支出：50元，账户：${firstAccount.title}`;
```

---

## 🎯 预期改进效果

1. **日期准确性**：AI生成的日记、任务、账单等内容将使用真实的当前日期，而不是错误的硬编码日期
2. **代码可执行性**：不再出现 `your_channel_id` 等占位符，生成的代码可以直接执行
3. **用户体验**：用户使用自然语言（如"记账"、"聊天"）时，AI能准确识别对应的插件
4. **智能选择**：当用户未指定ID时，AI会自动选择第一个或最合适的数据

---

## 📌 注意事项

1. 这些改动主要影响AI生成的JavaScript代码质量，不影响现有功能
2. 已添加完整的单元测试，确保改动不会破坏现有功能
3. 所有改动向后兼容，不需要修改其他代码

---

**更新日期**：2025-11-19
**测试状态**：✅ 全部通过
