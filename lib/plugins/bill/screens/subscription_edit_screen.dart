import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/widgets/form_fields/index.dart';
import '../models/subscription.dart';
import '../bill_plugin.dart';

class SubscriptionEditScreen extends StatefulWidget {
  final BillPlugin billPlugin;
  final Subscription? subscription;

  const SubscriptionEditScreen({
    super.key,
    required this.billPlugin,
    this.subscription,
  });

  @override
  State<SubscriptionEditScreen> createState() => _SubscriptionEditScreenState();
}

class _SubscriptionEditScreenState extends State<SubscriptionEditScreen> {
  /// 表单 wrapper 状态（onStateReady 回传），供 AppBar 保存按钮触发提交
  FormBuilderWrapperState? _formWrapperState;

  @override
  void initState() {
    super.initState();

    // 设置路由上下文
    if (widget.subscription != null) {
      _updateRouteContext(
        isEdit: true,
        subscriptionId: widget.subscription!.id,
      );
    } else {
      _updateRouteContext(isEdit: false);
    }
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前状态
  void _updateRouteContext({required bool isEdit, String? subscriptionId}) {
    if (isEdit && subscriptionId != null) {
      RouteHistoryManager.updateCurrentContext(
        pageId: '/bill_subscription_edit',
        title: '编辑订阅',
        params: {'subscriptionId': subscriptionId},
      );
    } else {
      RouteHistoryManager.updateCurrentContext(
        pageId: '/bill_subscription_create',
        title: '新建订阅',
        params: {},
      );
    }
  }

  Future<void> _saveSubscription(Map<String, dynamic> values) async {
    try {
      // 从表单值中提取数据
      final iconData = values['iconData'] as Map<String, dynamic>?;
      final icon = iconData?['icon'] as IconData? ?? Icons.subscriptions;
      final iconColor = iconData?['color'] as Color? ?? Colors.blue;

      final subscription = Subscription(
        id: widget.subscription?.id,
        name: values['name'] as String,
        totalAmount: double.parse(values['totalAmount'].toString()),
        days: values['days'] as int,
        category: '订阅',
        startDate: values['startDate'] as DateTime,
        endDate: values['endDate'] as DateTime?,
        note:
            (values['note'] as String?)?.isEmpty == true
                ? null
                : values['note'] as String?,
        icon: icon,
        iconColor: iconColor,
        isActive: values['isActive'] as bool,
      );

      // 验证天数
      if (subscription.days <= 0) {
        Toast.error('bill_subscriptionDaysError'.tr);
        return;
      }

      if (widget.subscription == null) {
        await widget.billPlugin.controller.subscriptions.createSubscription(
          subscription,
        );
        Toast.success('bill_subscriptionCreated'.tr);
      } else {
        await widget.billPlugin.controller.subscriptions.updateSubscription(
          subscription,
        );
        Toast.success('bill_subscriptionUpdated'.tr);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      Toast.error('bill_saveFailed'.tr);
    }
  }

  Future<void> _deleteSubscription() async {
    if (widget.subscription == null) return;

    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'bill_deleteSubscription'.tr,
                    message: 'bill_deleteConfirm'.tr.replaceAll(
                      '{name}',
                      widget.subscription!.name,
                    ),
                    cancelText: 'bill_cancel'.tr,
                    confirmText: 'bill_delete'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onCancel: () => Navigator.pop(context, false),
                    onConfirm: () => Navigator.pop(context, true),
                  ),
            ),
          ),
    );

    if (confirm == true) {
      await widget.billPlugin.controller.subscriptions.deleteSubscription(
        widget.subscription!.id,
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscription;
    final theme = DSThemeBridge.resolve(context);

    return Scaffold(
      backgroundColor: dsTransparentWhenGlobalBackground(theme.surface),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: DSThemeBridge(
            child: DSButton(
              label: 'bill_cancel'.tr,
              variant: DSButtonVariant.ghost,
              size: DSButtonSize.sm,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        leadingWidth: 80,
        title: Text(
          sub == null ? 'bill_addSubscription'.tr : 'bill_editSubscription'.tr,
          style: DsTypography.title.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: theme.text,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DSThemeBridge(
              child: DSIconButton(
                icon: DsIconKind.save,
                size: 38,
                tooltip: 'bill_save'.tr,
                onPressed: () => _formWrapperState?.submitForm(),
              ),
            ),
          ),
        ],
      ),
      body: FormBuilderWrapper(
        onStateReady: (state) => _formWrapperState = state,
        buttonBuilder: (context, onSubmit, onReset) {
          // 自定义按钮区域：保存按钮在 AppBar，底部显示删除按钮
          return Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return Column(
                children: [
                  if (widget.subscription != null) ...[
                    const SizedBox(height: 24),
                    Pressable(
                      onPressed: _deleteSubscription,
                      builder: (context, states) {
                        final pressed = states.contains(WidgetState.pressed);
                        return Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color:
                                pressed
                                    ? theme.danger.withValues(alpha: 0.15)
                                    : theme.surfaceAlt,
                            borderRadius: theme.radii.lg,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'bill_deleteSubscription'.tr,
                            style: DsTypography.button.copyWith(
                              color: theme.danger,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
        contentBuilder: (context, fields) {
          // 自定义布局：保存按钮在 AppBar
          // Expanded：FormBuilderWrapper 会把本回调结果放进 Column，
          // 直接返回 ListView 会拿到无界高度约束而崩溃
          return Expanded(
            child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // 图标选择器（居中）
              fields[0],
              const SizedBox(height: 24),

              // 名称和价格组
              FormFieldGroup(
                showBackground: false,
                children: [
                  fields[1], // 名称
                  fields[2], // 价格
                ],
              ),
              const SizedBox(height: 24),

              // 时间组
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fields[3], // 开始日期
                    const SizedBox(height: 12),
                    fields[4], // 结束日期
                    const SizedBox(height: 16),

                    // 周期按钮
                    fields[5], // 订阅周期
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 自动订阅开关
              FormFieldGroup(
                showBackground: false,
                showDividers: false,
                children: [
                  fields[6], // isActive
                ],
              ),
              const SizedBox(height: 24),

              // 备注
              FormFieldGroup(
                showBackground: false,
                showDividers: false,
                children: [
                  fields[7], // 备注
                ],
              ),
            ],
            ),
          );
        },
        config: FormConfig(
          showSubmitButton: false, // 不显示默认提交按钮
          fieldSpacing: 0, // 使用自定义间距
          fields: [
            // 图标和颜色选择器
            FormFieldConfig(
              name: 'iconData',
              type: FormFieldType.circleIconPicker,
              initialValue: {
                'icon': sub?.icon ?? Icons.subscriptions,
                'color': sub?.iconColor ?? Colors.blue,
              },
              extra: {'showLabel': true, 'labelText': 'bill_chooseIcon'.tr},
            ),

            // 名称
            FormFieldConfig(
              name: 'name',
              type: FormFieldType.text,
              labelText: 'bill_subscriptionName'.tr,
              hintText: 'Netflix',
              initialValue: sub?.name ?? '',
              required: true,
              validationMessage: 'bill_requiredField'.tr,
              extra: {'inline': true},
            ),

            // 价格
            FormFieldConfig(
              name: 'totalAmount',
              type: FormFieldType.number,
              labelText: 'bill_subscriptionPrice'.tr,
              hintText: '0.00',
              // 新建时不预填 0.0，避免输入框带着清不掉的 "0." 前缀
              initialValue: sub?.totalAmount,
              required: true,
              validationMessage: 'bill_requiredField'.tr,
              extra: {'inline': true, 'suffix': '¥'},
            ),

            // 开始日期
            FormFieldConfig(
              name: 'startDate',
              type: FormFieldType.date,
              labelText: 'bill_startDate'.tr,
              initialValue: sub?.startDate ?? DateTime.now(),
              extra: {
                'inline': true,
                'format': 'yyyy-MM-dd',
                'firstDate': DateTime(2000),
                'lastDate': DateTime(2100),
              },
            ),

            // 结束日期
            FormFieldConfig(
              name: 'endDate',
              type: FormFieldType.date,
              labelText: 'bill_endDate'.tr,
              hintText: 'bill_none'.tr,
              initialValue: sub?.endDate,
              extra: {
                'inline': true,
                'format': 'yyyy-MM-dd',
                'firstDate': sub?.startDate ?? DateTime.now(),
                'lastDate': DateTime(2100),
              },
            ),

            // 订阅周期
            FormFieldConfig(
              name: 'days',
              type: FormFieldType.subscriptionCycle,
              initialValue: sub?.days ?? 30,
              extra: {
                'monthlyLabel': 'bill_monthly'.tr,
                'quarterlyLabel': 'bill_quarterly'.tr,
                'yearlyLabel': 'bill_yearly'.tr,
              },
            ),

            // 自动订阅开关
            FormFieldConfig(
              name: 'isActive',
              type: FormFieldType.switchField,
              labelText: 'bill_autoSubscribe'.tr,
              hintText: 'bill_autoSubscribeDesc'.tr,
              initialValue: sub?.isActive ?? true,
              extra: {'inline': true},
            ),

            // 备注
            FormFieldConfig(
              name: 'note',
              type: FormFieldType.textArea,
              labelText: 'bill_notes'.tr,
              hintText: 'bill_notesHint'.tr,
              initialValue: sub?.note ?? '',
              extra: {'inline': true, 'maxLines': 4},
            ),
          ],
          onSubmit: _saveSubscription,
        ),
      ),
    );
  }
}
