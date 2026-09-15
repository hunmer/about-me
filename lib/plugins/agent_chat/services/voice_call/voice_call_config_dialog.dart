import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/models/voice_call_config.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

/// 语音通话配置对话框
class VoiceCallConfigDialog extends StatefulWidget {
  final VoiceCallConfig initialConfig;

  const VoiceCallConfigDialog({super.key, required this.initialConfig});

  @override
  State<VoiceCallConfigDialog> createState() => _VoiceCallConfigDialogState();
}

class _VoiceCallConfigDialogState extends State<VoiceCallConfigDialog> {
  late VoiceCallConfig _config;
  late bool _autoContinue;
  late bool _autoRecordAfterSpeaking;
  late bool _enableWelcomeMessage;
  late int _maxTurns;
  late int _recordingTimeout;
  late int _autoSendTimeout;
  late String _welcomeMessage;
  String? _backgroundImagePath;

  List<TTSServiceConfig> _ttsServices = [];
  bool _isLoadingServices = true;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _autoContinue = _config.autoContinue;
    _autoRecordAfterSpeaking = _config.autoRecordAfterSpeaking;
    _enableWelcomeMessage = _config.enableWelcomeMessage;
    _maxTurns = _config.maxTurns;
    _recordingTimeout = _config.recordingTimeout;
    _autoSendTimeout = _config.autoSendTimeout;
    _welcomeMessage = _config.welcomeMessage;
    _backgroundImagePath = _config.backgroundImagePath;
    _loadTTSServices();
  }

  /// 加载TTS服务列表
  Future<void> _loadTTSServices() async {
    try {
      final ttsPlugin = TTSPlugin.instance;
      final services = await ttsPlugin.managerService.getAllServices();

      setState(() {
        _ttsServices = services;
        _isLoadingServices = false;
      });
    } catch (e) {
      debugPrint('加载TTS服务失败: $e');
      setState(() {
        _isLoadingServices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.xl),
      constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DsIcon(DsIconKind.mic, color: theme.primaryText),
              const SizedBox(width: 8),
              Text(
                '语音通话设置',
                style: DsTypography.title.copyWith(color: theme.text),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // TTS服务选择
                _buildTTSServiceSelector(),
                Divider(
                  height: 32,
                  color: theme.textSub.withValues(alpha: 0.2),
                ),

                // 自动继续
                _buildSwitchRow(
                  title: '自动继续对话',
                  subtitle: 'AI回复完成后自动开始下一轮录音',
                  value: _autoContinue,
                  onChanged: (value) {
                    setState(() {
                      _autoContinue = value;
                    });
                  },
                ),

                // 自动录音
                if (_autoContinue)
                  _buildSwitchRow(
                    title: '播报后自动录音',
                    subtitle: 'TTS播报完成后自动开始录音',
                    value: _autoRecordAfterSpeaking,
                    onChanged: (value) {
                      setState(() {
                        _autoRecordAfterSpeaking = value;
                      });
                    },
                  ),

                // 最大对话轮数
                if (_autoContinue)
                  _buildSliderRow(
                    title: '最大对话轮数',
                    subtitle: _maxTurns == 0 ? '无限制' : '$_maxTurns 轮',
                    value: _maxTurns / 20,
                    onChanged: (t) {
                      setState(() {
                        _maxTurns = (t * 20).round();
                      });
                    },
                  ),

                // 录音超时
                _buildSliderRow(
                  title: '录音超时时间',
                  subtitle: '$_recordingTimeout 秒',
                  value: (_recordingTimeout - 10) / 50,
                  onChanged: (t) {
                    setState(() {
                      _recordingTimeout = 10 + (t * 50).round();
                    });
                  },
                ),

                // 自动发送超时
                _buildSliderRow(
                  title: '自动发送超时',
                  subtitle: '停止说话后 $_autoSendTimeout 秒自动发送',
                  value: (_autoSendTimeout - 1) / 9,
                  onChanged: (t) {
                    setState(() {
                      _autoSendTimeout = 1 + (t * 9).round();
                    });
                  },
                ),

                Divider(
                  height: 32,
                  color: theme.textSub.withValues(alpha: 0.2),
                ),

                // 欢迎语
                _buildSwitchRow(
                  title: '启用欢迎语',
                  subtitle: '通话开始时播报欢迎消息',
                  value: _enableWelcomeMessage,
                  onChanged: (value) {
                    setState(() {
                      _enableWelcomeMessage = value;
                    });
                  },
                ),

                // 欢迎语内容
                if (_enableWelcomeMessage)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: DSInput(
                      label: '欢迎语',
                      maxLines: 2,
                      controller: TextEditingController(text: _welcomeMessage),
                      onChanged: (value) {
                        _welcomeMessage = value;
                      },
                    ),
                  ),

                Divider(
                  height: 32,
                  color: theme.textSub.withValues(alpha: 0.2),
                ),

                // 背景图设置
                _buildBackgroundImageSelector(),
              ],
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Row(
            children: [
              Expanded(
                child: DSButton(
                  label: '取消',
                  variant: DSButtonVariant.outline,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: DSButton(
                  label: '保存',
                  onPressed: () {
                    final config = VoiceCallConfig(
                      ttsServiceId: _config.ttsServiceId,
                      autoContinue: _autoContinue,
                      autoRecordAfterSpeaking: _autoRecordAfterSpeaking,
                      maxTurns: _maxTurns,
                      recordingTimeout: _recordingTimeout,
                      autoSendTimeout: _autoSendTimeout,
                      enableWelcomeMessage: _enableWelcomeMessage,
                      welcomeMessage: _welcomeMessage,
                      backgroundImagePath: _backgroundImagePath,
                    );
                    Navigator.pop(context, config);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 开关行
  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = DSThemeBridge.resolve(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: DsTypography.body.copyWith(color: theme.text)),
              Text(
                subtitle,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ],
          ),
        ),
        DSSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  /// 滑杆行（DSSlider 的 value 归一化到 0~1）
  Widget _buildSliderRow({
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                  Text(
                    subtitle,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ],
              ),
            ),
          ],
        ),
        DSSlider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
      ],
    );
  }

  /// 构建背景图选择器
  Widget _buildBackgroundImageSelector() {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '背景图',
          style: DsTypography.heading.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
        const SizedBox(height: 8),
        Pressable(
          onPressed: _pickBackgroundImage,
          semanticLabel: '选择背景图',
          builder:
              (context, states) => Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.surfaceAlt,
                      borderRadius: theme.radii.sm,
                      image:
                          _backgroundImagePath != null
                              ? DecorationImage(
                                // 兼容旧配置的绝对路径与新的存储相对路径
                                image: ImageUtils.createImageProvider(
                                  _backgroundImagePath,
                                ),
                                fit: BoxFit.cover,
                              )
                              : null,
                    ),
                    child:
                        _backgroundImagePath == null
                            ? Center(
                              child: DsIcon(
                                DsIconKind.image,
                                size: 24,
                                color: theme.textSub,
                              ),
                            )
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _backgroundImagePath != null
                              ? path.basename(_backgroundImagePath!)
                              : '未设置',
                          style: DsTypography.body.copyWith(color: theme.text),
                        ),
                        Text(
                          _backgroundImagePath != null ? '点击更换背景图' : '点击选择背景图',
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_backgroundImagePath != null)
                    Pressable(
                      onPressed: () {
                        setState(() {
                          _backgroundImagePath = null;
                        });
                      },
                      semanticLabel: '清除背景图',
                      builder:
                          (context, states) => Padding(
                            padding: const EdgeInsets.all(6),
                            child: DsIcon(
                              DsIconKind.close,
                              size: 20,
                              color: theme.danger,
                            ),
                          ),
                    ),
                ],
              ),
        ),
      ],
    );
  }

  /// 选择背景图
  Future<void> _pickBackgroundImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowCompression: false,
      );

      if (result == null || result.files.isEmpty) return;
      final platformFile = result.files.single;

      // Web 上 FilePicker 只返回字节（path 为 null），统一经字节保存
      final Uint8List imageBytes;
      final String fileExtension;
      if (platformFile.bytes != null) {
        imageBytes = platformFile.bytes!;
        fileExtension = path.extension(platformFile.name).isEmpty
            ? '.png'
            : path.extension(platformFile.name);
      } else if (platformFile.path != null) {
        imageBytes = await File(platformFile.path!).readAsBytes();
        fileExtension = path.extension(platformFile.path!);
      } else {
        return;
      }

      // 经统一存储保存（远端=HTTP 上传，Web=IndexedDB，本地=应用目录）
      final relativePath = await ImageUtils.saveBytesToAppDirectory(
        imageBytes,
        'voice_call_bg',
        extension: fileExtension,
      );

      setState(() {
        _backgroundImagePath = relativePath;
      });
    } catch (e) {
      debugPrint('选择背景图失败: $e');
      if (mounted) {
        toastService.showToast('选择背景图失败: $e');
      }
    }
  }

  /// 构建TTS服务选择器
  Widget _buildTTSServiceSelector() {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TTS 服务',
          style: DsTypography.heading.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingServices)
          const Center(child: DSThemeBridge(child: DSLoadingDots()))
        else if (_ttsServices.isEmpty)
          Text(
            '暂无可用的TTS服务',
            style: DsTypography.body.copyWith(color: theme.textSub),
          )
        else
          DSSelect<String>(
            value: _config.ttsServiceId,
            hint: '选择TTS服务',
            items:
                _ttsServices.where((s) => s.isEnabled).map((service) {
                  return DSSelectItem<String>(
                    value: service.id,
                    label:
                        service.isDefault
                            ? '${service.name} (默认)'
                            : service.name,
                  );
                }).toList(),
            onChanged: (value) {
              setState(() {
                _config = _config.copyWith(ttsServiceId: value);
              });
            },
          ),
      ],
    );
  }
}
