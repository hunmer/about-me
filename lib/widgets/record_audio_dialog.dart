import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/blob_url.dart';

class RecordAudioDialog extends StatefulWidget {
  /// amplitudes 为录音期间的振幅采样（dBFS），用于还原真实波形
  final Function(File audioFile, Duration duration, List<double> amplitudes)
      onStop;

  /// Web 平台录音回调：无本地文件，返回字节内容和文件名
  final Function(
    Uint8List bytes,
    String fileName,
    Duration duration,
    List<double> amplitudes,
  )?
      onStopBytes;

  const RecordAudioDialog({
    super.key,
    required this.onStop,
    this.onStopBytes,
  });

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
  final List<double> _amplitudes = [];
  StreamSubscription<Amplitude>? _amplitudeSub;

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
    _amplitudeSub?.cancel();
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
                        title: 'record_failed'.tr,
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
    // Web 平台 record 插件忽略本地路径，仅桌面需要临时目录
    final String filePath;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) {
      filePath = 'audio_$timestamp.webm';
    } else {
      final tempDir = await getTemporaryDirectory();
      filePath = path.join(tempDir.path, 'audio_$timestamp.m4a');
    }

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

      // 采集振幅（dBFS）用于生成消息波形
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) => _amplitudes.add(amp.current));
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

    _amplitudeSub?.cancel();
    _amplitudeSub = null;

    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        if (kIsWeb) {
          // Web 上 stop() 返回 blob URL，读取字节后走字节回调
          final bytes = await readBlobBytes(path);
          final extension = path.split('.').last.toLowerCase();
          final fileName = extension.isEmpty || extension.contains('/')
              ? 'audio.webm'
              : 'audio.$extension';
          widget.onStopBytes?.call(bytes, fileName, _duration, _amplitudes.toList());
        } else {
          final file = File(path);
          widget.onStop(file, _duration, _amplitudes.toList());
        }
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
                        title: 'record_failed'.tr,
                        message: 'record_stopError'.tr,
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
                  'record_title'.tr,
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
                  'record_stopHint'.tr,
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
