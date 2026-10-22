/// 心情追踪圆角柱状小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 图例（数据色手绘色块）/ 手绘胶囊日期徽章 / 斜纹心情柱（数据色浅底 +
/// 浓斜纹 + 描边，淡墨轨道胶囊）/ 手绘表情脸（特殊装饰，CustomPaint 保留）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 正向情绪数据色
const Color _kPositiveColor = Color(0xFF9DB36D);

/// 负向情绪数据色
const Color _kNegativeColor = Color(0xFFE88D3E);

/// 柱状图标数据模型
class BarIconEntry {
  final String dayLabel;
  final double positiveValue;
  final double negativeValue;
  final BarIconType moodType;
  final bool isToday;

  const BarIconEntry({
    required this.dayLabel,
    required this.positiveValue,
    required this.negativeValue,
    required this.moodType,
    this.isToday = false,
  });

  /// 从 JSON 创建
  factory BarIconEntry.fromJson(Map<String, dynamic> json) {
    return BarIconEntry(
      dayLabel: json['dayLabel'] as String? ?? '',
      positiveValue: (json['positiveValue'] as num?)?.toDouble() ?? 0.0,
      negativeValue: (json['negativeValue'] as num?)?.toDouble() ?? 0.0,
      moodType: BarIconTypeExtension.fromJson(json['moodType'] as String? ?? 'positive'),
      isToday: json['isToday'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'dayLabel': dayLabel,
      'positiveValue': positiveValue,
      'negativeValue': negativeValue,
      'moodType': moodType.toJson(),
      'isToday': isToday,
    };
  }
}

/// 心情类型枚举
enum BarIconType {
  positive,
  negative,
}

/// 心情类型扩展
extension BarIconTypeExtension on BarIconType {
  String toJson() => name;

  static BarIconType fromJson(String value) {
    return BarIconType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BarIconType.positive,
    );
  }
}

/// 心情图标类型
enum MoodIconType {
  happy,
  neutralHappy,
  neutral,
  neutralSad,
  neutralFlat,
}

/// 现代化圆角心情追踪小组件
class ModernRoundedBarIconCard extends StatelessWidget {
  final List<BarIconEntry> weekMoods;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const ModernRoundedBarIconCard({
    super.key,
    required this.weekMoods,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory ModernRoundedBarIconCard.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final moodsList = (props['weekMoods'] as List<dynamic>?)
            ?.map((e) => BarIconEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [
          BarIconEntry(
            dayLabel: 'M',
            positiveValue: 0.15,
            negativeValue: 0.0,
            moodType: BarIconType.positive,
          ),
          BarIconEntry(
            dayLabel: 'T',
            positiveValue: 0.25,
            negativeValue: 0.0,
            moodType: BarIconType.positive,
          ),
          BarIconEntry(
            dayLabel: 'W',
            positiveValue: 0.40,
            negativeValue: 0.0,
            moodType: BarIconType.positive,
          ),
          BarIconEntry(
            dayLabel: 'T',
            positiveValue: 0.65,
            negativeValue: 0.0,
            moodType: BarIconType.positive,
          ),
          BarIconEntry(
            dayLabel: 'F',
            positiveValue: 0.85,
            negativeValue: 0.0,
            moodType: BarIconType.positive,
            isToday: true,
          ),
          BarIconEntry(
            dayLabel: 'S',
            positiveValue: 0.0,
            negativeValue: 0.15,
            moodType: BarIconType.negative,
          ),
          BarIconEntry(
            dayLabel: 'S',
            positiveValue: 0.0,
            negativeValue: 0.55,
            moodType: BarIconType.negative,
          ),
        ];

    return ModernRoundedBarIconCard(
      weekMoods: moodsList,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: inline ? double.maxFinite : 380,
        radius: BorderRadius.circular(24 * scale),
        padding: size.getPadding(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme),
            SizedBox(height: size.getTitleSpacing()),
            _buildWeeklyChart(theme),
            const SizedBox(height: 8),
            _buildDayLabels(theme),
            SizedBox(height: size.getItemSpacing()),
            // 淡墨分隔线
            Container(
              height: 1,
              color: theme.ink.withValues(alpha: 0.18),
            ),
            SizedBox(height: size.getItemSpacing()),
            _buildMoodHistory(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildLegend(theme, color: _kPositiveColor, label: 'Positive'),
            SizedBox(width: size.getItemSpacing()),
            _buildLegend(theme, color: _kNegativeColor, label: 'Negative'),
          ],
        ),
        // 手绘胶囊日期徽章
        Container(
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(16),
            fillColor: theme.surfaceAlt,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              DsIcon(DsIconKind.calendar, size: 16, color: theme.textSub),
              const SizedBox(width: 8),
              Text('Monthly', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 4),
              DsIcon(DsIconKind.chevronDown, size: 16, color: theme.textSub),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(AppThemeData theme, {required Color color, required String label}) {
    return Row(
      children: [
        // 手绘图例色块：数据色实底 + 墨线描边
        Container(
          width: 12,
          height: 12,
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(6),
            fillColor: color,
          ),
        ),
        SizedBox(width: size.getItemSpacing()),
        Text(label, style: TextStyle(color: theme.text, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildWeeklyChart(AppThemeData theme) {
    return SizedBox(
      height: 160,
      child: Row(
        children: weekMoods.map((mood) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _buildMoodBar(theme, mood),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 斜纹心情柱（§9.5：数据色浅底 + 浓斜纹 + 描边，淡墨轨道胶囊）
  Widget _buildMoodBar(AppThemeData theme, BarIconEntry mood) {
    final scale = size.scale;
    return SizedBox.expand(
      child: CustomPaint(
        painter: _StripedMoodBarPainter(
          positiveValue: mood.positiveValue,
          negativeValue: mood.negativeValue,
          positiveColor: _kPositiveColor,
          negativeColor: _kNegativeColor,
          theme: theme,
          scale: scale,
        ),
      ),
    );
  }

  Widget _buildDayLabels(AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        children: weekMoods.map((mood) {
          return Expanded(
            child: Center(
              child: Text(mood.dayLabel, style: TextStyle(color: theme.textSub, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMoodHistory(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mood History', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold, fontSize: 20)),
            DsIcon(DsIconKind.more, color: theme.textSub),
          ],
        ),
        SizedBox(height: size.getTitleSpacing()),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMoodIcon(theme, dayLabel: 'Mon', moodType: MoodIconType.happy, isToday: false),
            _buildMoodIcon(theme, dayLabel: 'Tue', moodType: MoodIconType.neutralHappy, isToday: false),
            _buildMoodIcon(theme, dayLabel: 'Wed', moodType: MoodIconType.neutral, isToday: false),
            _buildMoodIcon(theme, dayLabel: 'Thu', moodType: MoodIconType.happy, isToday: false),
            _buildMoodIcon(theme, dayLabel: 'Fri', moodType: MoodIconType.neutralSad, isToday: true),
            _buildMoodIcon(theme, dayLabel: 'Sat', moodType: MoodIconType.neutralFlat, isToday: false),
            _buildMoodIcon(theme, dayLabel: 'Sun', moodType: MoodIconType.happy, isToday: false),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodIcon(AppThemeData theme, {required String dayLabel, required MoodIconType moodType, required bool isToday}) {
    final colors = _getMoodIconColors(moodType);
    final badgeSize = 12 + size.getSmallSpacing() * 2;

    return Column(
      children: [
        Container(
          padding: isToday ? const EdgeInsets.symmetric(horizontal: 6, vertical: 6) : EdgeInsets.zero,
          // 手绘胶囊「今日」高亮
          decoration: isToday
              ? dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(999),
                  fillColor: theme.surfaceAlt,
                )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 手绘表情脸：特殊装饰保留
              CustomPaint(
                size: const Size(40, 40),
                painter: _MoodIconPainter(faceColor: colors.faceColor, eyeColor: colors.eyeColor, mouthType: moodType),
              ),
              if (isToday)
                Positioned(
                  bottom: -4,
                  right: -10,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(badgeSize / 2),
                      fillColor: theme.surfaceAlt,
                    ),
                    padding: EdgeInsets.all(size.getSmallSpacing()),
                    child: Center(
                      child: WiredIcon(
                        icon: Icons.thumb_up,
                        size: 12,
                        color: theme.ink,
                        drawConfig: theme.wired.drawConfig,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: size.getItemSpacing()),
        Text(dayLabel, style: TextStyle(color: isToday ? theme.text : theme.textSub, fontWeight: isToday ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
      ],
    );
  }

  _MoodIconColors _getMoodIconColors(MoodIconType type) {
    switch (type) {
      case MoodIconType.happy:
        return _MoodIconColors(faceColor: const Color(0xFFFBBF24), eyeColor: const Color(0xFF4A3B32));
      case MoodIconType.neutralHappy:
        return _MoodIconColors(faceColor: const Color(0xFF84A95E), eyeColor: const Color(0xFF2D3748));
      case MoodIconType.neutral:
        return _MoodIconColors(faceColor: const Color(0xFF9B80F3), eyeColor: const Color(0xFF2D3748));
      case MoodIconType.neutralSad:
        return _MoodIconColors(faceColor: const Color(0xFFE88D3E), eyeColor: const Color(0xFF4A3B32));
      case MoodIconType.neutralFlat:
        return _MoodIconColors(faceColor: const Color(0xFFBCABA3), eyeColor: const Color(0xFF2D3748));
    }
  }
}

class _MoodIconColors {
  final Color faceColor;
  final Color eyeColor;

  const _MoodIconColors({required this.faceColor, required this.eyeColor});
}

/// 斜纹心情柱绘制器
///
/// 淡墨轨道胶囊（surfaceAlt 底 + 淡墨斜纹 + 淡墨描边）垫底，
/// 数据段自底部铺数据色浅底 + 数据色浓斜纹（0.9）+ 数据色描边（0.85），
/// 正负值同锚底部、负值叠上层，几何保持平直（§9.5）。
class _StripedMoodBarPainter extends CustomPainter {
  final double positiveValue;
  final double negativeValue;
  final Color positiveColor;
  final Color negativeColor;
  final AppThemeData theme;
  final double scale;

  const _StripedMoodBarPainter({
    required this.positiveValue,
    required this.negativeValue,
    required this.positiveColor,
    required this.negativeColor,
    required this.theme,
    required this.scale,
  });

  void _paintSegment(Canvas canvas, Rect rect, Color color) {
    if (rect.height <= 0.5) return;
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      Path()..addRect(rect),
      rect,
      color: color.withValues(alpha: 0.9),
      strokeWidth: 3 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final capsule = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.width / 2),
        ),
      );

    // 轨道胶囊：surfaceAlt 底 + 淡墨斜纹 + 淡墨描边
    canvas.drawPath(capsule, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      capsule,
      Offset.zero & size,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawPath(
      capsule,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );

    // 数据段（胶囊内裁剪）
    canvas.save();
    canvas.clipPath(capsule);
    _paintSegment(
      canvas,
      Rect.fromLTWH(
        0,
        size.height * (1 - positiveValue),
        size.width,
        size.height * positiveValue,
      ),
      positiveColor,
    );
    _paintSegment(
      canvas,
      Rect.fromLTWH(
        0,
        size.height * (1 - negativeValue),
        size.width,
        size.height * negativeValue,
      ),
      negativeColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripedMoodBarPainter oldDelegate) {
    return oldDelegate.positiveValue != positiveValue ||
        oldDelegate.negativeValue != negativeValue ||
        oldDelegate.positiveColor != positiveColor ||
        oldDelegate.negativeColor != negativeColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}

/// 手绘表情脸绘制器（特殊装饰，保留原始几何）
class _MoodIconPainter extends CustomPainter {
  final Color faceColor;
  final Color eyeColor;
  final MoodIconType mouthType;

  _MoodIconPainter({required this.faceColor, required this.eyeColor, required this.mouthType});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final facePaint = Paint()..color = faceColor;
    canvas.drawCircle(center, radius, facePaint);

    final eyePaint = Paint()..color = eyeColor..style = PaintingStyle.fill;

    final leftEye = Offset(center.dx - radius * 0.3, center.dy - radius * 0.15);
    final rightEye = Offset(center.dx + radius * 0.3, center.dy - radius * 0.15);
    final eyeRadius = radius * 0.12;

    if (mouthType == MoodIconType.neutral) {
      _drawCrossEyes(canvas, leftEye, rightEye, eyeRadius, eyePaint);
    } else {
      canvas.drawCircle(leftEye, eyeRadius, eyePaint);
      canvas.drawCircle(rightEye, eyeRadius, eyePaint);
    }

    final mouthPaint = Paint()..color = eyeColor..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;
    _drawMouth(canvas, center, radius, mouthPaint);
  }

  void _drawCrossEyes(Canvas canvas, Offset left, Offset right, double radius, Paint paint) {
    final strokePaint = Paint()..color = paint.color..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    final offset = radius * 0.6;

    canvas.drawLine(Offset(left.dx - offset, left.dy - offset), Offset(left.dx + offset, left.dy + offset), strokePaint);
    canvas.drawLine(Offset(left.dx + offset, left.dy - offset), Offset(left.dx - offset, left.dy + offset), strokePaint);
    canvas.drawLine(Offset(right.dx - offset, right.dy - offset), Offset(right.dx + offset, right.dy + offset), strokePaint);
    canvas.drawLine(Offset(right.dx + offset, right.dy - offset), Offset(right.dx - offset, right.dy + offset), strokePaint);
  }

  void _drawMouth(Canvas canvas, Offset center, double radius, Paint paint) {
    final mouthY = center.dy + radius * 0.25;
    final mouthWidth = radius * 0.5;

    switch (mouthType) {
      case MoodIconType.happy:
        final path = Path();
        path.moveTo(center.dx - mouthWidth, mouthY - radius * 0.1);
        path.quadraticBezierTo(center.dx, mouthY + radius * 0.2, center.dx + mouthWidth, mouthY - radius * 0.1);
        canvas.drawPath(path, paint);
        break;
      case MoodIconType.neutralHappy:
        final path = Path();
        path.moveTo(center.dx - mouthWidth, mouthY);
        path.quadraticBezierTo(center.dx, mouthY + radius * 0.1, center.dx + mouthWidth, mouthY);
        canvas.drawPath(path, paint);
        break;
      case MoodIconType.neutral:
        final path = Path();
        path.moveTo(center.dx - mouthWidth * 0.8, mouthY + radius * 0.1);
        path.quadraticBezierTo(center.dx, mouthY - radius * 0.1, center.dx + mouthWidth * 0.8, mouthY + radius * 0.1);
        canvas.drawPath(path, paint);
        break;
      case MoodIconType.neutralSad:
        final path = Path();
        path.moveTo(center.dx - mouthWidth, mouthY + radius * 0.1);
        path.quadraticBezierTo(center.dx, mouthY - radius * 0.05, center.dx + mouthWidth, mouthY + radius * 0.1);
        canvas.drawPath(path, paint);
        break;
      case MoodIconType.neutralFlat:
        canvas.drawLine(Offset(center.dx - mouthWidth, mouthY), Offset(center.dx + mouthWidth, mouthY), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MoodIconPainter oldDelegate) {
    return oldDelegate.faceColor != faceColor || oldDelegate.eyeColor != eyeColor || oldDelegate.mouthType != mouthType;
  }
}
