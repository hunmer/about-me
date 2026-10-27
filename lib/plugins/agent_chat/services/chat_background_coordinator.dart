import 'dart:async';

import 'package:aboutme/core/notification_controller.dart';
import 'package:aboutme/core/services/foreground_task_manager.dart';
import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:universal_platform/universal_platform.dart';

import '../../openai/aliveness/services/keepalive_service.dart';
import 'chat_task_handler.dart';

/// 平台边界。协调器本身不依赖控制器，也不调用 iOS 常驻服务；
/// iOS finite background 的获取/释放可由控制器在 start/finish 外围接入。
abstract class ChatBackgroundPlatform {
  bool get supportsForegroundService;
  bool get supportsNotifications;
  bool get isAppResumed;
  Future<bool> isServiceRunning();
  Future<bool> startChatService();
  Future<bool> startKeepAliveService();
  Future<bool> stopService();
  void addDataCallback(void Function(Object) callback);
  void removeDataCallback(void Function(Object) callback);
  void sendData(Object data);
  Future<void> initializeNotifications();
  Future<void> showNotification(int id, String title, String body);
}

/// 主 isolate 共享协调状态：所有控制器及活人感保活共用同一串行队列。
class ChatBackgroundCoordinator {
  ChatBackgroundCoordinator(
    this.platform, {
    this.readyTimeout = const Duration(seconds: 3),
    this.probeInterval = const Duration(milliseconds: 100),
  });

  static final instance = ChatBackgroundCoordinator(
    _NativeChatBackgroundPlatform(),
  );
  final ChatBackgroundPlatform platform;
  final Duration readyTimeout;
  final Duration probeInterval;
  Future<void> _queue = Future<void>.value();
  final Map<String, _ChatTask> _tasks = {};
  // Set 保持插入顺序，仅保留最近 1000 个完成任务的去重记录。
  static const _finishedLimit = 1000;
  final Set<String> _finished = {};
  final Map<String, _CompletionNotification> _pendingNotifications = {};
  final Map<String, void Function(String)> _cancelListeners = {};
  Future<void>? _notificationInitialization;
  String? _owner;
  String? _sessionId;
  bool _keepAliveEnabled = false;
  bool _listening = false;
  int _probeId = 0;
  int _notificationId = DateTime.now().millisecondsSinceEpoch % 0x3fffffff;
  Completer<Map>? _probe;
  String? _probeRequest;

  int get activeTaskCount => _tasks.length;
  int get pendingNotificationCount => _pendingNotifications.length;

  void addCancelListener(String key, void Function(String) listener) {
    _cancelListeners[key] = listener;
  }

  void removeCancelListener(String key) => _cancelListeners.remove(key);

  Future<void> _serial(Future<void> Function() operation) {
    final result = _queue.then((_) async {
      try {
        await operation();
      } catch (error, stack) {
        debugPrint('[ChatBackground] $error\n$stack');
      }
    });
    _queue = result;
    return result;
  }

  Future<void> startTask(
    String conversationId,
    String taskId, {
    bool enableBackgroundService = true,
    bool showToken = true,
  }) => _serial(() async {
    if (_finished.contains(taskId) ||
        _pendingNotifications.containsKey(taskId)) {
      return;
    }
    final existing = _tasks[taskId];
    if (existing != null && existing.conversationId != conversationId) {
      throw StateError('taskId 已属于其他会话');
    }
    _tasks.putIfAbsent(
      taskId,
      () => _ChatTask(conversationId, showToken, enableBackgroundService),
    );
    if (!enableBackgroundService || !platform.supportsForegroundService) return;
    _ensureListening();
    if (_owner == 'keepalive') {
      if (!await _stopOwnedService()) return;
    }
    if (_owner == 'chat') {
      if (await _verifyOwner()) {
        _sendTask(taskId);
        return;
      }
    }
    // 运行中的无主服务绝不抢占，也不发送任何聊天数据。
    if (await platform.isServiceRunning()) return;
    if (!await platform.startChatService()) return;
    final ready = await _probeOwner('chat');
    if (ready == null) return;
    _owner = 'chat';
    _sessionId = ready['sessionId'] as String;
    // handler 已 ready，重放仍活跃任务，覆盖服务意外重启的情况。
    for (final entry in _tasks.entries) {
      if (entry.value.backgroundEnabled) _sendTask(entry.key);
    }
  });

  Future<void> finishTask(
    String taskId, {
    String content = '',
    int? tokenCount,
    String? messageId,
    String? error,
    bool cancelled = false,
  }) => _serial(() async {
    if (_pendingNotifications.containsKey(taskId) || !_finished.add(taskId)) {
      return;
    }
    if (_finished.length > _finishedLimit) _finished.remove(_finished.first);
    final task = _tasks[taskId];
    try {
      // 仅将生命周期信息发给已确认属于我们的 handler，正文留在主 isolate。
      if (_owner == 'chat' && await _verifyOwner()) {
        platform.sendData({
          'action': 'finish_generation',
          'sessionId': _sessionId,
          'taskId': taskId,
          'conversationId': task?.conversationId,
        });
      }
    } catch (failure) {
      debugPrint('[ChatBackground] 完成进度同步失败: $failure');
    }
    // 服务关闭、启动失败、后台开关关闭均不影响独立通知。
    if (!cancelled &&
        platform.supportsNotifications &&
        !platform.isAppResumed) {
      final preview = content.length > 50
          ? '${content.substring(0, 50)}...'
          : content;
      var body = error ?? (preview.isEmpty ? '点击查看完整回复' : preview);
      if (error == null && (task?.showToken ?? true) && (tokenCount ?? 0) > 0) {
        final count = tokenCount! >= 1000
            ? '${(tokenCount / 1000).toStringAsFixed(1)}K'
            : '$tokenCount';
        body = '$body\n$count tokens';
      }
      _pendingNotifications[taskId] = _CompletionNotification(
        ++_notificationId,
        error == null ? 'AI回复完成' : 'AI回复失败',
        body,
      );
      await _deliverNotification(taskId);
    }
    _tasks.remove(taskId);
    await _stopIfIdle();
  });

  /// 只重试之前后台产生但发送失败的通知；不会补发前台完成的任务。
  Future<void> retryPendingNotifications() => _serial(() async {
    for (final taskId in _pendingNotifications.keys.toList()) {
      await _deliverNotification(taskId);
    }
  });

  Future<void> _deliverNotification(String taskId) async {
    final notification = _pendingNotifications[taskId];
    if (notification == null) return;
    try {
      await (_notificationInitialization ??= platform
          .initializeNotifications());
      await platform.showNotification(
        notification.id,
        notification.title,
        notification.body,
      );
      _pendingNotifications.remove(taskId);
    } catch (error) {
      // 初始化失败也允许下次重试；相同任务沿用 notification ID，避免重复弹出。
      _notificationInitialization = null;
      debugPrint('[ChatBackground] 通知失败，保留待重试任务 $taskId: $error');
    }
  }

  Future<void> notifyProgress(String taskId, String progress) =>
      _serial(() async {
        final task = _tasks[taskId];
        if (task == null || _owner != 'chat' || !await _verifyOwner()) return;
        platform.sendData({
          'action': 'generation_progress',
          'sessionId': _sessionId,
          'taskId': taskId,
          'conversationId': task.conversationId,
          'progress': progress,
        });
      });

  Future<void> stopServiceIfIdle() => _serial(_stopIfIdle);

  Future<void> _stopIfIdle() async {
    if (_tasks.isNotEmpty || !platform.supportsForegroundService) return;
    if (_owner == 'chat' && !await _stopOwnedService()) return;
    await _restoreKeepAlive();
    if (_owner == null) _releaseListening();
  }

  Future<void> setKeepAliveEnabled(bool enabled) => _serial(() async {
    _keepAliveEnabled = enabled;
    if (!platform.supportsForegroundService) return;
    if (!enabled && _owner == 'keepalive') await _stopOwnedService();
    if (enabled) await _restoreKeepAlive();
    if (_owner == null && _tasks.isEmpty) _releaseListening();
  });

  Future<void> _restoreKeepAlive() async {
    if (!_keepAliveEnabled ||
        _tasks.isNotEmpty ||
        _owner != null ||
        await platform.isServiceRunning()) {
      return;
    }
    _ensureListening();
    if (!await platform.startKeepAliveService()) return;
    final ready = await _probeOwner('keepalive');
    if (ready != null) {
      _owner = 'keepalive';
      _sessionId = ready['sessionId'] as String;
    }
  }

  Future<bool> _stopOwnedService() async {
    if (!await _verifyOwner()) return !await platform.isServiceRunning();
    if (!await platform.stopService()) return false;
    _owner = null;
    _sessionId = null;
    return true;
  }

  Future<bool> _verifyOwner() async {
    if (!await platform.isServiceRunning()) {
      _owner = null;
      _sessionId = null;
      return false;
    }
    final ready = await _probeOwner(_owner!);
    if (ready == null || ready['sessionId'] != _sessionId) {
      _owner = null;
      _sessionId = null;
      return false;
    }
    return true;
  }

  // 仅发无业务数据的探针。重复探测覆盖 onStart/通信端口尚未就绪的窗口。
  Future<Map?> _probeOwner(String expectedOwner) async {
    final completer = Completer<Map>();
    final requestId = '${++_probeId}';
    _probe = completer;
    _probeRequest = requestId;
    void sendProbe() => platform.sendData({
      'action': 'chat_service_probe',
      'requestId': requestId,
    });
    Timer? timer;
    try {
      sendProbe();
      timer = Timer.periodic(probeInterval, (_) {
        try {
          sendProbe();
        } catch (error) {
          if (!completer.isCompleted) completer.completeError(error);
        }
      });
      final result = await completer.future.timeout(readyTimeout);
      return result['owner'] == expectedOwner && result['sessionId'] is String
          ? result
          : null;
    } on TimeoutException {
      debugPrint('[ChatBackground] handler ready 握手超时: $expectedOwner');
      return null;
    } finally {
      timer?.cancel();
      _probe = null;
      _probeRequest = null;
    }
  }

  void _ensureListening() {
    if (_listening) return;
    platform.addDataCallback(_onData);
    _listening = true;
  }

  void _releaseListening() {
    if (!_listening) return;
    platform.removeDataCallback(_onData);
    _listening = false;
  }

  void _onData(Object data) {
    if (data is! Map) return;
    if (data['event'] == 'chat_service_ready' &&
        data['requestId'] == _probeRequest) {
      final probe = _probe;
      if (probe != null && !probe.isCompleted) probe.complete(data);
      return;
    }
    if (data['event'] != 'cancel_generation' ||
        _owner != 'chat' ||
        data['sessionId'] != _sessionId) {
      return;
    }
    final taskId = data['taskId'];
    final task = _tasks[taskId];
    if (task == null || data['conversationId'] != task.conversationId) return;
    for (final listener in _cancelListeners.values.toList()) {
      try {
        listener(taskId as String);
      } catch (error) {
        debugPrint('[ChatBackground] 取消回调失败: $error');
      }
    }
  }

  void _sendTask(String taskId) {
    final task = _tasks[taskId]!;
    platform.sendData({
      'action': 'start_generation',
      'sessionId': _sessionId,
      'taskId': taskId,
      'conversationId': task.conversationId,
    });
  }
}

class _ChatTask {
  const _ChatTask(this.conversationId, this.showToken, this.backgroundEnabled);
  final String conversationId;
  final bool showToken;
  final bool backgroundEnabled;
}

class _CompletionNotification {
  const _CompletionNotification(this.id, this.title, this.body);
  final int id;
  final String title;
  final String body;
}

class _NativeChatBackgroundPlatform implements ChatBackgroundPlatform {
  ForegroundTaskManager get _manager => ForegroundTaskManager();
  @override
  bool get supportsForegroundService => !kIsWeb && UniversalPlatform.isAndroid;
  @override
  bool get supportsNotifications =>
      !kIsWeb && (UniversalPlatform.isAndroid || UniversalPlatform.isIOS);
  @override
  bool get isAppResumed =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  @override
  Future<bool> isServiceRunning() => _manager.isServiceRunning();
  @override
  Future<bool> startChatService() async => (await _manager.startService(
    serviceId: 257,
    notificationTitle: 'AI 助手运行中',
    notificationText: '正在为您生成回复...',
    notificationButtons: [
      const ServiceNotificationButton(key: 'cancel', label: '取消'),
    ],
    notificationInitialRoute: '/chat',
    callback: startAIChatTaskCallback,
  )).success;
  @override
  Future<bool> startKeepAliveService() async => (await _manager.startService(
    serviceId: AlivenessKeepAliveService.serviceId,
    notificationTitle: 'AI 陪伴守护中',
    notificationText: '你的伙伴还在这里，想念时会主动找你',
    notificationInitialRoute: '/chat',
    callback: startAlivenessKeepAliveCallback,
  )).success;
  @override
  Future<bool> stopService() async => (await _manager.stopService()).success;
  @override
  void addDataCallback(void Function(Object) callback) =>
      _manager.addDataCallback(callback);
  @override
  void removeDataCallback(void Function(Object) callback) =>
      _manager.removeDataCallback(callback);
  @override
  void sendData(Object data) => FlutterForegroundTask.sendDataToTask(data);
  @override
  Future<void> initializeNotifications() => NotificationController.initialize();
  @override
  Future<void> showNotification(int id, String title, String body) =>
      NotificationController.createBasicNotification(
        id: id,
        title: title,
        body: body,
      );
}
