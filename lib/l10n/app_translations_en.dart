/// English translations for app-level strings
///
/// All keys are prefixed with 'app_' to avoid conflicts with plugin translations.
/// Parameterized translations use @paramName format for GetX.
const Map<String, String> appTranslationsEn = {
  // App basics
  'app_appTitle': 'aboutme',
  'app_pluginManager': 'Plugin Manager',
  'app_home': 'Home',
  'app_settings': 'Settings',
  'app_version': 'Version',

  // Onboarding
  'app_onboarding_habitsTitle': 'Manage Your Daily Habits',
  'app_onboarding_habitsDesc': 'Keep your streaks by completing daily tasks. Reach big goals with consistent habits.',
  'app_onboarding_competeTitle': 'Compete with Friends',
  'app_onboarding_competeDesc': 'Follow your friends, earn points, and compete. Fun competition keeps you motivated.',
  'app_onboarding_challengeTitle': 'Challenge Yourself!',
  'app_onboarding_challengeDesc': 'Join 30-day challenges to set new goals for yourself. Push your limits with challenges.',
  'app_onboarding_next': 'NEXT',
  'app_onboarding_getStarted': 'GET STARTED',

  // Common actions
  'app_ok': 'OK',
  'app_select': 'Select',
  'app_no': 'No',
  'app_yes': 'Yes',
  'app_cancel': 'Cancel',
  'app_save': 'Save',
  'app_close': 'Close',
  'app_delete': 'Delete',
  'app_reset': 'Reset',
  'app_apply': 'Apply',
  'app_edit': 'Edit',
  'app_retry': 'Retry',
  'app_rename': 'Rename',
  'app_copy': 'Copy',
  'app_done': 'Done',
  'app_create': 'Create',
  'app_confirm': 'Confirm',
  'app_import': 'Import',

  // Delete confirmation
  'app_confirmDelete': 'Confirm Delete?',

  // Date and time
  'app_selectDate': 'select Date',
  'app_startTime': 'Start Time',
  'app_endTime': 'End Time',
  'app_interval': 'Interval',
  'app_minutes': 'Minutes',
  'app_week': 'Week',
  'app_month': 'Month',
  'app_date': 'Date',

  // Display options
  'app_showAll': 'show All',
  'app_adjustCardSize': 'Adjust Card Size',
  'app_width': 'Width',
  'app_height': 'Height',

  // Tags and categories
  'app_tags': 'Tags',
  'app_selectGroup': 'Select group',
  'app_selectLocation': 'Select location',
  'app_selectIcon': 'Select icon',

  // Form fields
  'app_submit': 'Submit',
  'app_pleaseSelect': 'Please select',
  'app_selectTime': 'Select time',
  'app_selectDateRange': 'Select date range',
  'app_selectColor': 'Select color',
  'app_to': 'to',
  'app_expense': 'Expense',
  'app_income': 'Income',
  'app_avatar': 'Avatar',
  'app_addEvent': 'Add event',
  'app_monthly': 'Monthly',
  'app_quarterly': 'Quarterly',
  'app_yearly': 'Yearly',
  'app_pleaseEnterAmount': 'Please enter an amount',
  'app_enterValidAmount': 'Enter a valid amount',
  'app_amountGreaterThanZero': 'Amount must be greater than 0',
  'app_noCustomFields': 'No custom fields',
  'app_addField': 'Add field',
  'app_addCustomField': 'Add custom field',
  'app_editCustomField': 'Edit custom field',
  'app_fieldName': 'Field name',
  'app_fieldNameHint': 'Enter field name',
  'app_fieldValue': 'Field value',
  'app_fieldValueHint': 'Enter field value',
  'app_confirmDeleteField': 'Delete this field?',
  'app_fieldNameAndValueRequired': 'Field name and value are required',
  'app_addTag': 'Add tag',
  'app_add': 'Add',
  'app_enterTitle': 'Enter title',
  'app_customFields': 'Custom fields',
  'app_icon': 'Icon',

  // Backup and export
  'app_selectBackupMethod': 'Please select backup method',

  // Backup progress
  'app_backupInProgress': 'Backup in progress',
  'app_completed': 'Completed: @percentage%',
  'app_exportingData': 'exporting Data',
  'app_importingData': 'importing Data',
  'app_pleaseWait': 'please Wait',

  // Export messages
  'app_exportCancelled': 'Export cancelled',
  'app_exportSuccess': 'Data exported successfully',
  'app_exportFailed': 'Export failed: @error',
  'app_dataExportedTo': 'Data exported to: @path',
  'app_exportFailedWithError': 'Export failed: @error',
  'app_exportSuccessTo': 'Export successful to: @path',

  // Import messages
  'app_warning': 'Warning',
  'app_importWarning':
      'Import will completely overwrite current app data.\nWe recommend backing up existing data before importing.\n\nContinue?',
  'app_stillContinue': 'Continue',
  'app_importCancelled': 'Import cancelled',
  'app_selectBackupFile': 'Please select backup file',
  'app_noFileSelected': 'No file selected',
  'app_importInProgress': 'Import in progress',
  'app_processingBackupFile': 'Processing backup file...',
  'app_importSuccess': 'Data imported successfully, please restart app',
  'app_restartRequired': 'Restart required',
  'app_restartMessage':
      'Data import completed, app restart is required to take effect.',
  'app_fileSelectionFailed': 'File selection failed: @error',
  'app_importFailed': 'Import failed',
  'app_importTimeout': 'Import timeout: file may be too large or inaccessible',
  'app_filesystemError': 'Filesystem error: unable to read or write file',
  'app_invalidBackupFile': 'Invalid backup file: file may be corrupted',
  'app_noPluginDataFound': 'No plugin data found for import',
  'app_importFailedWithError': 'Import failed: @error',

  // Plugin management
  'app_noPluginsAvailable': 'No plugins available',
  'app_failedToLoadPlugins': 'Failed to load plugins: @error',
  'app_selectPluginToExport': 'Select plugin to export',
  'app_selectPluginToImport': 'Select plugin to import (@mode)',
  'app_selectPluginsToImport': 'Select Plugins To Import',
  'app_selectFolderToImport': 'Select folder to import',
  'app_dataSize': 'Data size: @size',
  'app_mergeMode': 'Merge Mode',
  'app_overwriteMode': 'Overwrite Mode',

  // Permissions
  'app_permissionRequired': '@permission permission required',
  'app_permissionRequiredForApp':
      'App requires @permission permission to work properly. Grant permission?',
  'app_notNow': 'Not now',
  'app_grantPermission': 'Grant permission',
  'app_permissionRequiredInSettings':
      '@permission permission is required to continue. Please grant permission in system settings.',
  'app_storagePermissionRequired':
      'Storage permission is required to continue. Please grant permission in system settings.',
  'app_permissionsTitle': 'Permission access',
  'app_permissionsDescription':
      'Grant these permissions to ensure backups, imports, and reminders continue to work properly.',
  'app_permissionsGrantAll': 'Grant all permissions',
  'app_permissionsGranted': 'Granted',
  'app_permissionsRequest': 'Allow',
  'app_permissionsOpenSettings': 'Open settings',
  'app_permissionsManageDescription':
      'Review and manage multimedia and notification permissions.',
  'app_permission_photosTitle': 'Photos',
  'app_permission_photosDescription':
      'Required to pick and back up images inside diary, check-in, and other plugins.',
  'app_permission_videosTitle': 'Videos',
  'app_permission_videosDescription':
      'Required to attach and export recorded videos.',
  'app_permission_audioTitle': 'Audio',
  'app_permission_audioDescription':
      'Required to capture voice notes and attach audio files.',
  'app_permission_notificationsTitle': 'Notifications',
  'app_permission_notificationsDescription':
      'Required to deliver reminders and scheduled alerts.',
  'app_permission_storageTitle': 'Storage',
  'app_permission_storageDescription':
      'Required to read and write backup files on your device.',
  'app_permission_calendarTitle': 'Calendar',
  'app_permission_calendarDescription':
      'Required to sync system calendar and manage calendar events.',

  // File operations
  'app_downloadCancelled': 'Download cancelled',
  'app_moveSuccess': 'Move successful',
  'app_moveFailed': 'Move failed: @error',
  'app_renameFailed': 'Rename failed: @error',

  // Media selection
  'app_selectImage': 'Select image',
  'app_selectFromGallery': 'Select from gallery',
  'app_takePhoto': 'Take photo',
  'app_loadingVideo': 'Loading video...',
  'app_videoLoadFailed': 'Video load failed: @error',

  // Form validation
  'app_pleaseEnterTitle': 'Please Enter Title',
  'app_titleRequired': 'Title is required',

  // Colors
  'app_selectBackgroundColor': 'Select background color',
  'app_nodeColor': 'Node Color',

  // Testing
  'app_testForegroundTask': 'Test Foreground Task',

  // About
  'app_aboutTitle': 'About',
  'app_aboutDescription':
      'Aboutme is a productivity app designed to help you organize and remember important things.',
  'app_projectLinkTitle': 'Project Link',
  'app_projectLink': 'https://github.com/hunmer/aboutme',
  'app_feedbackTitle': 'Feedback & Issues',
  'app_feedbackLink': 'https://github.com/hunmer/Aboutme/issues',
  'app_documentationTitle': 'Documentation',
  'app_documentationLink': 'https://github.com/hunmer/Aboutme#readme',

  // Home Widget Categories
  'home_categoryRecord': 'Record',
  'home_categoryTools': 'Tools',
  'home_categoryCommunication': 'Communication',
  'home_categoryFinance': 'Finance',
  'home_categoryLife': 'Life',
  'home_loadFailed': 'Load Failed',
  'home_quickCreateTitle': 'Quick Create',
  'home_today': 'Today',
  'home_modeDateView': 'Switch to date view',
  'home_modeFixedLayout': 'Switch to fixed layout',
  'home_dateViewEmpty': 'No date cards yet',
  'home_dateViewNoData': 'No records on this day',
  'home_sortDefault': 'Default',
  'home_sortPriority': 'Priority',
  'home_sortTime': 'Time',
  'app_provider': 'Provider',
  'app_none': 'None',
  'app_reminders': 'Reminders',
  'app_noReminders': 'No reminders',

  // Tags dialog
  'app_tags_all': 'All',
  'app_tags_group': 'Group',
  'app_tags_sort': 'Sort',
  'app_tags_sortCreatedAt': 'Added time',
  'app_tags_sortLastUsedAt': 'Last used',
  'app_tags_sortName': 'Name',
  'app_tags_batchEdit': 'Batch edit',
  'app_tags_exitBatchEdit': 'Exit batch edit',
  'app_tags_addTag': 'Add tag',
  'app_tags_editTag': 'Edit tag',
  'app_tags_name': 'Tag name',
  'app_tags_nameHint': 'Enter a tag name',
  'app_tags_comment': 'Comment (optional)',
  'app_tags_commentHint': 'Add a note',
  'app_tags_deleteTagConfirm': 'Delete tag "@name"?',
  'app_tags_deleteSelectedConfirm': 'Delete @count selected tags?',
};
