import 'dart:async';

import 'package:aboutme/plugins/agent_chat/services/chat_background_coordinator.dart';
import 'package:aboutme/plugins/agent_chat/services/chat_task_handler.dart';
import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';
import 'package:aboutme_notifications/aboutme_notifications.dart';
// Mock 原生通道，验证实际通知包装层不会丢弃 false。
// ignore: depend_on_referenced_packages
import 'package:awesome_notifications/awesome_notifications_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:awesome_notifications/awesome_notifications_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notificationChannel = MethodChannel('awesome_notifications');

  group('真实通知包装层 false 返回', () {
    late AwesomeNotificationsPlatform previousPlatform;
    late bool permissionAllowed;
    late bool createResult;
    late List<MethodCall> calls;

    setUp(() {
      previousPlatform = AwesomeNotificationsPlatform.instance;
      AwesomeNotificationsPlatform.instance =
          MethodChannelAwesomeNotifications();
      permissionAllowed = false;
      createResult = false;
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationChannel, (call) async {
            calls.add(call);
            switch (call.method) {
              case 'isNotificationAllowed':
                return permissionAllowed;
              case 'createNewNotification':
                return createResult;
              default:
                throw StateError(
                  'Unexpected notification method: ${call.method}',
                );
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationChannel, null);
      AwesomeNotificationsPlatform.instance = previousPlatform;
    });

    test('关闭通知权限且create返回false时抛出StateError，不请求权限', () async {
      expect(await AboutmeNotifications.instance.checkPermission(), isFalse);
      await expectLater(
        AboutmeNotifications.instance.showNotification(
          id: 1,
          title: 'test',
          body: 'test',
        ),
        throwsA(isA<StateError>()),
      );
      expect(calls.map((call) => call.method), [
        'isNotificationAllowed',
        'createNewNotification',
      ]);
      createResult = true;
      await AboutmeNotifications.instance.showNotification(
        id: 1,
        title: 'test',
        body: 'test',
      );
    });

    test('create返回false保留pending，恢复权限重试同ID成功后去重', () async {
      final actualNotifications = RealNotificationPlatform();
      final actualCoordinator = ChatBackgroundCoordinator(actualNotifications);
      await actualCoordinator.startTask(
        'conversation',
        'denied',
        enableBackgroundService: false,
      );
      await actualCoordinator.finishTask('denied', content: 'done');
      expect(actualCoordinator.pendingNotificationCount, 1);
      final failedId = ((calls.last.arguments as Map)['content'] as Map)['id'];
      // 去重记录裁剪也不能覆盖尚未送达的通知。
      actualNotifications.resumed = true;
      for (var i = 0; i < 1001; i++) {
        await actualCoordinator.finishTask('other-$i', cancelled: true);
      }
      await actualCoordinator.finishTask('denied', content: 'duplicate');
      expect(
        calls.where((call) => call.method == 'createNewNotification'),
        hasLength(1),
      );
      permissionAllowed = true;
      createResult = true;
      expect(await AboutmeNotifications.instance.checkPermission(), isTrue);
      await actualCoordinator.retryPendingNotifications();
      expect(actualCoordinator.pendingNotificationCount, 0);
      expect(((calls.last.arguments as Map)['content'] as Map)['id'], failedId);
      await actualCoordinator.retryPendingNotifications();
      expect(
        calls.where((call) => call.method == 'createNewNotification'),
        hasLength(2),
      );
    });
  });

  late FakePlatform platform;
  late ChatBackgroundCoordinator coordinator;
  setUp(() {
    platform = FakePlatform();
    coordinator = ChatBackgroundCoordinator(
      platform,
      readyTimeout: const Duration(milliseconds: 35),
      probeInterval: const Duration(milliseconds: 2),
    );
  });

  test('完成去重仅保留最近1000项，重复完成不挤出较新记录', () async {
    platform.android = false;
    platform.resumed = true;
    for (var i = 0; i < 1001; i++) {
      await coordinator.finishTask('completed-$i', cancelled: true);
    }
    await coordinator.finishTask('completed-1000', cancelled: true);
    await coordinator.startTask('conversation', 'completed-1');
    await coordinator.startTask('conversation', 'completed-1000');
    expect(coordinator.activeTaskCount, 0);
    await coordinator.startTask('conversation', 'completed-0');
    expect(coordinator.activeTaskCount, 1);
  });

  test('ready超时不发送任务，仍可完成通知并继续处理下一任务', () async {
    platform.ignoreProbes = 10000;
    await coordinator.startTask('conversation', 'timeout');
    expect(
      platform.messages.every((m) => m['action'] == 'chat_service_probe'),
      isTrue,
    );
    await coordinator.finishTask('timeout', content: 'done');
    expect(platform.stops, 0);
    expect(platform.notifications, hasLength(1));
    platform.owner = null;
    platform.ignoreProbes = 0;
    await coordinator.startTask('conversation', 'next');
    await coordinator.finishTask('next', cancelled: true);
    expect(platform.stops, 1);
  });

  test('handler异步通知异常被捕获，不打断后续更新及销毁', () async {
    var updates = 0;
    final handler = AIChatTaskHandler(
      sendToMain: (_) {},
      updateNotification: (_, _) async {
        updates++;
        if (updates == 1) throw StateError('update failed');
      },
    );
    await handler.onStart(DateTime.now(), TaskStarter.developer);
    for (final taskId in ['a', 'b']) {
      handler.onReceiveData({
        'action': 'start_generation',
        'taskId': taskId,
        'conversationId': 'conversation',
        'sessionId': handler.sessionId,
      });
    }
    await Future<void>.delayed(Duration.zero);
    expect(updates, 2);
    await handler.onDestroy(DateTime.now(), false);
  });

  test('多控制器并发启动只启动一次，稳定taskId完成不影响另一会话', () async {
    await Future.wait([
      coordinator.startTask('conversation-a', 'round-a'),
      coordinator.startTask('conversation-b', 'round-b'),
    ]);
    expect(platform.starts, 1);
    expect(coordinator.activeTaskCount, 2);
    await coordinator.finishTask(
      'round-a',
      content: '回复',
      messageId: 'final-message',
    );
    expect(platform.stops, 0);
    expect(coordinator.activeTaskCount, 1);
    expect(
      platform.messages
          .where((m) => m['action'] == 'finish_generation')
          .last['taskId'],
      'round-a',
    );
    await coordinator.stopServiceIfIdle();
    expect(platform.stops, 0);
    await coordinator.finishTask('round-b', cancelled: true);
    expect(platform.stops, 1);
    expect(platform.callbacks, isEmpty);
  });

  test('等待明确ready才发送start，探针重试覆盖handler未就绪窗口', () async {
    platform.ignoreProbes = 3;
    await coordinator.startTask('conversation', 'task');
    expect(platform.probeCount, greaterThanOrEqualTo(4));
    expect(platform.sentBeforeReady, isFalse);
    expect(
      platform.messages.singleWhere(
        (m) => m['action'] == 'start_generation',
      )['taskId'],
      'task',
    );
    await coordinator.finishTask('task', cancelled: true);
  });

  test('未知服务不抢占，不发送聊天数据，不停止', () async {
    platform.owner = 'timer';
    await coordinator.startTask('conversation', 'task');
    await coordinator.finishTask('task', content: '后台回复');
    expect(platform.starts, 0);
    expect(platform.stops, 0);
    expect(platform.messages, isEmpty);
    expect(platform.notifications, hasLength(1));
  });

  test('自己启动的活人感临时让渡聊天，最后恢复', () async {
    await coordinator.setKeepAliveEnabled(true);
    expect(platform.owner, 'keepalive');
    await coordinator.startTask('conversation', 'task');
    expect(platform.owner, 'chat');
    expect(platform.stops, 1);
    await coordinator.finishTask('task', content: 'done');
    expect(platform.owner, 'keepalive');
    expect(platform.stops, 2);
    expect(platform.starts, 3);
    await coordinator.setKeepAliveEnabled(false);
  });

  test('聊天期间关闭活人感，最后不恢复', () async {
    await coordinator.setKeepAliveEnabled(true);
    await coordinator.startTask('conversation', 'task');
    await coordinator.setKeepAliveEnabled(false);
    await coordinator.finishTask('task', cancelled: true);
    expect(platform.owner, isNull);
    expect(platform.starts, 2);
  });

  test('已知服务被其他handler替换后不停止、不发送聊天内容', () async {
    await coordinator.startTask('conversation', 'task');
    platform.owner = 'timer';
    platform.session = 'foreign-session';
    platform.messages.clear();
    await coordinator.finishTask('task', content: 'done');
    expect(platform.stops, 0);
    expect(
      platform.messages.every((m) => m['action'] == 'chat_service_probe'),
      isTrue,
    );
    expect(platform.notifications, hasLength(1));
  });

  test('后台开关关闭/启动失败/服务已关闭均仍通知', () async {
    await coordinator.startTask(
      'conversation',
      'disabled',
      enableBackgroundService: false,
    );
    await coordinator.finishTask('disabled', content: 'done');
    expect(platform.starts, 0);
    platform.failStart = true;
    await coordinator.startTask('conversation', 'failed');
    await coordinator.finishTask('failed', error: 'error');
    platform.failStart = false;
    await coordinator.startTask('conversation', 'stopped');
    platform.owner = null;
    await coordinator.finishTask('stopped', content: 'done');
    expect(platform.notifications, hasLength(3));
  });

  test('两端统一通知，不支持Android保活仍可通知；前台成功错误和取消都抑制', () async {
    platform.android = false;
    await coordinator.startTask('conversation', 'ios');
    await coordinator.finishTask('ios', content: 'done', tokenCount: 1200);
    expect(platform.notifications.single.body, contains('1.2K tokens'));
    expect(platform.starts, 0);
    platform.resumed = true;
    await coordinator.startTask('conversation', 'foreground');
    await coordinator.finishTask('foreground', error: 'error');
    platform.resumed = false;
    await coordinator.startTask('conversation', 'cancelled');
    await coordinator.finishTask('cancelled', cancelled: true);
    expect(platform.notifications, hasLength(1));
  });

  test('通知完成前不停止服务，重复finish只发一次', () async {
    await coordinator.startTask('conversation', 'task');
    final pending = platform.notificationGate = Completer<void>();
    final finish = coordinator.finishTask('task', content: 'done');
    await platform.showStarted.future;
    expect(platform.stops, 0);
    pending.complete();
    await finish;
    await coordinator.finishTask('task', error: 'duplicate');
    expect(platform.notifications, hasLength(1));
    expect(platform.stops, 1);
  });

  test('初始化和发送异常被捕获保留待重试，重试沿用id不重复通知', () async {
    platform.failInitialization = true;
    await coordinator.startTask('conversation', 'task');
    await coordinator.finishTask('task', content: 'done');
    expect(coordinator.activeTaskCount, 0);
    expect(platform.stops, 1);
    expect(coordinator.pendingNotificationCount, 1);
    platform.failInitialization = false;
    platform.failNotification = true;
    await coordinator.retryPendingNotifications();
    expect(coordinator.pendingNotificationCount, 1);
    final failedId = platform.notifications.single.id;
    platform.failNotification = false;
    platform.resumed = true;
    await coordinator.retryPendingNotifications();
    expect(platform.notifications.last.id, failedId);
    expect(coordinator.pendingNotificationCount, 0);
    await coordinator.retryPendingNotifications();
    expect(platform.notifications, hasLength(2));
  });

  test('取消必须匹配会话/任务/session，回调可释放', () async {
    final cancelled = <String>[];
    coordinator.addCancelListener('listener', cancelled.add);
    await coordinator.startTask('a', 'task-a');
    await coordinator.startTask('b', 'task-b');
    void cancel(String conversation, String task, String session) =>
        platform.emit({
          'event': 'cancel_generation',
          'conversationId': conversation,
          'taskId': task,
          'sessionId': session,
        });
    cancel('b', 'task-a', platform.session);
    cancel('a', 'task-a', 'old');
    expect(cancelled, isEmpty);
    cancel('a', 'task-a', platform.session);
    expect(cancelled, ['task-a']);
    coordinator.removeCancelListener('listener');
    cancel('b', 'task-b', platform.session);
    expect(cancelled, ['task-a']);
    await coordinator.finishTask('task-a', cancelled: true);
    await coordinator.finishTask('task-b', cancelled: true);
  });

  test('handler仅接受ready session，按taskId跟踪并转发带会话取消', () async {
    final events = <Map>[];
    final handler = AIChatTaskHandler(
      sendToMain: (data) => events.add(data as Map),
      updateNotification: (_, _) async {},
    );
    handler.onReceiveData({
      'action': 'chat_service_probe',
      'requestId': 'early',
    });
    expect(events, isEmpty);
    await handler.onStart(DateTime.now(), TaskStarter.developer);
    handler.onReceiveData({
      'action': 'chat_service_probe',
      'requestId': 'ready',
    });
    expect(events.single['owner'], 'chat');
    void send(String action, String task, String conversation) =>
        handler.onReceiveData({
          'action': action,
          'taskId': task,
          'conversationId': conversation,
          'sessionId': handler.sessionId,
        });
    send('start_generation', 'a', 'conversation-a');
    send('start_generation', 'a', 'conversation-a');
    send('start_generation', 'b', 'conversation-b');
    expect(handler.activeTaskCount, 2);
    send('finish_generation', 'a', 'wrong-conversation');
    expect(handler.activeTaskCount, 2);
    handler.onNotificationButtonPressed('cancel');
    handler.onNotificationButtonPressed('cancel');
    final cancels = events
        .where((event) => event['event'] == 'cancel_generation')
        .toList();
    expect(cancels, hasLength(2));
    expect(cancels.first['conversationId'], 'conversation-a');
    send('finish_generation', 'a', 'conversation-a');
    expect(handler.activeTaskCount, 1);
    await handler.onDestroy(DateTime.now(), false);
  });
}

class Notice {
  Notice(this.id, this.title, this.body);
  final int id;
  final String title;
  final String body;
}

class RealNotificationPlatform extends FakePlatform {
  @override
  Future<void> showNotification(int id, String title, String body) =>
      AboutmeNotifications.instance.showNotification(
        id: id,
        title: title,
        body: body,
      );
}

class FakePlatform implements ChatBackgroundPlatform {
  bool android = true;
  bool resumed = false;
  String? owner;
  String session = 'session-0';
  int starts = 0;
  int stops = 0;
  int probeCount = 0;
  int ignoreProbes = 0;
  bool ready = false;
  bool sentBeforeReady = false;
  bool failStart = false;
  bool failInitialization = false;
  bool failNotification = false;
  final callbacks = <void Function(Object)>[];
  final messages = <Map>[];
  final notifications = <Notice>[];
  Completer<void>? notificationGate;
  final showStarted = Completer<void>();

  @override
  bool get supportsForegroundService => android;
  @override
  bool get supportsNotifications => true;
  @override
  bool get isAppResumed => resumed;
  @override
  Future<bool> isServiceRunning() async => owner != null;
  Future<bool> start(String value) async {
    starts++;
    if (failStart) return false;
    owner = value;
    session = 'session-$starts';
    ready = false;
    return true;
  }

  @override
  Future<bool> startChatService() => start('chat');
  @override
  Future<bool> startKeepAliveService() => start('keepalive');
  @override
  Future<bool> stopService() async {
    stops++;
    owner = null;
    return true;
  }

  @override
  void addDataCallback(void Function(Object) callback) =>
      callbacks.add(callback);
  @override
  void removeDataCallback(void Function(Object) callback) =>
      callbacks.remove(callback);
  void emit(Object data) {
    for (final callback in callbacks.toList()) {
      callback(data);
    }
  }

  @override
  void sendData(Object data) {
    final map = data as Map;
    messages.add(map);
    if (map['action'] == 'chat_service_probe') {
      probeCount++;
      if (probeCount <= ignoreProbes) return;
      ready = true;
      emit({
        'event': 'chat_service_ready',
        'owner': owner,
        'sessionId': session,
        'requestId': map['requestId'],
      });
    } else if (!ready) {
      sentBeforeReady = true;
    }
  }

  @override
  Future<void> initializeNotifications() async {
    if (failInitialization) throw StateError('initialization failed');
  }

  @override
  Future<void> showNotification(int id, String title, String body) async {
    if (!showStarted.isCompleted) showStarted.complete();
    await notificationGate?.future;
    notifications.add(Notice(id, title, body));
    if (failNotification) throw StateError('notification failed');
  }
}
