part of 'chat_screen.dart';

/// TTS 自动朗读与语音通话（含前台服务）
extension _ChatScreenTtsVoiceExt on _ChatScreenState {
  /// 检查并朗读新的AI消息
  void _checkAndReadNewAIMessage() {
    try {
      // 获取所有消息
      final messages = _controller.messages;
      if (messages.isEmpty) return;

      // 从后往前查找第一条AI消息(非生成中)
      for (int i = messages.length - 1; i >= 0; i--) {
        final message = messages[i];

        // 只朗读AI消息，且消息已完成(非生成中)
        if (!message.isUser && !message.isGenerating) {
          // 检查是否是新消息(避免重复朗读)
          if (_lastReadMessageId != message.id &&
              message.content.trim().isNotEmpty) {
            _lastReadMessageId = message.id;

            // 调用TTS朗读
            _readMessage(message.content);
          }
          break; // 只处理最新的一条AI消息
        }
      }
    } catch (e) {
      debugPrint('检查并朗读AI消息失败: $e');
    }
  }

  /// 朗读消息
  Future<void> _readMessage(String text) async {
    try {
      final ttsPlugin = TTSPlugin.instance;
      await ttsPlugin.speak(
        text,
        serviceId: _selectedTTSServiceId, // 使用选择的服务
        onStart: () {
          debugPrint('开始朗读AI消息');
        },
        onComplete: () {
          debugPrint('朗读AI消息完成');
        },
        onError: (error) {
          debugPrint('朗读AI消息出错: $error');
        },
      );
    } catch (e) {
      debugPrint('调用TTS朗读失败: $e');
    }
  }

  // ========== 语音通话相关方法 ==========

  /// 初始化语音通话功能
  Future<void> _initializeVoiceCall() async {
    try {
      // 从全局配置服务获取ASR配置
      final asrConfig = SpeechRecognitionConfigService.instance.config;

      if (asrConfig == null || !asrConfig.isValid()) {
        debugPrint('⚠️ 未配置ASR服务，语音通话功能将不可用');
        return;
      }

      final recognitionService = TencentASRService(config: asrConfig);

      _voiceCallManager = VoiceCallManager(
        recognitionService: recognitionService,
        onUserMessage: (text) async {
          // 设置输入框文本并发送
          _controller.setInputText(text);
          await _controller.sendMessage();
        },
        aiMessageStream: _aiMessageStreamController.stream,
        onStateChanged: (state) {
          debugPrint('语音通话状态变更: $state');
        },
        onPhaseChanged: (phase) {
          debugPrint('语音通话阶段: $phase');
        },
        onError: (error) {
          if (mounted) {
            toastService.showToast('语音通话错误: $error');
          }
        },
      );

      // 应用从设置加载的配置
      _voiceCallManager!.updateConfig(_voiceCallConfig);

      await _voiceCallManager!.initialize();
      debugPrint('✅ 语音通话管理器初始化完成');
    } catch (e) {
      debugPrint('❌ 语音通话管理器初始化失败: $e');
    }
  }

  /// 检查并发送AI消息到语音通话管理器
  void _checkAndSendAIMessageToVoiceCall() {
    if (_voiceCallManager == null || !_voiceCallManager!.isCallActive) return;

    try {
      final messages = _controller.messages;
      if (messages.isEmpty) return;

      // 获取最新的AI消息
      for (int i = messages.length - 1; i >= 0; i--) {
        final message = messages[i];

        // 只处理AI消息，且消息已完成(非生成中)
        if (!message.isUser && !message.isGenerating) {
          // 检查是否是新消息（避免重复处理）
          if (_lastVoiceCallMessageId != message.id &&
              message.content.trim().isNotEmpty) {
            _lastVoiceCallMessageId = message.id;
            _voiceCallManager?.handleAIMessage(message.content);
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('发送AI消息到语音通话管理器失败: $e');
    }
  }

  /// 打开语音通话界面
  Future<void> _openVoiceCall() async {
    if (_voiceCallManager == null) {
      toastService.showToast('语音通话功能未初始化，请先配置ASR服务');
      return;
    }

    // 启动前台服务
    await _startVoiceCallForegroundService();

    // 打开语音通话全屏界面
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          manager: _voiceCallManager!,
          agent: _currentAgent,
          onExit: () async {
            await _stopVoiceCallForegroundService();
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
          onConfigChanged: (config) async {
            setState(() {
              _voiceCallConfig = config;
            });
            await _saveChatSettings();
          },
        ),
      ),
    );
  }

  /// 启动语音通话前台服务
  Future<void> _startVoiceCallForegroundService() async {
    if (!UniversalPlatform.isAndroid) return;

    try {
      final isRunning = await FlutterForegroundTask.isRunningService;

      if (!isRunning) {
        await FlutterForegroundTask.startService(
          serviceId: 258, // 使用不同的ID避免与聊天前台服务冲突
          notificationTitle: 'AI 语音通话',
          notificationText: '正在通话中...',
          notificationButtons: [
            NotificationButton(text: '暂停', id: 'pause'),
            NotificationButton(text: '结束', id: 'end'),
          ],
          callback: startVoiceCallTaskCallback,
        );
        debugPrint('✅ 语音通话前台服务已启动');
      }
    } catch (e) {
      debugPrint('❌ 启动语音通话前台服务失败: $e');
    }
  }

  /// 停止语音通话前台服务
  Future<void> _stopVoiceCallForegroundService() async {
    if (!UniversalPlatform.isAndroid) return;

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        debugPrint('✅ 语音通话前台服务已停止');
      }
    } catch (e) {
      debugPrint('❌ 停止语音通话前台服务失败: $e');
    }
  }

  /// 显示语音通话配置对话框的便捷方法
  // ignore: unused_element
  Future<VoiceCallConfig?> showVoiceCallConfigDialog(
    BuildContext context, {
    required VoiceCallConfig initialConfig,
  }) {
    return showDSDialog<VoiceCallConfig>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => VoiceCallConfigDialog(initialConfig: initialConfig),
    );
  }

  /// 打开TTS设置对话框（语音设置统一保存到当前 Agent）
  Future<void> _openTTSSettings() async {
    final agent = _currentAgent;
    if (agent == null) return;
    final result = await showTTSSettingsDialog(
      context,
      agent: agent,
      initialEnabled: _autoReadEnabled,
      initialServiceId: _selectedTTSServiceId,
    );

    if (result != null) {
      setState(() {
        _autoReadEnabled = result.enabled;
        _selectedTTSServiceId = result.serviceId;
      });

      // 语音设置写回 agent，对该 agent 的所有会话与 Live2D 播报生效
      try {
        await AgentController().updateAgent(
          agent.copyWith(
            ttsEnabled: result.enabled,
            ttsServiceId: result.serviceId,
            clearTtsServiceId: result.serviceId == null,
          ),
        );
      } catch (e) {
        debugPrint('保存 agent 语音设置失败: $e');
      }

      // 显示提示
      if (mounted) {
        toastService.showToast(result.enabled ? '已开启自动朗读' : '已关闭自动朗读');
      }
    }
  }
}

class VoiceCallTaskHandler extends TaskHandler {
  static String notificationTitle = 'AI 语音通话';
  static String notificationText = '正在通话中...';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('🚀 语音通话前台服务已启动');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 定期任务（可选）
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('🗑️ 语音通话前台服务已销毁');
  }

  void onButtonPressed(String id) {
    debugPrint('🔔 通知按钮被点击: $id');
    // 发送事件到主应用
    switch (id) {
      case '0': // 第一个按钮
        FlutterForegroundTask.sendDataToTask({'event': 'pause_call'});
        break;
      case '1': // 第二个按钮
        FlutterForegroundTask.sendDataToTask({'event': 'end_call'});
        break;
    }
  }

  @override
  void onReceiveData(Object data) {
    // 接收来自主应用的数据
    if (data is Map<String, dynamic>) {
      final action = data['action'];
      if (action == 'update_notification') {
        notificationTitle = data['title'] ?? notificationTitle;
        notificationText = data['content'] ?? notificationText;

        FlutterForegroundTask.updateService(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
        );
      }
    }
  }
}
