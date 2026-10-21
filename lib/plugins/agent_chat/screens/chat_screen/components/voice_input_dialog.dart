import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/speech_recognition_service.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/speech_recognition_state.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:aboutme/widgets/siri_voice_assistant_orb_demo.dart';
import '../../../../../../core/services/toast_service.dart';
import '../../../../../../core/services/speech_recognition_config_service.dart';
import '../../../../../../plugins/openai/services/request_service.dart';

/// 语音输入对话框（Siri 流光球卡片风格）
///
/// 功能：
/// - 点击流光球开始/停止录音，长按松开结束
/// - 连续录音自动追加文本
/// - 标点符号替换功能（替换为空文本）
/// - AI智能纠错
/// - 实时显示识别文本与状态
/// - 键盘抽屉编辑文本
/// - 确定发送，取消关闭
class VoiceInputDialog extends StatefulWidget {
  /// 语音识别服务
  final SpeechRecognitionService recognitionService;

  /// 识别完成回调
  final Function(String text) onRecognitionComplete;

  const VoiceInputDialog({
    super.key,
    required this.recognitionService,
    required this.onRecognitionComplete,
  });

  @override
  State<VoiceInputDialog> createState() => _VoiceInputDialogState();
}

class _VoiceInputDialogState extends State<VoiceInputDialog> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _orbController = SiriOrbCardController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  SpeechRecognitionState _currentState = SpeechRecognitionState.idle;

  StreamSubscription<String>? _recognitionSubscription;
  StreamSubscription<SpeechRecognitionState>? _stateSubscription;
  StreamSubscription<String>? _errorSubscription;

  bool _isRecording = false;
  bool _isAppendMode = false; // 是否处于追加模式
  String? _savedText; // 保存的文本用于追加

  // 标点符号替换设置
  bool _enablePunctuationReplacement = false;

  // AI纠错状态
  bool _isCorrecting = false;

  @override
  void initState() {
    super.initState();
    // 识别文本变化时刷新提示区预览与按钮状态
    _textController.addListener(_onTextChanged);
    _initializeService();
  }

  @override
  void dispose() {
    _recognitionSubscription?.cancel();
    _stateSubscription?.cancel();
    _errorSubscription?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  /// 初始化服务
  Future<void> _initializeService() async {
    try {
      await widget.recognitionService.initialize();

      // 监听识别结果（仅在录音状态下更新文本）
      _recognitionSubscription = widget.recognitionService.recognitionStream
          .listen((text) {
            if (!mounted) return;

            // 只有在录音状态下才更新文本，停止录音后不再更新
            if (!_isRecording) return;

            // 应用标点符号替换
            final processedText = _applyPunctuationReplacement(text);

            setState(() {
              if (_isAppendMode &&
                  _savedText != null &&
                  _savedText!.isNotEmpty) {
                // 追加模式：在保存的文本后添加新识别的文本
                _textController.text = _savedText! + processedText;
                // 注意：不清空 _savedText，这样每次识别结果都会追加到原始文本后
              } else {
                // 普通模式：直接替换文本
                _textController.text = processedText;
              }
            });
          });

      // 监听状态变化
      _stateSubscription = widget.recognitionService.stateStream.listen((
        state,
      ) {
        setState(() {
          _currentState = state;
          if (state == SpeechRecognitionState.idle && _isRecording) {
            _isRecording = false;
          }
        });
      });

      // 监听错误
      _errorSubscription = widget.recognitionService.errorStream.listen((
        error,
      ) {
        setState(() {});
        _showErrorSnackBar(error);
      });
    } catch (e) {
      _showErrorSnackBar('初始化失败: $e');
    }
  }

  /// 开始录音
  Future<void> _startRecording({bool isFromTap = false}) async {
    try {
      // 重置追加模式
      _isAppendMode = false;
      _savedText = null;

      // 如果是点击触发的录音且已有文本，保存当前文本用于追加
      if (isFromTap && _textController.text.isNotEmpty) {
        _savedText = _textController.text;
        _isAppendMode = true;
      }

      setState(() {
        _isRecording = true;
      });
      _orbController.pulse();

      // 播放录音开始音效
      try {
        await _audioPlayer.play(AssetSource('audio/start_record.mp3'));
      } catch (e) {
        // 音效播放失败不影响录音功能
      }

      final success = await widget.recognitionService.startRecording();
      if (!success) {
        setState(() {
          _isRecording = false;
          _isAppendMode = false;
          _savedText = null;
        });
        _showErrorSnackBar('开始录音失败');
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isAppendMode = false;
        _savedText = null;
      });
      _showErrorSnackBar('开始录音失败: $e');
    }
  }

  /// 停止录音
  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
      _isAppendMode = false;
      _savedText = null;
    });

    try {
      // 停止录音
      await widget.recognitionService.stopRecording();
    } catch (e) {
      _showErrorSnackBar('停止录音失败: $e');
    }
  }

  /// 取消录音
  Future<void> _cancelRecording() async {
    try {
      await widget.recognitionService.cancelRecording();
    } catch (e) {
      _showErrorSnackBar('取消录音失败: $e');
    } finally {
      setState(() {
        _isRecording = false;
        _textController.clear();
      });
    }
  }

  /// 显示错误提示
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    toastService.showToast(message);
  }

  /// 应用标点符号替换
  String _applyPunctuationReplacement(String text) {
    if (!_enablePunctuationReplacement) return text;

    // 替换中文标点
    text = text.replaceAll(
      RegExp(
        r'[，。！？；：""'
        '（）【】「」『』、]',
      ),
      '',
    );
    // 替换英文标点
    text = text.replaceAll(RegExp(r"[,.!?;:'''()\[\]{}<>]"), '');
    return text;
  }

  /// 切换标点符号替换
  void _togglePunctuationReplacement() {
    setState(() {
      _enablePunctuationReplacement = !_enablePunctuationReplacement;
      // 开启时立即应用替换到当前文本
      if (_enablePunctuationReplacement &&
          _textController.text.isNotEmpty) {
        _textController.text = _applyPunctuationReplacement(
          _textController.text,
        );
      }
    });
  }

  /// 清空文本
  void _clearText() {
    _textController.clear();
    setState(() {
      _savedText = null;
      _isAppendMode = false;
    });
  }

  /// 执行AI智能纠错
  Future<void> _performAICorrection() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showErrorSnackBar('请先输入或录音获取文本');
      return;
    }

    // 检查是否配置了AI纠错Agent
    final configService = SpeechRecognitionConfigService.instance;
    final agent = configService.correctionAgent;

    if (agent == null) {
      // 未配置，提示用户跳转到设置界面
      final shouldGoToSettings = await showDSDialog<bool>(
        context: context,
        theme: DSThemeBridge.resolve(context),
        builder: (dialogContext) => DSThemeBridge(
          child: Builder(
            builder: (ctx) => DSDialog(
              title: 'AI智能纠错',
              message: '您还未配置AI纠错助手。是否跳转到设置界面进行配置？',
              cancelText: '取消',
              confirmText: '去设置',
              onConfirm: () => Navigator.of(dialogContext).pop(true),
              onCancel: () => Navigator.of(dialogContext).pop(false),
            ),
          ),
        ),
      );

      if (shouldGoToSettings == true && mounted) {
        // 关闭当前对话框
        Navigator.of(context).pop();
        // 打开设置界面
        // 注意：这里需要根据实际的设置界面路由来调整
        _showErrorSnackBar('请在设置中配置AI纠错Agent');
      }
      return;
    }

    // 已配置，执行AI纠错
    setState(() {
      _isCorrecting = true;
    });

    try {
      // 构建纠错请求
      final correctionPrompt = '请纠正以下文本中的识别错误，只输出纠正后的文本：\n\n$text';

      // 调用OpenAI服务进行纠错
      final correctedText = await RequestService.chat(correctionPrompt, agent);

      if (correctedText.startsWith('Error:')) {
        _showErrorSnackBar('AI纠错失败：${correctedText.substring(7)}');
      } else {
        // 应用纠错结果
        setState(() {
          _textController.text = correctedText.trim();
        });
        _showErrorSnackBar('AI纠错完成');
      }
    } catch (e) {
      _showErrorSnackBar('AI纠错失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCorrecting = false;
        });
      }
    }
  }

  /// 确认发送
  void _confirmSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showErrorSnackBar('请先录音或输入文本');
      return;
    }

    widget.onRecognitionComplete(text);
    Navigator.of(context).pop(true); // 返回 true 表示确认
  }

  /// 取消并关闭
  void _cancel() {
    if (_isRecording) {
      _cancelRecording();
    }
    Navigator.of(context).pop(false); // 返回 false 表示取消
  }

  /// 流光球动画模式跟随识别状态
  SiriOrbMode get _orbMode {
    switch (_currentState) {
      case SpeechRecognitionState.recording:
        return SiriOrbMode.micSim;
      case SpeechRecognitionState.processing:
        return SiriOrbMode.speaking;
      default:
        return SiriOrbMode.siriListen;
    }
  }

  /// 提示区：识别状态（空文本时附操作指引）
  String get _promptText {
    final status = _isRecording ? '正在录音…' : _currentState.description;
    if (_textController.text.trim().isEmpty) {
      return '$status\n点击流光球开始录音，长按松开结束；右下角键盘可直接输入';
    }
    return status;
  }

  /// 预览行：识别文本，超长时自动跑马灯滚动
  String? get _previewText {
    final text = _textController.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _textController.text.isNotEmpty;
    final sendingDisabled =
        _currentState == SpeechRecognitionState.recording;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SiriOrbCard(
          controller: _orbController,
          mode: _orbMode,
          prompt: _promptText,
          // 识别文本预览（超长自动跑马灯）
          preview: _previewText,
          // 真实麦克风音量驱动流光球能量
          energyStream: widget.recognitionService.volumeStream,
          height: 430,
          input: SiriOrbInput(
            controller: _textController,
            focusNode: _focusNode,
            hint: '识别的文本将显示在这里，您也可以编辑...',
            onSubmitted: (_) => _confirmSend(),
          ),
          topLeft: SiriOrbCorner(
            tooltip: 'agent_chat_cancel'.tr,
            onTap: _cancel,
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
          // 点击流光球：开始/停止录音；长按松开结束
          onOrbTap: () {
            if (_isRecording) {
              _stopRecording();
            } else {
              _startRecording(isFromTap: true);
            }
          },
          onOrbLongPressStart: (_) => _startRecording(isFromTap: false),
          onOrbLongPressEnd: (_) => _stopRecording(),
          actions: [
            SiriOrbAction(
              icon: Icons.spellcheck,
              label: '标点替换',
              highlighted: _enablePunctuationReplacement,
              onTap: _togglePunctuationReplacement,
            ),
            SiriOrbAction(
              icon: Icons.auto_awesome,
              label: _isCorrecting ? '纠错中…' : 'AI纠错',
              highlighted: _isCorrecting,
              onTap: _isCorrecting ? null : () => _performAICorrection(),
            ),
            SiriOrbAction(
              icon: Icons.delete_sweep_outlined,
              label: '清空',
              onTap: hasText ? _clearText : null,
            ),
            SiriOrbAction(
              icon: Icons.send_rounded,
              label: 'agent_chat_send'.tr,
              highlighted: true,
              onTap: sendingDisabled ? null : _confirmSend,
            ),
          ],
        ),
      ),
    );
  }
}
