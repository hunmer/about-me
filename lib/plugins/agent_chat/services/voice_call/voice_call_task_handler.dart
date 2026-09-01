import 'package:flutter/material.dart';
import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';

/// 语音通话前台服务任务处理器
///
/// 用于处理语音通话时的后台运行、通知更新和按钮事件
class VoiceCallTaskHandler extends TaskHandler {
  // 用于更新通知的回调
  static String notificationTitle = 'AI 语音通话';
  static String notificationText = '正在通话中...';
  static List<String> notificationButtons = ['暂停', '结束'];

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // 服务启动时的初始化
    debugPrint('🚀 语音通话前台服务已启动');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 定期任务（每秒执行一次）
    // 可以在这里更新通知内容
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // 服务销毁时的清理
    debugPrint('🗑️ 语音通话前台服务已销毁');
  }

  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('🔔 通知按钮被点击: $id');

    // 发送事件到主应用
    switch (id) {
      case 'pause': // 暂停按钮
        FlutterForegroundTask.sendDataToMain({'event': 'pause_call'});
        break;
      case 'resume': // 继续按钮
        FlutterForegroundTask.sendDataToMain({'event': 'resume_call'});
        break;
      case 'skip': // 跳过按钮
        FlutterForegroundTask.sendDataToMain({'event': 'skip_call'});
        break;
      case 'end': // 结束按钮
        FlutterForegroundTask.sendDataToMain({'event': 'end_call'});
        break;
    }
  }

  @override
  void onReceiveData(Object data) {
    // 接收来自主应用的数据，用于更新通知等
    if (data is Map<String, dynamic>) {
      final action = data['action'];

      switch (action) {
        case 'update_notification':
          // 更新通知内容
          notificationTitle = data['title'] ?? notificationTitle;
          notificationText = data['content'] ?? notificationText;

          // 更新按钮
          if (data['buttons'] != null) {
            notificationButtons = List<String>.from(data['buttons'] ?? []);
          }

          // 更新通知
          FlutterForegroundTask.updateService(
            notificationTitle: notificationTitle,
            notificationText: notificationText,
            notificationButtons: _buildNotificationButtons(),
          );
          break;

        case 'update_state':
          // 根据状态更新通知
          final state = data['state'];
          _updateNotificationForState(state);
          break;
      }
    }
  }

  /// 根据状态更新通知
  void _updateNotificationForState(String state) {
    switch (state) {
      case 'recording':
        notificationText = '请开始说话...';
        notificationButtons = ['暂停', '结束'];
        break;
      case 'processing':
        notificationText = 'AI正在思考...';
        notificationButtons = ['结束'];
        break;
      case 'speaking':
        notificationText = 'AI正在回复...';
        notificationButtons = ['跳过', '结束'];
        break;
      case 'paused':
        notificationText = '已暂停';
        notificationButtons = ['继续', '结束'];
        break;
      default:
        notificationText = '正在通话中...';
        notificationButtons = ['结束'];
    }

    FlutterForegroundTask.updateService(
      notificationTitle: notificationTitle,
      notificationText: notificationText,
      notificationButtons: _buildNotificationButtons(),
    );
  }

  /// 按钮标签到事件 id 的映射
  static const Map<String, String> _buttonIdMap = {
    '暂停': 'pause',
    '继续': 'resume',
    '跳过': 'skip',
    '结束': 'end',
  };

  /// 构建通知按钮
  List<NotificationButton> _buildNotificationButtons() {
    return notificationButtons.map((label) {
      return NotificationButton(
        id: _buttonIdMap[label] ?? label,
        text: label,
      );
    }).toList();
  }
}

/// 语音通话前台服务启动回调
///
/// 在顶层函数中定义，用于前台服务启动
@pragma('vm:entry-point')
void startVoiceCallTaskCallback() {
  FlutterForegroundTask.setTaskHandler(VoiceCallTaskHandler());
}
