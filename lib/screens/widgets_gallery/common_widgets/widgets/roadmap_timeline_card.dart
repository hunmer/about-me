/// 路线图时间轴卡片（手绘纸墨风）
///
/// 由 visa_roadmap_interactive_ui.html 的 roadmap 部分转换：
/// S 形曲线头部（起点圆点 + 两行大标题，斜纹管道从起点延伸入场）+
/// 垂直里程碑时间轴（淡墨轨道 + 数据色斜纹激活线逐段向下生长，
/// 每到达一步节点 scale pop 弹入、文字淡入上移）。
/// 入场编排：S 曲线管道延伸 → 激活线生长 → 节点/文字依次入场 → 未来步收尾。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 路线图里程碑步骤数据
class RoadmapStepData {
  /// 步骤标题
  final String title;

  /// 步骤描述
  final String subtitle;

  const RoadmapStepData({required this.title, this.subtitle = ''});
}

/// 路线图时间轴卡片
class RoadmapTimelineCardWidget extends StatefulWidget {
  /// 标题第一行
  final String titleLine1;

  /// 标题第二行
  final String titleLine2;

  /// 里程碑步骤列表
  final List<RoadmapStepData> steps;

  /// 当前进行到的步数（1-based）：激活线画到该步节点，
  /// 序号 <= currentStep 的节点为实心数据色圆，其余为纸底空心圆
  final int currentStep;

  /// 进度色（激活线 / 激活节点），数据色 props
  final Color activeColor;

  /// 组件尺寸
  final HomeWidgetSize size;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  const RoadmapTimelineCardWidget({
    super.key,
    this.titleLine1 = 'The Roadmap to',
    this.titleLine2 = 'Your Visa',
    this.steps = _defaultSteps,
    this.currentStep = 1,
    this.activeColor = const Color(0xFF432CE7),
    this.size = const Large3Size(),
    this.inline = false,
  });

  static const List<RoadmapStepData> _defaultSteps = [
    RoadmapStepData(
      title: 'You are here',
      subtitle: "You've made the greatest decision of your life",
    ),
    RoadmapStepData(
      title: 'Submit docs',
      subtitle: 'Plug your information into free templates!',
    ),
    RoadmapStepData(
      title: 'Reviews docs',
      subtitle: "We'll ensure your application is error free",
    ),
    RoadmapStepData(
      title: 'Submit to Govt.',
      subtitle: 'The embassy reviews your application',
    ),
    RoadmapStepData(
      title: 'Track status',
      subtitle: "We'll always update you on your visa",
    ),
    RoadmapStepData(
      title: 'Get visa on time!',
      subtitle: "You're ready to start packing for your trip!",
    ),
  ];

  /// 从 props 创建实例
  factory RoadmapTimelineCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    List<RoadmapStepData> parseSteps(dynamic stepsData) {
      if (stepsData is! List) return _defaultSteps;
      final steps = stepsData.map((item) {
        if (item is Map) {
          return RoadmapStepData(
            title: item['title'] as String? ?? '',
            subtitle: item['subtitle'] as String? ?? '',
          );
        }
        return RoadmapStepData(title: item?.toString() ?? '');
      }).toList();
      return steps.isEmpty ? _defaultSteps : steps;
    }

    return RoadmapTimelineCardWidget(
      titleLine1: props['titleLine1'] as String? ?? 'The Roadmap to',
      titleLine2: props['titleLine2'] as String? ?? 'Your Visa',
      steps: parseSteps(props['steps']),
      currentStep: (props['currentStep'] as num?)?.toInt() ?? 1,
      activeColor: _parseColor(props['activeColor'], const Color(0xFF432CE7)),
      size: size,
      inline: props['inline'] as bool? ?? false,
    );
  }

  @override
  State<RoadmapTimelineCardWidget> createState() =>
      _RoadmapTimelineCardWidgetState();
}

class _RoadmapTimelineCardWidgetState extends State<RoadmapTimelineCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// S 曲线描画阶段（0-0.26 ≈ 原编排 0-650ms）
  static const double _curveEnd = 0.26;

  /// 激活线生长阶段
  static const double _lineStart = 0.26;
  static const double _lineEnd = 0.82;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..forward();
  }

  @override
  void didUpdateWidget(RoadmapTimelineCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep ||
        oldWidget.steps != widget.steps ||
        oldWidget.activeColor != widget.activeColor) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _curveProgress =>
      Curves.easeInOut.transform((_controller.value / _curveEnd).clamp(0, 1));

  double get _lineProgress => Curves.easeInOut.transform(
    ((_controller.value - _lineStart) / (_lineEnd - _lineStart)).clamp(0, 1),
  );

  /// 第 [index] 步（0-based）的入场起始时刻：
  /// 激活步在激活线生长到该节点时入场，未来步在线画完后快速错峰入场
  double _stepRevealStart(int index, int stepCount) {
    final current = widget.currentStep.clamp(1, stepCount);
    if (index < current) {
      if (current <= 1) return index == 0 ? _lineStart : _lineEnd;
      final f = index / (current - 1);
      return _lineStart + (_lineEnd - _lineStart) * f;
    }
    final tail = (index - current + 1) * 0.025;
    return (_lineEnd + tail).clamp(0.0, 0.97);
  }

  Animation<double> _revealAnimation(int index, int stepCount) {
    final start = _stepRevealStart(index, stepCount).clamp(0.0, 0.98);
    final end = (start + 0.12).clamp(start + 0.01, 1.0);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  double _defaultHeight() {
    final scale = widget.size.scale;
    if (widget.size is SmallSize) return 150 * scale;
    if (widget.size is MediumSize || widget.size is WideSize) {
      return 190 * scale;
    }
    if (widget.size is LargeSize || widget.size is Wide2Size) {
      return 320 * scale;
    }
    if (widget.size is Wide3Size) return 420 * scale;
    return 440 * scale;
  }

  /// 是否显示步骤描述（小尺寸 / 矮宽条只保留标题）
  bool get _showSubtitle =>
      widget.size is! SmallSize &&
      widget.size is! MediumSize &&
      widget.size is! WideSize;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) =>
                _buildContent(theme, constraints),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AppThemeData theme, BoxConstraints constraints) {
    final scale = widget.size.scale;

    // 小尺寸：只画核心内容（轴线 + 节点 + 标题），省略 S 曲线头部与描述
    if (widget.size is SmallSize) {
      return SingleChildScrollView(
        child: _buildTimeline(theme, compact: true),
      );
    }

    // 宽条：标题 / S 曲线在左，时间轴在右
    if (widget.size.width > widget.size.height) {
      final bounded = constraints.maxHeight.isFinite;
      Widget timeline = _buildTimeline(theme, compact: !_showSubtitle);
      if (bounded) {
        timeline = SingleChildScrollView(child: timeline);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 42, child: _buildWideHeader(theme)),
          SizedBox(width: 12 * scale),
          Expanded(flex: 58, child: timeline),
        ],
      );
    }

    // 其余：S 曲线头部在上，时间轴在下
    final bounded = constraints.maxHeight.isFinite;
    Widget timeline = _buildTimeline(theme, compact: false);
    if (bounded) {
      timeline = Expanded(child: SingleChildScrollView(child: timeline));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVerticalHeader(theme),
        SizedBox(height: 4 * scale),
        timeline,
      ],
    );
  }

  /// 竖排头部：S 曲线（起点圆点旁绕标题弯下，出口对齐时间轴轴线）+ 两行标题
  Widget _buildVerticalHeader(AppThemeData theme) {
    final scale = widget.size.scale;
    final headerHeight = 66 * scale;
    final axisX = _RoadmapMetrics.axisX(scale);
    final titleFontSize = widget.size.getTitleFontSize();

    return SizedBox(
      height: headerHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SCurvePainter(
                exitX: axisX,
                startX: axisX,
                progress: _curveProgress,
                dotProgress: (_controller.value / 0.1).clamp(0.0, 1.0),
                activeColor: widget.activeColor,
                theme: theme,
                scale: scale,
              ),
            ),
          ),
          Positioned(
            left: axisX + 10 * scale,
            top: 0,
            bottom: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.titleLine1,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.titleLine2,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 宽条头部：标题在上，S 曲线装饰弯线填满剩余高度
  Widget _buildWideHeader(AppThemeData theme) {
    final scale = widget.size.scale;
    final titleFontSize = widget.size.getSubtitleFontSize() + 3 * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.titleLine1} ${widget.titleLine2}',
          style: TextStyle(
            color: theme.text,
            fontSize: titleFontSize,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 6 * scale),
        Expanded(
          child: CustomPaint(
            painter: _SCurvePainter(
              exitX: 30 * scale,
              startX: 30 * scale,
              progress: _curveProgress,
              dotProgress: (_controller.value / 0.1).clamp(0.0, 1.0),
              activeColor: widget.activeColor,
              theme: theme,
              scale: scale,
            ),
          ),
        ),
      ],
    );
  }

  /// 里程碑时间轴：每行 = 序号 + 节点列（轨道/激活线段 + 节点圆）+ 文案
  Widget _buildTimeline(
    AppThemeData theme, {
    required bool compact,
  }) {
    final scale = widget.size.scale;
    final steps = widget.steps;
    final rowHeight =
        (compact ? 30.0 : 74.0) * scale;
    final nodeCenterY = (compact ? 15.0 : 16.0) * scale;
    final stepCount = steps.length;
    final current = widget.currentStep.clamp(1, stepCount);

    final rows = <Widget>[];
    for (var i = 0; i < stepCount; i++) {
      rows.add(
        _buildMilestoneRow(
          theme,
          index: i,
          stepCount: stepCount,
          current: current,
          rowHeight: rowHeight,
          nodeCenterY: nodeCenterY,
          compact: compact,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildMilestoneRow(
    AppThemeData theme, {
    required int index,
    required int stepCount,
    required int current,
    required double rowHeight,
    required double nodeCenterY,
    required bool compact,
  }) {
    final scale = widget.size.scale;
    final step = widget.steps[index];
    final done = index < current;
    final nodeD = (done ? 17.0 : 15.0) * scale;
    final metrics = _RoadmapMetrics(scale);

    final reveal = _revealAnimation(index, stepCount);
    final t = reveal.value;
    final pop = Curves.easeOutBack.transform(t);

    return SizedBox(
      height: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 序号
          SizedBox(
            width: metrics.numberW,
            height: rowHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: nodeCenterY - 7 * scale),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: done ? theme.text : theme.textSub,
                    fontSize: compact
                        ? widget.size.getLegendFontSize() + 1
                        : widget.size.getLegendFontSize() + 2,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          // 节点列：轨道段 + 激活段 + 节点圆
          SizedBox(
            width: metrics.nodeColW,
            height: rowHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TimelineSegmentPainter(
                      rowIndex: index,
                      rowHeight: rowHeight,
                      nodeCenterY: nodeCenterY,
                      isLast: index == stepCount - 1,
                      currentStep: current,
                      lineProgress: _lineProgress,
                      activeColor: widget.activeColor,
                      theme: theme,
                      scale: scale,
                    ),
                  ),
                ),
                Positioned(
                  left: metrics.nodeColW / 2 - nodeD / 2,
                  top: nodeCenterY - nodeD / 2,
                  child: Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: pop,
                      child: _buildNode(theme, done, nodeD),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12 * scale),
          // 文案（淡入 + 上移）
          Expanded(
            child: Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 8 * scale * (1 - t)),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: compact ? nodeCenterY - 8 * scale : 2 * scale,
                  ),
                  child: compact
                      ? Text(
                          step.title,
                          style: TextStyle(
                            color: theme.text,
                            fontSize:
                                widget.size.getLegendFontSize() + 2 * scale,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              step.title,
                              style: TextStyle(
                                color: theme.text,
                                fontSize:
                                    widget.size.getSubtitleFontSize(),
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (step.subtitle.isNotEmpty) ...[
                              SizedBox(height: 4 * scale),
                              Text(
                                step.subtitle,
                                style: TextStyle(
                                  color: theme.textSub,
                                  fontSize: widget.size.getLegendFontSize(),
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 节点圆：小控件档墨线描边圆（激活 = 数据色实底 + 纸色内点；
  /// 未来 = 纸底 + 淡墨描边空心圆）
  Widget _buildNode(AppThemeData theme, bool done, double d) {
    return Container(
      width: d,
      height: d,
      decoration: dsSketchDecoration(
        theme: theme,
        circle: true,
        fillColor: done ? widget.activeColor : theme.paper,
        stroke: done ? null : theme.ink.withValues(alpha: 0.55),
        strokeWidth: 1.6,
      ),
      child: done
          ? Center(
              child: Container(
                width: d * 0.32,
                height: d * 0.32,
                decoration: BoxDecoration(
                  color: theme.paper,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

/// 时间轴几何常量（序号列宽 / 节点列宽 / 轴线 x）
class _RoadmapMetrics {
  _RoadmapMetrics(double scale)
    : numberW = 22 * scale,
      nodeColW = 30 * scale;

  final double numberW;
  final double nodeColW;

  static double axisX(double scale) => 22 * scale + 30 * scale / 2;
}

/// S 形曲线绘制器（rough 墨线装饰线，非数据几何）
/// S 形曲线绘制器（管道样式，与时间轴段视觉一致）
///
/// 从起点圆点 ([startX], 0.3H) 出发，左-下-右-下绕 S 弯，
/// 于 ([exitX], H) 出口接入时间轴轴线。轨道管道全程可见
/// （surfaceAlt 内芯 + 淡墨两侧边线），激活管道（数据色浅底 +
/// 浓斜纹 + 数据色边线）按 [progress] 沿路径长度向出口延伸。
class _SCurvePainter extends CustomPainter {
  _SCurvePainter({
    required this.exitX,
    required this.startX,
    required this.progress,
    required this.dotProgress,
    required this.activeColor,
    required this.theme,
    required this.scale,
  });

  final double exitX;
  final double startX;
  final double progress;
  final double dotProgress;
  final Color activeColor;
  final AppThemeData theme;
  final double scale;

  /// 管道笔：圆头圆接（转弯处圆润）
  Paint _pipe(Color color, double width) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = color;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.height < 12) return;
    final r = 7 * scale;
    final y0Max = size.height - 3 * r - 2;
    if (y0Max <= r + 2) return;
    final y0 = (size.height * 0.3).clamp(r + 2, y0Max);
    final y1 = size.height - r - 2;
    final leftX = (startX - 28 * scale).clamp(6 * scale, startX - 2 * r);
    if (y1 <= y0 + 2 * r) return;

    final path = Path()
      ..moveTo(startX, y0)
      ..lineTo(leftX + r, y0)
      ..quadraticBezierTo(leftX, y0, leftX, y0 + r)
      ..lineTo(leftX, y1 - r)
      ..quadraticBezierTo(leftX, y1, leftX + r, y1)
      ..lineTo(exitX - r, y1)
      ..quadraticBezierTo(exitX, y1, exitX, y1 + r)
      ..lineTo(exitX, size.height);

    // 管道宽度与时间轴线宽一致（同 _TimelineSegmentPainter）
    final barW = 5 * scale;
    final edgeW = 1.2 * scale;

    // 轨道管道：粗描淡墨描边 + surfaceAlt 内芯，叠出两侧边线
    canvas.drawPath(
      path,
      _pipe(theme.ink.withValues(alpha: 0.45), barW + 2 * edgeW),
    );
    canvas.drawPath(path, _pipe(theme.surfaceAlt, barW));

    if (progress > 0.01) {
      // 激活管道：按路径长度裁剪到描画头部
      final metrics = path.computeMetrics().toList();
      final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
      var remaining = total * progress.clamp(0.0, 1.0);
      final activePath = Path();
      for (final m in metrics) {
        if (remaining <= 0) break;
        final end = remaining < m.length ? remaining : m.length;
        activePath.addPath(m.extractPath(0, end), Offset.zero);
        remaining -= end;
      }
      final bounds = activePath.getBounds().inflate(barW + 2 * edgeW);
      if (!bounds.isEmpty) {
        // 数据色边线（粗描）+ 浅底内芯
        canvas.drawPath(
          activePath,
          _pipe(activeColor.withValues(alpha: 0.85), barW + 2 * edgeW),
        );
        canvas.drawPath(
          activePath,
          _pipe(activeColor.withValues(alpha: 0.28), barW),
        );
        // 浓斜纹：铺满包围盒后用激活管道作 dstIn 蒙版裁出
        canvas.saveLayer(bounds, Paint());
        paintDiagonalStripes(
          canvas,
          Path()..addRect(bounds),
          bounds,
          color: activeColor.withValues(alpha: 0.9),
          strokeWidth: 1.6 * scale,
          spacing: 4.5 * scale,
        );
        canvas.drawPath(
          activePath,
          _pipe(activeColor, barW)..blendMode = BlendMode.dstIn,
        );
        canvas.restore();
      }
    }

    // 起点圆点：数据色实底 + 纸色内点，先于曲线弹入（压在管道上）
    final dotT = Curves.easeOutBack.transform(dotProgress.clamp(0.0, 1.0));
    if (dotT > 0.01) {
      final dotR = 8 * scale * dotT;
      canvas.drawCircle(
        Offset(startX, y0),
        dotR,
        Paint()..color = activeColor,
      );
      canvas.drawCircle(
        Offset(startX, y0),
        dotR * 0.36,
        Paint()..color = theme.paper,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SCurvePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.dotProgress != dotProgress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}

/// 时间轴行段绘制器：淡墨轨道（§9.5 轨道档，简化为 surfaceAlt 底 +
/// 淡墨描边）+ 数据色斜纹激活段（平直几何，按 [lineProgress] 向下生长）
class _TimelineSegmentPainter extends CustomPainter {
  _TimelineSegmentPainter({
    required this.rowIndex,
    required this.rowHeight,
    required this.nodeCenterY,
    required this.isLast,
    required this.currentStep,
    required this.lineProgress,
    required this.activeColor,
    required this.theme,
    required this.scale,
  });

  final int rowIndex;
  final double rowHeight;
  final double nodeCenterY;
  final bool isLast;
  final int currentStep;
  final double lineProgress;
  final Color activeColor;
  final AppThemeData theme;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final centerX = size.width / 2;
    final barW = 5 * scale;
    final half = barW / 2;

    // 轨道纵向范围：首行从行顶（接 S 曲线出口），末行止于末节点圆心
    final yTop = 0.0;
    final yBottom = isLast ? nodeCenterY : size.height;
    if (yBottom <= yTop) return;

    // 轨道：surfaceAlt 底 + 淡墨描边（两侧边线，避免行间出现横向接缝）
    canvas.drawRect(
      Rect.fromLTRB(centerX - half, yTop, centerX + half, yBottom),
      Paint()..color = theme.surfaceAlt,
    );
    final trackStroke =
        Paint()
          ..color = theme.ink.withValues(alpha: 0.45)
          ..strokeWidth = 1.1 * scale;
    canvas.drawLine(
      Offset(centerX - half, yTop),
      Offset(centerX - half, yBottom),
      trackStroke,
    );
    canvas.drawLine(
      Offset(centerX + half, yTop),
      Offset(centerX + half, yBottom),
      trackStroke,
    );

    if (lineProgress <= 0.004) return;

    // 激活段：从行 0 顶部生长到当前步节点（略过节点圆心半个节点径）
    final maxLen =
        nodeCenterY + (currentStep - 1) * rowHeight + 4 * scale;
    final activeLen = lineProgress * maxLen;
    final localEnd = activeLen - rowIndex * rowHeight;
    if (localEnd <= yTop) return;
    final y1 = localEnd.clamp(yTop, yBottom);

    final rect = Rect.fromLTRB(centerX - half, yTop, centerX + half, y1);
    final clip = Path()..addRect(rect);
    // 数据色浅底
    canvas.drawRect(rect, Paint()..color = activeColor.withValues(alpha: 0.28));
    // 数据色浓斜纹
    paintDiagonalStripes(
      canvas,
      clip,
      rect,
      color: activeColor.withValues(alpha: 0.9),
      strokeWidth: 1.6 * scale,
      spacing: 4.5 * scale,
    );
    // 数据色描边（两侧边线）
    final activeStroke =
        Paint()
          ..color = activeColor.withValues(alpha: 0.85)
          ..strokeWidth = 1.2 * scale;
    canvas.drawLine(
      Offset(centerX - half, yTop),
      Offset(centerX - half, y1),
      activeStroke,
    );
    canvas.drawLine(
      Offset(centerX + half, yTop),
      Offset(centerX + half, y1),
      activeStroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineSegmentPainter oldDelegate) {
    return oldDelegate.lineProgress != lineProgress ||
        oldDelegate.currentStep != currentStep ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}

Color _parseColor(dynamic value, Color fallback) {
  if (value is Color) return value;
  if (value is int) return Color(value);
  if (value is String) {
    try {
      final hex = value.startsWith('#')
          ? value.substring(1)
          : value.startsWith('0x')
          ? value.substring(2)
          : '';
      if (hex.length == 6) {
        return Color(0xFF000000 | int.parse(hex, radix: 16));
      }
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }
  return fallback;
}
