import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';

import 'package:aboutme/core/services/foreground_task_manager.dart';

/// 活人感前台保活（Android）：
/// 通知常驻提升进程优先级，使主 isolate 的 ProactiveService 调度器
/// 在用户离开 app 后仍可运行（应用被杀后仍无法运行，属系统限制）。
/// 与 agent_chat 的前台服务（serviceId 257）互斥，被占用时不抢占。
@pragma('vm:entry-point')
void startAlivenessKeepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(AlivenessKeepAliveHandler());
}

class AlivenessKeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    FlutterForegroundTask.updateService(
      notificationTitle: '💕 AI 陪伴守护中',
      notificationText: '你的伙伴还在这里，想念时会主动找你',
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 心跳保活即可，无需更新
  }

  @override
  void onReceiveData(Object data) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class AlivenessKeepAliveService {
  AlivenessKeepAliveService._();
  static final AlivenessKeepAliveService instance =
      AlivenessKeepAliveService._();

  static const int serviceId = 258;
  bool _startedByUs = false;

  Future<bool> get isRunning async =>
      await ForegroundTaskManager().isServiceRunning();

  Future<void> start() async {
    if (_startedByUs || await isRunning) return; // 不抢占其他前台服务
    final result = await ForegroundTaskManager().startService(
      serviceId: serviceId,
      notificationTitle: '💕 AI 陪伴守护中',
      notificationText: '你的伙伴还在这里，想念时会主动找你',
      notificationInitialRoute: '/chat',
      callback: startAlivenessKeepAliveCallback,
    );
    _startedByUs = result.success;
  }

  Future<void> stop() async {
    if (!_startedByUs) return; // 只停自己启动的服务
    await ForegroundTaskManager().stopService();
    _startedByUs = false;
  }
}
