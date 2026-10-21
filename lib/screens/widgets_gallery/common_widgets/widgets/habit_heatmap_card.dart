/// 习惯打卡热力图卡片 - 公共小组件（手绘纸墨风格）
///
/// 结构：手绘图标 + 标题头部 / 7x10 热力图矩阵（值 4 为今日待打卡空心格）
/// / 底部胶囊打卡按钮（未打卡加号 / 已打卡勾号 + x N）。
/// 颜色一律取 AppTheme 语义色；入场为 WiredDraw 墨线描画（格子按 index 错峰描出）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 习惯打卡热力图主题色板（浅色系）
///
/// 手绘纸墨风下卡片底色走 AppTheme（纸底+墨线框），本色板只承载习惯的
/// 个性化彩色：[cellColors] 0=未打卡空格淡底、1-3=打卡档位由浅到浓，
/// [iconColor] 头部图标与按钮主色，[outlineColor] 今日待打卡空心格描边，
/// [checkedButtonColor] 已打卡按钮淡底。
/// cardGradient/borderColor 为旧深色卡字段，仅为 props 兼容保留。
class HabitHeatmapTheme {
  final List<Color> cardGradient;
  final Color borderColor;
  final Color iconColor;
  final List<Color> cellColors;
  final Color outlineColor;
  final Color checkedButtonColor;

  const HabitHeatmapTheme({
    required this.cardGradient,
    required this.borderColor,
    required this.iconColor,
    required this.cellColors,
    required this.outlineColor,
    required this.checkedButtonColor,
  });

  /// 蓝紫主题（Drink water）
  static const drinkWater = HabitHeatmapTheme(
    cardGradient: [Color(0xFF12131C), Color(0xFF1D1E2E)],
    borderColor: Color(0xFF28293D),
    iconColor: Color(0xFF6C73CB),
    cellColors: [
      Color(0xFFE9EAF2),
      Color(0xFFC9CDEF),
      Color(0xFF9DA6E5),
      Color(0xFF6C73CB),
    ],
    outlineColor: Color(0xFF6C73CB),
    checkedButtonColor: Color(0xFFE2E5F7),
  );

  /// 绿色主题（Journaling）
  static const journaling = HabitHeatmapTheme(
    cardGradient: [Color(0xFF0B1C0E), Color(0xFF17331A)],
    borderColor: Color(0xFF214224),
    iconColor: Color(0xFF4ECB58),
    cellColors: [
      Color(0xFFE9F4EA),
      Color(0xFFC8EDCC),
      Color(0xFF97E39E),
      Color(0xFF4ECB58),
    ],
    outlineColor: Color(0xFF4ECB58),
    checkedButtonColor: Color(0xFFE0F3E2),
  );

  /// 黄色主题（Play dog）
  static const playDog = HabitHeatmapTheme(
    cardGradient: [Color(0xFF211B08), Color(0xFF382E0B)],
    borderColor: Color(0xFF473B12),
    iconColor: Color(0xFFEBBB2D),
    cellColors: [
      Color(0xFFF7F2E3),
      Color(0xFFF4E5AC),
      Color(0xFFF2D36E),
      Color(0xFFEBBB2D),
    ],
    outlineColor: Color(0xFFEBBB2D),
    checkedButtonColor: Color(0xFFF8EFD2),
  );

  /// 橙色主题（Read）
  static const read = HabitHeatmapTheme(
    cardGradient: [Color(0xFF241106), Color(0xFF3B1C0A)],
    borderColor: Color(0xFF4C2611),
    iconColor: Color(0xFFF08130),
    cellColors: [
      Color(0xFFFAEEE3),
      Color(0xFFF8CFAF),
      Color(0xFFF5A96E),
      Color(0xFFF08130),
    ],
    outlineColor: Color(0xFFF08130),
    checkedButtonColor: Color(0xFFFCE9DA),
  );

  /// 按名称获取预设主题
  static HabitHeatmapTheme byName(String? name) {
    switch (name) {
      case 'journaling':
        return journaling;
      case 'playDog':
      case 'play-dog':
        return playDog;
      case 'read':
        return read;
      case 'drinkWater':
      case 'drink-water':
      default:
        return drinkWater;
    }
  }
}

/// 习惯打卡热力图卡片
class HabitHeatmapCard extends StatefulWidget {
  /// 习惯标题（如 'Drink water'）
  final String title;

  /// 头部图标
  final IconData icon;

  /// 热力图矩阵（7 行 x 10 列，值 0-4；4 为今日待打卡空心指示格）
  final List<List<int>> cells;

  /// 今日打卡次数：0=未打卡，1=已打卡，>1=多次打卡
  final int checkInCount;

  /// 主题色板（浅色系，格子/图标/按钮的个性化彩色）
  final HabitHeatmapTheme theme;

  /// 兼容保留：按钮已恒显开始图标，不再消费
  final String checkInLabel;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  /// 打卡按钮点击回调（如触发开始习惯弹窗）
  final VoidCallback? onCheckIn;

  const HabitHeatmapCard({
    super.key,
    required this.title,
    this.icon = Icons.auto_awesome,
    required this.cells,
    this.checkInCount = 0,
    this.theme = HabitHeatmapTheme.drinkWater,
    this.checkInLabel = 'Check-In',
    this.inline = false,
    this.size = const Large3Size(),
    this.onCheckIn,
  });

  /// 从 props 创建实例（注册器统一入口）
  factory HabitHeatmapCard.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    // 解析颜色
    Color? parseColor(dynamic colorValue) {
      if (colorValue is Color) return colorValue;
      if (colorValue is int) return Color(colorValue);
      if (colorValue is String) {
        try {
          if (colorValue.startsWith('#')) {
            return Color(
              int.parse(colorValue.substring(1), radix: 16) + 0xFF000000,
            );
          }
          if (colorValue.startsWith('0x')) {
            return Color(int.parse(colorValue.substring(2), radix: 16));
          }
        } catch (e) {
          // 解析失败，返回 null
        }
      }
      return null;
    }

    // 解析热力图矩阵：支持二维数组或一维数组（按 columns 切分）
    List<List<int>> parseCells(dynamic cellsData, int columns) {
      final cols = columns > 0 ? columns : 10;
      if (cellsData is List) {
        if (cellsData.isNotEmpty && cellsData.first is List) {
          return cellsData
              .map(
                (row) => (row as List)
                    .map((e) => (e as num?)?.toInt() ?? 0)
                    .toList(),
              )
              .toList();
        }
        final flat = cellsData.map((e) => (e as num?)?.toInt() ?? 0).toList();
        final rows = <List<int>>[];
        for (var i = 0; i < flat.length; i += cols) {
          rows.add(flat.sublist(i, math.min(i + cols, flat.length)));
        }
        return rows;
      }
      return const [];
    }

    // 解析主题：预设名称字符串或颜色 Map
    HabitHeatmapTheme parseTheme(dynamic themeData) {
      if (themeData is HabitHeatmapTheme) return themeData;
      if (themeData is String) return HabitHeatmapTheme.byName(themeData);
      if (themeData is Map) {
        final base = HabitHeatmapTheme.byName(themeData['preset'] as String?);
        List<Color>? gradient;
        if (themeData['cardGradient'] is List) {
          gradient = (themeData['cardGradient'] as List)
              .map(parseColor)
              .whereType<Color>()
              .toList();
        }
        List<Color>? cells;
        if (themeData['cellColors'] is List) {
          cells = (themeData['cellColors'] as List)
              .map(parseColor)
              .whereType<Color>()
              .toList();
        }
        return HabitHeatmapTheme(
          cardGradient:
              gradient != null && gradient.length >= 2
                  ? gradient
                  : base.cardGradient,
          borderColor: parseColor(themeData['borderColor']) ?? base.borderColor,
          iconColor: parseColor(themeData['iconColor']) ?? base.iconColor,
          cellColors:
              cells != null && cells.length == 4 ? cells : base.cellColors,
          outlineColor:
              parseColor(themeData['outlineColor']) ?? base.outlineColor,
          checkedButtonColor:
              parseColor(themeData['checkedButtonColor']) ??
              base.checkedButtonColor,
        );
      }
      return HabitHeatmapTheme.drinkWater;
    }

    final iconValue = props['icon'];
    return HabitHeatmapCard(
      title: props['title'] as String? ?? '',
      icon:
          iconValue is IconData
              ? iconValue
              : dynamicIconData(
                (iconValue as num?)?.toInt() ?? Icons.auto_awesome.codePoint,
                fontFamily: 'MaterialIcons',
              ),
      cells: parseCells(props['cells'], (props['columns'] as num?)?.toInt() ?? 10),
      checkInCount:
          (props['checkInCount'] as num?)?.toInt() ??
          (props['count'] as num?)?.toInt() ??
          0,
      theme: parseTheme(props['theme']),
      checkInLabel: props['checkInLabel'] as String? ?? 'Check-In',
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<HabitHeatmapCard> createState() => _HabitHeatmapCardState();
}

class _HabitHeatmapCardState extends State<HabitHeatmapCard> {
  double _defaultHeight() {
    final scale = widget.size.scale;
    if (widget.size is SmallSize) {
      return 170 * scale;
    }
    if (widget.size is MediumSize || widget.size is WideSize) {
      return 210 * scale;
    }
    if (widget.size is LargeSize || widget.size is Wide2Size) {
      return 330 * scale;
    }
    return 410 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘描画入场：挂载即播一次，墨线「画出来」而非淡入
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        radius: BorderRadius.circular(24 * scale),
        padding: EdgeInsets.all(16 * scale * widget.size.padding),
        child: _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(AppThemeData theme) {
    // 小尺寸只显示热力图
    if (widget.size is SmallSize) {
      return Center(
        child: _HeatmapGrid(
          cells: widget.cells,
          palette: widget.theme,
          scale: widget.size.scale,
        ),
      );
    }

    final scale = widget.size.scale;

    // 宽条型：热力图居左，头部与按钮在右
    if (widget.size.width > widget.size.height) {
      return Row(
        children: [
          Expanded(
            flex: 55,
            child: Center(
              child: _HeatmapGrid(
                cells: widget.cells,
                palette: widget.theme,
                scale: scale,
              ),
            ),
          ),
          SizedBox(width: 16 * scale),
          Expanded(
            flex: 45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme),
                const Spacer(),
                _buildCheckInButton(theme),
              ],
            ),
          ),
        ],
      );
    }

    // 其余：头部在上、热力图居中、按钮在底
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(theme),
        SizedBox(height: 14 * scale),
        _HeatmapGrid(cells: widget.cells, palette: widget.theme, scale: scale),
        const Spacer(),
        SizedBox(height: 14 * scale),
        _buildCheckInButton(theme),
      ],
    );
  }

  /// 头部：手绘图标 + 标题
  Widget _buildHeader(AppThemeData theme) {
    final scale = widget.size.scale;
    return Row(
      children: [
        WiredIcon(
          icon: widget.icon,
          size: 20 * scale,
          color: widget.theme.iconColor,
          drawConfig: theme.wired.drawConfig,
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              color: theme.text,
              fontSize: 17.5 * scale,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  /// 底部胶囊打卡按钮：恒显开始图标（未打卡主色实底，已打卡淡底）
  Widget _buildCheckInButton(AppThemeData theme) {
    final scale = widget.size.scale;
    final buttonHeight = 47.0 * scale;
    final checked = widget.checkInCount > 0;
    final palette = widget.theme;

    return GestureDetector(
      onTap: widget.onCheckIn,
      child: Container(
        height: buttonHeight,
        decoration: dsSketchDecoration(
          theme: theme,
          // 大圆角被 rough 引擎自动钳制成胶囊
          radius: BorderRadius.circular(buttonHeight / 2),
          fillColor: checked ? palette.checkedButtonColor : palette.iconColor,
          strokeWidth: 1.6,
        ),
        child: Center(
          child: DsIcon(
            DsIconKind.play,
            size: 22 * scale,
            color: checked ? palette.iconColor : theme.surface,
          ),
        ),
      ),
    );
  }
}

/// 热力图矩阵（cell 随宽度自适应，宽高比 1:1）
class _HeatmapGrid extends StatelessWidget {
  final List<List<int>> cells;
  final HabitHeatmapTheme palette;
  final double scale;

  const _HeatmapGrid({required this.cells, required this.palette, required this.scale});

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty || cells.first.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = cells.length;
        final cols = cells.first.length;
        final gap = 4.6 * scale;
        final cell = (constraints.maxWidth - (cols - 1) * gap) / cols;
        final height = rows * cell + (rows - 1) * gap;

        return SizedBox(
          width: constraints.maxWidth,
          height: height,
          child: CustomPaint(
            painter: _HeatmapPainter(
              cells: cells,
              cell: cell,
              gap: gap,
              palette: palette,
              theme: AppTheme.of(context),
              // 外层无 WiredDraw（或动画被禁用）时为 null = 全部直接画完
              progress: WiredDrawTransition.progressOf(context),
            ),
          ),
        );
      },
    );
  }
}

/// 热力图绘制器：rough 墨线格，逐格错峰描画（消费外层 WiredDraw 进度）
///
/// 值 0=淡底空格；1-3=色板 cellColors 由浅到浓实底；4=色板 outline 空心待打卡格
class _HeatmapPainter extends CustomPainter {
  final List<List<int>> cells;
  final double cell;
  final double gap;
  final HabitHeatmapTheme palette;
  final AppThemeData theme;
  final Animation<double>? progress;

  _HeatmapPainter({
    required this.cells,
    required this.cell,
    required this.gap,
    required this.palette,
    required this.theme,
    required this.progress,
  }) : super(repaint: progress);

  /// 每格 rough 绘图缓存（painter 随尺寸变化重建，动画帧间复用）
  late final List<RoughDrawing> _drawings = _buildDrawings();

  List<RoughDrawing> _buildDrawings() {
    final rows = cells.length;
    final cols = cells.first.length;
    final radius = cell * 0.19;

    final config = theme.wired.drawConfig;
    config.randomizer.reset();
    final solidGen = Generator(config, SolidFiller());
    final lineGen = Generator(config, NoFiller());

    Paint stroke(double width, Color color) =>
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = width
          ..color = color;

    final cellColors = palette.cellColors;
    final emptyColor = cellColors.isNotEmpty ? cellColors[0] : theme.surfaceAlt;

    return List.generate(rows * cols, (i) {
      final r = i ~/ cols;
      final c = i % cols;
      final value = c < cells[r].length ? cells[r][c] : 0;
      final x = c * (cell + gap);
      final y = r * (cell + gap);
      final filled = value >= 1 && value <= 3 && cellColors.length == 4;

      final borderPaint = switch (value) {
        0 => stroke(1.2, theme.ink.withValues(alpha: 0.22)),
        4 => stroke(1.8, palette.outlineColor),
        _ => stroke(1.2, theme.ink.withValues(alpha: 0.45)),
      };
      final fillPaint = switch (value) {
        0 => stroke(1.2, emptyColor),
        1 => stroke(1.2, cellColors[1]),
        2 => stroke(1.2, cellColors[2]),
        3 => stroke(1.2, cellColors[3]),
        _ => stroke(1.2, const Color(0x00000000)),
      };

      final gen = filled ? solidGen : lineGen;
      return RoughDrawing(
        gen.roundedRectangle(x, y, cell, cell, radius, radius, radius, radius),
        borderPaint,
        fillPaint,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rows = cells.length;
    final cols = cells.first.length;
    final total = rows * cols;
    final p = progress?.value ?? 1;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols && c < cells[r].length; c++) {
        final index = r * cols + c;
        // 依次错峰描画：前半段总进度用于铺开全部 cell 的起点
        final start = 0.5 * (index / total);
        final local = ((p - start) / 0.5).clamp(0.0, 1.0);
        if (local <= 0) continue;
        _drawings[index].paint(canvas, progress: local, pressure: 0);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.cells != cells ||
        oldDelegate.cell != cell ||
        oldDelegate.palette != palette ||
        oldDelegate.theme != theme;
  }
}
