/// 聊天插件中文翻译
class ChatTranslationsZh {
  static const Map<String, String> keys = {
    // 基础翻译
    'chat_name': '频道聊天',
    'chat_all': '所有',
    'chat_ungrouped': '未分组',
    'chat_archived': '已封存',
    'chat_editChannel': '编辑频道',
    'chat_pinChannel': '固定',
    'chat_unpinChannel': '取消固定',
    'chat_archiveChannel': '已封存',
    'chat_unarchiveChannel': '取消封存',
    'chat_archivedNoSend': '该频道已封存，无法发送消息',
    'chat_channelList': '频道列表',
    'chat_newChannel': '新建频道',
    'chat_deleteChannel': '删除频道',
    'chat_deleteMessages': '删除消息',
    'chat_draft': '草稿',
    'chat_enterMessage': '输入消息...',
    'chat_justNow': '刚刚',
    'chat_edit': '编辑',
    'chat_copy': '复制',
    'chat_delete': '删除',
    'chat_pin': '置顶',
    'chat_multiSelectMode': '多选模式',
    'chat_clearMessages': '清空消息',
    'chat_autoReplySettings': '自动回复设置',
    'chat_channelsTab': '频道',
    'chat_timelineTab': '时间线',
    'chat_today': '今天',
    'chat_yesterday': '昨天',

    // 时间相关
    'chat_minutesAgo': '@minutes分钟前',
    'chat_hoursAgo': '@hours小时前',
    'chat_daysAgo': '@days天前',

    // 高级筛选
    'chat_dateRange': '日期范围：',
    'chat_selectChannels': '选择频道：',

    // 消息操作对话框
    'chat_messageOptions': '消息选项',
    'chat_addEmoji': '添加表情',
    'chat_share': '分享',
    'chat_makeSticker': '制作贴图',
    'chat_reply': '回复',
    'chat_favorite': '收藏',
    'chat_unfavorite': '取消收藏',
    'chat_recentSymbols': '最近使用',
    'chat_removeSymbol': '移除标记',
    'chat_editMessage': '编辑消息',
    'chat_deleteMessage': '删除消息',
    'chat_deleteMessageConfirmation': '确定要删除这条消息吗？此操作不可撤销。',
    'chat_copiedToClipboard': '已复制到剪贴板',
    'chat_noMessagesYet': '暂无消息',
    'chat_noMessagesFound': '没有找到匹配的消息',

    // 聊天功能相关
    'chat_copiedSelectedMessages': '已复制所选消息',
    'chat_aiAssistantNotFound': '找不到对应的AI助手',
    'chat_aiMessages': 'AI消息',
    'chat_favoriteMessages': '收藏的消息',

    // 录音与文件相关
    'chat_fileNotAccessible': '文件不存在或无法访问',
    'chat_fileProcessingFailed': '处理文件失败: @processingError',
    'chat_fileSelectionFailed': '选择文件失败: @e',
    'chat_fileSelected': '已选择文件: @originalFileName',
    'chat_imageNotExist': '图片文件不存在',
    'chat_imageProcessingFailed': '处理图片失败: @e',
    'chat_imageSelectionFailed': '选择图片失败: @e',
    'chat_clearAllMessages': '清空消息',
    'chat_confirmClearAllMessages': '确定要清空所有消息吗？此操作不可撤销。',
    'chat_videoNotSupportedOnWeb': 'Web平台不支持视频拍摄功能',
    'chat_videoNotExist': '视频文件不存在',
    'chat_videoProcessingFailed': '处理视频失败: @processingError',
    'chat_videoSelectionFailed': '选择视频失败: @e',
    'chat_videoSent': '已发送视频: @basename',
    'chat_channelCreationFailed': '创建频道失败: @e',

    // 新增翻译
    'chat_usernameCannotBeEmpty': '用户名不能为空',
    'chat_updateFailed': '更新失败: @e',

    // UI服务相关
    'chat_channelCount': '频道数量',
    'chat_todayMessages': '今日新增消息',
    'chat_chatSettings': '聊天设置',
    'chat_showAvatarInChat': '在聊天中显示头像',
    'chat_playSoundOnSend': '发送消息播放提示音',
    'chat_showAvatarInTimeline': '在时间线中显示头像',

    // 消息输入动作
    'chat_advancedEditor': '高级编辑',
    'chat_photo': '图片',
    'chat_takePhoto': '拍照',
    'chat_recordVideo': '录像',
    'chat_video': '视频',
    'chat_file': '文件',
    'chat_smartAgent': '智能体',

    // 小组件相关
    'chat_widgetName': '聊天',
    'chat_widgetDescription': '快速打开聊天',
    'chat_overviewName': '聊天概览',
    'chat_overviewDescription': '显示频道和消息统计',
    'chat_channelQuickAccess': '频道快速访问',
    'chat_channelQuickAccessDesc': '快速打开指定频道',
    'chat_noMessages': '暂无消息',

    // 选择器相关
    'chat_channelSelectorName': '选择频道',
    'chat_channelSelectorDesc': '选择一个聊天频道',
    'chat_selectChannel': '选择频道',
    'chat_noChannels': '暂无频道，请先创建',

    // 其他UI元素
    'chat_errorFilePreviewFailed': '预览文件失败: @e',
    'chat_audioMessageBubbleErrorText': '音频消息气泡错误文本',
    'chat_metadataFilters': '元数据筛选器',

    // 频道相关
    'chat_channelName': '频道名称',
    'chat_username': '用户名',
    'chat_channelGroupLabel': '频道分组',
    'chat_channelGroupHint': '可选，留空则归类为默认分组',

    // 底部栏按钮
    'chat_create': '创建',
    'chat_cancel': '取消',

    // 其他

    // 界面搜索
    'chat_channelListTitle': '频道列表',
    'chat_searchPlaceholder': '搜索频道名称',

    // 标签功能
    'chat_tagsTab': '标签',
    'chat_statsTab': '统计',

    // 消息统计
    'chat_statsUnit': '条',
    'chat_statsVsYesterday': '@diff 较昨日',
    'chat_statsTotalSummary': '共 @messages 条 · @channels 个频道',
    'chat_statsStreak': '连续记录 @count 天',
    'chat_statsNotStarted': '尚未开始记录',
    'chat_statsTodayChart': '今日消息分布',
    'chat_statsDailyChart': '每日消息分布',
    'chat_statsDailyAvg': '日均 @count 条',
    'chat_statsTypeChart': '消息类型分布',
    'chat_statsRanking': '频道活跃排行',
    'chat_typeSent': '发出',
    'chat_typeReceived': '收到',
    'chat_typeAudio': '语音',
    'chat_messageCount': '@count 条消息',
    'chat_searchTags': '搜索标签',
    'chat_sortByTime': '按时间排序',
    'chat_sortByCount': '按数量排序',
    'chat_sort': '排序',
    'chat_noTagsFound': '暂无标签',
    'chat_noMatchingTags': '未找到匹配的标签',
    'chat_totalMessages': '共 @count 条消息',
    'chat_channelNotFound': '频道不存在',
    'chat_searchMessages': '搜索消息',
    'chat_noMatchingMessages': '未找到匹配的消息',
    'chat_refresh': '刷新',
  
  // const Text 硬编码迁移(zh)
  'chat_deleteStickerPack': '删除贴纸包',
  'chat_stickerManager': '贴纸管理',
  'chat_deleteSticker': '删除贴纸',
  'chat_confirmDeleteSticker': '删除这个贴纸？',

  // 贴图管理（sticker_manager_screen）
  'chat_stickerNewCollection': '新建贴图合集',
  'chat_stickerCollectionCreated': '合集已创建，可继续添加贴图',
  'chat_stickerCreateFailed': '创建失败: @error',
  'chat_stickerAddedCount': '已添加 @count 张贴图',
  'chat_stickerAddFailed': '添加贴图失败: @error',
  'chat_stickerRenameCollection': '重命名合集',
  'chat_stickerDeleteConfirm': '确定删除「@name」吗？将同时删除 @count 张贴图文件，此操作不可恢复。',
  'chat_stickerCollectionDeleted': '合集已删除',
  'chat_stickerDeleteFailed': '删除失败: @error',
  'chat_stickerNameHint': '请输入合集名称',
  'chat_stickerEmptyTitle': '还没有贴图合集',
  'chat_stickerEmptyMessage': '点击右上角 + 创建，或用脚本中心下载 LINE 贴图',
  'chat_stickerCountDate': '@count 张 · @date',
  'chat_stickerMenuEdit': '编辑贴图',
  'chat_stickerMenuAdd': '添加贴图',
  'chat_stickerMenuRename': '重命名',
  'chat_stickerMenuDelete': '删除合集',
  'chat_stickerCollectionTitle': '贴图合集',
  'chat_stickerEmptyGrid': '暂无贴图，点击右上角添加',
  'chat_back': '返回',
  'chat_read': '已读',
  'chat_randomWalk': '随机漫步',
  'chat_randomWalkEmpty': '当前过滤条件下没有可漫步的消息',
  'chat_randomWalkReshuffle': '重新洗牌',
  'chat_randomWalkCount': '已漫步 @seen 张 / 共 @total 张',

  // AI 回复线程 drawer
  'chat_threadTitle': 'AI 回复',
  'chat_threadTyping': '正在输入…',
  'chat_threadThinking': '正在想…',
  'chat_threadInputHint': '发送消息…',
  'chat_threadSendFailed': '发送失败: @error',

  // 示例数据
  'chat_sampleChannelsTitle': '示例频道与消息',
  'chat_sampleChannelsDesc': '创建几个示例聊天频道、消息和设置',
    'chat_pluginNotAvailable': '插件不可用',
    'chat_videoFileNotExist': '视频文件不存在',

    // 多选模式工具栏
    'chat_copySelectedMessages': '复制选中消息',
    'chat_deleteSelectedMessages': '删除选中消息',
    'chat_exitMultiSelectMode': '退出多选模式',
};
}
