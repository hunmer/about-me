import 'package:aboutme_foreground_service/aboutme_foreground_service.dart';
import 'package:aboutme/core/notification_controller.dart';

/// AI 聊天任务处理器 - 在独立 isolate 中运行
///
/// 负责：
/// 1. 监听 AI 生成状态
/// 2. 更新前台服务通知
/// 3. AI 完成后发送系统通知
/// 4. 处理用户取消操作

// 必须是顶级函数或静态函数
@pragma('vm:entry-point')
void startAIChatTaskCallback() {
  FlutterForegroundTask.setTaskHandler(AIChatTaskHandler());
}

class AIChatTaskHandler extends TaskHandler {
  // AI 聊天状态（支持多任务）
  final Map<String, _GenerationTask> _activeTasks = {};
  int _updateCounter = 0;

  bool get _isGenerating => _activeTasks.isNotEmpty;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🤖 [后台服务] AI聊天后台服务启动');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 定期更新通知显示进度（每5秒）
    if (_isGenerating) {
      _updateCounter++;
      final animationStates = ['💭', '✨', '⚡', '🔮'];
      final icon = animationStates[_updateCounter % animationStates.length];

      FlutterForegroundTask.updateService(
        notificationTitle: '🤖 AI助手运行中',
        notificationText: '$icon AI正在生成回复...',
      );
    }
  }

  @override
  void onReceiveData(Object data) {
    print('🤖 [后台服务] 收到数据: $data');

    // 从主 isolate 接收数据
    if (data is Map<String, dynamic>) {
      final action = data['action'] as String?;

      switch (action) {
        case 'start_generation':
          _handleStartGeneration(data);
          break;

        case 'generation_progress':
          _handleGenerationProgress(data);
          break;

        case 'generation_complete':
          _handleGenerationComplete(data);
          break;

        case 'generation_error':
          _handleGenerationError(data);
          break;

        default:
          print('⚠️ [后台服务] 未知操作: $action');
      }
    }
  }

  /// 处理开始生成
  void _handleStartGeneration(Map<String, dynamic> data) {
    final conversationId = data['conversationId'] as String?;
    final messageId = data['messageId'] as String?;

    if (conversationId == null || messageId == null) {
      print('❌ [后台服务] 缺少必要参数');
      return;
    }

    // 创建新任务
    final task = _GenerationTask(
      conversationId: conversationId,
      messageId: messageId,
    );

    _activeTasks[task.taskId] = task;

    print('✅ [后台服务] 开始生成 - 任务: ${task.taskId} (活跃任务: ${_activeTasks.length})');

    // 更新通知
    _updateNotification();
  }

  /// 更新通知显示
  void _updateNotification() {
    final taskCount = _activeTasks.length;

    if (taskCount == 0) {
      return;
    }

    String title;
    String text;

    if (taskCount == 1) {
      title = '🤖 AI助手运行中';
      text = '💭 AI正在思考中...';
    } else {
      title = '🤖 AI助手运行中 ($taskCount个任务)';
      text = '⚡ 同时处理$taskCount个会话';
    }

    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  /// 处理生成进度更新
  void _handleGenerationProgress(Map<String, dynamic> data) {
    final progress = data['progress'] as String?;
    if (progress != null) {
      FlutterForegroundTask.updateService(
        notificationText: progress,
      );
    }
  }

  /// 处理生成完成
  void _handleGenerationComplete(Map<String, dynamic> data) {
    final conversationId = data['conversationId'] as String?;
    final messageId = data['messageId'] as String?;
    final preview = data['preview'] as String? ?? '点击查看完整回复';
    final isInForeground = data['isInForeground'] as bool? ?? false;
    final showToken = data['showToken'] as bool? ?? true;
    final tokenCount = data['tokenCount'] as int? ?? 0;

    if (conversationId == null || messageId == null) {
      print('❌ [后台服务] 完成回调缺少参数');
      return;
    }

    final taskId = '$conversationId:$messageId';

    // 移除完成的任务
    _activeTasks.remove(taskId);

    print('✅ [后台服务] 任务完成 - $taskId (Token: $tokenCount, 剩余: ${_activeTasks.length})');

    // 构建通知文本（可选显示token）
    String notificationText;
    if (showToken && tokenCount > 0) {
      notificationText = '$preview\n📊 消耗Token: $tokenCount';
    } else {
      notificationText = preview;
    }

    // 更新前台服务通知（如果还有其他任务，显示任务数）
    if (_activeTasks.isEmpty) {
      FlutterForegroundTask.updateService(
        notificationTitle: '✅ AI回复完成',
        notificationText: notificationText,
      );
    } else {
      FlutterForegroundTask.updateService(
        notificationTitle: '✅ 1个任务完成 (${_activeTasks.length}个进行中)',
        notificationText: notificationText,
      );
    }

    // 如果用户不在聊天界面，发送独立的系统通知
    if (!isInForeground) {
      String systemNotificationBody;
      if (showToken && tokenCount > 0) {
        // 格式化token显示（K = 1000）
        final formattedToken = tokenCount >= 1000
            ? '${(tokenCount / 1000).toStringAsFixed(1)}K'
            : '$tokenCount';
        systemNotificationBody = '$preview\n📊 $formattedToken tokens';
      } else {
        systemNotificationBody = preview;
      }

      NotificationController.createBasicNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: '💬 AI回复完成',
        body: systemNotificationBody,
      );
    }

    // 通知主 isolate
    FlutterForegroundTask.sendDataToMain({
      'event': 'ai_response_ready',
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  /// 处理生成错误
  void _handleGenerationError(Map<String, dynamic> data) {
    final conversationId = data['conversationId'] as String?;
    final messageId = data['messageId'] as String?;
    final error = data['error'] as String? ?? '生成回复时出现错误';

    if (conversationId != null && messageId != null) {
      final taskId = '$conversationId:$messageId';
      _activeTasks.remove(taskId);
      print('❌ [后台服务] 任务失败 - $taskId: $error (剩余: ${_activeTasks.length})');
    } else {
      print('❌ [后台服务] AI生成失败: $error');
    }

    // 更新前台服务通知
    if (_activeTasks.isEmpty) {
      FlutterForegroundTask.updateService(
        notificationTitle: '❌ AI回复失败',
        notificationText: '⚠️ $error',
      );
    } else {
      FlutterForegroundTask.updateService(
        notificationTitle: '❌ 1个任务失败 (${_activeTasks.length}个进行中)',
        notificationText: '⚠️ $error',
      );
    }

    // 发送错误通知
    NotificationController.createBasicNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '❌ AI回复失败',
      body: '⚠️ $error',
    );

    // 通知主 isolate
    FlutterForegroundTask.sendDataToMain({
      'event': 'ai_response_error',
      'error': error,
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('🤖 [后台服务] AI聊天后台服务停止 (timeout: $isTimeout)');

    if (isTimeout && _isGenerating) {
      // 服务超时且仍在生成，通知用户
      NotificationController.createBasicNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'AI服务已停止',
        body: '后台服务已超时停止',
      );
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('🤖 [后台服务] 通知按钮点击: $id');

    if (id == 'cancel') {
      // 取消所有 AI 生成任务
      final taskCount = _activeTasks.length;

      // 通知主 isolate 取消所有任务
      for (final task in _activeTasks.values) {
        FlutterForegroundTask.sendDataToMain({
          'event': 'cancel_generation',
          'conversationId': task.conversationId,
          'messageId': task.messageId,
        });
      }

      // 清空所有任务
      _activeTasks.clear();

      FlutterForegroundTask.updateService(
        notificationTitle: '🛑 已取消',
        notificationText: '已取消 $taskCount 个AI生成任务',
      );

      print('✅ [后台服务] 已取消所有任务');
    }
  }

  @override
  void onNotificationPressed() {
    print('🤖 [后台服务] 通知被点击');

    // 点击通知打开应用到聊天界面
    FlutterForegroundTask.launchApp('/chat');
  }

  @override
  void onNotificationDismissed() {
    print('🤖 [后台服务] 通知被关闭');
  }
}

/// 生成任务数据
class _GenerationTask {
  final String conversationId;
  final String messageId;
  final DateTime startTime;

  _GenerationTask({
    required this.conversationId,
    required this.messageId,
  }) : startTime = DateTime.now();

  String get taskId => '$conversationId:$messageId';
}
