/// 设置屏幕中文翻译
const Map<String, String> settingsScreenTranslationsZh = {
  // 页面标题
  'settings_screen_settingsTitle': '设置',

  // 语言设置
  'settings_screen_languageTitle': '语言 (中文)',
  'settings_screen_languageSubtitle': '点击切换到英文',

  // 主题设置
  'settings_screen_darkModeTitle': '深色模式',
  'settings_screen_darkModeSubtitle': '切换应用主题',

  // 数据管理
  'settings_screen_exportDataTitle': '导出应用数据',
  'settings_screen_exportDataSubtitle': '将插件数据导出到文件',
  'settings_screen_dataManagementTitle': '数据文件管理',
  'settings_screen_dataManagementSubtitle': '管理应用数据目录中的文件',
  'settings_screen_importDataTitle': '导入应用数据',
  'settings_screen_importDataSubtitle': '从文件导入插件数据',
  'settings_screen_fullBackupTitle': '完整备份',
  'settings_screen_fullBackupSubtitle': '备份整个应用数据目录',
  'settings_screen_fullRestoreTitle': '完整恢复',
  'settings_screen_fullRestoreSubtitle': '从备份恢复整个应用数据（覆盖现有数据）',

  // 悬浮球设置
  'settings_screen_floatingBallTitle': '悬浮球设置',
  'settings_screen_floatingBallEnabled': '已启用',
  'settings_screen_floatingBallDisabled': '已禁用',

  // 插件管理
  'settings_screen_pluginManagementTitle': '插件管理',
  'settings_screen_pluginManagementSubtitle': '控制各插件是否在启动时加载',
  'settings_screen_pluginManagementTip': '关闭的插件将在下次启动时不再加载，重新开启即可恢复',

  // 自动打开上次插件
  'settings_screen_autoOpenLastPluginTitle': '自动打开上次使用的插件',
  'settings_screen_autoOpenLastPluginSubtitle': '启动时自动打开最后使用的插件',

  // 更新检查
  'settings_screen_autoCheckUpdateTitle': '自动检查更新',
  'settings_screen_autoCheckUpdateSubtitle': '定期检查应用新版本',
  'settings_screen_checkUpdateTitle': '检查更新',
  'settings_screen_checkUpdateSubtitle': '立即检查应用新版本',

  // 更新提示
  'settings_screen_updateAvailableTitle': '发现新版本',
  'settings_screen_updateAvailableContent': '当前版本: @currentVersion\n最新版本: @latestVersion\n更新内容:',
  'settings_screen_updateLaterButton': '稍后再说',
  'settings_screen_updateViewButton': '查看更新',
  'settings_screen_alreadyLatestVersion': '当前已是最新版本',
  'settings_screen_updateCheckFailed': '检查更新失败: @error',

  // 服务器同步设置

  // WebSocket 状态

  // 强制同步

  // 清空同步快照

  // 语言选择对话框
  'settingsScreen_selectLanguage': '选择语言',
  'settingsScreen_chinese': '中文',
  'settingsScreen_english': 'English',

  // const Text 硬编码迁移(zh)
  'settings_screen_changeUsername': '修改用户名',
  'settings_screen_appSettings': '应用设置',
  'settings_screen_interfaceSettings': '界面设置',
  // 手绘便签效果设置
  'settings_screen_handDrawnGroupTitle': '手绘便签效果',
  'settings_screen_handDrawnTapeTitle': '贴条',
  'settings_screen_handDrawnTapeSubtitle': '显示卡片顶部胶带贴条',
  'settings_screen_handDrawnTiltTitle': '倾斜角度',
  'settings_screen_handDrawnTiltSubtitle': '卡片保持轻微随机倾斜',
  'settings_screen_handDrawnEntranceTitle': '入场动画',
  'settings_screen_handDrawnEntranceSubtitle': '卡片淡入上滑进入列表',
  'settings_screen_tapeStyle': '贴条样式',
  'settings_screen_tapeStyleCenterTape': '居中胶带',
  'settings_screen_tapeStyleWashiTape': '和纸胶带',
  'settings_screen_tapeStyleCornerTapes': '双角斜贴',
  'settings_screen_tapeStyleStaple': '订书钉',
  // 底部导航栏磨砂玻璃设置
  'settings_screen_bottomBarGroupTitle': '底部导航栏',
  'settings_screen_bottomBarFrostedTitle': '磨砂玻璃',
  'settings_screen_bottomBarFrostedSubtitle': '弧形底栏启用背景模糊磨砂效果',
  'settings_screen_speechRecognitionSettings': '语音识别设置',
  'settings_screen_confirmClear': '确认清除',
  'settings_screen_confirmClearAiCorrection': '确定清除AI纠错Agent设置吗？',
  'settings_screen_aiCorrectionConfigured': '已配置AI纠错助手',
  'settings_screen_editAiCorrectionAgent': '编辑AI纠错Agent',
  'settings_screen_configureAiCorrectionAgent': '配置AI纠错Agent',
  'settings_screen_verifyConfiguration': '验证配置',
  'settings_screen_speechDesc': '配置腾讯云实时语音识别服务，用于语音输入功能。',
  'settings_screen_speechCredHint': '需要在腾讯云控制台开通语音识别服务并获取 API 凭证。',
  'settings_screen_speechAppIdHint': '请输入腾讯云应用 ID',
  'settings_screen_speechAppIdRequired': '请输入 App ID',
  'settings_screen_speechSecretIdHint': '请输入密钥 ID',
  'settings_screen_speechSecretIdRequired': '请输入 Secret ID',
  'settings_screen_speechSecretKeyHint': '请输入密钥 Key（请妥善保管）',
  'settings_screen_speechSecretKeyRequired': '请输入 Secret Key',
  'settings_screen_speechVerifyPassed': '配置验证通过！',
  'settings_screen_speechInvalidConfig': '配置无效，请检查输入',
  'settings_screen_speechLoadFailed': '加载设置失败：@error',
  'settings_screen_speechSaveFailed': '保存设置失败：@error',
  'settings_screen_speechVerifyFailed': '验证失败：@error',
  'settings_screen_speechAgentSaved': 'AI纠错Agent设置成功',
  'settings_screen_speechAgentCleared': '已清除AI纠错Agent设置',
  'settings_screen_speechClearFailed': '清除设置失败：@error',
  'settings_screen_speechAiCorrectionTitle': 'AI智能纠错',
  'settings_screen_speechAiCorrectionDesc': '配置AI助手来自动纠正语音识别中的错误',
  'settings_screen_speechDefaultAgentName': '语音文本纠错',
  'settings_screen_speechDefaultAgentDesc': '用于自动纠正语音识别错误的AI助手',
  'settings_screen_speechDefaultAgentTag': '语音纠错',
  'settings_screen_speechDefaultAgentPrompt':
      '你是一个专业的语音文本纠错助手。你的任务是纠正语音识别中的错误。\n\n## 工作流程\n1. 分析用户输入的文本\n2. 识别可能的识别错误（同音字、语法错误、标点错误等）\n3. 纠正错误，保持原意不变\n4. 只输出纠正后的文本，不要添加任何解释或说明\n\n## 注意事项\n- 只处理明显的识别错误\n- 保持口语化表达的自然流畅\n- 适当添加标点符号以提高可读性\n- 不要改变原文的意思\n- 如果文本本身就没有错误，直接返回原文',
  'settings_screen_switchStorageBackend': '切换存储后端',
  'settings_screen_switchStorageBackendDesc': '切换不会迁移或删除现有数据。请先导出数据并确保没有写入进行中。保存后需重启应用。',
  'settings_screen_storageBackend': '数据存储后端',
  'settings_screen_testConnection': '测试连接',
  'settings_screen_migrateLocalData': '迁移本地数据',
  'settings_screen_storageLocalFile': '本地文件',
  'settings_screen_storageHttpServer': 'HTTP 服务器',
  'settings_screen_storageServerUrl': '服务器地址',
  'settings_screen_storageServerUrlRequired': '请输入服务器地址',
  'settings_screen_storageCredentialRequired': '请输入认证凭据',
  'settings_screen_storageCopyApiKey': '复制 API Key',
  'settings_screen_storageUserId': '用户标识（可选）',
  'settings_screen_storageConnectionSuccess': '连接成功',
  'settings_screen_storageConnectionFailed': '连接失败：@error',
  'settings_screen_storageSaveFailed': '保存失败：@error',
  'settings_screen_storageMigrating': '正在迁移…',
  'settings_screen_storageMigrateProgress': '正在迁移 @completed/@total',
  'settings_screen_storageMigrateDone': '迁移完成：@migrated 个文件，跳过 @skipped 个',
  'settings_screen_storageMigrateFailed': '迁移失败：@error',
  'settings_screen_storageCopied': '已复制',
  'settings_screen_storageSavedRestart': '设置已保存，请重新启动应用',
  'settings_screen_storageRemoteUnavailable': '远程服务器不可用',
  'settings_screen_storageRemoteUnavailableDesc': '无法连接远端存储服务器，数据暂时无法同步。是否打开存储设置检查配置？',
  'settings_screen_storageOpenSettings': '打开设置',
  'settings_screen_importExportGroup': '导入导出',
  'settings_screen_backupRestoreGroup': '备份与恢复',
  'settings_screen_storageGroup': '存储',

  // 设置主页(settings_screen.dart)
  'settings_screen_generalSection': '通用',
  'settings_screen_dataSettings': '数据管理',
  'settings_screen_appSection': '应用',
  'settings_screen_enterUsernameHint': '输入用户名',
  'settings_screen_usageDuration': '使用时长',
  'settings_screen_statDaysUsed': '使用天数',
  'settings_screen_statPlugins': '插件',
  'settings_screen_statVersion': '版本',
  'settings_screen_durationDays': '@days 天 @hours 小时',
  'settings_screen_durationHours': '@hours 小时 @minutes 分',
  'settings_screen_durationMinutes': '@minutes 分钟',

  // 应用设置分组文案(app_settings_screen.dart)
  'settings_screen_generalGroup': '通用',
  'settings_screen_reminderTitle': '定时提醒',
  'settings_screen_reminderSubtitle': '管理定时提醒任务',
  'settings_screen_speechSettingsTitle': '语音识别设置',
  'settings_screen_speechConfigured': '已配置腾讯云语音识别',
  'settings_screen_speechNotConfigured': '配置语音识别服务',
  'settings_screen_clipboardGroup': '剪切板设置',
  'settings_screen_clipboardAutoReadTitle': '自动读取剪切板',
  'settings_screen_clipboardAutoReadSubtitle': '启用后将自动识别剪切板中的数据',
  'settings_screen_clipboardReadTitle': '读取并识别剪切板',
  'settings_screen_clipboardReadSubtitle': '手动读取剪切板中的数据并识别处理',
  'settings_screen_clipboardReadSuccess': '剪切板识别成功',
  'settings_screen_clipboardReadEmpty': '剪切板中没有可识别的数据',
  'settings_screen_updateGroup': '更新',
  'settings_screen_devTestGroup': '开发者测试',
  'settings_screen_routeViewerTitle': '路由查看器',
  'settings_screen_routeViewerSubtitle': '查看所有可用路由',
  'settings_screen_liveActivitiesTestTitle': 'Live Activities 测试',
  'settings_screen_liveActivitiesTestSubtitle': '测试实时活动通知',
  'settings_screen_widgetsGalleryTitle': '通用组件示例',
  'settings_screen_widgetsGallerySubtitle': '查看 widgets 目录下的通用组件示例',
  'settings_screen_logSystemTitle': '日志系统',
  'settings_screen_logSystemSubtitle': '查看和管理应用日志',
  'settings_screen_aboutGroup': '关于',
    'import_filePathError': '文件路径错误',
    'import_importSuccess': '导入成功',
    'import_importSuccessContent': '数据已成功导入，重启应用后生效',
    'import_importFailed': '导入失败',
    'import_restartLater': '稍后重启',
    'import_restartNow': '立即重启',
};
