import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';
import 'package:path_provider/path_provider.dart';

import '../cute_notepad_card.dart' show captureCuteNotepadPng;
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

  /// 条目双击回调（只读模式下浏览照片等场景使用）。
  /// 经 onTap 自测双击实现——条目若注册 onDoubleTap 会被画布
  /// 外层单击手势在竞技场中抢先淘汰，导致双击永不触发。
  /// 只读模式下未注册本回调时，双击图片条目内建打开 GalleryViewer
  final void Function(ScrapItemData item)? onItemDoubleTap;

  /// 初始涂鸦笔画（恢复上次编辑内容）
  final List<ScrapStroke> initialStrokes;

  /// 内容变更回调（条目增删/旋转/拖动结束/涂鸦结束），供外部持久化
  final void Function(List<ScrapItemData> items, List<ScrapStroke> strokes)?
  onChanged;

  /// Back pill 回调（注册时接管退出；未注册保持内置视图重置行为）
  final VoidCallback? onClose;

  /// 添加素材回调（工具栏"+"）：由外部弹选择器，返回
  /// 图片/SVG 素材/emoji 三选一，组件负责落为画布条目
  final Future<ScrapPickedAsset?> Function()? onPickAsset;

  /// 组件尺寸
  final HomeWidgetSize size;

  const ScrapbookCanvasCardWidget({
    super.key,
    this.items = const [],
    this.inline = false,
    this.readOnly = false,
    this.onItemDoubleTap,
    this.initialStrokes = const [],
    this.onChanged,
    this.onClose,
    this.onPickAsset,
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
  bool _doodleMode = false;
  Color _penColor = const Color(0xFF56A8E8);
  final List<ScrapStroke> _strokes = [];

  // undo/redo 历史栈（items+strokes 深拷贝快照，上限 50 步）
  final List<_ScrapSnapshot> _undoStack = [];
  final List<_ScrapSnapshot> _redoStack = [];

  String? _toastMessage;
  Timer? _toastTimer;

  final GlobalKey _exportBoundaryKey = GlobalKey();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _items = widget.items.map((e) => e).toList(); // 拷贝，交互中可增删
    for (final item in _items) {
      if (item.zIndex > _highestZ) _highestZ = item.zIndex;
    }
    _strokes.addAll(widget.initialStrokes);
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
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
    _pushHistory();
    setState(() {
      item.rotation = ((item.rotation + 8 + 180) % 360) - 180;
    });
    _notifyChanged();
  }

  void _deleteItem(ScrapItemData item) {
    _pushHistory();
    setState(() {
      _items.removeWhere((e) => e.id == item.id);
      if (_selectedId == item.id) _selectedId = null;
    });
    _showToast('🗑️ Removed sticker');
    _notifyChanged();
  }

  /// 内容变更通知外部（供持久化），视图平移缩放不触发
  void _notifyChanged() {
    widget.onChanged?.call(
      List.unmodifiable(_items),
      List.unmodifiable(_strokes),
    );
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
    _pushHistory();
    setState(() {
      _items.add(item);
      _selectedId = item.id;
      item.zIndex = ++_highestZ;
    });
    _notifyChanged();
  }

  /// 时间戳 id：重开画布后新增条目不与已存条目冲突
  String _nextId() => 'spawn_${DateTime.now().microsecondsSinceEpoch}';

  // ===== undo / redo =====

  void _pushHistory() {
    _undoStack.add(_snapshot());
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  _ScrapSnapshot _snapshot() => _ScrapSnapshot(
    items: [
      for (final item in _items) ScrapItemData.fromMap(item.toMap()),
    ],
    strokes: [
      for (final stroke in _strokes) ScrapStroke.fromMap(stroke.toMap()),
    ],
  );

  void _restore(_ScrapSnapshot snapshot) {
    setState(() {
      _items
        ..clear()
        ..addAll(snapshot.items);
      _strokes
        ..clear()
        ..addAll(snapshot.strokes);
      _selectedId = null;
      _highestZ = 35;
      for (final item in _items) {
        if (item.zIndex > _highestZ) _highestZ = item.zIndex;
      }
    });
    _notifyChanged();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot());
    _restore(_undoStack.removeLast());
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot());
    _restore(_redoStack.removeLast());
  }

  // ===== 添加素材（图片 / SVG 贴纸 / emoji） =====

  /// 文字条目快捷入口：弹输入对话框（文字 + 4 色点），确认后落到画布中心
  Future<void> _addTextItem() async {
    final controller = TextEditingController();
    var color = const Color(0xFFD9388A);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const noteColors = [
      Color(0xFFD9388A),
      Color(0xFF3B9E4C),
      Color(0xFFD4842A),
      Color(0xFF111111),
    ];

    void submit(BuildContext dialogContext) => Navigator.pop(dialogContext, true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor:
            isDark ? const Color(0xF21E293B) : const Color(0xF2FAF8F2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? const Color(0xFF3B4A61) : const Color(0xFFE5E0D5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF333333),
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Write a cute caption...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                onSubmitted: (_) => submit(dialogContext),
              ),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (context, setDialogState) => Row(
                  children: [
                    for (final c in noteColors)
                      GestureDetector(
                        onTap: () => setDialogState(() => color = c),
                        child: Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == c ? c : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => submit(dialogContext),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (!mounted || confirmed != true || text.isEmpty) return;

    final center = _canvasCenter();
    _spawnItem(
      ScrapItemData(
        id: _nextId(),
        kind: ScrapItemKind.text,
        captions: [text],
        captionColor: color,
        x: center.dx,
        y: center.dy,
      ),
    );
    _showToast('🏷️ Added caption to canvas');
  }

  Future<void> _pickAsset() async {
    final picker = widget.onPickAsset;
    if (picker == null) {
      _showToast('🧷 Picker not available');
      return;
    }
    final asset = await picker();
    if (asset == null || !mounted) return;

    if (asset.svgSource != null && asset.svgSource!.isNotEmpty) {
      _spawnItem(
        ScrapItemData(
          id: _nextId(),
          kind: ScrapItemKind.svg,
          svgSource: asset.svgSource,
          x: _canvasCenter().dx,
          y: _canvasCenter().dy,
          width: 96,
          height: 96,
          rotation: (math.Random().nextDouble() * 10 - 5),
        ),
      );
      _showToast('🧷 Added sticker');
      return;
    }
    if (asset.emoji != null && asset.emoji!.isNotEmpty) {
      _spawnItem(
        ScrapItemData(
          id: _nextId(),
          kind: ScrapItemKind.text,
          captions: [asset.emoji!],
          x: _canvasCenter().dx,
          y: _canvasCenter().dy,
          fontSize: 34,
        ),
      );
      return;
    }
    if (asset.imageUrl != null && asset.imageUrl!.isNotEmpty) {
      _spawnItem(
        ScrapItemData(
          id: _nextId(),
          kind: ScrapItemKind.photo,
          imageUrl: asset.imageUrl,
          x: _canvasCenter().dx,
          y: _canvasCenter().dy,
          width: 120,
          height: 120,
          rotation: (math.Random().nextDouble() * 8 - 4),
        ),
      );
      _showToast('📸 Added photo');
    }
  }

  // ===== 涂鸦模式 =====

  void _setDoodleMode(bool active) {
    setState(() {
      _doodleMode = active;
      if (active) {
        _selectedId = null;
      }
    });
    if (active) _showToast('✏️ Draw directly on the grid canvas!');
  }

  void _onDoodleStart(DragStartDetails details) {
    _pushHistory();
    final pt = _screenToCanvas(details.localPosition);
    setState(() => _strokes.add(ScrapStroke(_penColor, [pt])));
  }

  void _onDoodleUpdate(DragUpdateDetails details) {
    final pt = _screenToCanvas(details.localPosition);
    setState(() => _strokes.last.points.add(pt));
  }

  void _onDoodleEnd(DragEndDetails details) => _notifyChanged();

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
            // 画布交互区（网格 + 变换平面），RepaintBoundary 用于导出图片
            Positioned.fill(
              child: Listener(
                onPointerSignal: _onPointerSignal,
                child: RepaintBoundary(
                  key: _exportBoundaryKey,
                  child: _doodleMode
                      ? GestureDetector(
                          onPanStart: _onDoodleStart,
                          onPanUpdate: _onDoodleUpdate,
                          onPanEnd: _onDoodleEnd,
                          child: _buildCanvasLayers(gridColor, isDark),
                        )
                      : GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedId = null;
                            });
                          },
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          child: _buildCanvasLayers(gridColor, isDark),
                        ),
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
                      if (widget.onClose != null) {
                        widget.onClose!();
                        return;
                      }
                      setState(() {
                        _panX = 0;
                        _panY = 0;
                        _zoom = 1;
                      });
                      _showToast('🇯🇵 Viewing Tokyo Trip • Day 1 of 5');
                    }),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildExportButton(isDark),
                        const SizedBox(width: 8),
                        _buildNavPill('Save', isDark, () {
                          setState(() => _selectedId = null);
                          _showToast('✨ Saved "Tokyo DAY 1" to Memories!');
                        }),
                      ],
                    ),
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
            // 底部工具栏：undo / redo / 涂鸦 / 添加素材（只读模式下隐藏）
            if (!widget.readOnly)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(child: _buildToolbar(isDark)),
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 只读模式下条目不可拖拽/选中；注册 onTap 供双击检测使用
            onTap: () => _handleItemTap(item),
            onPanStart: _doodleMode || widget.readOnly
                ? null
                : (_) {
                    _pushHistory();
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
            onPanEnd:
                _doodleMode || widget.readOnly
                    ? null
                    : (_) => _notifyChanged(),
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
    );
  }

  /// 条目单击：只读模式下 300ms 内两次点击视为双击触发回调，
  /// 否则走选中逻辑（涂鸦模式忽略）
  DateTime? _lastItemTap;

  void _handleItemTap(ScrapItemData item) {
    if (widget.readOnly) {
      final now = DateTime.now();
      final last = _lastItemTap;
      _lastItemTap = now;
      if (last != null && now.difference(last).inMilliseconds < 320) {
        _lastItemTap = null;
        // 外部回调优先（自行接管打开逻辑），未注册则内建打开 GalleryViewer
        if (widget.onItemDoubleTap != null) {
          widget.onItemDoubleTap!.call(item);
        } else {
          _openPhotoInGalleryViewer(item);
        }
      }
      return;
    }
    if (!_doodleMode) _selectItem(item);
  }

  /// 只读模式双击图片条目：用 GalleryViewer 打开画布上的照片集
  /// （按 z 序收集全部 photo 条目，双击项为起始页），非图片条目忽略
  void _openPhotoInGalleryViewer(ScrapItemData item) {
    if (item.kind != ScrapItemKind.photo) return;
    final photoItems = _sortedItems()
        .where(
          (e) =>
              e.kind == ScrapItemKind.photo &&
              e.imageUrl != null &&
              e.imageUrl!.isNotEmpty,
        )
        .toList();
    if (photoItems.isEmpty) return;

    final index = photoItems.indexOf(item);
    NavigationHelper.push(
      context,
      GalleryViewer(
        title: 'Scrapbook',
        entranceAnimation: true,
        initialIndex: index < 0 ? 0 : index,
        photos: [
          for (final photo in photoItems)
            GalleryPhoto(
              url: photo.imageUrl!,
              caption: photo.captions.isNotEmpty ? photo.captions.first : null,
            ),
        ],
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

  // ===== 导出画布 =====

  Widget _buildExportButton(bool isDark) {
    return GestureDetector(
      onTap: _exporting ? null : _exportCanvasPng,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xD92A3648) : const Color(0xD9FBF9F4),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? const Color(0xFF3B4A61) : const Color(0xFFE5E0D4),
          ),
        ),
        alignment: Alignment.center,
        child: _exporting
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF001AFF),
                ),
              )
            : Icon(
                Icons.download,
                size: 16,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
      ),
    );
  }

  Future<void> _exportCanvasPng() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      // 隐藏选中虚线框与控制按钮，避免拍进图里
      _selectedId = null;
    });

    try {
      // 确保入场动画与选中态消失后的帧都已绘制
      if (_entryController.isAnimating) {
        await _entryController.forward();
      }
      final pngBytes = await captureCuteNotepadPng(
        _exportBoundaryKey,
        pixelRatio: 3,
      );
      if (pngBytes == null) {
        throw StateError('无法获取画布绘制边界');
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/scrapbook-canvas-'
        '${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      if (!mounted) return;
      ToastService.instance.showToast(
        '已导出画布 PNG：${file.path}',
        type: ToastType.success,
      );
    } catch (e) {
      if (mounted) {
        ToastService.instance.showToast(
          '导出失败：$e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  // ===== 底部工具栏 =====

  /// undo / redo / 涂鸦 / 添加素材（pill 风格与顶部导航一致）
  Widget _buildToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xD92A3648) : const Color(0xD9FBF9F4),
        border: Border.all(
          color: isDark ? const Color(0xFF3B4A61) : const Color(0xFFE5E0D4),
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolbarButton(
            icon: Icons.undo,
            label: 'Undo',
            isDark: isDark,
            onPressed: _undoStack.isEmpty ? null : _undo,
          ),
          _buildToolbarButton(
            icon: Icons.redo,
            label: 'Redo',
            isDark: isDark,
            onPressed: _redoStack.isEmpty ? null : _redo,
          ),
          _buildToolbarDivider(isDark),
          _buildToolbarButton(
            icon: Icons.text_fields,
            label: 'Text',
            isDark: isDark,
            onPressed: _addTextItem,
          ),
          _buildToolbarButton(
            icon: Icons.edit,
            label: 'Doodle',
            isDark: isDark,
            active: _doodleMode,
            onPressed: () => _setDoodleMode(!_doodleMode),
          ),
          _buildToolbarButton(
            icon: Icons.add_photo_alternate_outlined,
            label: 'Add',
            isDark: isDark,
            onPressed: _pickAsset,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback? onPressed,
    bool active = false,
  }) {
    final enabled = onPressed != null;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF001AFF)
                : (isDark ? Colors.white12 : const Color(0x0F000000)),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: active
                ? Colors.white
                : (isDark
                      ? (enabled ? Colors.white : Colors.white38)
                      : (enabled ? const Color(0xFF1A1A1A) : const Color(0x611A1A1A))),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarDivider(bool isDark) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: isDark ? Colors.white24 : const Color(0x14202020),
    );
  }

  // ===== 涂鸦横幅 =====

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

}


/// undo/redo 历史快照（条目与涂鸦的深拷贝）
class _ScrapSnapshot {
  final List<ScrapItemData> items;
  final List<ScrapStroke> strokes;

  const _ScrapSnapshot({required this.items, required this.strokes});
}