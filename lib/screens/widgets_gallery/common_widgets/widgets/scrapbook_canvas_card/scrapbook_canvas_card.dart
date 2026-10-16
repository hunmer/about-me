import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

import 'scrapbook_item_content.dart';
import 'scrapbook_item_models.dart';
import 'scrapbook_painters.dart';

// 聚合入口：旧调用方仍从本文件拿到数据模型
export 'scrapbook_item_models.dart';

/// 手帐无限画布卡片
///
/// 可平移缩放的网格画布 + 可拖拽/旋转/删除的手帐拼贴元素 + 自由涂鸦。
class ScrapbookCanvasCardWidget extends StatefulWidget {
  /// 画布条目列表
  final List<ScrapItemData> items;

  /// 是否为内联模式（内联模式填满父容器，否则固定宽高）
  final bool inline;

  /// 只读模式：隐藏导航 pill 与 FAB，禁止拖拽/选中/添加条目
  final bool readOnly;

  /// 条目双击回调（只读模式下浏览照片等场景使用）
  final void Function(ScrapItemData item)? onItemDoubleTap;

  /// 条目 Hero tag：返回非 null 的条目挂 Hero，
  /// 与目标页同 tag 图片形成转场飞行（如打开图库大图）
  final String? Function(ScrapItemData item)? heroTagOf;

  /// 组件尺寸
  final HomeWidgetSize size;

  const ScrapbookCanvasCardWidget({
    super.key,
    this.items = const [],
    this.inline = false,
    this.readOnly = false,
    this.onItemDoubleTap,
    this.heroTagOf,
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
  final List<ScrapStroke> _strokes = [];
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
    _items = widget.items.map((e) => e).toList(); // 拷贝，交互中可增删
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
    final canvasPoint = (event.localPosition - Offset(_panX, _panY)) / _zoom;
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
    final text = _noteController.text.trim().isEmpty
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
    setState(() => _strokes.add(ScrapStroke(_penColor, [pt])));
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
    final paperColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFFAF8F2);
    final gridColor = isDark
        ? const Color(0xFF2C3A4F)
        : const Color(0xFFEFECE4);

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
                child: _doodleMode
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
            // 顶部导航 pill（只读模式下隐藏）
            if (!widget.readOnly)
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
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: Center(child: _buildDoodleBanner()),
              ),
            // FAB（只读模式下隐藏，无入口则创建抽屉也不会弹出）
            if (!widget.readOnly)
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
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 26,
                      ),
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
                  child: _toastMessage == null
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
            painter: ScrapGridPainter(
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
          transform: Matrix4.identity()
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
                      painter: ScrapDoodleDecorPainter(
                        railColor: isDark
                            ? const Color(0xFFE8E4DB)
                            : const Color(0xFF181818),
                        railFillColor: isDark
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
                      child: CustomPaint(
                        painter: ScrapStrokesPainter(_strokes),
                      ),
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
    final sorted = [..._items]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return sorted;
  }

  Widget _buildItem(ScrapItemData item, bool isDark) {
    final selected = item.id == _selectedId;
    final index = _items.indexOf(item);
    final start = (index * 0.05).clamp(0.0, 0.55);
    final anim = CurvedAnimation(
      parent: _entryController,
      curve: Interval(
        start,
        (start + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
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
          child: _heroWrap(
            item,
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              // 只读模式下条目不可交互（禁选中即禁旋转/删除入口），双击回调独立可用
              onTap: _doodleMode || widget.readOnly
                  ? null
                  : () => _selectItem(item),
              onDoubleTap: widget.onItemDoubleTap == null
                  ? null
                  : () => widget.onItemDoubleTap!(item),
              onPanStart: _doodleMode || widget.readOnly
                  ? null
                  : (_) {
                      _selectItem(item);
                    },
              onPanUpdate: _doodleMode || widget.readOnly
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
                    painter: selected
                        ? ScrapDashedRectPainter(
                            color: const Color(0x8C001AFF),
                            inset: -6,
                          )
                        : null,
                    child: buildScrapItemContent(item, isDark, _showToast),
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
      ),
    );
  }

  /// heroTagOf 返回非 null 时给条目挂 Hero（tag 需与目标页一致才能飞行）
  Widget _heroWrap(ScrapItemData item, Widget child) {
    final tag = widget.heroTagOf?.call(item);
    return tag == null ? child : Hero(tag: tag, child: child);
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
          color: isDark ? const Color(0xD92A3648) : const Color(0xD9FBF9F4),
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
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
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
    final borderColor = isDark
        ? const Color(0xFF3B4A61)
        : const Color(0xFFE5E0D5);
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
                child: Transform.scale(scale: 0.75, child: buildScrapTape()),
                label: 'Tape',
                textColor: textColor,
                onTap: () => _addSticker(ScrapStickerType.tape),
              ),
              _buildDrawerButton(
                cardColor,
                borderColor,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
            padding: const EdgeInsets.only(
              left: 12,
              right: 4,
              top: 4,
              bottom: 4,
            ),
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
                          color: _noteColor == c ? c : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: _noteColor == c
                            ? [
                                BoxShadow(
                                  color: c.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _addCustomNote,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
