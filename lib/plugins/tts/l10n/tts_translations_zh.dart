/// TTS插件中文翻译
const Map<String, String> ttsTranslationsZh = {
  // 基础信息
  'tts_name': '语音朗读',
  'tts_servicesList': '服务列表',
  'tts_addService': '添加服务',
  'tts_editService': '编辑服务',
  'tts_deleteService': '删除服务',
  'tts_serviceName': '服务名称',
  'tts_serviceType': '服务类型',
  'tts_systemTts': '系统TTS',
  'tts_httpService': 'HTTP服务',
  'tts_minimaxService': 'MiniMax',
  'tts_defaultService': '默认服务',

  // 状态
  'tts_enabled': '已启用',
  'tts_disabled': '已禁用',

  // 参数
  'tts_pitch': '音调',
  'tts_speed': '语速',
  'tts_volume': '音量',
  'tts_voice': '语音',

  // HTTP配置
  'tts_apiUrl': 'API URL',
  'tts_headers': '请求头',
  'tts_requestBody': '请求体',
  'tts_responseType': '响应类型',
  'tts_audioFieldPath': '音频字段路径',
  'tts_audioFormat': '音频格式',
  'tts_audioBase64Encoded': '音频Base64编码',
  'tts_audioIsBase64Encoded': '音频数据是否为Base64编码',
  'tts_directAudioReturn': '直接返回音频',
  'tts_jsonWrapped': 'JSON 包裹',

  // 配置分组
  'tts_basicConfig': '基础配置',
  'tts_readingParameters': '朗读参数',
  'tts_httpConfig': 'HTTP 配置',
  'tts_minimaxConfig': 'MiniMax 配置',

  // 操作
  'tts_test': '测试',
  'tts_save': '保存',
  'tts_cancel': '取消',
  'tts_refresh': '刷新',
  'tts_setAsDefault': '设为默认',
  'tts_setAsDefaultTTSService': '设为默认朗读服务',
  'tts_enableThisService': '启用此服务',
  'tts_disableThisService': '禁用此服务',

  // 确认对话框
  'tts_confirmDelete': '确定要删除这个服务吗？',

  // 队列管理
  'tts_queue': '队列',
  'tts_currentReading': '当前朗读',
  'tts_waiting': '等待中',
  'tts_clearQueue': '清空队列',

  // 状态提示
  'tts_loading': '加载中...',
  'tts_loadingVoiceList': '正在加载语音列表...',
  'tts_testSuccess': '测试成功',
  'tts_testFailed': '测试失败',
  'tts_testFailedPrefix': '测试失败',

  // 成功提示
  'tts_serviceAdded': '服务已添加',
  'tts_serviceUpdated': '服务已更新',
  'tts_serviceDeleted': '服务已删除',
  'tts_setAsDefaultService': '已设置为默认服务',

  // 失败提示
  'tts_saveFailed': '保存失败',
  'tts_addFailed': '添加失败',
  'tts_updateFailed': '更新失败',
  'tts_deleteFailed': '删除失败',
  'tts_setDefaultFailed': '设置失败',
  'tts_loadServicesFailed': '加载服务失败',
  'tts_loadVoiceListFailed': '加载语音列表失败',

  // 空状态
  'tts_noServicesAvailable': '暂无服务',

  // 表单验证
  'tts_pleaseEnterApiUrl': '请输入API URL',
  'tts_pleaseEnterAudioFieldPath': '请输入音频字段路径',
  'tts_urlMustStartWithHttp': 'URL 必须以 http:// 或 https:// 开头',
  'tts_configValidationFailed': '配置验证失败，请检查必填项',
  'tts_pleaseEnterApiKey': '请输入 API Key',
  'tts_pleaseEnterVoiceId': '请输入语音 ID',

  // MiniMax 配置
  'tts_apiKey': 'API Key',
  'tts_voiceId': '语音 ID',
  'tts_model': '模型',
  'tts_emotion': '情绪',
  'tts_emotionHelper': '模型会根据文本自动匹配合适的情绪',
  'tts_auto': '自动',

  // 语音相关
  'tts_voiceTestText': '你好，这是语音测试',
  'tts_reloadVoiceList': '重新加载语音列表',
  'tts_fillAccordingToApi': '根据API要求填写',

  // 参数化翻译 - 使用 @name 占位符
  'tts_availableVoiceCount': '共 @count 个可用语音',

  // Widget Home Strings
  'tts_widgetName': '语音朗读',
  'tts_widgetDescription': '快速打开语音朗读',
  'tts_overviewName': 'TTS概览',
  'tts_overviewDescription': '显示TTS服务状态',

  // 服务列表与编辑弹层
  'tts_serviceActions': '服务操作',
  'tts_noServicesHint': '点击右下角的按钮添加第一个服务',
  'tts_pleaseEnterName': '请输入服务名称',
  'tts_pleaseSelect': '请选择',
  'tts_urlPlaceholderHint': '支持占位符: {text}, {voice}, {pitch}, {speed}, {volume}',
  'tts_headersHint': '每行一个键值对，格式：Key: Value',
  'tts_requestBodyHint': 'JSON 格式，支持占位符',
  'tts_audioFieldPathHint': '用点号分隔的JSON路径',
  'tts_apiKeyHint': '在 https://platform.minimaxi.com 获取',
  'tts_voiceIdHint': '支持系统音色、复刻音色和文生音色',

  // 语音性别
  'tts_male': '男',
  'tts_female': '女',
  'tts_neutral': '中性',

  // MiniMax 情绪
  'tts_emotionHappy': '高兴',
  'tts_emotionSad': '悲伤',
  'tts_emotionAngry': '愤怒',
  'tts_emotionFearful': '害怕',
  'tts_emotionDisgusted': '厌恶',
  'tts_emotionSurprised': '惊讶',
  'tts_emotionCalm': '平静',
  'tts_emotionFluent': '生动',
  'tts_emotionWhisper': '低语',
  'tts_serviceStatusSummary': '已配置 @total 个服务，启用 @enabled 个',
};
