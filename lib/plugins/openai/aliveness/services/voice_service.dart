import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/models/file_attachment.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/chat/services/file_service.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:uuid/uuid.dart';

/// 合成产物：音频已存入 chat 音频目录
class SynthesizedVoice {
  final String storagePath; // './chat/chat_files/audios/xxx.mp3'
  final String absolutePath;
  final int byteLength;
  final Duration duration;
  SynthesizedVoice({
    required this.storagePath,
    required this.absolutePath,
    required this.byteLength,
    required this.duration,
  });
}

/// 语音主动发送（PRD 5.1.5）：
/// 决策层判定 useVoice 后，把回复文本经 TTS 合成为音频。
/// 两个聊天体系共用合成核心：
/// - chat 频道：以 MessageType.audio 消息发送（chat 语音消息）
/// - agent_chat：以 FileAttachment.audio 附件追加（复用同一播放器 UI）
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  static const _uuid = Uuid();

  ChatPlugin get _plugin =>
      PluginManager.instance.getPlugin('chat')! as ChatPlugin;

  /// 合成核心：TTS → 临时文件 → chat 音频目录，返回绝对/相对路径与时长
  Future<SynthesizedVoice?> synthesize(
    String text, {
    String? ttsServiceId,
  }) async {
    try {
      final ttsPlugin = PluginManager.instance.getPlugin('tts');
      if (ttsPlugin is! TTSPlugin) return null;

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
        return null;
      }

      final bytes = await File(synthesized).readAsBytes();
      final fileService = FileService();
      final storagePath = await fileService.saveAudioBytes(
        bytes,
        'tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      try {
        await File(synthesized).delete();
      } catch (_) {}

      final duration = await _resolveDuration(storagePath, bytes.length);
      debugPrint('[Aliveness][语音] 合成成功 | ${bytes.length} 字节 '
          '${duration.inSeconds}s');
      return SynthesizedVoice(
        storagePath: storagePath,
        absolutePath: await _toAbsolute(storagePath),
        byteLength: bytes.length,
        duration: duration,
      );
    } catch (e) {
      debugPrint('[Aliveness][语音] 合成失败: $e');
      return null;
    }
  }

  // ---------- chat 频道版：语音消息 ----------

  /// 失败静默降级，不影响文字消息。
  Future<bool> sendVoiceMessage({
    required String agentId,
    required String channelId,
    required User aiUser,
    required String text,
    String? ttsServiceId,
    String? replyToId,
  }) async {
    try {
      final voice = await synthesize(text, ttsServiceId: ttsServiceId);
      if (voice == null) return false;

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
            'path': voice.storagePath,
            'size': voice.byteLength,
            'extension': '.mp3',
            'mimeType': 'audio/mpeg',
            'type': 'audio',
            'isAudio': true,
            'duration': voice.duration.inSeconds,
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
      debugPrint('[Aliveness][语音] chat 频道语音消息已发送');
      return true;
    } catch (e) {
      debugPrint('[Aliveness][语音] 发送失败: $e');
      return false;
    }
  }

  // ---------- agent_chat 版：语音附件消息 ----------

  /// 追加一条带语音附件的 AI 消息（复用 chat 的音频播放器 UI）
  Future<bool> sendVoiceMessageToConversation({
    required String agentId,
    required Conversation conversation,
    required MessageService messageService,
    required String text,
    String? ttsServiceId,
  }) async {
    try {
      final voice = await synthesize(text, ttsServiceId: ttsServiceId);
      if (voice == null) return false;

      final attachment = FileAttachment.audio(
        filePath: voice.absolutePath,
        fileName: '语音消息.mp3',
        fileSize: voice.byteLength,
        durationSeconds: voice.duration.inSeconds,
      );

      final message = ChatMessage(
        id: _uuid.v4(),
        conversationId: conversation.id,
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        attachments: [attachment],
        isGenerating: false,
        generatedByAgentId: agentId,
        metadata: {'isVoiceVersion': true},
      );
      await messageService.addMessage(message);
      debugPrint('[Aliveness][语音] agent_chat 语音附件消息已发送');
      return true;
    } catch (e) {
      debugPrint('[Aliveness][语音] agent_chat 发送失败: $e');
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
    // storagePath 形如 './chat/chat_files/audios/x.mp3'（storageManager 以 app_data 为基准）
    final normalized = storagePath.replaceAll('./', '');
    final appDir = await StorageManager.getApplicationDocumentsDirectory();
    return '${appDir.path}/app_data/$normalized';
  }
}
