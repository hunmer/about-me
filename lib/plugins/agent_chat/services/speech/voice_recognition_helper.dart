import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/voice_input_dialog.dart';
import 'package:aboutme/core/services/speech_recognition_config_service.dart';
import 'speech_recognition_config.dart';
import 'tencent_asr_service.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 语音识别辅助类
///
/// 功能：
/// - 封装语音识别的配置读取和服务创建
/// - 支持带 UI 和不带 UI 两种模式
/// - 自动管理资源释放
/// - 优先使用全局配置服务，向后兼容插件配置
class VoiceRecognitionHelper {
  /// 显示语音输入对话框（带 UI 模式）
  ///
  /// [context] - 上下文对象
  /// [onComplete] - 识别完成回调
  ///
  /// 返回值：
  /// - true: 用户确认发送
  /// - false: 用户取消
  static Future<bool> showVoiceInputDialog({
    required BuildContext context,
    required Function(String text) onComplete,
  }) async {
    try {
      // 创建语音识别服务
      final recognitionService = await _createRecognitionService(context);
      if (recognitionService == null) {
        return false;
      }

      // 显示语音输入对话框
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => VoiceInputDialog(
          recognitionService: recognitionService,
          onRecognitionComplete: onComplete,
        ),
      );

      // 释放服务资源
      recognitionService.dispose();

      return result ?? false;
    } catch (e) {
      debugPrint('显示语音输入对话框失败: $e');
      if (context.mounted) {
        toastService.showToast('打开语音输入失败: $e');
      }
      return false;
    }
  }

  /// 直接开始语音识别（无 UI 模式，默认）
  ///
  /// [context] - 上下文对象（用于显示错误提示）
  /// [onTextUpdate] - 文本更新回调（实时）
  /// [onComplete] - 识别完成回调
  /// [showUI] - 是否显示 UI（默认 false）
  ///
  /// 返回值：语音识别服务实例，需要手动调用 dispose() 释放资源
  static Future<TencentASRService?> startRecognition({
    required BuildContext context,
    Function(String text)? onTextUpdate,
    Function(String text)? onComplete,
  }) async {
    try {
      // 创建语音识别服务
      final recognitionService = await _createRecognitionService(context);
      if (recognitionService == null) {
        return null;
      }

      // 监听识别结果
      if (onTextUpdate != null) {
        recognitionService.recognitionStream.listen(onTextUpdate);
      }

      // 开始录音
      final success = await recognitionService.startRecording();
      if (!success) {
        recognitionService.dispose();
        if (context.mounted) {
          toastService.showToast('开始录音失败');
        }
        return null;
      }

      return recognitionService;
    } catch (e) {
      debugPrint('开始语音识别失败: $e');
      if (context.mounted) {
        toastService.showToast('开始语音识别失败: $e');
      }
      return null;
    }
  }

  /// 创建语音识别服务（不显示 UI 提示）
  ///
  /// 用于在需要服务实例但不想显示错误提示的场景
  ///
  /// 返回值：创建成功返回服务实例，失败返回 null
  static Future<TencentASRService?> createServiceSilently(
    BuildContext context,
  ) async {
    return _createRecognitionService(context, showError: false);
  }

  /// 创建语音识别服务
  ///
  /// 私有方法，用于创建并初始化语音识别服务
  /// 优先使用全局配置服务，如果未配置则回退到插件配置（向后兼容）
  static Future<TencentASRService?> _createRecognitionService(
    BuildContext context, {
    bool showError = true,
  }) async {
    try {
      TencentASRConfig? asrConfig;

      // 1. 优先尝试从全局配置服务获取
      final globalConfig = SpeechRecognitionConfigService.instance.config;
      if (globalConfig != null && globalConfig.isValid()) {
        debugPrint('🎤 [语音识别] 使用全局配置服务');
        asrConfig = globalConfig;
      } else {
        // 2. 回退到插件配置（向后兼容）
        debugPrint('🎤 [语音识别] 全局配置为空，尝试从插件配置读取');
        final plugin = AgentChatPlugin.instance;
        final settings = plugin.settings;
        debugPrint('🎤 [语音识别] 读取到的完整配置: $settings');
        final asrConfigMap = settings['asrConfig'] as Map<String, dynamic>?;
        debugPrint('🎤 [语音识别] ASR配置: $asrConfigMap');

        if (asrConfigMap != null) {
          asrConfig = TencentASRConfig.fromJson(asrConfigMap);
        }
      }

      if (asrConfig == null) {
        debugPrint('⚠️ [语音识别] ASR配置为空');
        if (showError && context.mounted) {
          toastService.showToast('请先在设置中配置腾讯云语音识别服务');
        }
        return null;
      }

      debugPrint('🎤 [语音识别] 创建配置对象: appId=${asrConfig.appId}');

      // 验证配置
      if (!asrConfig.isValid()) {
        if (showError && context.mounted) {
          toastService.showToast('语音识别配置无效，请检查设置');
        }
        return null;
      }

      // 创建语音识别服务
      final recognitionService = TencentASRService(config: asrConfig);

      // 初始化服务
      await recognitionService.initialize();

      return recognitionService;
    } catch (e) {
      debugPrint('创建语音识别服务失败: $e');
      if (showError && context.mounted) {
        toastService.showToast('创建语音识别服务失败: $e');
      }
      return null;
    }
  }
}
