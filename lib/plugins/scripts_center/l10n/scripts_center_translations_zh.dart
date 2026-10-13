/// 脚本中心插件中文翻译
const Map<String, String> scriptsCenterTranslationsZh = {
  // 插件基本信息
  'scripts_center_name': '脚本中心',
  'scripts_center_scriptCenter': '脚本中心',

  // 脚本商场
  'scripts_center_scriptStore': '脚本商场',
  'scripts_center_select_source': '选择源',
  'scripts_center_manage_sources': '管理源',
  'scripts_center_no_sources': '没有可用的源',
  'scripts_center_delete_source': '删除源',
  'scripts_center_delete_source_confirm': '确认删除源',
  'scripts_center_add_source': '添加源',
  'scripts_center_source_name': '源名称',
  'scripts_center_source_url': '源URL',
  'scripts_center_source_base_url': '基础URL',
  'scripts_center_fill_all_fields': '请填写所有字段',
  'scripts_center_source_added': '源已添加',
  'scripts_center_installed_only': '只显示已安装',
  'scripts_center_installed_status': '安装状态',
  'scripts_center_not_installed': '未安装',
  'scripts_center_no_scripts_found': '未找到脚本',
  'scripts_center_downloading': '下载中',
  'scripts_center_installing': '安装中',
  'scripts_center_install': '安装',
  'scripts_center_uninstall': '卸载',
  'scripts_center_installed': '安装成功',
  'scripts_center_uninstalled': '卸载成功',
  'scripts_center_install_failed': '安装失败',
  'scripts_center_update': '更新',
  'scripts_center_tags': '标签',
  'scripts_center_permissions': '权限',
  'scripts_center_author': '作者',
  'scripts_center_description': '描述',

  // 搜索和操作
  'scripts_center_search': '搜索脚本',
  'scripts_center_newScript': '新增脚本',

  // 脚本编辑 - 页面和按钮
  'scripts_center_editScript': '编辑脚本',
  'scripts_center_createNewScript': '创建新脚本',
  'scripts_center_save': '保存',
  'scripts_center_create': '创建',
  'scripts_center_basicInfo': '基本信息',
  'scripts_center_codeEditor': '代码编辑',
  'scripts_center_triggers': '触发条件',
  'scripts_center_advancedSettings': '高级设置',
  'scripts_center_config': '配置',
  'scripts_center_format': '格式化',
  'scripts_center_addTrigger': '添加触发器',
  'scripts_center_addTriggerCondition': '添加触发条件',
  'scripts_center_add': '添加',

  // 脚本字段
  'scripts_center_scriptName': '脚本名称',
  'scripts_center_scriptId': '脚本ID',
  'scripts_center_version': '版本号',
  'scripts_center_scriptType': '脚本类型',
  'scripts_center_updateUrl': '更新地址（可选）',
  'scripts_center_icon': '图标',
  'scripts_center_selectIcon': '选择图标',

  // 配置相关
  'scripts_center_selectAgent': '选择 AI 助手',
  'scripts_center_enabledEvents': '监听的事件',
  'scripts_center_promptTemplate': '提示词模板',

  // 脚本类型
  'scripts_center_moduleType': 'Module(可接受参数)',
  'scripts_center_standaloneType': 'Standalone(独立运行)',

  // 输入参数
  'scripts_center_addInputParameter': '添加输入参数',
  'scripts_center_enableScript': '启用脚本',
  'scripts_center_disableScript': '禁用脚本',
  'scripts_center_requiredParameter': '必填参数',
  'scripts_center_userMustFillThisParameter': '用户必须填写此参数',
  'scripts_center_thisParameterIsOptional': '此参数可选',

  // 操作按钮
  'scripts_center_cancel': '取消',
  'scripts_center_run': '运行',

  // 其他
  'scripts_center_all': '全部',

  // 参数化翻译 - 使用 @name 占位符
  'scripts_center_categoryLabel': '类别: @category',
  'scripts_center_descriptionLabel': '描述: @description',
  'scripts_center_delayLabel': '延迟: @delayms',

  // Widget Home Strings
  'scripts_center_widgetName': '脚本中心',
  'scripts_center_widgetDescription': '快速打开脚本中心',
  'scripts_center_overviewName': '脚本概览',
  'scripts_center_overviewDescription': '显示脚本统计信息',

  // 脚本快速执行小组件
  'scripts_center_scriptExecutorName': '脚本快速执行',
  'scripts_center_scriptExecutorDescription': '选择并快速执行脚本',
  'scripts_center_selectScript': '选择脚本',
  'scripts_center_script': '脚本',
  'scripts_center_tapToExecute': '点击执行',
  'scripts_center_clickToExecute': '点击执行脚本',
  'scripts_center_scriptNotFound': '脚本未找到',
  'scripts_center_scriptExecuted': '脚本执行成功',
  'scripts_center_scriptExecuteFailed': '脚本执行失败',
  'scripts_center_scriptExecuteError': '脚本执行错误',

  // 脚本列表小组件
  'scripts_center_scriptsListWidgetName': '脚本列表',
  'scripts_center_scriptsListWidgetDesc': '以彩色网格展示所有脚本',

  // 删除相关
  'scripts_center_delete_confirm': '确认删除',
  'scripts_center_delete_script_confirm': '确认删除脚本',
  'scripts_center_delete_success': '脚本删除成功',
  'scripts_center_operation_failed': '操作失败',

  // const Text 硬编码迁移(zh)
  'scripts_center_clear': '清除',
  'scripts_center_selectFile': '选择文件',
  'scripts_center_selectEventRequired': '选择事件 *',
  'scripts_center_deleteConfigFile': '删除配置文件',
  'scripts_center_clearExecutionLogs': '清空执行记录',
  'scripts_center_confirmClearLogs': '确定删除所有执行记录？此操作不可撤销。',
  'scripts_center_clearAll': '清空全部',
  'scripts_center_terminateScript': '终止脚本',
  'scripts_center_terminate': '终止',
  'scripts_center_errorMessage': '错误信息',
  'scripts_center_returnValue': '返回值',
  'scripts_center_imagePreview': '图片预览',
  'scripts_center_imageLoadFailed': '图片加载失败（文件可能已被移动或删除）',
  'scripts_center_failedOnly': '仅看失败',
  'scripts_center_allScripts': '全部脚本',
  'scripts_center_selectConfigFile': '选择配置文件',
  'scripts_center_executionLogs': '执行记录',
  'scripts_center_exportScript': '导出脚本',
  'scripts_center_exportScriptDesc': '导出代码、元数据和所有配置文件',
  'scripts_center_importJsFile': '导入 JS 文件',
  'scripts_center_required': '必填',
  'scripts_center_addLink': '添加链接',
  'scripts_center_addImageLink': '添加图片链接',

  // 执行记录页面
  'scripts_center_logsCleared': '执行记录已清空',
  'scripts_center_terminateConfirm':
      '确定终止「@name」？\n\n将中断脚本所有挂起的操作，执行记录中会标记为"脚本已被用户终止"。\n注意：如有多个脚本同时在运行，会一并终止。',
  'scripts_center_terminateRequested': '已请求终止，等待脚本退出...',
  'scripts_center_status': '状态',
  'scripts_center_statusSuccess': '成功',
  'scripts_center_statusFailed': '失败',
  'scripts_center_triggerMethod': '触发方式',
  'scripts_center_duration': '耗时',
  'scripts_center_secondsFormat': '（@seconds秒）',
  'scripts_center_time': '时间',
  'scripts_center_generatedImages': '生成图片（@count）',
  'scripts_center_today': '今天',
  'scripts_center_runningElapsed': '已运行 @elapsed',
  'scripts_center_noExecutionLogs': '暂无执行记录',
  'scripts_center_imagesShort': '@count图',
  'scripts_center_loadFailed': '加载失败',
};
