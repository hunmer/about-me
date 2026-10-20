import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 连线任务流卡片条目数据
class LinkedTaskItemData {
  /// 任务标题
  final String title;

  /// 负责人名称
  final String assignee;

  /// 完成进度（0 - 100）
  final double progress;

  /// 头像底色（为 null 时按索引轮换默认渐变色）
  final Color? avatarColor;

  /// 头像图标（为 null 时显示负责人首字母）
  final IconData? avatarIcon;

  /// 卡片宽度占比（0 - 1，为 null 时按索引轮换 0.645 / 0.765 / 0.76）
  final double? widthFactor;

  /// 头像槽：自定义头像 Widget（如心情表情），优先于 avatarColor/avatarIcon
  final Widget? avatar;

  /// 照片槽：显示在顶行胶囊右侧的圆形缩略图
  final ImageProvider? photo;

  /// 文本胶囊槽位（非空时替代 "Assign to" 固定行）
  final List<String>? chips;

  /// 是否显示进度填充与百分比文案（默认 true）
  final bool showProgress;

  /// 进度关闭时胶囊内的文字槽（如天气/位置）
  final String? badgeText;

  /// 负责人行前缀文案（默认 "Assign to: "，传空串则只显示内容）
  final String? assignLabel;

  /// 图片堆叠槽：嵌入卡片的自定义内容（如 WalkStackCardWidget 照片堆），
  /// 占据 chips 行以下的剩余卡面空间（FittedBox 自适应缩放）
  final Widget? photoStack;

  const LinkedTaskItemData({
    required this.title,
    required this.assignee,
    this.progress = 0,
    this.avatarColor,
    this.avatarIcon,
    this.widthFactor,
    this.avatar,
    this.photo,
    this.chips,
    this.showProgress = true,
    this.badgeText,
    this.assignLabel,
    this.photoStack,
  });
}

/// 自定义卡面构建器：[index] 对应 [LinkedTaskItemData] 在 items 中的下标
typedef LinkedTaskCardBuilder = Widget Function(BuildContext context, int index);

/// 连线任务流卡片
///
/// 参考橙色 Admin Dashboard 效果图：交错左右对齐的任务卡片
/// （头像 + 进度胶囊 + 标题 + 负责人）由贝塞尔曲线依次相连，
/// 入场时按「卡片浮现 -> 连线生长 -> 下一张卡片」编排播放，
/// 连线带循环流光与端点圆点。
///
/// 提供 [LinkedTaskFlowCardWidget.cardBuilder] 时卡面整面外置，
/// 组件仅负责交错布局、连线与动画。
class LinkedTaskFlowCardWidget extends StatefulWidget {
  /// 任务条目列表（相邻两张卡片之间自动连线）
  final List<LinkedTaskItemData> items;

  /// 背景渐变起始色（默认 #F87941）
  final Color backgroundFrom;

  /// 背景渐变结束色（默认 #F47238）
  final Color backgroundTo;

  /// 卡片底色（默认 #FDA882）
  final Color cardColor;

  /// 连线与端点颜色（默认白色）
  final Color connectorColor;

  /// 是否显示背景斜向细纹理
  final bool showStripes;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 条目点击回调（null 时不可点击）
  final void Function(int index)? onItemTap;

  /// 组件尺寸
  final HomeWidgetSize size;

  /// 单卡高度（设计基准 px，默认 130；嵌入 photoStack 等大内容时可调高）
  final double cardHeight;

  /// 自定义卡面构建器（提供时整面替换默认任务卡面，
  /// 组件仅保留交错布局、贝塞尔连线与入场编排——连线能力本体）
  final LinkedTaskCardBuilder? cardBuilder;

  const LinkedTaskFlowCardWidget({
    super.key,
    required this.items,
    this.backgroundFrom = const Color(0xFFF87941),
    this.backgroundTo = const Color(0xFFF47238),
    this.cardColor = const Color(0xFFFDA882),
    this.connectorColor = Colors.white,
    this.showStripes = true,
    this.inline = false,
    this.onItemTap,
    this.size = const Large3Size(),
    this.cardHeight = 130,
    this.cardBuilder,
  });

  /// 从 props 创建实例
  factory LinkedTaskFlowCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    Color? tryParseColor(dynamic value) {
      if (value is Color) return value;
      if (value is int) return Color(value);
      if (value is String) {
        try {
          if (value.startsWith('#')) {
            return Color(int.parse(value.substring(1), radix: 16) + 0xFF000000);
          }
          if (value.startsWith('0x')) {
            return Color(int.parse(value.substring(2), radix: 16));
          }
        } catch (_) {}
      }
      return null;
    }

    Color parseColor(dynamic value, Color fallback) =>
        tryParseColor(value) ?? fallback;

    List<LinkedTaskItemData> parseItems(dynamic itemsData) {
      if (itemsData is! List) return [];
      return itemsData.map((raw) {
        if (raw is Map<String, dynamic>) {
          final icon = raw['avatarIcon'];
          return LinkedTaskItemData(
            title: raw['title'] as String? ?? '',
            assignee: raw['assignee'] as String? ?? '',
            progress: (raw['progress'] as num?)?.toDouble() ?? 0,
            avatarColor: tryParseColor(raw['avatarColor']),
            avatarIcon: icon is IconData
                ? icon
                : dynamicIconData(
                    (icon as num?)?.toInt() ?? Icons.person.codePoint,
                    fontFamily: 'MaterialIcons',
                  ),
            widthFactor: (raw['widthFactor'] as num?)?.toDouble(),
          );
        }
        return LinkedTaskItemData(title: '', assignee: '');
      }).toList();
    }

    return LinkedTaskFlowCardWidget(
      items: parseItems(props['items']),
      backgroundFrom: parseColor(props['backgroundFrom'], const Color(0xFFF87941)),
      backgroundTo: parseColor(props['backgroundTo'], const Color(0xFFF47238)),
      cardColor: parseColor(props['cardColor'], const Color(0xFFFDA882)),
      connectorColor: parseColor(props['connectorColor'], Colors.white),
      showStripes: props['showStripes'] as bool? ?? true,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<LinkedTaskFlowCardWidget> createState() =>
      _LinkedTaskFlowCardWidgetState();

  /// 重播指定卡片组件的入场编排动画
  ///
  /// [key] 需挂在 [LinkedTaskFlowCardWidget] 上（示例页的"重播"按钮用）
  static void replayOf(GlobalKey key) {
    final state = key.currentState;
    if (state is _LinkedTaskFlowCardWidgetState) {
      state.replay();
    }
  }
}

class _LinkedTaskFlowCardWidgetState extends State<LinkedTaskFlowCardWidget>
    with TickerProviderStateMixin {
  /// 编排控制器（卡片入场 / 连线生长 / 胶囊填充）
  late AnimationController _sequence;

  /// 流光循环控制器
  late AnimationController _flow;

  @override
  void initState() {
    super.initState();
    _sequence = AnimationController(
      duration: Duration(milliseconds: _totalDurationMs),
      vsync: this,
    )..forward();
    _flow = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();
  }

  @override
  void didUpdateWidget(LinkedTaskFlowCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _sequence.duration = Duration(milliseconds: _totalDurationMs);
      _sequence.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sequence.dispose();
    _flow.dispose();
    super.dispose();
  }

  /// 重播整套入场编排动画
  void replay() => _sequence.forward(from: 0);

  // ===== 编排时间轴（毫秒，参考原效果图的节奏） =====
  static const _firstDelay = 180.0;
  static const _cardStagger = 800.0;
  static const _cardInMs = 450.0;
  static const _fillMs = 900.0;
  static const _lineDelay = 340.0;
  static const _lineGrowMs = 650.0;
  static const _tailMs = 700.0;

  int get _totalDurationMs =>
      (_firstDelay + (widget.items.length - 1) * _cardStagger + _tailMs)
          .round();

  double _t(int index) => _firstDelay + index * _cardStagger;

  /// [a, b] 区间的编排进度（0 - 1，超出自动截断）
  double _phase(double startMs, double durationMs) {
    final total = _totalDurationMs;
    final value = Interval(
      (startMs / total).clamp(0.0, 1.0),
      ((startMs + durationMs) / total).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    ).transform(_sequence.value);
    return value.clamp(0.0, 1.0);
  }

  // ===== 几何计算（以 375 逻辑宽为设计基准） =====
  static const _designWidth = 375.0;
  static const _defaultWidthFactors = [0.645, 0.765, 0.76];
  static const _defaultAvatarColors = [
    Color(0xFF4A90D9),
    Color(0xFFD99B16),
    Color(0xFF29B6F6),
  ];

  double _widthFactor(int index) =>
      widget.items[index].widthFactor ??
      _defaultWidthFactors[index % _defaultWidthFactors.length];

  bool _isLeftAligned(int index) => index.isEven;

  double _computeHeight(double boxWidth) {
    final k = boxWidth / _designWidth;
    final n = math.max(1, widget.items.length);
    return n * widget.cardHeight * k + (n - 1) * 26 * k + 2 * 14 * k;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxWidth = widget.inline ? null : 384 * widget.size.scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 固定宽度不超过可用宽度，避免窄容器溢出
        final fixedWidth = boxWidth;
        final width = fixedWidth == null || !constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : math.min(fixedWidth, constraints.maxWidth);
        final k = width / _designWidth;
        final vPad = 14.0 * k;
        final hPad = 16.0 * k;
        final cardH = widget.cardHeight * k;
        final gap = 26.0 * k;
        final stageW = width - 2 * hPad;

        // 高度受限时按预算裁剪可见卡片数
        var visibleCount = widget.items.length;
        final maxHeight = constraints.maxHeight;
        if (maxHeight.isFinite) {
          final budget = (maxHeight - 2 * vPad + gap) / (cardH + gap);
          visibleCount = math.max(1, math.min(visibleCount, budget.floor()));
        }

        final bgFrom = isDark
            ? Color.lerp(widget.backgroundFrom, Colors.black, 0.45)!
            : widget.backgroundFrom;
        final bgTo = isDark
            ? Color.lerp(widget.backgroundTo, Colors.black, 0.45)!
            : widget.backgroundTo;

        return Container(
          width: width,
          height: widget.inline
              ? double.maxFinite
              : _computeHeight(width),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24 * widget.size.scale),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                blurRadius: 20 * widget.size.scale,
                offset: Offset(0, 4 * widget.size.scale),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _BackgroundPainter(
              gradientColors: [bgFrom, bgTo],
              stripeColor: const Color(0xFFC64814).withValues(alpha: 0.24),
              stripeSpacing: 25 * k,
              stripeWidth: 1.3 * k,
              showStripes: widget.showStripes,
            ),
            child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                child: Center(
                  child: SizedBox(
                    width: stageW,
                    height: visibleCount * cardH + (visibleCount - 1) * gap,
                    child: Stack(
                      children: [
                        // 连线层（置于卡片底层）
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ConnectorsPainter(
                              itemCount: visibleCount,
                              widthFactors: List.generate(
                                visibleCount,
                                _widthFactor,
                              ),
                              cardHeight: cardH,
                              gap: gap,
                              scale: k,
                              color: widget.connectorColor,
                              sequence: _sequence,
                              flow: _flow,
                              lineProgress: (i) =>
                                  _phase(_t(i) + _lineDelay, _lineGrowMs),
                              flowOpacity: () => _phase(
                                _t(visibleCount - 1) + 300,
                                400,
                              ),
                            ),
                          ),
                        ),
                        // 卡片层
                        Column(
                          children: List.generate(visibleCount, (i) {
                            final left = _isLeftAligned(i);
                            return Padding(
                              padding: EdgeInsets.only(top: i > 0 ? gap : 0),
                              child: Align(
                                alignment: left
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: SizedBox(
                                  width: stageW * _widthFactor(i),
                                  height: cardH,
                                  child: _buildCard(i, k),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        );
      },
    );
  }

  Widget _buildCard(int index, double k) {
    // 入场：透明度 + 下移 + 缩放；胶囊填充与数字随编排同步生长
    return AnimatedBuilder(
      animation: _sequence,
      builder: (context, _) {
        final entry = _phase(_t(index), _cardInMs);
        final fill = _phase(_t(index), _fillMs);
        return Opacity(
          opacity: entry,
          child: Transform.translate(
            offset: Offset(0, 22 * k * (1 - entry)),
            child: Transform.scale(
              scale: 0.95 + 0.05 * entry,
              alignment: _isLeftAligned(index)
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              // cardBuilder 外置卡面；默认渲染内置任务卡
              child: _wrapTap(
                widget.cardBuilder != null
                    ? widget.cardBuilder!(context, index)
                    : _buildCardBody(index, k, fill),
                index,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardBody(int index, double k, double fill) {
    final item = widget.items[index];
    return Container(
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(25 * k),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFAD380A).withValues(alpha: 0.28),
            blurRadius: 24 * k,
            offset: Offset(0, 10 * k),
          ),
        ],
      ),
      padding: EdgeInsets.all(15 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 头像 + 进度胶囊
              Expanded(
                child: Container(
                  height: 38 * k,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD3BE).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // 白色半透明进度填充层（进度关闭时不占槽位）
                      if (item.showProgress)
                        FractionallySizedBox(
                          widthFactor: (fill * item.progress / 100).clamp(
                            0.0,
                            1.0,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.42),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(right: 12 * k),
                        child: Row(
                          children: [
                            _buildAvatar(item, index, k),
                            SizedBox(width: 8 * k),
                            Expanded(
                              child: Text(
                                item.showProgress
                                    ? '${(fill * item.progress).round()}% Done'
                                    : (item.badgeText ?? ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF121212),
                                  fontSize: 11.5 * k,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8 * k),
              // 照片槽：胶囊右侧的圆形缩略图
              if (item.photo != null)
                ClipOval(
                  child: Image(
                    image: item.photo!,
                    width: 38 * k,
                    height: 38 * k,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (item.photo != null) SizedBox(width: 8 * k),
              // 圆形操作按钮
              _wrapTap(
                Container(
                  width: 36 * k,
                  height: 36 * k,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEC2A6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 15 * k,
                    color: const Color(0xFF121212),
                  ),
                ),
                index,
              ),
            ],
          ),
          if (item.title.isNotEmpty) ...[
            SizedBox(height: 16 * k),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF121212),
                fontSize: 19.5 * k,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            SizedBox(height: 3 * k),
          ],
          _buildBottomRow(item, k),
          // 图片堆叠槽：占满剩余卡面，内容自适应缩放
          if (item.photoStack != null)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 8 * k),
                child: Center(child: FittedBox(child: item.photoStack!)),
              ),
            ),
        ],
      ),
    );
  }

  /// 底部行：chips 槽位与内容行（原 "Assign to" 负责人）可共存
  Widget _buildBottomRow(LinkedTaskItemData item, double k) {
    final chips =
        (item.chips == null || item.chips!.isEmpty) ? null : item.chips;
    final showContent = item.assignee.isNotEmpty;

    if (chips == null && !showContent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips != null)
          Wrap(
            spacing: 6 * k,
            runSpacing: 4 * k,
            children: [
              for (final chip in chips)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 9 * k,
                    vertical: 3 * k,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF121212),
                      fontSize: 11 * k,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        if (chips != null && showContent) SizedBox(height: 4 * k),
        if (showContent)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: item.assignLabel ?? 'Assign to: ',
                  style: TextStyle(
                    color: const Color(0xFF8E4728),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: item.assignee,
                  style: TextStyle(
                    color: const Color(0xFF121212),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5 * k, height: 1.3),
          ),
      ],
    );
  }

  Widget _buildAvatar(LinkedTaskItemData item, int index, double k) {
    // 头像槽：自定义 Widget 优先（FittedBox 保证任意尺寸都不溢出）
    if (item.avatar != null) {
      return SizedBox(
        width: 38 * k,
        height: 38 * k,
        child: Center(child: FittedBox(child: item.avatar!)),
      );
    }
    final color = item.avatarColor ??
        _defaultAvatarColors[index % _defaultAvatarColors.length];
    return Container(
      width: 38 * k,
      height: 38 * k,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      alignment: Alignment.center,
      child: item.avatarIcon != null
          ? Icon(item.avatarIcon, size: 18 * k, color: Colors.white)
          : Text(
              item.assignee.isEmpty ? '?' : item.assignee[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 14 * k,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
    );
  }

  /// 点击包装（onItemTap 为 null 时原样返回）
  Widget _wrapTap(Widget child, int index) {
    if (widget.onItemTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onItemTap!.call(index),
      child: child,
    );
  }
}

/// 一条连线的几何信息（stage 坐标）
class _ConnectorGeometry {
  final Path path;
  final Offset start;
  final Offset end;

  const _ConnectorGeometry(this.path, this.start, this.end);
}

/// 计算卡片 i 与 i+1 之间的贝塞尔连线
///
/// 几何规则参考原效果图：
/// - 左对齐卡片：从右侧中点出发，向右上绕出后落入下张卡片顶部偏右（0.72 宽处）
/// - 右对齐卡片：从左侧中点出发，向左上绕出后落入下张卡片顶部偏左（0.16 宽处）
///
/// 连线层绘制在卡片层之下，端点圆点略微外移到卡片边缘外侧以保证可见。
_ConnectorGeometry _connectorGeometry(
  int index,
  List<double> widthFactors,
  double stageW,
  double cardH,
  double gap,
  double k,
) {
  double cardLeft(int i) => _cardLeft(i, widthFactors, stageW);
  double cardTop(int i) => i * (cardH + gap);
  double cardW(int i) => stageW * widthFactors[i];

  Offset start;
  Offset end;
  Offset c1;
  Offset c2;

  if (index.isEven) {
    start = Offset(cardLeft(index) + cardW(index) + 1.5 * k, cardTop(index) + cardH * 0.50);
    end = Offset(cardLeft(index + 1) + cardW(index + 1) * 0.72, cardTop(index + 1) - 1.5 * k);
    c1 = Offset(start.dx + 72 * k, start.dy - 2 * k);
    c2 = Offset(end.dx + 18 * k, end.dy - 58 * k);
  } else {
    start = Offset(cardLeft(index) - 1.5 * k, cardTop(index) + cardH * 0.56);
    end = Offset(cardLeft(index + 1) + cardW(index + 1) * 0.16, cardTop(index + 1) - 1.5 * k);
    c1 = Offset(start.dx - 52 * k, start.dy + 2 * k);
    c2 = Offset(end.dx - 24 * k, end.dy - 38 * k);
  }

  return _ConnectorGeometry(
    Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy),
    start,
    end,
  );
}

double _cardLeft(int i, List<double> widthFactors, double stageW) =>
    i.isEven ? 0 : stageW - stageW * widthFactors[i];

/// 连线层绘制器：底线路径生长 + 流光 + 端点圆点
class _ConnectorsPainter extends CustomPainter {
  final int itemCount;
  final List<double> widthFactors;
  final double cardHeight;
  final double gap;
  final double scale;
  final Color color;
  final Animation<double> sequence;
  final Animation<double> flow;
  final double Function(int index) lineProgress;
  final double Function() flowOpacity;

  _ConnectorsPainter({
    required this.itemCount,
    required this.widthFactors,
    required this.cardHeight,
    required this.gap,
    required this.scale,
    required this.color,
    required this.sequence,
    required this.flow,
    required this.lineProgress,
    required this.flowOpacity,
  }) : super(repaint: Listenable.merge([sequence, flow]));

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3 * scale
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2);

    final flowOpacity = this.flowOpacity();
    final flowPaint = Paint()
      ..color = color.withValues(alpha: 0.95 * flowOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * scale
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);

    final dotPaint = Paint()..color = color;

    for (var i = 0; i < itemCount - 1; i++) {
      final geometry = _connectorGeometry(
        i,
        widthFactors,
        size.width,
        cardHeight,
        gap,
        scale,
      );
      final progress = lineProgress(i);
      if (progress <= 0) continue;

      final metric = geometry.path.computeMetrics().first;
      final length = metric.length;
      final visible = metric.extractPath(0, length * progress);
      canvas.drawPath(visible, basePaint);

      // 流光：一段短亮线沿路径循环移动
      if (flowOpacity > 0 && progress >= 1) {
        final dash = 10.0 * scale;
        final t = flow.value * (length + dash);
        final start = t.clamp(0.0, length);
        final end = (t + dash).clamp(0.0, length);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), flowPaint);
        }
      }

      // 端点圆点：起点随生长出现，终点在收尾 12% 内弹出
      final dotR = 3.2 * scale;
      canvas.drawCircle(geometry.start, dotR, dotPaint);
      final endAppear = ((progress - 0.88) / 0.12).clamp(0.0, 1.0);
      if (endAppear > 0) {
        canvas.drawCircle(geometry.end, dotR * endAppear, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorsPainter oldDelegate) => true;
}

/// 卡片背景绘制器：竖直渐变 + 斜向细纹理（纹理位于渐变之上、卡片之下）
class _BackgroundPainter extends CustomPainter {
  final List<Color> gradientColors;
  final Color stripeColor;
  final double stripeSpacing;
  final double stripeWidth;
  final bool showStripes;

  _BackgroundPainter({
    required this.gradientColors,
    required this.stripeColor,
    required this.stripeSpacing,
    required this.stripeWidth,
    required this.showStripes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ).createShader(rect),
    );

    if (!showStripes || stripeSpacing <= 0) return;

    // 原效果图约 -65° 的斜向等距细线：旋转画布后画竖线
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-65 * math.pi / 180);
    final extent = size.width + size.height;
    final paint = Paint()
      ..color = stripeColor
      ..strokeWidth = stripeWidth
      ..strokeCap = StrokeCap.butt;
    for (var x = -extent; x <= extent; x += stripeSpacing) {
      canvas.drawLine(Offset(x, -extent), Offset(x, extent), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) =>
      oldDelegate.gradientColors != gradientColors ||
      oldDelegate.stripeColor != stripeColor ||
      oldDelegate.stripeSpacing != stripeSpacing ||
      oldDelegate.showStripes != showStripes;
}
