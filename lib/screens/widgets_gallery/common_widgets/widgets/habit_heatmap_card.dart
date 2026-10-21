/// 习惯打卡热力图卡片 - 公共小组件（iOS 深色小组件风格）
///
/// 结构：彩色图标 + 标题头部 / 7x10 四档亮度热力图矩阵（值 4 为今日待打卡空心格）
/// / 底部胶囊打卡按钮（未打卡 Check-In / 已打卡勾号 / 多次打卡勾号 + x N）。
/// 内置 4 套主题色板（drinkWater / journaling / playDog / read）。
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 习惯打卡热力图主题色板
class HabitHeatmapTheme {
  /// 卡片背景渐变（自上而下偏右，约 155deg）
  final List<Color> cardGradient;

  /// 卡片 1px 内描边颜色
  final Color borderColor;

  /// 头部图标颜色
  final Color iconColor;

  /// 热力图 cell 颜色（0=未打卡暗底，1=饱和主色，2=中等亮度，3=高亮浅色）
  final List<Color> cellColors;

  /// 今日待打卡空心格描边颜色
  final Color outlineColor;

  /// 已打卡按钮底色（勾号为白圆底 + 该色勾）
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
    iconColor: Color(0xFF6972D6),
    cellColors: [
      Color(0xFF272838),
      Color(0xFF6C73CB),
      Color(0xFF9DA5E8),
      Color(0xFFD0D5F7),
    ],
    outlineColor: Color(0xFF656CC2),
    checkedButtonColor: Color(0xFF32344A),
  );

  /// 绿色主题（Journaling）
  static const journaling = HabitHeatmapTheme(
    cardGradient: [Color(0xFF0B1C0E), Color(0xFF17331A)],
    borderColor: Color(0xFF214224),
    iconColor: Color(0xFF48E554),
    cellColors: [
      Color(0xFF213824),
      Color(0xFF3FD849),
      Color(0xFF7BEF83),
      Color(0xFFBEF9C3),
    ],
    outlineColor: Color(0xFF48E554),
    checkedButtonColor: Color(0xFF2B472D),
  );

  /// 黄色主题（Play dog）
  static const playDog = HabitHeatmapTheme(
    cardGradient: [Color(0xFF211B08), Color(0xFF382E0B)],
    borderColor: Color(0xFF473B12),
    iconColor: Color(0xFFF7C520),
    cellColors: [
      Color(0xFF3C3315),
      Color(0xFFF6C218),
      Color(0xFFFBE069),
      Color(0xFFFEF0A5),
    ],
    outlineColor: Color(0xFFF6C218),
    checkedButtonColor: Color(0xFF4C4017),
  );

  /// 橙色主题（Read）
  static const read = HabitHeatmapTheme(
    cardGradient: [Color(0xFF241106), Color(0xFF3B1C0A)],
    borderColor: Color(0xFF4C2611),
    iconColor: Color(0xFFF7630C),
    cellColors: [
      Color(0xFF3F2212),
      Color(0xFFF06915),
      Color(0xFFF6934C),
      Color(0xFFFCC396),
    ],
    outlineColor: Color(0xFFF06915),
    checkedButtonColor: Color(0xFF502D1A),
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

  /// 主题色板
  final HabitHeatmapTheme theme;

  /// 未打卡按钮文字
  final String checkInLabel;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

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

class _HabitHeatmapCardState extends State<HabitHeatmapCard>
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
    _animationController.addListener(() {
      setState(() {});
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
    final scale = widget.size.scale;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _animation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.theme.cardGradient,
            begin: const Alignment(-0.42, -0.91),
            end: const Alignment(0.42, 0.91),
          ),
          borderRadius: BorderRadius.circular(24 * scale),
          border: Border.all(color: widget.theme.borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20 * scale,
              offset: Offset(0, 4 * scale),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16 * scale * widget.size.padding),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // 小尺寸只显示热力图
    if (widget.size is SmallSize) {
      return Center(
        child: _HeatmapGrid(
          cells: widget.cells,
          theme: widget.theme,
          progress: _animation.value,
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
                theme: widget.theme,
                progress: _animation.value,
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
                _buildHeader(),
                const Spacer(),
                _buildCheckInButton(),
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
        _buildHeader(),
        SizedBox(height: 14 * scale),
        _HeatmapGrid(
          cells: widget.cells,
          theme: widget.theme,
          progress: _animation.value,
          scale: scale,
        ),
        const Spacer(),
        SizedBox(height: 14 * scale),
        _buildCheckInButton(),
      ],
    );
  }

  /// 头部：彩色图标 + 白色标题
  Widget _buildHeader() {
    final scale = widget.size.scale;
    return Row(
      children: [
        Icon(widget.icon, color: widget.theme.iconColor, size: 20 * scale),
        SizedBox(width: 8 * scale),
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              color: Colors.white,
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

  /// 底部胶囊打卡按钮（三态）
  Widget _buildCheckInButton() {
    final scale = widget.size.scale;
    final buttonHeight = 47.0 * scale;
    final radius = BorderRadius.circular(buttonHeight / 2);

    final buttonAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOutBack),
    );

    final Widget content;
    final Color background;
    if (widget.checkInCount <= 0) {
      background = const Color(0xFFA4A5AF);
      content = Text(
        widget.checkInLabel,
        style: TextStyle(
          color: const Color(0xFF23242E),
          fontSize: 16 * scale,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      );
    } else {
      background = widget.theme.checkedButtonColor;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCheckBadge(scale),
          if (widget.checkInCount > 1) ...[
            SizedBox(width: 8 * scale),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'x ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: '${widget.checkInCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 15 * scale, height: 1.0),
            ),
          ],
        ],
      );
    }

    return AnimatedBuilder(
      animation: buttonAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.85 + 0.15 * buttonAnimation.value,
          child: Opacity(opacity: buttonAnimation.value, child: child),
        );
      },
      child: Container(
        height: buttonHeight,
        decoration: BoxDecoration(color: background, borderRadius: radius),
        child: Center(child: content),
      ),
    );
  }

  /// 白圆底 + 主题深色勾号
  Widget _buildCheckBadge(double scale) {
    final badgeSize = 22.0 * scale;
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        color: widget.theme.checkedButtonColor,
        size: badgeSize * 0.68,
      ),
    );
  }
}

/// 热力图矩阵（cell 随宽度自适应，宽高比 1:1）
class _HeatmapGrid extends StatelessWidget {
  final List<List<int>> cells;
  final HabitHeatmapTheme theme;
  final double progress;
  final double scale;

  const _HeatmapGrid({
    required this.cells,
    required this.theme,
    required this.progress,
    required this.scale,
  });

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
              theme: theme,
              gap: gap,
              progress: progress,
            ),
          ),
        );
      },
    );
  }
}

/// 热力图绘制器（cell 依次淡入）
class _HeatmapPainter extends CustomPainter {
  final List<List<int>> cells;
  final HabitHeatmapTheme theme;
  final double gap;
  final double progress;

  _HeatmapPainter({
    required this.cells,
    required this.theme,
    required this.gap,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rows = cells.length;
    final cols = cells.first.length;
    final total = rows * cols;
    final cell = (size.width - (cols - 1) * gap) / cols;
    final radius = Radius.circular(cell * 0.19);

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols && c < cells[r].length; c++) {
        final value = cells[r][c];
        final index = r * cols + c;
        // 依次淡入：前半段总进度用于铺开全部 cell 的起点
        final start = 0.5 * (index / total);
        final local = ((progress - start) / 0.5).clamp(0.0, 1.0);
        if (local <= 0) continue;

        final rect = Rect.fromLTWH(
          c * (cell + gap),
          r * (cell + gap),
          cell,
          cell,
        );
        final rrect = RRect.fromRectAndRadius(rect, radius);

        final fillPaint =
            Paint()
              ..color = theme.cellColors[value.clamp(0, 3)].withOpacity(local)
              ..style = PaintingStyle.fill;
        canvas.drawRRect(rrect, fillPaint);

        // 值 4：今日待打卡空心格（0 档底色 + 内描边）
        if (value == 4) {
          final strokeWidth = math.max(1.2, cell * 0.05);
          final borderPaint =
              Paint()
                ..color = theme.outlineColor.withOpacity(local)
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth;
          canvas.drawRRect(rrect.deflate(strokeWidth / 2), borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.cells != cells ||
        oldDelegate.theme != theme;
  }
}
