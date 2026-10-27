import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';

/// 前台任务管理器 - 使用 aboutme_foreground_service 插件
///
/// 这是对 aboutme_foreground_service 插件的薄封装层，
/// 保持与原有 API 的兼容性。
class ForegroundTaskManager {
  static final ForegroundTaskManager _instance =
      ForegroundTaskManager._internal();

  factory ForegroundTaskManager() => _instance;

  ForegroundTaskManager._internal() {
    _initializationFuture = AboutmeForegroundService.instance.initialize();
  }

  late final Future<void> _initializationFuture;

  /// 可等待的初始化屏障。
  Future<void> get initialization => _initializationFuture;

  Future<void> _waitForInitialization() => _initializationFuture;

  /// 启动前台服务
  Future<ServiceResult> startService({
    required int serviceId,
    String? notificationIcon,
    List<ServiceNotificationButton>? notificationButtons,
    required String notificationTitle,
    required String notificationText,
    required Function() callback,
    String? notificationInitialRoute,
  }) async {
    await _waitForInitialization();
    return await AboutmeForegroundService.instance.startService(
      serviceId: serviceId,
      notificationTitle: notificationTitle,
      notificationText: notificationText,
      notificationIcon: notificationIcon ?? 'github.hunmer.aboutme.service.APP_ICON',
      notificationButtons: notificationButtons,
      notificationInitialRoute: notificationInitialRoute,
      callback: callback,
    );
  }

  Future<ServiceResult> stopService() async {
    await _waitForInitialization();
    return AboutmeForegroundService.instance.stopService();
  }

  /// 检查服务是否正在运行
  Future<bool> isServiceRunning() async {
    await _waitForInitialization();
    return AboutmeForegroundService.instance.isRunning;
  }

  /// 添加数据回调
  void addDataCallback(Function(Object) callback) {
    AboutmeForegroundService.instance.addDataCallback(callback);
  }

  /// 移除数据回调
  void removeDataCallback(Function(Object) callback) {
    AboutmeForegroundService.instance.removeDataCallback(callback);
  }
}
