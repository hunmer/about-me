import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// 角色头顶的对话气泡：白色胶囊 + 下垂小尾巴
///
/// 胶囊与尾巴合并为同一路径一次填充/描边（Path union），
/// 不会有「底边描边穿过尾巴根部」的接缝横线。
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
    this.bubbleAsset,
    this.modelName,
  });

  final String text;
  final VoidCallback? onTap;

  /// 打字效果完成后回调一次（用于延迟隐藏气泡）
  final VoidCallback? onTypingComplete;

  /// 每个字的浮现间隔
  final Duration typingInterval;
  final bool streaming;
  final VoidCallback? onUserInteract;
  final String? bubbleAsset;
  final String? modelName;

  /// 尾巴高度（画在胶囊边界之外，下方 Padding 负责占位）
  static const double tailHeight = 13;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (modelName != null && modelName!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              modelName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.primaryText,
              ),
            ),
          ),
        Expanded(
          child: _ScrollableBubbleText(
            text: text,
            interval: typingInterval,
            onComplete: onTypingComplete,
            style: DsTypography.button.copyWith(
              fontSize: 15,
              color: theme.primaryText,
            ),
            streaming: streaming,
            onUserInteract: onUserInteract,
          ),
        ),
      ],
    );
    final bubble = Padding(
      padding: const EdgeInsets.only(bottom: tailHeight + 2),
      child: CustomPaint(
        painter: bubbleAsset == null
            ? _BubblePainter(
                fill: theme.surface,
                line: theme.primary.withValues(alpha: 0.30),
                shadows: theme.shadows.soft,
                tailHeight: tailHeight,
              )
            : null,
        child: Container(
          decoration: bubbleAsset == null
              ? null
              : BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(bubbleAsset!),
                    fit: BoxFit.fill,
                    // Keep the decorative border fixed while the center expands.
                    centerSlice: const Rect.fromLTWH(500, 300, 1000, 400),
                  ),
                ),
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.xl,
            vertical: theme.spacing.md,
          ),
          child: content,
        ),
      ),
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
          if (event is! PointerScrollEvent || !_scrollController.hasClients)
            return;
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
          constraints: const BoxConstraints(minHeight: 24, maxHeight: 72),
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              _userScrolling = notification.direction != ScrollDirection.idle;
              widget.onUserInteract?.call();
              return false;
            },
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                  ],
                  stops: [0.0, 0.16, 1.0],
                ).createShader(bounds),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: SizedBox(
                      width: double.infinity,
                      child: widget.text == '...'
                          ? const SizedBox(
                              height: 24,
                              child: Center(
                                child: Text('...', textAlign: TextAlign.center),
                              ),
                            )
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
        ),
      ),
    );
  }
}

/// 胶囊 + 尾巴一体绘制：
/// 先 Path.union 合并两个子路径，再依次画阴影、填充、描边——
/// 描边沿合并后的外轮廓走一圈，尾巴与胶囊天然无缝。
class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.fill,
    required this.line,
    required this.shadows,
    required this.tailHeight,
  });

  final Color fill;
  final Color line;
  final List<BoxShadow> shadows;
  final double tailHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final capsule = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      );

    // 尾巴根部往胶囊里压 2px，保证 union 后完全一体
    final baseY = size.height - 2;
    final tipX = size.width * 0.44;
    final tipY = size.height + tailHeight;
    const halfTail = 13.0;
    final tail = Path()
      ..moveTo(size.width / 2 - halfTail, baseY)
      ..quadraticBezierTo(tipX - 4, baseY + tailHeight * 0.6, tipX, tipY)
      ..quadraticBezierTo(
        tipX + 8,
        baseY + tailHeight * 0.5,
        size.width / 2 + halfTail,
        baseY,
      )
      ..close();

    final shape = Path.combine(PathOperation.union, capsule, tail);

    for (final shadow in shadows) {
      canvas.drawPath(
        shape.shift(shadow.offset),
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma),
      );
    }
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = line,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.line != line ||
      oldDelegate.tailHeight != tailHeight;
}

/// 逐字浮现的文本（打字机效果）
class TypewriterText extends StatefulWidget {
  const TypewriterText(
    this.text, {
    super.key,
    this.style,
    this.interval = const Duration(milliseconds: 110),
    this.onComplete,
  });

  final String text;
  final TextStyle? style;
  final Duration interval;

  /// 全部字符浮现完毕后回调一次
  final VoidCallback? onComplete;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  Timer? _timer;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (widget.text.startsWith(oldWidget.text) &&
          _shown <= oldWidget.text.length) {
        _timer?.cancel();
        _timer = Timer.periodic(widget.interval, _tick);
      } else {
        setState(_restart);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _shown = 0;
    if (widget.text.isEmpty) {
      widget.onComplete?.call();
      return;
    }
    _timer = Timer.periodic(widget.interval, _tick);
  }

  void _tick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    setState(() => _shown++);
    if (_shown >= widget.text.length) {
      timer.cancel();
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.text.substring(
      0,
      _shown.clamp(0, widget.text.length),
    );
    return Text(visible, style: widget.style);
  }
}
