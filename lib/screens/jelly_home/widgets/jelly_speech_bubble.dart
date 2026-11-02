import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// 旧图片气泡素材的文字安全区（历史遗留模型）。
///
/// 图片气泡渲染已移除（统一为 design_system 手绘纸墨风），
/// 此类仅为兼容保留：悬浮桌宠与区域编辑器仍在读写相关设置，
/// 组件渲染不再消费这些坐标。
///
/// 坐标为原图归一化坐标（left/top/right/bottom）。
class BubbleTextRegions {
  const BubbleTextRegions(this.modelName, this.message);

  final Rect modelName;
  final Rect message;

  static const _default = BubbleTextRegions(
    Rect.fromLTRB(0.20, 0.08, 0.42, 0.25),
    Rect.fromLTRB(0.14, 0.30, 0.86, 0.86),
  );

  static BubbleTextRegions forAsset(String? _) => _default;

  static BubbleTextRegions fromSettings(
    String? asset,
    Map<String, dynamic>? settings,
  ) {
    final raw = asset == null ? null : settings?[asset];
    if (raw is! Map) return forAsset(asset);
    double value(String key, double fallback) =>
        (raw[key] as num?)?.toDouble() ?? fallback;
    final base = forAsset(asset);
    return BubbleTextRegions(
      Rect.fromLTRB(
        value('nameLeft', base.modelName.left),
        value('nameTop', base.modelName.top),
        value('nameRight', base.modelName.right),
        value('nameBottom', base.modelName.bottom),
      ),
      Rect.fromLTRB(
        value('messageLeft', base.message.left),
        value('messageTop', base.message.top),
        value('messageRight', base.message.right),
        value('messageBottom', base.message.bottom),
      ),
    );
  }
}

/// 角色头顶的对话气泡：使用 design_system 手绘纸墨风轮廓。
///
/// 由 [DsSpeechBubble] 绘制，外轮廓由 [DsSpeechBubbleShape] 选择；默认胶囊形状，
/// 与全局手绘主题一致。
///
/// 文本带打字机效果（逐字浮现），全部浮现后回调 [onTypingComplete]，
/// 由宿主决定何时收起气泡。
class JellySpeechBubble extends StatelessWidget {
  const JellySpeechBubble({
    super.key,
    required this.text,
    this.onTap,
    this.onTypingComplete,
    this.typingInterval = const Duration(milliseconds: 110),
    this.streaming = false,
    this.onUserInteract,
    this.modelName,
    this.shape = DsSpeechBubbleShape.capsule,
  });

  final String text;
  final VoidCallback? onTap;

  /// 打字效果完成后回调一次（用于延迟隐藏气泡）
  final VoidCallback? onTypingComplete;

  /// 每个字的浮现间隔
  final Duration typingInterval;
  final bool streaming;
  final VoidCallback? onUserInteract;

  /// 顶部标题（角色名）
  final String? modelName;

  /// 手绘气泡轮廓；默认保持原有胶囊形状
  final DsSpeechBubbleShape shape;

  /// 尾巴高度（画在气泡边界之外，下方 Padding 负责占位）
  static const double tailHeight = 13;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    final message = _ScrollableBubbleText(
      text: text,
      interval: typingInterval,
      onComplete: onTypingComplete,
      style: DsTypography.button.copyWith(
        fontSize: 15,
        color: theme.primaryText,
      ),
      streaming: streaming,
      onUserInteract: onUserInteract,
    );
    final bubble = DsSpeechBubble(
      header: modelName,
      shape: shape,
      tailHeight: tailHeight,
      child: message,
    );

    if (onTap == null) return bubble;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) => states.contains(WidgetState.pressed)
          ? Opacity(opacity: 0.85, child: bubble)
          : bubble,
    );
  }
}

class _ScrollableBubbleText extends StatefulWidget {
  const _ScrollableBubbleText({
    required this.text,
    required this.interval,
    required this.onComplete,
    required this.style,
    required this.streaming,
    this.onUserInteract,
  });
  final String text;
  final Duration interval;
  final VoidCallback? onComplete;
  final TextStyle style;
  final bool streaming;
  final VoidCallback? onUserInteract;

  @override
  State<_ScrollableBubbleText> createState() => _ScrollableBubbleTextState();
}

class _ScrollableBubbleTextState extends State<_ScrollableBubbleText> {
  final ScrollController _scrollController = ScrollController();
  Timer? _typeTimer;
  int _shown = 0;
  bool _mouseHovering = false;
  bool _userScrolling = false;

  @override
  void initState() {
    super.initState();
    _restartTyping();
  }

  @override
  void didUpdateWidget(covariant _ScrollableBubbleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.streaming != widget.streaming) {
      if (widget.text.startsWith(oldWidget.text) &&
          _shown <= oldWidget.text.runes.length) {
        _startTypingTimer();
      } else {
        _restartTyping();
      }
    }
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _restartTyping() {
    _typeTimer?.cancel();
    _shown = 0;
    _startTypingTimer();
  }

  void _startTypingTimer() {
    _typeTimer?.cancel();
    if (_shown >= widget.text.runes.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finishTyping());
      return;
    }
    _typeTimer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() => _shown++);
      if (!_mouseHovering && !_userScrolling) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
      if (_shown >= widget.text.runes.length) {
        _typeTimer?.cancel();
        _finishTyping();
      }
    });
  }

  void _finishTyping() {
    if (!mounted || _shown < widget.text.runes.length) return;
    if (!widget.streaming) widget.onComplete?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: true);
    });
  }

  void _scrollToBottom({bool animated = false}) {
    if (!mounted || !_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleText = String.fromCharCodes(widget.text.runes.take(_shown));
    return MouseRegion(
      onEnter: (_) {
        _mouseHovering = true;
        widget.onUserInteract?.call();
      },
      onExit: (_) {
        _mouseHovering = false;
        _userScrolling = false;
        _scrollToBottom(animated: true);
      },
      child: Listener(
        onPointerDown: (_) => widget.onUserInteract?.call(),
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent || !_scrollController.hasClients) {
            return;
          }
          GestureBinding.instance.pointerSignalResolver.register(event, (
            resolvedEvent,
          ) {
            final scroll = resolvedEvent as PointerScrollEvent;
            final position = _scrollController.position;
            final target = (position.pixels + scroll.scrollDelta.dy).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            );
            _userScrolling = true;
            widget.onUserInteract?.call();
            _scrollController.jumpTo(target);
          });
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 72),
          child: IntrinsicWidth(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                _userScrolling = notification.direction != ScrollDirection.idle;
                widget.onUserInteract?.call();
                return false;
              },
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: widget.text == '...'
                      ? const Text('...', textAlign: TextAlign.center)
                      : MarkdownBody(
                          data: visibleText,
                          shrinkWrap: true,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(
                                Theme.of(context),
                              ).copyWith(
                                p: widget.style,
                                h1: widget.style.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                                h2: widget.style.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                                code: widget.style,
                              ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
