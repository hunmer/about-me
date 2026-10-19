/// Screens通用英文翻译
final Map<String, String> screensTranslationsEn = {
  // route.dart
  'screens_error': 'Error',
  'screens_errorWidgetIdMissing': 'Error: widgetId parameter is missing',
  'screens_errorHabitIdRequired': 'Error: habitId is required',
  'screens_errorHabitsPluginNotFound': 'Error: HabitsPlugin not found',
  'screens_errorHabitNotFound': 'Error: Habit not found with id: @id',

  // floating_widget_screen
  'screens_floatingBallSettings': 'System Floating Ball',
  'screens_requestPermission': 'Request Permission',
  'screens_floatingBallConfig': 'Floating Ball Configuration',
  'screens_customizeFloatingBallAppearanceBehavior':
      'Customize the appearance and behavior of the floating ball',
  'screens_selectImageAsFloatingBall': 'Select image as floating ball',
  'screens_sizeColon': 'Size: ',
  'screens_ballSizeDp': '@sizedp',
  'screens_snapThresholdColon': 'Snap Threshold: ',
  'screens_snapThresholdPx': '@thresholdpx',
  'screens_autoRestoreFloatingBallState': 'Auto restore floating ball state',
  'screens_buttonCountColon': 'Button Count: ',
  'screens_buttonCount': '@count buttons',
  'screens_manageFloatingButtons': 'Manage Floating Buttons',
  'screens_currentPosition': 'Current Position',

  // home_screen
  'screens_createNewFolder': 'Create New Folder',
  'screens_addWidget': 'Add Widget',
  'screens_saveCurrentLayout': 'Save Current Layout',
  'screens_manageLayouts': 'Manage Layouts',
  'screens_themeSettings': 'Theme Settings',
  'screens_gridSettings': 'Grid Settings',
  'screens_clearLayout': 'Clear Layout',
  'screens_confirmClear': 'Confirm Clear',
  'screens_confirmClearAllWidgets':
      'Are you sure you want to clear all widgets? This action cannot be undone.',
  'screens_cancel': 'Cancel',
  'screens_confirm': 'Confirm',
  'screens_adjustSize': 'Adjust Size',
  'screens_delete': 'Delete',
  'screens_selectWidgetSize': 'Select Widget Size',
  'screens_confirmDelete': 'Confirm Delete',
  'screens_confirmDeleteItem': 'Are you sure you want to delete "@itemName"?',
  'screens_moveToFolder': 'Move to Folder',
  'screens_topDisplay': 'Top Display',
  'screens_centerDisplay': 'Center Display',
  'screens_complete': 'Complete',
  'screens_clearFilterConditions': 'Clear filter conditions',

  // background_settings_page
  'screens_globalBackgroundSettings': 'Global Background Settings',
  'screens_selectImage': 'Select Image',
  'screens_fillMode': 'Fill Mode',
  'screens_cover': 'Cover',
  'screens_contain': 'Contain',
  'screens_fill': 'Fill',
  'screens_fitWidth': 'Fit Width',
  'screens_fitHeight': 'Fit Height',
  'screens_none': 'None',
  'screens_scaleDown': 'Scale Down',
  'screens_blurLevel': 'Blur Level',
  'screens_save': 'Save',
  'screens_globalBackgroundImage': 'Global Background Image',
  'screens_solidBackgroundColor': 'Solid Color Background',
  'screens_solidBackgroundSet': 'Solid color set',
  'screens_solidBackgroundNotSet': 'Not set (follows light/dark default)',
  'screens_solidBackgroundColorSettings': 'Solid Color Background Settings',
  'screens_gridBackground': 'Grid Background',
  'screens_gridBackgroundSet': 'Grid background set',
  'screens_gridBackgroundNotSet': 'Not set (follows light/dark default)',
  'screens_gridBackgroundSettings': 'Grid Background Settings',
  'screens_gridBackgroundStyle': 'Background Style',
  'screens_gridGap': 'Grid Spacing',
  'screens_restoreDefaultBackground': 'Restore Default Background',
  'screens_themeBackgroundDescription': 'The background image and solid color apply to all screens. When both are set, the image sits on top with the color filling uncovered areas; otherwise the system default is used. The grid background sits above the base color and below the image. A background set separately on the home screen still takes priority.',

  // theme style picker (theme_background_settings_screen)
  'screens_themeStyle': 'Theme Style',
  'screens_themePreset_sketchbook': 'Sketchbook',
  'screens_themePreset_berry': 'Berry',
  'screens_themePreset_ocean': 'Ocean',
  'screens_themePreset_matcha': 'Matcha',
  'screens_themePreset_peach': 'Peach',
  'screens_themePreset_cuddly': 'Cuddly',
  'screens_themePreset_butter': 'Butter',
  'screens_themePreset_berry_night': 'Berry Night',
  'screens_inkStyleGentle': 'Gentle',
  'screens_inkStylePlayful': 'Playful',
  'screens_inkStyleExpressive': 'Expressive',
  'screens_strokeStyle': 'Stroke Style',
  'screens_strokeFollowTheme': 'Follow Theme',
  'screens_strokeNeedle': 'Needle',
  'screens_strokeMarker': 'Marker',
  'screens_strokeFountain': 'Fine Brush',

  // create_folder_dialog
  'screens_selectIcon': 'Select Icon',
  'screens_selectColor': 'Select Color',
  'screens_create': 'Create',

  // folder_dialog
  'screens_folderHasBeenDeleted': 'Folder has been deleted',
  'screens_moveOutOfFolder': 'Move out of folder',
  'screens_confirmDeleteThisItem': 'Are you sure you want to delete this item?',
  'screens_moveFromHomePage': 'Move from home page',
  'screens_moveIn': 'Move in (@count)',
  'screens_editFolder': 'Edit Folder',

  // home_card
  'screens_cannotOpenPlugin': 'Cannot open plugin',
  'screens_pluginDisabled': 'Plugin disabled',

  // home_grid
  'screens_quickCreateLayout': 'Quick Create Layout',
  'screens_dragToFolder': 'Drag to folder',
  'screens_dragItemToFolder': 'Drag "@item" to folder "@folder"',
  'screens_pleaseSelectAction': 'Please select an action:',
  'screens_replacePosition': 'Replace Position',
  'screens_addToFolder': 'Add to Folder',

  // layout_manager_dialog
  'screens_renameLayout': 'Rename Layout',
  'screens_confirmDeleteLayout':
      'Are you sure you want to delete layout "@layoutName"? This action cannot be undone.',
  'screens_layoutManagement': 'Layout Management',
  'screens_layoutInfo': '@items widgets · @columns columns grid',
  'screens_switchToThisLayout': 'Switch to this layout',
  'screens_rename': 'Rename',
  'screens_close': 'Close',

  // widget_settings_dialog
  'screens_oneColumn': 'One Column',
  'screens_twoColumns': 'Two Columns',
  'screens_backgroundImage': 'Background Image',
  'screens_alreadySet': 'Already Set',
  'screens_notSet': 'Not Set',
  'screens_iconColor': 'Icon Color',
  'screens_customized': 'Customized',
  'screens_useDefault': 'Use Default',
  'screens_backgroundColor': 'Background Color',
  'screens_effectWhenNoBackgroundImage': 'Effective when no background image',
  'screens_customColorWithTransparency':
      'Custom color (with transparency support)',

  // intent_test_screen
  'screens_quickRegisterIntent': 'Quick Register Intent',
  'screens_selectPresetIntentType':
      'Select a preset Intent type for quick registration',
  'screens_aboutmeTest': 'Aboutme Test (aboutme:///test)',
  'screens_aboutmeComplete':
      'Aboutme Complete (aboutme://app.example.com/open)',
  'screens_customApp': 'Custom App (myapp://custom.host)',
  'screens_intentTest': 'Intent Test',
  'screens_grokCharacterStudyTitle': 'Grok Character Motion',
  'screens_grokCharacterStudySubtitle': 'Spring character engine single-animation debug',
  'screens_quickRegister': 'Quick Register',
  'screens_bulletScheme': '• @scheme',

  // json_dynamic_test
  'screens_jsonDynamicUITest': 'JSON Dynamic UI Test',
  'screens_loadFile': 'Load File',
  'screens_previewEffect': 'Preview Effect',
  'screens_uiPreview': 'UI Preview',

  // notification_test
  'screens_notificationTestPage': 'Notification Test Page',
  'screens_test': 'Test',

  // settings_screen
  'screens_jsonDynamicWidgetTest': 'JSON Dynamic Widget Test',
  'screens_testAndPreviewDynamicUI': 'Test and preview dynamic UI components',
  'screens_testIOSStyleNavigation': 'Test iOS style navigation bar component',
  'screens_notificationTest': 'Notification Test',
  'screens_manageSystemFloatingBall':
      'Manage system-level floating ball functionality',
  'screens_testDynamicIntentAndDeepLink':
      'Test dynamic Intent registration and deep linking',

  // base_settings_controller
  'screens_selectLanguage': 'Select Language',
  'screens_chinese': 'Chinese',
  'screens_english': 'English',

  // super_cupertino_test_screen
  'screens_superCupertinoTest': 'Super Cupertino Test',
  'screens_fruitList': 'Fruit List',
  'screens_fruitIndex': 'This is the @indexth fruit',

  // Additional messages
  'screens_floatingBallStarted': 'Floating ball started',
  'screens_floatingBallStopped': 'Floating ball stopped',
  'screens_pleaseEnterLayoutName': 'Please enter layout name',
  'screens_notificationPermissionGranted': 'Notification permission granted',
  'screens_notificationPermissionDenied': 'Notification permission denied',
  'screens_saveSuccess': 'Saved successfully',
  'screens_allWidgetsCleared': 'All widgets cleared',
  'screens_layoutSaved': 'Layout "@name" saved',
  'screens_saveFailed': 'Save failed',
  'screens_noImage': 'No image',
  'screens_imageLoadFailed': 'Failed to load image',
  'screens_pleaseSelectImage': 'Please select an image',
  'screens_copySuccess': 'Copy successful',
  'screens_copiedToClipboard': 'Copied to clipboard',
  'screens_sendNotification': 'Send notification',
  'screens_notificationSent': 'Notification sent',
  'screens_noTestSchemeAvailable': 'No test scheme available',
  'screens_widgetSettings': 'Widget Settings',
  'screens_reselectData': 'Reselect Data',
  'screens_replaceWidget': 'Replace Widget',
  'screens_itemCount': '@count items',
  'screens_layoutBackgroundSettings': '@layoutName - Background Settings',
  'screens_layoutBackgroundSettingsTitle': 'Layout Background Settings',
  'screens_addWidgets': 'Add Widgets',
  'screens_clear': 'Clear',
  'screens_newLayout': 'New Layout',

  // Additional floating ball messages
  'screens_permissionGranted': 'Permission granted',
  'screens_permissionDenied': 'Permission denied',
  'screens_floatingBallStatus': 'Floating Ball Status',
  'screens_running': 'Running',
  'screens_stopped': 'Stopped',
  'screens_floatingWindowPermission': 'Floating Window Permission',
  'screens_granted': 'Granted',
  'screens_notGranted': 'Not Granted',
  'screens_floatingBallSwitch': 'Floating Ball Switch',
  'screens_clickToStop': 'Click to Stop',
  'screens_clickToStart': 'Click to Start',
  'screens_autoHideInApp': 'Auto Hide In App',
  'screens_autoHideInAppDescription': 'Auto hide overlay floating ball in app',
  'screens_expandAnimation': 'Expand Animation',
  'screens_expandAnimationDescription': 'Show animation effect when expanding/collapsing floating ball',
  'screens_clickedButton': 'Clicked: @buttonName',
  'screens_xPositionYPosition': 'X: @x, Y: @y',

  // Additional home screen messages
  'screens_confirmDeleteSelectedItems':
      'Are you sure you want to delete the selected @count items?',
  'screens_widgetSize': '@width×@height',
  'screens_smallSize': 'Small (Icon)',
  'screens_mediumSize': 'Medium (Horizontal Card)',
  'screens_largeSize': 'Large (Square Card)',
  'screens_large3Size': 'Tall (Vertical Card)',
  'screens_wideSize': 'Wide (Full Width x1)',
  'screens_wide2Size': 'Wide (Full Width x2)',
  'screens_wide3Size': 'Wide (Full Width x3)',
  'screens_customSize': 'Custom',
  'screens_customSizeDesc': 'Custom Size',
  'screens_customSizeAdjust': 'Adjust Custom Size',
  'screens_width': 'Width',
  'screens_height': 'Height',
  'screens_customSizePreview': 'Preview: @width×@height',
  'screens_applyCustomSize': 'Apply Size',
  'screens_noLayoutName': 'No layout name',
  'screens_createNewLayout': 'Create New Layout',
  'screens_inputLayoutName': 'Please enter layout name',
  'screens_layoutName': 'Layout Name',
  'screens_layoutNameHint': 'e.g., Work Layout, Entertainment Layout',
  'screens_deleted': 'deleted',
  'screens_itemsDeleted': 'Deleted @count items',
  'screens_noAvailableFolders':
      'No available folders, please create a folder first',
  'screens_itemsMovedToFolder': 'Moved @count items to folder',
  'screens_gridSize': 'Grid Size',
  'screens_gridSizeDescription':
      'Select the number of columns for the home grid (1-10)',
  'screens_gridColumns': '@count columns',
  'screens_displayPosition': 'Display Position',
  'screens_displayPositionDescription':
      'Choose the alignment of widgets on the screen',
  'screens_backgroundImageSet': 'Background image set',
  'screens_backgroundImageNotSet': 'Background image not set',
  'screens_customBackgroundImage': 'Custom background image set',
  'screens_useGlobalBackgroundImage': 'Using global background image',

  // create_folder_dialog
  'screens_folderName': 'Folder Name',
  'screens_enterFolderName': 'Enter folder name',
  'screens_pleaseEnterFolderName': 'Please enter folder name',
  'screens_folderCreated': 'Folder created: @name',

  // background_settings_page
  'screens_widgetOverallOpacity': 'Widget Overall Opacity',
  'screens_widgetOverallOpacityDescription':
      'Adjust the opacity of the entire widget (including text and content)',
  'screens_backgroundColorOpacity': 'Background Color Opacity',
  'screens_backgroundColorOpacityDescription':
      'Adjust only the background color opacity, does not affect text',
  'screens_layoutBackgroundSettingsDescription':
      'Set background images for each layout individually, priority higher than global background image',
  'screens_noSavedLayouts': 'No saved layouts',
  'screens_saveLayoutFirst': 'Please save a layout on the home page first',
  'screens_clearUseGlobalBackground': 'Clear (Use Global Background)',
  'screens_customBackgroundHasPriority':
      'Individually set background images have priority over global background images',
  'screens_zeroPercentFullyTransparent': '0% (Fully Transparent)',
  'screens_oneHundredPercentOpaque': '100% (Opaque)',

  // folder_dialog
  'screens_folderIsEmpty': 'The folder is empty',
  'screens_selectItemsToMoveToFolder': 'Select items to move to folder',
  'screens_movedToHomePage': 'Moved to home page',
  'screens_folderUpdated': 'Folder updated',
  'screens_clickToAddContent': 'Click the + button above to add content',
  'screens_noItemsOnHome': 'No items available on home page to move',

  // home_grid
  'screens_noWidgetsYet': 'No widgets yet',
  'screens_quickLayout': 'Quick Layout',
  'screens_component': 'Widget',
  'screens_item': 'Item',
  'screens_clickPlusToAdd': 'Click the + button in the top right to add',
  'screens_loadLayoutFailed': 'Failed to load layout',
  'screens_switchedToLayout': 'Switched to',
  'screens_switchFailed': 'Failed to switch',
  'screens_saveFirstLayoutHint':
      'Click "Save Current Layout" in the top right menu to create your first layout configuration',

  // layout_manager_dialog
  'screens_renameSuccess': 'Rename successful',
  'screens_deleteSuccess': 'Delete successful',

  'screens_presetColors': 'Preset Colors',
  'screens_quickSelectPresetColors': 'Quick Select Preset Colors',

  // location_api_key_settings
  'screens_locationApiKey': 'Location API Key',
  'screens_locationApiKeyNotSet': 'Not Set',
  'screens_locationApiKeyPartial': '@key...',
  'screens_setLocationApiKey': 'Set Location API Key',
  'screens_locationApiKeyHint': 'Please enter Amap API Key',
  'screens_apiKeyLabel': 'API Key',
  'screens_apiKeyInputHint': 'Enter API Key',
  'screens_locationApiKeyGuide':
      'How to get API Key:\n1. Visit Amap Open Platform\n2. Register and create application\n3. Get Web Service API Key',

  // unstack
  'screens_unstackCurrent': 'Unstack @widget widget',
  'screens_unstackAll': 'Unstack all widgets',
  'screens_confirmUnstack': 'Confirm Unstack',
  'screens_confirmUnstackItem':
      'Are you sure you want to unstack the "@widget" widget?',
  'screens_confirmUnstackAll':
      'Are you sure you want to unstack all @count widgets?',
  'screens_unstack': 'Unstack',
  'screens_unstackSuccess': 'Unstacked "@widget" widget',
  'screens_unstackAllSuccess': 'Unstacked @count widgets',

  // stack merge
  'screens_cannotMergeDifferentSizes':
      'Cannot merge widgets of different sizes',
  'screens_mergeFailed': 'Merge failed',
  'screens_mergeSuccess': 'Merge successful',

  // jelly_home live2d
  'screens_jellyLive2dTapHead1': 'Head pats~',
  'screens_jellyLive2dTapHead2': 'My hair is getting messy!',
  'screens_jellyLive2dTapHead3': "Hehe, I love head pats",
  'screens_jellyLive2dTapHead4': "Let's do our best today!",
  'screens_jellyLive2dPokeBody1': 'Poking my tummy tickles!',
  'screens_jellyLive2dPokeBody2': 'Why are you poking me?',
  'screens_jellyLive2dPokeBody3': "Poke me again and I'll get mad!",
  'screens_jellyLive2dPokeBody4': 'Eek!',
  'screens_jellyLive2dMiss1': "Hm? There's nothing over there",
  'screens_jellyLive2dMiss2': 'Did you need something?',
  'screens_jellyLive2dMiss3': "I'm right here~",
  'screens_jellyLive2dMiss4': "Hmm? What's up?",
  'screens_jellyLive2dModelNotLoaded': 'Model is not loaded yet',
  'screens_jellyLive2dCaptureUnavailable': 'Cannot access the model view',
  'screens_jellyLive2dCaptureUnsupported':
      'Capturing the Live2D view is not supported on this platform',
  'screens_jellyLive2dCaptureEncodeFailed': 'Failed to encode the model image',
  'screens_jellyLive2dCropErrorTitle': 'Cannot set crop region',
  'screens_jellyLive2dGotIt': 'Got it',
  'screens_jellyLive2dLoadStagePreparing': 'Preparing',
  'screens_jellyLive2dLoadStageModelConfig': 'Reading model config',
  'screens_jellyLive2dLoadStageModelData': 'Loading model data',
  'screens_jellyLive2dLoadStageComponents': 'Loading model components',
  'screens_jellyLive2dLoadStageMotions': 'Loading motions and sounds',
  'screens_jellyLive2dLoadStageTextures': 'Loading model textures',
  'screens_jellyLive2dLoadStageComplete': 'Loading complete',
  'screens_jellyLive2dLoadStageLoading': 'Loading',
  'screens_jellyLive2dArchives': 'Live2D Profiles',
  'screens_jellyLive2dNoArchives': 'No profiles yet. Create one in Live2D settings',
  'screens_jellyLive2dOpenModelList': 'Models',
  'screens_jellyLive2dCharacterSize': 'Character Size',
  'screens_jellyLive2dShrink': 'Shrink',
  'screens_jellyLive2dEnlarge': 'Enlarge',
  'screens_jellyLive2dReset': 'Reset',
  'screens_jellyLive2dCurrentSize':
      'Current @percent% (@size px, saved automatically)',
  'screens_jellyLive2dDisplayArea': 'Display Area',
  'screens_jellyLive2dSetCropRegion': 'Set Display Crop Region',
  'screens_jellyLive2dCropFullModel': 'Currently showing the full model',
  'screens_jellyLive2dCropApplied': 'Custom crop region applied',
  'screens_jellyLive2dShowBorder': 'Show Border',
  'screens_jellyLive2dShowBorderDesc': 'Outline the actual Live2D display area',
  'screens_jellyLive2dShowBorderSemantic': 'Show Live2D border',
  'screens_jellyLive2dHitAreas': 'Hit Areas',
  'screens_jellyLive2dEnabled': 'On',
  'screens_jellyLive2dDisabled': 'Off',
  'screens_jellyLive2dHitAreasDesc':
      "When enabled, outlines the model's clickable areas (red boxes + names). Tapping a hit area triggers a random motion",
  'screens_jellyLive2dLoadFailed': 'Failed to load model',
  'screens_jellyLive2dTapToReload': 'Tap to reload',
  'screens_jellyLive2dApply': 'Apply',
  'screens_jellyLive2dResetCrop': 'Restore Full Region',

  // jelly_home live2d motions
  'screens_jellyLive2dMotionIdle': 'Idle',
  'screens_jellyLive2dMotion1': 'Motion 1',
  'screens_jellyLive2dMotion2': 'Motion 2',
  'screens_jellyLive2dMotion3': 'Motion 3',
  'screens_jellyLive2dSpecialMotion1': 'Special Motion 1',
  'screens_jellyLive2dSpecialMotion2': 'Special Motion 2',
  'screens_jellyLive2dSpecialMotion3': 'Special Motion 3',
  'screens_jellyLive2dMotionWithVoice': '@label (voice)',
  'screens_jellyLive2dMotionGeneric': 'Motion',

  // jelly_home live2d online models
  'screens_jellyLive2dOnlineTitle': 'Online Live2D Models',
  'screens_jellyLive2dOnlineRefresh': 'Refresh model repository',
  'screens_jellyLive2dOnlineSearchHint': 'Search models or categories',
  'screens_jellyLive2dOnlineAll': 'All',
  'screens_jellyLive2dOnlineLoading': 'Loading model repository',
  'screens_jellyLive2dOnlineUnavailable': 'Model repository unavailable',
  'screens_jellyLive2dOnlineEmpty': 'No matching models found',
  'screens_jellyLive2dOnlineCount': '@count models available (Cubism 3/4)',
  'screens_jellyLive2dOnlineLoadRepoFailed':
      'Failed to load online model repository: @error',
  'screens_jellyLive2dOnlineLoadConfigFailed':
      'Failed to read model config: @error',
  'screens_jellyLive2dRepoHttpError': 'Model repository returned HTTP @code',
  'screens_jellyLive2dConfigHttpError': 'Model config returned HTTP @code',
  'screens_jellyLive2dConfigNotJson': 'Model config is not a JSON object',
  'screens_jellyLive2dUncategorized': 'Uncategorized',

  // const Text 硬编码迁移(en)
  'screens_batchEdit': 'Batch Edit',
  'screens_selectCommonWidgetStyle': 'Select Common Widget Style',
  'screens_live2dInitFailed': 'Live2D chat failed to initialize',
  'screens_markBubbleRegion': 'Mark Bubble Regions',
  'screens_markBubbleRegionDesc': 'After selecting a region, drag on the image to draw rectangles. Red for model name, blue for body text.',
  'screens_configureTopPanel': 'Configure Top Info Panel',
  'screens_avatarPosition': 'Avatar Position',
  'screens_expBarPosition': 'Exp Bar Position',
  'screens_iconPosition': 'Icon Position',
  'screens_valuePosition': 'Value Position',
  'screens_topPanelAvatarHint':
      'Tap the avatar to change it. If the Live2D archive has a cover, the cover takes precedence.',
  'screens_logSystem': 'Log System',
  'screens_confirmDeleteLogs': 'Delete all log files? This cannot be undone.',

  // theme_background_settings_screen
  'screens_pickImageFailed': 'Failed to pick image: @error',
  'screens_themeSettingsSaved': 'Theme settings saved',
  'screens_saveFailedWithReason': 'Save failed: @error',
  'screens_restoredDefaultBackground': 'Default background restored',

  // jelly_home assistant tab
  'screens_assistantTitle': 'Chat Assistant',
  'screens_assistantSubtitle': 'One line, all noted',
  'screens_assistantBadgeIdle': 'Your Assistant',
  'screens_assistantWorking': 'Working on it…',
  'screens_assistantTyping': 'Typing…',
  'screens_assistantGreeting': 'Hey! What can I\nnote down for you?',
  'screens_assistantReady': 'Your quick-note assistant is ready',
  'screens_assistantIdeas': 'Try these',
  'screens_assistantIdeaTodo': 'Todo: standup at 9 am',
  'screens_assistantIdeaBill': 'Expense: lunch ¥25',
  'screens_assistantIdeaDiary': 'Diary: feeling good today',
  'screens_assistantIdeaCheckin': 'Check in: drank 500ml water',
  'screens_assistantOpenFull': 'Open full chat',
  'screens_assistantInitFailed': 'Chat assistant failed to initialize',
};
