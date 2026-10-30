/// 聊天插件英文翻译
class ChatTranslationsEn {
  static const Map<String, String> keys = {
    // Basic translations
    'chat_name': 'Chat',
    'chat_all': 'All',
    'chat_ungrouped': 'Ungrouped',
    'chat_archived': 'Archived',
    'chat_editChannel': 'Edit Channel',
    'chat_pinChannel': 'Pin',
    'chat_unpinChannel': 'Unpin',
    'chat_archiveChannel': 'Archive',
    'chat_unarchiveChannel': 'Unarchive',
    'chat_archivedNoSend': 'This channel is archived. Sending messages is disabled.',
    'chat_channelList': 'Channel List',
    'chat_newChannel': 'New Channel',
    'chat_deleteChannel': 'Delete Channel',
    'chat_deleteMessages': 'Delete Messages',
    'chat_draft': 'Draft',
    'chat_enterMessage': 'Type a message...',
    'chat_justNow': 'Just now',
    'chat_edit': 'Edit',
    'chat_copy': 'Copy',
    'chat_delete': 'Delete',
    'chat_pin': 'Pin',
    'chat_multiSelectMode': 'Multi-select Mode',
    'chat_clearMessages': 'Clear Messages',
    'chat_autoReplySettings': 'Auto Reply Settings',
    'chat_channelsTab': 'Channels',
    'chat_timelineTab': 'Timeline',
    'chat_today': 'Today',
    'chat_yesterday': 'Yesterday',

    // Time related
    'chat_minutesAgo': '@minutes minutes ago',
    'chat_hoursAgo': '@hours hours ago',
    'chat_daysAgo': '@days days ago',

    // Advanced filter
    'chat_dateRange': 'Date range:',
    'chat_selectChannels': 'Select channels:',

    // Message options dialog
    'chat_messageOptions': 'Message Options',
    'chat_addEmoji': 'Add Emoji',
    'chat_share': 'Share',
    'chat_makeSticker': 'Make Sticker',
    'chat_reply': 'Reply',
    'chat_favorite': 'Favorite',
    'chat_unfavorite': 'Unfavorite',
    'chat_recentSymbols': 'Recently used',
    'chat_removeSymbol': 'Remove Symbol',
    'chat_editMessage': 'Edit Message',
    'chat_deleteMessage': 'Delete Message',
    'chat_deleteMessageConfirmation':
        'Are you sure you want to delete this message? This action cannot be undone.',
    'chat_copiedToClipboard': 'Copied to clipboard',
    'chat_noMessagesYet': 'No messages yet',
    'chat_noMessagesFound': 'No messages found for',

    // Chat functionality related
    'chat_copiedSelectedMessages': 'Selected messages copied',
    'chat_aiAssistantNotFound': 'Corresponding AI assistant not found',
    'chat_aiMessages': 'AI Messages',
    'chat_favoriteMessages': 'Favorite Messages',

    // Recording and file related
    'chat_fileNotAccessible': 'File does not exist or is not accessible',
    'chat_fileProcessingFailed': 'File processing failed: @processingError',
    'chat_fileSelectionFailed': 'File selection failed: @e',
    'chat_fileSelected': 'File selected: @originalFileName',
    'chat_imageNotExist': 'Image file does not exist',
    'chat_imageProcessingFailed': 'Image processing failed: @e',
    'chat_imageSelectionFailed': 'Image selection failed: @e',
    'chat_clearAllMessages': 'Clear All Messages',
    'chat_confirmClearAllMessages':
        'Are you sure you want to clear all messages? This action cannot be undone.',
    'chat_videoNotSupportedOnWeb':
        'Video recording is not supported on Web platform',
    'chat_videoNotExist': 'Video file does not exist',
    'chat_videoProcessingFailed': 'Video processing failed: @processingError',
    'chat_videoSelectionFailed': 'Video selection failed: @e',
    'chat_videoSent': 'Video sent: @basename',
    'chat_channelCreationFailed': 'Failed to create channel: @e',

    // New translations
    'chat_usernameCannotBeEmpty': 'Username cannot be empty',
    'chat_updateFailed': 'Update failed: @e',

    // UI service related
    'chat_channelCount': 'Channels',
    'chat_todayMessages': 'Today',
    'chat_chatSettings': 'Chat Settings',
    'chat_showAvatarInChat': 'Show avatar in chat',
    'chat_playSoundOnSend': 'Play sound when sending message',
    'chat_showAvatarInTimeline': 'Show avatar in timeline',

    // Message input actions
    'chat_advancedEditor': 'Advanced Editor',
    'chat_photo': 'Photo',
    'chat_takePhoto': 'Take Photo',
    'chat_recordVideo': 'Record Video',
    'chat_video': 'Video',
    'chat_file': 'File',
    'chat_smartAgent': 'Smart Agent',

    // Widget related
    'chat_widgetName': 'Chat',
    'chat_widgetDescription': 'Quick access to chat',
    'chat_overviewName': 'Chat Overview',
    'chat_overviewDescription': 'Display channel and message statistics',
    'chat_channelQuickAccess': 'Channel Quick Access',
    'chat_channelQuickAccessDesc': 'Quickly open a specific channel',
    'chat_noMessages': 'No messages',

    // Selector related
    'chat_channelSelectorName': 'Select Channel',
    'chat_channelSelectorDesc': 'Choose a chat channel',
    'chat_selectChannel': 'Select Channel',
    'chat_noChannels': 'No channels, please create one first',

    // Other UI elements
    'chat_errorFilePreviewFailed': 'Failed to preview file: @e',
    'chat_audioMessageBubbleErrorText': 'Failed to load audio message: @e',
    'chat_metadataFilters': 'Metadata filters',

    // Channel related
    'chat_channelName': 'Channel Name',
    'chat_username': 'Username',
    'chat_channelGroupLabel': 'Channel Groups',
    'chat_channelGroupHint': 'Optional, leave empty for default group',

    // Bottom bar buttons
    'chat_create': 'Create',
    'chat_cancel': 'Cancel',

    // Other

    // Interface search
    'chat_channelListTitle': 'Channel List',
    'chat_searchPlaceholder': 'Search channel name',

    // Tags feature
    'chat_tagsTab': 'Tags',
    'chat_statsTab': 'Stats',

    // Message stats
    'chat_statsUnit': 'msgs',
    'chat_statsVsYesterday': '@diff vs yesterday',
    'chat_statsTotalSummary': '@messages msgs · @channels channels',
    'chat_statsStreak': '@count-day streak',
    'chat_statsNotStarted': 'No messages yet',
    'chat_statsTodayChart': 'Today',
    'chat_statsDailyChart': 'Last 7 Days',
    'chat_statsDailyAvg': 'Avg @count / day',
    'chat_statsTypeChart': 'Message Types',
    'chat_statsRanking': 'Top Channels',
    'chat_typeSent': 'Sent',
    'chat_typeReceived': 'Received',
    'chat_typeAudio': 'Audio',
    'chat_messageCount': '@count messages',
    'chat_searchTags': 'Search tags',
    'chat_sortByTime': 'Sort by Time',
    'chat_sortByCount': 'Sort by Count',
    'chat_sort': 'Sort',
    'chat_noTagsFound': 'No Tags Found',
    'chat_noMatchingTags': 'No Matching Tags',
    'chat_totalMessages': 'Total @count messages',
    'chat_channelNotFound': 'Channel not found',
    'chat_searchMessages': 'Search messages',
    'chat_noMatchingMessages': 'No matching messages',
    'chat_refresh': 'Refresh',
  
  // const Text 硬编码迁移(en)
  'chat_deleteStickerPack': 'Delete Sticker Pack',
  'chat_stickerManager': 'Sticker Manager',
  'chat_deleteSticker': 'Delete Sticker',
  'chat_confirmDeleteSticker': 'Delete this sticker?',

  // Sticker manager (sticker_manager_screen)
  'chat_stickerNewCollection': 'New Sticker Pack',
  'chat_stickerCollectionCreated': 'Pack created, you can add stickers now',
  'chat_stickerCreateFailed': 'Failed to create: @error',
  'chat_stickerAddedCount': 'Added @count stickers',
  'chat_stickerAddFailed': 'Failed to add stickers: @error',
  'chat_stickerRenameCollection': 'Rename Pack',
  'chat_stickerDeleteConfirm': 'Delete "@name"? This also deletes @count sticker files and cannot be undone.',
  'chat_stickerCollectionDeleted': 'Pack deleted',
  'chat_stickerDeleteFailed': 'Failed to delete: @error',
  'chat_stickerNameHint': 'Enter pack name',
  'chat_stickerEmptyTitle': 'No sticker packs yet',
  'chat_stickerEmptyMessage': 'Tap + above to create one, or download LINE stickers in Script Center',
  'chat_stickerCountDate': '@count stickers · @date',
  'chat_stickerMenuEdit': 'Edit Stickers',
  'chat_stickerMenuAdd': 'Add Stickers',
  'chat_stickerMenuRename': 'Rename',
  'chat_stickerMenuDelete': 'Delete Pack',
  'chat_stickerCollectionTitle': 'Sticker Pack',
  'chat_stickerEmptyGrid': 'No stickers yet, tap + above to add',
  'chat_back': 'Back',
  'chat_read': 'Read',
  'chat_randomWalk': 'Random Walk',
  'chat_randomWalkEmpty': 'No messages to walk through under current filters',
  'chat_randomWalkReshuffle': 'Reshuffle',
  'chat_randomWalkCount': '@seen of @total cards seen',

  // AI reply thread drawer
  'chat_threadTitle': 'AI Replies',
  'chat_threadTyping': 'Typing…',
  'chat_threadThinking': 'Thinking…',
  'chat_threadViewThinking': 'View thinking process',
  'chat_threadThinkingProcess': 'Thinking Process',
  'chat_threadInputHint': 'Send a message…',
  'chat_threadSendFailed': 'Failed to send: @error',

  // Sample data
  'chat_sampleChannelsTitle': 'Sample channels & messages',
  'chat_sampleChannelsDesc': 'Create sample chat channels, messages and settings',
    'chat_pluginNotAvailable': 'Plugin not available',
    'chat_videoFileNotExist': 'Video file does not exist',

    // Multi-select mode toolbar
    'chat_copySelectedMessages': 'Copy Selected Messages',
    'chat_deleteSelectedMessages': 'Delete Selected Messages',
    'chat_exitMultiSelectMode': 'Exit Multi-Select Mode',
};
}
