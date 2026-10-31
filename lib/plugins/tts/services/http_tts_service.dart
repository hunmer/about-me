import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';
import 'tts_base_service.dart';
import 'tts_audio_utils.dart';
import 'package:aboutme/plugins/tts/models/tts_voice.dart';

/// HTTP TTS服务实现
class HttpTTSService extends TTSBaseService {
  static final _log = Logger('HttpTTSService');
  final Dio _dio = Dio();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isPaused = false;

  HttpTTSService(super.config);

  @override
  Future<void> initialize() async {
    try {
      // 配置 Dio
      _dio.options.headers.addAll(config.headers ?? {});
      _dio.options.connectTimeout = const Duration(seconds: 30);
      _dio.options.receiveTimeout = const Duration(seconds: 30);

      // 配置音频播放器回调
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed) {
          _isPlaying = false;
          _isPaused = false;
        }
      });

      _log.info('HTTP TTS服务初始化成功: ${config.name}');
    } catch (e) {
      _log.severe('HTTP TTS服务初始化失败: $e');
      rethrow;
    }
  }

  @override
  Future<void> speak(
    String text, {
    TTSCallback? onStart,
    TTSCallback? onComplete,
    TTSErrorCallback? onError,
    TTSAudioDataCallback? onAudioData,
  }) async {
    try {
      _isPlaying = true;
      _isPaused = false;

      _log.info(
        'HTTP TTS 朗读: ${text.substring(0, text.length > 50 ? 50 : text.length)}...',
      );

      final audioBytes = await _synthesizeBytes(text);
      onAudioData?.call(audioBytes, config.audioFormat);

      // 播放音频（onStart 在真正起播时才回调，见 _playAudioFromBytes）
      await _playAudioFromBytes(audioBytes, onStart: onStart);

      onComplete?.call();
      _isPlaying = false;
      _isPaused = false;
    } catch (e) {
      _log.severe('HTTP TTS朗读失败: $e');
      onError?.call(e.toString());
      _isPlaying = false;
      _isPaused = false;
    }
  }

  @override
  Future<String?> synthesizeToFile(String text, String filePath) async {
    final audioBytes = await _synthesizeBytes(text);
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsBytes(audioBytes);
    return filePath;
  }

  /// 请求 TTS 服务并返回音频字节（speak 与 synthesizeToFile 共用）
  Future<List<int>> _synthesizeBytes(String text) async {
    // 替换URL中的占位符
    final requestUrl = _replacePlaceholders(config.url ?? '', text: text);

    // 替换请求体中的占位符
    final requestBodyData = config.requestBody != null
        ? _replacePlaceholders(config.requestBody!, text: text)
        : null;

    _log.info('请求URL: $requestUrl');

    // 发送请求
    final response = await _dio.post(
      requestUrl,
      data: requestBodyData,
      options: Options(
        responseType: config.responseType == 'audio'
            ? ResponseType.bytes
            : ResponseType.json,
        headers: config.headers,
      ),
    );

    if (config.responseType == 'audio') {
      final bytes = response.data as List<int>;
      _log.info('收到音频字节: ${bytes.length} bytes');
      return bytes;
    }
    final bytes = _extractAudioFromJson(response.data);
    _log.info('从JSON提取音频: ${bytes.length} bytes');
    return bytes;
  }

  /// 替换占位符
  String _replacePlaceholders(String template, {required String text}) {
    return template
        .replaceAll('{text}', text)
        .replaceAll('{voice}', config.voice ?? '')
        .replaceAll('{pitch}', config.pitch.toString())
        .replaceAll('{speed}', config.speed.toString())
        .replaceAll('{volume}', config.volume.toString());
  }

  /// 从JSON响应中提取音频数据
  List<int> _extractAudioFromJson(Map<String, dynamic> json) {
    try {
      // 根据 audioFieldPath 提取音频数据
      final path = config.audioFieldPath?.split('.') ?? [];
      dynamic current = json;

      for (final key in path) {
        if (current is Map) {
          current = current[key];
        } else {
          throw Exception('无效的音频字段路径: ${config.audioFieldPath}');
        }
      }

      // 处理base64编码的音频
      if (config.audioIsBase64 == true && current is String) {
        return base64Decode(current);
      }

      // 直接返回字节数组
      if (current is List<int>) {
        return current;
      }

      throw Exception('无效的音频数据格式');
    } catch (e) {
      _log.severe('提取音频数据失败: $e');
      rethrow;
    }
  }

  /// 从字节数组播放音频
  ///
  /// [onStart] 在音频真正出声时才回调：play() 的 Future 在平台通道
  /// 应答时即完成，早于扬声器实际发声，因此用首个位置更新事件
  /// （平台真实播放时钟）确认；800ms 超时兜底，避免动画丢失。
  Future<void> _playAudioFromBytes(
    List<int> audioBytes, {
    TTSCallback? onStart,
  }) async {
    try {
      final pcm = isPcmAudioFormat(config.audioFormat);
      final playbackBytes = pcm ? pcm16ToWav(audioBytes) : audioBytes;
      if (pcm) {
        _log.info('PCM16 音频已包装为 WAV 播放: ${playbackBytes.length} bytes');
      }
      if (kIsWeb) {
        // Web 无本地临时文件，直接从字节播放（audioplayers Web 走 blob）
        await _audioPlayer.play(BytesSource(Uint8List.fromList(playbackBytes)));
        await _awaitPlaybackReallyStarted(onStart);
        await _audioPlayer.onPlayerComplete.first;
        return;
      }

      // 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/tts_temp_${DateTime.now().millisecondsSinceEpoch}.${pcm ? 'wav' : config.audioFormat ?? 'mp3'}',
      );

      await tempFile.writeAsBytes(playbackBytes);
      _log.info('音频临时文件: ${tempFile.path}');

      // 播放音频（play 完成即已起播）
      await _audioPlayer.play(DeviceFileSource(tempFile.path));
      await _awaitPlaybackReallyStarted(onStart);

      // 等待播放完成
      await _audioPlayer.onPlayerComplete.first;

      // 删除临时文件
      try {
        await tempFile.delete();
      } catch (e) {
        _log.warning('删除临时文件失败: $e');
      }
    } catch (e) {
      _log.severe('播放音频失败: $e');
      rethrow;
    }
  }

  /// 等待平台真实播放时钟（首个位置更新事件）确认已出声后回调 [onStart]。
  Future<void> _awaitPlaybackReallyStarted(TTSCallback? onStart) async {
    if (onStart == null) return;
    try {
      await _audioPlayer.onPositionChanged.first
          .timeout(const Duration(milliseconds: 800));
    } catch (_) {
      // 平台未发位置事件（极端情况）：退化为立即触发，保证动画不丢
    }
    onStart();
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _isPaused = false;
      _log.info('停止HTTP TTS播放');
    } catch (e) {
      _log.warning('停止HTTP TTS播放失败: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      if (_isPlaying && !_isPaused) {
        await _audioPlayer.pause();
        _isPaused = true;
        _log.info('暂停HTTP TTS播放');
      }
    } catch (e) {
      _log.warning('暂停HTTP TTS播放失败: $e');
    }
  }

  @override
  Future<void> resume() async {
    try {
      if (_isPlaying && _isPaused) {
        await _audioPlayer.resume();
        _isPaused = false;
        _log.info('继续HTTP TTS播放');
      }
    } catch (e) {
      _log.warning('继续HTTP TTS播放失败: $e');
    }
  }

  @override
  Future<List<TTSVoice>> getAvailableVoices() async {
    // HTTP服务需要手动配置语音列表
    // 这里返回空列表,用户需要自己配置voice参数
    return [];
  }

  @override
  Future<bool> testConnection() async {
    try {
      _log.info('测试HTTP TTS连接: ${config.url}');

      // 发送测试请求
      await speak(
        '测试',
        onError: (error) {
          throw Exception(error);
        },
      );

      return true;
    } catch (e) {
      _log.warning('HTTP TTS连接测试失败: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      _dio.close();
      _log.info('HTTP TTS服务已释放');
    } catch (e) {
      _log.warning('释放HTTP TTS服务失败: $e');
    }
  }
}
