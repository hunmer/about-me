import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/day/models/memorial_day.dart';
import 'package:aboutme/plugins/day/widgets/memorial_background.dart';

/// 手绘里程碑卡片（Warm Paper Sketch 风）
///
/// 复刻设计稿 stitch_design_system_framework 的纪念日卡片：
/// - 墨色错位底影（lifted paper，rough 实底自带抖动，形成 marker offset）
/// - 右上淡彩晕染 + 半透明幽灵涂鸦图标
/// - 状态标签 pill / 大数字天数 / 标题 / 日期 / 底部首条笔记或周期进度条
class SketchMilestoneCard extends StatelessWidget {
  const SketchMilestoneCard({
    super.key,
    required this.memorialDay,
    this.index = 0,
    this.isDraggable = false,
    this.onTap,
    this.onLongPress,
  });

  final MemorialDay memorialDay;

  /// 列表下标，用于让每张卡的墨迹 seed 不同
  final int index;

  /// 手动排序模式下长按被拖拽接管，不弹菜单
  final bool isDraggable;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final isDark = theme.isDark;
    // 强调色来自数据（用户为每个纪念日选的背景色）
    final accent = memorialDay.backgroundColor;
    final radius = theme.radii.lg;
    final seed = index + 1;

    final isUpcoming = !memorialDay.isExpired;
    final numberColor =
        memorialDay.isToday
            ? theme.danger
            : isUpcoming
            ? theme.primary
            : theme.text;

    return Pressable(
      onPressed: onTap,
      onLongPress: isDraggable ? null : onLongPress,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.scale(
          scale: pressed ? 0.97 : 1.0,
          child: Stack(
            children: [
              // 墨色错位底影：手绘 lifted paper
              Positioned.fill(
                child: Transform.translate(
                  offset: const Offset(3, 3),
                  child: DecoratedBox(
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.ink.withValues(
                        alpha: isDark ? 0.45 : 0.85,
                      ),
                      radius: radius,
                      seed: seed + 97,
                    ),
                  ),
                ),
              ),
              // 主卡面：纸底/背景图 + 内容 + 顶层墨线
              Stack(
                children: [
                  // 圆角裁剪的背景组：纸底 + 背景图片 + 淡彩晕染
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: radius,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: theme.surface),
                          if (memorialDay.backgroundImageUrl != null)
                            MemorialBackgroundImage(
                              imageUrl: memorialDay.backgroundImageUrl!,
                              dimAlpha: isDark ? 0.55 : 0.5,
                            ),
                          // 右上淡彩晕染
                          Positioned(
                            top: -30,
                            right: -30,
                            child: Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: isDark ? 0.12 : 0.16,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 幽灵涂鸦图标
                  Positioned(
                    top: 6,
                    right: 8,
                    child: IgnorePointer(
                      child: WiredIcon(
                        icon: memorialDay.icon ?? Icons.favorite_border,
                        size: 52,
                        color: accent.withValues(
                          alpha: isDark ? 0.38 : 0.22,
                        ),
                        drawConfig: theme.wired.drawConfig,
                      ),
                    ),
                  ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTagPill(theme, accent, isDark, seed),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _formatCount(_dayNumber),
                                    style: DsTypography.display.copyWith(
                                      fontSize: 32,
                                      color: numberColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _unitLabel,
                                    style: DsTypography.label.copyWith(
                                      color: theme.textSub,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                memorialDay.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsTypography.heading.copyWith(
                                  color: theme.text,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _dotDate,
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child:
                                        memorialDay.notes.isNotEmpty
                                            ? Text(
                                              memorialDay.notes.first,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: DsTypography.caption
                                                  .copyWith(
                                                    color: theme.textSub,
                                                  ),
                                            )
                                            : _buildProgressTrack(
                                              accent,
                                              _cycleProgress,
                                            ),
                                  ),
                                  if (memorialDay.notes.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    DSBadge(
                                      label: 'day_notesCount'.trParams({
                                        'count':
                                            memorialDay.notes.length
                                                .toString(),
                                      }),
                                      color: accent.withValues(
                                        alpha: isDark ? 0.35 : 1.0,
                                      ),
                                      textColor: theme.text,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 顶层墨线描边（盖住背景图，保持手绘边框完整）
                    Positioned.fill(
                      child: IgnorePointer(
                        child: SketchStrokeOverlay(
                          theme: theme,
                          radius: radius,
                          seed: seed,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  /// 状态标签 pill：纯色实底 + 细墨线（小控件档）
  Widget _buildTagPill(
    AppThemeData theme,
    Color accent,
    bool isDark,
    int seed,
  ) {
    final label =
        memorialDay.isToday
            ? 'day_tagToday'.tr
            : memorialDay.isExpired
            ? 'day_tagPassed'.tr
            : 'day_tagCountdown'.tr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: accent.withValues(alpha: isDark ? 0.35 : 1.0),
        radius: BorderRadius.circular(6),
        strokeWidth: 1.2,
        seed: seed + 3,
      ),
      child: Text(
        label,
        style: DsTypography.label.copyWith(color: theme.text),
      ),
    );
  }

  /// 手绘进度条：淡彩轨道 + 实色填充
  Widget _buildProgressTrack(Color accent, double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: accent.withValues(alpha: 0.25),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          child: Container(color: accent),
        ),
      ),
    );
  }

  int get _dayNumber =>
      memorialDay.isExpired ? memorialDay.daysPassed : memorialDay.daysRemaining;

  String get _unitLabel =>
      memorialDay.isExpired || memorialDay.isToday
          ? 'day_unitDays'.tr
          : 'day_unitDaysAfter'.tr;

  /// 设计稿日期样式：2021.05.20
  String get _dotDate {
    final d = memorialDay.targetDate;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}.${two(d.month)}.${two(d.day)}';
  }

  /// 千分位：1314 → 1,314
  static String _formatCount(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final rem = s.length - i;
      if (rem > 1 && rem % 3 == 1) buf.write(',');
    }
    return n < 0 ? '-$buf' : buf.toString();
  }

  /// 周期进度：未来事件按创建→目标推进；已过事件按周年循环推进
  double get _cycleProgress {
    final now = DateTime.now();
    if (memorialDay.targetDate.isAfter(now)) {
      final total = memorialDay.targetDate.difference(
        memorialDay.creationDate,
      ).inDays;
      if (total <= 0) return 0;
      return (now.difference(memorialDay.creationDate).inDays / total).clamp(
        0.0,
        1.0,
      );
    }
    final today = DateTime(now.year, now.month, now.day);
    final t = memorialDay.targetDate;
    var next = DateTime(now.year, t.month, t.day);
    if (!next.isAfter(today)) {
      next = DateTime(now.year + 1, t.month, t.day);
    }
    final daysToNext = next.difference(today).inDays;
    return ((365 - daysToNext) / 365).clamp(0.0, 1.0);
  }
}
