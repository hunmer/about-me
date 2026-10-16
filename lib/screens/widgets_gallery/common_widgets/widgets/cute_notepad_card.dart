import 'dart:io' show File;
import 'dart:isolate' show Isolate;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderProxyBox, RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

import 'cute_notepad_stickers.dart';
import 'cute_notepad_variants.dart';

/// 画布坐标系宽度（与网页版 viewBox 一致）
const double _kViewBoxWidth = 300;

/// 最小画布高度
const double _kMinViewBoxHeight = 300;

/// 自由文本行高（viewBox 单位）
const double _kFreeformLineHeight = 26;

/// 底部留白（保证底部贴纸不遮挡文字）
const double _kBottomClearance = 73;

/// 手写正文字号（viewBox 单位）
const double _kBodyFontSize = 15.2;

/// 手账手写字体（851 手写杂书体）
const String _kHandFont = 'TegakiZatsu';

/// 将样式预设的贴纸解析为绝对坐标布局（贴图编辑器初始 / 重置用）
List<CuteNotepadSticker> resolveCuteNotepadStickerLayouts({
  required CuteNotepadVariant variant,
  String? title,
  String? text,
  List<CuteNotepadTodoItem>? items,
}) {
  final canvasHeight = _NoteLayoutEngine.compute(
    variant,
    title ?? variant.title ?? '',
    text ?? '',
    items ?? variant.items,
  ).height;
  return [
    for (final s in variant.stickers)
      () {
        final pos = _anchorOffset(s.anchor, s.w, s.h, canvasHeight);
        return CuteNotepadSticker(
          asset: s.asset,
          anchor: s.anchor,
          w: s.w,
          h: s.h,
          dx: s.dx,
          dy: s.dy,
          x: pos.dx + s.dx,
          y: pos.dy + s.dy,
          rotation: s.rotation,
          scale: s.scale,
        );
      }(),
  ];
}

/// 捕获便签卡片当前画面为 PNG 字节
///
/// [boundaryKey] 需是传入 [CuteNotepadCardWidget.repaintBoundaryKey] 的 key，
/// 且卡片已完成入场动画（编辑场景下通常早已完成）。
Future<Uint8List?> captureCuteNotepadPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 3,
}) async {
  await WidgetsBinding.instance.endOfFrame;
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    // 纯 Dart PNG 编码（避免部分平台 toByteData(png) 编码挂起）。
    // 编码移入后台 isolate：长内容高画布 × pixelRatio 的同步编码
    // 会阻塞 UI 线程数秒，桌面端表现为窗口假死/白屏
    final rgba = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final width = image.width;
    final height = image.height;
    return await Isolate.run(() {
      final pngImage = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgba.buffer,
        bytesOffset: rgba.offsetInBytes,
        order: img.ChannelOrder.rgba,
        numChannels: 4,
      );
      return img.encodePng(pngImage);
    });
  } finally {
    image.dispose();
  }
}

/// 可爱手账便签卡片
///
/// 移植自 Cute Template Notepad：手绘便签底图（方格/格纹/波浪框/撕边/活页孔等
/// 16 种风格预设）+ 可爱贴纸（flutter_svg 渲染）+ 手写标题/正文/待办内容。
/// 高度随内容自动撑开（viewBox 300×H），单一组件入口，通过 [variant] 切换风格。
///
/// 开启 [editable] 后右上角显示编辑按钮；进入编辑模式后按钮切换为「导出 PNG」，
/// 此时点选贴纸可拖动改变位置、双指/Shift+滚轮旋转缩放（选中后底部有工具条），
/// 点击导出按钮将当前便签渲染为高清 PNG 保存到临时目录并退出编辑。
///
/// 贴图编辑器场景可传 [stickers] 完全接管贴纸列表（添加/删除由外部驱动，
/// 已有贴纸的拖动/旋转/缩放状态在列表变化时按贴纸资产自动保留），
/// 传入 [repaintBoundaryKey] 配合 [captureCuteNotepadPng] 自行导出。
class CuteNotepadCardWidget extends StatefulWidget {
  /// 风格预设
  final CuteNotepadVariant variant;

  /// 覆盖标题（null 使用预设标题，空串隐藏标题）
  final String? title;

  /// 自由文本内容（freeform 类型）
  final String? text;

  /// 正文自定义渲染（freeform 类型，覆盖 [text] 的手绘文字，
  /// 如传入 MarkdownContent 渲染 markdown 消息）；
  /// 画布高度随其测量高度自动撑开
  final Widget? contentWidget;

  /// 待办/横线行（null 使用预设空白行）
  final List<CuteNotepadTodoItem>? items;

  /// 覆盖贴纸列表（null 使用预设贴纸；非 null 时完全由外部管理）
  final List<CuteNotepadSticker>? stickers;

  /// 编辑模式下贴纸被工具条删除时回调（下标针对当前贴纸列表）
  final void Function(int index)? onStickerRemoved;

  /// 贴纸布局变化回传（受控模式）：拖拽/旋转/缩放结束后给出完整布局快照，
  /// 配合外部撤销栈使用；同一帧内多次操作合并为一次回传
  final void Function(List<CuteNotepadSticker> layouts)? onStickersLayoutChanged;

  /// 外部传入的绘制边界 key（配合 captureCuteNotepadPng 导出）
  final GlobalKey? repaintBoundaryKey;

  /// 是否展示编辑入口（编辑模式下可变换贴纸并导出 PNG）
  final bool editable;

  /// editable 时初始即处于编辑模式（贴图编辑器场景）
  final bool initialEditing;

  /// editable 时是否显示右上角编辑/导出按钮（编辑器自行提供保存/分享时隐藏）
  final bool showModeButton;

  /// 是否为内联模式
  final bool inline;

  /// 覆盖卡片宽度（默认 384 × size.scale；样式迷你预览等场景使用）
  final double? cardWidth;

  /// 组件尺寸
  final HomeWidgetSize size;

  const CuteNotepadCardWidget({
    super.key,
    required this.variant,
    this.title,
    this.text,
    this.contentWidget,
    this.items,
    this.stickers,
    this.onStickerRemoved,
    this.onStickersLayoutChanged,
    this.repaintBoundaryKey,
    this.editable = false,
    this.initialEditing = false,
    this.showModeButton = true,
    this.inline = false,
    this.cardWidth,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例
  ///
  /// - style: 风格 id（如 'pinkGridBunny'）或序号 0~15，缺省用第一种
  /// - title / text / items: 覆盖预设内容
  /// - editable: 开启编辑入口
  factory CuteNotepadCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final variant =
        props['variant'] is CuteNotepadVariant
            ? props['variant']! as CuteNotepadVariant
            : resolveCuteNotepadVariant(props['style']);

    List<CuteNotepadTodoItem>? items;
    final itemsData = props['items'];
    if (itemsData is List) {
      items =
          itemsData.map((e) {
            if (e is Map) {
              return CuteNotepadTodoItem(
                checked: e['checked'] == true,
                text: e['text']?.toString() ?? '',
              );
            }
            return const CuteNotepadTodoItem();
          }).toList();
    }

    return CuteNotepadCardWidget(
      variant: variant,
      title: props['title'] as String?,
      text: props['text'] as String?,
      items: items,
      stickers: _parseStickers(props['stickers']),
      editable: props['editable'] as bool? ?? false,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  static List<CuteNotepadSticker>? _parseStickers(dynamic data) {
    if (data is! List) return null;
    final result = <CuteNotepadSticker>[];
    for (final e in data) {
      if (e is Map) {
        final anchorName = e['anchor'] as String?;
        CuteNotepadStickerAnchor? anchor;
        for (final a in CuteNotepadStickerAnchor.values) {
          if (a.name == anchorName) anchor = a;
        }
        result.add(
          CuteNotepadSticker(
            asset: e['asset'] as String? ?? '',
            anchor: anchor ?? CuteNotepadStickerAnchor.center,
            w: (e['w'] as num?)?.toDouble() ?? 60,
            h: (e['h'] as num?)?.toDouble() ?? 60,
            dx: (e['dx'] as num?)?.toDouble() ?? 0,
            dy: (e['dy'] as num?)?.toDouble() ?? 0,
          ),
        );
      }
    }
    return result;
  }

  @override
  State<CuteNotepadCardWidget> createState() => _CuteNotepadCardWidgetState();
}

class _CuteNotepadCardWidgetState extends State<CuteNotepadCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  /// 编辑模式（可变换贴纸）
  bool _editing = false;

  /// 正在导出 PNG
  bool _exporting = false;

  /// 当前选中的贴纸下标（null 未选中）
  int? _selectedSticker;

  /// 贴纸可编辑状态（位置/旋转/缩放，viewBox 坐标）
  late List<_EditableSticker> _stickerStates;

  /// 导出用绘制边界
  final GlobalKey _exportBoundaryKey = GlobalKey();

  // 缩放手势过程中的增量基准
  double _gestureScale = 1;
  double _gestureRotation = 0;

  /// contentWidget 测量高度换算的行数（null = 未测量）
  double? _contentWidgetLines;

  void _onContentMeasured(Size logicalSize) {
    if (logicalSize.height <= 0) return;
    final lines = (logicalSize.height / _kFreeformLineHeight).ceilToDouble();
    if (lines == _contentWidgetLines) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && lines != _contentWidgetLines) {
        setState(() => _contentWidgetLines = lines);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _editing = widget.initialEditing;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
    _stickerStates = _buildStickerStates();
  }

  @override
  void didUpdateWidget(covariant CuteNotepadCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stickers != null) {
      // 编辑器接管贴纸列表：列表变化时按贴纸资产合并，保留已有变换
      final oldSpecs = oldWidget.stickers ?? oldWidget.variant.stickers;
      final newSpecs = widget.stickers!;
      if (!identical(oldSpecs, newSpecs)) {
        _mergeStickerStates(newSpecs);
        if (_selectedSticker != null &&
            _selectedSticker! >= _stickerStates.length) {
          _selectedSticker = null;
        }
      }
      return;
    }
    if (oldWidget.variant != widget.variant ||
        oldWidget.text != widget.text ||
        oldWidget.items != widget.items ||
        oldWidget.title != widget.title) {
      _stickerStates = _buildStickerStates();
      _selectedSticker = null;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<_EditableSticker> _buildStickerStates() {
    final canvasHeight = _NoteLayoutEngine.compute(
      widget.variant,
      widget.title ?? widget.variant.title ?? '',
      widget.text ?? '',
      widget.items ?? widget.variant.items,
    ).height;
    final specs = widget.stickers ?? widget.variant.stickers;
    return [
      for (final s in specs) _EditableSticker.fromPreset(s, canvasHeight),
    ];
  }

  /// 按 asset 匹配合并贴纸状态：外部列表增删/重排后，已有贴纸的
  /// 位置/旋转/缩放保留，新增贴纸按预设锚点初始化。
  /// 携带绝对布局（x/y/rotation/scale）的 spec 视为受控，直接按值重建。
  void _mergeStickerStates(List<CuteNotepadSticker> specs) {
    final canvasHeight = _stickerStates.isNotEmpty
        ? _stickerStates.first.canvasHeight
        : _kMinViewBoxHeight;
    final pool = List<_EditableSticker>.from(_stickerStates);
    final merged = <_EditableSticker>[];
    for (final spec in specs) {
      if (spec.x != null || spec.y != null) {
        merged.add(_EditableSticker.fromPreset(spec, canvasHeight));
        continue;
      }
      final idx = pool.indexWhere((s) => s.asset == spec.asset);
      if (idx >= 0) {
        merged.add(pool.removeAt(idx));
      } else {
        merged.add(_EditableSticker.fromPreset(spec, canvasHeight));
      }
    }
    _stickerStates = merged;
  }

  /// 当前贴纸布局快照（受控回传）
  List<CuteNotepadSticker> _currentStickerLayouts() {
    return [
      for (final s in _stickerStates)
        CuteNotepadSticker(
          asset: s.asset,
          w: s.w,
          h: s.h,
          x: s.x,
          y: s.y,
          rotation: s.rotation,
          scale: s.scale,
          flipX: s.flipX,
        ),
    ];
  }

  /// 帧末合并回传贴纸布局（同一帧多次操作只回传一次）
  bool _layoutSyncScheduled = false;
  void _scheduleLayoutSync() {
    final callback = widget.onStickersLayoutChanged;
    if (callback == null || _layoutSyncScheduled) return;
    _layoutSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutSyncScheduled = false;
      if (!mounted) return;
      widget.onStickersLayoutChanged?.call(_currentStickerLayouts());
    });
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.variant;
    final title = widget.title ?? variant.title ?? '';
    final text = widget.text ?? '';
    final items = widget.items ?? variant.items;
    final useContentWidget =
        widget.contentWidget != null &&
        variant.type == CuteNotepadNoteType.freeform;
    final layout = _NoteLayoutEngine.compute(
      variant,
      title,
      text,
      items,
      contentWidgetLines: useContentWidget ? _contentWidgetLines : null,
      contentWidgetMode: useContentWidget,
    );

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
      child: SizedBox(
        width:
            widget.inline
                ? double.maxFinite
                : widget.cardWidth ?? 384 * widget.size.scale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 便签本体（导出边界，不包含右上角按钮与工具条）
            AspectRatio(
              aspectRatio: _kViewBoxWidth / layout.height,
              child: RepaintBoundary(
                key: widget.repaintBoundaryKey ?? _exportBoundaryKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final unit = constraints.maxWidth / _kViewBoxWidth;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            // 编辑模式下点击空白处取消贴纸选中
                            behavior: HitTestBehavior.opaque,
                            onTap:
                                _editing && _selectedSticker != null
                                    ? () => setState(() => _selectedSticker = null)
                                    : null,
                            child: CustomPaint(
                              painter: _CuteNotepadPainter(
                                variant: variant,
                                layout: layout,
                              ),
                            ),
                          ),
                        ),
                        // 正文自定义渲染层（如 Markdown），位于贴纸之下
                        if (useContentWidget && layout.freeformRect != null)
                          Positioned(
                            left: layout.freeformRect!.left * unit,
                            top: layout.freeformRect!.top * unit,
                            width: (layout.freeformRect!.width - 4) * unit,
                            child: FittedBox(
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topLeft,
                              clipBehavior: Clip.none,
                              child: _SizeReporter(
                                onSizeChanged: _onContentMeasured,
                                child: SizedBox(
                                  width: layout.freeformRect!.width - 4,
                                  child: widget.contentWidget,
                                ),
                              ),
                            ),
                          ),
                        for (int i = 0; i < _stickerStates.length; i++)
                          _buildSticker(
                            i,
                            unit,
                            layout.height,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // 右上角：编辑按钮 ↔ 导出 PNG 按钮
            if (widget.editable && widget.showModeButton)
              Positioned(top: -12, right: 2, child: _buildModeButton()),

            // 编辑模式选中贴纸时的变换工具条
            if (widget.editable &&
                _editing &&
                _selectedSticker != null)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(child: _buildStickerToolbar()),
              ),
          ],
        ),
      ),
    );
  }

  // ---- 编辑模式 UI ----

  /// 右上角模式按钮：未编辑 → 编辑；编辑中 → 导出 PNG
  Widget _buildModeButton() {
    final editing = _editing;
    return Tooltip(
      message: editing ? '导出 PNG' : '编辑便签',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _exporting ? null : (editing ? _exportPng : _enterEditing),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: editing ? const Color(0xFFFFDCE2) : Colors.white,
              border: Border.all(color: const Color(0xFF6B4C3B), width: 1.5),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child:
                _exporting
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF5A3B2E),
                      ),
                    )
                    : Icon(
                      editing ? Icons.download : Icons.edit,
                      size: 16,
                      color: const Color(0xFF5A3B2E),
                    ),
          ),
        ),
      ),
    );
  }

  /// 贴纸变换工具条（旋转 / 缩放）
  Widget _buildStickerToolbar() {
    Widget toolButton(IconData icon, String label, VoidCallback onTap) {
      return Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(icon, size: 15, color: const Color(0xFF5A4235)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: Border.all(color: const Color(0xFFCBB7A6)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          toolButton(Icons.rotate_left, '左转 15°', () => _nudgeSelected(
            rotation: -15,
          )),
          toolButton(Icons.rotate_right, '右转 15°', () => _nudgeSelected(
            rotation: 15,
          )),
          const SizedBox(width: 2),
          toolButton(Icons.remove, '缩小', () => _nudgeSelected(scaleRatio: 0.9)),
          toolButton(Icons.add, '放大', () => _nudgeSelected(scaleRatio: 1.1)),
          const SizedBox(width: 2),
          toolButton(Icons.flip, '水平翻转', _toggleFlipSelected),
          // 贴图编辑器场景：删除当前贴纸（由外部更新贴纸列表）
          if (widget.onStickerRemoved != null && _selectedSticker != null) ...[
            const SizedBox(width: 2),
            toolButton(Icons.delete_outline, '删除贴纸', () {
              widget.onStickerRemoved!.call(_selectedSticker!);
            }),
          ],
        ],
      ),
    );
  }

  void _enterEditing() {
    setState(() => _editing = true);
  }

  /// 工具条微调当前选中贴纸
  void _nudgeSelected({double rotation = 0, double scaleRatio = 1}) {
    final index = _selectedSticker;
    if (index == null || index >= _stickerStates.length) return;
    final st = _stickerStates[index];
    _applySticker(
      index,
      rotation: st.rotation + rotation,
      scale: st.scale * scaleRatio,
    );
    _scheduleLayoutSync();
  }

  /// 水平翻转当前选中贴纸
  void _toggleFlipSelected() {
    final index = _selectedSticker;
    if (index == null || index >= _stickerStates.length) return;
    final st = _stickerStates[index];
    setState(() => st.flipX = !st.flipX);
    _scheduleLayoutSync();
  }

  /// 更新贴纸并刷新（clamp 到画布附近，允许少量出界）
  void _applySticker(
    int index, {
    double? x,
    double? y,
    double? rotation,
    double? scale,
  }) {
    final st = _stickerStates[index];
    setState(() {
      if (x != null) st.x = x.clamp(-st.w * 0.5, _kViewBoxWidth - st.w * 0.5);
      if (y != null) st.y = y.clamp(-st.h * 0.3, st.canvasHeight - st.h * 0.6);
      if (rotation != null) st.rotation = rotation.clamp(-360, 360);
      if (scale != null) st.scale = scale.clamp(0.3, 3.0);
    });
  }

  // ---- 贴纸 ----

  Widget _buildSticker(int index, double unit, double canvasHeight) {
    final st = _stickerStates[index];
    if (st.canvasHeight != canvasHeight) st.canvasHeight = canvasHeight;

    // 贴纸依次弹性弹出（编辑结束后仍保留入场效果）
    final begin = math.min(0.35 + index * 0.07, 0.85);
    final pop = CurvedAnimation(
      parent: _animationController,
      curve: Interval(begin, math.min(begin + 0.45, 1.0),
          curve: Curves.easeOutBack),
    );

    final selected = _editing && _selectedSticker == index;

    Widget content = Transform(
      alignment: Alignment.center,
      transform:
          Matrix4.rotationZ(st.rotation * math.pi / 180)
            ..scale(st.flipX ? -st.scale : st.scale, st.scale, 1),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          SvgPicture.string(
            cuteNotepadStickerSvg(st.asset),
            fit: BoxFit.contain,
          ),
          // 选中框（随贴纸一起旋转缩放）
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFE11D48).withOpacity(0.85),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (_editing) {
      content = MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Listener(
          // 滚轮缩放；Shift+滚轮旋转（桌面端）
          onPointerSignal: (event) {
            // 滚轮缩放；Shift+滚轮旋转（桌面端）
            if (event is PointerScrollEvent && _selectedSticker == index) {
              final down = event.scrollDelta.dy > 0;
              final cur = _stickerStates[index];
              if (HardwareKeyboard.instance.isShiftPressed) {
                _applySticker(
                  index,
                  rotation: cur.rotation + (down ? 5 : -5),
                );
              } else {
                _applySticker(
                  index,
                  scale: cur.scale * (down ? 0.94 : 1.06),
                );
              }
              _scheduleLayoutSync();
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(
              () => _selectedSticker = _selectedSticker == index ? null : index,
            ),
            // 单指拖动 / 双指旋转缩放共用 scale 手势
            onScaleStart: (details) {
              _gestureScale = 1;
              _gestureRotation = 0;
              setState(() => _selectedSticker = index);
            },
            onScaleUpdate: (details) {
              final st = _stickerStates[index];
              _applySticker(
                index,
                x: st.x + details.focalPointDelta.dx / unit,
                y: st.y + details.focalPointDelta.dy / unit,
                scale: st.scale * details.scale / _gestureScale,
                rotation:
                    st.rotation + (details.rotation - _gestureRotation) * 180 /
                    math.pi,
              );
              _gestureScale = details.scale;
              _gestureRotation = details.rotation;
            },
            onScaleEnd: (_) => _scheduleLayoutSync(),
            child: content,
          ),
        ),
      );
    }

    return Positioned(
      left: st.x * unit,
      top: st.y * unit,
      width: st.w * unit,
      height: st.h * unit,
      child: AnimatedBuilder(
        animation: pop,
        builder: (context, child) {
          return Transform.scale(
            scale: pop.value.clamp(0.0, 1.2),
            child: child,
          );
        },
        child: content,
      ),
    );
  }

  // ---- 导出 PNG ----

  Future<void> _exportPng() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      // 先隐藏选中框，避免拍进图里
      _selectedSticker = null;
    });

    try {
      // 确保入场动画与选中框消失后的帧都已绘制
      if (_animationController.isAnimating) {
        await _animationController.forward();
      }
      final pngBytes = await captureCuteNotepadPng(
        widget.repaintBoundaryKey ?? _exportBoundaryKey,
      );
      if (pngBytes == null) {
        throw StateError('无法获取便签绘制边界');
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/cute-notepad-${widget.variant.id}-'
        '${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      if (!mounted) return;
      ToastService.instance.showToast(
        '已导出 PNG：${file.path}',
        type: ToastType.success,
      );
      // 导出完成，退出编辑模式
      setState(() => _editing = false);
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
}

/// 贴纸的可编辑运行时状态（viewBox 坐标系）
class _EditableSticker {
  final String asset;
  final double w;
  final double h;

  double x;
  double y;
  double rotation = 0; // 角度
  double scale = 1;
  bool flipX = false;

  /// 底部锚定贴纸需要感知画布高度（允许随内容撑高微调）
  double canvasHeight;

  _EditableSticker({
    required this.asset,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.rotation = 0,
    this.scale = 1,
    this.flipX = false,
    required this.canvasHeight,
  });

  factory _EditableSticker.fromPreset(
    CuteNotepadSticker preset,
    double canvasHeight,
  ) {
    final pos = _anchorOffset(preset.anchor, preset.w, preset.h, canvasHeight);
    return _EditableSticker(
      asset: preset.asset,
      // 绝对布局（编辑器受控）优先于锚点 + 偏移
      x: preset.x ?? pos.dx + preset.dx,
      y: preset.y ?? pos.dy + preset.dy,
      w: preset.w,
      h: preset.h,
      rotation: preset.rotation ?? 0,
      scale: preset.scale ?? 1,
      flipX: preset.flipX,
      canvasHeight: canvasHeight,
    );
  }
}

/// 按锚点方位计算贴纸在 viewBox 坐标系中的基准位置
Offset _anchorOffset(
  CuteNotepadStickerAnchor anchor,
  double w,
  double h,
  double canvasHeight,
) {
  const margin = 10.0;
  switch (anchor) {
    case CuteNotepadStickerAnchor.topLeft:
      return const Offset(margin, margin);
    case CuteNotepadStickerAnchor.topCenter:
      return Offset((_kViewBoxWidth - w) / 2, 4);
    case CuteNotepadStickerAnchor.topRight:
      return Offset(_kViewBoxWidth - w - margin, margin);
    case CuteNotepadStickerAnchor.bottomLeft:
      return Offset(margin, canvasHeight - h - margin);
    case CuteNotepadStickerAnchor.bottomRight:
      return Offset(_kViewBoxWidth - w - margin, canvasHeight - h - margin);
    case CuteNotepadStickerAnchor.center:
      return Offset(
        (_kViewBoxWidth - w) / 2,
        (canvasHeight - h) / 2,
      );
  }
}

// ---------------------------------------------------------------------------
// 布局引擎（移植网页版 computeNoteLayout：按内容计算画布高度与各行坐标）
// ---------------------------------------------------------------------------

/// 单条待办/横线行的布局
class _NoteItemLayout {
  final int itemIndex;
  final double top;
  final double height;
  final List<double> underlineYs;
  final bool checked;
  final TextPainter? painter;
  final double textLeft;

  const _NoteItemLayout({
    required this.itemIndex,
    required this.top,
    required this.height,
    required this.underlineYs,
    required this.checked,
    this.painter,
    required this.textLeft,
  });
}

/// 自由文本区的一行（markdown 复选框语法解析结果）：
/// 待办行（手绘复选框 + 底线）或普通文本行，交错排列
class _FreeformLine {
  final bool isTodo;
  final bool checked;

  /// 普通文本行
  final TextPainter? painter;

  /// 待办行文本与底线
  final TextPainter? todoPainter;
  final double top;
  final List<double> underlineYs;

  const _FreeformLine({
    required this.isTodo,
    this.checked = false,
    this.painter,
    this.todoPainter,
    required this.top,
    this.underlineYs = const [],
  });
}

/// markdown 任务列表语法（- [ ] / * [x] 等），供编辑器侧复用
final RegExp markdownTodoPattern = RegExp(
  r'^\s*[-*+]\s+\[( |x|X)\]\s*(.*)$',
);

/// 整张便签的布局结果
class _NoteLayout {
  final double height;

  final TextPainter? titlePainter;
  final Offset titleOffset;
  final double titleRotateRad;
  final Offset titleRotateOrigin;

  final TextPainter? freeformPainter;
  final Offset freeformOffset;

  /// 自由文本区（viewBox 坐标；contentWidget 叠放位置）
  final Rect? freeformRect;

  /// markdown 复选框解析后的行序列（非 null 时按行渲染，
  /// 覆盖整块 freeformPainter 文字）
  final List<_FreeformLine>? freeformLines;

  final List<_NoteItemLayout> itemLayouts;
  final bool hasCheck;

  const _NoteLayout({
    required this.height,
    this.titlePainter,
    this.titleOffset = Offset.zero,
    this.titleRotateRad = 0,
    this.titleRotateOrigin = Offset.zero,
    this.freeformPainter,
    this.freeformOffset = Offset.zero,
    this.freeformRect,
    this.freeformLines,
    required this.itemLayouts,
    required this.hasCheck,
  });
}

class _NoteLayoutEngine {
  static _NoteLayout compute(
    CuteNotepadVariant variant,
    String title,
    String text,
    List<CuteNotepadTodoItem> items, {
    double? contentWidgetLines,
    bool contentWidgetMode = false,
  }) {
    var curY = variant.contentStartY;
    final spacing = variant.lineSpacing;

    final hasCheck =
        variant.type == CuteNotepadNoteType.checklist ||
        variant.type == CuteNotepadNoteType.freeform ||
        variant.showChecksOnLined;
    final lineX1 = hasCheck ? 62.0 : (variant.lineX1 ?? 36.0);
    final lineX2 = variant.lineX2 ?? 252.0;
    final textLeft = hasCheck ? 63.0 : lineX1 + 2;
    final textWidth = lineX2 - textLeft;

    // 1. 标题
    TextPainter? titlePainter;
    Offset titleOffset = Offset.zero;
    double titleRotateRad = 0;
    Offset titleRotateOrigin = Offset.zero;
    final tp = variant.titlePos;
    if (title.isNotEmpty && tp != null) {
      titlePainter = _textPainter(
        title,
        fontSize: tp.fontSize,
        lineHeight: tp.fontSize * 1.15,
        maxWidth: tp.width,
        color: variant.textColor,
        weight: FontWeight.w700,
        align: tp.center ? TextAlign.center : TextAlign.left,
      );
      // 网页版文字基线在 top + 17，近似换算为绘制顶部
      titleOffset = Offset(tp.left, tp.top + 17 - tp.fontSize * 0.8);
      if (tp.rotate != 0) {
        titleRotateRad = tp.rotate * math.pi / 180;
        titleRotateOrigin = Offset(tp.left + 20, tp.top + 14);
      }
    }

    // 2. 自由文本区
    TextPainter? freeformPainter;
    Offset freeformOffset = Offset.zero;
    Rect? freeformRect;
    List<_FreeformLine>? freeformLines;
    if (variant.type == CuteNotepadNoteType.freeform) {
      final freeformTop = curY;
      final minLines = items.isEmpty ? variant.minFreeformLines : 2;
      final hasTodoLines =
          text.isNotEmpty &&
          !contentWidgetMode &&
          text.split('\n').any((l) => markdownTodoPattern.hasMatch(l));

      var lines = minLines;
      if (hasTodoLines) {
        // markdown 复选框语法 → 手绘待办行 + 文本行交错布局
        freeformLines = [];
        var y = freeformTop;
        final todoTextLeft = 63.0;
        final todoLineX2 = variant.freeformLeft + variant.freeformWidth - 2;
        final todoTextWidth = todoLineX2 - todoTextLeft - 2;
        for (final rawLine in text.split('\n')) {
          final match = markdownTodoPattern.firstMatch(rawLine);
          if (match != null) {
            final checked = (match.group(1) ?? ' ').toLowerCase() == 'x';
            final todoText = match.group(2)?.trim() ?? '';
            TextPainter? tp;
            var lineCount = 1;
            if (todoText.isNotEmpty) {
              tp = _textPainter(
                todoText,
                fontSize: _kBodyFontSize,
                lineHeight: variant.lineSpacing,
                maxWidth: todoTextWidth,
                color: checked
                    ? variant.textColor.withOpacity(0.6)
                    : variant.textColor,
                lineThrough: checked,
              );
              lineCount = math.max(1, tp.computeLineMetrics().length);
            }
            freeformLines.add(
              _FreeformLine(
                isTodo: true,
                checked: checked,
                todoPainter: tp,
                top: y,
                underlineYs: List<double>.generate(
                  lineCount,
                  (l) => y + (l + 1) * variant.lineSpacing - 8,
                ),
              ),
            );
            y += lineCount * variant.lineSpacing;
          } else {
            TextPainter? tp;
            var lineCount = 1;
            if (rawLine.trim().isNotEmpty) {
              tp = _textPainter(
                rawLine,
                fontSize: 15.5,
                lineHeight: _kFreeformLineHeight,
                maxWidth: variant.freeformWidth - 4,
                color: variant.textColor,
              );
              lineCount = math.max(1, tp.computeLineMetrics().length);
            }
            freeformLines.add(
              _FreeformLine(isTodo: false, painter: tp, top: y),
            );
            y += lineCount * _kFreeformLineHeight;
          }
        }
        final contentHeight = y - curY;
        lines = (contentHeight / _kFreeformLineHeight).ceil();
        curY += math.max(contentHeight, minLines * _kFreeformLineHeight) +
            (items.isNotEmpty ? 6 : 0);
      } else {
        if (contentWidgetLines != null) {
          // contentWidget 模式：按测量高度换算行数
          lines = math.max(minLines, contentWidgetLines.ceil());
        } else if (text.isNotEmpty) {
          // 未测量时按纯文本估算（contentWidget 模式只估行数，不画手绘文字）
          final estimate = _textPainter(
            text,
            fontSize: 15.5,
            lineHeight: _kFreeformLineHeight,
            maxWidth: variant.freeformWidth - 4,
            color: variant.textColor,
          );
          lines = math.max(minLines, estimate.computeLineMetrics().length);
          if (!contentWidgetMode) {
            freeformPainter = estimate;
          }
        }
        freeformOffset = Offset(variant.freeformLeft + 2, curY + 1);
        curY += lines * _kFreeformLineHeight + (items.isNotEmpty ? 6 : 0);
      }
      freeformRect = Rect.fromLTWH(
        variant.freeformLeft,
        freeformTop,
        variant.freeformWidth,
        math.max(0, lines * _kFreeformLineHeight),
      );
    }

    // 3. 待办/横线行
    final itemLayouts = <_NoteItemLayout>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      TextPainter? painter;
      var lineCount = 1;
      if (item.text.isNotEmpty) {
        painter = _textPainter(
          item.text,
          fontSize: _kBodyFontSize,
          lineHeight: spacing,
          maxWidth: textWidth - 4,
          color: item.checked
              ? variant.textColor.withOpacity(0.6)
              : variant.textColor,
          lineThrough: item.checked,
        );
        lineCount = math.max(1, painter.computeLineMetrics().length);
      }
      final top = curY;
      final height = lineCount * spacing;
      final underlineYs = List<double>.generate(
        lineCount,
        (l) => top + (l + 1) * spacing - 8,
      );
      itemLayouts.add(
        _NoteItemLayout(
          itemIndex: i,
          top: top,
          height: height,
          underlineYs: underlineYs,
          checked: item.checked,
          painter: painter,
          textLeft: textLeft,
        ),
      );
      curY += height;
    }

    final height = math.max(
      _kMinViewBoxHeight,
      (curY + _kBottomClearance).ceilToDouble(),
    );

    return _NoteLayout(
      height: height,
      titlePainter: titlePainter,
      titleOffset: titleOffset,
      titleRotateRad: titleRotateRad,
      titleRotateOrigin: titleRotateOrigin,
      freeformPainter: freeformPainter,
      freeformOffset: freeformOffset,
      freeformRect: freeformRect,
      freeformLines: freeformLines,
      itemLayouts: itemLayouts,
      hasCheck: hasCheck,
    );
  }

  static TextPainter _textPainter(
    String text, {
    required double fontSize,
    required double lineHeight,
    required double maxWidth,
    required Color color,
    FontWeight weight = FontWeight.w500,
    TextAlign align = TextAlign.left,
    bool lineThrough = false,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _kHandFont,
          fontSize: fontSize,
          height: lineHeight / fontSize,
          // 与浏览器 line-height 的 half-leading 模型一致：行距上下均分，
          // 否则字形沉底、手绘下划线（行底 -8）会穿过文字中部
          leadingDistribution: TextLeadingDistribution.even,
          color: color,
          fontWeight: weight,
          decoration: lineThrough ? TextDecoration.lineThrough : null,
          decorationColor: color,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
  }
}

// ---------------------------------------------------------------------------
// 便签画笔（底图 + 复选框 + 手绘底线 + 文字，viewBox 300×H 坐标系）
// ---------------------------------------------------------------------------

class _CuteNotepadPainter extends CustomPainter {
  final CuteNotepadVariant variant;
  final _NoteLayout layout;

  _CuteNotepadPainter({required this.variant, required this.layout});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _kViewBoxWidth);
    final h = layout.height;

    _paintBackground(canvas, h);
    _paintItems(canvas);
    _paintTexts(canvas);

    canvas.restore();
  }

  // ---- 底图 ----

  void _paintBackground(Canvas canvas, double h) {
    switch (variant.background) {
      case CuteNotepadBackground.gridPaper:
        _paper(canvas, h, radius: 6, stroke: true);
        _grid(
          canvas,
          rect: Rect.fromLTRB(14, 14, 280, h - 20),
          step: variant.gridStep,
        );
      case CuteNotepadBackground.wavyInner:
        _paper(canvas, h, radius: 8, stroke: true);
        _fillPath(
          canvas,
          _wavyRectPath(22, 24, 272, h - 30, 3),
          variant.innerFillColor,
        );
      case CuteNotepadBackground.plain:
        _paper(canvas, h, radius: 6, stroke: true);
      case CuteNotepadBackground.innerRoundFrame:
        _paper(canvas, h, radius: 8, stroke: false);
        _innerRoundRect(canvas, h);
      case CuteNotepadBackground.waveTopHeader:
        _paper(canvas, h, radius: 6, stroke: true);
        _waveTopHeader(canvas);
      case CuteNotepadBackground.leftBinderHoles:
        _paper(canvas, h, radius: 5, stroke: true);
        for (double cy = 42; cy <= h - 36; cy += 36) {
          _leftHole(canvas, cy);
        }
      case CuteNotepadBackground.plaidInnerRound:
        _paper(canvas, h, radius: 6, stroke: false);
        _plaid(canvas, Rect.fromLTRB(6, 6, 288, h - 12), variant.plaidStep);
        _strokeRect(canvas, Rect.fromLTRB(6, 6, 288, h - 12), 6,
            variant.paperStroke, 1.5);
        _fillRRect(
          canvas,
          RRect.fromRectAndRadius(
            Rect.fromLTRB(22, 22, 272, h - 28),
            const Radius.circular(28),
          ),
          variant.innerFillColor,
        );
      case CuteNotepadBackground.gridBanner:
        _paper(canvas, h, radius: 6, stroke: true);
        _grid(canvas, rect: Rect.fromLTRB(12, 12, 282, h - 18),
            step: variant.gridStep);
        _banner(canvas);
      case CuteNotepadBackground.tornEdge:
        final path = _tornEdgePath(h);
        _fillPath(canvas, path.shift(const Offset(4, 4)), variant.shadowColor);
        _fillPath(canvas, path, variant.paperColor);
        _strokePath(canvas, path, variant.paperStroke, 1.5);
      case CuteNotepadBackground.doubleWavyFrame:
        _paper(canvas, h, radius: 6, stroke: true);
        _strokePath(
          canvas,
          _wavyRectPath(21, 21, 273, h - 27, 3),
          variant.innerStrokeColor,
          2.2,
        );
        _strokePath(
          canvas,
          _wavyRectPath(24, 24, 270, h - 30, 2),
          variant.innerStroke2Color,
          1.2,
        );
      case CuteNotepadBackground.rightWaveEdge:
        final path = _rightWaveEdgePath(h);
        _fillPath(canvas, path.shift(const Offset(4, 4)), variant.shadowColor);
        _fillPath(canvas, path, variant.paperColor);
        _strokePath(canvas, path, variant.paperStroke, 1.5);
      case CuteNotepadBackground.plaidCloudFrame:
        _paper(canvas, h, radius: 6, stroke: false);
        _plaid(canvas, Rect.fromLTRB(6, 6, 288, h - 12), variant.plaidStep);
        _strokeRect(canvas, Rect.fromLTRB(6, 6, 288, h - 12), 6,
            variant.paperStroke, 1.5);
        _fillPath(canvas, _cloudFramePath(h), variant.innerFillColor);
        _strokePath(
          canvas,
          _cloudFramePath(h),
          variant.innerStrokeColor,
          2.2,
        );
      case CuteNotepadBackground.wavyFrame:
        _paper(canvas, h, radius: 6, stroke: true);
        _strokePath(
          canvas,
          _wavyRectPath(22, 22, 272, h - 28, 3),
          variant.innerStrokeColor,
          2.4,
        );
      case CuteNotepadBackground.topBinderHoles:
        _paper(canvas, h, radius: 5, stroke: true);
        for (var i = 0; i < 7; i++) {
          _topHole(canvas, 36.0 + i * 37);
        }
    }
  }

  /// 纸面：边影层 + 主纸面（纸面 y 偏移随风格有 6/10/12 三档）
  void _paper(Canvas canvas, double h,
      {required double radius, required bool stroke}) {
    final paperTop = variant.paperTop;
    final paperBottom = paperTop <= 6 ? h - 12 : h - 14;

    _fillRRect(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromLTRB(10, paperTop + 4, 292, paperBottom + 4),
        Radius.circular(radius),
      ),
      variant.shadowColor,
    );
    _fillRRect(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromLTRB(6, paperTop, 288, paperBottom),
        Radius.circular(radius),
      ),
      variant.paperColor,
    );
    if (stroke && variant.paperStroke != null) {
      _strokeRRect(
        canvas,
        RRect.fromRectAndRadius(
          Rect.fromLTRB(6, paperTop, 288, paperBottom),
          Radius.circular(radius),
        ),
        variant.paperStroke,
        1.5,
      );
    }
  }

  /// 内嵌圆角框（04/14 号便签，两款的内框 y 略有差异）
  void _innerRoundRect(Canvas canvas, double h) {
    final low = variant.paperTop > 6;
    final rect = low
        ? Rect.fromLTRB(18, 22, 276, h - 26)
        : Rect.fromLTRB(18, 18, 276, h - 24);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    _fillRRect(canvas, rrect, variant.innerFillColor);
    _strokeRRect(canvas, rrect, variant.innerStrokeColor, 2.4);
  }

  /// 方格纸
  void _grid(Canvas canvas, {required Rect rect, required double step}) {
    final color = variant.gridColor;
    if (color == null) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var x = rect.left; x <= rect.right + 0.1; x += step) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    for (var y = rect.top; y <= rect.bottom + 0.1; y += step) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  /// 格纹纸（纵横半宽色带，叠色与网页版 pattern 一致）
  void _plaid(Canvas canvas, Rect rect, double step) {
    final band = variant.plaidBandColor;
    if (band == null) return;
    final paint = Paint()..color = band.withOpacity(0.55);
    for (var x = rect.left; x < rect.right; x += step) {
      canvas.drawRect(
        Rect.fromLTRB(x, rect.top, math.min(x + step / 2, rect.right),
            rect.bottom),
        paint,
      );
    }
    for (var y = rect.top; y < rect.bottom; y += step) {
      canvas.drawRect(
        Rect.fromLTRB(rect.left, y, rect.right,
            math.min(y + step / 2, rect.bottom)),
        paint,
      );
    }
  }

  /// 波浪顶栏 + 装饰短线（05 号便签）
  void _waveTopHeader(Canvas canvas) {
    final path = Path()
      ..moveTo(6, 12)
      ..quadraticBezierTo(6, 6, 12, 6)
      ..lineTo(282, 6)
      ..quadraticBezierTo(288, 6, 288, 12)
      ..lineTo(288, 32)
      ..quadraticBezierTo(265, 14, 242, 32)
      ..quadraticBezierTo(218, 14, 195, 32)
      ..quadraticBezierTo(172, 14, 148, 32)
      ..quadraticBezierTo(124, 14, 100, 32)
      ..quadraticBezierTo(76, 14, 52, 32)
      ..quadraticBezierTo(28, 14, 6, 32)
      ..close();
    _fillPath(canvas, path, variant.waveHeaderColor);
    _strokePath(canvas, path, variant.waveHeaderStroke, 1.8);

    final paint = Paint()
      ..color = variant.textColor
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(94, 42), const Offset(100, 38), paint);
    canvas.drawLine(const Offset(97, 50), const Offset(105, 49), paint);
    canvas.drawLine(const Offset(95, 58), const Offset(102, 61), paint);
  }

  /// 标题横幅（08 号便签）
  void _banner(Canvas canvas) {
    final path = Path()
      ..moveTo(56, 20)
      ..quadraticBezierTo(148, 18, 238, 20)
      ..quadraticBezierTo(242, 33, 238, 46)
      ..quadraticBezierTo(148, 48, 56, 46)
      ..quadraticBezierTo(53, 33, 56, 20)
      ..close();
    _fillPath(canvas, path, variant.bannerFillColor);
    _strokePath(canvas, path, variant.bannerStrokeColor, 2);
  }

  /// 左侧活页孔（06 号便签）
  void _leftHole(Canvas canvas, double cy) {
    _fillRect(canvas, Rect.fromLTRB(6, cy - 3.5, 20, cy + 3.5),
        variant.holeBgColor);
    canvas.drawCircle(
      Offset(23, cy),
      6.5,
      Paint()..color = variant.holeBgColor ?? Colors.white,
    );
    canvas.drawCircle(
      Offset(23, cy),
      6.5,
      Paint()
        ..color = variant.holeStrokeColor ?? Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// 顶部活页孔（16 号便签）
  void _topHole(Canvas canvas, double cx) {
    _fillRect(canvas, Rect.fromLTRB(cx - 3.5, 12, cx + 3.5, 26),
        variant.holeBgColor);
    canvas.drawCircle(
      Offset(cx, 28),
      6.2,
      Paint()..color = variant.holeBgColor ?? Colors.white,
    );
    canvas.drawCircle(
      Offset(cx, 28),
      6.2,
      Paint()
        ..color = variant.holeStrokeColor ?? Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ---- 待办行（复选框 + 手绘底线） ----

  void _paintItems(Canvas canvas) {
    final linePaint = Paint()
      ..color = variant.lineColor
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final lineX1 = layout.hasCheck ? 62.0 : (variant.lineX1 ?? 36.0);
    final lineX2 = variant.lineX2 ?? 252.0;

    for (final il in layout.itemLayouts) {
      // 手绘底线
      for (final uy in il.underlineYs) {
        canvas.drawLine(Offset(lineX1, uy), Offset(lineX2, uy), linePaint);
      }
      // 复选框
      if (layout.hasCheck) {
        _drawCheckbox(canvas, il.checked, il.underlineYs.first);
      }
    }
  }

  /// 复选框（box / heart / star / circle 四种手绘样式）
  void _drawCheckbox(Canvas canvas, bool checked, double y) {
    switch (variant.checkStyle) {
      case CuteNotepadCheckStyle.box:
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(33, y - 13, 49, y + 3),
          const Radius.circular(3.5),
        );
        _fillRRect(canvas, rrect,
            checked ? const Color(0xFFFFD84D) : const Color(0xFFFFFBE8));
        _strokeRRect(canvas, rrect, const Color(0xFF7A5C43), 2.2);
        if (checked) {
          _checkMark(canvas, 36, y - 5, 40, y - 1, 46, y - 9,
              const Color(0xFF5E4227), 2.6);
        }
      case CuteNotepadCheckStyle.heart:
        final path = Path()
          ..moveTo(41, y - 9)
          ..cubicTo(41, y - 15, 32, y - 16, 32, y - 8)
          ..cubicTo(32, y - 2, 41, y + 3, 41, y + 6)
          ..cubicTo(41, y + 3, 50, y - 2, 50, y - 8)
          ..cubicTo(50, y - 16, 41, y - 15, 41, y - 9)
          ..close();
        _fillPath(canvas, path,
            checked ? const Color(0xFF68A83C) : const Color(0xFFA8D170));
        _strokePath(canvas, path, const Color(0xFF486B2B), 2);
        if (checked) {
          _checkMark(
              canvas, 37, y - 5, 40, y - 2, 46, y - 8, Colors.white, 2.2);
        }
      case CuteNotepadCheckStyle.star:
        final path = Path()
          ..moveTo(40, y - 16)
          ..lineTo(43, y - 10)
          ..lineTo(50, y - 9)
          ..lineTo(45, y - 4)
          ..lineTo(46, y + 3)
          ..lineTo(40, y - 1)
          ..lineTo(34, y + 3)
          ..lineTo(35, y - 4)
          ..lineTo(30, y - 9)
          ..lineTo(37, y - 10)
          ..close();
        _fillPath(canvas, path,
            checked ? const Color(0xFF5B8F3D) : const Color(0xFF94C476));
        _strokePath(canvas, path, const Color(0xFF466B30), 1.8);
        if (checked) {
          canvas.drawCircle(
            Offset(40, y - 6),
            2.8,
            Paint()..color = Colors.white,
          );
        }
      case CuteNotepadCheckStyle.circle:
        final center = Offset(41, y - 5);
        final fill = Paint()
          ..color = checked
              ? const Color(0xFFF5C242)
              : const Color(0xFFFFFBE8);
        canvas.drawCircle(center, 8, fill);
        canvas.drawCircle(
          center,
          8,
          Paint()
            ..color = const Color(0xFFDEB249)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
        if (checked) {
          _checkMark(canvas, 37, y - 5, 40, y - 2, 46, y - 8,
              const Color(0xFF6B4922), 2.4);
        }
    }
  }

  void _checkMark(Canvas canvas, double x1, double y1, double x2, double y2,
      double x3, double y3, Color color, double width) {
    final path = Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2)
      ..lineTo(x3, y3);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  // ---- 文字 ----

  void _paintTexts(Canvas canvas) {
    // 标题（可带旋转）
    final titlePainter = layout.titlePainter;
    if (titlePainter != null) {
      canvas.save();
      if (layout.titleRotateRad != 0) {
        canvas.translate(
          layout.titleRotateOrigin.dx,
          layout.titleRotateOrigin.dy,
        );
        canvas.rotate(layout.titleRotateRad);
        canvas.translate(
          -layout.titleRotateOrigin.dx,
          -layout.titleRotateOrigin.dy,
        );
      }
      titlePainter.paint(canvas, layout.titleOffset);
      canvas.restore();
    }

    // 自由文本
    final freeformLines = layout.freeformLines;
    if (freeformLines != null) {
      // markdown 复选框 → 手绘待办行（与整块文本互斥）
      final todoLineX2 =
          variant.freeformLeft + variant.freeformWidth - 2;
      final linePaint = Paint()
        ..color = variant.lineColor
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final line in freeformLines) {
        if (line.isTodo) {
          for (final uy in line.underlineYs) {
            canvas.drawLine(
              Offset(62, uy),
              Offset(todoLineX2, uy),
              linePaint,
            );
          }
          if (layout.hasCheck) {
            _drawCheckbox(canvas, line.checked, line.underlineYs.first);
          }
          line.todoPainter?.paint(canvas, Offset(64, line.top + 3));
        } else {
          line.painter?.paint(
            canvas,
            Offset(variant.freeformLeft + 2, line.top),
          );
        }
      }
    } else {
      layout.freeformPainter?.paint(canvas, layout.freeformOffset);
    }

    // 待办/横线行文本
    for (final il in layout.itemLayouts) {
      il.painter?.paint(canvas, Offset(il.textLeft + 3, il.top + 3));
    }
  }

  // ---- 基础绘制辅助 ----

  void _fillRRect(Canvas canvas, RRect rrect, Color? color) {
    if (color == null) return;
    canvas.drawRRect(rrect, Paint()..color = color);
  }

  void _strokeRRect(Canvas canvas, RRect rrect, Color? color, double width) {
    if (color == null) return;
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  void _fillRect(Canvas canvas, Rect rect, Color? color) {
    if (color == null) return;
    canvas.drawRect(rect, Paint()..color = color);
  }

  void _strokeRect(Canvas canvas, Rect rect, double radius, Color? color,
      double width) {
    if (color == null) return;
    _strokeRRect(
      canvas,
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      color,
      width,
    );
  }

  void _fillPath(Canvas canvas, Path path, Color? color) {
    if (color == null) return;
    canvas.drawPath(path, Paint()..color = color);
  }

  void _strokePath(Canvas canvas, Path path, Color? color, double width) {
    if (color == null) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant _CuteNotepadPainter oldDelegate) {
    return oldDelegate.variant != variant ||
        oldDelegate.layout.height != layout.height ||
        oldDelegate.layout != layout;
  }
}

// ---------------------------------------------------------------------------
// 手绘路径生成器（移植网页版 buildWavyRectPath / buildCloudFramePath 等）
// ---------------------------------------------------------------------------

/// 波浪边矩形（Q + T 平滑二次曲线，四边随 H 无缝延展）
Path _wavyRectPath(double x1, double y1, double x2, double y2,
    [double amp = 2.5]) {
  final midX = (x1 + x2) / 2;
  final midY = (y1 + y2) / 2;
  final path = Path()..moveTo(x1, y1);

  var current = Offset(x1, y1);
  Offset prevCtrl = Offset.zero;
  var hasCtrl = false;

  void quad(Offset ctrl, Offset end) {
    path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    prevCtrl = ctrl;
    current = end;
    hasCtrl = true;
  }

  void smooth(Offset end) {
    final ctrl = hasCtrl
        ? Offset(2 * current.dx - prevCtrl.dx, 2 * current.dy - prevCtrl.dy)
        : current;
    quad(ctrl, end);
  }

  quad(Offset((x1 + midX) / 2, y1 - amp), Offset(midX, y1));
  smooth(Offset(x2, y1));
  quad(Offset(x2 + amp, (y1 + midY) / 2), Offset(x2, midY));
  smooth(Offset(x2, y2));
  quad(Offset((x2 + midX) / 2, y2 + amp), Offset(midX, y2));
  smooth(Offset(x1, y2));
  quad(Offset(x1 - amp, (y2 + midY) / 2), Offset(x1, midY));
  smooth(Offset(x1, y1));

  return path..close();
}

/// 云朵波浪内框（13 号便签，随 H 增加侧边波浪弧度）
Path _cloudFramePath(double h) {
  const topY = 36.0, leftX = 34.0, rightX = 258.0;
  final botY = h - 42;
  final path = Path()..moveTo(leftX, topY);
  path.quadraticBezierTo(75, 22, 115, 32);
  path.quadraticBezierTo(150, 20, 185, 32);
  path.quadraticBezierTo(225, 22, rightX, topY);

  final sideSpan = math.max(72.0, botY - topY);
  final steps = math.max(3, (sideSpan / 70).round());
  final stepH = sideSpan / steps;
  for (var i = 0; i < steps; i++) {
    final yMid = topY + (i + 0.5) * stepH;
    final yNext = (topY + (i + 1) * stepH).roundToDouble();
    final bulge = i % 2 == 0 ? rightX + 14 : rightX + 12;
    path.quadraticBezierTo(bulge, yMid, rightX + (i % 2 == 0 ? 4 : 0), yNext);
  }

  path.quadraticBezierTo(220, botY + 14, 182, botY + 4);
  path.quadraticBezierTo(148, botY + 16, 112, botY + 4);
  path.quadraticBezierTo(72, botY + 14, leftX, botY);

  for (var i = steps - 1; i >= 0; i--) {
    final yMid = topY + (i + 0.5) * stepH;
    final yPrev = (topY + i * stepH).roundToDouble();
    final bulge = i % 2 == 0 ? leftX - 12 : leftX - 14;
    path.quadraticBezierTo(bulge, yMid, leftX - (i % 2 == 0 ? 0 : 2), yPrev);
  }

  return path..close();
}

/// 撕边锯齿纸（09 号便签）
Path _tornEdgePath(double h) {
  final path = Path()..moveTo(6, 24);
  for (var x = 6.0; x < 288; x += 8) {
    path.lineTo(x + 4, 19);
    path.lineTo(x + 8, 24);
  }
  path.lineTo(288, h - 14);
  path.quadraticBezierTo(288, h - 10, 284, h - 10);
  path.lineTo(10, h - 10);
  path.quadraticBezierTo(6, h - 10, 6, h - 14);
  return path..close();
}

/// 右侧波浪边纸（12 号便签）
Path _rightWaveEdgePath(double h) {
  final path = Path()
    ..moveTo(10, 10)
    ..lineTo(280, 10);
  for (var y = 10.0; y < h - 18; y += 16) {
    path.quadraticBezierTo(288, y + 4, 282, y + 8);
    path.quadraticBezierTo(276, y + 12, 282, y + 16);
  }
  path.lineTo(10, h - 10);
  path.quadraticBezierTo(6, h - 10, 6, h - 16);
  path.lineTo(6, 14);
  path.quadraticBezierTo(6, 10, 10, 10);
  return path..close();
}

/// 上报子树尺寸变化（contentWidget 高度测量，用于撑开画布）
class _SizeReporter extends SingleChildRenderObjectWidget {
  final void Function(Size size) onSizeChanged;

  const _SizeReporter({required this.onSizeChanged, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSizeReporter(onSizeChanged);
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  final void Function(Size size) onSizeChanged;
  Size? _lastReported;

  _RenderSizeReporter(this.onSizeChanged);

  @override
  void performLayout() {
    super.performLayout();
    if (_lastReported == size) return;
    _lastReported = size;
    // 布局期间不可 setState，延迟到帧末上报
    WidgetsBinding.instance.addPostFrameCallback((_) => onSizeChanged(size));
  }
}
