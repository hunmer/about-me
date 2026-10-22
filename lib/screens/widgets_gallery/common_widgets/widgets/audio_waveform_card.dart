import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 音频波形小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题/日期 / 波形条（数据色实底细条，逐条错峰生长，动画保留）/
/// 翻牌时间 + 数据色墨线播放按钮。
class AudioWaveformCardWidget extends StatefulWidget {
  /// 音频标题
  final String title;

  /// 录制日期
  final String date;

  /// 音频时长
  final Duration duration;

  /// 主题色
  final Color? primaryColor;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const AudioWaveformCardWidget({
    super.key,
    required this.title,
    required this.date,
    required this.duration,
    this.primaryColor,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于通用小组件系统）
  factory AudioWaveformCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    // 解析时长（秒数）
    final durationInSeconds = (props['durationInSeconds'] as num?)?.toInt() ?? 0;
    final duration = Duration(seconds: durationInSeconds);

    return AudioWaveformCardWidget(
      title: props['title'] as String? ?? '未命名音频',
      date: props['date'] as String? ?? '',
      duration: duration,
      primaryColor: props['primaryColor'] != null
          ? Color(props['primaryColor'] as int)
          : null,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<AudioWaveformCardWidget> createState() =>
      _AudioWaveformCardWidgetState();
}

class _AudioWaveformCardWidgetState extends State<AudioWaveformCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 数据色 props 保留，缺省走主题
    final effectivePrimaryColor = widget.primaryColor ?? theme.primary;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : null,
        radius: BorderRadius.circular(24 * widget.size.scale),
        padding: widget.size.getPadding(),
        child: Column(
          children: [
            // 顶部：标题和设置按钮
            _buildHeader(theme),

            // 中间：波形动画
            Expanded(child: _buildWaveform(effectivePrimaryColor, theme)),

            // 底部：时间和播放按钮
            _buildFooter(effectivePrimaryColor, theme),
          ],
        ),
      ),
    );
  }

  /// 构建顶部标题区域
  Widget _buildHeader(AppThemeData theme) {
    final titleAnimation = CurvedAnimation(
      parent: _animation,
      curve: const Interval(0, 0.4, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: titleAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: titleAnimation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: widget.size.getTitleFontSize(),
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: widget.size.getSmallSpacing()),
              Text(
                widget.date,
                style: TextStyle(
                  fontSize: widget.size.getSubtitleFontSize(),
                  fontWeight: FontWeight.w500,
                  color: theme.textSub,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建波形动画
  Widget _buildWaveform(Color primaryColor, AppThemeData theme) {
    final waveformAnimation = CurvedAnimation(
      parent: _animation,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: waveformAnimation,
      builder: (context, child) {
        return _WaveformBars(
          size: widget.size,
          primaryColor: primaryColor,
          theme: theme,
          animation: waveformAnimation,
        );
      },
    );
  }

  /// 构建底部时间和播放按钮
  Widget _buildFooter(Color primaryColor, AppThemeData theme) {
    final footerAnimation = CurvedAnimation(
      parent: _animation,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: footerAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: footerAnimation.value,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TimeDisplay(
                size: widget.size,
                duration: widget.duration,
                animation: footerAnimation,
              ),
              _PlayPauseButton(
                size: widget.size,
                primaryColor: primaryColor,
                animation: footerAnimation,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 波形条组件
///
/// 细条用手绘数据色实底（不适合斜纹）：
/// 已播放淡轨道底、未播放淡墨底、播放位数据色加宽。
class _WaveformBars extends StatelessWidget {
  final HomeWidgetSize size;
  final Color primaryColor;
  final AppThemeData theme;
  final Animation<double> animation;

  const _WaveformBars({
    required this.size,
    required this.primaryColor,
    required this.theme,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    // 模拟波形高度数据 (24个条)
    final heights = [
      12.0,
      20.0,
      25.0,
      12.0,
      24.0,
      32.0,
      16.0,
      28.0,
      20.0,
      12.0,
      24.0,
      40.0,
      20.0,
      28.0,
      56.0,
      24.0,
      12.0,
      32.0,
      20.0,
      12.0,
      20.0,
      28.0,
      24.0,
      12.0,
    ];

    // 根据 size 计算波形条宽度和间距
    final barWidth = size.getBarWidth() * 0.3; // 约 3.6/4.8/6
    final barSpacing = size.getBarSpacing(); // 约 0.5/1.0/1.5
    final playingBarWidth = barWidth * 1.5; // 播放位置的条更宽

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(heights.length, (index) {
        final baseHeight = heights[index];
        final isPlayed = index < 12;
        final isPlayingPosition = index == 12;

        // 计算每个条的延迟动画
        final step = 0.03;
        final start = (index * step).clamp(0.0, 0.7);
        final end = (0.5 + index * step).clamp(0.0, 1.0);
        final itemAnimation = CurvedAnimation(
          parent: animation,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: barSpacing),
          child: _WaveformBar(
            height: baseHeight * itemAnimation.value,
            color:
                isPlayingPosition
                    ? primaryColor
                    : isPlayed
                    ? theme.surfaceAlt
                    : theme.ink.withValues(alpha: 0.12),
            width: isPlayingPosition ? playingBarWidth : barWidth,
            isPlayingPosition: isPlayingPosition,
            primaryColor: primaryColor,
          ),
        );
      }),
    );
  }
}

/// 单个波形条
class _WaveformBar extends StatelessWidget {
  final double height;
  final Color color;
  final double width;
  final bool isPlayingPosition;
  final Color primaryColor;

  const _WaveformBar({
    required this.height,
    required this.color,
    required this.width,
    required this.isPlayingPosition,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isPlayingPosition ? primaryColor : color,
        borderRadius: BorderRadius.circular(width / 2),
      ),
    );
  }
}

/// 时间显示组件
class _TimeDisplay extends StatelessWidget {
  final HomeWidgetSize size;
  final Duration duration;
  final Animation<double> animation;

  const _TimeDisplay({
    required this.size,
    required this.duration,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    // 根据 size 计算时间字体大小
    final timeFontSize = size.getLargeFontSize() * 0.5; // 约 18/24/28
    final timeStyle = TextStyle(
      fontSize: timeFontSize,
      fontWeight: FontWeight.w500,
      color: theme.text,
    );

    return Row(
      children: [
        AnimatedFlipCounter(
          value: hours * animation.value,
          textStyle: timeStyle.copyWith(letterSpacing: 1),
          padding: EdgeInsets.symmetric(horizontal: size.getSmallSpacing()),
        ),
        Text(':', style: timeStyle),
        AnimatedFlipCounter(
          value: minutes * animation.value,
          textStyle: timeStyle.copyWith(letterSpacing: 1),
          padding: EdgeInsets.symmetric(horizontal: size.getSmallSpacing()),
        ),
        Text(':', style: timeStyle),
        AnimatedFlipCounter(
          value: seconds * animation.value,
          textStyle: timeStyle.copyWith(letterSpacing: 1),
          padding: EdgeInsets.symmetric(horizontal: size.getSmallSpacing()),
        ),
      ],
    );
  }
}

/// 播放/暂停按钮组件
class _PlayPauseButton extends StatefulWidget {
  final HomeWidgetSize size;
  final Color primaryColor;
  final Animation<double> animation;

  const _PlayPauseButton({
    required this.size,
    required this.primaryColor,
    required this.animation,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _isPlaying = true;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 根据 size 计算按钮大小和图标大小
    final iconSize = widget.size.getIconSize();
    final buttonSize = iconSize * widget.size.iconContainerScale;

    return Transform.scale(
      scale: widget.animation.value * (_isPressed ? 0.95 : 1.0),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () => setState(() => _isPlaying = !_isPlaying),
        // 数据色实底圆形徽章 + 墨线描边
        child: Container(
          width: buttonSize,
          height: buttonSize,
          // 大圆角被 rough 引擎自动钳制成圆
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(buttonSize / 2),
            fillColor: widget.primaryColor,
          ),
          child: DsIcon(
            _isPlaying ? DsIconKind.pause : DsIconKind.play,
            size: iconSize,
            color: theme.onPrimary,
          ),
        ),
      ),
    );
  }
}
