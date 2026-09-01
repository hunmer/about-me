import 'package:flutter/material.dart';
import 'package:aboutme_notifications/aboutme_notifications.dart';

import 'event/event.dart';

/// 通知控制器 - 使用 aboutme_notifications 插件
///
/// 这是对 aboutme_notifications 插件的薄封装层，
/// 保持与原有 API 的兼容性，同时添加业务特定的事件处理。
class NotificationController {
  /// 初始化通知服务
  static Future<void> initialize() async {
    await AboutmeNotifications.instance.initialize(
      channels: [
        const AboutmeNotificationChannel(
          key: 'basic_channel',
          name: 'Basic Notifications',
          description: 'Notification channel for basic tests',
          groupKey: 'basic_channel_group',
          defaultColor: Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: AboutmeNotificationImportance.high,
        ),
        const AboutmeNotificationChannel(
          key: 'custom_channel',
          name: 'Custom Notifications',
          description: 'Notification channel for custom notifications',
          groupKey: 'custom_channel_group',
          defaultColor: Color(0xFF2196F3),
          ledColor: Colors.blue,
          importance: AboutmeNotificationImportance.max,
          playSound: true,
          enableVibration: true,
        ),
      ],
      channelGroups: const [
        AboutmeNotificationChannelGroup(
          key: 'basic_channel_group',
          name: 'Basic Group',
        ),
        AboutmeNotificationChannelGroup(
          key: 'custom_channel_group',
          name: 'Custom Group',
        ),
      ],
      debug: true,
    );

    // 设置事件监听器
    AboutmeNotifications.instance.setListeners(
      AboutmeNotificationListeners(
        onCreated: _onNotificationCreatedMethod,
        onDisplayed: _onNotificationDisplayedMethod,
        onDismissed: _onDismissActionReceivedMethod,
        onAction: _onActionReceivedMethod,
      ),
    );
  }

  /// 请求通知权限
  static Future<bool> requestPermission() async {
    return await AboutmeNotifications.instance.requestPermission();
  }

  /// 检查通知权限
  static Future<bool> checkPermission() async {
    return await AboutmeNotifications.instance.checkPermission();
  }

  /// 当通知被创建时调用
  static Future<void> _onNotificationCreatedMethod(
    AboutmeReceivedNotification receivedNotification,
  ) async {
    debugPrint(
      '通知已创建: ID=${receivedNotification.id}, Title=${receivedNotification.title}',
    );
  }

  /// 当通知被显示时调用
  static Future<void> _onNotificationDisplayedMethod(
    AboutmeReceivedNotification receivedNotification,
  ) async {
    debugPrint(
      '通知已显示: ID=${receivedNotification.id}, Title=${receivedNotification.title}',
    );
  }

  /// 当通知被关闭时调用
  static Future<void> _onDismissActionReceivedMethod(
    AboutmeReceivedAction receivedAction,
  ) async {
    debugPrint(
      '通知已关闭: ID=${receivedAction.id}',
    );
  }

  /// 当用户点击通知或通知按钮时调用
  static Future<void> _onActionReceivedMethod(
    AboutmeReceivedAction receivedAction,
  ) async {
    debugPrint(
      '通知动作接收: ID=${receivedAction.id}, ButtonKey=${receivedAction.buttonKeyPressed}',
    );

    // 检查是否是活动通知
    if (receivedAction.payload?['type'] == 'activity_reminder') {
      await _handleActivityNotificationAction(receivedAction);
      return;
    }

    // 根据按钮 key 处理不同的逻辑
    if (receivedAction.buttonKeyPressed == 'YES') {
      debugPrint('用户点击了 YES 按钮');
    } else if (receivedAction.buttonKeyPressed == 'NO') {
      debugPrint('用户点击了 NO 按钮');
    } else if (receivedAction.buttonKeyPressed == 'MORE') {
      debugPrint('用户点击了 MORE 按钮');
    } else {
      // 点击通知本身(没有按钮)
      debugPrint('用户点击了通知本体');
    }
  }

  /// 创建基础通知
  static Future<void> createBasicNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await AboutmeNotifications.instance.showNotification(
      id: id,
      title: title,
      body: body,
      channelKey: 'basic_channel',
      layout: AboutmeNotificationLayout.basic,
    );
  }

  /// 创建带按钮的自定义通知
  static Future<void> createCustomNotification({
    required int id,
    required String title,
    required String body,
    String? bigPicture,
    String? largeIcon,
    AboutmeNotificationLayout layout = AboutmeNotificationLayout.basic,
    List<AboutmeNotificationButton>? actionButtons,
  }) async {
    await AboutmeNotifications.instance.showNotification(
      id: id,
      title: title,
      body: body,
      channelKey: 'custom_channel',
      layout: layout,
      bigPicture: bigPicture,
      largeIcon: largeIcon,
      buttons: actionButtons,
    );
  }

  /// 创建带大图的通知
  static Future<void> createBigPictureNotification({
    required int id,
    required String title,
    required String body,
    required String bigPicture,
  }) async {
    await AboutmeNotifications.instance.showNotification(
      id: id,
      title: title,
      body: body,
      channelKey: 'custom_channel',
      layout: AboutmeNotificationLayout.bigPicture,
      bigPicture: bigPicture,
      buttons: const [
        AboutmeNotificationButton(
          key: 'YES',
          label: 'Yes',
          actionType: AboutmeButtonActionType.defaultAction,
          color: Colors.green,
        ),
        AboutmeNotificationButton(
          key: 'NO',
          label: 'No',
          actionType: AboutmeButtonActionType.defaultAction,
          color: Colors.red,
        ),
        AboutmeNotificationButton(
          key: 'MORE',
          label: 'More Options',
          actionType: AboutmeButtonActionType.defaultAction,
        ),
      ],
    );
  }

  /// 取消指定 ID 的通知
  static Future<void> cancelNotification(int id) async {
    await AboutmeNotifications.instance.cancel(id);
  }

  /// 取消所有通知
  static Future<void> cancelAllNotifications() async {
    await AboutmeNotifications.instance.cancelAll();
  }

  /// 获取活动通知列表
  static Future<List<AboutmeScheduledNotification>> getActiveNotifications() async {
    return await AboutmeNotifications.instance.getScheduledNotifications();
  }

  /// 处理活动通知的动作
  static Future<void> _handleActivityNotificationAction(
    AboutmeReceivedAction receivedAction,
  ) async {
    debugPrint(
      '活动通知动作接收: ID=${receivedAction.id}, ButtonKey=${receivedAction.buttonKeyPressed}',
    );

    if (receivedAction.buttonKeyPressed == 'open_form') {
      // 打开活动表单
      debugPrint('用户点击了"记录活动"按钮');
      _broadcastOpenActivityForm();
    } else if (receivedAction.buttonKeyPressed == 'dismiss') {
      // 忽略通知
      debugPrint('用户点击了"忽略"按钮');
    } else {
      // 点击通知本体
      debugPrint('用户点击了活动通知本体');
      _broadcastOpenActivityForm();
    }
  }

  /// 广播打开活动表单事件
  static void _broadcastOpenActivityForm() {
    try {
      debugPrint('[NotificationController] 广播打开活动表单事件');

      // 使用全局事件管理器广播事件
      eventManager.broadcast('activity_notification_tapped', EventArgs('activity_notification_tapped'));

      debugPrint('[NotificationController] 事件广播成功: activity_notification_tapped');
    } catch (e) {
      debugPrint('[NotificationController] 广播事件失败: $e');
    }
  }
}
