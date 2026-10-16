/// 脚本中心插件英文翻译
const Map<String, String> scriptsCenterTranslationsEn = {
  // Basic info
  'scripts_center_name': 'Script Center',
  'scripts_center_scriptCenter': 'Script Center',

  // Script Store
  'scripts_center_scriptStore': 'Script Store',
  'scripts_center_select_source': 'Select Source',
  'scripts_center_manage_sources': 'Manage Sources',
  'scripts_center_no_sources': 'No sources available',
  'scripts_center_delete_source': 'Delete Source',
  'scripts_center_delete_source_confirm': 'Confirm to delete source',
  'scripts_center_add_source': 'Add Source',
  'scripts_center_source_name': 'Source Name',
  'scripts_center_source_url': 'Source URL',
  'scripts_center_source_base_url': 'Base URL',
  'scripts_center_fill_all_fields': 'Please fill all fields',
  'scripts_center_source_added': 'Source added',
  'scripts_center_installed_only': 'Installed Only',
  'scripts_center_installed_status': 'Installation Status',
  'scripts_center_not_installed': 'Not Installed',
  'scripts_center_no_scripts_found': 'No scripts found',
  'scripts_center_downloading': 'Downloading',
  'scripts_center_installing': 'Installing',
  'scripts_center_install': 'Install',
  'scripts_center_uninstall': 'Uninstall',
  'scripts_center_installed': 'Installed successfully',
  'scripts_center_uninstalled': 'Uninstalled successfully',
  'scripts_center_install_failed': 'Installation failed',
  'scripts_center_update': 'Update',
  'scripts_center_tags': 'Tags',
  'scripts_center_permissions': 'Permissions',
  'scripts_center_author': 'Author',
  'scripts_center_description': 'Description',

  // Search and actions
  'scripts_center_search': 'Search scripts',
  'scripts_center_newScript': 'New Script',

  // Script editing - pages and buttons
  'scripts_center_editScript': 'Edit Script',
  'scripts_center_createNewScript': 'Create New Script',
  'scripts_center_save': 'Save',
  'scripts_center_create': 'Create',
  'scripts_center_basicInfo': 'Basic Info',
  'scripts_center_codeEditor': 'Code Editor',
  'scripts_center_triggers': 'Triggers',
  'scripts_center_advancedSettings': 'Advanced Settings',
  'scripts_center_config': 'Configuration',
  'scripts_center_format': 'Format',
  'scripts_center_addTrigger': 'Add Trigger',
  'scripts_center_addTriggerCondition': 'Add Trigger Condition',
  'scripts_center_add': 'Add',

  // Script fields
  'scripts_center_scriptName': 'Script Name',
  'scripts_center_scriptId': 'Script ID',
  'scripts_center_version': 'Version',
  'scripts_center_scriptType': 'Script Type',
  'scripts_center_updateUrl': 'Update URL (Optional)',
  'scripts_center_icon': 'Icon',
  'scripts_center_selectIcon': 'Select Icon',

  // Configuration
  'scripts_center_selectAgent': 'Select AI Agent',
  'scripts_center_enabledEvents': 'Monitored Events',
  'scripts_center_promptTemplate': 'Prompt Template',

  // Script types
  'scripts_center_moduleType': 'Module (Accepts Parameters)',
  'scripts_center_standaloneType': 'Standalone (Runs Independently)',

  // Input parameters
  'scripts_center_addInputParameter': 'Add Input Parameter',
  'scripts_center_enableScript': 'Enable Script',
  'scripts_center_disableScript': 'Disable Script',
  'scripts_center_requiredParameter': 'Required Parameter',
  'scripts_center_userMustFillThisParameter': 'User must fill this parameter',
  'scripts_center_thisParameterIsOptional': 'This parameter is optional',

  // Actions
  'scripts_center_cancel': 'Cancel',
  'scripts_center_run': 'Run',

  // Other
  'scripts_center_all': 'All',

  // Parameterized translations - using @name placeholders
  'scripts_center_categoryLabel': 'Category: @category',
  'scripts_center_descriptionLabel': 'Description: @description',
  'scripts_center_delayLabel': 'Delay: @delayms',

  // Widget Home Strings
  'scripts_center_widgetName': 'Script Center',
  'scripts_center_widgetDescription': 'Quick access to Script Center',
  'scripts_center_overviewName': 'Script Overview',
  'scripts_center_overviewDescription': 'Display script statistics',

  // Script Executor Widget
  'scripts_center_scriptExecutorName': 'Script Quick Execute',
  'scripts_center_scriptExecutorDescription': 'Select and quickly execute a script',
  'scripts_center_selectScript': 'Select Script',
  'scripts_center_script': 'Script',
  'scripts_center_tapToExecute': 'Tap to Execute',
  'scripts_center_clickToExecute': 'Click to execute script',
  'scripts_center_scriptNotFound': 'Script not found',
  'scripts_center_scriptExecuted': 'Script executed successfully',
  'scripts_center_scriptExecuteFailed': 'Script execution failed',
  'scripts_center_scriptExecuteError': 'Script execution error',

  // Scripts List Widget
  'scripts_center_scriptsListWidgetName': 'Scripts List',
  'scripts_center_scriptsListWidgetDesc': 'Display all scripts in a colorful grid',

  // Delete related
  'scripts_center_delete_confirm': 'Confirm Delete',
  'scripts_center_delete_script_confirm': 'Confirm to delete script',
  'scripts_center_delete_success': 'Script deleted successfully',
  'scripts_center_operation_failed': 'Operation failed',

  // const Text 硬编码迁移(en)
  'scripts_center_clear': 'Clear',
  'scripts_center_selectFile': 'Select File',
  'scripts_center_selectEventRequired': 'Select Event *',
  'scripts_center_deleteConfigFile': 'Delete Config File',
  'scripts_center_clearExecutionLogs': 'Clear Execution Logs',
  'scripts_center_confirmClearLogs': 'Delete all execution logs? This cannot be undone.',
  'scripts_center_clearAll': 'Clear All',
  'scripts_center_terminateScript': 'Terminate Script',
  'scripts_center_terminate': 'Terminate',
  'scripts_center_errorMessage': 'Error Message',
  'scripts_center_returnValue': 'Return Value',
  'scripts_center_imagePreview': 'Image Preview',
  'scripts_center_imageLoadFailed': 'Image failed to load (file may have been moved or deleted)',
  'scripts_center_failedOnly': 'Failed Only',
  'scripts_center_allScripts': 'All Scripts',
  'scripts_center_selectConfigFile': 'Select Config File',
  'scripts_center_executionLogs': 'Execution Logs',
  'scripts_center_exportScript': 'Export Script',
  'scripts_center_exportScriptDesc': 'Export code, metadata and all config files',
  'scripts_center_importJsFile': 'Import JS File',
  'scripts_center_required': 'Required',
  'scripts_center_addLink': 'Add Link',
  'scripts_center_addImageLink': 'Add Image Link',

  // 执行记录页面
  'scripts_center_logsCleared': 'Execution logs cleared',
  'scripts_center_terminateConfirm':
      'Terminate "@name"?\n\nThis will interrupt all pending operations of the script. The execution log will be marked as "Script terminated by user".\nNote: If multiple scripts are running at the same time, they will all be terminated.',
  'scripts_center_terminateRequested':
      'Termination requested, waiting for script to exit...',
  'scripts_center_status': 'Status',
  'scripts_center_statusSuccess': 'Success',
  'scripts_center_statusFailed': 'Failed',
  'scripts_center_triggerMethod': 'Trigger',
  'scripts_center_duration': 'Duration',
  'scripts_center_secondsFormat': ' (@seconds s)',
  'scripts_center_time': 'Time',
  'scripts_center_generatedImages': 'Generated Images (@count)',
  'scripts_center_today': 'Today',
  'scripts_center_runningElapsed': 'Running @elapsed',
  'scripts_center_noExecutionLogs': 'No execution logs',
  'scripts_center_imagesShort': '@count img',
  'scripts_center_loadFailed': 'Load failed',

  // Empty state placeholders
  'scripts_center_noMatchingScripts': 'No matching scripts',
  'scripts_center_emptyScriptsHint':
      'No scripts yet\nTap the bottom-right button to create one',
};
