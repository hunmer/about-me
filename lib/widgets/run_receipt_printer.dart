import 'dart:math' as math;

import 'package:aboutme/widgets/thermal_printer.dart';
import 'package:flutter/material.dart';

/// 单段配速明细
class RunReceiptSegment {
  final String label;
  final bool isFast;
  final String pace;
  final String time;
  final int hr;

  const RunReceiptSegment({
    required this.label,
    required this.pace,
    required this.time,
    this.isFast = false,
    this.hr = 0,
  });
}

/// 跑步账单数据
class RunReceiptData {
  final String title;
  final String orderNo;
  final String date;
  final String mode;
  final List<RunReceiptSegment> segments;
  final String paceRangeText;
  final String chartStartLabel;
  final String chartEndLabel;
  final String totalLabel;
  final String duration;
  final String avgPace;
  final String best1k;
  final String calories;
  final String description;
  final String footerOffice;
  final String footerDate;
  final String slogan;
  final String generatedBy;

  const RunReceiptData({
    this.title = 'RUN RECEIPT',
    this.orderNo = 'ORDER:#1235',
    this.date = 'JANUARY 28, 2026',
    this.mode = 'INDOOR - EASY',
    this.segments = const [
      RunReceiptSegment(
        label: '1 KM',
        pace: "09'21\"",
        time: '09:21',
        isFast: true,
      ),
      RunReceiptSegment(label: '1.08 KM', pace: "09'59\"", time: '00:50'),
    ],
    this.paceRangeText = "09'21\"/KM-09'59\"/KM | 09'24\"/KM",
    this.chartStartLabel = '0KM',
    this.chartEndLabel = '1.1KM',
    this.totalLabel = '1.08 KM',
    this.duration = '00:10:12',
    this.avgPace = "09'24\"/KM",
    this.best1k = "09'21\"/KM",
    this.calories = '73 KCAL',
    this.description =
        'Every run leaves a trace. Run Receipt\n'
        'turns it into something you can keep and\n'
        'share, capturing distance, pace, and\n'
        'effort as a simple receipt of movement —\n'
        'a small record of where you ran and how\n'
        'it felt. Learn more at\n'
        'receipt.atomicos.run.',
    this.footerOffice = 'OFFICE HOUR',
    this.footerDate = 'WED-JAN 10:51',
    this.slogan = 'A LIGHT RUN MOVES THINGS FORWARD.',
    this.generatedBy = 'GENERATED LOCALLY VIA ATOMIC OS.',
  });
}

/// 跑步账单热敏打印组件（[ThermalPrinter] 的具体用法示例）
///
/// 打印内容通过 [data] 参数化；打印机动画/拖拽/重播由通用组件
/// [ThermalPrinter] 提供，外部可用 GlobalKey 调 `ThermalPrinterState.replay()`。
class RunReceiptPrinter extends StatelessWidget {
  final RunReceiptData data;
  final bool autoStart;

  const RunReceiptPrinter({
    super.key,
    this.data = const RunReceiptData(),
    this.autoStart = true,
  });

  @override
  Widget build(BuildContext context) {
    return ThermalPrinter(
      autoStart: autoStart,
      child: RunReceiptContent(data: data),
    );
  }
}

/// 跑步账单纸张内容（宽度固定 326，可单独复用）
class RunReceiptContent extends StatelessWidget {
  final RunReceiptData data;

  const RunReceiptContent({super.key, this.data = const RunReceiptData()});

  TextStyle _mono(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = const Color(0xFF141414),
    double letterSpacing = 0,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 326,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 双人跑步剪影 Logo
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Center(
              child: CustomPaint(
                size: const Size(68, 32),
                painter: RunnerLogoPainter(),
              ),
            ),
          ),

          // 2. 标题与订单信息
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: _mono(
              19,
              weight: FontWeight.w800,
              color: const Color(0xFF111111),
              letterSpacing: 0.04 * 19,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${data.orderNo}\n${data.date}\n${data.mode}',
            textAlign: TextAlign.center,
            style: _mono(
              10.5,
              weight: FontWeight.w500,
              color: const Color(0xFF222222),
              letterSpacing: 0.03 * 10.5,
              height: 1.65,
            ),
          ),

          const ReceiptDivider(),

          // 3. 分段配速明细表
          _buildTableHeader(),
          const ReceiptDivider(margin: 10),
          for (final seg in data.segments) _buildSegmentRow(seg),

          const ReceiptDivider(),

          // 4. 配速折线图
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'PACE',
                      style: _mono(
                        10,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111111),
                        letterSpacing: 0.02 * 10,
                      ),
                    ),
                    Text(
                      data.paceRangeText,
                      style: _mono(
                        7.5,
                        weight: FontWeight.w500,
                        color: const Color(0xFF767676),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    return CustomPaint(
                      size: Size(w, w * 82 / 282),
                      painter: PaceChartPainter(),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data.chartStartLabel,
                      style: _mono(
                        8.5,
                        weight: FontWeight.w500,
                        color: const Color(0xFF666666),
                      ),
                    ),
                    Text(
                      data.chartEndLabel,
                      style: _mono(
                        8.5,
                        weight: FontWeight.w500,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const ReceiptDivider(),

          // 5. 汇总统计
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'TOTAL:',
                      style: _mono(
                        13,
                        weight: FontWeight.w800,
                        color: const Color(0xFF111111),
                        letterSpacing: 0.02 * 13,
                      ),
                    ),
                    Text(
                      data.totalLabel,
                      style: _mono(
                        14,
                        weight: FontWeight.w800,
                        color: const Color(0xFF111111),
                        letterSpacing: 0.02 * 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildStatRow('DURATION', data.duration),
                const SizedBox(height: 6),
                _buildStatRow('AVG PACE', data.avgPace),
                const SizedBox(height: 6),
                _buildStatRow('BEST 1K', data.best1k),
                const SizedBox(height: 6),
                _buildStatRow('CALORIES', data.calories),
              ],
            ),
          ),

          const ReceiptDivider(),

          // 6. 副本声明与纪念文案
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Text(
                  '*** DUPLICATE COPY ***',
                  textAlign: TextAlign.center,
                  style: _mono(
                    11,
                    weight: FontWeight.w800,
                    color: const Color(0xFF111111),
                    letterSpacing: 0.04 * 11,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'KEEP FOR YOUR RECORDS',
                  textAlign: TextAlign.center,
                  style: _mono(
                    9.5,
                    weight: FontWeight.w500,
                    color: const Color(0xFF444444),
                    letterSpacing: 0.03 * 9.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.description,
                  style: _mono(
                    9.2,
                    color: const Color(0xFF4A4A4A),
                    height: 1.48,
                  ),
                ),
              ],
            ),
          ),

          const ReceiptDivider(),

          // 7. 底部跑道丝带图形与标语
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Column(
              children: [
                Text(
                  '${data.footerOffice}\n${data.footerDate}',
                  textAlign: TextAlign.center,
                  style: _mono(
                    9,
                    weight: FontWeight.w700,
                    color: const Color(0xFF181818),
                    letterSpacing: 0.03 * 9,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 58,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: RibbonPainter()),
                      Center(
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            data.slogan,
                            style: _mono(
                              9.5,
                              weight: FontWeight.w800,
                              color: const Color(0xFF111111),
                              letterSpacing: 0.02 * 9.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.generatedBy,
                  textAlign: TextAlign.center,
                  style: _mono(
                    8.5,
                    weight: FontWeight.w500,
                    color: const Color(0xFF666666),
                    letterSpacing: 0.04 * 8.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const flex = [150, 100, 70, 90, 45];
    const labels = ['ITEM', 'PACE', 'ZONE', 'TIME', 'HR'];
    const aligns = [
      TextAlign.left,
      TextAlign.left,
      TextAlign.center,
      TextAlign.right,
      TextAlign.right,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: flex[i],
              child: Text(
                labels[i],
                textAlign: aligns[i],
                style: _mono(
                  9.5,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111111),
                  letterSpacing: 0.02 * 9.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentRow(RunReceiptSegment seg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 150,
            child: Row(
              children: [
                Text(
                  seg.label,
                  style: _mono(
                    10.5,
                    weight: FontWeight.w600,
                    color: const Color(0xFF181818),
                  ),
                ),
                if (seg.isFast)
                  Container(
                    margin: const EdgeInsets.only(left: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.5,
                      vertical: 2.5,
                    ),
                    color: const Color(0xFF141414),
                    child: Text(
                      'FAST',
                      style: _mono(
                        9.5,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.02 * 9.5,
                        height: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 100,
            child: Text(
              seg.pace,
              style: _mono(
                10.5,
                weight: FontWeight.w600,
                color: const Color(0xFF181818),
              ),
            ),
          ),
          Expanded(
            flex: 70,
            child: Center(
              child: Container(
                width: 7.5,
                height: 7.5,
                decoration: const BoxDecoration(
                  color: Color(0xFF7BD53C),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 90,
            child: Text(
              seg.time,
              textAlign: TextAlign.right,
              style: _mono(
                10.5,
                weight: FontWeight.w600,
                color: const Color(0xFF181818),
              ),
            ),
          ),
          Expanded(
            flex: 45,
            child: Text(
              '${seg.hr}',
              textAlign: TextAlign.right,
              style: _mono(
                10.5,
                weight: FontWeight.w600,
                color: const Color(0xFF181818),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: _mono(
            10.5,
            weight: FontWeight.w500,
            color: const Color(0xFF222222),
          ),
        ),
        Text(
          value,
          style: _mono(
            10.5,
            weight: FontWeight.w600,
            color: const Color(0xFF222222),
          ),
        ),
      ],
    );
  }
}

/// 热敏打印虚线分割线
class ReceiptDivider extends StatelessWidget {
  final double margin;

  const ReceiptDivider({super.key, this.margin = 14});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: margin),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashLinePainter(),
      ),
    );
  }
}

class _DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC4C4C4)
      ..strokeWidth = 1;
    const dash = 3.9;
    const gap = 3.1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0.5),
        Offset(math.min(x + dash, size.width), 0.5),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 双人跑步像素风剪影 Logo（viewBox 68x32）
class RunnerLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 68, size.height / 32);
    const ink = Color(0xFF141414);
    final fill = Paint()..color = ink;
    Paint stroke(double w) => Paint()
      ..color = ink
      ..strokeWidth = w
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // 尾随速度扫描线
    for (final r in const [
      Rect.fromLTWH(44, 9, 16, 1.5),
      Rect.fromLTWH(48, 12.5, 14, 1.5),
      Rect.fromLTWH(42, 16, 19, 1.5),
      Rect.fromLTWH(46, 19.5, 13, 1.5),
      Rect.fromLTWH(41, 23, 14, 1.5),
    ]) {
      canvas.drawRect(r, fill);
    }

    // 左侧领跑者
    canvas.drawCircle(const Offset(15.5, 6.5), 2.6, fill);
    canvas.drawPath(
      Path()
        ..moveTo(16, 10)
        ..lineTo(13.5, 17.5)
        ..lineTo(18.5, 18.5)
        ..lineTo(20.5, 11.5)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(15.5, 11)
        ..lineTo(10.5, 13.5)
        ..lineTo(8.5, 11.5),
      stroke(2.3),
    );
    canvas.drawPath(
      Path()
        ..moveTo(18.5, 11.5)
        ..lineTo(23, 14.5)
        ..lineTo(25, 12.5),
      stroke(2.2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(14.5, 17)
        ..lineTo(10, 22.5)
        ..lineTo(7, 23),
      stroke(2.5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(17.5, 17.5)
        ..lineTo(21.5, 23)
        ..lineTo(25.5, 20.5),
      stroke(2.5),
    );

    // 右侧跟跑者
    canvas.drawCircle(const Offset(32.5, 5.8), 2.6, fill);
    canvas.drawPath(
      Path()
        ..moveTo(33, 9.5)
        ..lineTo(30.5, 17)
        ..lineTo(35.5, 18)
        ..lineTo(37.5, 11)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(32.5, 10.5)
        ..lineTo(27.5, 13)
        ..lineTo(25.5, 10.8),
      stroke(2.3),
    );
    canvas.drawPath(
      Path()
        ..moveTo(36, 11)
        ..lineTo(40.5, 14)
        ..lineTo(43, 12),
      stroke(2.2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(31.5, 16.5)
        ..lineTo(27, 23.5)
        ..lineTo(24.5, 24),
      stroke(2.5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(34.5, 17)
        ..lineTo(38.5, 22.5)
        ..lineTo(42.5, 19.5),
      stroke(2.5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 配速阶梯折线图（viewBox 282x82）
class PaceChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 282;
    canvas.save();
    canvas.scale(s, s);

    // 纵向网格线
    final grid = Paint()
      ..color = const Color(0xFFE5E5E5)
      ..strokeWidth = 1;
    for (double x = 1; x <= 281; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, 75), grid);
    }

    // 曲线下方浅灰填充
    canvas.drawPath(
      Path()
        ..moveTo(1, 19)
        ..lineTo(261, 19)
        ..lineTo(261, 31)
        ..lineTo(281, 31)
        ..lineTo(281, 75)
        ..lineTo(1, 75)
        ..close(),
      Paint()..color = const Color(0xFF141414).withValues(alpha: 0.03),
    );

    // 配速阶梯实线
    final line = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 1.35
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(
      Path()
        ..moveTo(1, 19)
        ..lineTo(261, 19)
        ..lineTo(261, 31)
        ..lineTo(281, 31),
      line,
    );

    // 底部坐标轴与两端刻度
    canvas.drawLine(const Offset(1, 75), const Offset(281, 75), line);
    canvas.drawLine(const Offset(1, 70), const Offset(1, 75), line);
    canvas.drawLine(const Offset(281, 70), const Offset(281, 75), line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// S 型跑道丝带（水平条纹半色调填充，viewBox 260x64，BoxFit.contain）
class RibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 260, size.height / 64);
    canvas.save();
    canvas.translate((size.width - 260 * s) / 2, (size.height - 64 * s) / 2);
    canvas.scale(s, s);

    final path = Path()
      ..moveTo(110, 2)
      ..cubicTo(155, 2, 195, 9, 195, 19)
      ..cubicTo(195, 29, 68, 27, 68, 40)
      ..cubicTo(68, 51, 118, 57, 152, 62)
      ..lineTo(116, 62)
      ..cubicTo(82, 56, 36, 50, 36, 39)
      ..cubicTo(36, 25, 165, 26, 165, 18)
      ..cubicTo(165, 11, 130, 6, 92, 2)
      ..close();

    // 裁剪到丝带轮廓后绘制水平条纹
    canvas.save();
    canvas.clipPath(path);
    final stripe = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..strokeWidth = 1.15;
    for (double y = 1; y <= 64; y += 2.5) {
      canvas.drawLine(Offset(0, y), Offset(260, y), stripe);
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
