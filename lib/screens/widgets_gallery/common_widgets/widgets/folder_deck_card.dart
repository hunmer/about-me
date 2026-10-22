/// 文件夹卡片堆叠（deck）小组件（手绘纸墨风）
///
/// 由 interactive_folder_portfolio_ui.html 转换：一叠 3D 文件夹卡片
/// （左上 tab 凸起 + 右上斜切肩线的文件夹剪影，rough 墨线描边 + 数据色实底），
/// 扇形堆叠 + 轻点/拖动循环切换 + 封面绕左脊 3D 翻开窥视（peek）+
/// 顶部大标题纵向联动滚动 + 底部呼吸状态 pill + 自动轮播（交互即停）。
/// 无 sheen 高光 / 投影 / 滤镜，层次靠墨线与数据色深浅（depth 越深叠淡墨越多）。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 文件夹卡片数据
class FolderDeckItemData {
  /// tab 标签（大写展示）
  final String label;

  /// 联动大标题
  final String headline;

  /// 文件夹数据色
  final Color color;

  /// 底部状态 pill 文字（缺省回落 'Currently at $label'）
  final String? statusText;

  /// 封面中央大图标（原 HTML 的 SVG 插画的通用化替代）
  final IconData? icon;

  const FolderDeckItemData({
    required this.label,
    required this.headline,
    required this.color,
    this.statusText,
    this.icon,
  });
}

/// 文件夹卡片堆叠小组件
class FolderDeckCardWidget extends StatefulWidget {
  /// 文件夹卡片列表（循环队列）
  final List<FolderDeckItemData> items;

  /// 是否自动轮播（用户交互即停）
  final bool autoPlay;

  /// 自动轮播间隔
  final Duration autoPlayInterval;

  /// 组件尺寸
  final HomeWidgetSize size;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  const FolderDeckCardWidget({
    super.key,
    this.items = _defaultItems,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 3),
    this.size = const Large3Size(),
    this.inline = false,
  });

  static const List<FolderDeckItemData> _defaultItems = [
    FolderDeckItemData(
      label: 'RESUME',
      headline: 'Hey there, I am a product designer polishing ideas',
      color: Color(0xFFD4D6DC),
      statusText: 'Open to new opportunities',
      icon: Icons.description_outlined,
    ),
    FolderDeckItemData(
      label: 'STAX.AI',
      headline: 'From fragmented workflows to a seamless OS',
      color: Color(0xFF20C5E8),
      statusText: 'Currently at STAX.AI',
      icon: Icons.layers_outlined,
    ),
    FolderDeckItemData(
      label: 'TRUFFLE',
      headline: 'Crafting sweet brand moments with playful design',
      color: Color(0xFFEFA9D9),
      icon: Icons.cake_outlined,
    ),
    FolderDeckItemData(
      label: 'PULSE',
      headline: 'Tracking habits and health with gentle reminders',
      color: Color(0xFFA9BC69),
      icon: Icons.favorite_border,
    ),
    FolderDeckItemData(
      label: 'ATLAS',
      headline: 'Mapping journeys and memories across the globe',
      color: Color(0xFF9FB6E8),
      icon: Icons.public,
    ),
    FolderDeckItemData(
      label: 'NOTES',
      headline: 'Collecting daily notes, sketches and ideas',
      color: Color(0xFFF2CE5F),
      icon: Icons.edit_note,
    ),
  ];

  /// 从 props 创建实例
  factory FolderDeckCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    List<FolderDeckItemData> parseItems(dynamic itemsData) {
      if (itemsData is! List) return _defaultItems;
      final items = itemsData.map((item) {
        if (item is! Map) return null;
        final label = item['label'] as String? ?? '';
        if (label.isEmpty) return null;
        final iconValue = item['icon'];
        return FolderDeckItemData(
          label: label,
          headline: item['headline'] as String? ?? label,
          color: _parseColor(item['color'], const Color(0xFFD4D6DC)),
          statusText: item['statusText'] as String?,
          icon: iconValue is int ? dynamicIconData(iconValue) : null,
        );
      }).whereType<FolderDeckItemData>().toList();
      return items.isEmpty ? _defaultItems : items;
    }

    return FolderDeckCardWidget(
      items: parseItems(props['items']),
      autoPlay: props['autoPlay'] as bool? ?? true,
      autoPlayInterval: Duration(
        milliseconds: (props['autoPlayIntervalMs'] as num?)?.toInt() ?? 3000,
      ),
      size: size,
      inline: props['inline'] as bool? ?? false,
    );
  }

  @override
  State<FolderDeckCardWidget> createState() => _FolderDeckCardWidgetState();
}

class _FolderDeckCardWidgetState extends State<FolderDeckCardWidget>
    with TickerProviderStateMixin {
  /// 切换动画（飞出/归位 + 深度前移 + 标题联动）
  late final AnimationController _flip;

  /// 封面窥视动画（0 = 合拢，1 = 绕左脊翻开）
  late final AnimationController _peek;

  /// 状态点呼吸光环
  late final AnimationController _pulse;

  late final Animation<double> _flipCurve;

  int _activeIndex = 0;

  /// 切换中各卡的起点/终点姿态（null = 非切换中，按深度静态布局）
  Map<int, _DeckPose>? _transFrom;
  Map<int, _DeckPose>? _transTo;

  /// 正在飞行（飞出/飞回）且需要置顶绘制的卡
  int? _flyingIndex;

  /// 标题轨道起点下标（切换动画开始时记录）
  int _headlineFrom = 0;

  Timer? _autoTimer;
  Timer? _entryTimer;
  bool _userInteracted = false;
  double _dragDx = 0;

  /// 扇形堆叠参数（depth 0..5：x/y/rot°/scale/opacity，相对 244x312 基准）
  static const _stack = [
    (0.0, 0.0, 0.0, 1.0, 1.0),
    (18.0, 6.0, 5.5, 0.975, 1.0),
    (31.0, 14.0, 11.0, 0.95, 1.0),
    (42.0, 24.0, 16.5, 0.925, 1.0),
    (51.0, 35.0, 21.5, 0.90, 1.0),
    (58.0, 46.0, 26.0, 0.875, 0.95),
  ];

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      duration: const Duration(milliseconds: 560),
      vsync: this,
    );
    _flipCurve = CurvedAnimation(parent: _flip, curve: Curves.easeOutCubic);
    _flip.addStatusListener((status) {
      if (status == AnimationStatus.completed && _transFrom != null) {
        setState(() {
          _transFrom = null;
          _transTo = null;
          _flyingIndex = null;
        });
      }
    });
    _peek = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat();

    // 入场编排：450ms 后封面窥视一次，之后按间隔自动轮播（交互即停）
    _entryTimer = Timer(const Duration(milliseconds: 450), () {
      if (!_userInteracted && mounted) _peekForward();
    });
    if (widget.autoPlay) {
      _autoTimer = Timer.periodic(widget.autoPlayInterval, (_) {
        if (!_userInteracted) _goNext(user: false);
      });
    }
  }

  @override
  void didUpdateWidget(FolderDeckCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items &&
        _activeIndex >= widget.items.length) {
      _activeIndex = 0;
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _entryTimer?.cancel();
    _flip.dispose();
    _peek.dispose();
    _pulse.dispose();
    super.dispose();
  }

  int get _count => widget.items.length;

  void _stopAutoPlay() {
    _userInteracted = true;
    _autoTimer?.cancel();
    _autoTimer = null;
  }

  void _peekForward() {
    if (_count == 0) return;
    _peek.forward();
  }

  void _goNext({bool user = true}) {
    if (_count < 2 || _flip.isAnimating) return;
    if (user) _stopAutoPlay();
    final to = (_activeIndex + 1) % _count;
    _beginTransition(to, forward: true);
  }

  void _goPrev() {
    if (_count < 2 || _flip.isAnimating) return;
    _stopAutoPlay();
    final to = (_activeIndex - 1 + _count) % _count;
    _beginTransition(to, forward: false);
  }

  /// 记录所有卡的起止姿态后启动切换动画：
  /// next = 当前卡向左下飞出、其余前移；prev = 目标卡从左下飞回顶部
  void _beginTransition(int to, {required bool forward}) {
    final u = _unit;
    final from = _activeIndex;
    final fromMap = <int, _DeckPose>{};
    final toMap = <int, _DeckPose>{};
    for (var idx = 0; idx < _count; idx++) {
      final oldDepth = (idx - from + _count) % _count;
      final newDepth = (idx - to + _count) % _count;
      if (forward && idx == from) {
        fromMap[idx] = _depthPose(0, u);
        toMap[idx] = _flyoutPose(u);
      } else if (!forward && idx == to) {
        fromMap[idx] = _flyoutPose(u);
        toMap[idx] = _depthPose(0, u);
      } else {
        fromMap[idx] = _depthPose(oldDepth, u);
        toMap[idx] = _depthPose(newDepth, u);
      }
    }
    setState(() {
      _transFrom = fromMap;
      _transTo = toMap;
      _flyingIndex = forward ? from : to;
      _headlineFrom = from;
      _activeIndex = to;
    });
    _flip.forward(from: 0);
  }

  /// 文件夹宽度 → 扇形参数单位（原参数基于 244px 宽）
  double get _unit => _folderWidth / 244;

  double get _folderWidth {
    final scale = widget.size.scale;
    if (widget.size is SmallSize) return 84 * scale;
    if (widget.size is MediumSize || widget.size is WideSize) {
      return 112 * scale;
    }
    if (widget.size is LargeSize || widget.size is Wide2Size) {
      return 148 * scale;
    }
    if (widget.size is Wide3Size) return 190 * scale;
    return 200 * scale;
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
    return 460 * scale;
  }

  _DeckPose _depthPose(int depth, double u) {
    if (depth < _stack.length) {
      final s = _stack[depth];
      return _DeckPose(
        x: s.$1 * u,
        y: s.$2 * u,
        rot: s.$3 * math.pi / 180,
        rotY: 0,
        scale: s.$4,
        opacity: s.$5,
        depth: depth.toDouble(),
      );
    }
    final l = _stack.last;
    return _DeckPose(
      x: (l.$1 + 6) * u,
      y: (l.$2 + 8) * u,
      rot: (l.$3 + 4) * math.pi / 180,
      rotY: 0,
      scale: 0.84,
      opacity: 0,
      depth: depth.toDouble(),
    );
  }

  _DeckPose _flyoutPose(double u) {
    return _DeckPose(
      x: -245 * u,
      y: 68 * u,
      rot: -14 * math.pi / 180,
      rotY: -18 * math.pi / 180,
      scale: 1,
      opacity: 0,
      depth: -0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 内容本身就是一叠文件夹（主角即 deck），外层不再套面板
    return SizedBox(
      width: widget.inline ? double.maxFinite : 384 * scale,
      height: widget.inline ? double.maxFinite : _defaultHeight(),
      child: Padding(
        padding: widget.size.getPadding(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_flip, _peek]),
          builder: (context, _) => _buildContent(theme),
        ),
      ),
    );
  }

  Widget _buildContent(AppThemeData theme) {
    final scale = widget.size.scale;
    if (_count == 0) return const SizedBox.shrink();

    // 小尺寸：只显示当前文件夹（+ 身后 1 层），无标题/pill
    if (widget.size is SmallSize) {
      return Center(child: _buildDeck(theme, maxDepth: 1, center: true));
    }

    // 宽条：标题 + pill 在左，deck 在右
    if (widget.size.width > widget.size.height) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildHeadline(theme),
                  ),
                ),
                SizedBox(height: 8 * scale),
                _buildStatusPill(theme),
              ],
            ),
          ),
          SizedBox(width: 12 * scale),
          _buildDeck(theme, maxDepth: 5),
        ],
      );
    }

    // 其余：标题在上、deck 在中、pill 在下
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeadline(theme),
        SizedBox(height: 8 * scale),
        Expanded(child: _buildDeck(theme, maxDepth: 5)),
        SizedBox(height: 8 * scale),
        _buildStatusPill(theme),
      ],
    );
  }

  /// 顶部联动标题：单行高 viewport + translateY 轨道，随切换动画滚动
  Widget _buildHeadline(AppThemeData theme) {
    final fontSize = widget.size.getTitleFontSize();
    final vpH = fontSize * 1.25 * 2;
    final t = _flipCurve.value;
    final pos = _transFrom == null
        ? _activeIndex.toDouble()
        : _headlineFrom + (_activeIndex - _headlineFrom) * t;

    return SizedBox(
      height: vpH,
      child: ClipRect(
        child: OverflowBox(
          minHeight: 0,
          maxHeight: double.infinity,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(0, -pos * vpH),
            child: Column(
              children: [
                for (final item in widget.items)
                  SizedBox(
                    height: vpH,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 文件夹堆叠区：扇形布局 + 手势（轻点/拖动切换，按下窥视）
  Widget _buildDeck(
    AppThemeData theme, {
    required int maxDepth,
    bool center = false,
  }) {
    final scale = widget.size.scale;
    final fw = _folderWidth;
    final fh = fw * 312 / 244;
    final u = _unit;
    final t = _flipCurve.value;
    final n = _count;

    final entries = <MapEntry<int, _DeckPose>>[];
    for (var idx = 0; idx < n; idx++) {
      final depth = (idx - _activeIndex + n) % n;
      final _DeckPose pose;
      if (_transFrom != null && _transFrom!.containsKey(idx)) {
        pose = _DeckPose.lerp(_transFrom![idx]!, _transTo![idx]!, t);
      } else {
        if (depth > maxDepth) continue;
        pose = _depthPose(depth, u);
      }
      if (pose.opacity > 0.008 || idx == _flyingIndex) {
        entries.add(MapEntry(idx, pose));
      }
    }
    // 绘制顺序：深卡先画，飞行卡最后（置顶）
    entries.sort((a, b) {
      final aFly = a.key == _flyingIndex;
      final bFly = b.key == _flyingIndex;
      if (aFly != bFly) return aFly ? 1 : -1;
      return b.value.depth.compareTo(a.value.depth);
    });

    final deck = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _stopAutoPlay();
        _peekForward();
      },
      onTapUp: (_) => _peek.reverse(),
      onTapCancel: () => _peek.reverse(),
      onTap: _goNext,
      onHorizontalDragStart: (_) {
        _stopAutoPlay();
        _dragDx = 0;
      },
      onHorizontalDragUpdate: (details) {
        _dragDx += details.delta.dx;
        if (_dragDx.abs() > 42) {
          if (_dragDx < 0) {
            _goNext();
          } else {
            _goPrev();
          }
          _dragDx = 0;
        }
      },
      child: SizedBox(
        width: fw + 66 * u + 8 * scale,
        height: fh + 52 * u + 8 * scale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final e in entries)
              _buildDeckCard(theme, e.key, e.value, fw, fh, u),
          ],
        ),
      ),
    );
    return center ? Center(child: deck) : deck;
  }

  /// 单张文件夹：背页（深色）+ 内页（纸底，peek 时露出）+ 前封面（绕左脊 3D 翻开）
  Widget _buildDeckCard(
    AppThemeData theme,
    int idx,
    _DeckPose pose,
    double fw,
    double fh,
    double u,
  ) {
    final item = widget.items[idx];
    final isFront = idx == _activeIndex && idx != _flyingIndex;
    final peek = isFront ? Curves.easeOut.transform(_peek.value) : 0.0;
    // depth 越深叠淡墨越多，代替投影表达层次
    final shade = (pose.depth * 0.09).clamp(0.0, 0.35);
    final fill = Color.alphaBlend(theme.ink.withValues(alpha: shade), item.color);
    final backFill = Color.alphaBlend(
      theme.ink.withValues(alpha: shade + 0.22),
      item.color,
    );
    final labelColor = fill.computeLuminance() > 0.45
        ? theme.ink
        : theme.paper;

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..translate(pose.x, pose.y)
      ..rotateZ(pose.rot)
      ..rotateY(pose.rotY)
      ..scale(pose.scale);

    return Positioned(
      left: 0,
      top: 0,
      child: Opacity(
        opacity: pose.opacity.clamp(0.0, 1.0),
        child: Transform(
          alignment: const Alignment(-0.5, 0.76),
          transform: matrix,
          child: SizedBox(
            width: fw,
            height: fh,
            child: Stack(
              children: [
                // 背页
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FolderPainter(color: backFill, theme: theme),
                  ),
                ),
                // 内页（纸底 + 淡墨描边，peek 时露出）
                Positioned(
                  top: 16 * u,
                  left: 14 * u,
                  right: 12 * u,
                  bottom: 12 * u,
                  child: Opacity(
                    opacity: peek,
                    child: Transform.translate(
                      offset: Offset(6 * u * peek, 0),
                      child: Transform.rotate(
                        angle: 0.026 + 0.018 * peek,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.paper,
                            border: Border.all(
                              color: theme.ink.withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(14 * u),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 前封面（绕左脊 rotateY 翻开）
                Positioned.fill(
                  child: Transform(
                    alignment: Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..rotateY(-0.5934 * peek)
                      ..rotateZ(-0.021 * peek),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _FolderPainter(color: fill, theme: theme),
                          ),
                        ),
                        // tab 标签
                        Positioned(
                          left: 20 * u,
                          top: 22 * u,
                          child: Text(
                            item.label.toUpperCase(),
                            style: TextStyle(
                              color: labelColor,
                              fontSize: 12 * u,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        // 封面中央大图标
                        if (item.icon != null)
                          Center(
                            child: Icon(
                              item.icon,
                              size: fw * 0.34,
                              color: labelColor.withValues(alpha: 0.92),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 底部状态 pill：小控件档墨线胶囊 + 数据色呼吸点 + 状态文字
  Widget _buildStatusPill(AppThemeData theme) {
    final scale = widget.size.scale;
    final item = widget.items[_activeIndex];
    final dot = 10 * scale;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surfaceAlt,
          radius: BorderRadius.circular(999),
          strokeWidth: 1.4,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: 6 * scale,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: dot,
              height: dot,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final v = _pulse.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // 呼吸光环：数据色 alpha 圆缩放（非阴影）
                      Transform.scale(
                        scale: 1 + 0.9 * v,
                        child: Container(
                          width: dot,
                          height: dot,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.color.withValues(
                              alpha: 0.32 * (1 - v),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: dot * 0.55,
                        height: dot * 0.55,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item.color,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(width: 8 * scale),
            Flexible(
              child: Text(
                item.statusText ?? 'Currently at ${item.label}',
                style: TextStyle(
                  color: theme.textSub,
                  fontSize: widget.size.getLegendFontSize(),
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单卡姿态（扇形堆叠 / 飞出 / 飞回插值用）
class _DeckPose {
  final double x;
  final double y;
  final double rot;
  final double rotY;
  final double scale;
  final double opacity;
  final double depth;

  const _DeckPose({
    required this.x,
    required this.y,
    required this.rot,
    required this.rotY,
    required this.scale,
    required this.opacity,
    required this.depth,
  });

  static _DeckPose lerp(_DeckPose a, _DeckPose b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return _DeckPose(
      x: l(a.x, b.x),
      y: l(a.y, b.y),
      rot: l(a.rot, b.rot),
      rotY: l(a.rotY, b.rotY),
      scale: l(a.scale, b.scale),
      opacity: l(a.opacity, b.opacity),
      depth: l(a.depth, b.depth),
    );
  }
}

/// 文件夹剪影绘制器：沿 folder path 的 rough 墨线描边 + 数据色实底
///
/// 剪影按原 HTML clip-path（244x312 基准：左上 tab 凸起 + 右上斜切肩线 +
/// 圆角）等比构建，采样为点列后经 skribble Generator.polygon + SolidFiller
/// 生成（手绘抖动墨线），无任何高光/投影。
class _FolderPainter extends CustomPainter {
  _FolderPainter({required this.color, required this.theme});

  final Color color;
  final AppThemeData theme;

  Size? _size;
  RoughDrawing? _drawing;

  /// 原 clip-path 等比缩放构建（半径取两轴缩放均值近似）
  static Path folderPath(Size size) {
    final sx = size.width / 244;
    final sy = size.height / 312;
    final avg = (sx + sy) / 2;
    return Path()
      ..moveTo(0, 18 * sy)
      ..arcToPoint(
        Offset(18 * sx, 0),
        radius: Radius.circular(18 * avg),
        clockwise: true,
      )
      ..lineTo(136 * sx, 0)
      ..cubicTo(149 * sx, 0, 153 * sx, 10 * sy, 166 * sx, 10 * sy)
      ..lineTo(228 * sx, 10 * sy)
      ..arcToPoint(
        Offset(244 * sx, 26 * sy),
        radius: Radius.circular(16 * avg),
        clockwise: true,
      )
      ..lineTo(244 * sx, 292 * sy)
      ..arcToPoint(
        Offset(224 * sx, 312 * sy),
        radius: Radius.circular(20 * avg),
        clockwise: true,
      )
      ..lineTo(20 * sx, 312 * sy)
      ..arcToPoint(
        Offset(0, 292 * sy),
        radius: Radius.circular(20 * avg),
        clockwise: true,
      )
      ..close();
  }

  void _prepare(Size size) {
    _size = size;
    final path = folderPath(size);
    final points = <PointD>[];
    for (final metric in path.computeMetrics()) {
      final n = (metric.length / 5).ceil().clamp(6, 160);
      for (var k = 0; k < n; k++) {
        final tangent = metric.getTangentForOffset(metric.length * k / n);
        if (tangent != null) {
          points.add(PointD(tangent.position.dx, tangent.position.dy));
        }
      }
    }
    final config = theme.wired.drawConfig;
    config.randomizer.reset();
    final generator = Generator(config, SolidFiller());
    final border =
        Paint()
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 1.8
          ..color = theme.ink;
    final fill =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color;
    _drawing = RoughDrawing(generator.polygon(points), border, fill);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_drawing == null || _size != size) _prepare(size);
    _drawing!.paint(canvas, progress: 1, pressure: 0);
  }

  @override
  bool shouldRepaint(covariant _FolderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.theme != theme;
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
