import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/audio_ui_replica_demo.dart';

/// 深色语音备忘录卡片样式的音频消息（复刻 audio_ui_replica_demo 的样式）
class AudioMessageBubble extends StatefulWidget {
  final Message message;

  const AudioMessageBubble({super.key, required this.message});

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isInitialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final filePath = await ImageUtils.getAbsolutePath(widget.message.content);
      await _player.setSource(DeviceFileSource(filePath));
      _duration = widget.message.audioDuration > 0
          ? Duration(seconds: widget.message.audioDuration)
          : await _player.getDuration() ?? Duration.zero;

      _player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      });
      _player.onPositionChanged.listen((position) {
        if (mounted) setState(() => _position = position);
      });
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('初始化音频播放器时出错: $e');
    }
  }

  Future<void> _togglePlay() async {
    if (!_isInitialized) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      // 播放完成后从头重播
      if (_position >= _duration && _duration > Duration.zero) {
        await _player.seek(Duration.zero);
      }
      await _player.resume();
    }
  }

  void _seekBars(int bars) {
    if (!_isInitialized || _duration == Duration.zero) return;
    final ratio = (bars / _waveHeights.length).clamp(0.0, 1.0);
    _player.seek(Duration(milliseconds: (ratio * _duration.inMilliseconds).round()));
  }

  int get _progressBars {
    if (_duration.inMilliseconds == 0) return 0;
    final ratio = _position.inMilliseconds / _duration.inMilliseconds;
    return (ratio * _waveHeights.length).round().clamp(0, _waveHeights.length);
  }

  /// 录音时采集的真实波形；旧消息没有则退回 demo 默认波形
  List<int> get _waveHeights {
    final fileInfo =
        widget.message.metadata?[Message.metadataKeyFileInfo]
            as Map<String, dynamic>?;
    final wave = fileInfo?['waveform'] as List?;
    if (wave == null || wave.isEmpty) return audioUiWaveHeights;
    return wave.whereType<num>().map((e) => e.toInt()).toList();
  }

  /// 书签 = 收藏消息（与气泡旁 FavoriteIcon 同一份 isFavorite 状态）
  Future<void> _toggleFavorite() async {
    final message = widget.message;
    if (message.channelId == null) return;
    final metadata = Map<String, dynamic>.from(message.metadata ?? {});
    final isFavorite = metadata['isFavorite'] as bool? ?? false;
    metadata['isFavorite'] = !isFavorite;
    if (!isFavorite) {
      metadata['favoritedAt'] = DateTime.now().toIso8601String();
    } else {
      metadata.remove('favoritedAt');
    }
    final updated = await message.copyWith(metadata: metadata);
    await ChatPlugin.instance.channelService.updateMessage(updated);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final audioPath = widget.message.content;
    if (audioPath.isEmpty) {
      return Text('chat_audioMessageBubbleErrorText'.tr);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VoiceMemoCard(
          title: widget.message.user.username,
          subtitle: '语音消息 ${_formatDuration(_duration)}',
          waveHeights: _waveHeights,
          progress: _progressBars,
          showPause: _isPlaying,
          bookmarked: widget.message.metadata?['isFavorite'] == true,
          onTogglePlay: _togglePlay,
          onToggleBookmark: _toggleFavorite,
          onSeek: _seekBars,
        ),
        // 如果消息被编辑过，显示编辑标记
        if (widget.message.isEdited)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '已编辑',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
