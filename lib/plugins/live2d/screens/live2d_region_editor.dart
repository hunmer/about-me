import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:live2d_flutter/live2d_flutter.dart';

import 'live2d_hit_area_editor.dart';

part 'live2d_region_painter.dart';

/// 预览交互模式：选择/移动、绘制矩形、点击测试台词
enum _InteractionMode { select, draw, test }

/// 区域列表的行尾统计文案
String _regionSummary(List<Live2DTapRegion> regions) {
  final modelCount = regions.where((r) => r.source == 'model').length;
  final customCount = regions.where((r) => r.source == 'custom').length;
  final messageCount = regions.fold<int>(
    0,
    (sum, region) => sum + region.effectiveMessages.length,
  );
  return live2dRegionText(
    '模型部位 $modelCount · 自定义 $customCount · 台词 $messageCount 条',
    'Model $modelCount · Custom $customCount · $messageCount messages',
  );
}

/// 绘制模式的草稿矩形状态机：pointer-down 锁定原点，move 只更新终点，
/// up 时按最小边阈值决定提交或丢弃。
///
/// 原点固定是关键——绝不能从上一帧草稿反推起点（草稿中点会随指针
/// 漂移，触摸板慢速拖动时矩形会塌缩成一个点）。纯逻辑、无 UI 依赖，
/// 由 test/live2d_region_drawing_test.dart 回归覆盖。
class Live2DDraftSession {
  Live2DDraftSession({required this.pointer, required this.start});

  /// 触发本次绘制的指针 id（日志排查多指串扰用）
  final int pointer;

  /// pointer-down 时锁定的归一化原点，直到 up/cancel 前不变
  final Offset start;

  Offset? _current;

  /// 当前草稿矩形：固定原点与最近一次终点的归一化包围盒
  Rect? get draft =>
      _current == null ? null : Rect.fromPoints(start, _current!);

  /// move 只更新终点，原点保持 pointer-down 时的位置
  void move(Offset current) => _current = current;

  /// up 时结算：任一边小于 [minEdge] 视为误触，返回 null 丢弃
  Rect? commit({double minEdge = 0.02}) {
    final rect = draft;
    if (rect == null) return null;
    if (rect.width < minEdge || rect.height < minEdge) return null;
    return rect;
  }
}

/// 点击区域与逐区域台词编辑器：
/// 上半区实时模型预览（视口纵横比与运行时一致，归一化坐标直接对齐），
/// 交互分三态——选择（点选/拖动移动）、绘制（拖拽画自定义矩形）、
/// 测试（点击穿透到原生 HitArea 判定，命中草稿区域随机弹出台词）；
/// 下半区列出模型自带 HitAreas 与自定义区域，可编辑名称、边界数值
/// 与多条台词（每行一条随机挑选）。
class Live2DRegionEditorScreen extends StatefulWidget {
  const Live2DRegionEditorScreen({
    super.key,
    required this.archive,
    this.initialRegions = const [],
    this.onChanged,
  });

  final Live2DArchive archive;
  final List<Live2DTapRegion> initialRegions;

  /// 每次区域变化都会回调（编辑过程实时同步给表单草稿）
  final ValueChanged<List<Live2DTapRegion>>? onChanged;

  @override
  State<Live2DRegionEditorScreen> createState() =>
      _Live2DRegionEditorScreenState();
}

class _Live2DRegionEditorScreenState extends State<Live2DRegionEditorScreen> {
  static const double _viewportAspectRatio = 0.5;
  static const double _minRegionEdge = 0.02;

  /// 调试日志总开关：定位指针/绘制链路问题用，稳定后置 false 即全量静音
  static const bool _regionEditorDebugLogs = true;

  late List<Live2DTapRegion> _regions;
  String? _selectedId;
  List<Live2DModelHitArea> _hitAreas = const [];
  Live2DViewController? _previewController;
  bool _hitOverlayVisible = false;
  _InteractionMode _mode = _InteractionMode.select;

  /// 已同步到原生视图的交互模式；原生视图重建（detached）后置回 null 强制重新应用
  _InteractionMode? _interactiveMode;

  /// setInteractive 在途标志：防止状态通知风暴下的并发调用交错
  bool _interactiveSyncing = false;

  /// 失败日志只打一次：避免 iOS/Android 每次状态变化都刷「未实现」错误
  bool _interactiveErrorLogged = false;

  /// 上次通知时的原生视图挂载状态：只在变化时打日志
  bool _wasAttached = false;

  /// 高频 move 回调的日志抽样计数
  int _panUpdateLogTick = 0;
  final math.Random _random = math.Random();
  Rect? _draftRect;

  /// 绘制会话：pointer-down 锁定原点，move 只更新终点（修复起点漂移）
  Live2DDraftSession? _draftSession;

  /// 最近一次按下的原始指针 id（Listener 捕获，日志/会话关联用）
  int? _activePointerId;
  Rect? _moveStartBounds;
  Offset? _moveStartPos;
  double _toolsHeight = 320;

  /// 统一调试输出：前缀过滤方便日志面板检索
  void _debugLog(String message) {
    if (_regionEditorDebugLogs) {
      debugPrint('[Live2DRegionEditor] $message');
    }
  }

  /// 矩形调试格式：归一化坐标保留 3 位小数
  String _rectDebug(Rect? rect) => rect == null
      ? '无'
      : '(${rect.left.toStringAsFixed(3)},${rect.top.toStringAsFixed(3)},'
            '${rect.right.toStringAsFixed(3)},${rect.bottom.toStringAsFixed(3)})';

  final _nameController = TextEditingController();
  final _messagesController = TextEditingController();
  final _boundControllers = List.generate(4, (_) => TextEditingController());
  static const _boundLabels = ['left', 'top', 'right', 'bottom'];

  Live2DTapRegion? get _selected =>
      _regions.where((region) => region.id == _selectedId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _regions = List.of(widget.initialRegions);
  }

  @override
  void dispose() {
    _previewController?.removeListener(_onPreviewStateChanged);
    _nameController.dispose();
    _messagesController.dispose();
    for (final controller in _boundControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _notify() => widget.onChanged?.call(List.of(_regions));

  void _mutate(List<Live2DTapRegion> Function(List<Live2DTapRegion>) update) {
    setState(() => _regions = update(_regions));
    if (_selected == null) _selectedId = null;
    _notify();
  }

  List<Live2DTapRegion> _replaceSelected(Live2DTapRegion updated) {
    return _regions
        .map((region) => region.id == updated.id ? updated : region)
        .toList();
  }

  /// 选中区域并回填编辑控件
  void _select(String? id) {
    setState(() => _selectedId = id);
    final region = _selected;
    _nameController.text = region?.name ?? '';
    _messagesController.text = (region?.messages ?? const []).join('\n');
    final bounds = [region?.left, region?.top, region?.right, region?.bottom];
    for (var i = 0; i < _boundControllers.length; i++) {
      _boundControllers[i].text = bounds[i]?.toStringAsFixed(3) ?? '';
    }
  }

  void _onNameChanged(String value) {
    final region = _selected;
    if (region == null) return;
    _mutate(
      (regions) => _replaceSelected(
        Live2DTapRegion(
          id: region.id,
          name: value,
          source: region.source,
          left: region.left,
          top: region.top,
          right: region.right,
          bottom: region.bottom,
          messages: region.messages,
        ),
      ),
    );
  }

  void _onMessagesChanged(String value) {
    final region = _selected;
    if (region == null) return;
    _mutate(
      (regions) => _replaceSelected(
        Live2DTapRegion(
          id: region.id,
          name: region.name,
          source: region.source,
          left: region.left,
          top: region.top,
          right: region.right,
          bottom: region.bottom,
          messages: value.split('\n'),
        ),
      ),
    );
  }

  void _onBoundChanged(int index, double value) {
    final region = _selected;
    if (region == null || region.source != 'custom') return;
    final bounds = [
      region.left ?? 0,
      region.top ?? 0,
      region.right ?? 0,
      region.bottom ?? 0,
    ]..[index] = value;
    _mutate(
      (regions) => _replaceSelected(
        Live2DTapRegion(
          id: region.id,
          name: region.name,
          source: region.source,
          left: bounds[0],
          top: bounds[1],
          right: bounds[2],
          bottom: bounds[3],
          messages: region.messages,
        ),
      ),
    );
  }

  void _deleteSelected() {
    final region = _selected;
    if (region == null) return;
    _mutate((regions) => regions.where((r) => r.id != region.id).toList());
    _select(null);
  }

  /// 从模型自带 HitAreas 添加区域（id 用原生 HitArea id 保证命中匹配）
  Future<void> _addModelRegion() async {
    final existing = _regions
        .where((region) => region.source == 'model')
        .map((region) => region.id)
        .toSet();
    final available = _hitAreas
        .where((area) => !existing.contains(area.id))
        .toList();
    if (!mounted) return;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _hitAreas.isEmpty
                ? live2dRegionText(
                    '模型未声明 HitAreas（model3.json），请使用自定义矩形',
                    'This model declares no HitAreas; use custom rects',
                  )
                : live2dRegionText('所有模型部位都已添加', 'All hit areas added'),
          ),
        ),
      );
      return;
    }
    final area = await showLive2DHitAreaPickerSheet(
      context,
      available: available,
    );
    if (area == null) return;
    final name = area.name.trim().isNotEmpty
        ? area.name.trim()
        : area.rawDisplayName;
    final region = Live2DTapRegion(
      id: area.id,
      name: name,
      source: 'model',
      messages: const [],
    );
    _mutate((regions) => [...regions, region]);
    _select(region.id);
  }

  /// 提交拖拽画出的草稿矩形为自定义区域
  void _commitDraft(Rect draft) {
    final normalized = Rect.fromLTWH(
      draft.left,
      draft.top,
      draft.width,
      draft.height,
    );
    if (normalized.width < _minRegionEdge ||
        normalized.height < _minRegionEdge) {
      _debugLog(
        '草稿过小已丢弃 w=${normalized.width.toStringAsFixed(3)} h=${normalized.height.toStringAsFixed(3)}',
      );
      setState(() => _draftRect = null);
      return;
    }
    final index =
        _regions.where((region) => region.source == 'custom').length + 1;
    final region = Live2DTapRegion(
      id: const Uuid().v4(),
      name: live2dRegionText('区域 $index', 'Region $index'),
      source: 'custom',
      left: normalized.left.clamp(0.0, 1.0),
      top: normalized.top.clamp(0.0, 1.0),
      right: normalized.right.clamp(0.0, 1.0),
      bottom: normalized.bottom.clamp(0.0, 1.0),
      messages: const [],
    );
    _debugLog('提交草稿 → 区域 ${region.id} ${_rectDebug(normalized)}');
    _mutate((regions) => [...regions, region]);
    setState(() => _draftRect = null);
    _select(region.id);
  }

  /// 预览模型加载成功后读取模型自带 HitAreas
  Future<void> _onModelLoaded(Live2DModelDefinition localModel) async {
    try {
      final areas = await readModelHitAreas(localModel);
      if (!mounted) return;
      setState(() => _hitAreas = areas);
    } catch (_) {
      // HitAreas 解析失败不阻塞编辑，仍可添加自定义矩形
      if (mounted) setState(() => _hitAreas = const []);
    }
    _syncInteractive();
  }

  /// 切换交互模式：清空进行中的草稿/拖动状态并同步原生视图交互开关
  void _setMode(_InteractionMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _draftRect = null;
      _draftSession = null;
      _moveStartBounds = null;
      _moveStartPos = null;
    });
    _debugLog(
      '切换模式 → $mode（${mode == _InteractionMode.draw ? "黑色蒙层开" : "黑色蒙层关"}）',
    );
    _syncInteractive();
  }

  /// macOS 的 Live2D 预览是真实 NSView（WKWebView），AppKit 会在 Flutter
  /// 手势竞技场之前把鼠标事件派发给原生视图——选择/绘制模式下前景
  /// GestureDetector 永远收不到指针，拖拽画不出矩形。这里调用
  /// setInteractive(false) 让原生视图退出命中测试，事件落回 Flutter
  /// 手势层；测试模式恢复 true，原生才能判定 HitArea 并回调 onTap。
  /// 其余平台命中测试本就由手势竞技场裁决（原生 recognizer 集为空，
  /// 无人认领时才派发给平台视图），未实现该命令时忽略即可。
  ///
  /// 可靠性：成功之后才记录 [_interactiveMode]；失败置回 null，
  /// 下一次状态通知/_setMode/_onModelLoaded 都会重试——避免一次
  /// 瞬时失败（如模型加载中视图忙）导致交互开关永久卡在错误状态。
  Future<void> _syncInteractive() async {
    final controller = _previewController;
    if (controller == null || _interactiveSyncing) return;
    if (!controller.value.isAttached) return;
    if (_interactiveMode == _mode) return;
    _interactiveSyncing = true;
    final target = _mode == _InteractionMode.test;
    try {
      await controller.setInteractive(target);
      _interactiveMode = _mode;
      _interactiveErrorLogged = false;
      _debugLog('setInteractive($target) 成功，模式=$_mode');
    } catch (error) {
      // 失败不记录模式：保持 null 让后续触发点重试
      _interactiveMode = null;
      if (!_interactiveErrorLogged) {
        _interactiveErrorLogged = true;
        _debugLog('setInteractive($target) 失败: $error（将在下次触发时重试）');
      }
    } finally {
      _interactiveSyncing = false;
    }
  }

  /// 预览控制器状态变化：原生视图重建后恢复默认（interactive），
  /// 需清记录并在重新挂载时按当前模式重新关闭交互
  void _onPreviewStateChanged() {
    final controller = _previewController;
    if (controller == null) return;
    final attached = controller.value.isAttached;
    if (_wasAttached != attached) {
      _wasAttached = attached;
      _debugLog('预览原生视图 ${attached ? "attached" : "detached"}');
    }
    if (!attached) {
      _interactiveMode = null;
      return;
    }
    _syncInteractive();
  }

  Future<void> _toggleHitOverlay() async {
    final controller = _previewController;
    if (controller == null) return;
    final next = !_hitOverlayVisible;
    try {
      await controller.setHitAreasVisible(next);
      if (mounted) setState(() => _hitOverlayVisible = next);
    } on Live2DException {
      // 平台不支持调试叠加时静默忽略（与 jelly_live2d 一致）
    } catch (_) {}
  }

  Offset _toNormalized(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  /// 草稿区域内按 HitArea id/name 匹配模型区
  /// （与运行时 Live2DArchive.tapRegionForHitArea 同语义，但作用于未保存草稿）
  Live2DTapRegion? _regionForHitArea(String? hitAreaId, String? hitAreaName) {
    final id = hitAreaId?.trim().toLowerCase();
    final name = hitAreaName?.trim().toLowerCase();
    if ((id == null || id.isEmpty) && (name == null || name.isEmpty)) {
      return null;
    }
    for (final region in _regions) {
      if (region.source != 'model') continue;
      if (id != null && id.isNotEmpty && region.id.toLowerCase() == id) {
        return region;
      }
      if (name != null &&
          name.isNotEmpty &&
          region.name.trim().toLowerCase() == name) {
        return region;
      }
    }
    return null;
  }

  /// 测试模式：原生 Live2DView 点击回调（x/y 为 view coords -1..1，y 轴上正）
  /// 命中顺序与运行时一致：先自定义矩形（归一化包含判定），再模型 HitArea id/name
  void _handleTestHit(
    String? hitAreaId,
    String? hitAreaName,
    double x,
    double y,
  ) {
    if (!mounted || _mode != _InteractionMode.test) return;
    final nx = ((x + 1) / 2).clamp(0.0, 1.0);
    final ny = ((1 - y) / 2).clamp(0.0, 1.0);
    _debugLog(
      '原生 onTap id=$hitAreaId name=$hitAreaName '
      '→ ($nx, $ny)',
    );
    final region =
        _regionAt(Offset(nx, ny)) ?? _regionForHitArea(hitAreaId, hitAreaName);
    if (region == null) {
      _showTestToast(
        live2dRegionText(
          '未命中区域（HitArea: ${hitAreaId ?? hitAreaName ?? '无'}）',
          'No region hit (HitArea: ${hitAreaId ?? hitAreaName ?? 'none'})',
        ),
      );
      return;
    }
    final messages = region.effectiveMessages;
    if (messages.isEmpty) {
      _showTestToast(
        live2dRegionText(
          '命中「${region.name}」，尚未配置台词',
          'Hit "${region.name}" has no messages yet',
        ),
      );
      return;
    }
    _showTestToast(
      '${region.name}：${messages[_random.nextInt(messages.length)]}',
    );
  }

  void _showTestToast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Live2DTapRegion? _regionAt(Offset normalized) => _regions
      .where(
        (region) =>
            region.containsNormalizedPoint(normalized.dx, normalized.dy),
      )
      .firstOrNull;

  Widget _buildForeground(Size size) {
    // 测试模式不挂手势层：点击直达原生 Live2DView，由 onTap 回调判定 HitArea
    if (_mode == _InteractionMode.test) return const SizedBox.shrink();
    final drawMode = _mode == _InteractionMode.draw;
    // Listener 捕获原始指针 id（DragStartDetails 无 pointer 字段），供会话/日志关联
    return Listener(
      onPointerDown: (event) => _activePointerId = event.pointer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          if (drawMode) return;
          final pos = _toNormalized(details.localPosition, size);
          final hit = _regionAt(pos);
          _debugLog(
            'pointer#$_activePointerId tap '
            '(${pos.dx.toStringAsFixed(3)},'
            '${pos.dy.toStringAsFixed(3)}) 命中=${hit?.id ?? "无"}',
          );
          _select(hit?.id);
        },
        onPanStart: (details) {
          final pos = _toNormalized(details.localPosition, size);
          if (drawMode) {
            // 锁定原点直到本次 pointer up/cancel：绝不由后续 move 反推
            _draftSession = Live2DDraftSession(
              pointer: _activePointerId ?? -1,
              start: pos,
            );
            setState(() => _draftRect = null);
            _debugLog(
              'pointer#$_activePointerId down '
              '(${pos.dx.toStringAsFixed(3)},${pos.dy.toStringAsFixed(3)}) '
              '模式=$_mode 原点已锁定',
            );
            return;
          }
          _debugLog(
            'pointer#$_activePointerId down '
            '(${pos.dx.toStringAsFixed(3)},${pos.dy.toStringAsFixed(3)}) '
            '模式=$_mode',
          );
          final hit = _regionAt(pos);
          if (hit == null) return;
          if (hit.id != _selectedId) _select(hit.id);
          if (hit.source == 'custom' && hit.hasBounds) {
            _moveStartBounds = Rect.fromLTRB(
              hit.left!,
              hit.top!,
              hit.right!,
              hit.bottom!,
            );
            _moveStartPos = pos;
          }
        },
        onPanUpdate: (details) {
          if (drawMode) {
            final session = _draftSession;
            if (session == null) return;
            final current = _toNormalized(details.localPosition, size);
            session.move(current);
            setState(() => _draftRect = session.draft);
            // 高频回调：抽样打印，核对固定原点与终点
            if (++_panUpdateLogTick % 8 == 1) {
              _debugLog(
                'pointer#${session.pointer} move '
                'start=(${session.start.dx.toStringAsFixed(3)},'
                '${session.start.dy.toStringAsFixed(3)}) '
                'current=(${current.dx.toStringAsFixed(3)},'
                '${current.dy.toStringAsFixed(3)}) '
                '草稿=${_rectDebug(_draftRect)}',
              );
            }
            return;
          }
          final startBounds = _moveStartBounds;
          final startPos = _moveStartPos;
          final region = _selected;
          if (startBounds == null ||
              startPos == null ||
              region == null ||
              region.source != 'custom') {
            return;
          }
          final pos = _toNormalized(details.localPosition, size);
          final dx = (pos - startPos).dx;
          final dy = (pos - startPos).dy;
          final width = startBounds.width;
          final height = startBounds.height;
          final left = (startBounds.left + dx).clamp(0.0, 1.0 - width);
          final top = (startBounds.top + dy).clamp(0.0, 1.0 - height);
          _mutate(
            (regions) => _replaceSelected(
              Live2DTapRegion(
                id: region.id,
                name: region.name,
                source: region.source,
                left: left,
                top: top,
                right: left + width,
                bottom: top + height,
                messages: region.messages,
              ),
            ),
          );
        },
        onPanEnd: (_) {
          if (drawMode) {
            final session = _draftSession;
            _draftSession = null;
            if (session == null) return;
            final draft = session.commit(minEdge: _minRegionEdge);
            _debugLog(
              'pointer#${session.pointer} up '
              'start=(${session.start.dx.toStringAsFixed(3)},'
              '${session.start.dy.toStringAsFixed(3)}) '
              '最终=${_rectDebug(session.draft)} '
              '${draft == null ? "过小丢弃" : "提交"}',
            );
            if (draft == null) {
              setState(() => _draftRect = null);
            } else {
              _commitDraft(draft);
            }
            return;
          }
          _debugLog('pointer up（移动区域结束）');
          if (_moveStartBounds != null) {
            _moveStartBounds = null;
            _moveStartPos = null;
            _select(_selectedId);
          }
        },
        onPanCancel: () {
          _debugLog('pointer cancel 放弃进行中的草稿/拖动');
          _draftSession = null;
          if (drawMode) {
            setState(() => _draftRect = null);
            return;
          }
          _moveStartBounds = null;
          _moveStartPos = null;
        },
      ),
    );
  }

  Widget _buildPreview(AppThemeData theme) {
    final definition = localDefinitionForArchive(widget.archive);
    return Stack(
      fit: StackFit.expand,
      children: [
        Live2DModelPreview(
          definition: definition,
          aspectRatio: _viewportAspectRatio,
          onModelLoaded: _onModelLoaded,
          onControllerReady: (controller) {
            _previewController = controller;
            // 挂载即按当前模式同步交互开关（macOS 上选择/绘制需关闭原生命中）
            controller.addListener(_onPreviewStateChanged);
            _syncInteractive();
            // 测试模式依赖原生 HitArea 判定回调（点击未落在预览手势层时由此触发）
            controller.onTap = _handleTestHit;
          },
          topRight: _buildModeCluster(theme),
          overlay: CustomPaint(
            painter: _RegionPainter(
              regions: _regions,
              selectedId: _selectedId,
              draftRect: _draftRect,
            ),
          ),
          // 绘制模式给整个预览压一层半透明黑色蒙层：直观标示「可绘制」状态，
          // 同时压暗模型让黑色矩形/琥珀描边更醒目；选择/测试模式不传。
          scrim: _mode == _InteractionMode.draw
              ? const ColoredBox(color: Colors.black45)
              : null,
          foreground: LayoutBuilder(
            builder: (context, constraints) =>
                _buildForeground(constraints.biggest),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${definition?.label ?? ''}  ${live2dRegionText('模型 HitAreas', 'model HitAreas')}: ${_hitAreas.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(AppThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        _mode == _InteractionMode.test
            ? live2dRegionText('点击模型测试台词', 'Tap model to test')
            : live2dRegionText('点击区域预览', 'Region preview'),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: theme.text,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// 预览右上角互斥模式按钮组：选择/绘制/测试 + HitAreas 叠加开关。
  /// 只占预览一角，不阻挡画面主体的绘制与拖动手势。
  Widget _buildModeCluster(AppThemeData theme) {
    Widget modeButton(_InteractionMode mode, DsIconKind icon, String tooltip) {
      final selected = _mode == mode;
      return DSIconButton(
        icon: icon,
        tooltip: tooltip,
        size: 36,
        color: selected ? theme.primary : theme.surface,
        iconColor: selected ? theme.onPrimary : theme.textSub,
        onPressed: () => _setMode(mode),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        modeButton(
          _InteractionMode.select,
          DsIconKind.drag,
          live2dRegionText('选择 / 移动区域', 'Select / move regions'),
        ),
        const SizedBox(width: 6),
        modeButton(
          _InteractionMode.draw,
          DsIconKind.edit,
          live2dRegionText('绘制矩形区域', 'Draw rectangle regions'),
        ),
        const SizedBox(width: 6),
        modeButton(
          _InteractionMode.test,
          DsIconKind.chat,
          live2dRegionText('点击模型测试台词', 'Tap model to test messages'),
        ),
        const SizedBox(width: 6),
        DSIconButton(
          icon: DsIconKind.eye,
          size: 36,
          tooltip: live2dRegionText('模型 HitAreas 叠加', 'Show model hit areas'),
          color: _hitOverlayVisible ? theme.primary : theme.surface,
          iconColor: _hitOverlayVisible ? theme.onPrimary : theme.textSub,
          onPressed: _toggleHitOverlay,
        ),
      ],
    );
  }

  Widget _buildToolPanel(AppThemeData theme) {
    final region = _selected;
    return Column(
      children: [
        // 可拖拽分隔条：上下调整预览与工具区高度
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            final mediaHeight = MediaQuery.of(context).size.height;
            setState(
              () => _toolsHeight = (_toolsHeight - details.delta.dy).clamp(
                160.0,
                mediaHeight * 0.8,
              ),
            );
          },
          child: Container(
            height: 18,
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.text.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _regionSummary(_regions),
                  style: TextStyle(fontSize: 12, color: theme.textSub),
                ),
                const SizedBox(height: 10),
                // 交互模式切换在预览右上角按钮组；这里仅提示当前模式操作方式
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(switch (_mode) {
                    _InteractionMode.select => live2dRegionText(
                      '点选区域查看/编辑，拖动可移动自定义矩形',
                      'Tap to select, drag to move custom rects',
                    ),
                    _InteractionMode.draw => live2dRegionText(
                      '在预览上按住拖拽画出矩形，松手创建区域',
                      'Drag on the preview to draw a rectangle',
                    ),
                    _InteractionMode.test => live2dRegionText(
                      '直接点击模型：命中区域会随机弹出一条台词',
                      'Tap the model: a random message pops up on hit',
                    ),
                  }, style: TextStyle(fontSize: 12, color: theme.textSub)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DSButton(
                        label: live2dRegionText('添加模型部位', 'Add hit area'),
                        icon: DsIconKind.plus,
                        size: DSButtonSize.sm,
                        onPressed: _addModelRegion,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_regions.isEmpty)
                  Text(
                    live2dRegionText(
                      '还没有区域：添加模型自带部位，或绘制自定义矩形',
                      'No regions yet: add a model hit area or draw a rect',
                    ),
                    style: TextStyle(fontSize: 12, color: theme.textSub),
                  ),
                for (final item in _regions) _buildRegionRow(theme, item),
                if (region != null) ...[
                  const SizedBox(height: 12),
                  _buildRegionDetail(theme, region),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegionRow(AppThemeData theme, Live2DTapRegion region) {
    final selected = region.id == _selectedId;
    final isModel = region.source == 'model';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DSListItem(
        title: region.name.isEmpty
            ? live2dRegionText('（未命名）', '(unnamed)')
            : region.name,
        subtitle:
            '${isModel ? live2dRegionText('模型部位', 'model') : live2dRegionText('自定义矩形', 'custom')} · ${live2dRegionText('台词', 'messages')} ${region.effectiveMessages.length}',
        leading: DsIcon(
          isModel ? DsIconKind.tag : DsIconKind.layers,
          color: theme.primary,
        ),
        trailing: selected
            ? DsIcon(DsIconKind.check, color: theme.primary)
            : null,
        onTap: () => _select(region.id),
      ),
    );
  }

  Widget _buildRegionDetail(AppThemeData theme, Live2DTapRegion region) {
    final isCustom = region.source == 'custom';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: dsSketchDecoration(theme: theme, fillColor: theme.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DSInput(
            controller: _nameController,
            label: live2dRegionText('区域名称', 'Region name'),
            onChanged: _onNameChanged,
          ),
          if (isCustom) ...[
            const SizedBox(height: 8),
            Text(
              live2dRegionText('边界（0-1，相对模型视口）', 'Bounds (0-1 of viewport)'),
              style: TextStyle(fontSize: 12, color: theme.textSub),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _BoundField(
                      controller: _boundControllers[i],
                      label: _boundLabels[i],
                      onChanged: (value) => _onBoundChanged(i, value),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 8),
          DSInput(
            controller: _messagesController,
            label: live2dRegionText(
              '台词（每行一条，随机挑选）',
              'Messages (one per line, random pick)',
            ),
            maxLines: 6,
            minLines: 3,
            onChanged: _onMessagesChanged,
          ),
          const SizedBox(height: 10),
          DSButton(
            label: live2dRegionText('删除区域', 'Delete region'),
            icon: DsIconKind.trash,
            size: DSButtonSize.sm,
            variant: DSButtonVariant.destructive,
            onPressed: _deleteSelected,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        title: Text(live2dRegionText('点击区域与台词', 'Tap regions & messages')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(live2dRegionText('完成', 'Done')),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.all(10),
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: theme.surface,
                ),
                child: Column(
                  children: [
                    _buildHeader(theme),
                    const SizedBox(height: 8),
                    Expanded(child: _buildPreview(theme)),
                  ],
                ),
              ),
            ),
            SizedBox(height: _toolsHeight, child: _buildToolPanel(theme)),
          ],
        ),
      ),
    );
  }
}
