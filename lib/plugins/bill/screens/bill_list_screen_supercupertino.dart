import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../../../widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/plugins/bill/models/bill_model.dart';
import 'package:aboutme/plugins/bill/models/bill.dart';
import 'package:aboutme/plugins/bill/bill_plugin.dart';
import 'package:aboutme/plugins/bill/widgets/month_selector.dart';
import 'package:aboutme/widgets/swipe_action/index.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'bill_edit_screen.dart';
import 'account_list_screen.dart';

class BillListScreenSupercupertino extends StatefulWidget {
  final BillPlugin billPlugin;
  final String accountId;

  const BillListScreenSupercupertino({
    super.key,
    required this.billPlugin,
    required this.accountId,
  });

  @override
  State<BillListScreenSupercupertino> createState() =>
      _BillListScreenSupercupertinoState();
}

class _BillListScreenSupercupertinoState
    extends State<BillListScreenSupercupertino> {
  late final void Function() _billPluginListener;
  late CalendarController _calendarController;

  // Calendar State
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Data State
  List<BillModel> _allMonthBills = []; // All bills for the focused month
  Map<DateTime, _DailyStats> _dailyStats = {};

  String _filterCategory =
      'all'; // 'all', 'income', 'expense', or specific category name
  String _searchQuery = '';

  // 搜索过滤器状态
  final Map<String, bool> _searchFilters = {
    'category': true, // 是否搜索分类
    'note': true, // 是否搜索笔记
  };

  // Colors
  static const Color _incomeColor = Color(0xFF2ECC71);
  static const Color _expenseColor = Color(0xFFE74C3C);
  static const Color _primaryColor = Color(0xFF3498DB);

  @override
  void initState() {
    super.initState();
    // 确保默认选中今天
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _calendarController = CalendarController();
    _calendarController.displayDate = DateTime.now();
    _calendarController.selectedDate = DateTime.now();

    // 监听插件数据变化，自动刷新
    _billPluginListener = () {
      if (mounted) {
        _loadMonthBills();
      }
    };
    widget.billPlugin.addListener(_billPluginListener);

    // 初始化时加载当月账单数据，确保日历能显示账单标记
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonthBills();
    });

    // 初始化时设置路由上下文（包含选中的日期）
    _updateRouteContext(_focusedDay, selectedDay: _selectedDay);
  }

  @override
  void dispose() {
    _calendarController.dispose();
    widget.billPlugin.removeListener(_billPluginListener);
    super.dispose();
  }

  void _loadMonthBills() {
    // 检查账户数据是否可用
    if (widget.billPlugin.accounts.isEmpty) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _loadMonthBills();
        }
      });
      return;
    }

    try {
      final currentAccount = widget.billPlugin.accounts.firstWhere(
        (account) => account.id == widget.accountId,
      );
      // Calculate month start and end
      final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final monthEnd = DateTime(
        _focusedDay.year,
        _focusedDay.month + 1,
        0,
        23,
        59,
        59,
      );

      final filteredBills = currentAccount.bills.where(
        (bill) =>
            bill.date.isAfter(
              monthStart.subtract(const Duration(seconds: 1)),
            ) &&
            bill.date.isBefore(monthEnd.add(const Duration(seconds: 1))),
      );

      final bills = filteredBills
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

      // Sort by date descending
      bills.sort((a, b) => b.date.compareTo(a.date));

      // Calculate daily stats
      final stats = <DateTime, _DailyStats>{};
      for (var bill in bills) {
        final date = DateTime(bill.date.year, bill.date.month, bill.date.day);
        if (!stats.containsKey(date)) {
          stats[date] = _DailyStats();
        }
        if (bill.isExpense) {
          stats[date]!.expense += bill.amount;
        } else {
          stats[date]!.income += bill.amount;
        }
      }

      if (mounted) {
        setState(() {
          _allMonthBills = bills;
          _dailyStats = stats;
        });

        // 强制刷新日历显示
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {});
          }
        });
      }
    } catch (e) {
      debugPrint('加载账单失败: $e');
    }
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前月份或具体日期
  ///
  /// [date] 当前聚焦的日期（月份）
  /// [selectedDay] 可选参数，用户选中的具体日期
  void _updateRouteContext(DateTime date, {DateTime? selectedDay}) {
    String dateStr;
    String title;

    if (selectedDay != null) {
      // 如果有选中的具体日期，显示完整日期（YYYY-MM-DD）
      dateStr =
          '${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}';
      title = '账单列表 - $dateStr';
    } else {
      // 否则只显示月份（YYYY-MM）
      dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      title = '账单列表 - $dateStr';
    }

    RouteHistoryManager.updateCurrentContext(
      pageId: '/bill_list',
      title: title,
      params: {'date': dateStr},
    );
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildCalendarCell(DateTime day, bool isSelected) {
    final theme = DSThemeBridge.resolve(context);
    final date = DateTime(day.year, day.month, day.day);
    final stats = _dailyStats[date];
    final isToday = _isSameDay(DateTime.now(), day);
    final income = stats?.income ?? 0;
    final expense = stats?.expense ?? 0;
    final hasData = income > 0 || expense > 0;

    // 背景按收支占比双色填充：上绿（收入）下红（支出），分界线即占比
    Gradient? background;
    if (hasData) {
      final total = income + expense;
      final incomeRatio = total > 0 ? income / total : 0.0;
      final incomeBg = _incomeColor.withValues(alpha: 0.20);
      final expenseBg = _expenseColor.withValues(alpha: 0.20);
      background = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [incomeBg, incomeBg, expenseBg, expenseBg],
        stops: [0.0, incomeRatio, incomeRatio, 1.0],
      );
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: background,
        border: isToday
            ? Border.all(color: _primaryColor, width: 2)
            : (isSelected ? Border.all(color: _primaryColor, width: 1.5) : null),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        // 日期居中，下方收支"圆点+数字"分两行
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isSelected ? _primaryColor : theme.text,
            ),
          ),
          if (income > 0) ...[
            const SizedBox(height: 2),
            _buildDotStat(income, _incomeColor),
          ],
          if (expense > 0) ...[
            const SizedBox(height: 2),
            _buildDotStat(expense, _expenseColor),
          ],
        ],
      ),
    );
  }

  /// 日历单元格"圆点+金额"行，过宽时整体缩放
  Widget _buildDotStat(double amount, Color color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(
            amount.toInt().toString(),
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<BillModel> get _selectedDayBills {
    if (_selectedDay == null) return [];

    final selectedDate = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );

    return _allMonthBills.where((bill) {
      final billDate = DateTime(bill.date.year, bill.date.month, bill.date.day);
      return _isSameDay(billDate, selectedDate);
    }).toList();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '¥', decimalDigits: 2).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text('bill_billList'.tr),
      largeTitle: 'bill_billList'.tr,
      enableSearchBar: true,
      searchPlaceholder: 'bill_searchPlaceholder'.tr,
      onSearchChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      enableSearchFilter: true,
      filterLabels: const {'category': '分类', 'note': '笔记'},
      onSearchFilterChanged: (filters) {
        setState(() {
          _searchFilters.addAll(filters);
        });
      },
      searchBody: _buildSearchBody(),
      body: _buildMainBody(),
      enableLargeTitle: true,
      actions: [
        // SuperAppBar 的 actions 经 Overlay 渲染,DS 按钮需自带 DSThemeBridge
        // (DS 暂无钱包图标,account_balance_wallet 用 piggy 近似)
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.piggy,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'bill_accountManagement'.tr,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AccountListScreen(billPlugin: widget.billPlugin),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // 订阅入口已移至底部栏中间 tab
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.plus,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                onPressed: () {
                  // 打开前在 DS 主题树内取底色（sheet 是新路由，取不到 DS 主题）
                  final sheetTheme = DSThemeBridge.resolve(context);
                  SmoothBottomSheet.show(
                    context: context,
                    backgroundColor: sheetTheme.surface,
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题与保存按钮由 BillEditScreen 的 DSLightHeader 提供
                        // 固定高度：BillEditScreen 内部 Expanded 布局需要
                        // 有界高度约束
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.82,
                          child: BillEditScreen(
                            billPlugin: widget.billPlugin,
                            accountId: widget.accountId,
                            initialDate: _selectedDay ?? DateTime.now(),
                            embeddedInSheet: true,
                            onSaved: () {
                              _loadMonthBills();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMainBody() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month Selector
          MonthSelector(
            selectedMonth: _focusedDay,
            onMonthSelected: (month) {
              setState(() {
                _focusedDay = month;
                _calendarController.displayDate = month;
                _loadMonthBills();
              });
              // 更新路由上下文（切换月份时清除具体日期）
              _updateRouteContext(month);
            },
            getMonthStats: _getMonthStats,
            primaryColor: _primaryColor,
          ),

          // Calendar
          // viewHeaderHeight(40) + 6 行 × 单元格高度；调大单元格就改这里
          SizedBox(
            height: 40 + 6 * 64.0,
            child: SfCalendar(
              controller: _calendarController,
              view: CalendarView.month,
              initialDisplayDate: _focusedDay,
              minDate: DateTime(2020),
              maxDate: DateTime(2030),
              headerHeight: 0,
              viewHeaderHeight: 40,
              showNavigationArrow: false,
              monthViewSettings: const MonthViewSettings(
                showTrailingAndLeadingDates: true,
                dayFormat: 'EEE',
              ),
              cellBorderColor: Colors.transparent,
              selectionDecoration: const BoxDecoration(),
              monthCellBuilder:
                  (BuildContext context, MonthCellDetails details) {
                    final day = details.date;
                    final isSelected =
                        _selectedDay != null && _isSameDay(day, _selectedDay!);
                    return _buildCalendarCell(day, isSelected);
                  },
              onTap: (CalendarTapDetails details) {
                if (details.date != null) {
                  setState(() {
                    _selectedDay = details.date;
                    _focusedDay = details.date!;
                    _calendarController.selectedDate = details.date;
                  });
                  // 更新路由上下文到具体日期
                  _updateRouteContext(_focusedDay, selectedDay: _selectedDay);
                }
              },
              onViewChanged: (ViewChangedDetails details) {
                if (details.visibleDates.isNotEmpty) {
                  final newFocusedDay =
                      details.visibleDates[details.visibleDates.length ~/ 2];
                  _focusedDay = newFocusedDay;
                  _loadMonthBills();
                  // 更新路由上下文
                  _updateRouteContext(newFocusedDay);
                }
              },
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: DSThemeBridge(
              child: Wrap(
                spacing: 8,
                children: [
                  _buildFilterChip('all', '全部'),
                  _buildFilterChip('income', '收入'),
                  _buildFilterChip('expense', '支出'),
                ],
              ),
            ),
          ),

          // Daily Bills List
          if (_selectedDay != null) ...[
            Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      DsIcon(
                        DsIconKind.calendar,
                        size: 20,
                        color: _primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy年MM月dd日').format(_selectedDay!),
                        style: DsTypography.heading.copyWith(
                          color: theme.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (_selectedDayBills.isEmpty)
              DSThemeBridge(
                child: DSEmptyState(emoji: '📭', title: '这一天没有账单'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedDayBills.length,
                itemBuilder: (context, index) {
                  final bill = _selectedDayBills[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: DSThemeBridge(
                      child: JellyBox(
                        color: DSThemeBridge.resolve(context).surface,
                        radius: BorderRadius.circular(14),
                        raised: false,
                        child: SwipeActionWrapper(
                          key: ValueKey(bill.id),
                          leadingActions: [
                            SwipeActionPresets.edit(
                              onTap: () => _editBillSheet(context, bill),
                            ),
                          ],
                          trailingActions: [
                            SwipeActionPresets.delete(
                              onTap: () async {
                                try {
                                  final currentAccount = widget
                                      .billPlugin
                                      .accounts
                                      .firstWhere(
                                        (account) =>
                                            account.id == widget.accountId,
                                      );
                                  await widget.billPlugin.controller
                                      .deleteBill(currentAccount.id, bill.id);
                                  _loadMonthBills();
                                } catch (e) {
                                  Toast.error('删除失败: $e');
                                }
                              },
                            ),
                          ],
                          child: _buildBillRow(
                            context,
                            bill,
                            showNote: false,
                            onTap: () => _editBillSheet(context, bill),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ] else
            DSThemeBridge(
              child: DSEmptyState(emoji: '🗓️', title: '请选择一天查看账单'),
            ),
          // 悬浮底部栏预留
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  Widget _buildSearchBody() {
    // 过滤账单
    List<BillModel> filteredBills = _allMonthBills;

    if (_searchQuery.isNotEmpty) {
      filteredBills = filteredBills.where((bill) {
        final query = _searchQuery.toLowerCase();

        // 按名称搜索
        final matchTitle = bill.title.toLowerCase().contains(query);

        // 按分类搜索（如果启用）
        final matchCategory =
            (_searchFilters['category'] ?? true) &&
            bill.category.toLowerCase().contains(query);

        // 按笔记搜索（如果启用）
        final matchNote =
            (_searchFilters['note'] ?? true) &&
            (bill.note?.toLowerCase().contains(query) ?? false);

        // 满足任一条件即匹配
        return matchTitle || matchCategory || matchNote;
      }).toList();
    }

    if (_searchQuery.isNotEmpty && filteredBills.isEmpty) {
      return const DSThemeBridge(
        child: DSEmptyState(emoji: '🔍', title: '未找到匹配的账单'),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: filteredBills.length,
      itemBuilder: (context, index) {
        final bill = filteredBills[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DSThemeBridge(
            child: JellyBox(
              color: DSThemeBridge.resolve(context).surface,
              radius: BorderRadius.circular(14),
              raised: false,
              child: _buildBillRow(
                context,
                bill,
                showNote: true,
                onTap: () => _editBillSheet(context, bill),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 打开账单编辑底部弹层（smooth_sheets，与主界面 FAB 同款）
  void _editBillSheet(BuildContext context, BillModel bill) {
    final billObject = Bill(
      id: bill.id,
      title: bill.title,
      amount: bill.isExpense ? -bill.amount : bill.amount,
      accountId: widget.accountId,
      category: bill.category,
      date: bill.date,
      tag: bill.category,
      note: bill.note ?? '',
      createdAt: bill.date,
      icon: bill.icon,
      iconColor: bill.color,
    );
    final theme = DSThemeBridge.resolve(context);
    SmoothBottomSheet.show(
      context: context,
      backgroundColor: theme.surface,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题与保存按钮由 BillEditScreen 的 DSLightHeader 提供
          // 固定高度：BillEditScreen 内部 Expanded 布局需要有界高度约束
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.82,
            child: BillEditScreen(
              billPlugin: widget.billPlugin,
              accountId: widget.accountId,
              bill: billObject,
              embeddedInSheet: true,
              onSaved: _loadMonthBills,
            ),
          ),
        ],
      ),
    );
  }

  /// 账单行（自绘，图标/颜色为持久化数据）
  Widget _buildBillRow(
    BuildContext context,
    BillModel bill, {
    bool showNote = false,
    VoidCallback? onTap,
  }) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        // 收入/支出行浅色底：按压时加深作为反馈
        final tintAlpha = theme.isDark ? 0.16 : 0.12;
        final tintColor = (bill.isExpense ? _expenseColor : _incomeColor)
            .withValues(alpha: pressed ? tintAlpha + 0.08 : tintAlpha);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: tintColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bill.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(bill.icon, size: 22, color: bill.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.title,
                      style: DsTypography.body.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(bill.date),
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                    if (showNote && bill.note?.isNotEmpty == true)
                      Text(
                        bill.note!,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${bill.isExpense ? '-' : '+'}${_formatCurrency(bill.amount)}',
                style: DsTypography.body.copyWith(
                  color: bill.isExpense ? _expenseColor : _incomeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterCategory == value;
    return DSChip(
      label: label,
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterCategory = value;
        });
      },
    );
  }
}

class _DailyStats {
  double income = 0;
  double expense = 0;
}
