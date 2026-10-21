import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';

/// 手绘打字机文本：逐字浮现 + 「_」光标闪烁
///
/// [text] 变化时自动重播；[play] 为 false 时直接全显（光标仍闪烁）；
/// 动画减弱（`context.dsAnimationsDisabled`）时直接全显并隐藏光标；
/// 最后一个字打完触发 [onFinished]。
///
/// ```dart
/// DsTypewriter(
///   text: '今天也要好好记录哦',
///   onFinished: () => debugPrint('打完了'),
/// )
/// ```
class DsTypewriter extends StatefulWidget {
  const DsTypewriter({
    super.key,
    required this.text,
    this.perChar = const Duration(milliseconds: 80),
    this.style,
    this.showCursor = true,
    this.cursorPeriod = const Duration(milliseconds: 500),
    this.play = true,
    this.onFinished,
  });

  final String text;

  /// 每个字的间隔
  final Duration perChar;

  /// 文字样式（默认 body + 主题文字色）
  final TextStyle? style;

  /// 是否显示光标
  final bool showCursor;

  /// 光标闪烁半周期（亮/暗各一次 [cursorPeriod]）
  final Duration cursorPeriod;

  /// false = 直接全显（不再打字）
  final bool play;

  /// 打字完成回调（每次重播完成各触发一次）
  final VoidCallback? onFinished;

  @override
  State<DsTypewriter> createState() => _DsTypewriterState();
}

class _DsTypewriterState extends State<DsTypewriter> {
  Timer? _typeTimer;
  Timer? _cursorTimer;

  /// 已打出的字符数
  int _shown = 0;

  /// 光标亮/暗
  bool _cursorOn = true;

  @override
  void initState() {
    super.initState();
    _startCursorBlink();
    // 首帧后起播（initState 内不可做 inherited 查询，如 disableAnimations）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTyping(fromStart: true);
    });
  }

  @override
  void didUpdateWidget(DsTypewriter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      // 文本变化：从头重播
      _syncTyping(fromStart: true);
    } else if (widget.perChar != oldWidget.perChar ||
        widget.play != oldWidget.play) {
      // 节奏/播放状态变化：从当前进度续打
      _syncTyping(fromStart: false);
    }
    if (widget.cursorPeriod != oldWidget.cursorPeriod) {
      _startCursorBlink();
    }
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  /// 对齐打字状态：全显（不播/动画减弱）或（重）启动逐字计时器
  void _syncTyping({required bool fromStart}) {
    if (fromStart) _shown = 0;
    final disabled = context.dsAnimationsDisabled;
    _typeTimer?.cancel();
    _typeTimer = null;
    if (!widget.play || disabled || _shown >= widget.text.length) {
      if (!widget.play || disabled) {
        // 静态全显：直接跳到终态（不补发 onFinished，只在实际「打完」时触发）
        if (_shown != widget.text.length) {
          setState(() => _shown = widget.text.length);
        }
      }
      return;
    }
    _typeTimer = Timer.periodic(widget.perChar, _tick);
  }

  void _tick(Timer timer) {
    if (_shown >= widget.text.length) {
      timer.cancel();
      _typeTimer = null;
      return;
    }
    setState(() => _shown++);
    if (_shown >= widget.text.length) {
      timer.cancel();
      _typeTimer = null;
      widget.onFinished?.call();
    }
  }

  void _startCursorBlink() {
    _cursorTimer?.cancel();
    _cursorTimer = null;
    _cursorOn = true;
    if (!widget.showCursor) return;
    _cursorTimer = Timer.periodic(widget.cursorPeriod, (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final disabled = context.dsAnimationsDisabled;

    final shownText = widget.text.substring(
      0,
      _shown.clamp(0, widget.text.length),
    );
    // 光标「_」：亮暗交替；灭的半周期用不间断空格占位，避免文字抖动
    final text =
        widget.showCursor && !disabled
        ? '$shownText${_cursorOn ? '_' : '\u00A0'}'
        : shownText;

    return Text(
      text,
      style: widget.style ?? DsTypography.body.copyWith(color: theme.text),
    );
  }
}
