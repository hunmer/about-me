import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 随机漫步卡片堆叠数据
///
/// [quote] 为已抽离图片语法后的正文；[imagePaths] 中第 1 张落在卡片
/// 左下角拍立得位、第 2 张落在右上角书签位（仅前两张参与展示）。
class WalkStackCardData {
  const WalkStackCardData({
    required this.id,
    required this.quote,
    this.signature = '',
    this.stars = 5,
    this.imagePaths = const [],
  });

  final String id;
  final String quote;
  final String signature;
  final int stars;
  final List<String> imagePaths;
}

/// 每层卡片的静止几何（px，基于 282×348 基准卡，实际渲染乘 size.scale）
class _StackSlot {
  const _StackSlot(this.dx, this.dy, this.rot, this.scale, this.opacity);
  final double dx;
  final double dy;
  final double rot; // 度
  final double scale;
  final double opacity;
}

const List<_StackSlot> _kSlots = [
  _StackSlot(0, 0, 3.2, 1.0, 1.0),
  _StackSlot(11, 8, 9.4, 0.985, 0.72),
  _StackSlot(20, 15, 15.8, 0.968, 0.44),
  _StackSlot(24, 18, 18.0, 0.94, 0.0),
];

/// 基准卡尺寸（与原参考稿 282×348 一致）
const double _kCardWidth = 282;
const double _kCardHeight = 348;

/// 磨砂参数：高斯模糊半径与磨砂纸底不透明度
const double _kFrostSigma = 6;
const double _kFrostAlpha = 0.72;

/// 可滑动卡片堆叠（书摘感言卡）：顶层卡片可拖拽，超过阈值飞出切卡，
/// 后方叠层弹性补位；开启 [randomMode] 后每次切卡从剩余卡片随机抽取
/// 下一张（随机漫步）。
///
/// 视觉为手绘纸墨风：卡片纸底 + 淡排线 + 墨线框，星级与签名手写字体，
/// 边角图片以拍立得相框贴纸呈现。
class WalkStackCardWidget extends StatefulWidget {
  const WalkStackCardWidget({
    super.key,
    required this.cards,
    this.size = const Large3Size(),
    this.inline = false,
    this.randomMode = false,
    this.starColor = const Color(0xFFF2CE5F),
    this.frosted = true,
    this.onCardDismissed,
  });

  /// 卡片队列（至少 1 张；少于 4 张时只渲染现有层数）
  final List<WalkStackCardData> cards;

  /// 组件尺寸
  final HomeWidgetSize size;

  /// 内联模式（居中展示，不占固定宽）
  final bool inline;

  /// 随机漫步：飞出后下一张从剩余卡片随机抽取（否则顺序循环）
  final bool randomMode;

  /// 星星颜色（数据色，可覆盖）
  final Color starColor;

  /// 卡片背景磨砂模糊（BackdropFilter + 半透明纸底）
  final bool frosted;

  /// 顶层卡片飞出后的回调
  final ValueChanged<WalkStackCardData>? onCardDismissed;

  /// 从 props 创建实例（注册器统一入口）
  factory WalkStackCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final cardsRaw = props['cards'] as List? ?? const [];
    final cards = <WalkStackCardData>[];
    for (final e in cardsRaw) {
      if (e is WalkStackCardData) {
        cards.add(e);
        continue;
      }
      if (e is! Map) continue;
      cards.add(
        WalkStackCardData(
          id: e['id']?.toString() ?? '',
          quote: e['quote']?.toString() ?? '',
          signature: e['signature']?.toString() ?? '',
          stars: (e['stars'] as num?)?.toInt() ?? 5,
          imagePaths: ((e['images'] as List?) ?? const [])
              .map((p) => p.toString())
              .toList(),
        ),
      );
    }
    return WalkStackCardWidget(
      cards: cards,
      randomMode: props['randomMode'] as bool? ?? false,
      frosted: props['frosted'] as bool? ?? true,
      size: size,
      inline: props['inline'] as bool? ?? false,
    );
  }

  @override
  State<WalkStackCardWidget> createState() => _WalkStackCardWidgetState();
}

enum _WalkPhase { idle, dragging, flying, settling }

class _WalkStackCardWidgetState extends State<WalkStackCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  final math.Random _random = math.Random();

  /// 渲染队列（_queue[0] 为顶层激活卡）
  late List<WalkStackCardData> _queue;

  _WalkPhase _phase = _WalkPhase.idle;

  // 拖拽 / 动画起始量（px，已含 scale）
  double _dragX = 0;
  double _dragY = 0;
  double _flyFromX = 0;
  double _flyFromY = 0;
  double _settleFromX = 0;
  double _fromProgress = 0;
  int _flyDir = -1;

  @override
  void initState() {
    super.initState();
    _queue = widget.cards.toList();
    _ctrl.addStatusListener(_onAnimStatus);
  }

  @override
  void didUpdateWidget(WalkStackCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部换卡堆（如重新洗牌）：以列表实例判断，同一实例的内部队列变化不重建
    if (!identical(oldWidget.cards, widget.cards)) {
      _queue = widget.cards.toList();
      _phase = _WalkPhase.idle;
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_phase == _WalkPhase.flying) {
      final dismissed = _queue.isNotEmpty ? _queue.first : null;
      _advanceQueue();
      setState(() {
        _phase = _WalkPhase.idle;
        _dragX = 0;
        _dragY = 0;
      });
      _ctrl.value = 0;
      if (dismissed != null) widget.onCardDismissed?.call(dismissed);
    } else if (_phase == _WalkPhase.settling) {
      setState(() => _phase = _WalkPhase.idle);
      _ctrl.value = 0;
    }
  }

  /// 推进队列：顶层飞出后移到队尾，层 1 顶替为顶层
  ///
  /// 随机漫步的取卡在拖拽开始时已决定（见 [_pickNextIntoSecond]），
  /// 层 1 渐显的内容与飞出后的顶层是同一张。
  void _advanceQueue() {
    if (_queue.length < 2) return;
    _queue.add(_queue.removeAt(0));
  }

  /// 随机漫步：从第 3 张起随机抽一张换到层 1（下一张顶层），
  /// 让拖拽全程渐显的预览内容与切卡结果一致
  void _pickNextIntoSecond() {
    if (!widget.randomMode || _queue.length <= 2) return;
    final pick = 2 + _random.nextInt(_queue.length - 2);
    _queue.insert(1, _queue.removeAt(pick));
  }

  double get _scale => widget.size.scale;

  /// 后层向上一层槽位靠拢的进度（0~1）
  double get _dragProgress =>
      (_dragX.abs() / (155 * _scale)).clamp(0.0, 1.0);

  void _onPanStart(DragStartDetails details) {
    if (_phase != _WalkPhase.idle) return;
    // 随机漫步：拖拽开始即决定下一张，层 1 渐显内容与飞出后顶层一致
    _pickNextIntoSecond();
    setState(() => _phase = _WalkPhase.dragging);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_phase != _WalkPhase.dragging) return;
    setState(() {
      _dragX += details.delta.dx;
      _dragY += details.delta.dy;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_phase != _WalkPhase.dragging) return;
    final vx = details.velocity.pixelsPerSecond.dx;
    final s = _scale;
    final shouldFly =
        _queue.length > 1 &&
        (_dragX.abs() > 82 * s || (vx.abs() > 450 && _dragX.abs() > 28 * s));
    if (shouldFly) {
      _flyDir = (vx != 0 ? vx : _dragX) < 0 ? -1 : 1;
      _flyFromX = _dragX;
      _flyFromY = _dragY * 0.32;
      _fromProgress = _dragProgress;
      setState(() => _phase = _WalkPhase.flying);
      _ctrl.forward(from: 0);
    } else {
      _settleFromX = _dragX;
      _fromProgress = _dragProgress;
      setState(() {
        _phase = _WalkPhase.settling;
        _dragX = 0;
        _dragY = 0;
      });
      _ctrl.forward(from: 0);
    }
  }

  void _onPanCancel() {
    if (_phase != _WalkPhase.dragging) return;
    _settleFromX = _dragX;
    _fromProgress = _dragProgress;
    setState(() {
      _phase = _WalkPhase.settling;
      _dragX = 0;
      _dragY = 0;
    });
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = AppTheme.of(context);
          final s = _scale;
          // 卡片 + 挂件出血（左下照片 / 右上书签各出框约 40px）
          final stageW = _kCardWidth * s + 72 * s;
          final stageH = _kCardHeight * s + 96 * s;

          Widget stage = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: _onPanCancel,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => _buildStack(theme),
            ),
          );

          // 挂载即播一次墨线描画入场
          stage = WiredDraw(child: stage);

          Widget box = SizedBox(
            width: stageW,
            height: stageH,
            child: Center(child: stage),
          );
          if (widget.inline) box = Center(child: box);
          return box;
        },
      ),
    );
  }

  Widget _buildStack(AppThemeData theme) {
    final layerCount = _queue.length.clamp(0, _kSlots.length);
    if (layerCount == 0) return const SizedBox.shrink();

    // 顶层姿态与后层补位进度
    double topX = 0, topY = 0, topRot = 3.2, topOpacity = 1, p = 0;
    switch (_phase) {
      case _WalkPhase.idle:
        break;
      case _WalkPhase.dragging:
        topX = _dragX;
        topY = _dragY * 0.32;
        topRot = 3.2 + _dragX * 0.068;
        p = _dragProgress;
      case _WalkPhase.flying:
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        topX = _lerp(_flyFromX, _flyDir * 460 * _scale, t);
        topY = _lerp(_flyFromY, 24 * _scale, t);
        topRot = _lerp(3.2 + _flyFromX * 0.068, 3.2 + _flyDir * 26.0, t);
        topOpacity = (1 - t * 1.15).clamp(0.0, 1.0);
        p = _lerp(_fromProgress, 1.0, t);
      case _WalkPhase.settling:
        final t = Curves.easeOutBack.transform(_ctrl.value);
        topX = _lerp(_settleFromX, 0, t);
        topRot = 3.2 + topX * 0.068;
        p = _lerp(_fromProgress, 0.0, t);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 后层先画（层 3 → 1），顶层最后画
        for (var pos = layerCount - 1; pos >= 1; pos--)
          _buildLayer(theme, pos: pos, progress: p),
        Opacity(
          opacity: topOpacity,
          child: Transform.translate(
            offset: Offset(topX, topY),
            child: Transform.rotate(
              angle: topRot * math.pi / 180,
              child: _buildCardFace(theme, _queue.first, contentOpacity: 1,
                  parallaxX: topX),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLayer(
    AppThemeData theme, {
    required int pos,
    required double progress,
  }) {
    // 回弹曲线（easeOutBack）过冲会让进度越出 [0,1]，
    // slot 透明度 0 起始的层会插值出负 opacity 触发断言
    final p = progress.clamp(0.0, 1.0);
    final s = _scale;
    final slot = _kSlots[pos];
    final prev = _kSlots[pos - 1];
    final x = _lerp(slot.dx, prev.dx, p) * s;
    final y = _lerp(slot.dy, prev.dy, p) * s;
    final rot = _lerp(slot.rot, prev.rot, p);
    final scale = _lerp(slot.scale, prev.scale, p);
    final opacity = _lerp(slot.opacity, prev.opacity, p);
    // 第 2 层在补位进度后段渐显内容与挂件
    final contentOpacity =
        pos == 1 ? ((p - 0.35) / 0.65).clamp(0.0, 1.0) : 0.0;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(x, y),
        child: Transform.rotate(
          angle: rot * math.pi / 180,
          child: Transform.scale(
            scale: scale,
            child: _buildCardFace(
              theme,
              _queue[pos],
              contentOpacity: contentOpacity,
              parallaxX: 0,
            ),
          ),
        ),
      ),
    );
  }

  /// 单张卡片：纸面（引言 + 星级 + 签名）+ 边角图片挂件
  Widget _buildCardFace(
    AppThemeData theme,
    WalkStackCardData data, {
    required double contentOpacity,
    required double parallaxX,
  }) {
    final s = _scale;
    final cardW = _kCardWidth * s;
    final cardH = _kCardHeight * s;
    final seed = data.id.hashCode & 0x7fffffff;

    // 纸面始终可见（透明度由外层卡片层控制），contentOpacity 只作用于
    // 文字内容与挂件——后层呈干净的半透明空纸卡
    Widget face = Container(
      width: cardW,
      height: cardH,
      padding: EdgeInsets.fromLTRB(28 * s, 26 * s, 24 * s, 20 * s),
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(22 * s),
        strokeWidth: 1.6,
        fillStyle: DsSketchFill.hachure,
        seed: seed,
      ),
      child: Opacity(
        opacity: contentOpacity,
        child: _buildCardContent(theme, data),
      ),
    );

    // 磨砂背景：模糊其后内容（页面底色 / 后层叠卡）+ 半透明纸底
    if (widget.frosted) {
      face = ClipRRect(
        borderRadius: BorderRadius.circular(22 * s),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _kFrostSigma * s,
            sigmaY: _kFrostSigma * s,
          ),
          child: ColoredBox(
            color: theme.surface.withValues(alpha: _kFrostAlpha),
            child: face,
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        face,
        // 右上角书签位（第 2 张图）
        if (data.imagePaths.length > 1)
          Positioned(
            top: -30 * s,
            right: 8 * s,
            child: Opacity(
              opacity: contentOpacity,
              child: _buildPendant(
                theme,
                data.imagePaths[1],
                width: 74,
                height: 104,
                rotation: -0.136,
                parallax: Offset(parallaxX * 0.085, -parallaxX.abs() * 0.03),
                seed: seed + 1,
              ),
            ),
          ),
        // 左下角拍立得位（第 1 张图）
        if (data.imagePaths.isNotEmpty)
          Positioned(
            bottom: -24 * s,
            left: -16 * s,
            child: Opacity(
              opacity: contentOpacity,
              child: _buildPendant(
                theme,
                data.imagePaths.first,
                width: 92,
                height: 112,
                rotation: -0.328,
                parallax: Offset(-parallaxX * 0.065, parallaxX.abs() * 0.025),
                seed: seed + 2,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCardContent(AppThemeData theme, WalkStackCardData data) {
    final s = _scale;
    final sketch = DsTypography.sketchFamily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '❝',
          style: TextStyle(
            fontFamily: sketch,
            fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
            fontSize: 26 * s,
            height: 1,
            color: theme.textSub,
          ),
        ),
        SizedBox(height: 10 * s),
        Expanded(
          child: Text(
            data.quote,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: sketch,
              fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
              fontSize: 18.5 * s,
              height: 1.38,
              color: theme.text,
            ),
          ),
        ),
        SizedBox(height: 10 * s),
        Row(
          children: [
            for (var i = 0; i < data.stars && i < 5; i++)
              Padding(
                padding: EdgeInsets.only(right: 7 * s),
                child: DsIcon(
                  DsIconKind.star,
                  size: 15 * s,
                  color: widget.starColor,
                  fill: true,
                ),
              ),
          ],
        ),
        SizedBox(height: 4 * s),
        Align(
          alignment: Alignment.centerRight,
          child: Transform.rotate(
            angle: -0.026,
            child: Text(
              data.signature,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: sketch,
                fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
                fontSize: 20 * s,
                height: 1,
                color: theme.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 边角图片挂件：纸底相框 + 墨线描边 + 轻微倾斜，随拖拽视差移动
  Widget _buildPendant(
    AppThemeData theme,
    String path, {
    required double width,
    required double height,
    required double rotation,
    required Offset parallax,
    required int seed,
  }) {
    final s = _scale;
    return Transform.translate(
      offset: parallax * s,
      child: Transform.rotate(
        angle: rotation,
        child: DsSketchPanel(
          theme: theme,
          width: width * s,
          height: height * s,
          radius: BorderRadius.circular(7 * s),
          hachure: false,
          fillColor: theme.surface,
          padding: EdgeInsets.all(3.5 * s),
          seed: seed,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5 * s),
            // key 绑定路径：层内容随队列推进换数据时强制重建，避免复用旧 future
            child: _PendantImage(key: ValueKey(path), path: path),
          ),
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// 挂件图片：网络地址直接加载，本地相对路径经 ImageUtils 解析为绝对路径
class _PendantImage extends StatefulWidget {
  const _PendantImage({super.key, required this.path});

  final String path;

  @override
  State<_PendantImage> createState() => _PendantImageState();
}

class _PendantImageState extends State<_PendantImage> {
  late final Future<String> _future = _resolve();

  Future<String> _resolve() async {
    final p = widget.path;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    try {
      return await ImageUtils.getAbsolutePath(p);
    } catch (_) {
      return p;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null || resolved.isEmpty) {
          return const ColoredBox(color: Color(0x11000000));
        }
        final Widget image = resolved.startsWith('http')
            ? Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0x11000000)),
              )
            : Image.file(
                File(resolved),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0x11000000)),
              );
        return SizedBox.expand(child: image);
      },
    );
  }
}
