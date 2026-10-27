import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'foreground_service_config.dart';
import 'service_result.dart';

/// Aboutme 前台服务管理器
///
/// 封装 flutter_foreground_task，提供简洁的前台服务 API。
/// 用于管理前台服务的初始化、启动、停止和数据通信。
class AboutmeForegroundService {
  static final AboutmeForegroundService _instance =
      AboutmeForegroundService._internal();

  /// 单例实例
  static AboutmeForegroundService get instance => _instance;

  AboutmeForegroundService._internal();

  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// flutter_foreground_task 仅提供 Android/iOS 原生实现，
  /// 其他平台调用方法通道会抛 MissingPluginException
  bool get _isSupportedPlatform =>
      platformOverride ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  @visibleForTesting
  static bool? platformOverride;

  /// 初始化前台服务。
  ///
  /// 并发调用会等待同一个 Future，避免构造函数触发的异步初始化与首次
  /// start/stop 请求竞态。初始化只配置服务，不自动请求权限。
  Future<void> initialize({ForegroundServiceConfig? config}) {
    if (_isInitialized) return Future<void>.value();
    final current = _initializationFuture;
    if (current != null) return current;

    final future = _initialize(config ?? const ForegroundServiceConfig());
    _initializationFuture = future;
    return future;
  }

  Future<void> _initialize(ForegroundServiceConfig cfg) async {
    try {
      if (!_isSupportedPlatform) {
        debugPrint('[AboutmeForegroundService] 当前平台不支持前台服务，跳过初始化');
        _isInitialized = true;
        return;
      }

      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: cfg.channelId,
          channelName: cfg.channelName,
          channelDescription: cfg.channelDescription,
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: IOSNotificationOptions(
          showNotification: cfg.iosShowNotification,
          playSound: cfg.iosPlaySound,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(cfg.eventIntervalMs),
          autoRunOnBoot: cfg.autoRunOnBoot,
          autoRunOnMyPackageReplaced: cfg.autoRunOnMyPackageReplaced,
          allowWakeLock: cfg.allowWakeLock,
          allowWifiLock: cfg.allowWifiLock,
        ),
      );

      _isInitialized = true;
      debugPrint('[AboutmeForegroundService] 初始化完成');
    } catch (_) {
      _initializationFuture = null;
      rethrow;
    }
  }

  /// 将 flutter_foreground_task 的请求结果转换为本插件结果。
  @visibleForTesting
  static ServiceResult serviceResultFromRequest(ServiceRequestResult result) {
    if (result is ServiceRequestSuccess) return ServiceResult.success();
    if (result is ServiceRequestFailure) {
      return ServiceResult.failure(result.error.toString());
    }
    return ServiceResult.failure(result.toString());
  }

  /// 启动前台服务
  ///
  /// [serviceId] 服务唯一标识
  /// [notificationTitle] 通知标题
  /// [notificationText] 通知内容
  /// [notificationIcon] 通知图标元数据名称
  /// [notificationButtons] 通知按钮列表
  /// [notificationInitialRoute] 点击通知时的初始路由
  /// [callback] 前台任务回调
  Future<ServiceResult> startService({
    required int serviceId,
    required String notificationTitle,
    required String notificationText,
    String? notificationIcon,
    List<ServiceNotificationButton>? notificationButtons,
    String? notificationInitialRoute,
    required Function() callback,
  }) async {
    if (!_isSupportedPlatform) {
      return ServiceResult.failure('当前平台不支持前台服务');
    }

    try {
      await initialize();
      if (await isRunning) {
        final result = await FlutterForegroundTask.restartService();
        return serviceResultFromRequest(result);
      }

      // 转换按钮配置
      final buttons =
          notificationButtons
              ?.map((b) => NotificationButton(id: b.key, text: b.label))
              .toList();

      final result = await FlutterForegroundTask.startService(
        serviceId: serviceId,
        notificationIcon:
            notificationIcon != null
                ? NotificationIcon(metaDataName: notificationIcon)
                : null,
        notificationButtons: buttons,
        notificationTitle: notificationTitle,
        notificationText: notificationText,
        notificationInitialRoute: notificationInitialRoute,
        callback: callback,
      );

      return serviceResultFromRequest(result);
    } catch (e) {
      return ServiceResult.failure('启动服务异常: $e');
    }
  }

  /// 停止前台服务
  Future<ServiceResult> stopService() async {
    if (!_isSupportedPlatform) {
      return ServiceResult.failure('当前平台不支持前台服务');
    }

    try {
      await initialize();
      final result = await FlutterForegroundTask.stopService();
      return serviceResultFromRequest(result);
    } catch (e) {
      return ServiceResult.failure('停止服务异常: $e');
    }
  }

  /// 更新通知内容
  Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (!_isSupportedPlatform) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  /// 检查服务是否正在运行
  Future<bool> get isRunning async {
    if (!_isSupportedPlatform) return false;
    return FlutterForegroundTask.isRunningService;
  }

  /// 添加数据回调
  void addDataCallback(Function(Object) callback) {
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  /// 移除数据回调
  void removeDataCallback(Function(Object) callback) {
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }

  /// 发送数据到前台任务
  void sendDataToTask(Object data) {
    FlutterForegroundTask.sendDataToTask(data);
  }

  /// 检查通知权限
  Future<bool> checkNotificationPermission() async {
    if (!_isSupportedPlatform) return false;
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    return permission == NotificationPermission.granted;
  }

  /// 请求通知权限
  Future<bool> requestNotificationPermission() async {
    if (!_isSupportedPlatform) return false;
    final permission =
        await FlutterForegroundTask.requestNotificationPermission();
    return permission == NotificationPermission.granted;
  }

  /// 检查是否忽略电池优化
  Future<bool> get isIgnoringBatteryOptimizations async {
    if (!_isSupportedPlatform) return false;
    return FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  /// 请求忽略电池优化
  Future<bool> requestIgnoreBatteryOptimization() async {
    if (!_isSupportedPlatform) return false;
    return FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }

  /// 检查是否可以调度精确闹钟
  Future<bool> get canScheduleExactAlarms async {
    if (!_isSupportedPlatform) return false;
    return FlutterForegroundTask.canScheduleExactAlarms;
  }

  /// 打开闹钟和提醒设置
  Future<bool> openAlarmsAndRemindersSettings() async {
    if (!_isSupportedPlatform) return false;
    return FlutterForegroundTask.openAlarmsAndRemindersSettings();
  }
}
