import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';

import '../models/media_item.dart';

/// 手绘书架视图：木隔板 + 竖立书脊 + 偶发绿植（迁移自 tbr_bookshelf_ui_replica）
///
/// - 进入本视图的 [items] 已经过滤/排序，不符合条件的书直接不上架
/// - 书脊高度/颜色、绿植位置均由 id 哈希确定性生成，重排后姿态不变
/// - 配色属内容插画色（同程序化封面，不随主题切换）；墨线走全局墨线风格
class MediaBookshelfView extends StatelessWidget {
  const MediaBookshelfView({
    super.key,
    required this.items,
    required this.onTap,
    this.onLongPress,
    this.padding,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item) onTap;
  final void Function(MediaItem item)? onLongPress;
  final EdgeInsetsGeometry? padding;

  /// 隔板厚度 / 书脊区高度 / 层间距
  static const double _boardHeight = 13;
  static const double _shelfHeight = 168;
  static const double _shelfGap = 22;

  /// 书脊 / 绿植在 Row 中的 flex 权重（绿植约占 2.4 本宽）
  static const int _bookFlex = 5;
  static const int _plantFlex = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 目标书脊宽约 40：按宽度决定每层书数（4~10 本）
        final booksPerShelf = (constraints.maxWidth / 42).floor().clamp(4, 10);

        // 分层（绿植以占位符混入书序，约三分之一的层出现一次）
        final rows = <List<Object>>[];
        var cursor = 0;
        var rowIndex = 0;
        while (cursor < items.length) {
          // 首层书够时固定摆一盆保证可见，其余层确定性随机（约 1/3）
          final hasPlant = rowIndex == 0
              ? items.length >= 4
              : handDrawnUnitRandom('media_shelf_plant_$rowIndex') > 0.3;
          final capacity = booksPerShelf - (hasPlant ? 2 : 0);
          final take = math.min(capacity, items.length - cursor);
          // 槽位固定：末层不足补空位占位，保证各层书脊等宽
          final row = <Object>[...items.sublist(cursor, cursor + take)];
          for (var i = 0; i < capacity - take; i++) {
            row.add(const _EmptyMarker());
          }
          if (hasPlant) {
            final plantAt =
                (((handDrawnUnitRandom('media_shelf_plant_pos_$rowIndex') *
                                0.5 +
                            0.5)) *
                        math.max(take, 1))
                    .floor();
            row.insert(plantAt, const _PlantMarker());
          }
          rows.add(row);
          cursor += take;
          rowIndex++;
        }

        return SingleChildScrollView(
          padding: padding,
          child: Column(
            children: [
              for (final (i, row) in rows.indexed)
                _buildShelfRow(context, i, row, isLast: i == rows.length - 1),
            ],
          ),
        );
      },
    );
  }

  /// 单层书架：书脊行（底对齐）+ 木隔板
  Widget _buildShelfRow(
    BuildContext context,
    int rowIndex,
    List<Object> row, {
    required bool isLast,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : _shelfGap),
      // Builder 在 WiredDraw 之下取描画进度与主题（design.md §10）
      child: WiredDraw(
        child: Builder(
          builder: (context) {
            final theme = AppTheme.of(context);
            final progress = WiredDrawTransition.progressOf(context);
            return SizedBox(
              height: _shelfHeight + _boardHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: _shelfHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final slot in row)
                          Expanded(
                            flex: switch (slot) {
                              _PlantMarker() => _plantFlex,
                              _EmptyMarker() => _bookFlex,
                              _ => _bookFlex,
                            },
                            child: switch (slot) {
                              _PlantMarker() =>
                                _buildPlant(context, rowIndex, theme, progress),
                              _EmptyMarker() => const SizedBox.expand(),
                              final MediaItem item => _buildBook(context, item),
                              _ => const SizedBox.shrink(),
                            },
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: _boardHeight,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _ShelfBoardPainter(
                        theme: theme,
                        seed: rowIndex + 1,
                        progress: progress,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 单本书：书脊高度由 id 哈希确定性生成，按压时以底部为轴轻微缩放
  Widget _buildBook(BuildContext context, MediaItem item) {
    final u = handDrawnUnitRandom('media_spine_${item.id}') * 0.5 + 0.5;
    final height = _shelfHeight * (0.78 + 0.22 * u);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: _shelfHeight,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Pressable(
            onPressed: () => onTap(item),
            onLongPress: onLongPress == null ? null : () => onLongPress!(item),
            semanticLabel: item.title,
            builder: (context, states) {
              final pressed = states.contains(WidgetState.pressed);
              return AnimatedScale(
                scale: pressed ? 0.94 : 1,
                alignment: Alignment.bottomCenter,
                duration: const Duration(milliseconds: 120),
                child: CustomPaint(
                  size: Size(double.infinity, height),
                  painter: _BookSpinePainter(
                    item: item,
                    theme: AppTheme.of(context),
                    seed: item.id.hashCode & 0xffff,
                    progress: WiredDrawTransition.progressOf(context),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 绿植摆件：纯装饰，不响应点击
  Widget _buildPlant(
    BuildContext context,
    int rowIndex,
    AppThemeData theme,
    Animation<double>? progress,
  ) {
    return SizedBox(
      height: _shelfHeight,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: IgnorePointer(
          child: CustomPaint(
            size: Size(double.infinity, _shelfHeight * 0.66),
            painter: _PlantPainter(
              theme: theme,
              seed: rowIndex * 7 + 11,
              progress: progress,
            ),
          ),
        ),
      ),
    );
  }
}

/// 绿植占位（区分于 MediaItem）
class _PlantMarker {
  const _PlantMarker();
}

/// 空槽占位（末层书不足时保持书脊等宽）
class _EmptyMarker {
  const _EmptyMarker();
}

/// 手绘书脊：粗墨线圆角矩形 + 实底色 + 顶部装饰带 + 旋转书名
///
/// 观影条目在装饰带下画胶片孔圆点，与书籍区分。
class _BookSpinePainter extends CustomPainter {
  const _BookSpinePainter({
    required this.item,
    required this.theme,
    required this.seed,
    required this.progress,
  }) : super(repaint: progress);

  final MediaItem item;
  final AppThemeData theme;
  final int seed;
  final Animation<double>? progress;

  /// 书脊配色板（取自书架参考稿，内容插画色不随主题切换）
  static const List<Color> _palette = [
    Color(0xFFCBB5A6),
    Color(0xFFB49397),
    Color(0xFF99A3AC),
    Color(0xFFD4BE8F),
    Color(0xFF869484),
    Color(0xFF718B95),
    Color(0xFF8E7964),
    Color(0xFFB6BBD0),
    Color(0xFFC2CFA9),
    Color(0xFF94967D),
    Color(0xFFDF644F),
    Color(0xFF47484A),
  ];

  static const Color _darkText = Color(0xFF2B2B2B);
  static const Color _lightText = Color(0xFFF7F3EC);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final p = progress?.value ?? 1;

    final config = theme.wired.drawConfig.copyWith(seed: seed);
    config.randomizer.reset();
    final solidGen = Generator(config, SolidFiller());
    final inkGen = Generator(config, NoFiller());

    final color = _palette[seed % _palette.length];

    Paint ink(double width, double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = theme.ink.withValues(alpha: alpha);

    // 书脊主体：顶部小圆角
    final spine = solidGen.roundedRectangle(0.8, 0.8, w - 1.6, h - 1.2, 3, 3, 1, 1);
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = color;
    RoughDrawing(spine, ink(1.5, 0.9), fill).paint(canvas, progress: p, pressure: 0);

    // 顶部装饰带
    RoughDrawing(
      inkGen.line(w * 0.2, 8.5, w * 0.8, 7.8),
      ink(1.1, 0.4),
      ink(1.1, 0.4),
    ).paint(canvas, progress: p, pressure: 0);

    // 观影条目：胶片孔圆点
    if (item.kind == MediaKind.watching) {
      final dotPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = _lightText.withValues(alpha: 0.7);
      for (var i = 0; i < 3; i++) {
        RoughDrawing(
          solidGen.circle(w / 2, 15 + i * 6.5, 2.6),
          dotPaint,
          dotPaint,
        ).paint(canvas, progress: p, pressure: 0);
      }
    }

    // 旋转书名（顶端预留装饰区）
    if (w >= 18 && h > 64) {
      final fontSize = (w * 0.5).clamp(8.0, 13.0);
      final dark = color.computeLuminance() > 0.55;
      final tp = TextPainter(
        text: TextSpan(
          text: item.title,
          style: TextStyle(
            color: dark ? _darkText : _lightText,
            fontSize: fontSize,
            fontFamily: DsTypography.sketchFamily,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(h - 50, 24));
      canvas.save();
      canvas.translate(w / 2, 42 + (h - 50) / 2);
      canvas.rotate(math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BookSpinePainter old) =>
      old.item != item ||
      !identical(old.theme, theme) ||
      old.seed != seed ||
      old.progress != progress;
}

/// 木隔板：实底木色 + 墨线框 + 顶面高光与木纹
class _ShelfBoardPainter extends CustomPainter {
  const _ShelfBoardPainter({
    required this.theme,
    required this.seed,
    required this.progress,
  }) : super(repaint: progress);

  final AppThemeData theme;
  final int seed;
  final Animation<double>? progress;

  // 木色（内容插画色，取自参考稿）
  static const Color _wood = Color(0xFF7C6246);
  static const Color _woodLight = Color(0xFFA98A67);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final p = progress?.value ?? 1;

    final config = theme.wired.drawConfig.copyWith(seed: seed);
    config.randomizer.reset();
    final solidGen = Generator(config, SolidFiller());
    final inkGen = Generator(config, NoFiller());

    Paint ink(double width, double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = theme.ink.withValues(alpha: alpha);

    final board = solidGen.rectangle(1, 1.2, w - 2, size.height - 2.2);
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = _wood;
    RoughDrawing(board, ink(1.5, 0.9), fill).paint(canvas, progress: p, pressure: 0);

    // 顶面高光
    final light = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..color = _woodLight.withValues(alpha: 0.8);
    RoughDrawing(inkGen.line(5, 3.4, w - 5, 3), light, light)
        .paint(canvas, progress: p, pressure: 0);

    // 木纹两笔
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1
      ..color = theme.ink.withValues(alpha: 0.22);
    RoughDrawing(
      inkGen.line(w * 0.16, size.height * 0.6, w * 0.42, size.height * 0.56),
      grain,
      grain,
    ).paint(canvas, progress: p, pressure: 0);
    RoughDrawing(
      inkGen.line(w * 0.58, size.height * 0.66, w * 0.86, size.height * 0.6),
      grain,
      grain,
    ).paint(canvas, progress: p, pressure: 0);
  }

  @override
  bool shouldRepaint(_ShelfBoardPainter old) =>
      !identical(old.theme, theme) ||
      old.seed != seed ||
      old.progress != progress;
}

/// 绿植摆件：扇形叶片 + 陶盆（内容插画色）
class _PlantPainter extends CustomPainter {
  const _PlantPainter({
    required this.theme,
    required this.seed,
    required this.progress,
  }) : super(repaint: progress);

  final AppThemeData theme;
  final int seed;
  final Animation<double>? progress;

  static const List<Color> _greens = [
    Color(0xFF5C7F4D),
    Color(0xFF789B63),
    Color(0xFF9BB977),
  ];
  static const Color _pot = Color(0xFFB06A45);
  static const List<double> _leafAngles = [-0.62, -0.31, 0.0, 0.31, 0.62];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = progress?.value ?? 1;

    final config = theme.wired.drawConfig.copyWith(seed: seed);
    config.randomizer.reset();
    final solidGen = Generator(config, SolidFiller());
    final inkGen = Generator(config, NoFiller());

    Paint ink(double width, double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = theme.ink.withValues(alpha: alpha);

    final cx = size.width / 2;
    final potW = size.width * 0.56;
    final potH = size.height * 0.34;
    final potTop = size.height - potH;

    // 扇形叶片（后画盆压住叶根）
    for (var i = 0; i < _leafAngles.length; i++) {
      final u = handDrawnUnitRandom('media_plant_leaf_${seed}_$i') * 0.5 + 0.5;
      final len = size.height * 0.68 * (0.72 + 0.32 * u);
      final leafFill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _greens[(seed + i) % _greens.length];
      canvas.save();
      canvas.translate(cx, potTop + 6);
      canvas.rotate(_leafAngles[i]);
      final leaf = solidGen.ellipse(0, -len / 2, len * 0.3, len);
      RoughDrawing(leaf, ink(1.1, 0.5), leafFill)
          .paint(canvas, progress: p, pressure: 0);
      canvas.restore();
    }

    // 陶盆
    final potFill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _pot;
    final pot = solidGen.roundedRectangle(
      cx - potW / 2,
      potTop,
      potW,
      potH,
      4,
      4,
      3,
      3,
    );
    RoughDrawing(pot, ink(1.4, 0.9), potFill).paint(canvas, progress: p, pressure: 0);

    // 盆沿
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..color = theme.ink.withValues(alpha: 0.35);
    RoughDrawing(
      inkGen.line(cx - potW / 2 + 4, potTop + potH * 0.3, cx + potW / 2 - 4,
          potTop + potH * 0.26),
      rim,
      rim,
    ).paint(canvas, progress: p, pressure: 0);
  }

  @override
  bool shouldRepaint(_PlantPainter old) =>
      !identical(old.theme, theme) ||
      old.seed != seed ||
      old.progress != progress;
}
