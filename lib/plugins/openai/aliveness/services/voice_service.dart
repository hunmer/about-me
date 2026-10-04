import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/chat/services/file_service.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:uuid/uuid.dart';

/// 语音主动发送（PRD 5.1.5 / Phase 4）：
/// 决策层判定 useVoice 后，把回复文本经 TTS 合成为音频文件，
/// 以 chat 语音消息（MessageType.audio）追加发送。
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  static const _uuid = Uuid();

  ChatPlugin get _plugin =>
      PluginManager.instance.getPlugin('chat')! as ChatPlugin;

  /// 将 [text] 合成语音并发送到频道。失败返回 false（静默降级，不影响文字消息）。
  Future<bool> sendVoiceMessage({
    required String agentId,
    required String channelId,
    required User aiUser,
    required String text,
    String? ttsServiceId,
    String? replyToId,
  }) async {
    try {
      final ttsPlugin = PluginManager.instance.getPlugin('tts');
      if (ttsPlugin is! TTSPlugin) return false;

      // 1) 合成到临时文件（http/minimax 服务支持；system 服务不支持时放弃）
      final tempDir = Directory.systemTemp;
      final tempPath =
          '${tempDir.path}/aliveness_voice_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final synthesized = await ttsPlugin.synthesizeToFile(
        text,
        serviceId: ttsServiceId,
        filePath: tempPath,
      );
      if (synthesized == null) {
        debugPrint('[Aliveness][语音] TTS 服务不支持合成文件，跳过语音消息');
        return false;
      }

      // 2) 转存到 chat 音频目录（相对存储路径）
      final bytes = await File(synthesized).readAsBytes();
      debugPrint('[Aliveness][语音] 合成成功 | ${bytes.length} 字节 时长解析中');
      final fileService = FileService();
      final storagePath = await fileService.saveAudioBytes(
        bytes,
        'tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      try {
        await File(synthesized).delete();
      } catch (_) {}

      // 3) 解析真实时长（失败则按 mp3 128kbps 估算）
      final duration = await _resolveDuration(storagePath, bytes.length);

      // 4) 构造语音消息（结构与录音消息一致）
      final message = await Message.create(
        id: 'ai_voice_${agentId}_${DateTime.now().millisecondsSinceEpoch}',
        content: '[语音] $text',
        channelId: channelId,
        user: aiUser,
        replyToId: replyToId,
        type: MessageType.audio,
        metadata: {
          'fileInfo': {
            'id': _uuid.v4(),
            'name': 'tts_voice.mp3',
            'originalName': 'tts_voice.mp3',
            'path': storagePath,
            'size': bytes.length,
            'extension': '.mp3',
            'mimeType': 'audio/mpeg',
            'type': 'audio',
            'isAudio': true,
            'duration': duration.inSeconds,
            'createdAt': DateTime.now().toIso8601String(),
          },
          'isAI': true,
          'agentId': agentId,
          'isVoiceVersion': true,
          'isCompleted': true,
        },
      );

      await _plugin.channelService.addMessage(channelId, message);
      _plugin.refresh();
      EventManager.instance.broadcast(
        'chat_message_updated',
        Value<Message>(message),
      );
      debugPrint('[Aliveness][语音] 已发送语音消息 | 时长=${duration.inSeconds}s '
          '路径=$storagePath');
      return true;
    } catch (e) {
      debugPrint('[Aliveness][语音] 发送失败: $e');
      return false;
    }
  }

  /// 优先用播放器解析真实时长；失败按 128kbps mp3 估算
  Future<Duration> _resolveDuration(String storagePath, int byteLength) async {
    try {
      final player = AudioPlayer();
      final absolute = await _toAbsolute(storagePath);
      await player.setSource(DeviceFileSource(absolute));
      final duration = await player.getDuration();
      await player.dispose();
      if (duration != null && duration.inMilliseconds > 0) {
        return duration;
      }
    } catch (_) {}
    return Duration(milliseconds: (byteLength * 8 / 128).round());
  }

  Future<String> _toAbsolute(String storagePath) async {
    // storagePath 形如 './chat/chat_files/audios/x.mp3'，基于应用文档目录还原
    final normalized = storagePath.replaceAll('./', '');
    final appDir = await StorageManager.getApplicationDocumentsDirectory();
    return '${appDir.path}/$normalized';
  }
}
