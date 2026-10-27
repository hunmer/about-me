import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/services/foreground_task_manager.dart';
import 'package:aboutme/plugins/agent_chat/services/chat_background_coordinator.dart';

@pragma('vm:entry-point')
void startAlivenessKeepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(AlivenessKeepAliveHandler());
}

/// 不接收聊天任务，只回复不含业务数据的所有权/ready 探针。
class AlivenessKeepAliveHandler extends TaskHandler {
  final String _sessionId = const Uuid().v4();
  bool _ready = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _ready = true;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onReceiveData(Object data) {
    if (!_ready || data is! Map || data['action'] != 'chat_service_probe') {
      return;
    }
    FlutterForegroundTask.sendDataToMain({
      'event': 'chat_service_ready',
      'owner': 'keepalive',
      'sessionId': _sessionId,
      'requestId': data['requestId'],
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _ready = false;
  }
}

/// 活人感与聊天共用串行协调器；聊天结束后仅在仍启用时恢复保活。
class AlivenessKeepAliveService {
  AlivenessKeepAliveService._();
  static final AlivenessKeepAliveService instance =
      AlivenessKeepAliveService._();
  static const int serviceId = 258;

  Future<bool> get isRunning => ForegroundTaskManager().isServiceRunning();

  Future<void> start() =>
      ChatBackgroundCoordinator.instance.setKeepAliveEnabled(true);

  Future<void> stop() =>
      ChatBackgroundCoordinator.instance.setKeepAliveEnabled(false);
}
