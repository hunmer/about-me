/// Agent Chat插件中文翻译
const Map<String, String> agentChatTranslationsZh = {
  // 对话列表页面
  'agent_chat_addChannel': '添加频道',
  'agent_chat_editConversation': '编辑会话',
  'agent_chat_confirmDelete': '确认删除',
  'agent_chat_delete': '删除',
  'agent_chat_clear': '清除',

  // 聊天页面
  'agent_chat_selectAgent': '选择Agent',
  'agent_chat_tokenStatistics': 'Token统计',
  'agent_chat_close': '关闭',
  'agent_chat_save': '保存',
  'agent_chat_cancel': '取消',
  'agent_chat_confirmClear': '确认清空',
  'agent_chat_confirmClearTools': '确定要清空所有选中的工具吗？',
  'agent_chat_confirmDeleteMessage': '确定要删除这条消息吗？',
  'agent_chat_editMessage': '编辑消息',
  'agent_chat_toolExecutionResult': '工具执行结果',
  'agent_chat_image': '图片',
  'agent_chat_document': '文档',

  // 工具模板页面
  'agent_chat_toolTemplate': '工具模板',
  'agent_chat_use': '使用',
  'agent_chat_reset': '重置',
  'agent_chat_confirm': '确定',

  // 工具管理页面
  'agent_chat_toolManagement': '工具管理',
  'agent_chat_selectPlugin': '选择插件',
  'agent_chat_confirmImport': '确认导入',
  'agent_chat_importConfigOverride': '导入配置将覆盖现有配置,是否继续?',
  'agent_chat_confirmRestoreDefault': '确认恢复默认',
  'agent_chat_restoreDefaultDescription': '此操作将删除所有自定义配置,恢复到默认配置。是否继续?',
  'agent_chat_restoreDefault': '恢复默认',
  'agent_chat_all': '全部',
  'agent_chat_thisPlugin': '本插件',
  'agent_chat_groupFilter': '分组',
  'agent_chat_disabledTools': '已禁用的工具',
  'agent_chat_enableAll': '全部启用',
  'agent_chat_confirmEnableAll': '确认全部启用',

  // 设置页面
  'agent_chat_agentChatSettings': 'Agent Chat 设置',
  'agent_chat_prioritizeToolTemplate': '优先使用工具模版',
  'agent_chat_prioritizeToolTemplateDescription': '启用后,AI将优先使用预定义的工具模板执行任务',
  'agent_chat_enableBackgroundService': '启用后台服务',
  'agent_chat_enableBackgroundServiceDescription': '切换到其他应用后继续接收AI回复。会显示前台通知以保持服务运行。',
  'agent_chat_showTokenConsumption': '显示Token消耗',
  'agent_chat_showTokenConsumptionDescription': '在通知中实时显示输入/输出token数量和总消耗。',

  // 配置对话框
  'agent_chat_copyResult': '复制结果',
  'agent_chat_executeAgain': '重新执行此步骤',
  'agent_chat_viewCreatedDetail': '点击查看详情',

  // 新增的硬编码文本
  'agent_chat_initializationFailed': '初始化失败: @error',
  'agent_chat_goBack': '返回',

  // 消息操作
  'agent_chat_edit': '编辑',
  'agent_chat_saveTool': '保存工具',
  'agent_chat_send': '发送',

  // 工具相关
  'agent_chat_addTool': '添加工具',
  'agent_chat_importConfig': '导入配置',
  'agent_chat_exportConfig': '导出配置',
  'agent_chat_noToolConfig': '暂无工具配置',
  'agent_chat_allToolsEnabled': '所有工具都已启用!',
  'agent_chat_confirmEnableAllTools': '确定要启用所有 @count 个已禁用的工具吗?',
  'agent_chat_enableTool': '启用工具',
  'agent_chat_disableToolWarning': '禁用后该工具将不会提供给AI使用',
  'agent_chat_addParameter': '添加参数',
  'agent_chat_noParametersClickToAdd': '暂无参数,点击上方按钮添加',
  'agent_chat_optionalParameter': '可选参数',
  'agent_chat_addExample': '添加示例',
  'agent_chat_noExamplesClickToAdd': '暂无示例,点击上方按钮添加',
  'agent_chat_test': '测试',
  'agent_chat_executingJSCode': '正在执行 JS 代码...',
  'agent_chat_confirmDeleteTool': '确定要删除工具 "@toolId" 吗?',
  'agent_chat_deleteConfirmation': '删除确认',
  'agent_chat_confirmDeleteTemplate': '确定要删除工具模板"@templateName"吗?',
  'agent_chat_resetConfirmation': '重置确认',
  'agent_chat_resettingDefaultTemplates': '正在重置默认模板...',

  // 创建对话框
  'agent_chat_aiChat': 'AI 对话',

  // 插件信息
  'agent_chat_pluginInfo': '@pluginId (@enabledCount/@totalCount)',

  // 确认删除会话
  'agent_chat_confirmDeleteConversation': '确定要删除会话 "@title" 吗?\n\n此操作将同时删除所有消息记录,且不可恢复。',

  // 空状态
  'agent_chat_loadingToolTemplates': '正在加载工具模板...',

  // Widget Home Strings
  'agent_chat_pluginName': 'AI 对话',
  'agent_chat_name': 'AI 对话',
  'agent_chat_overview': 'Agent Chat 概览',
  'agent_chat_overviewDescription': '显示会话统计信息',
  'agent_chat_totalConversations': '会话总数',
  'agent_chat_unreadMessages': '未读消息',
  'agent_chat_totalGroups': '分组总数',

  // 选择器小组件
  'agent_chat_conversationSelectorName': '会话选择',
  'agent_chat_conversationSelectorDesc': '选择一个会话频道',
  'agent_chat_selectConversation': '选择会话',
  'agent_chat_conversationQuickAccess': 'AI 频道快捷入口',
  'agent_chat_conversationQuickAccessDesc': '快速进入指定的 AI 会话频道',
  'agent_chat_justNow': '刚刚',
  'agent_chat_minutesAgo': '@count 分钟前',
  'agent_chat_hoursAgo': '@count 小时前',
  'agent_chat_daysAgo': '@count 天前',

  // 界面搜索
  'agent_chat_searchPlaceholder': '搜索会话...',

  // const Text 硬编码迁移(zh)

  // 工具模板管理
  'agent_chat_tag': '标签',
  'agent_chat_emptyTemplates': '暂无保存的工具模板',
  'agent_chat_noMatchTemplates': '未找到匹配的模板',
  'agent_chat_emptyTemplatesHint': '在AI工具调用消息中点击"保存工具"即可保存',
  'agent_chat_stepCount': '@count 个步骤',
  'agent_chat_usedCount': '使用 @count 次',
  'agent_chat_toolCount': '@count 个工具',
  'agent_chat_deleteSuccess': '删除成功',
  'agent_chat_deleteFailed': '删除失败: @error',
  'agent_chat_resetDefaultTemplates': '重置默认模板',
  'agent_chat_resetDefaultHint':
      '此操作将强制恢复所有默认工具模板到初始状态。\n\n⚠️ 注意：如果您修改过默认模板，这些修改将会被覆盖！\n\n自定义模板不会受到影响。',
  'agent_chat_resetSuccess': '默认模板已成功重置',
  'agent_chat_resetFailed': '重置失败: @error',
  'agent_chat_executeTest': '执行测试',
  'agent_chat_editToolTemplate': '编辑工具模板',
  'agent_chat_basicInfo': '基础信息',
  'agent_chat_executionSteps': '执行步骤',
  'agent_chat_toolNameLabel': '工具名称 *',
  'agent_chat_toolNameHint': '例如:导出数据',
  'agent_chat_toolNameRequired': '请输入工具名称',
  'agent_chat_toolNameExists': '该名称已存在',
  'agent_chat_descriptionOptional': '描述(可选)',
  'agent_chat_descriptionHint': '描述这个工具的用途...',
  'agent_chat_declaredToolsCount': '声明使用的工具 (@count)',
  'agent_chat_tagsOptional': '标签(可选)',
  'agent_chat_tagInputHint': '输入标签后按回车添加',
  'agent_chat_addTag': '添加标签',
  'agent_chat_addStep': '添加步骤',
  'agent_chat_deleteStep': '删除步骤',
  'agent_chat_noStepsHint': '暂无步骤,点击上方按钮添加',
  'agent_chat_stepIndex': '步骤 @index',
  'agent_chat_stepCountLabel': '执行步骤 (@count)',
  'agent_chat_stepTitle': '步骤标题',
  'agent_chat_stepDesc': '步骤描述',
  'agent_chat_stepCode': 'JavaScript 代码',
  'agent_chat_stepCodeHint': 'const result = await Aboutme.plugins...',
  'agent_chat_needOneStep': '至少需要一个步骤',
  'agent_chat_stepCodeRequired': '步骤 @index 的代码不能为空',
  'agent_chat_templateUpdated': '工具模板 "@name" 更新成功',
  'agent_chat_toolSaved': '工具 "@name" 保存成功',

  // 示例数据
  'agentChat_sampleConversationsTitle': '示例会话与消息',
  'agentChat_sampleConversationsDesc': '创建分组好的示例 AI 会话和消息记录',
    'agent_chat_conversationNotFound': '未找到对话',
    'agent_chat_pluginNotAvailable': '插件不可用',
};
