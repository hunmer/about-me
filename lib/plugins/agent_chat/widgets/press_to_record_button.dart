import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/speech_recognition_service.dart';
import 'package:aboutme/plugins/agent_chat/services/speech/speech_recognition_state.dart';
import 'package:aboutme/widgets/audio_ui_replica/shazam_pill.dart';
import 'package:universal_platform/universal_platform.dart';

/// 点击录音按钮组件
///
/// 功能：
/// - 点击开始录音，再次点击停止录音
/// - 移动端支持震动反馈
/// - 实时将识别结果输出到目标输入框
/// - 显示录音状态视觉反馈
/// - 可自定义图标、颜色、大小
///
/// 使用示例：
/// ```dart
/// PressToRecordButton(
///   textController: _textController,
///   recognitionService: myRecognitionService,
///   icon: Icon(Icons.mic),
/// )
/// ```
class PressToRecordButton extends StatefulWidget {
  /// 目标输入框控制器（识别结果将添加到此输入框）
  final TextEditingController textController;

  /// 语音识别服务
  final SpeechRecognitionService recognitionService;

  /// 自定义图标（默认为 Icons.mic）
  final Widget? icon;

  /// 按钮大小（默认为标准 IconButton 大小）
  final double? size;

  /// 按钮颜色（默认为主题色）
  final Color? color;

  /// 录音时的颜色（默认为红色）
  final Color? recordingColor;

  /// 是否禁用按钮
  final bool enabled;

  /// 工具提示文本
  final String? tooltip;

  /// 录音完成回调（可选）
  final Function(String text)? onRecognitionComplete;

  /// 录音失败回调（可选）
  final Function(String error)? onError;

  /// 长按回调（可选，如打开录音对话框）
  final VoidCallback? onLongPress;

  const PressToRecordButton({
    super.key,
    required this.textController,
    required this.recognitionService,
    this.icon,
    this.size,
    this.color,
    this.recordingColor,
    this.enabled = true,
    this.tooltip,
    this.onRecognitionComplete,
    this.onError,
    this.onLongPress,
  });

  @override
  State<PressToRecordButton> createState() => _PressToRecordButtonState();
}

class _PressToRecordButtonState extends State<PressToRecordButton>
    with SingleTickerProviderStateMixin {
  String _recognizedText = '';
  bool _isRecording = false;
  bool _isInitialized = false;

  /// 录音开始前输入框中的文本
  String _textBeforeRecording = '';

  /// 录音开始前光标的位置
  int _cursorPositionBeforeRecording = 0;

  StreamSubscription<String>? _recognitionSubscription;
  StreamSubscription<SpeechRecognitionState>? _stateSubscription;
  StreamSubscription<String>? _errorSubscription;

  // 录音时顶部的 Shazam 风格状态胶囊浮层（实时展示转写文本）
  OverlayEntry? _pillOverlay;
  final GlobalKey<_RecordingPillHostState> _pillKey = GlobalKey();
  String _liveText = '';

  // 动画控制器
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeService();
  }

  /// 初始化动画
  void _initializeAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _removeRecordingPill();
    _recognitionSubscription?.cancel();
    _stateSubscription?.cancel();
    _errorSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// 初始化语音识别服务
  Future<void> _initializeService() async {
    try {
      await widget.recognitionService.initialize();

      // 监听识别结果并实时更新到输入框
      _recognitionSubscription = widget.recognitionService.recognitionStream
          .listen((text) {
            setState(() {
              _recognizedText = text;
            });

            // 同步实时文本到顶部胶囊
            _liveText = text;
            _refreshRecordingPill();

            // 实时更新到输入框
            if (_isRecording && text.isNotEmpty) {
              _updateTextController(text);
            }
          });

      // 监听状态变化
      _stateSubscription = widget.recognitionService.stateStream.listen((
        state,
      ) {
        if (state == SpeechRecognitionState.idle && _isRecording) {
          setState(() {
            _isRecording = false;
          });
          // 播放收起动画后再移除浮层
          _pillKey.currentState?.dismiss();
          _onRecordingComplete();
        }
      });

      // 监听错误
      _errorSubscription = widget.recognitionService.errorStream.listen((
        error,
      ) {
        _handleError(error);
      });

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('初始化语音识别服务失败: $e');
      _handleError('初始化失败: $e');
    }
  }

  /// 开始录音
  Future<void> _startRecording() async {
    if (!widget.enabled || !_isInitialized || _isRecording) return;

    try {
      // 保存录音开始前的文本和光标位置
      _textBeforeRecording = widget.textController.text;
      _cursorPositionBeforeRecording =
          widget.textController.selection.baseOffset;
      // 如果光标位置无效（-1），则使用文本末尾
      if (_cursorPositionBeforeRecording < 0 ||
          _cursorPositionBeforeRecording > _textBeforeRecording.length) {
        _cursorPositionBeforeRecording = _textBeforeRecording.length;
      }

      setState(() {
        _isRecording = true;
        _recognizedText = '';
        _liveText = '';
      });

      // 启动循环缩放动画
      _animationController.repeat(reverse: true);

      final success = await widget.recognitionService.startRecording();
      if (success) {
        // 录音激活确认反馈（移动端）
        if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
          HapticFeedback.heavyImpact();
        }
        _showRecordingPill();
      } else {
        setState(() {
          _isRecording = false;
        });
        // 停止动画
        _animationController.stop();
        _animationController.reset();
        _handleError('开始录音失败');
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      // 停止动画
      _animationController.stop();
      _animationController.reset();
      _handleError('开始录音失败: $e');
    }
  }

  /// 停止录音
  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    // 立即停止动画并更新状态
    _animationController.stop();
    _animationController.reset();

    // 停止确认反馈（移动端）
    if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
      HapticFeedback.lightImpact();
    }

    try {
      await widget.recognitionService.stopRecording();
    } catch (e) {
      _handleError('停止录音失败: $e');
    }
  }

  /// 切换录音状态（点击时调用）
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  /// 实时更新文本控制器
  void _updateTextController(String recognizedText) {
    if (recognizedText.isEmpty) return;

    // 将识别的文本插入到开始录音时的光标位置
    final beforeCursor = _textBeforeRecording.substring(
      0,
      _cursorPositionBeforeRecording,
    );
    final afterCursor = _textBeforeRecording.substring(
      _cursorPositionBeforeRecording,
    );

    // 构建新文本：光标前 + 识别文本 + 光标后
    final newText = beforeCursor + recognizedText + afterCursor;

    widget.textController.text = newText;

    // 将光标移动到插入文本的末尾
    final newCursorPosition =
        _cursorPositionBeforeRecording + recognizedText.length;
    widget.textController.selection = TextSelection.fromPosition(
      TextPosition(offset: newCursorPosition),
    );
  }

  /// 录音完成时的处理
  void _onRecordingComplete() {
    if (_recognizedText.isNotEmpty) {
      // 文本已经通过实时更新添加到输入框了，这里只需要触发回调
      widget.onRecognitionComplete?.call(_recognizedText);

      // 清空识别文本
      setState(() {
        _recognizedText = '';
      });
    }
  }

  /// 处理错误
  void _handleError(String error) {
    debugPrint('语音识别错误: $error');
    _pillKey.currentState?.dismiss();
    widget.onError?.call(error);
  }

  /// 顶部展示录音状态胶囊（Shazam 风格，实时转写文本）
  void _showRecordingPill() {
    _removeRecordingPill();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _pillOverlay = OverlayEntry(
      builder:
          (context) => _RecordingPillHost(
            key: _pillKey,
            subtitle: _liveText.isEmpty ? '语音识别中' : _liveText,
            onClose: _stopRecording,
            onDismissed: _removeRecordingPill,
          ),
    );
    overlay.insert(_pillOverlay!);
  }

  void _removeRecordingPill() {
    _pillOverlay?.remove();
    _pillOverlay = null;
  }

  /// 识别文本变化时刷新胶囊内容
  void _refreshRecordingPill() {
    _pillOverlay?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final iconWidget = widget.icon ?? DsIcon(DsIconKind.mic);
    final buttonColor =
        _isRecording
            ? (widget.recordingColor ?? theme.danger)
            : (widget.color ?? theme.textSub);
    final tooltipText = widget.tooltip ?? (_isRecording ? '点击停止录音' : '点击开始录音');

    return Tooltip(
      message: tooltipText,
      child: Pressable(
        onPressed: widget.enabled && _isInitialized ? _toggleRecording : null,
        onLongPress:
            widget.enabled && _isInitialized ? widget.onLongPress : null,
        semanticLabel: tooltipText,
        builder:
            (context, states) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final scale = _isRecording ? _scaleAnimation.value : 1.0;

                  return Transform.scale(
                    scale: scale,
                    child:
                        _isRecording
                            ? Container(
                              // 录音激活：红色圆形背景 + 白色图标
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: buttonColor,
                              ),
                              child: IconTheme(
                                data: IconThemeData(
                                  color: Colors.white,
                                  size: widget.size ?? 24.0,
                                ),
                                child: iconWidget,
                              ),
                            )
                            : IconTheme(
                              data: IconThemeData(
                                color: buttonColor,
                                size: widget.size ?? 24.0,
                              ),
                              child: iconWidget,
                            ),
                  );
                },
              ),
            ),
      ),
    );
  }
}

/// 顶部录音胶囊浮层宿主：负责灵动岛式展开/收起过渡动画
/// （缩放 0.82↔1.0 + 淡入淡出，350ms 弹性曲线，与 demo 页一致）
class _RecordingPillHost extends StatefulWidget {
  const _RecordingPillHost({
    super.key,
    required this.subtitle,
    required this.onClose,
    required this.onDismissed,
  });

  final String subtitle;
  final VoidCallback onClose;

  /// 收起动画完成后回调（由外部移除 OverlayEntry）
  final VoidCallback onDismissed;

  @override
  State<_RecordingPillHost> createState() => _RecordingPillHostState();
}

class _RecordingPillHostState extends State<_RecordingPillHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 0, // 0 = 收起/透明，1 = 展开
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _ctrl,
    curve: const Cubic(0.22, 1, 0.36, 1),
  );
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  /// 播放收起动画，完成后回调 onDismissed（由外部移除浮层）
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _ctrl.reverse().whenCompleteOrCancel(() {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 12,
          left: 24,
          right: 24,
        ),
        child: FadeTransition(
          opacity: _curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.82, end: 1.0).animate(_curve),
            child: ShazamPill(
              animated: !_dismissed,
              title: '正在聆听…',
              subtitle: widget.subtitle,
              onLogoTap: () {},
              onClose: widget.onClose,
            ),
          ),
        ),
      ),
    );
  }
}
