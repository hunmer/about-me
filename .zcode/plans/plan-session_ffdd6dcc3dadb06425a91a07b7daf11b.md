1. 在 `lib/plugins/habits/habits_js_api.dart` 的 `_jsCreateHabit` 增加 JSAPI 专用 skill 处理：复制传入参数，读取并 `trim()` `skillId`；空字符串按未传处理并移除该字段。对非空 skill ID 等待 `SkillController.initialized` 完成后查询现有 skill；存在则保持原 ID 直接创建习惯，不存在则调用现有 `HabitsUseCase.createSkill`，使用该 ID 同时作为新 skill 的 `id` 和 `title`。若 skill 查询或创建失败，返回错误并不创建习惯；成功后再调用原有 `createHabit`。这样只修复 JSAPI/plugin_tool 路径，不改变其他 UseCase 调用方行为。

2. 在 `test/habits_tool_regression_test.dart` 增加回归测试，使用现有真实插件与临时存储的 `invoke` 入口覆盖：
   - 传入不存在的 `skillId` 时，`createHabit` 成功创建 skill，skill 的 ID/标题正确，返回习惯绑定同一 ID，并清理习惯和 skill。
   - 传入已有 skill ID 时，创建习惯复用该 skill，不产生错误或替换 skill 信息，并清理测试数据。
   - 延伸现有扁平化参数测试，确认 `skillId: ''` 不会保存空字符串关联。

3. 保留 `habits.json` 现有自动创建契约，因为实现将使其与行为一致；不修改底层 SDK 或通用 `HabitsUseCase.createHabit`。完成后运行目标回归测试（必要时先执行格式化），根据失败结果修正参数映射或初始化时序。