import 'package:flutter/material.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:skribble/skribble.dart';
import '../../../../widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/plugins/bill/bill_plugin.dart';
import 'package:aboutme/plugins/bill/models/bill_model.dart';
import 'package:aboutme/plugins/bill/widgets/month_selector.dart';
import 'package:aboutme/widgets/stats/sketch_stats.dart';
import 'package:aboutme/widgets/wave_fill.dart';

/// 账单统计页（视觉风格同 ChatStatsScreen：手绘墨线统计卡）
///
/// - 预算卡：每月支出上限（存 pluginSettings）+ 当月支出进度
/// - Hero 卡：本月支出大数字 + 较上月增量胶囊 + 收入/结余/笔数摘要
/// - 每日支出分布：手绘墨线曲线
/// - 分类明细：支出/收入切换 + 手绘时间线排行（可展开子项）
class BillStatsScreenSupercupertino extends StatefulWidget {
  final BillPlugin billPlugin;
  final String accountId;
  final DateTime startDate;
  final DateTime endDate;

  const BillStatsScreenSupercupertino({
    super.key,
    required this.billPlugin,
    required this.accountId,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<BillStatsScreenSupercupertino> createState() =>
      _BillStatsScreenSupercupertinoState();
}

class _BillStatsScreenSupercupertinoState
    extends State<BillStatsScreenSupercupertino> {
  late DateTime _selectedMonth;
  bool _isExpenseSelected = true;
  final Set<String> _expandedCategories = {};

  static const Color _incomeColor = Color(0xFF2ECC71);
  static const Color _expenseColor = Color(0xFFE74C3C);
  static const Color _primaryColor = Color(0xFF3498DB);

  @override
  void initState() {
    super.initState();
    // 默认显示当前月份，而不是 startDate 的月份
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);

    // 初始化时设置路由上下文
    _updateRouteContext(_selectedMonth);
  }

  List<BillModel> _getBillsForMonth(DateTime month) {
    try {
      final currentAccount = widget.billPlugin.accounts.firstWhere(
        (account) => account.id == widget.accountId,
      );

      final monthStart = DateTime(month.year, month.month, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final bills = currentAccount.bills.where(
        (bill) =>
            bill.date.isAfter(
              monthStart.subtract(const Duration(seconds: 1)),
            ) &&
            bill.date.isBefore(monthEnd.add(const Duration(seconds: 1))),
      );

      return bills
          .map(
            (bill) => BillModel(
              id: bill.id,
              title: bill.title,
              amount: bill.absoluteAmount,
              date: bill.date,
              icon: bill.icon,
              color: bill.iconColor,
              category: bill.tag ?? '未分类',
              note: bill.note,
              isExpense: bill.isExpense,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Map<String, double> _getMonthStats(DateTime month) {
    try {
      final currentAccount = widget.billPlugin.accounts.firstWhere(
        (account) => account.id == widget.accountId,
      );

      final monthStart = DateTime(month.year, month.month, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final bills = currentAccount.bills.where(
        (bill) =>
            bill.date.isAfter(
              monthStart.subtract(const Duration(seconds: 1)),
            ) &&
            bill.date.isBefore(monthEnd.add(const Duration(seconds: 1))),
      );

      double income = 0;
      double expense = 0;

      for (var bill in bills) {
        if (bill.isExpense) {
          expense += bill.absoluteAmount;
        } else {
          income += bill.absoluteAmount;
        }
      }

      return {
        'income': income,
        'expense': expense,
        'balance': income - expense,
      };
    } catch (e) {
      return {'income': 0, 'expense': 0, 'balance': 0};
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
      _expandedCategories.clear();
    });
    // 更新路由上下文
    _updateRouteContext(_selectedMonth);
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前月份
  void _updateRouteContext(DateTime month) {
    final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    RouteHistoryManager.updateCurrentContext(
      pageId: '/bill_stats',
      title: '账单分析 - $monthStr',
      params: {'month': monthStr},
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '¥', decimalDigits: 2).format(amount);
  }

  // ===== 每月预算（存 pluginSettings） =====

  /// 支出上限；未设置或非法时为 null
  double? get _monthlyBudget {
    final v = widget.billPlugin.settings['monthlyBudget'];
    if (v is num && v > 0) return v.toDouble();
    return null;
  }

  Future<void> _editBudget() async {
    final controller = TextEditingController(
      text: _monthlyBudget?.toStringAsFixed(0) ?? '',
    );
    final input = await showDSDialog<String>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: DSDialog(
          title: 'bill_budgetSetAmount'.tr,
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '例如: 3000'),
          ),
          cancelText: 'app_cancel'.tr,
          confirmText: 'app_ok'.tr,
          onCancel: () => Navigator.pop(dialogContext),
          onConfirm: () => Navigator.pop(dialogContext, controller.text.trim()),
        ),
      ),
    );
    controller.dispose();
    if (!mounted || input == null) return;

    final value = double.tryParse(input);
    if (value == null || value <= 0) {
      Toast.error('bill_budgetInvalid'.tr);
      return;
    }
    await widget.billPlugin.updateSettings({'monthlyBudget': value});
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bills = _getBillsForMonth(_selectedMonth);

    double totalIncome = 0;
    double totalExpense = 0;
    for (var bill in bills) {
      if (bill.isExpense) {
        totalExpense += bill.amount;
      } else {
        totalIncome += bill.amount;
      }
    }
    final balance = totalIncome - totalExpense;

    // Filter bills for the list based on toggle
    final listBills =
        bills.where((b) => b.isExpense == _isExpenseSelected).toList();
    final totalListAmount = _isExpenseSelected ? totalExpense : totalIncome;

    // Group by Category
    final categoryStats = <String, _CategoryData>{};
    for (var bill in listBills) {
      if (!categoryStats.containsKey(bill.category)) {
        categoryStats[bill.category] = _CategoryData(
          name: bill.category,
          amount: 0,
          icon: bill.icon,
          color: bill.color,
        );
      }
      categoryStats[bill.category]!.amount += bill.amount;

      // Group by Title for sub-items
      final subMap = categoryStats[bill.category]!.subItems;
      final key = bill.title.isNotEmpty ? bill.title : '其他';
      subMap[key] = (subMap[key] ?? 0) + bill.amount;
    }

    final sortedCategories =
        categoryStats.values.toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    return SuperCupertinoNavigationWrapper(
      title: Text('bill_statisticsAnalysis'.tr),
      largeTitle: 'bill_statisticsAnalysis'.tr,
      enableSearchBar: false,
      // Tab 切换挂载时墨线描画入场（与 chat 统计页一致）
      body: WiredDraw(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildBudgetCard(theme, totalExpense),
            const SizedBox(height: 16),
            _buildHeroCard(
              theme,
              totalIncome,
              totalExpense,
              balance,
              bills.length,
            ),
            const SizedBox(height: 16),
            _buildDailyLineChartCard(theme, bills),
            const SizedBox(height: 16),
            _buildCategoryCard(theme, sortedCategories, totalListAmount),
          ],
        ),
      ),
      enableLargeTitle: true,
    );
  }

  // ===== Header：年份切换 + 月份条 =====

  Widget _buildHeader() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'bill_statsReport'.tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  DSThemeBridge(
                    child: DSIconButton(
                      icon: DsIconKind.chevronLeft,
                      size: 30,
                      onPressed: () => _changeMonth(-1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${_selectedMonth.year}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DSThemeBridge(
                    child: DSIconButton(
                      icon: DsIconKind.chevronRight,
                      size: 30,
                      onPressed: () => _changeMonth(1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        MonthSelector(
          selectedMonth: _selectedMonth,
          onMonthSelected: (month) {
            setState(() {
              _selectedMonth = month;
              _expandedCategories.clear();
            });
            // 更新路由上下文
            _updateRouteContext(month);
          },
          getMonthStats: _getMonthStats,
          primaryColor: _primaryColor,
        ),
      ],
    );
  }

  // ===== 预算卡：每月支出上限 + 进度 =====

  Widget _buildBudgetCard(ThemeData theme, double totalExpense) {
    final budget = _monthlyBudget;

    return StatsSketchCard(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _editBudget,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.savings_outlined, size: 20, color: _expenseColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'bill_monthBudget'.tr,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (budget == null)
              Text(
                'bill_budgetHint'.tr,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              // 支出进度波浪条（超支整条飘红）
              SizedBox(
                height: 26,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: SizedBox.expand(
                      child: WaveFill(
                        progress:
                            (totalExpense / budget).clamp(0.0, 1.0),
                        color: totalExpense > budget
                            ? _expenseColor
                            : theme.colorScheme.primary,
                        horizontal: true,
                        amplitude: 3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${'bill_budgetUsed'.tr} ${_formatCurrency(totalExpense)} / ${_formatCurrency(budget)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (totalExpense > budget)
                    Text(
                      '${'bill_budgetOverspent'.tr} ${_formatCurrency(totalExpense - budget)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _expenseColor,
                      ),
                    )
                  else
                    Text(
                      '${'bill_budgetRemaining'.tr} ${_formatCurrency(budget - totalExpense)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===== Hero 卡：本月总览 =====

  Widget _buildHeroCard(
    ThemeData theme,
    double totalIncome,
    double totalExpense,
    double balance,
    int billCount,
  ) {
    final lastMonth = _getMonthStats(
      DateTime(_selectedMonth.year, _selectedMonth.month - 1),
    );
    final diff = totalExpense - lastMonth['expense']!;

    return StatsSketchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('yyyy年MM月').format(_selectedMonth)} · ${'bill_expense'.tr}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCurrency(totalExpense),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              // 较上月增量胶囊
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFFFDBCF),
                ),
                child: Row(
                  children: [
                    Icon(
                      diff >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${diff >= 0 ? '+' : ''}${_formatCurrency(diff)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFA5E1E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${'bill_income'.tr} ${_formatCurrency(totalIncome)} · ${'bill_balance'.tr} ${_formatCurrency(balance)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                'bill_monthBillsCount'.trParams({'count': '$billCount'}),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== 每日支出分布曲线（手绘墨线） =====

  Widget _buildDailyLineChartCard(ThemeData theme, List<BillModel> bills) {
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final dailyExpense = List.filled(daysInMonth, 0.0);
    for (final bill in bills) {
      if (bill.isExpense) {
        dailyExpense[bill.date.day - 1] += bill.amount;
      }
    }
    final maxDaily = dailyExpense.fold(0.0, (a, b) => a > b ? a : b);

    // x 轴标签：1 / 8 / 15 / 22 / 月末
    final labelDays = {
      1,
      8,
      15,
      22,
      daysInMonth,
    };

    return StatsSketchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'bill_dailyExpenseChart'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 手绘墨线曲线（CustomPaint 无 child，需 tight 约束撑满）
          SizedBox(
            width: double.infinity,
            height: 160,
            child: Builder(
              builder: (context) {
                final dsTheme = DSThemeBridge.resolve(context);
                return SketchLineChart(
                  values: dailyExpense,
                  maxValue: maxDaily < 1 ? 1.0 : maxDaily,
                  color: theme.colorScheme.primary,
                  drawConfig: dsTheme.wired.drawConfig,
                  drawProgress: WiredDrawTransition.progressOf(context),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < daysInMonth; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  child: Center(
                    child: Text(
                      labelDays.contains(i + 1) ? '${i + 1}' : '',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ===== 分类明细：支出/收入切换 + 手绘时间线排行 =====

  Widget _buildCategoryCard(
    ThemeData theme,
    List<_CategoryData> sortedCategories,
    double totalListAmount,
  ) {
    return StatsSketchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.donut_small,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'bill_byCategory'.tr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                _formatCurrency(totalListAmount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 支出/收入切换
          Row(
            children: [
              _buildToggleButton(theme, 'bill_expense'.tr, true),
              const SizedBox(width: 8),
              _buildToggleButton(theme, 'bill_income'.tr, false),
            ],
          ),
          const SizedBox(height: 8),
          if (sortedCategories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'bill_noData'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < sortedCategories.length; i++)
              _buildCategoryItem(
                theme,
                sortedCategories[i],
                totalListAmount > 0
                    ? sortedCategories[i].amount / totalListAmount
                    : 0.0,
                i < sortedCategories.length - 1,
              ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(ThemeData theme, String label, bool isExpense) {
    final isSelected =
        (_isExpenseSelected && isExpense) ||
        (!_isExpenseSelected && !isExpense);
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpenseSelected = isExpense;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: isSelected
              ? (_isExpenseSelected && isExpense
                    ? _expenseColor.withValues(alpha: 0.12)
                    : _incomeColor.withValues(alpha: 0.12))
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (_isExpenseSelected && isExpense
                      ? _expenseColor
                      : _incomeColor)
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    ThemeData theme,
    _CategoryData category,
    double percentage,
    bool showLine,
  ) {
    final isExpanded = _expandedCategories.contains(category.name);

    return IntrinsicHeight(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedCategories.remove(category.name);
            } else {
              _expandedCategories.add(category.name);
            }
          });
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 时间线：圆点 + 连接线
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  const SizedBox(height: 5),
                  // 手绘圆点：分类色实底 + 墨线描边
                  Container(
                    width: 12,
                    height: 12,
                    decoration: dsSketchDecoration(
                      theme: DSThemeBridge.resolve(context),
                      circle: true,
                      fillColor: category.color,
                      strokeWidth: 1.4,
                    ),
                  ),
                  if (showLine)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.only(top: 4),
                        color: theme.colorScheme.surfaceContainerHigh,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isExpanded ? 8 : showLine ? 16 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          category.icon,
                          size: 15,
                          color: category.color,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(percentage * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatCurrency(category.amount),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    // 展开子项
                    if (isExpanded && category.subItems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 21),
                        child: Column(
                          children:
                              category.subItems.entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.key,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(entry.value),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryData {
  final String name;
  double amount;
  final IconData icon;
  final Color color;
  final Map<String, double> subItems = {};

  _CategoryData({
    required this.name,
    required this.amount,
    required this.icon,
    required this.color,
  });
}
