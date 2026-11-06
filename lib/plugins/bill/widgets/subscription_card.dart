import 'package:flutter/material.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../models/subscription.dart';

/// 订阅周期文案（卡片/列表共用）
String subscriptionFrequencyText(int days) {
  if (days >= 360) return 'bill_yearly'.tr;
  if (days >= 28) return 'bill_monthly'.tr;
  if (days == 7) return 'bill_weekly'.tr;
  return '$days ${"bill_days".tr}';
}

/// 订阅卡片（网格视图）
class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isInactive;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    required this.onTap,
    required this.onLongPress,
    this.isInactive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final color = isInactive ? theme.disabled : subscription.iconColor;
    final frequency = subscriptionFrequencyText(subscription.days);
    final nextDate =
        subscription.isActive
            ? DateTime.now().add(Duration(days: subscription.remainingDays))
            : null;
    final resetDays = subscription.daysUntilMonthlyReset;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.stroke.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 背景装饰图标
            Positioned(
              right: -16,
              bottom: -16,
              child: Transform.rotate(
                angle: 0.2, // ~12 degrees
                child: Icon(
                  subscription.icon,
                  size: 96,
                  color: color.withOpacity(0.05),
                ),
              ),
            ),

            // 渐变遮罩
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.transparent, color.withOpacity(0.05)],
                ),
              ),
            ),

            // 内容
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 头部：图标 + 价格/周期
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              isInactive
                                  ? theme.disabled.withValues(alpha: 0.1)
                                  : color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(subscription.icon, color: color, size: 24),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              frequency,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '¥${subscription.totalAmount.toStringAsFixed(0)}',
                            style: DsTypography.body.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // 标题
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      subscription.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.heading.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // 底部：日期 + 进度
                  Column(
                    children: [
                      Divider(
                        height: 1,
                        color: theme.stroke.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      // 日期行 + 重置倒计时
                      Row(
                        children: [
                          if (nextDate != null) ...[
                            DsIcon(
                              DsIconKind.calendar,
                              size: 12,
                              color: theme.textSub,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${"bill_nextDate".tr} ${DateFormat('MMM d').format(nextDate)}',
                              style: DsTypography.caption.copyWith(
                                fontSize: 10,
                                color: theme.textSub,
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (resetDays != null && subscription.isActive)
                            buildResetBadge(context, resetDays),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 进度条行
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: theme.disabled.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: subscription.progress.clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${(subscription.progress * 100).toInt()}%',
                                  style: DsTypography.caption.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (subscription.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'bill_autoRenew'.tr,
                                style: DsTypography.caption.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: theme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 订阅列表项（列表视图）
class SubscriptionListTile extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isInactive;

  const SubscriptionListTile({
    super.key,
    required this.subscription,
    required this.onTap,
    required this.onLongPress,
    this.isInactive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final color = isInactive ? theme.disabled : subscription.iconColor;
    final frequency = subscriptionFrequencyText(subscription.days);
    final nextDate =
        subscription.isActive
            ? DateTime.now().add(Duration(days: subscription.remainingDays))
            : null;
    final resetDays = subscription.daysUntilMonthlyReset;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 128,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.stroke.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 背景装饰图标
            Positioned(
              right: -24,
              bottom: -24,
              child: Transform.rotate(
                angle: 0.2,
                child: Icon(
                  subscription.icon,
                  size: 160,
                  color: color.withOpacity(0.05),
                ),
              ),
            ),

            // 渐变遮罩
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, color.withOpacity(0.05)],
                ),
              ),
            ),

            // 内容
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // 图标
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color:
                          isInactive
                              ? theme.disabled.withValues(alpha: 0.1)
                              : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(subscription.icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),

                  // 信息列
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题行
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                subscription.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsTypography.heading.copyWith(
                                  color: theme.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // 价格 + 周期
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                '¥${subscription.totalAmount.toStringAsFixed(0)}',
                                style: DsTypography.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  frequency,
                                  style: DsTypography.caption.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // 底部：日期 + 重置倒计时 + 进度
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (nextDate != null) ...[
                              DsIcon(
                                DsIconKind.calendar,
                                size: 12,
                                color: theme.textSub,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${"bill_nextDate".tr} ${DateFormat('MMM d, yyyy').format(nextDate)}',
                                style: DsTypography.caption.copyWith(
                                  fontSize: 10,
                                  color: theme.textSub,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (resetDays != null && subscription.isActive) ...[
                              buildResetBadge(context, resetDays),
                              const SizedBox(width: 8),
                            ],

                            // 进度 + 自动续费角标
                            Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: theme.disabled.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                          ),
                                          child: FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: subscription.progress
                                                .clamp(0.0, 1.0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${(subscription.progress * 100).toInt()}%',
                                        style: DsTypography.caption.copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (subscription.isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'bill_autoRenew'.tr,
                                      style: DsTypography.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: theme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 每月重置倒计时角标（开启重置后显示）
Widget buildResetBadge(BuildContext context, int days) {
  final theme = DSThemeBridge.resolve(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: theme.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DsIcon(DsIconKind.refresh, size: 10, color: theme.warning),
        const SizedBox(width: 2),
        Text(
          'bill_resetInDays'.tr.replaceAll('{days}', days.toString()),
          style: DsTypography.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: theme.warning,
          ),
        ),
      ],
    ),
  );
}
