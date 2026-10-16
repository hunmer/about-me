import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 手帐画布条目类型
enum ScrapItemKind { header, photo, text, companions, sticker, gift }

/// 贴纸子类型
enum ScrapStickerType { tape, cloud, price, sparkles }

/// 同行人数据
class ScrapCompanionData {
  final String name;
  final String emoji;
  final Color color;

  const ScrapCompanionData({
    required this.name,
    required this.emoji,
    required this.color,
  });

  factory ScrapCompanionData.fromMap(Map<String, dynamic> map) {
    return ScrapCompanionData(
      name: map['name'] as String? ?? '',
      emoji: map['emoji'] as String? ?? '🙂',
      color: _parseColor(map['color'], const Color(0xFFFFE4D6)),
    );
  }
}

/// 胶带贴纸装饰数据（相对条目左上角偏移）
class ScrapTapeData {
  final double dx;
  final double dy;
  final double angle;

  const ScrapTapeData({required this.dx, required this.dy, this.angle = 0});

  factory ScrapTapeData.fromMap(Map<String, dynamic> map) {
    return ScrapTapeData(
      dx: (map['dx'] as num?)?.toDouble() ?? 0,
      dy: (map['dy'] as num?)?.toDouble() ?? 0,
      angle: (map['angle'] as num?)?.toDouble() ?? 0,
    );
  }
}

Color _parseColor(dynamic value, Color fallback) {
  if (value == null) return fallback;
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
    } catch (_) {
      // 解析失败走兜底
    }
  }
  return fallback;
}

ScrapItemKind _parseKind(dynamic value) {
  switch (value) {
    case 'header':
      return ScrapItemKind.header;
    case 'photo':
      return ScrapItemKind.photo;
    case 'companions':
      return ScrapItemKind.companions;
    case 'sticker':
      return ScrapItemKind.sticker;
    case 'gift':
      return ScrapItemKind.gift;
    case 'text':
    default:
      return ScrapItemKind.text;
  }
}

ScrapStickerType _parseStickerType(dynamic value) {
  switch (value) {
    case 'cloud':
      return ScrapStickerType.cloud;
    case 'price':
      return ScrapStickerType.price;
    case 'sparkles':
      return ScrapStickerType.sparkles;
    case 'tape':
    default:
      return ScrapStickerType.tape;
  }
}

/// 手帐画布条目数据模型（x/y/rotation/zIndex 可在交互中被修改）
class ScrapItemData {
  final String id;
  final ScrapItemKind kind;
  double x;
  double y;
  double rotation;
  int zIndex;

  // header
  final String? dateLabel;
  final String? title;
  final String? subtitle;

  // photo
  final String? imageUrl;
  final double width;
  final double height;
  final Color fallbackColor;
  final List<String> captions;
  final Color? captionColor;

  /// 手绘图风格：airplaneWindow / fuji / shinkansen / plushie，null 则加载网络图
  final String? artStyle;
  final ScrapTapeData? tape;
  final String? bubbleText;
  final bool narutomakiBorder;
  final bool sparklesDecor;

  // companions
  final List<ScrapCompanionData> companions;

  // sticker
  final ScrapStickerType stickerType;
  final String? stickerText;
  final Color? stickerColor;

  ScrapItemData({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.rotation = 0,
    this.zIndex = 20,
    this.dateLabel,
    this.title,
    this.subtitle,
    this.imageUrl,
    this.width = 96,
    this.height = 132,
    this.fallbackColor = const Color(0xFFE5E0D5),
    this.captions = const [],
    this.captionColor,
    this.artStyle,
    this.tape,
    this.bubbleText,
    this.narutomakiBorder = false,
    this.sparklesDecor = false,
    this.companions = const [],
    this.stickerType = ScrapStickerType.tape,
    this.stickerText,
    this.stickerColor,
  });

  factory ScrapItemData.fromMap(Map<String, dynamic> map) {
    return ScrapItemData(
      id: map['id'] as String? ?? 'item_${map.hashCode}',
      kind: _parseKind(map['kind']),
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0,
      zIndex: (map['zIndex'] as num?)?.toInt() ?? 20,
      dateLabel: map['dateLabel'] as String?,
      title: map['title'] as String?,
      subtitle: map['subtitle'] as String?,
      imageUrl: map['imageUrl'] as String?,
      width: (map['width'] as num?)?.toDouble() ?? 96,
      height: (map['height'] as num?)?.toDouble() ?? 132,
      fallbackColor: _parseColor(
        map['fallbackColor'],
        const Color(0xFFE5E0D5),
      ),
      captions:
          (map['captions'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      captionColor:
          map['captionColor'] != null
              ? _parseColor(map['captionColor'], const Color(0xFFD9388A))
              : null,
      artStyle: map['artStyle'] as String?,
      tape:
          map['tape'] is Map<String, dynamic>
              ? ScrapTapeData.fromMap(map['tape'] as Map<String, dynamic>)
              : null,
      bubbleText: map['bubbleText'] as String?,
      narutomakiBorder: map['narutomakiBorder'] as bool? ?? false,
      sparklesDecor: map['sparklesDecor'] as bool? ?? false,
      companions:
          (map['companions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ScrapCompanionData.fromMap)
              .toList(growable: false) ??
          const [],
      stickerType: _parseStickerType(map['stickerType']),
      stickerText: map['stickerText'] as String?,
      stickerColor:
          map['stickerColor'] != null
              ? _parseColor(map['stickerColor'], const Color(0xFFD9388A))
              : null,
    );
  }
}

/// 用户涂鸦笔画
class _Stroke {
  final Color color;
  final List<Offset> points;

  _Stroke(this.color, this.points);
}

/// 手帐无限画布卡片
///
/// 可平移缩放的网格画布 + 可拖拽/旋转/删除的手帐拼贴元素 + 自由涂鸦。
class ScrapbookCanvasCardWidget extends StatefulWidget {
  /// 画布条目列表
  final List<ScrapItemData> items;

  /// 是否为内联模式（内联模式填满父容器，否则固定宽高）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const ScrapbookCanvasCardWidget({
    super.key,
    this.items = const [],
    this.inline = false,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例
  factory ScrapbookCanvasCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return ScrapbookCanvasCardWidget(
      items:
          (props['items'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ScrapItemData.fromMap)
              .toList() ??
          const [],
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<ScrapbookCanvasCardWidget> createState() =>
      _ScrapbookCanvasCardWidgetState();
}

class _ScrapbookCanvasCardWidgetState extends State<ScrapbookCanvasCardWidget>
    with SingleTickerProviderStateMixin {
  static const double _minZoom = 0.55;
  static const double _maxZoom = 2.2;
  static const double _gridSize = 30;

  late final AnimationController _entryController;
  late final List<ScrapItemData> _items;

  double _panX = 0;
  double _panY = 0;
  double _zoom = 1;

  // scale 手势起始快照
  Offset _startFocal = Offset.zero;
  Offset _startPan = Offset.zero;
  double _startZoom = 1;

  String? _selectedId;
  int _highestZ = 35;
  bool _menuOpen = false;
  bool _doodleMode = false;
  Color _penColor = const Color(0xFF56A8E8);
  Color _noteColor = const Color(0xFFD9388A);
  final List<_Stroke> _strokes = [];
  final TextEditingController _noteController = TextEditingController();

  String? _toastMessage;
  Timer? _toastTimer;
  int _spawnCounter = 0;
  int _snapIndex = 0;

  static const _tokyoSnaps = [
    (
      'https://images.unsplash.com/photo-1554797589-7241bb691973?auto=format&fit=crop&w=400&q=80',
      'harajuku backstreets 🛹',
      Color(0xFFD9388A),
    ),
    (
      'https://images.unsplash.com/photo-1528164344705-475426879c0d?auto=format&fit=crop&w=400&q=80',
      'tokyo sky view 🌇',
      Color(0xFFD4842A),
    ),
    (
      'https://images.unsplash.com/photo-1580442151529-343f2f6e0e27?auto=format&fit=crop&w=400&q=80',
      'konbini egg sando 🥪',
      Color(0xFF3B9E4C),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _items =
        widget.items.map((e) => e).toList(); // 拷贝，交互中可增删
    for (final item in _items) {
      if (item.zIndex > _highestZ) _highestZ = item.zIndex;
    }
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _noteController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  // ===== Toast =====

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  // ===== 画布手势 =====

  void _onScaleStart(ScaleStartDetails details) {
    _startFocal = details.localFocalPoint;
    _startPan = Offset(_panX, _panY);
    _startZoom = _zoom;
    if (_menuOpen) setState(() => _menuOpen = false);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      final nextZoom = (_startZoom * details.scale).clamp(_minZoom, _maxZoom);
      // 起始焦点对应的画布坐标保持不变（单指平移时 scale=1 同样成立）
      final canvasPoint = (_startFocal - _startPan) / _startZoom;
      _zoom = nextZoom;
      _panX = details.localFocalPoint.dx - canvasPoint.dx * nextZoom;
      _panY = details.localFocalPoint.dy - canvasPoint.dy * nextZoom;
    });
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final factor = event.scrollDelta.dy < 0 ? 1.08 : 0.92;
    final nextZoom = (_zoom * factor).clamp(_minZoom, _maxZoom);
    final canvasPoint =
        (event.localPosition - Offset(_panX, _panY)) / _zoom;
    setState(() {
      _zoom = nextZoom;
      _panX = event.localPosition.dx - canvasPoint.dx * nextZoom;
      _panY = event.localPosition.dy - canvasPoint.dy * nextZoom;
    });
  }

  Offset _screenToCanvas(Offset local) =>
      (local - Offset(_panX, _panY)) / _zoom;

  // ===== 条目交互 =====

  void _selectItem(ScrapItemData item) {
    setState(() {
      _selectedId = item.id;
      item.zIndex = ++_highestZ;
    });
  }

  void _rotateItem(ScrapItemData item) {
    setState(() {
      item.rotation = ((item.rotation + 8 + 180) % 360) - 180;
    });
  }

  void _deleteItem(ScrapItemData item) {
    setState(() {
      _items.removeWhere((e) => e.id == item.id);
      if (_selectedId == item.id) _selectedId = null;
    });
    _showToast('🗑️ Removed sticker');
  }

  // ===== 创建抽屉 =====

  Offset _canvasCenter() {
    final jitterX = (math.Random().nextDouble() - 0.5) * 50;
    final jitterY = (math.Random().nextDouble() - 0.5) * 50;
    return Offset(
      (165 - _panX) / _zoom + jitterX,
      (360 - _panY) / _zoom + jitterY,
    );
  }

  void _spawnItem(ScrapItemData item) {
    setState(() {
      _items.add(item);
      _menuOpen = false;
      _selectedId = item.id;
      item.zIndex = ++_highestZ;
    });
  }

  String _nextId() => 'spawn_${++_spawnCounter}';

  void _addSticker(ScrapStickerType type) {
    final center = _canvasCenter();
    switch (type) {
      case ScrapStickerType.tape:
        _spawnItem(
          ScrapItemData(
            id: _nextId(),
            kind: ScrapItemKind.sticker,
            stickerType: ScrapStickerType.tape,
            x: center.dx,
            y: center.dy,
            rotation: 28,
          ),
        );
        _showToast('🩹 Added masking tape sticker');
      case ScrapStickerType.cloud:
        _spawnItem(
          ScrapItemData(
            id: _nextId(),
            kind: ScrapItemKind.sticker,
            stickerType: ScrapStickerType.cloud,
            stickerText: 'omg!!',
            x: center.dx,
            y: center.dy,
            rotation: -6,
          ),
        );
        _showToast('☁️ Added thought bubble');
      case ScrapStickerType.price:
        const amounts = ['-\$18', '-\$45', '-\$120', '-¥3,800'];
        final pick = amounts[math.Random().nextInt(amounts.length)];
        _spawnItem(
          ScrapItemData(
            id: _nextId(),
            kind: ScrapItemKind.sticker,
            stickerType: ScrapStickerType.price,
            stickerText: pick,
            x: center.dx,
            y: center.dy,
            rotation: -4,
          ),
        );
        _showToast('💸 Added price tag');
      case ScrapStickerType.sparkles:
        _spawnItem(
          ScrapItemData(
            id: _nextId(),
            kind: ScrapItemKind.sticker,
            stickerType: ScrapStickerType.sparkles,
            x: center.dx,
            y: center.dy,
            rotation: 5,
          ),
        );
        _showToast('✨ Added hand-drawn sparkles');
    }
  }

  void _addTokyoSnap() {
    final snap = _tokyoSnaps[_snapIndex % _tokyoSnaps.length];
    _snapIndex += 1;
    final center = _canvasCenter();
    final rot = math.Random().nextDouble() * 10 - 5;
    _spawnItem(
      ScrapItemData(
        id: _nextId(),
        kind: ScrapItemKind.photo,
        imageUrl: snap.$1,
        x: center.dx,
        y: center.dy,
        rotation: rot,
        captions: [snap.$2],
        captionColor: snap.$3,
        tape: const ScrapTapeData(dx: 64, dy: -8, angle: 34),
      ),
    );
    _showToast('📸 Added new Tokyo photo!');
  }

  void _addCustomNote() {
    final text =
        _noteController.text.trim().isEmpty
            ? 'tokyo memories ✨'
            : _noteController.text.trim();
    final center = _canvasCenter();
    _spawnItem(
      ScrapItemData(
        id: _nextId(),
        kind: ScrapItemKind.text,
        captions: [text],
        captionColor: _noteColor,
        x: center.dx,
        y: center.dy,
      ),
    );
    _noteController.clear();
    _showToast('🏷️ Added caption to canvas');
  }

  // ===== 涂鸦模式 =====

  void _setDoodleMode(bool active) {
    setState(() {
      _doodleMode = active;
      if (active) {
        _menuOpen = false;
        _selectedId = null;
      }
    });
    if (active) _showToast('✏️ Draw directly on the grid canvas!');
  }

  void _onDoodleStart(DragStartDetails details) {
    final pt = _screenToCanvas(details.localPosition);
    setState(() => _strokes.add(_Stroke(_penColor, [pt])));
  }

  void _onDoodleUpdate(DragUpdateDetails details) {
    final pt = _screenToCanvas(details.localPosition);
    setState(() => _strokes.last.points.add(pt));
  }

  // ===== 构建 =====

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = widget.size.scale;
    final paperColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFFAF8F2);
    final gridColor = isDark ? const Color(0xFF2C3A4F) : const Color(0xFFEFECE4);

    return Container(
      width: widget.inline ? double.maxFinite : 384 * scale,
      height: widget.inline ? double.maxFinite : 560 * scale,
      decoration: BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.circular(12 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20 * scale,
            offset: Offset(0, 4 * scale),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12 * scale),
        child: Stack(
          children: [
            // 画布交互区（网格 + 变换平面）
            Positioned.fill(
              child: Listener(
                onPointerSignal: _onPointerSignal,
                child:
                    _doodleMode
                        ? GestureDetector(
                          onPanStart: _onDoodleStart,
                          onPanUpdate: _onDoodleUpdate,
                          child: _buildCanvasLayers(gridColor, isDark),
                        )
                        : GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedId = null;
                              _menuOpen = false;
                            });
                          },
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          child: _buildCanvasLayers(gridColor, isDark),
                        ),
              ),
            ),
            // 顶部导航 pill
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavPill('Back', isDark, () {
                    setState(() {
                      _panX = 0;
                      _panY = 0;
                      _zoom = 1;
                    });
                    _showToast('🇯🇵 Viewing Tokyo Trip • Day 1 of 5');
                  }),
                  _buildNavPill('Save', isDark, () {
                    setState(() => _selectedId = null);
                    _showToast('✨ Saved "Tokyo DAY 1" to Memories!');
                  }),
                ],
              ),
            ),
            // 涂鸦模式横幅
            if (_doodleMode)
              Positioned(top: 48, left: 0, right: 0, child: Center(child: _buildDoodleBanner())),
            // FAB
            Positioned(
              right: 16,
              bottom: 18,
              child: GestureDetector(
                onTap: () {
                  if (_doodleMode) {
                    _setDoodleMode(false);
                    return;
                  }
                  setState(() => _menuOpen = !_menuOpen);
                },
                child: AnimatedRotation(
                  turns: _menuOpen ? 0.125 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFF001AFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x59001AFF),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
            // 创建抽屉
            if (_menuOpen)
              Positioned(
                left: 16,
                right: 16,
                bottom: 82,
                child: _buildCreatorDrawer(isDark),
              ),
            // Toast
            Positioned(
              top: _doodleMode ? 88 : 48,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _toastMessage != null ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child:
                      _toastMessage == null
                          ? const SizedBox.shrink()
                          : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xE6111111),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              _toastMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasLayers(Color gridColor, bool isDark) {
    return Stack(
      children: [
        // 网格背景（视口坐标，随 pan/zoom 同步）
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(
              panX: _panX,
              panY: _panY,
              zoom: _zoom,
              gridSize: _gridSize,
              color: gridColor,
            ),
          ),
        ),
        // 变换平面：涂鸦装饰 + 用户笔画 + 条目
        Transform(
          alignment: Alignment.topLeft,
          transform:
              Matrix4.identity()
                ..translate(_panX, _panY)
                ..scale(_zoom),
          child: SizedBox(
            width: 390,
            height: 900,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 静态手绘装饰层（蓝色飞机弯箭头 + 黑色铁路轨道）
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _DoodleDecorPainter(
                        railColor:
                            isDark
                                ? const Color(0xFFE8E4DB)
                                : const Color(0xFF181818),
                        railFillColor:
                            isDark
                                ? const Color(0xE61E293B)
                                : const Color(0xEAFFFFFF),
                      ),
                    ),
                  ),
                ),
                // 用户涂鸦笔画
                if (_strokes.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _StrokesPainter(_strokes)),
                    ),
                  ),
                // 手帐条目（z 序升序，大的在上）
                ..._sortedItems().map((item) => _buildItem(item, isDark)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<ScrapItemData> _sortedItems() {
    final sorted = [..._items]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return sorted;
  }

  Widget _buildItem(ScrapItemData item, bool isDark) {
    final selected = item.id == _selectedId;
    final index = _items.indexOf(item);
    final start = (index * 0.05).clamp(0.0, 0.55);
    final anim = CurvedAnimation(
      parent: _entryController,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: Curves.easeOutBack),
    );

    return Positioned(
      left: item.x,
      top: item.y,
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, child) {
          final t = anim.value.clamp(0.0, 1.0);
          return Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
          );
        },
        child: Transform.rotate(
          angle: item.rotation * math.pi / 180,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _doodleMode ? null : () => _selectItem(item),
            onPanStart:
                _doodleMode
                    ? null
                    : (_) {
                      _selectItem(item);
                    },
            onPanUpdate:
                _doodleMode
                    ? null
                    : (details) {
                      setState(() {
                        item.x += details.delta.dx / _zoom;
                        item.y += details.delta.dy / _zoom;
                      });
                    },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  painter:
                      selected
                          ? _DashedRectPainter(
                            color: const Color(0x8C001AFF),
                            inset: -6,
                          )
                          : null,
                  child: _buildItemContent(item, isDark),
                ),
                if (selected)
                  Positioned(
                    top: -30,
                    right: -10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildControlChip('↻', () => _rotateItem(item)),
                        const SizedBox(width: 4),
                        _buildControlChip('×', () => _deleteItem(item)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildNavPill(String label, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:
              isDark
                  ? const Color(0xD92A3648)
                  : const Color(0xD9FBF9F4),
          border: Border.all(
            color: isDark ? const Color(0xFF3B4A61) : const Color(0xFFE5E0D4),
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }

  // ===== 条目内容 =====

  Widget _buildItemContent(ScrapItemData item, bool isDark) {
    switch (item.kind) {
      case ScrapItemKind.header:
        return _buildHeaderItem(item, isDark);
      case ScrapItemKind.photo:
        return _buildPhotoItem(item, isDark);
      case ScrapItemKind.text:
        return _buildTextItem(item, isDark);
      case ScrapItemKind.companions:
        return _buildCompanionsItem(item, isDark);
      case ScrapItemKind.sticker:
        return _buildStickerItem(item);
      case ScrapItemKind.gift:
        return _buildGiftItem(isDark);
    }
  }

  Widget _buildHeaderItem(ScrapItemData item, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          (item.dateLabel ?? '').toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
            color: Color(0xFFB5AFA4),
            height: 1.1,
          ),
        ),
        Text(
          item.title ?? '',
          style: TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
            height: 1.05,
            color: isDark ? Colors.white : const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          item.subtitle ?? '',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: isDark ? Colors.white : const Color(0xFF111111),
          ),
        ),
        SizedBox(
          width: 34,
          height: 10,
          child: CustomPaint(painter: _SquigglePainter()),
        ),
      ],
    );
  }

  Widget _buildPhotoItem(ScrapItemData item, bool isDark) {
    final captionColor =
        item.captionColor ??
        (isDark ? Colors.white70 : const Color(0xFF1A1A1A));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.narutomakiBorder)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: SizedBox(
                      width: item.width,
                      height: 16,
                      child: CustomPaint(painter: _NarutomakiRowPainter()),
                    ),
                  ),
                _buildPhotoFrame(item),
              ],
            ),
            if (item.tape != null)
              Positioned(
                left: item.tape!.dx,
                top: item.tape!.dy,
                child: Transform.rotate(
                  angle: item.tape!.angle * math.pi / 180,
                  child: _buildTape(),
                ),
              ),
            if (item.bubbleText != null)
              Positioned(
                top: -20,
                right: -15,
                child: _buildCloudBubble(item.bubbleText!),
              ),
            if (item.sparklesDecor)
              const Positioned(
                top: -14,
                left: 4,
                child: SizedBox(
                  width: 32,
                  height: 30,
                  child: CustomPaint(painter: _SparklesPainter()),
                ),
              ),
          ],
        ),
        if (item.captions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in item.captions)
                  Text(
                    line,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.25,
                      color: captionColor,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoFrame(ScrapItemData item) {
    const shadow = [
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
      BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1)),
    ];

    switch (item.artStyle) {
      case 'airplaneWindow':
        return Container(
          width: item.width,
          height: item.height,
          decoration: const BoxDecoration(
            color: Color(0xFF16151A),
            boxShadow: shadow,
          ),
          child: Center(
            child: Container(
              width: item.width * 0.7,
              height: item.height * 0.68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF2C2933), width: 2.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(painter: _AirplaneWindowPainter()),
            ),
          ),
        );
      case 'fuji':
        return ClipPath(
          clipper: _ArchClipper(),
          child: Container(
            width: item.width,
            height: item.height,
            color: const Color(0xFF87A8C4),
            child: CustomPaint(painter: _FujiPainter()),
          ),
        );
      case 'shinkansen':
        return Container(
          width: item.width,
          height: item.height,
          decoration: const BoxDecoration(
            color: Color(0xFF3E3D38),
            boxShadow: shadow,
          ),
          child: CustomPaint(painter: _ShinkansenPainter()),
        );
      case 'plushie':
        return Container(
          width: item.width,
          height: item.height,
          decoration: const BoxDecoration(
            color: Color(0xFFE8C84B),
            boxShadow: shadow,
          ),
          child: CustomPaint(painter: _PlushiePainter()),
        );
      default:
        return Container(
          width: item.width,
          height: item.height,
          decoration: BoxDecoration(
            color: item.fallbackColor,
            boxShadow: shadow,
          ),
          clipBehavior: Clip.antiAlias,
          child:
              item.imageUrl != null
                  ? Image.network(
                    item.imageUrl!,
                    width: item.width,
                    height: item.height,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                            Container(color: item.fallbackColor),
                  )
                  : null,
        );
    }
  }

  Widget _buildTextItem(ScrapItemData item, bool isDark) {
    final color =
        item.captionColor ??
        (isDark ? Colors.white : const Color(0xFF111111));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in item.captions)
          Text(
            line,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              height: 1.25,
              color: color,
            ),
          ),
      ],
    );
  }

  Widget _buildCompanionsItem(ScrapItemData item, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'with',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFFD9388A),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 红心弧
            SizedBox(
              width: 24,
              height: 66,
              child: Stack(
                children: [
                  Positioned(
                    left: 13,
                    top: -4,
                    child: Transform.rotate(
                      angle: -0.21,
                      child: Text('❤️', style: TextStyle(fontSize: 7)),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    top: 5,
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Text('❤️', style: TextStyle(fontSize: 8.5)),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 17,
                    child: Transform.rotate(
                      angle: 0.17,
                      child: Text('❤️', style: TextStyle(fontSize: 7)),
                    ),
                  ),
                  Positioned(
                    left: 2,
                    top: 27,
                    child: Transform.rotate(
                      angle: -0.14,
                      child: Text('❤️', style: TextStyle(fontSize: 10.5)),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    top: 44,
                    child: Transform.rotate(
                      angle: 0.24,
                      child: Text('❤️', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in item.companions)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: c.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            c.emoji,
                            style: const TextStyle(fontSize: 9, height: 1),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          c.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStickerItem(ScrapItemData item) {
    switch (item.stickerType) {
      case ScrapStickerType.tape:
        return _buildTape();
      case ScrapStickerType.cloud:
        return _buildCloudBubble(item.stickerText ?? 'omg!!');
      case ScrapStickerType.price:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF3D5B5),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            '💸 ${item.stickerText ?? '-\$45'}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Color(0xFF1E1E1E),
            ),
          ),
        );
      case ScrapStickerType.sparkles:
        return const SizedBox(
          width: 38,
          height: 36,
          child: CustomPaint(painter: _SparklesPainter()),
        );
    }
  }

  Widget _buildTape() {
    return Container(
      width: 44,
      height: 16,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xEBF4F1EA), Color(0xE0E8E4DB)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 10,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0x73A09A8E), width: 1),
              right: BorderSide(color: Color(0x73A09A8E), width: 1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloudBubble(String text) {
    return SizedBox(
      width: 54,
      height: 42,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CloudBubblePainter())),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: Color(0xFFD9388A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 礼盒组合（黄色礼盒 + 小票 + 价格 pill + WISHLIST pill）=====

  Widget _buildGiftItem(bool isDark) {
    return SizedBox(
      width: 142,
      height: 178,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 阶梯层叠底卡
          Positioned(
            left: 6,
            top: 14,
            child: Container(width: 116, height: 54, color: const Color(0xFF222421)),
          ),
          Positioned(
            left: 16,
            top: 6,
            child: Container(width: 96, height: 72, color: const Color(0xFF2E302B)),
          ),
          Positioned(
            left: 26,
            top: 0,
            child: Container(width: 76, height: 86, color: const Color(0xFF8E8468)),
          ),
          // 黄色礼盒
          Positioned(
            left: 38,
            top: 10,
            child: Container(
              width: 52,
              height: 76,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF5D033), Color(0xFFE8BE1E), Color(0xFFC99E10)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGiftLogo('東京\n銀座'),
                  const SizedBox(width: 3),
                  _buildGiftLogo('GIN\nZA'),
                ],
              ),
            ),
          ),
          // 小票
          Positioned(
            left: 22,
            top: 60,
            child: Transform.rotate(
              angle: -4 * math.pi / 180,
              child: Container(
                width: 50,
                height: 66,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F3EF),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GINZA SIX',
                          style: TextStyle(
                            fontSize: 5.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '06/02',
                          style: TextStyle(fontSize: 4, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Divider(height: 2, thickness: 0.4),
                    const Text(
                      'TOTAL  \$1,500',
                      style: TextStyle(
                        fontSize: 4.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: Colors.black,
                      ),
                    ),
                    // 条码
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final w in [1.5, 0.8, 2.0, 1.0, 1.5, 2.2, 0.8, 1.5, 1.0, 2.0])
                          Container(width: w, height: 8, color: Colors.black),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 价格 pill
          Positioned(
            left: 76,
            top: 80,
            child: Transform.rotate(
              angle: -2 * math.pi / 180,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3D5B5),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Text(
                  '💸 -\$1,500',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ),
            ),
          ),
          // 颜文字
          Positioned(
            left: 38,
            top: 123,
            child: Text(
              'ദ്ദി ( ᵔ ᗜ ᵔ )',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
          // WISHLIST pill
          Positioned(
            left: 36,
            top: 148,
            child: GestureDetector(
              onTap: () => _showToast('🛍️ Ginza Uniqlo / Luxury Box • \$1,500'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE6E2D8)),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  '🔗 WISHLIST',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftLogo(String text) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFFD9231E),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 4.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }

  // ===== 创建抽屉 & 涂鸦横幅 =====

  Widget _buildDoodleBanner() {
    const penColors = [
      Color(0xFF56A8E8),
      Color(0xFFE84C3D),
      Color(0xFF111111),
      Color(0xFFD9388A),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE6212121),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: _penColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text(
            'Draw on canvas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            width: 1,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white24,
          ),
          for (final c in penColors)
            GestureDetector(
              onTap: () => setState(() => _penColor = c),
              child: Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _penColor == c ? Colors.white : Colors.white38,
                    width: _penColor == c ? 2 : 1,
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: () => _setDoodleMode(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorDrawer(bool isDark) {
    final noteColors = [
      const Color(0xFFD9388A),
      const Color(0xFF3B9E4C),
      const Color(0xFFD4842A),
      const Color(0xFF111111),
    ];
    final cardColor = isDark ? const Color(0xFF2A3648) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3B4A61) : const Color(0xFFE5E0D5);
    final textColor = isDark ? Colors.white : const Color(0xFF333333);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF21E293B) : const Color(0xF2FAF8F2),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ADD TO TOKYO DAY 1',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
              ),
              const Text(
                'Tap to drop on canvas',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD9388A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 贴纸行
          Row(
            children: [
              _buildDrawerButton(
                cardColor,
                borderColor,
                child: Transform.scale(scale: 0.75, child: _buildTape()),
                label: 'Tape',
                textColor: textColor,
                onTap: () => _addSticker(ScrapStickerType.tape),
              ),
              _buildDrawerButton(
                cardColor,
                borderColor,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF0F6),
                    border: Border.all(color: const Color(0xFFF3C6DD)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'omg!!',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD9388A),
                    ),
                  ),
                ),
                label: 'Cloud',
                textColor: textColor,
                onTap: () => _addSticker(ScrapStickerType.cloud),
              ),
              _buildDrawerButton(
                cardColor,
                borderColor,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3D5B5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '💸 -\$45',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                label: 'Price Tag',
                textColor: textColor,
                onTap: () => _addSticker(ScrapStickerType.price),
              ),
              _buildDrawerButton(
                cardColor,
                borderColor,
                child: const Text(
                  '✦✧',
                  style: TextStyle(fontSize: 14, color: Color(0xFFD93829)),
                ),
                label: 'Sparkles',
                textColor: textColor,
                onTap: () => _addSticker(ScrapStickerType.sparkles),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 照片 / 涂鸦行
          Row(
            children: [
              Expanded(
                child: _buildWideDrawerButton(
                  cardColor,
                  borderColor,
                  '📸 Add Tokyo Snap',
                  textColor,
                  _addTokyoSnap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWideDrawerButton(
                  cardColor,
                  borderColor,
                  '✏️ Draw Doodle',
                  const Color(0xFF001AFF),
                  () => _setDoodleMode(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 自定义文字 + 颜色点 + Add
          Container(
            padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Write a cute caption...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onSubmitted: (_) => _addCustomNote(),
                  ),
                ),
                for (final c in noteColors)
                  GestureDetector(
                    onTap: () => setState(() => _noteColor = c),
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              _noteColor == c ? c : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow:
                            _noteColor == c
                                ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 4)]
                                : null,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _addCustomNote,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerButton(
    Color cardColor,
    Color borderColor, {
    required Widget child,
    required String label,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 22, child: Center(child: child)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideDrawerButton(
    Color cardColor,
    Color borderColor,
    String label,
    Color textColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ===== 绘制器 =====

/// 网格背景绘制器（视口坐标系，随 pan/zoom 同步）
class _GridPainter extends CustomPainter {
  final double panX;
  final double panY;
  final double zoom;
  final double gridSize;
  final Color color;

  _GridPainter({
    required this.panX,
    required this.panY,
    required this.zoom,
    required this.gridSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final g = gridSize * zoom;
    if (g < 4) return;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1;
    final startX = panX % g;
    for (double x = startX; x <= size.width; x += g) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final startY = panY % g;
    for (double y = startY; y <= size.height; y += g) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.panX != panX ||
      oldDelegate.panY != panY ||
      oldDelegate.zoom != zoom ||
      oldDelegate.color != color;
}

/// 静态手绘装饰：蓝色飞机弯箭头 + 黑色铁路轨道（画布平面坐标系）
class _DoodleDecorPainter extends CustomPainter {
  final Color railColor;
  final Color railFillColor;

  _DoodleDecorPainter({required this.railColor, required this.railFillColor});

  @override
  void paint(Canvas canvas, Size size) {
    const blue = Color(0xFF56A8E8);
    final bluePaint =
        Paint()
          ..color = blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    // 1. 蓝色手绘弯箭头
    final arrow =
        Path()
          ..moveTo(122, 252)
          ..cubicTo(138, 230, 152, 232, 150, 247)
          ..cubicTo(148, 262, 134, 256, 141, 236)
          ..cubicTo(147, 219, 156, 212, 162, 206);
    canvas.drawPath(arrow, bluePaint);

    // 箭头末端的小飞机（translate(157,191) rotate(-32°)）
    canvas.save();
    canvas.translate(157, 191);
    canvas.rotate(-32 * math.pi / 180);
    final plane =
        Path()
          ..moveTo(2, 7)
          ..lineTo(13, 7)
          ..moveTo(7.5, 1.5)
          ..lineTo(9.5, 7)
          ..lineTo(7.5, 12.5)
          ..moveTo(3.5, 4.5)
          ..lineTo(5.5, 7)
          ..lineTo(3.5, 9.5);
    canvas.drawPath(plane, bluePaint);
    canvas.restore();

    // 2. 蜿蜒铁路轨道
    final fillPath =
        Path()
          ..moveTo(110, 662)
          ..cubicTo(104, 686, 86, 715, 92, 746)
          ..cubicTo(97, 772, 132, 786, 174, 756)
          ..cubicTo(188, 746, 200, 738, 208, 733)
          ..lineTo(208, 712)
          ..cubicTo(194, 720, 178, 734, 162, 742)
          ..cubicTo(138, 754, 120, 742, 124, 716)
          ..cubicTo(128, 692, 132, 676, 127, 662)
          ..close();
    canvas.drawPath(fillPath, Paint()..color = railFillColor);

    final railPaint =
        Paint()
          ..color = railColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.35
          ..strokeCap = StrokeCap.round;
    final outerRail =
        Path()
          ..moveTo(110, 661)
          ..cubicTo(103, 688, 86, 716, 92, 747)
          ..cubicTo(97, 774, 134, 786, 176, 755)
          ..cubicTo(190, 745, 201, 738, 209, 733);
    canvas.drawPath(outerRail, railPaint);
    final innerRail =
        Path()
          ..moveTo(127, 661)
          ..cubicTo(132, 680, 127, 696, 124, 718)
          ..cubicTo(120, 742, 139, 753, 163, 741)
          ..cubicTo(179, 733, 193, 720, 208, 712);
    canvas.drawPath(innerRail, railPaint);

    // 枕木
    final sleeperPaint =
        Paint()
          ..color = railColor
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
    const sleepers = [
      [108.0, 671.0, 128.0, 672.0],
      [104.0, 683.0, 128.0, 686.0],
      [99.0, 696.0, 126.0, 700.0],
      [94.0, 710.0, 124.0, 714.0],
      [91.0, 725.0, 123.0, 726.0],
      [91.0, 740.0, 124.0, 736.0],
      [96.0, 756.0, 128.0, 743.0],
      [107.0, 769.0, 134.0, 747.0],
      [124.0, 775.0, 142.0, 749.0],
      [143.0, 773.0, 152.0, 746.0],
      [161.0, 765.0, 163.0, 741.0],
      [176.0, 755.0, 174.0, 734.0],
      [189.0, 746.0, 186.0, 726.0],
      [201.0, 738.0, 198.0, 718.0],
    ];
    for (final s in sleepers) {
      canvas.drawLine(Offset(s[0], s[1]), Offset(s[2], s[3]), sleeperPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DoodleDecorPainter oldDelegate) =>
      oldDelegate.railColor != railColor ||
      oldDelegate.railFillColor != railFillColor;
}

/// 用户涂鸦笔画绘制器（画布平面坐标系，圆头线帽 2.2px）
class _StrokesPainter extends CustomPainter {
  final List<_Stroke> strokes;

  _StrokesPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint =
          Paint()
            ..color = stroke.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final p in stroke.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) => true;
}

/// 选中虚线框
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double inset;

  _DashedRectPainter({required this.color, this.inset = -6});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    const dash = 4.0;
    const gap = 3.0;

    void drawDashedLine(Offset a, Offset b) {
      final total = (b - a).distance;
      if (total == 0) return;
      final dir = (b - a) / total;
      double d = 0;
      while (d < total) {
        final end = math.min(d + dash, total);
        canvas.drawLine(a + dir * d, a + dir * end, paint);
        d = end + gap;
      }
    }

    drawDashedLine(rect.topLeft, rect.topRight);
    drawDashedLine(rect.topRight, rect.bottomRight);
    drawDashedLine(rect.bottomRight, rect.bottomLeft);
    drawDashedLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 标题红色波浪下划线
class _SquigglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 36;
    final sy = size.height / 10;
    canvas.scale(sx, sy);
    final paint =
        Paint()
          ..color = const Color(0xFFE44C39)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 / ((sx + sy) / 2)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final path =
        Path()
          ..moveTo(3, 3.5)
          ..lineTo(29, 2.2)
          ..lineTo(9, 6.5)
          ..lineTo(31, 6.2)
          ..lineTo(16, 8.8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 飞机窗：黎明天空渐变 + 云海
class _AirplaneWindowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF6B7A99),
        Color(0xFF9A8FA6),
        Color(0xFFD49B94),
        Color(0xFFE59872),
        Color(0xFF3E323B),
        Color(0xFF221C24),
      ],
      stops: const [0.0, 0.35, 0.62, 0.78, 0.9, 1.0],
    );
    canvas.drawRect(
      Offset.zero & Size(w, h),
      Paint()..shader = gradient.createShader(Offset.zero & Size(w, h)),
    );
    // 地平线光带
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.73),
        width: w * 1.3,
        height: h * 0.125,
      ),
      Paint()..color = const Color(0xA6FFAE78),
    );
    // 云海与机翼剪影
    final cloud1 =
        Path()
          ..moveTo(0, h * 0.78)
          ..quadraticBezierTo(w * 0.32, h * 0.72, w * 0.68, h * 0.76)
          ..quadraticBezierTo(w * 0.85, h * 0.78, w, h * 0.74)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
    canvas.drawPath(cloud1, Paint()..color = const Color(0xFF2A2229));
    final cloud2 =
        Path()
          ..moveTo(0, h * 0.83)
          ..quadraticBezierTo(w * 0.44, h * 0.79, w, h * 0.82)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
    canvas.drawPath(cloud2, Paint()..color = const Color(0xFF1A151B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 拱形裁剪（富士山照片）
class _ArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.88, h * 0.28)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(w * 0.12, h * 0.28)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 富士山 + 雪顶 + 秋叶 + 轨道
class _FujiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 44;
    final sy = size.height / 48;
    canvas.scale(sx, sy);

    canvas.drawRect(const Rect.fromLTWH(0, 0, 44, 48), Paint()..color = const Color(0xFFCFE2F3));
    // 山体
    final mountain =
        Path()
          ..moveTo(4, 34)
          ..lineTo(17, 11)
          ..lineTo(27, 11)
          ..lineTo(40, 34)
          ..close();
    canvas.drawPath(mountain, Paint()..color = const Color(0xFF4A6984));
    // 雪顶
    final snow =
        Path()
          ..moveTo(17, 11)
          ..lineTo(27, 11)
          ..lineTo(31, 19)
          ..lineTo(26, 17)
          ..lineTo(22, 20)
          ..lineTo(18, 17)
          ..lineTo(13, 19)
          ..close();
    canvas.drawPath(snow, Paint()..color = Colors.white);
    // 两侧秋叶
    canvas.drawCircle(const Offset(6, 28), 9, Paint()..color = const Color(0xFFC84B31));
    canvas.drawCircle(const Offset(38, 28), 9, Paint()..color = const Color(0xFFD96B27));
    canvas.drawCircle(const Offset(4, 36), 8, Paint()..color = const Color(0xFF5C8244));
    canvas.drawCircle(const Offset(40, 36), 8, Paint()..color = const Color(0xFF4E7338));
    // 前景轨道
    final track =
        Path()
          ..moveTo(18, 32)
          ..lineTo(11, 48)
          ..lineTo(33, 48)
          ..lineTo(26, 32)
          ..close();
    canvas.drawPath(track, Paint()..color = const Color(0xFFD9D2C5));
    final railPaint =
        Paint()
          ..color = const Color(0xFF333333)
          ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(19, 32), const Offset(14, 48), railPaint);
    canvas.drawLine(const Offset(25, 32), const Offset(30, 48), railPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 新干线站台 + 红白列车
class _ShinkansenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 90;
    final sy = size.height / 134;
    canvas.scale(sx, sy);

    // 站台顶棚
    canvas.drawRect(const Rect.fromLTWH(0, 0, 90, 54), Paint()..color = const Color(0xFF4B473E));
    final roofLine =
        Paint()
          ..color = const Color(0xFF38342C)
          ..strokeWidth = 2;
    canvas.drawLine(const Offset(0, 18), const Offset(90, 18), roofLine);
    canvas.drawLine(const Offset(0, 36), const Offset(90, 36), roofLine);
    // 天空与山丘
    canvas.drawRect(const Rect.fromLTWH(0, 54, 90, 38), Paint()..color = const Color(0xFFDCE7EB));
    final hills =
        Path()
          ..moveTo(0, 78)
          ..quadraticBezierTo(25, 62, 55, 72)
          ..quadraticBezierTo(75, 77, 90, 66)
          ..lineTo(90, 92)
          ..lineTo(0, 92)
          ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0xFF4F6F46));
    // 列车车身
    final body =
        Path()
          ..moveTo(18, 96)
          ..cubicTo(22, 76, 48, 68, 90, 66)
          ..lineTo(90, 108)
          ..lineTo(18, 108)
          ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFFF7F7F7));
    // 车窗
    final windshield =
        Path()
          ..moveTo(26, 88)
          ..cubicTo(34, 78, 52, 74, 68, 74)
          ..lineTo(68, 85)
          ..lineTo(26, 88)
          ..close();
    canvas.drawPath(windshield, Paint()..color = const Color(0xFF1E242B));
    // 红色腰线
    final stripe =
        Path()
          ..moveTo(18, 96)
          ..cubicTo(26, 92, 55, 90, 90, 90)
          ..lineTo(90, 102)
          ..lineTo(18, 102)
          ..close();
    canvas.drawPath(stripe, Paint()..color = const Color(0xFFC92424));
    // 底部轨道
    canvas.drawRect(const Rect.fromLTWH(0, 108, 90, 26), Paint()..color = const Color(0xFF18181A));
    canvas.drawLine(
      const Offset(0, 115),
      const Offset(90, 115),
      Paint()
        ..color = const Color(0xFF555555)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 黄色毛绒玩具店
class _PlushiePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 92;
    final sy = size.height / 130;
    canvas.scale(sx, sy);

    canvas.drawRect(const Rect.fromLTWH(0, 0, 92, 130), Paint()..color = const Color(0xFFD8E2DC));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 92, 44), Paint()..color = const Color(0xFF5A8F48));
    canvas.drawCircle(const Offset(14, 24), 12, Paint()..color = const Color(0xFF76AA5E));
    canvas.drawCircle(const Offset(38, 18), 14, Paint()..color = const Color(0xFF467836));
    canvas.drawCircle(const Offset(66, 24), 13, Paint()..color = const Color(0xFF689F52));
    canvas.drawCircle(const Offset(22, 14), 4, Paint()..color = const Color(0xFFFF9EBB));
    canvas.drawCircle(const Offset(52, 22), 4.5, Paint()..color = const Color(0xFFFFD166));
    // 毛绒玩具
    canvas.drawOval(const Rect.fromLTWH(0, 66, 56, 60), Paint()..color = const Color(0xFFF5CC27));
    canvas.drawOval(const Rect.fromLTWH(46, 70, 52, 56), Paint()..color = const Color(0xFFEBBF1E));
    // 表情
    final dark = Paint()..color = const Color(0xFF2B1E16);
    canvas.drawCircle(const Offset(15, 86), 2.8, dark);
    canvas.drawCircle(const Offset(32, 87), 2.8, dark);
    canvas.drawOval(const Rect.fromLTWH(21, 88, 4, 2.4), dark);
    canvas.drawCircle(const Offset(9, 92), 4, Paint()..color = const Color(0xB3E85D56));
    canvas.drawCircle(const Offset(38, 93), 4, Paint()..color = const Color(0xB3E85D56));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 鱼板 swirl 边框（一排鸣人卷）
class _NarutomakiRowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width / 16).floor().clamp(1, 12);
    final swirlPaint =
        Paint()
          ..color = const Color(0xFFE86F88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
    for (int i = 0; i < count; i++) {
      final center = Offset(8.0 + i * 16, size.height / 2);
      canvas.drawCircle(
        center,
        7.5,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        center,
        7.5,
        Paint()
          ..color = const Color(0xFFE5E0D5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      // 粉色旋涡：两段螺旋弧
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 4),
        0,
        math.pi * 1.7,
        false,
        swirlPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 1.8),
        math.pi * 0.8,
        math.pi * 1.7,
        false,
        swirlPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 红色四角星 sparkles
class _SparklesPainter extends CustomPainter {
  const _SparklesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 36;
    final sy = size.height / 34;
    canvas.scale(sx, sy);
    final paint =
        Paint()
          ..color = const Color(0xFFD93829)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeJoin = StrokeJoin.round;
    final big =
        Path()
          ..moveTo(18, 2)
          ..cubicTo(19, 10, 21, 12, 29, 13)
          ..cubicTo(21, 14, 19, 16, 18, 24)
          ..cubicTo(17, 16, 15, 14, 7, 13)
          ..cubicTo(15, 12, 17, 10, 18, 2)
          ..close();
    canvas.drawPath(big, paint);
    final small =
        Path()
          ..moveTo(9, 17)
          ..cubicTo(9.6, 22, 11, 23, 16, 23.5)
          ..cubicTo(11, 24, 9.6, 25, 9, 30)
          ..cubicTo(8.4, 25, 7, 24, 2, 23.5)
          ..cubicTo(7, 23, 8.4, 22, 9, 17)
          ..close();
    canvas.drawPath(small, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 云朵思考气泡
class _CloudBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 64;
    final sy = size.height / 50;
    canvas.scale(sx, sy);
    final fillPaint = Paint()..color = Colors.white;
    final strokePaint =
        Paint()
          ..color = const Color(0xFFD4D0C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    final cloud =
        Path()
          ..moveTo(16, 34)
          ..cubicTo(9, 34, 6, 28, 9, 23)
          ..cubicTo(6, 17, 11, 11, 18, 12)
          ..cubicTo(21, 6, 31, 5, 36, 10)
          ..cubicTo(43, 6, 52, 10, 52, 17)
          ..cubicTo(58, 19, 59, 27, 54, 31)
          ..cubicTo(55, 36, 48, 40, 42, 38)
          ..cubicTo(38, 42, 28, 42, 25, 38)
          ..cubicTo(21, 40, 16, 38, 16, 34)
          ..close();
    canvas.drawPath(cloud, fillPaint);
    canvas.drawPath(cloud, strokePaint);
    // 思考小圆点
    canvas.drawCircle(const Offset(14, 42), 2.6, fillPaint);
    canvas.drawCircle(const Offset(14, 42), 2.6, strokePaint..strokeWidth = 1.2);
    canvas.drawCircle(const Offset(9, 46), 1.6, fillPaint);
    canvas.drawCircle(const Offset(9, 46), 1.6, strokePaint..strokeWidth = 1.1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
