import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_method_channel.dart';
import 'package:flutter_foreground_task/flutter_foreground_task_platform_interface.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FlutterForegroundTaskPlatform.instance =
        MethodChannelFlutterForegroundTask();
    FlutterForegroundTask.resetStatic();
    AboutmeForegroundService.platformOverride = null;
  });

  test('initialize 在不支持平台是可等待且不会请求权限', () async {
    await expectLater(
      AboutmeForegroundService.instance.initialize(),
      completes,
    );
    expect(AboutmeForegroundService.instance.isInitialized, isTrue);
  });

  test('并发 initialize 共享同一个初始化屏障', () async {
    AboutmeForegroundService.platformOverride = true;
    final first = AboutmeForegroundService.instance.initialize();
    final second = AboutmeForegroundService.instance.initialize();
    await Future.wait([first, second]);
    expect(AboutmeForegroundService.instance.isInitialized, isTrue);
  });

  test('isRunning 在不支持的平台返回 false', () async {
    expect(await AboutmeForegroundService.instance.isRunning, isFalse);
  });

  test('checkNotificationPermission 在不支持的平台返回 false', () async {
    expect(
      await AboutmeForegroundService.instance.checkNotificationPermission(),
      isFalse,
    );
  });

  test(
    'startService 透传 flutter_foreground_task ServiceRequestFailure',
    () async {
      AboutmeForegroundService.platformOverride = true;
      _initForegroundTask();
      FlutterForegroundTaskPlatform.instance = _FailingForegroundTaskPlatform(
        startFailure: StateError('start failed'),
        running: false,
      );

      final result = await AboutmeForegroundService.instance.startService(
        serviceId: 1,
        notificationTitle: 'title',
        notificationText: 'text',
        callback: () {},
      );

      expect(result.success, isFalse);
      expect(result.error, contains('start failed'));
    },
  );

  test(
    'restartService 透传 flutter_foreground_task ServiceRequestFailure',
    () async {
      AboutmeForegroundService.platformOverride = true;
      _initForegroundTask();
      FlutterForegroundTaskPlatform.instance = _FailingForegroundTaskPlatform(
        restartFailure: StateError('restart failed'),
        running: true,
      );

      final result = await AboutmeForegroundService.instance.startService(
        serviceId: 1,
        notificationTitle: 'title',
        notificationText: 'text',
        callback: () {},
      );

      expect(result.success, isFalse);
      expect(result.error, contains('restart failed'));
    },
  );

  test(
    'stopService 透传 flutter_foreground_task ServiceRequestFailure',
    () async {
      AboutmeForegroundService.platformOverride = true;
      _initForegroundTask();
      FlutterForegroundTaskPlatform.instance = _FailingForegroundTaskPlatform(
        stopFailure: StateError('stop failed'),
        running: true,
      );

      final result = await AboutmeForegroundService.instance.stopService();

      expect(result.success, isFalse);
      expect(result.error, contains('stop failed'));
    },
  );

  test('FiniteBackgroundTask 校验 taskId 且非 iOS 通道失败时安全返回', () async {
    final task = FiniteBackgroundTask.instance;
    expect(() => task.begin(''), throwsArgumentError);
    expect(await task.begin('ios-task'), isFalse);
    await task.end('ios-task');
  });
}

void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'test',
      channelName: 'test',
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
    ),
  );
}

class _FailingForegroundTaskPlatform extends FlutterForegroundTaskPlatform {
  _FailingForegroundTaskPlatform({
    this.startFailure,
    this.restartFailure,
    this.stopFailure,
    required this.running,
  });

  final Object? startFailure;
  final Object? restartFailure;
  final Object? stopFailure;
  final bool running;

  @override
  Future<void> startService({
    required AndroidNotificationOptions androidNotificationOptions,
    required IOSNotificationOptions iosNotificationOptions,
    required ForegroundTaskOptions foregroundTaskOptions,
    int? serviceId,
    List<ForegroundServiceTypes>? serviceTypes,
    required String notificationTitle,
    required String notificationText,
    NotificationIcon? notificationIcon,
    List<NotificationButton>? notificationButtons,
    String? notificationInitialRoute,
    Function? callback,
  }) async {
    if (startFailure != null) throw startFailure!;
  }

  @override
  Future<void> restartService() async {
    if (restartFailure != null) throw restartFailure!;
  }

  @override
  Future<void> stopService() async {
    if (stopFailure != null) throw stopFailure!;
  }

  @override
  Future<bool> get isRunningService async => running;
}
