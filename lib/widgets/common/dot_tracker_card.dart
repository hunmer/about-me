import 'dart:convert';
import 'dart:math' as math;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

/// 点阵追踪卡片数据模型
///
/// 用于存储点阵追踪卡片的配置数据，支持 JSON 序列化。
class DotTrackerCardData {
  /// 卡片标题
  final String title;

  /// 卡片图标代码点（用于 JSON 序列化）
  final int iconCodePoint;

  /// 当前数值
  final int currentValue;

  /// 数值单位
  final String unit;

  /// 状态文本（如 "On Track"）
  final String status;

  /// 周日期标签列表（如 ['M', 'T', 'W', 'T', 'F', 'S', 'S']）
  final List<String> weekDays;

  /// 每天的点阵状态（true 表示已完成/激活，false 表示未完成）
  /// 外层列表长度应与 weekDays 一致，内层列表表示每天的多状态
  final List<List<bool>> dotStates;

  const DotTrackerCardData({
    required this.title,
    required this.iconCodePoint,
    required this.currentValue,
    required this.unit,
    required this.status,
    required this.weekDays,
    required this.dotStates,
  });

  /// 从图标创建数据
  factory DotTrackerCardData.withIcon({
    required String title,
    required IconData icon,
    required int currentValue,
    required String unit,
    required String status,
    required List<String> weekDays,
    required List<List<bool>> dotStates,
  }) {
    return DotTrackerCardData(
      title: title,
      iconCodePoint: icon.codePoint,
      currentValue: currentValue,
      unit: unit,
      status: status,
      weekDays: weekDays,
      dotStates: dotStates,
    );
  }

  /// 从 JSON 创建数据
  factory DotTrackerCardData.fromJson(Map<String, dynamic> json) {
    return DotTrackerCardData(
      title: json['title'] as String,
      iconCodePoint: json['iconCodePoint'] as int,
      currentValue: json['currentValue'] as int,
      unit: json['unit'] as String,
      status: json['status'] as String,
      weekDays: List<String>.from(json['weekDays'] as List),
      dotStates:
          (json['dotStates'] as List)
              .map((day) => List<bool>.from(day as List))
              .toList(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'iconCodePoint': iconCodePoint,
      'currentValue': currentValue,
      'unit': unit,
      'status': status,
      'weekDays': weekDays,
      'dotStates': dotStates,
    };
  }

  /// 从 JSON 字符串创建数据
  factory DotTrackerCardData.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return DotTrackerCardData.fromJson(json);
  }

  /// 转换为 JSON 字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// 复制并修改部分字段
  DotTrackerCardData copyWith({
    String? title,
    int? iconCodePoint,
    int? currentValue,
    String? unit,
    String? status,
    List<String>? weekDays,
    List<List<bool>>? dotStates,
  }) {
    return DotTrackerCardData(
      title: title ?? this.title,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      weekDays: weekDays ?? this.weekDays,
      dotStates: dotStates ?? this.dotStates,
    );
  }

  /// 获取图标
  IconData get icon => dynamicIconData(iconCodePoint, fontFamily: 'MaterialIcons');
}

/// 点阵追踪卡片小组件
///
/// 用于展示周度点阵追踪进度，例如每日目标完成情况、习惯打卡等。
/// 手绘纸墨风（纸底 + 淡排线 + rough 墨线框，WiredDraw 墨线描画入场）：
/// 点阵参照 habit_heatmap（档位色实底 + 淡墨描边，不做斜纹），
/// 逐点错峰弹入与数值翻牌动画保留。
/// 根据尺寸自动调整所有元素大小。
class DotTrackerCardWidget extends StatefulWidget {
  /// 卡片标题
  final String title;

  /// 卡片图标
  final IconData icon;

  /// 当前数值
  final int currentValue;

  /// 数值单位
  final String unit;

  /// 状态文本（如 "On Track"）
  final String status;

  /// 周日期标签列表（如 ['M', 'T', 'W', 'T', 'F', 'S', 'S']）
  final List<String> weekDays;

  /// 每天的点阵状态（true 表示已完成/激活，false 表示未完成）
  /// 外层列表长度应与 weekDays 一致，内层列表表示每天的多状态
  final List<List<bool>> dotStates;

  /// 自定义宽度
  final double? width;

  /// 自定义高度
  final double? height;

  /// 是否启用动画
  final bool enableAnimation;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸，用于调整所有元素大小
  final HomeWidgetSize size;

  /// 点击回调
  final VoidCallback? onTap;

  const DotTrackerCardWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.currentValue,
    required this.unit,
    required this.status,
    required this.weekDays,
    required this.dotStates,
    this.width,
    this.height,
    this.enableAnimation = true,
    this.inline = false,
    this.size = const MediumSize(),
    this.onTap,
  });

  /// 从数据模型创建组件
  factory DotTrackerCardWidget.fromData(
    DotTrackerCardData data, {
    Key? key,
    double? width,
    double? height,
    bool enableAnimation = true,
    bool inline = false,
    HomeWidgetSize size = const MediumSize(),
    VoidCallback? onTap,
  }) {
    return DotTrackerCardWidget(
      key: key,
      title: data.title,
      icon: data.icon,
      currentValue: data.currentValue,
      unit: data.unit,
      status: data.status,
      weekDays: data.weekDays,
      dotStates: data.dotStates,
      width: width,
      height: height,
      enableAnimation: enableAnimation,
      inline: inline,
      size: size,
      onTap: onTap,
    );
  }

  @override
  State<DotTrackerCardWidget> createState() => _DotTrackerCardWidgetState();
}

class _DotTrackerCardWidgetState extends State<DotTrackerCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late int _displayValue;

  @override
  void initState() {
    super.initState();
    _displayValue = 0;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    if (widget.enableAnimation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _displayValue = widget.currentValue;
          });
          _animationController.forward();
        }
      });
    } else {
      _displayValue = widget.currentValue;
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(DotTrackerCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableAnimation &&
        (oldWidget.currentValue != widget.currentValue ||
            oldWidget.dotStates != widget.dotStates)) {
      setState(() {
        _displayValue = widget.currentValue;
      });
      _animationController.reset();
      _animationController.forward();
    } else if (!widget.enableAnimation) {
      setState(() {
        _displayValue = widget.currentValue;
      });
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final size = widget.size;

    // 数据色：激活点档位色（无 props 数据色时取主题色）
    final primaryColor = theme.secondary;
    final primaryLight = primaryColor.withValues(alpha: 0.3);

    // 数值显示（使用 Positioned 定位在右上角，不受 padding 影响）
    final valueDisplay = Positioned(
      top: size.getSmallSpacing() * 4,
      right: size.getSmallSpacing() * 6,
      child: _buildValueDisplay(theme, size),
    );

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 墨线描画入场
    final card = WiredDraw(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DsSketchPanel(
            theme: theme,
            height: widget.inline ? double.maxFinite : (widget.height ?? 250),
            radius: BorderRadius.circular(24 * size.scale),
            padding: size.getPadding(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏（包含 status 作为副标题）
                _buildHeader(theme, size),
                SizedBox(height: size.getTitleSpacing()),
                // 点阵进度（占满剩余空间）
                Expanded(
                  child: _buildDotsGrid(primaryColor, primaryLight, size),
                ),
              ],
            ),
          ),
          valueDisplay,
        ],
      ),
    );

    if (widget.onTap != null) {
      return InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(28),
        child: card,
      );
    }

    return card;
  }

  Widget _buildHeader(AppThemeData theme, HomeWidgetSize size) {
    final titleFontSize = size.getTitleFontSize() * 0.75;
    final subtitleFontSize = size.getSubtitleFontSize();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: theme.text,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: size.getSmallSpacing()),
            Text(
              widget.status,
              style: TextStyle(
                fontSize: subtitleFontSize,
                fontWeight: FontWeight.w500,
                color: theme.textSub,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValueDisplay(AppThemeData theme, HomeWidgetSize size) {
    final valueFontSize = size.getLargeFontSize() * 0.6;
    final unitFontSize = size.getSubtitleFontSize() * 0.7;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedFlipCounter(
          value: _displayValue.toDouble(),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          textStyle: TextStyle(
            fontSize: valueFontSize,
            fontWeight: FontWeight.w800,
            color: theme.text,
            height: 1.0,
            letterSpacing: -1,
          ),
        ),
        SizedBox(width: size.getSmallSpacing() * 1.5),
        Text(
          widget.unit,
          style: TextStyle(
            fontSize: unitFontSize,
            fontWeight: FontWeight.w600,
            color: theme.textSub,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildDotsGrid(Color primaryColor, Color primaryLight, HomeWidgetSize size) {
    final dayCount = widget.weekDays.length;

    // 计算列数：根据天数决定
    final crossAxisCount = dayCount <= 14 ? dayCount : (dayCount > 30 ? 7 : 7);

    // 计算动画步长
    final step = dayCount > 1 ? 0.35 / (dayCount - 1) : 0.0;

    // 根据尺寸计算圆点大小
    final dotSize =
        size is SmallSize
            ? 16.0
            : (size is MediumSize || size is WideSize ? 26.0 : 30.0);
    final dotSpacing = size.getSmallSpacing();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: true,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 0,
              crossAxisSpacing: dotSpacing * 0.5,
              mainAxisExtent: constraints.maxHeight,
            ),
            itemCount: dayCount,
            itemBuilder: (context, index) {
              final itemAnimation = CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  index * step,
                  0.65 + index * step,
                  curve: Curves.easeOutCubic,
                ),
              );

              return _DayDotColumn(
                dotStates: widget.dotStates[index],
                primaryColor: primaryColor,
                primaryLight: primaryLight,
                animation:
                    widget.enableAnimation
                        ? itemAnimation
                        : AlwaysStoppedAnimation(1.0),
                dotSize: dotSize,
              );
            },
          ),
        );
      },
    );
  }
}

/// 每日点阵列组件
///
/// 点阵为平直几何：激活档数据色实底 + 淡墨描边，空档 surfaceAlt 实底 +
/// 更淡墨描边（参照 habit_heatmap 的档位格，不做斜纹）；
/// 激活点随 [animation] 逐点弹入。
class _DayDotColumn extends StatelessWidget {
  final List<bool> dotStates;
  final Color primaryColor;
  final Color primaryLight;
  final Animation<double> animation;
  final double dotSize;

  const _DayDotColumn({
    required this.dotStates,
    required this.primaryColor,
    required this.primaryLight,
    required this.animation,
    required this.dotSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // CustomPaint 无 child：GridView cell 给紧宽紧高，显式撑满防塌缩
    return CustomPaint(
      size: const Size(double.infinity, double.infinity),
      painter: _DotColumnPainter(
        dotStates: dotStates,
        primaryColor: primaryColor,
        primaryLight: primaryLight,
        theme: theme,
        animation: animation,
        dotSize: dotSize,
      ),
    );
  }
}

/// 点阵列绘制器：档位色实底 + 淡墨描边（habit_heatmap 同款手法）
class _DotColumnPainter extends CustomPainter {
  final List<bool> dotStates;
  final Color primaryColor;
  final Color primaryLight;
  final AppThemeData theme;
  final Animation<double> animation;
  final double dotSize;

  _DotColumnPainter({
    required this.dotStates,
    required this.primaryColor,
    required this.primaryLight,
    required this.theme,
    required this.animation,
    required this.dotSize,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || dotStates.isEmpty) return;
    final n = dotStates.length;
    final cellHeight = size.height / n;
    final radius = math.min(dotSize, cellHeight) / 2;
    final center = Offset(size.width / 2, 0);
    final allEmpty = dotStates.every((s) => !s);

    for (var i = 0; i < n; i++) {
      final enabled = dotStates[i];
      // 激活档：数据色实底 + 淡墨描边，逐点弹入（半径随错峰动画生长）
      final fill =
          enabled
              ? primaryColor
              : (i == 0 && allEmpty ? primaryLight : theme.surfaceAlt);
      var r = radius;
      if (enabled) {
        r *= animation.value;
      }
      if (r <= 0.1) continue;
      final cy = cellHeight * (i + 0.5);
      canvas.drawCircle(center.translate(0, cy), r, Paint()..color = fill);
      canvas.drawCircle(
        center.translate(0, cy),
        r,
        Paint()
          ..color = theme.ink.withValues(alpha: enabled ? 0.45 : 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DotColumnPainter oldDelegate) {
    return oldDelegate.dotStates != dotStates ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.primaryLight != primaryLight ||
        oldDelegate.theme != theme ||
        oldDelegate.dotSize != dotSize;
  }
}
