import 'package:flutter/material.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import '../models/subscription.dart';
import '../models/bill_model.dart';
import 'package:aboutme/core/event/event_manager.dart';

/// 订阅服务事件参数
class SubscriptionAddedEventArgs extends EventArgs {
  final Subscription subscription;
  SubscriptionAddedEventArgs(this.subscription) : super('subscription_added');
}

class SubscriptionUpdatedEventArgs extends EventArgs {
  final Subscription subscription;
  SubscriptionUpdatedEventArgs(this.subscription)
    : super('subscription_updated');
}

class SubscriptionTerminatedEventArgs extends EventArgs {
  final String subscriptionId;
  SubscriptionTerminatedEventArgs(this.subscriptionId)
    : super('subscription_terminated');
}

class SubscriptionDeletedEventArgs extends EventArgs {
  final String subscriptionId;
  SubscriptionDeletedEventArgs(this.subscriptionId)
    : super('subscription_deleted');
}

class SubscriptionController with ChangeNotifier {
  /// 订阅服务事件名称
  static const String subscriptionAddedEvent = 'subscription_added';
  static const String subscriptionUpdatedEvent = 'subscription_updated';
  static const String subscriptionTerminatedEvent = 'subscription_terminated';
  static const String subscriptionDeletedEvent = 'subscription_deleted';

  final List<Subscription> _subscriptions = [];

  List<Subscription> get subscriptions => List.unmodifiable(_subscriptions);

  /// 调用统一数据 SDK 的订阅命令（失败抛错；tolerateNotFound 时忽略 NOT_FOUND，
  /// 保持旧行为中对已不存在的订阅静默成功的语义）
  Future<void> _sdkCall(
    String action,
    Map<String, dynamic> params, {
    bool tolerateNotFound = false,
  }) async {
    final response = await AboutmeDataService.instance.data.call(
      'bill',
      action,
      params,
    );
    if (response['success'] != true &&
        !(tolerateNotFound && response['code'] == 'NOT_FOUND')) {
      throw '订阅服务操作失败: ${response['error']}';
    }
  }

  /// 加载订阅服务列表
  Future<void> loadSubscriptions() async {
    try {
      final response = await AboutmeDataService.instance.data.get(
        'bill',
        'getSubscriptions',
      );
      if (response['success'] != true) {
        debugPrint('加载订阅服务失败: ${response['error']}');
        return;
      }

      final subscriptionsJson = (response['data'] as Map)['data'] as List;
      _subscriptions.clear();
      for (final json in subscriptionsJson.whereType<Map<String, dynamic>>()) {
        try {
          _subscriptions.add(Subscription.fromJson(json));
        } catch (e) {
          // 单条损坏不阻断整体加载，避免一条坏数据清空订阅列表
          debugPrint('解析订阅数据失败（已跳过）: $e');
        }
      }
      debugPrint('[Sub] 加载完成: ${_subscriptions.length} 条订阅');

      notifyListeners();
    } catch (e) {
      debugPrint('加载订阅服务失败: $e');
    }
  }

  /// 创建订阅服务
  Future<void> createSubscription(Subscription subscription) async {
    await _sdkCall('createSubscription', subscription.toJson());
    _subscriptions.add(subscription);
    debugPrint(
      '[Sub] 创建成功: ${subscription.name}, '
      'start=${subscription.startDate}, days=${subscription.days}, '
      '当前订阅数=${_subscriptions.length}',
    );
    notifyListeners();

    // 广播事件
    EventManager.instance.broadcast(
      subscriptionAddedEvent,
      SubscriptionAddedEventArgs(subscription),
    );
  }

  /// 更新订阅服务
  Future<void> updateSubscription(Subscription subscription) async {
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (index != -1) {
      await _sdkCall('updateSubscription', subscription.toJson());
      _subscriptions[index] = subscription;
      notifyListeners();

      // 广播事件
      EventManager.instance.broadcast(
        subscriptionUpdatedEvent,
        SubscriptionUpdatedEventArgs(subscription),
      );
    }
  }

  /// 终止订阅服务
  Future<void> terminateSubscription(String subscriptionId) async {
    final subscription = _subscriptions.firstWhere(
      (s) => s.id == subscriptionId,
      orElse: () => throw Exception('订阅服务不存在'),
    );

    final updatedSubscription = subscription.copyWith(
      isActive: false,
      terminatedAt: DateTime.now(),
    );

    await _sdkCall(
      'updateSubscription',
      updatedSubscription.toJson(),
      tolerateNotFound: true,
    );

    final index = _subscriptions.indexOf(subscription);
    _subscriptions[index] = updatedSubscription;
    notifyListeners();

    // 广播事件
    EventManager.instance.broadcast(
      subscriptionTerminatedEvent,
      SubscriptionTerminatedEventArgs(subscriptionId),
    );
  }

  /// 删除订阅服务
  Future<void> deleteSubscription(String subscriptionId) async {
    await _sdkCall('deleteSubscription', {
      'id': subscriptionId,
    }, tolerateNotFound: true);
    _subscriptions.removeWhere((s) => s.id == subscriptionId);
    notifyListeners();

    // 广播事件
    EventManager.instance.broadcast(
      subscriptionDeletedEvent,
      SubscriptionDeletedEventArgs(subscriptionId),
    );
  }

  /// 获取活跃的订阅服务
  List<Subscription> getActiveSubscriptions() {
    return _subscriptions.where((s) => s.isActive).toList();
  }

  /// 返回指定日期应计费的订阅列表（订阅不再生成真实账单，
  /// 账单列表按天动态摊销展示）。
  ///
  /// 计费日 = [startDate, 最后计费日]，最后计费日取 endDate、
  /// startDate+days-1 两者的最早值；已终止的订阅再与终止日取更早者。
  /// 未来日期也按订阅有效期展示摊销。
  List<Subscription> subscriptionsForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return _subscriptions.where((s) {
      final start = DateTime(
        s.startDate.year,
        s.startDate.month,
        s.startDate.day,
      );
      if (day.isBefore(start)) return false;

      var last = start.add(Duration(days: s.days - 1));
      final endDate = s.endDate;
      if (endDate != null) {
        final endDay = DateTime(endDate.year, endDate.month, endDate.day);
        if (endDay.isBefore(last)) last = endDay;
      }
      final terminatedAt = s.terminatedAt;
      if (!s.isActive && terminatedAt != null) {
        final termDay = DateTime(
          terminatedAt.year,
          terminatedAt.month,
          terminatedAt.day,
        );
        if (termDay.isBefore(last)) last = termDay;
      }
      return !day.isAfter(last);
    }).toList();
  }

  /// 构建指定月份的订阅摊销虚拟条目（每天每个应计费订阅一条，
  /// 供账单列表/统计页展示，不落库）
  List<BillModel> subscriptionBillsForMonth(DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final result = <BillModel>[];

    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(month.year, month.month, d);
      for (final subscription in subscriptionsForDate(day)) {
        result.add(
          BillModel(
            id: 'sub_${subscription.id}_${day.year}${day.month}${day.day}',
            title: subscription.name,
            amount: subscription.dailyAmount,
            date: day,
            icon: subscription.icon,
            color: subscription.iconColor,
            category: subscription.category,
            isExpense: true,
            isSubscription: true,
          ),
        );
      }
    }
    debugPrint(
      '[Sub] 月度虚拟条目: ${month.year}-${month.month} '
      '生成${result.length}条 (订阅数=${_subscriptions.length})',
    );
    return result;
  }

  /// 根据ID查找订阅服务
  Subscription? findSubscriptionById(String id) {
    try {
      return _subscriptions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }
}
