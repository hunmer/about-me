import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';
import 'package:aboutme/core/services/foreground_task_manager.dart';
import 'package:universal_platform/universal_platform.dart';
import '../../services/chat_task_handler.dart';
import '../../services/token_counter_service.dart';
import 'shared/manager_context.dart';

/// 聊天前台服务管理器 (Android 专用)
///
/// 负责管理 AI 聊天时的前台服务、通知和后台通信
/// 遵循单一职责原则 (SRP)
class ChatForegroundServiceManager {
  final ManagerContext context;
  final ForegroundTaskManager _taskManager = ForegroundTaskManager();

  /// 是否正在发送消息 (用于判断是否需要停止服务)
  final bool Function() isSendingGetter;

  /// 取消发送回调
  final VoidCallback? onCancelRequested;

  ChatForegroundServiceManager({
    required this.context,
    required this.isSendingGetter,
    this.onCancelRequested,
  });

  // ========== 生命周期管理 ==========

  /// 初始化 - 注册数据回调
  Future<void> initialize() async {
    if (!kIsWeb && UniversalPlatform.isAndroid) {
      _taskManager.addDataCallback(_onReceiveBackgroundData);
      debugPrint('📝 已注册前台服务数据回调');
    }
  }

  /// 释放资源 - 移除回调
  void dispose() {
    if (!kIsWeb && UniversalPlatform.isAndroid) {
      _taskManager.removeDataCallback(_onReceiveBackgroundData);
      debugPrint('📝 已移除前台服务数据回调');
    }
  }

  // ========== 服务控制 ==========

  /// 启动 AI 聊天前台服务
  Future<void> startService(String conversationId, String messageId) async {
    if (kIsWeb || !UniversalPlatform.isAndroid) {
      debugPrint('ℹ️ [ForegroundService] 非 Android 平台，跳过前台服务');
      return;
    }

    try {
      final isRunning = await _taskManager.isServiceRunning();

      if (!isRunning) {
        debugPrint('🚀 [ForegroundService] 启动 AI 聊天前台服务');

        await _taskManager.startService(
          serviceId: 257, // 唯一 ID (与 TimerService 区分)
          notificationTitle: 'AI 助手运行中',
          notificationText: '正在为您生成回复...',
          notificationButtons: [
            const ServiceNotificationButton(key: 'cancel', label: '取消'),
          ],
          notificationInitialRoute: '/chat',
          callback: startAIChatTaskCallback,
        );
      }

      // 发送开始生成的消息到后台服务
      FlutterForegroundTask.sendDataToTask({
        'action': 'start_generation',
        'conversationId': conversationId,
        'messageId': messageId,
      });

      debugPrint('✅ [ForegroundService] 前台服务启动成功');
    } catch (e) {
      debugPrint('❌ [ForegroundService] 启动前台服务失败: $e');
    }
  }

  /// 停止前台服务 (如果空闲)
  Future<void> stopServiceIfIdle() async {
    if (kIsWeb || !UniversalPlatform.isAndroid) return;

    try {
      if (!isSendingGetter() && await _taskManager.isServiceRunning()) {
        await _taskManager.stopService();
        debugPrint('✅ [ForegroundService] 前台服务已停止');
      }
    } catch (e) {
      debugPrint('❌ [ForegroundService] 停止前台服务失败: $e');
    }
  }

  // ========== 通知更新 ==========

  /// 通知生成完成
  void notifyGenerationComplete(
    String content, {
    int? tokenCount,
    String? messageId,
  }) {
    if (kIsWeb || !UniversalPlatform.isAndroid) return;

    try {
      final preview =
          content.length > 50 ? '${content.substring(0, 50)}...' : content;
      final isInForeground = _isInChatScreen();

      // 获取设置: 是否显示 token
      final showToken = context.getSetting<bool>(
        'showTokenInNotification',
        true,
      );

      FlutterForegroundTask.sendDataToTask({
        'action': 'generation_complete',
        'conversationId': context.conversationId,
        'messageId': messageId,
        'preview': preview,
        'isInForeground': isInForeground,
        'showToken': showToken,
        'tokenCount':
            tokenCount ?? TokenCounterService.estimateTokenCount(content),
      });

      debugPrint('✅ [ForegroundService] 已通知生成完成 (token: $tokenCount)');
    } catch (e) {
      debugPrint('❌ [ForegroundService] 通知生成完成失败: $e');
    }
  }

  /// 通知生成进度
  void notifyGenerationProgress(String progress) {
    if (kIsWeb || !UniversalPlatform.isAndroid) return;

    try {
      FlutterForegroundTask.sendDataToTask({
        'action': 'generation_progress',
        'progress': progress,
      });
    } catch (e) {
      debugPrint('❌ [ForegroundService] 通知生成进度失败: $e');
    }
  }

  /// 通知生成错误
  void notifyGenerationError(String error, {String? messageId}) {
    if (kIsWeb || !UniversalPlatform.isAndroid) return;

    try {
      FlutterForegroundTask.sendDataToTask({
        'action': 'generation_error',
        'conversationId': context.conversationId,
        'messageId': messageId,
        'error': error,
      });

      debugPrint('✅ [ForegroundService] 已通知生成错误');
    } catch (e) {
      debugPrint('❌ [ForegroundService] 通知生成错误失败: $e');
    }
  }

  // ========== 私有方法 ==========

  /// 接收后台服务发送的数据
  void _onReceiveBackgroundData(Object data) {
    debugPrint('📨 [ForegroundService] 收到后台服务数据: $data');

    if (data is Map<String, dynamic>) {
      final event = data['event'];

      switch (event) {
        case 'cancel_generation':
          // 后台服务请求取消生成
          debugPrint('🛑 [ForegroundService] 后台服务请求取消生成');
          onCancelRequested?.call();
          break;

        case 'ai_response_ready':
          // AI 回复完成
          final messageId = data['messageId'] as String?;
          debugPrint('✅ [ForegroundService] AI 回复完成: $messageId');
          context.notify(); // 刷新 UI
          break;

        case 'ai_response_error':
          // AI 回复错误
          final error = data['error'] as String?;
          debugPrint('❌ [ForegroundService] AI 回复错误: $error');
          context.notify(); // 刷新 UI
          break;

        default:
          debugPrint('⚠️ [ForegroundService] 未知事件: $event');
      }
    }
  }

  /// 检查是否在聊天界面
  bool _isInChatScreen() {
    // 方式 1: 通过 WidgetsBinding 检查应用状态
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != AppLifecycleState.resumed) {
      return false; // 应用在后台
    }

    // 方式 2: 简化实现 - 假设在前台就是在聊天界面
    // TODO: 可以通过路由监听或全局状态更精确判断
    return true;
  }
}
