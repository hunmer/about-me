/// 账单插件英文翻译 (GetX)
class BillTranslationsEn {
  static const Map<String, String> translations = {
    // Basic fields
    'bill_name': 'Bill',
    'bill_dayCardName': 'Bill day card',
    'bill_dayCardDesc': 'Show bills for the selected date',
    'bill_dateStatExpenseLabel': 'Expense',
    'bill_dateStatIncomeLabel': 'Income',
    'bill_dateStatUnit': '¥',
    'bill_dayCardEmpty': 'No bills on this day',
    'bill_billList': 'Bill List',
    'bill_newBill': 'New Bill',
    'bill_editBill': 'Edit Bill',
    'bill_date': 'Date',
    'bill_note': 'Note',
    'bill_income': 'Income',
    'bill_expense': 'Expense',
    'bill_save': 'Save',
    'bill_cancel': 'Cancel',
    'bill_confirmDelete': 'Confirm Delete',
    'bill_selectCategory': 'Select Category',
    'bill_addNote': 'Add Note',

    // Statistics
    'bill_byCategory': 'By Category',
    'bill_statisticsAnalysis': 'Statistics Analysis',

    // List and search

    // Messages
    'bill_billSaved': 'Bill saved successfully',
    'bill_billSaveFailed': 'Failed to save bill',
    'bill_requiredField': 'This field is required',

    // Account management
    'bill_accountName': 'Account Name',
    'bill_accountManagement': 'Account Management',
    'bill_accountDeleted': 'Account deleted',
    'bill_noAccounts': 'No accounts yet',
    'bill_deleteAccount': 'Delete Account',
    'bill_enterAccountName': 'Enter account name',
    'bill_confirmDeleteAccountWithBills':
        'Delete this account and all its bills?',

    // Time range
    'bill_todayFinance': 'Today',
    'bill_monthFinance': 'Monthly',
    'bill_monthBills': 'Monthly',

    // Others
    'bill_delete': 'Delete',
    'bill_balance': 'Balance',
    'bill_title': 'Title',

    // Quick bookkeeping config
    'bill_saveConfig': 'Save Config',
    'bill_quickBookkeepingConfig': 'Quick Bookkeeping Config',
    'bill_addQuickPreset': 'Add Quick Preset',
    'bill_noQuickPresets': 'No Quick Presets',
    'bill_clickToAddQuickPreset':
        'Click the + button in the bottom right to add quick presets',
    'bill_editQuickPreset': 'Edit Quick Preset',
    'bill_presetName': 'Preset Name',
    'bill_presetNameHint': 'e.g: breakfast, taxi',
    'bill_pleaseEnterPresetName': 'Please enter preset name',
    'bill_presetAmount': 'Preset Amount (Optional)',
    'bill_presetAmountHint': 'Leave blank to enter manually each time',
    'bill_edit': 'Edit',
    'bill_monthlyRecord': 'Monthly Records',

    // Home Widget Strings
    'bill_widgetName': 'Bill',
    'bill_widgetDescription': 'Quick access to bills',
    'bill_overviewName': 'Bill Overview',
    'bill_overviewDescription': 'Display income and expense statistics',
    'bill_createShortcutName': 'Create Bill',
    'bill_createShortcutDescription': 'Quick create new bill',

    // Stats Widget Strings
    'bill_statsWidgetName': 'Expense Stats',
    'bill_statsWidgetDescription':
        'Display income/expense stats with custom target',

    // Monthly Bill Widget Strings
    'bill_monthlyBillsWidgetName': 'Monthly Bills',
    'bill_monthlyBillsWidgetDescription': 'Display bills for a specific month',

    // Interface search
    'bill_searchPlaceholder': 'Search bills by name, category, or note',

    // Subscription service
    'bill_subscription': 'Subscription',
    'bill_addSubscription': 'Add Subscription',
    'bill_editSubscription': 'Edit Subscription',
    'bill_deleteSubscription': 'Delete Subscription',
    'bill_activeSubscriptions': 'Active Subscriptions',
    'bill_inactiveSubscriptions': 'Inactive',
    'bill_noSubscriptions': 'No subscriptions yet',
    'bill_clickToAddSubscription': 'Tap the button below to add a subscription',
    'bill_subscriptionName': 'Name',
    'bill_subscriptionPrice': 'Price',
    'bill_startDate': 'Start Date',
    'bill_endDate': 'End Date',
    'bill_chooseIcon': 'Choose Icon',
    'bill_monthly': 'Monthly',
    'bill_quarterly': 'Quarterly',
    'bill_yearly': 'Yearly',
    'bill_autoSubscribe': 'Auto-subscribe',
    'bill_autoSubscribeDesc': 'Renew automatically when expired',
    'bill_notes': 'Notes',
    'bill_terminateSubscription': 'Terminate Subscription',
    'bill_terminateConfirm': 'Are you sure you want to terminate "{name}"?',
    'bill_deleteConfirm':
        'Are you sure you want to delete "{name}"? This action cannot be undone.',
    'bill_subscriptionCreated': 'Subscription created',
    'bill_subscriptionUpdated': 'Subscription updated',
    'bill_saveFailed': 'Save failed',
    'bill_subscriptionDaysError': 'Subscription days must be greater than 0',
    'bill_groupManual': 'Manual Records',
    'bill_groupSubscription': 'Subscription Proration',
    'bill_subscriptionBillHint':
        'Daily prorated from a subscription; edit it in subscription management',
    'bill_nextDate': 'Next:',
    'bill_autoRenew': 'Auto-renew',
    'bill_days': 'Days',
    'bill_weekly': 'Weekly',
    'bill_none': 'None',
    'bill_switchToListView': 'Switch to List View',
    'bill_switchToGridView': 'Switch to Grid View',
    'bill_notesHint': 'Add comments, order numbers, or account details...',

    // const Text 硬编码迁移(en)
    'bill_statsReport': 'Statistics Report',

    // Edit bill screen
    'bill_addBill': 'Add Bill',
    'bill_amountMustBePositive':
        'Please enter a valid amount (must be greater than 0)',
    'bill_pleaseEnterSubscriptionName':
        'Please enter the subscription service name',
    'bill_pleaseEnterSubscriptionDays': 'Please enter the subscription days',
    'bill_titleHint': 'Leave blank to use category name',
    'bill_enableSubscription': 'Enable Subscription',
    'bill_enableSubscriptionHint':
        'When enabled, a daily bill will be generated automatically',
    'bill_subscriptionNameHint': 'e.g. Netflix membership',
    'bill_subscriptionDays': 'Subscription Days',
    'bill_subscriptionDaysHint': 'e.g. 30',
    'bill_dailyAmount': 'Daily Amount',
    'bill_perDaySuffix': ' / day',

    // Stats screen (sketch style)
    'bill_monthBudget': 'Monthly Budget',
    'bill_budgetHint': 'Set a monthly spending limit',
    'bill_budgetSetAmount': 'Set Budget Amount',
    'bill_budgetInvalid': 'Enter a valid amount',
    'bill_budgetUsed': 'Used',
    'bill_budgetRemaining': 'Remaining',
    'bill_budgetOverspent': 'Over budget',
    'bill_dailyExpenseChart': 'Daily Expenses',
    'bill_monthBillsCount': '@count bills',
    'bill_noData': 'No data',

    // Bill scan (image recognition)
    'bill_scanTitle': 'Scan Bill',
    'bill_scanAnalyzing': 'Analyzing bill…',
    'bill_scanNoModel':
        'No image model configured. Set it up in OpenAI plugin settings first',
    'bill_scanFailed': 'Recognition failed',
    'bill_scanNoItems': 'No bills recognized from the image',
    'bill_scanAddSelected': 'Add selected (@count)',
    'bill_scanSaving': 'Saving…',
    'bill_scanAdded': '@count bills added',

    // Sample data
    'bill_sampleAccountsTitle': 'Sample accounts & bills',
    'bill_sampleAccountsDesc': 'Create sample accounts with bill records',

    // Daily bill receipt
    'bill_receiptTitle': 'Bill Receipt',
    'bill_receiptItem': 'ITEM',
    'bill_receiptAmount': 'AMOUNT',
    'bill_receiptType': 'TYPE',
    'bill_receiptDate': 'TIME',
    'bill_receiptIncome': 'INCOME',
    'bill_receiptExpense': 'EXPENSE',
    'bill_receiptBills': 'BILLS',
    'bill_receiptBalance': 'BALANCE',
    'bill_receiptSlogan': 'EVERY BILL LEAVES A TRACE.',
    'bill_receiptDescription':
        'This receipt summarizes the bills of\n'
        'the day above, capturing income,\n'
        'expense and balance as a simple\n'
        'record of where money went.',
  };
}
