import 'package:flutter/foundation.dart';
import 'package:aboutme/core/app_initializer.dart' show globalConfigManager;
import 'package:aboutme/plugins/agent_chat/services/speech/speech_recognition_config.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';

/// 语音识别配置服务
///
/// 全局单例服务，用于管理语音识别配置。
/// 配置存储在全局配置中，可被多个插件共享使用。
class SpeechRecognitionConfigService extends ChangeNotifier {
  static SpeechRecognitionConfigService? _instance;

  /// 获取单例实例
  static SpeechRecognitionConfigService get instance {
    _instance ??= SpeechRecognitionConfigService._();
    return _instance!;
  }

  SpeechRecognitionConfigService._();

  /// 配置存储键（作为特殊插件 ID）
  static const String _configPluginId = 'speechRecognition';

  /// 缓存的配置
  TencentASRConfig? _cachedConfig;

  /// AI纠错Agent（完整配置）
  AIAgent? _correctionAgent;

  /// 获取腾讯云 ASR 配置
  TencentASRConfig? get config => _cachedConfig;

  /// 获取AI纠错Agent
  AIAgent? get correctionAgent => _correctionAgent;

  /// 检查是否已配置ASR
  bool get isConfigured => _cachedConfig != null && _cachedConfig!.isValid();

  /// 检查是否已配置AI纠错
  bool get isCorrectionConfigured => _correctionAgent != null;

  /// 初始化服务，加载配置
  Future<void> initialize() async {
    await _loadConfig();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      final configMap = await globalConfigManager.getPluginConfig(
        _configPluginId,
      );
      if (configMap != null && configMap.isNotEmpty) {
        final asrConfigMap = configMap['asrConfig'] as Map<String, dynamic>?;
        if (asrConfigMap != null) {
          _cachedConfig = TencentASRConfig.fromJson(asrConfigMap);
        }

        // 加载AI纠错Agent（完整配置）
        final agentMap = configMap['correctionAgent'] as Map<String, dynamic>?;
        if (agentMap != null) {
          try {
            _correctionAgent = AIAgent.fromJson(agentMap);
          } catch (e) {
            _correctionAgent = null;
          }
        }
      }
    } catch (e) {
      _cachedConfig = null;
      _correctionAgent = null;
    }
    notifyListeners();
  }

  /// 保存配置
  Future<void> saveConfig(TencentASRConfig config) async {
    try {
      await globalConfigManager.savePluginConfig(_configPluginId, {
        'asrConfig': config.toJson(),
        'correctionAgent': _correctionAgent?.toJson(),
      });

      _cachedConfig = config;

      notifyListeners();
    } catch (e) {
      debugPrint('🎤 [语音识别配置服务] 保存配置失败: $e');
      rethrow;
    }
  }

  /// 保存AI纠错Agent
  Future<void> saveCorrectionAgent(AIAgent? agent) async {
    try {
      _correctionAgent = agent;

      // 如果已有ASR配置，保存所有配置
      if (_cachedConfig != null) {
        await globalConfigManager.savePluginConfig(_configPluginId, {
          'asrConfig': _cachedConfig!.toJson(),
          'correctionAgent': agent?.toJson(),
        });
      } else {
        // 只保存Agent配置
        await globalConfigManager.savePluginConfig(_configPluginId, {
          'correctionAgent': agent?.toJson(),
        });
      }

      notifyListeners();
    } catch (e) {
      debugPrint('🎤 [语音识别配置服务] 保存AI纠错Agent失败: $e');
      rethrow;
    }
  }

  /// 清除配置
  Future<void> clearConfig() async {
    try {
      await globalConfigManager.savePluginConfig(_configPluginId, {});
      _cachedConfig = null;
      _correctionAgent = null;
      notifyListeners();
    } catch (e) {
      debugPrint('🎤 [语音识别配置服务] 清除配置失败: $e');
      rethrow;
    }
  }

  /// 重新加载配置
  Future<void> reload() async {
    await _loadConfig();
  }
}
