/// 账单插件中文翻译 (GetX)
class BillTranslationsZh {
  static const Map<String, String> translations = {
    // 基础字段
    'bill_name': '账单',
    'bill_dayCardName': '账单日卡',
    'bill_dayCardDesc': '展示选中日期的账单收支',
    'bill_dayCardEmpty': '当天没有账单',
    'bill_billList': '账单列表',
    'bill_newBill': '新建账单',
    'bill_editBill': '编辑账单',
    'bill_date': '日期',
    'bill_note': '备注',
    'bill_income': '收入',
    'bill_expense': '支出',
    'bill_save': '保存',
    'bill_cancel': '取消',
    'bill_confirmDelete': '确认删除',
    'bill_selectCategory': '选择分类',
    'bill_addNote': '添加备注',

    // 统计相关
    'bill_byCategory': '按分类',
    'bill_statisticsAnalysis': '统计分析',

    // 列表和搜索

    // 消息提示
    'bill_billSaved': '账单保存成功',
    'bill_billSaveFailed': '账单保存失败',
    'bill_requiredField': '此项为必填项',

    // 账户管理
    'bill_accountName': '账户名称',
    'bill_accountManagement': '账户管理',
    'bill_accountDeleted': '账户已删除',
    'bill_noAccounts': '暂无账户',
    'bill_deleteAccount': '删除账户',
    'bill_enterAccountName': '输入账户名称',
    'bill_confirmDeleteAccountWithBills': '确认删除账户及其关联账单?',

    // 时间范围
    'bill_todayFinance': '今日财务',
    'bill_monthFinance': '月度财务',
    'bill_monthBills': '月度账单',

    // 其他
    'bill_delete': '删除',
    'bill_balance': '余额',
    'bill_title': '标题',

    // 快捷记账配置
    'bill_saveConfig': '保存配置',
    'bill_quickBookkeepingConfig': '快捷记账配置',
    'bill_addQuickPreset': '添加快捷预设',
    'bill_noQuickPresets': '暂无快捷预设',
    'bill_clickToAddQuickPreset': '点击右下角的 + 按钮添加快捷预设',
    'bill_editQuickPreset': '编辑快捷预设',
    'bill_presetName': '预设名称',
    'bill_presetNameHint': '例如: 早餐、打车',
    'bill_pleaseEnterPresetName': '请输入预设名称',
    'bill_presetAmount': '预设金额(可选)',
    'bill_presetAmountHint': '留空则每次手动输入',
    'bill_edit': '编辑',
    'bill_monthlyRecord': '月度记账',

    // Home Widget Strings
    'bill_widgetName': '账单',
    'bill_widgetDescription': '快速打开账单',
    'bill_overviewName': '账单概览',
    'bill_overviewDescription': '显示收支统计信息',
    'bill_createShortcutName': '创建账单',
    'bill_createShortcutDescription': '快速创建新账单',

    // 支出统计组件
    'bill_statsWidgetName': '支出统计',
    'bill_statsWidgetDescription': '显示收入/支出统计，支持自定义目标金额',

    // 月份账单组件
    'bill_monthlyBillsWidgetName': '月份账单',
    'bill_monthlyBillsWidgetDescription': '显示指定月份的账单列表和统计',

    // 界面搜索
    'bill_searchPlaceholder': '搜索账单名称/分类/笔记',

    // 订阅服务
    'bill_subscription': '订阅服务',
    'bill_addSubscription': '添加订阅',
    'bill_editSubscription': '编辑订阅',
    'bill_deleteSubscription': '删除订阅',
    'bill_activeSubscriptions': '活跃订阅',
    'bill_inactiveSubscriptions': '不再续费',
    'bill_noSubscriptions': '暂无订阅服务',
    'bill_clickToAddSubscription': '点击下方按钮添加订阅服务',
    'bill_subscriptionName': '订阅名称',
    'bill_subscriptionPrice': '价格',
    'bill_startDate': '开始日期',
    'bill_endDate': '结束日期',
    'bill_chooseIcon': '选择图标',
    'bill_monthly': '每月',
    'bill_quarterly': '每季度',
    'bill_yearly': '每年',
    'bill_autoSubscribe': '自动续费',
    'bill_autoSubscribeDesc': '到期时自动续费',
    'bill_notes': '备注',
    'bill_terminateSubscription': '终止订阅',
    'bill_terminateConfirm': '确定要终止"{name}"吗？',
    'bill_deleteConfirm': '确定要删除"{name}"吗？此操作不可撤销。',
    'bill_subscriptionCreated': '订阅创建成功',
    'bill_subscriptionUpdated': '订阅更新成功',
    'bill_saveFailed': '保存失败',
    'bill_subscriptionDaysError': '订阅天数必须大于0',
    'bill_nextDate': '下次:',
    'bill_autoRenew': '自动续费',
    'bill_days': '天',
    'bill_weekly': '每周',
    'bill_none': '无',
    'bill_switchToListView': '切换到列表视图',
    'bill_switchToGridView': '切换到网格视图',
    'bill_notesHint': '添加备注、订单号或账户详情...',
  
  // const Text 硬编码迁移(zh)
  'bill_statsReport': '统计报表',

  // 编辑账单屏幕
  'bill_addBill': '添加账单',
  'bill_amountMustBePositive': '请输入有效金额（需大于0）',
  'bill_pleaseEnterSubscriptionName': '请输入订阅服务名称',
  'bill_pleaseEnterSubscriptionDays': '请输入订阅天数',
  'bill_titleHint': '留空则使用分类名称',
  'bill_enableSubscription': '启用订阅服务',
  'bill_enableSubscriptionHint': '启用后将自动生成每日账单',
  'bill_subscriptionNameHint': '例如：Netflix会员',
  'bill_subscriptionDays': '订阅天数',
  'bill_subscriptionDaysHint': '例如：30',
  'bill_dailyAmount': '单日金额',
  'bill_perDaySuffix': ' / 天',

  // 统计页(手绘风格)
  'bill_monthBudget': '每月预算',
  'bill_budgetHint': '设置每月支出上限, 掌控花销节奏',
  'bill_budgetSetAmount': '设置预算金额',
  'bill_budgetInvalid': '请输入有效金额',
  'bill_budgetUsed': '已用',
  'bill_budgetRemaining': '剩余',
  'bill_budgetOverspent': '已超支',
  'bill_dailyExpenseChart': '每日支出',
  'bill_monthBillsCount': '@count 笔',
  'bill_noData': '暂无数据',

  // 拍照记账（识图识别）
  'bill_scanTitle': '拍照记账',
  'bill_scanAnalyzing': '正在识别账单…',
  'bill_scanNoModel': '未配置识图模型，请先在 OpenAI 插件设置中配置',
  'bill_scanFailed': '识别失败',
  'bill_scanNoItems': '未从图片中识别出账单',
  'bill_scanAddSelected': '添加选中 (@count)',
  'bill_scanSaving': '保存中…',
  'bill_scanAdded': '已添加 @count 笔账单',

  // 示例数据
  'bill_sampleAccountsTitle': '示例账户与账单',
  'bill_sampleAccountsDesc': '创建包含账单记录的示例账户',

  // 单日账单小票
  'bill_receiptTitle': '账单小票',
  'bill_receiptItem': '项目',
  'bill_receiptAmount': '金额',
  'bill_receiptType': '类型',
  'bill_receiptDate': '时间',
  'bill_receiptIncome': '收入',
  'bill_receiptExpense': '支出',
  'bill_receiptBills': '笔数',
  'bill_receiptBalance': '结余',
  'bill_receiptSlogan': '每一笔账单都留下痕迹。',
  'bill_receiptDescription':
      '这是您当日账单的汇总小票，\n'
      '记录每一笔收支与结余，\n'
      '可作为当日记账的留存凭证。',
};
}
