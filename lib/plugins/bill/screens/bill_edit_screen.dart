import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/bill/bill_plugin.dart';
import 'package:aboutme/plugins/bill/models/bill.dart';
import 'package:aboutme/plugins/bill/models/subscription.dart';
import 'package:aboutme/widgets/form_fields/index.dart';

class BillEditScreen extends StatefulWidget {
  final BillPlugin billPlugin;
  final String accountId;
  final Bill? bill;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;
  final DateTime? initialDate;

  // 预填充参数（用于快捷记账小组件）
  final String? initialCategory;
  final double? initialAmount;
  final bool? initialIsExpense;

  const BillEditScreen({
    super.key,
    required this.billPlugin,
    required this.accountId,
    this.bill,
    this.onSaved,
    this.onCancel,
    this.initialDate,
    this.initialCategory,
    this.initialAmount,
    this.initialIsExpense,
  });

  @override
  State<BillEditScreen> createState() => _BillEditScreenState();
}

class _BillEditScreenState extends State<BillEditScreen> {
  // 表单 key
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();

  // FormBuilderWrapper 的状态引用
  FormBuilderWrapperState? _wrapperState;

  // 分类相关数据
  String? _tag;
  IconData _selectedIcon = Icons.category;
  Color _selectedColor = Colors.blue;
  DateTime _selectedDate = DateTime.now();

  // 订阅服务状态
  bool _isSubscriptionEnabled = false;

  // 可用的分类标签
  final List<String> _availableTags = <String>[
    '餐饮',
    '购物',
    '交通',
    '日用',
    '娱乐',
    '医疗',
    '教育',
    '住房',
    '工资',
    '奖金',
    '投资',
    '其他',
  ];

  // 分类图标映射
  final Map<String, IconData> _categoryIcons = {
    '餐饮': Icons.restaurant,
    '购物': Icons.shopping_bag,
    '交通': Icons.commute,
    '日用': Icons.local_mall,
    '娱乐': Icons.sports_esports,
    '医疗': Icons.local_hospital,
    '教育': Icons.school,
    '住房': Icons.home,
    '工资': Icons.attach_money,
    '奖金': Icons.card_giftcard,
    '投资': Icons.trending_up,
    '其他': Icons.more_horiz,
    '未分类': Icons.category,
  };

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  /// 初始化表单数据
  void _initializeFormData() {
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }

    if (widget.bill != null) {
      _tag = widget.bill!.tag ?? widget.bill!.category;
      _selectedIcon = widget.bill!.icon;
      _selectedColor = widget.bill!.iconColor;
      _selectedDate = widget.bill!.date;

      if (_tag != null && !_availableTags.contains(_tag)) {
        _availableTags.add(_tag!);
      }

      _updateRouteContext(isEdit: true, billId: widget.bill!.id);
    } else {
      _tag = widget.initialCategory ?? _availableTags.first;
      _selectedIcon = _categoryIcons[_tag] ?? Icons.category;

      if (_tag != null && !_availableTags.contains(_tag)) {
        _availableTags.add(_tag!);
      }

      _updateRouteContext(isEdit: false);
    }
  }

  /// 更新路由上下文
  void _updateRouteContext({required bool isEdit, String? billId}) {
    if (isEdit && billId != null) {
      RouteHistoryManager.updateCurrentContext(
        pageId: '/bill_edit',
        title: 'bill_editBill'.tr,
        params: {'billId': billId},
      );
    } else {
      RouteHistoryManager.updateCurrentContext(
        pageId: '/bill_create',
        title: 'bill_newBill'.tr,
        params: {},
      );
    }
  }

  /// 保存账单
  Future<void> _handleSave(Map<String, dynamic> values) async {
    try {
      final amount = (values['amount'] as num?)?.toDouble() ?? 0.0;
      final isExpense = values['isExpense'] as bool? ?? false;
      final isSubscription = values['isSubscription'] as bool?;

      // 验证金额必须大于0
      if (amount <= 0) {
        Toast.error('bill_amountMustBePositive'.tr);
        return;
      }

      if (isSubscription == true) {
        // 验证订阅服务字段
        final subscriptionName = values['subscriptionName'] as String?;
        final subscriptionDaysValue = values['subscriptionDays'];

        if (subscriptionName == null || subscriptionName.isEmpty) {
          Toast.error('bill_pleaseEnterSubscriptionName'.tr);
          return;
        }

        if (subscriptionDaysValue == null) {
          Toast.error('bill_pleaseEnterSubscriptionDays'.tr);
          return;
        }

        final days = int.tryParse(subscriptionDaysValue.toString());
        if (days == null || days <= 0) {
          Toast.error('bill_subscriptionDaysError'.tr);
          return;
        }

        // 保存为订阅服务
        final subscription = Subscription(
          name: subscriptionName,
          totalAmount: amount,
          days: days,
          category: _tag ?? '订阅',
          startDate: _selectedDate,
          note: values['note'] as String?,
          icon: _selectedIcon,
          iconColor: _selectedColor,
        );

        await widget.billPlugin.controller.subscriptions.createSubscription(
          subscription,
        );

        if (!mounted) return;
        Toast.success('bill_subscriptionCreated'.tr);
      } else {
        // 保存为普通账单
        final title = values['title'] as String?;
        final finalTitle =
            (title == null || title.isEmpty) ? (_tag ?? '未分类') : title;

        final bill = Bill(
          id: widget.bill?.id ?? const Uuid().v4(),
          title: finalTitle,
          amount: isExpense ? -amount : amount,
          accountId: widget.accountId,
          category: _tag ?? '未分类',
          date: _selectedDate,
          tag: _tag,
          note: values['note'] as String? ?? '',
          icon: _selectedIcon,
          iconColor: _selectedColor,
          createdAt: widget.bill?.createdAt ?? _selectedDate,
        );

        await widget.billPlugin.controller.saveBill(bill);

        if (!mounted) return;
        Toast.success('bill_billSaved'.tr);
      }

      Navigator.of(context).pop();
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      Toast.error('${'bill_billSaveFailed'.tr}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final backgroundColor = theme.surface;
    final cardColor = theme.surfaceAlt;
    final primaryColor = theme.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor.withValues(alpha: 0.8),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          widget.bill == null ? 'bill_addBill'.tr : 'bill_editBill'.tr,
          style: DsTypography.title.copyWith(
            color: theme.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.chevronLeft,
                size: 40,
                color: theme.surface,
                iconColor: theme.text,
                onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
              );
            },
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: FormBuilderWrapper(
                formKey: _formKey,
                onStateReady: (state) => _wrapperState = state,
                config: FormConfig(
                  fields: _buildFormFields(primaryColor),
                  showSubmitButton: false,
                  showResetButton: false,
                  onSubmit: _handleSave,
                  fieldSpacing: 0,
                ),
                contentBuilder: (context, fields) {
                  // 使用 contentBuilder 自定义布局
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 标题字段
                      FormFieldGroup(
                        showDividers: false,
                        showBackground: false,
                        children: [fields[2]], // title字段
                      ),
                      const SizedBox(height: 16),

                      // 类型和金额卡片
                      _buildTypeAndAmountCard(fields, cardColor, primaryColor),
                      const SizedBox(height: 16),

                      // 分类选择卡片
                      _buildCategoryCard(fields, cardColor, primaryColor),
                      const SizedBox(height: 16),

                      // 日期和备注
                      _buildDateAndNoteSection(fields),
                      const SizedBox(height: 16),

                      // 订阅服务卡片
                      _buildSubscriptionCard(fields, cardColor, primaryColor),
                    ],
                  );
                },
              ),
            ),
          ),

          // 保存按钮区域
          _buildSaveButton(backgroundColor, primaryColor),
        ],
      ),
    );
  }

  /// 构建表单字段配置
  List<FormFieldConfig> _buildFormFields(Color primaryColor) {
    return [
      // 收支类型选择器（隐藏，用于状态管理）
      FormFieldConfig(
        name: 'isExpense',
        type: FormFieldType.expenseTypeSelector,
        initialValue:
            widget.bill != null
                ? widget.bill!.isExpense
                : (widget.initialIsExpense ?? true),
        extra: {
          'expenseColor': const Color(0xFFE74C3C),
          'incomeColor': const Color(0xFF2ECC71),
        },
      ),

      // 金额输入框（隐藏，用于状态管理）
      FormFieldConfig(
        name: 'amount',
        type: FormFieldType.amountInput,
        initialValue:
            widget.bill != null
                ? widget.bill!.absoluteAmount
                : widget.initialAmount,
        required: true,
        validationMessage: 'bill_amountMustBePositive'.tr,
        extra: {'currencySymbol': '¥', 'fontSize': 40.0},
      ),

      // 标题
      FormFieldConfig(
        name: 'title',
        type: FormFieldType.text,
        initialValue: widget.bill?.title ?? '',
        labelText: 'bill_title'.tr,
        hintText: 'bill_titleHint'.tr,
      ),

      // 日期选择器
      FormFieldConfig(
        name: 'date',
        type: FormFieldType.date,
        initialValue: _selectedDate,
        extra: {
          'format': Get.locale?.languageCode == 'zh' ? 'yyyy年MM月dd日' : 'yyyy/MM/dd',
          'inline': true,
        },
      ),

      // 备注
      FormFieldConfig(
        name: 'note',
        type: FormFieldType.textArea,
        initialValue: widget.bill?.note ?? '',
        hintText: 'bill_addNote'.tr,
        extra: {'minLines': 3, 'maxLines': 5},
      ),

      // 订阅服务开关
      FormFieldConfig(
        name: 'isSubscription',
        type: FormFieldType.switchField,
        initialValue: false,
        labelText: 'bill_enableSubscription'.tr,
        hintText: 'bill_enableSubscriptionHint'.tr,
        prefixIcon: Icons.autorenew,
        onChanged: (value) {
          setState(() {
            _isSubscriptionEnabled = value as bool;
          });
        },
      ),

      // 订阅服务名称
      FormFieldConfig(
        name: 'subscriptionName',
        type: FormFieldType.text,
        labelText: 'bill_subscriptionName'.tr,
        hintText: 'bill_subscriptionNameHint'.tr,
      ),

      // 订阅天数
      FormFieldConfig(
        name: 'subscriptionDays',
        type: FormFieldType.number,
        labelText: 'bill_subscriptionDays'.tr,
        hintText: 'bill_subscriptionDaysHint'.tr,
      ),
    ];
  }

  /// 构建类型和金额卡片
  Widget _buildTypeAndAmountCard(
    List<Widget> fields,
    Color cardColor,
    Color primaryColor,
  ) {
    // 获取类型选择器和金额输入框的字段
    final typeField = fields[0];
    final amountField = fields[1];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          typeField,
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [const SizedBox(width: 16), Expanded(child: amountField)],
          ),
        ],
      ),
    );
  }

  /// 构建分类选择卡片
  Widget _buildCategoryCard(
    List<Widget> fields,
    Color cardColor,
    Color primaryColor,
  ) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'bill_selectCategory'.tr,
            style: DsTypography.heading.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.textSub,
            ),
          ),
          const SizedBox(height: 16),
          CategorySelectorField(
            categories: _availableTags,
            selectedCategory: _tag,
            categoryIcons: _categoryIcons,
            primaryColor: primaryColor,
            onCategoryChanged: (category) {
              setState(() {
                _tag = category;
                _selectedIcon = _categoryIcons[category] ?? Icons.category;
              });
            },
          ),
        ],
      ),
    );
  }

  /// 构建日期和备注区域
  Widget _buildDateAndNoteSection(List<Widget> fields) {
    final dateField = fields[3];
    final noteField = fields[4];
    final theme = DSThemeBridge.resolve(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFieldGroup(showDividers: true, children: [dateField]),
        const SizedBox(height: 16),
        FormFieldGroup(
          showDividers: false,
          children: [
            // 备注标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'bill_note'.tr,
                style: DsTypography.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.textSub,
                ),
              ),
            ),
            noteField,
          ],
        ),
      ],
    );
  }

  /// 构建订阅服务卡片
  Widget _buildSubscriptionCard(
    List<Widget> fields,
    Color cardColor,
    Color primaryColor,
  ) {
    final theme = DSThemeBridge.resolve(context);
    final switchField = fields[5];
    final nameField = fields[6];
    final daysField = fields[7];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'bill_subscription'.tr,
            style: DsTypography.heading.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.textSub,
            ),
          ),
          const SizedBox(height: 16),
          switchField,
          // 根据订阅服务状态显示额外字段
          if (_isSubscriptionEnabled) ...[
            const SizedBox(height: 16),
            nameField,
            const SizedBox(height: 16),
            daysField,
            _buildDailyAmountCalculation(primaryColor),
          ],
        ],
      ),
    );
  }

  /// 构建单日金额计算显示
  Widget _buildDailyAmountCalculation(Color primaryColor) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        final formState = _formKey.currentState;
        final amountValue = formState?.value['amount'];
        final daysValue = formState?.value['subscriptionDays'];

        if (amountValue == null || daysValue == null) {
          return const SizedBox.shrink();
        }

        final amount = amountValue as double;
        final days = int.tryParse(daysValue.toString());

        if (days == null || days <= 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              DsIcon(DsIconKind.piggy, color: primaryColor),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'bill_dailyAmount'.tr,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  Text(
                    '¥${(amount / days).toStringAsFixed(2)}${'bill_perDaySuffix'.tr}',
                    style: DsTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建保存按钮
  Widget _buildSaveButton(Color backgroundColor, Color primaryColor) {
    return Container(
      padding:
          const EdgeInsets.all(16) +
          MediaQuery.of(context).padding.copyWith(top: 0),
      color: backgroundColor.withValues(alpha: 0.8),
      child: DSThemeBridge(
        child: DSButton(
          label: 'bill_save'.tr,
          onPressed: () {
            // 使用 wrapper 的提交方法，确保所有字段值正确收集
            _wrapperState?.submitForm();
          },
          expand: true,
          size: DSButtonSize.lg,
        ),
      ),
    );
  }
}
