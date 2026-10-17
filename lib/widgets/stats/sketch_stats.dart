import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 统计页公共组件：手绘墨线曲线图、统计纸卡、本地化文案辅助。
/// 供 chat/todo/habits 等插件的统计 tab 复用（timer 统计页保留私有实现）。

// ===== 本地化文案辅助 =====

bool get statsIsZh => Get.locale?.languageCode == 'zh';

const statsWeekdaysZh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const statsWeekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const statsWeekdayShortsZh = ['一', '二', '三', '四', '五', '六', '日'];
const statsWeekdayShortsEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// 全名周几（周一 / Mon），weekday 为 DateTime.weekday（1-7）
String statsWeekdayLabel(int weekday) =>
    (statsIsZh ? statsWeekdaysZh : statsWeekdaysEn)[weekday - 1];

/// 单字周几（一 / M），按 weekday 索引（周一 = 0）
String statsWeekdayShort(int weekday) =>
    (statsIsZh ? statsWeekdayShortsZh : statsWeekdayShortsEn)[weekday - 1];

/// 短日期（X月X日 / M/D）
String statsDateLabel(DateTime d) =>
    statsIsZh ? '${d.month}月${d.day}日' : '${d.month}/${d.day}';

/// 折线 x 轴小时标签（0点 / 0）
String statsHourLabel(int hour) => statsIsZh ? '$hour点' : '$hour';

// ===== 手绘墨线曲线图 =====

/// 手绘墨线曲线图：skribble rough 曲线（与全局墨线风格同源）
/// + 主色淡渐变填充体 + 实底数据点，接 WiredDraw 描画入场。
/// CustomPaint 无 child，须置于 tight 约束下（SizedBox 宽高有界）
class SketchLineChart extends StatelessWidget {
  const SketchLineChart({
    super.key,
    required this.values,
    required this.maxValue,
    required this.color,
    required this.drawConfig,
    this.drawProgress,
  });

  final List<double> values;
  final double maxValue;
  final Color color;

  /// 主题墨线绘制配置（AppThemeData.wired.drawConfig）
  final DrawConfig drawConfig;

  /// 外层 WiredDraw 描画进度；null = 已画完
  final Animation<double>? drawProgress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SketchLineChartPainter(
        values: values,
        maxValue: maxValue,
        color: color,
        drawConfig: drawConfig,
        drawProgress: drawProgress,
      ),
    );
  }
}

class _SketchLineChartPainter extends CustomPainter {
  _SketchLineChartPainter({
    required this.values,
    required this.maxValue,
    required this.color,
    required this.drawConfig,
    this.drawProgress,
  }) : super(repaint: drawProgress);

  final List<double> values;
  final double maxValue;
  final Color color;
  final DrawConfig drawConfig;
  final Animation<double>? drawProgress;

  /// rough 生成缓存：尺寸不变时描画动画帧复用，不重算墨线
  Size? _builtFor;
  Path? _fillPath;
  RoughDrawing? _curve;
  List<Offset> _points = const [];

  /// 墨线先描，填充体与数据点在 30%–100% 阶段浮现（同 WaveFill 节奏）
  double get _phase => (((drawProgress?.value ?? 1) - 0.3) / 0.7).clamp(
    0.0,
    1.0,
  );

  void _build(Size size) {
    final top = 14.0; // 顶部留空给最高点数据点
    final bottom = size.height - 3;
    final chartHeight = bottom - top;
    final n = values.length;
    _points = [
      for (var i = 0; i < n; i++)
        Offset(
          i / (n - 1) * size.width,
          bottom - (values[i] / maxValue).clamp(0.0, 1.0) * chartHeight,
        ),
    ];

    // 主色淡渐变填充体（Catmull-Rom 平滑 + 闭合到底边）
    final fill = _smoothPath(_points);
    fill
      ..lineTo(_points.last.dx, bottom)
      ..lineTo(_points.first.dx, bottom)
      ..close();
    _fillPath = fill;

    // 手绘墨线曲线；reset 保证同尺寸下墨迹稳定不抖变
    drawConfig.randomizer.reset();
    final generator = Generator(drawConfig, NoFiller());
    final drawable = generator.curvePath([
      for (final p in _points) PointD(p.dx, p.dy),
    ]);
    _curve = RoughDrawing(
      drawable,
      Paint()
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.8
        ..color = color,
      Paint()..color = color, // NoFiller 下填充笔不参与绘制
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || maxValue <= 0 || size.isEmpty) return;
    if (_builtFor != size) {
      _build(size);
      _builtFor = size;
    }
    final drawValue = drawProgress?.value ?? 1;
    final phase = _phase;
    final n = values.length;

    if (phase > 0 && _fillPath != null) {
      canvas.drawPath(
        _fillPath!,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.20 * phase),
              color.withValues(alpha: 0.02 * phase),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    _curve?.paint(canvas, progress: drawValue, pressure: 0);

    // 数据点：描画推进到该点后浮现（值为 0 的贴底点不画）
    for (var i = 0; i < n; i++) {
      if (values[i] <= 0) continue;
      final appear = (drawValue * (n - 1) - i).clamp(0.0, 1.0);
      if (appear <= 0) continue;
      canvas.drawCircle(
        _points[i],
        i == n - 1 ? 5 : 3.2,
        Paint()..color = color.withValues(alpha: phase * appear),
      );
    }
  }

  /// Catmull-Rom 样条平滑路径（填充体轮廓，非手绘）
  static Path _smoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i > 0 ? i - 1 : i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i + 2 < pts.length ? i + 2 : i + 1];
      const segments = 16;
      for (var j = 1; j <= segments; j++) {
        final t = j / segments;
        final t2 = t * t;
        final t3 = t2 * t;
        path.lineTo(
          0.5 *
              ((2 * p1.dx) +
                  (-p0.dx + p2.dx) * t +
                  (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
                  (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
          0.5 *
              ((2 * p1.dy) +
                  (-p0.dy + p2.dy) * t +
                  (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
                  (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
        );
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _SketchLineChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.color != color ||
      oldDelegate.drawConfig != drawConfig;
}

/// 统计页通用卡：手绘纸面板（纸底 + 淡排线 + 墨线框）
class StatsSketchCard extends StatelessWidget {
  final Widget child;

  const StatsSketchCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DsSketchPanel(
      theme: DSThemeBridge.resolve(context),
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}
