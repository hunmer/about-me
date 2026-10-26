import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/models/tts_voice.dart';

/// TTS服务回调
typedef TTSCallback = void Function();
typedef TTSErrorCallback = void Function(String error);
typedef TTSAudioDataCallback = void Function(List<int> bytes, String? format);

/// TTS服务抽象基类
abstract class TTSBaseService {
  /// 服务配置
  final TTSServiceConfig config;

  TTSBaseService(this.config);

  /// 初始化服务
  Future<void> initialize();

  /// 朗读文本
  ///
  /// [text] 要朗读的文本
  /// [onStart] 开始朗读回调
  /// [onComplete] 完成回调
  /// [onError] 错误回调
  Future<void> speak(
    String text, {
    TTSCallback? onStart,
    TTSCallback? onComplete,
    TTSErrorCallback? onError,
    TTSAudioDataCallback? onAudioData,
  });

  /// 停止朗读
  Future<void> stop();

  /// 合成语音写入指定文件（语音消息等"生成不播放"场景）。
  /// 返回写入的文件路径；服务不支持时返回 null。
  Future<String?> synthesizeToFile(String text, String filePath) async {
    return null;
  }

  /// 暂停朗读
  Future<void> pause();

  /// 继续朗读
  Future<void> resume();

  /// 获取可用语音列表
  Future<List<TTSVoice>> getAvailableVoices();

  /// 测试服务连接 (HTTP服务用)
  Future<bool> testConnection();

  /// 释放资源
  Future<void> dispose();
}
