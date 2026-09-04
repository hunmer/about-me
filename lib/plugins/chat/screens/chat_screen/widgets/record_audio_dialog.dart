import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

class RecordAudioDialog extends StatefulWidget {
  final Function(File audioFile, Duration duration) onStop;

  const RecordAudioDialog({super.key, required this.onStop});

  @override
  State<RecordAudioDialog> createState() => _RecordAudioDialogState();
}

class _RecordAudioDialogState extends State<RecordAudioDialog> {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _duration = Duration.zero;
  DateTime? _startTime;
  bool _isInitialized = false;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    // 延迟执行录音初始化，以确保对话框完全显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isInitialized) {
        _isInitialized = true;
        _initializeAndStartRecording();
      }
    });
  }

  @override
  void dispose() {
    _stopRecording();
    super.dispose();
  }

  Future<void> _initializeAndStartRecording() async {
    // 防止重复初始化
    if (_isStarting) return;
    _isStarting = true;

    try {
      // 检查录音权限
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        throw '需要录音权限才能录制语音消息';
      }

      // 开始录音
      await _startRecording();
    } catch (e) {
      if (mounted) {
        // 显示错误提示对话框
        await showDSDialog(
          context: context,
          theme: DSThemeBridge.resolve(context),
          builder:
              (context) => DSThemeBridge(
                child: Builder(
                  builder:
                      (context) => DSDialog(
                        title: 'chat_recordingFailed'.tr,
                        message: e.toString(),
                        confirmText: 'app_ok'.tr,
                      ),
                ),
              ),
        );
        // 关闭录音对话框
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _startRecording() async {
    // 获取临时目录
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = path.join(tempDir.path, 'audio_$timestamp.m4a');

    // 配置录音参数
    await _audioRecorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 2,
      ),
      path: filePath,
    );

    if (mounted) {
      setState(() {
        _isRecording = true;
        _startTime = DateTime.now();
      });

      // 更新录音时长
      _updateDuration();
    }
  }

  void _updateDuration() {
    if (!mounted || !_isRecording || _startTime == null) return;

    setState(() {
      _duration = DateTime.now().difference(_startTime!);
    });

    Future.delayed(const Duration(seconds: 1), _updateDuration);
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        final file = File(path);
        widget.onStop(file, _duration);
      }
    } catch (e) {
      if (mounted) {
        // 显示错误提示对话框
        await showDSDialog(
          context: context,
          theme: DSThemeBridge.resolve(context),
          builder:
              (context) => DSThemeBridge(
                child: Builder(
                  builder:
                      (context) => DSDialog(
                        title: 'chat_recordingFailed'.tr,
                        message: 'chat_recordingStopError'.tr,
                        confirmText: 'app_ok'.tr,
                      ),
                ),
              ),
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'chat_audioRecording'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),
                Text(
                  _formatDuration(_duration),
                  style: DsTypography.display.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),
                // 停止录音按钮
                DSIconButton(
                  icon: DsIconKind.stop,
                  size: 64,
                  color: theme.danger,
                  iconColor: theme.onDanger,
                  onPressed: _stopRecording,
                ),
                SizedBox(height: theme.spacing.lg),
                Text(
                  'chat_stopRecordingHint'.tr,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
