import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/achievement/models/achievement_definition.dart';

/// 成就徽章：图标 + 等级边框（Lv1 灰铁 / Lv2 青铜 / Lv3 白银 / Lv4 黄金 / Lv5 彩虹流光）
///
/// level = 0 表示未解锁（图标灰化 + 灰边框）
class AchievementBadge extends StatefulWidget {
  const AchievementBadge({
    super.key,
    required this.iconAsset,
    required this.level,
    this.size = 56,
    this.showLevelTag = false,
  });

  final String iconAsset;
  final int level;
  final double size;

  /// 是否在右下角显示 Lv 角标
  final bool showLevelTag;

  @override
  State<AchievementBadge> createState() => _AchievementBadgeState();
}

class _AchievementBadgeState extends State<AchievementBadge>
    with SingleTickerProviderStateMixin {
  AnimationController? _flowController;

  @override
  void initState() {
    super.initState();
    _updateFlow();
  }

  @override
  void didUpdateWidget(AchievementBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _updateFlow();
    }
  }

  /// Lv5 彩虹流光需要常驻动画
  void _updateFlow() {
    if (widget.level >= 5) {
      _flowController ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat();
    } else {
      _flowController?.stop();
    }
  }

  @override
  void dispose() {
    _flowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = widget.size;
    final level = widget.level;
    final unlocked = level > 0;
    final borderColors = unlocked
        ? (level >= 5
            ? AchievementLevels.rainbowColors
            : [AchievementLevels.borderColor(level), AchievementLevels.borderColor(level)])
        : [theme.disabledColor, theme.disabledColor];

    Widget badge = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 边框层（Lv5 旋转彩虹渐变，其余纯色）
          _buildBorder(borderColors),
          // 图标层
          Padding(
            padding: EdgeInsets.all(size * 0.11),
            child: _buildIcon(theme, unlocked),
          ),
        ],
      ),
    );

    if (widget.showLevelTag) {
      badge = Stack(
        clipBehavior: Clip.none,
        children: [
          badge,
          Positioned(
            right: -2,
            bottom: -2,
            child: _buildLevelTag(theme, level),
          ),
        ],
      );
    }
    return badge;
  }

  Widget _buildBorder(List<Color> colors) {
    final isRainbow = colors.length > 2;
    Widget border = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isRainbow
            ? SweepGradient(colors: colors)
            : LinearGradient(colors: colors),
      ),
    );
    if (isRainbow && _flowController != null) {
      border = AnimatedBuilder(
        animation: _flowController!,
        builder: (context, child) => Transform.rotate(
          angle: _flowController!.value * 2 * math.pi,
          child: child,
        ),
        child: border,
      );
    }
    return border;
  }

  Widget _buildIcon(ThemeData theme, bool unlocked) {
    Widget icon = ClipOval(
      child: Image.asset(
        widget.iconAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.emoji_events_outlined,
          size: widget.size * 0.5,
          color: theme.disabledColor,
        ),
      ),
    );
    if (!unlocked) {
      // 灰度 + 半透明，保留轮廓神秘感
      icon = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 0.6, 0,
        ]),
        child: icon,
      );
    }
    return icon;
  }

  Widget _buildLevelTag(ThemeData theme, int level) {
    final color = level > 0 ? AchievementLevels.borderColor(level) : theme.disabledColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        level > 0 ? '$level' : '-',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          height: 1,
        ),
      ),
    );
  }
}
