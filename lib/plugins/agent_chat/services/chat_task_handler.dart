import 'dart:async';

import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

@pragma('vm:entry-point')
void startAIChatTaskCallback() {
  FlutterForegroundTask.setTaskHandler(AIChatTaskHandler());
}

/// Android handler 只跟踪任务进度和转发取消；完成通知由主 isolate await。
class AIChatTaskHandler extends TaskHandler {
  AIChatTaskHandler({
    void Function(Object)? sendToMain,
    Future<void> Function(String title, String text)? updateNotification,
  }) : _sendToMain = sendToMain ?? FlutterForegroundTask.sendDataToMain,
       _updateNotification = updateNotification ?? _updateService;

  final void Function(Object) _sendToMain;
  final Future<void> Function(String title, String text) _updateNotification;
  final String sessionId = const Uuid().v4();
  final Map<String, String> _tasks = {};
  final Set<String> _cancelRequested = {};
  bool _ready = false;
  Future<void> _updates = Future<void>.value();

  int get activeTaskCount => _tasks.length;

  static Future<void> _updateService(String title, String text) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _ready = true;
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map || !_ready) return;
    if (data['action'] == 'chat_service_probe') {
      _sendToMain({
        'event': 'chat_service_ready',
        'owner': 'chat',
        'sessionId': sessionId,
        'requestId': data['requestId'],
      });
      return;
    }
    if (data['sessionId'] != sessionId) return;
    final taskId = data['taskId'];
    final conversationId = data['conversationId'];
    if (taskId is! String || conversationId is! String) return;
    switch (data['action']) {
      case 'start_generation':
        // 同一 taskId 重放幂等，不允许跨会话覆盖。
        if (_tasks.containsKey(taskId) && _tasks[taskId] != conversationId) {
          return;
        }
        _tasks[taskId] = conversationId;
        _refresh();
        break;
      case 'finish_generation':
        if (_tasks[taskId] != conversationId) return;
        _tasks.remove(taskId);
        _cancelRequested.remove(taskId);
        _refresh();
        break;
      case 'generation_progress':
        if (_tasks[taskId] != conversationId || data['progress'] is! String) {
          return;
        }
        _enqueueUpdate(
          'AI 助手运行中 (${_tasks.length})',
          data['progress'] as String,
        );
        break;
    }
  }

  void _refresh() {
    _enqueueUpdate(
      'AI 助手运行中',
      _tasks.isEmpty ? '正在结束后台任务...' : '正在生成回复（${_tasks.length} 个任务）',
    );
  }

  void _enqueueUpdate(String title, String text) {
    _updates = _updates.then((_) async {
      if (!_ready) return;
      try {
        await _updateNotification(title, text);
      } catch (error) {
        debugPrint('[AIChatTaskHandler] 更新进度通知失败: $error');
      }
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id != 'cancel') return;
    for (final task in _tasks.entries) {
      if (!_cancelRequested.add(task.key)) continue;
      _sendToMain({
        'event': 'cancel_generation',
        'sessionId': sessionId,
        'taskId': task.key,
        'conversationId': task.value,
      });
    }
    // 等主 isolate 的 finish 确认后才移除，避免在取消清理完成前丢失任务。
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp('/chat');

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _ready = false;
    await _updates;
    _tasks.clear();
    _cancelRequested.clear();
  }
}
