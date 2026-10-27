import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../services/chat_background_coordinator.dart';
import '../../services/token_counter_service.dart';
import 'shared/manager_context.dart';

/// 控制器局部适配器；服务、任务及通知状态统一保存在主 isolate 协调器。
class ChatForegroundServiceManager {
  final ManagerContext context;
  final bool Function() isSendingGetter;
  final VoidCallback? onCancelRequested;
  final ChatBackgroundCoordinator _coordinator;
  final String _listenerKey = const Uuid().v4();
  final Set<String> _taskIds = {};
  bool _initialized = false;
  bool _disposed = false;

  ChatForegroundServiceManager({
    required this.context,
    required this.isSendingGetter,
    this.onCancelRequested,
    ChatBackgroundCoordinator? coordinator,
  }) : _coordinator = coordinator ?? ChatBackgroundCoordinator.instance;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    _coordinator.addCancelListener(_listenerKey, (taskId) {
      // 协调器先校验 conversationId/sessionId，此处再校验本控制器持有的 taskId。
      if (!_disposed && _taskIds.contains(taskId)) onCancelRequested?.call();
    });
  }

  void dispose() {
    _disposed = true;
    _coordinator.removeCancelListener(_listenerKey);
  }

  /// taskId 是本轮稳定 UUID，与最终落库 messageId 无关。
  Future<void> startService(String conversationId, String taskId) async {
    if (_disposed) return;
    if (conversationId != context.conversationId) {
      throw ArgumentError('conversationId 与管理器会话不一致');
    }
    await initialize();
    _taskIds.add(taskId);
    await _coordinator.startTask(
      conversationId,
      taskId,
      enableBackgroundService:
          context.getSetting<bool>('enableBackgroundService', true) ?? true,
      showToken:
          context.getSetting<bool>('showTokenInNotification', true) ?? true,
    );
  }

  /// 即使后台服务关闭/失败或控制器已 dispose，仍 await 通知及任务清理。
  Future<void> finishTask(
    String taskId, {
    String content = '',
    int? tokenCount,
    String? messageId,
    String? error,
    bool cancelled = false,
  }) async {
    await _coordinator.finishTask(
      taskId,
      content: content,
      tokenCount: tokenCount ?? TokenCounterService.estimateTokenCount(content),
      messageId: messageId,
      error: error,
      cancelled: cancelled,
    );
    _taskIds.remove(taskId);
  }

  Future<void> stopServiceIfIdle() => _coordinator.stopServiceIfIdle();

  Future<void> retryPendingNotifications() =>
      _coordinator.retryPendingNotifications();

  Future<void> notifyGenerationProgress(
    String progress, {
    String? taskId,
  }) async {
    final target = taskId ?? (_taskIds.length == 1 ? _taskIds.single : null);
    if (target != null && _taskIds.contains(target)) {
      await _coordinator.notifyProgress(target, progress);
    }
  }

  // 兼容旧调用方；新调用方统一用带稳定 taskId 的 finishTask。
  Future<void> notifyGenerationComplete(
    String content, {
    int? tokenCount,
    String? messageId,
    String? taskId,
  }) async {
    final target = taskId ?? (_taskIds.length == 1 ? _taskIds.single : null);
    if (target != null) {
      await finishTask(
        target,
        content: content,
        tokenCount: tokenCount,
        messageId: messageId,
      );
    }
  }

  Future<void> notifyGenerationError(
    String error, {
    String? messageId,
    String? taskId,
  }) async {
    final target = taskId ?? (_taskIds.length == 1 ? _taskIds.single : null);
    if (target != null) {
      await finishTask(target, error: error, messageId: messageId);
    }
  }
}
