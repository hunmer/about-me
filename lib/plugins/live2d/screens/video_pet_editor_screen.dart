import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_player.dart';

const _unchanged = Object();

String videoPetText(String zh, String en) =>
    (Get.locale?.languageCode ?? 'zh') == 'zh' ? zh : en;

/// Editor for a [VideoPetManifest].
///
/// The draft is isolated so cancel never mutates the incoming manifest.
class VideoPetEditorScreen extends StatefulWidget {
  const VideoPetEditorScreen({
    super.key,
    required this.manifest,
    required this.baseUri,
    this.resolvedSources = const {},
  });

  final VideoPetManifest manifest;
  final String baseUri;
  final Map<String, String> resolvedSources;

  @override
  State<VideoPetEditorScreen> createState() => _VideoPetEditorScreenState();
}

class _VideoPetEditorScreenState extends State<VideoPetEditorScreen> {
  late VideoPetManifest _draft;
  final _animationRequest = ValueNotifier<String?>(null);
  final _searchController = TextEditingController();
  final _jsonController = TextEditingController();

  String? _selectedRegionId;
  String? _selectedAnimationId;
  String _category = 'all';
  bool _isAddingRegion = false;
  bool _isPaused = false;
  bool _isTestMode = true;
  bool _showRegions = true;
  String? _lastHitRegion;
  String? _lastActionAnimation;
  Rect? _gestureRect;
  Offset? _gestureOrigin;
  Rect? _gestureInitialRect;
  String? _gestureRegionId;
  _RegionGestureMode _gestureMode = _RegionGestureMode.none;

  @override
  void initState() {
    super.initState();
    _draft = VideoPetManifest.fromJson(
      Map<String, dynamic>.from(widget.manifest.toJson()),
    );
    _selectedRegionId = _draft.regions.isEmpty ? null : _draft.regions.first.id;
  }

  @override
  void dispose() {
    _animationRequest.dispose();
    _searchController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  String _text(String key, String fallback) {
    if (key.isEmpty) return fallback;
    return videoPetText(fallback, fallback);
  }

  VideoPetRegion? get _selectedRegion => _draft.regions
      .where((region) => region.id == _selectedRegionId)
      .firstOrNull;

  void _setDraft(VideoPetManifest value) {
    setState(() => _draft = value);
  }

  void _save() {
    try {
      _draft.validate();
      Navigator.of(context).pop(_draft);
    } catch (error) {
      _showMessage('$error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _requestAnimation(String id) {
    _selectedAnimationId = id;
    // Reset first so tapping the same animation restarts the player request.
    _animationRequest.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animationRequest.value = id;
    });
    setState(() {});
  }

  List<VideoPetAnimation> get _visibleAnimations {
    final query = _searchController.text.trim().toLowerCase();
    return _draft.animations.where((animation) {
      final matchesQuery =
          query.isEmpty ||
          animation.name.toLowerCase().contains(query) ||
          animation.id.toLowerCase().contains(query);
      final matchesCategory =
          _category == 'all' || animation.category == _category;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  Set<String> get _categories => {
    'all',
    ..._draft.animations
        .map((animation) => animation.category)
        .where((category) => category.isNotEmpty),
  };

  void _onEditPointer(String type, double x, double y) {
    if (_isTestMode) return;
    final point = Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
    switch (type) {
      case 'pointerdown':
        _startRegionGesture(point);
      case 'pointermove':
        _updateRegionGesture(point);
      case 'pointerup':
      case 'pointercancel':
        _finishRegionGesture();
    }
  }

  void _startRegionGesture(Offset normalized) {
    if (_isAddingRegion) {
      _gestureMode = _RegionGestureMode.add;
      _gestureOrigin = normalized;
      setState(() => _gestureRect = Rect.fromPoints(normalized, normalized));
      return;
    }
    final hit =
        _draft.regions
            .where((region) => _regionRect(region).contains(normalized))
            .toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));
    if (hit.isEmpty) return;
    final region = hit.first;
    final rect = _regionRect(region);
    _gestureRegionId = region.id;
    _gestureInitialRect = rect;
    _gestureOrigin = normalized;
    _gestureMode = _isResizeHandle(normalized, rect)
        ? _RegionGestureMode.resize
        : _RegionGestureMode.move;
    setState(() => _selectedRegionId = region.id);
  }

  void _updateRegionGesture(Offset current) {
    final origin = _gestureOrigin;
    if (origin == null) return;
    if (_gestureMode == _RegionGestureMode.add) {
      setState(() => _gestureRect = Rect.fromPoints(origin, current));
      return;
    }
    final initial = _gestureInitialRect;
    if (initial == null || _gestureRegionId == null) return;
    final dx = current.dx - origin.dx;
    final dy = current.dy - origin.dy;
    if (_gestureMode == _RegionGestureMode.move) {
      _updateSelectedRegion(
        x: (initial.left + dx).clamp(0.0, 1.0 - initial.width),
        y: (initial.top + dy).clamp(0.0, 1.0 - initial.height),
      );
    } else if (_gestureMode == _RegionGestureMode.resize) {
      _updateSelectedRegion(
        width: (initial.width + dx).clamp(.01, 1.0 - initial.left),
        height: (initial.height + dy).clamp(.01, 1.0 - initial.top),
      );
    }
  }

  void _finishRegionGesture() {
    final rect = _gestureRect;
    if (_gestureMode != _RegionGestureMode.add) {
      setState(_clearGesture);
      return;
    }
    if (rect == null || rect.width < .02 || rect.height < .02) {
      setState(_clearGesture);
      return;
    }
    final id = 'region_${DateTime.now().microsecondsSinceEpoch}';
    final region = VideoPetRegion(
      id: id,
      name: videoPetText('新区域', 'New region'),
      x: rect.left.clamp(0, 1),
      y: rect.top.clamp(0, 1),
      width: rect.width.clamp(.01, 1),
      height: rect.height.clamp(.01, 1),
      enabled: true,
      priority: _draft.regions.length,
      hover: null,
      click: null,
    );
    _setDraft(_draft.copyWith(regions: [..._draft.regions, region]));
    setState(() {
      _selectedRegionId = id;
      _isAddingRegion = false;
      _clearGesture();
    });
  }

  Rect _regionRect(VideoPetRegion region) =>
      Rect.fromLTWH(region.x, region.y, region.width, region.height);

  bool _isResizeHandle(Offset point, Rect rect) =>
      (point - rect.bottomRight).distance <= .04;

  void _clearGesture() {
    _gestureRect = null;
    _gestureOrigin = null;
    _gestureInitialRect = null;
    _gestureRegionId = null;
    _gestureMode = _RegionGestureMode.none;
  }

  VideoPetBinding _withBinding(
    VideoPetBinding binding, {
    List<String>? animationIds,
    String? strategy,
  }) => VideoPetBinding(
    animationIds: animationIds ?? binding.animationIds,
    strategy: strategy ?? binding.strategy,
  );

  void _deleteRegion() {
    final selected = _selectedRegion;
    if (selected == null) return;
    final regions = _draft.regions
        .where((region) => region.id != selected.id)
        .toList();
    _setDraft(_draft.copyWith(regions: regions));
    setState(
      () => _selectedRegionId = regions.isEmpty ? null : regions.first.id,
    );
  }

  void _updateGlobalBinding({VideoPetBinding? hover, VideoPetBinding? click}) {
    _setDraft(_draft.copyWith(hover: hover, click: click));
  }

  Widget _buildGlobalBindingEditor(
    String title,
    VideoPetBinding binding,
    ValueChanged<VideoPetBinding> onChanged,
  ) {
    final selectedIds = binding.animationIds.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: binding.strategy,
          decoration: InputDecoration(
            labelText: _text('videoPet_strategy', '播放策略'),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'random', child: Text('random')),
            DropdownMenuItem(value: 'sequence', child: Text('sequence')),
          ],
          onChanged: (value) =>
              onChanged(_withBinding(binding, strategy: value ?? 'random')),
        ),
        const SizedBox(height: 6),
        Text(
          _text('videoPet_multiSelect', '可多选动画；清空即禁用'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: _draft.animations.map((animation) {
            final selected = selectedIds.contains(animation.id);
            return FilterChip(
              label: Text(
                animation.name.isEmpty ? animation.id : animation.name,
              ),
              selected: selected,
              onSelected: (checked) {
                final next = {...selectedIds};
                if (checked) {
                  next.add(animation.id);
                } else {
                  next.remove(animation.id);
                }
                onChanged(_withBinding(binding, animationIds: next.toList()));
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _updateSelectedRegion({
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    bool? enabled,
    int? priority,
    Object? hover = _unchanged,
    Object? click = _unchanged,
  }) {
    final selected = _selectedRegion;
    if (selected == null) return;
    var updated = selected.copyWith(
      name: name,
      x: x,
      y: y,
      width: width,
      height: height,
      enabled: enabled,
      priority: priority,
    );
    if (!identical(hover, _unchanged)) {
      updated = updated.copyWith(hover: hover as VideoPetBinding?);
    }
    if (!identical(click, _unchanged)) {
      updated = updated.copyWith(click: click as VideoPetBinding?);
    }
    _setDraft(
      _draft.copyWith(
        regions: [
          for (final region in _draft.regions)
            region.id == selected.id ? updated : region,
        ],
      ),
    );
  }

  void _importJson() {
    final decoded = jsonDecode(_jsonController.text);
    if (decoded is! Map) throw const FormatException('manifest JSON 必须是对象');
    final imported = VideoPetManifest.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    _setDraft(imported);
    setState(() {
      _selectedRegionId = imported.regions.firstOrNull?.id;
      _selectedAnimationId = null;
    });
  }

  Future<void> _showJsonDialog({required bool importing}) async {
    _jsonController.text = importing
        ? ''
        : const JsonEncoder.withIndent('  ').convert(_draft.toJson());
    final action = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          importing
              ? _text('videoPet_importJson', '导入 JSON')
              : _text('videoPet_exportJson', '导出 JSON'),
        ),
        content: SizedBox(
          width: 680,
          child: TextField(
            controller: _jsonController,
            autofocus: importing,
            minLines: 12,
            maxLines: 24,
            readOnly: !importing,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: _text(
                'videoPet_manifestJsonHint',
                '仅粘贴或复制 manifest JSON',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_text('core_cancel', '取消')),
          ),
          if (!importing)
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: _jsonController.text),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) _showMessage(_text('videoPet_copied', '已复制 JSON'));
              },
              icon: const Icon(Icons.copy_outlined),
              label: Text(_text('videoPet_copy', '复制')),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_text('videoPet_import', '导入')),
            ),
        ],
      ),
    );
    if (action != true || !importing) return;
    try {
      _importJson();
    } catch (error) {
      _showMessage('${_text('videoPet_invalidJson', 'JSON 无效')}: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_text('videoPet_editorTitle', '精灵图宠物编辑器')),
        leading: IconButton(
          tooltip: _text('core_cancel', '取消'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: _text('videoPet_importJson', '导入 JSON'),
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () => _showJsonDialog(importing: true),
          ),
          IconButton(
            tooltip: _text('videoPet_exportJson', '导出 JSON'),
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _showJsonDialog(importing: false),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(_text('videoPet_save', '保存')),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return Row(
              children: [
                SizedBox(width: 300, child: _buildRegionPanel()),
                Expanded(child: _buildPreviewAndAnimationPanel()),
                SizedBox(width: 330, child: _buildBindingPanel()),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: _buildPreviewAndAnimationPanel()),
              SizedBox(height: 280, child: _buildRegionPanel(horizontal: true)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreviewAndAnimationPanel() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildPreview(),
          ),
        ),
        SizedBox(height: 220, child: _buildAnimationPanel()),
      ],
    );
  }

  Widget _buildPreview() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isTestMode
                        ? _text('videoPet_testPreview', '测试预览')
                        : _text('videoPet_editPreview', '编辑预览'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(_text('videoPet_edit', '编辑')),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(_text('videoPet_test', '测试')),
                      icon: const Icon(Icons.touch_app_outlined, size: 16),
                    ),
                  ],
                  selected: {_isTestMode},
                  onSelectionChanged: (values) =>
                      setState(() => _isTestMode = values.first),
                ),
                IconButton(
                  tooltip: _isPaused
                      ? _text('videoPet_resume', '继续')
                      : _text('videoPet_pause', '暂停'),
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  onPressed: () => setState(() => _isPaused = !_isPaused),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: AspectRatio(
                    aspectRatio: _draft.canvasWidth / _draft.canvasHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: VideoPetPlayer(
                            manifest: _draft,
                            baseUri: widget.baseUri,
                            resolvedSources: widget.resolvedSources,
                            active: true,
                            paused: _isPaused,
                            animationRequest: _animationRequest,
                            interactive: _isTestMode,
                            onEditPointer: _isTestMode ? null : _onEditPointer,
                            showRegions: _showRegions,
                            onInteraction: (regionId, animationId) {
                              setState(() {
                                _selectedRegionId = regionId;
                                _lastHitRegion = regionId;
                                _lastActionAnimation = animationId;
                              });
                            },
                            onTap: (regionId, regionName) {
                              setState(
                                () => _lastHitRegion = regionName ?? regionId,
                              );
                            },
                          ),
                        ),
                        if (!_isTestMode &&
                            (_isAddingRegion ||
                                _gestureMode != _RegionGestureMode.none))
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _RegionPainter(
                                  regions: _draft.regions,
                                  selectedId: _selectedRegionId,
                                  draftRect: _gestureRect,
                                  showLabels: true,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  _isTestMode
                                      ? '${_text('videoPet_hit', '命中')}: ${_lastHitRegion ?? '-'}  ${_text('videoPet_action', '动作')}: ${_lastActionAnimation ?? '-'}'
                                      : _text(
                                          'videoPet_editHint',
                                          '拖动区域移动，拖动右下角调整大小',
                                        ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionPanel({bool horizontal = false}) {
    final panel = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _text('videoPet_regions', '区域'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: _text('videoPet_addRegion', '框选新增区域'),
                icon: Icon(_isAddingRegion ? Icons.close : Icons.crop_free),
                onPressed: () =>
                    setState(() => _isAddingRegion = !_isAddingRegion),
              ),
              IconButton(
                tooltip: _text('videoPet_deleteRegion', '删除区域'),
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleteRegion,
              ),
            ],
          ),
          if (_isAddingRegion)
            Text(
              _text('videoPet_drawHint', '在预览中拖动框选区域'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
              itemCount: _draft.regions.length,
              itemBuilder: (context, index) {
                final region = _draft.regions[index];
                return SizedBox(
                  width: horizontal ? 220 : null,
                  child: ListTile(
                    dense: true,
                    selected: region.id == _selectedRegionId,
                    leading: CircleAvatar(
                      radius: 12,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      region.name.isEmpty ? region.id : region.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${region.priority} · ${region.enabled ? _text('videoPet_enabled', '启用') : _text('videoPet_disabled', '停用')}',
                    ),
                    trailing: Icon(
                      region.enabled
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    onTap: () => setState(() => _selectedRegionId = region.id),
                    onLongPress: () {
                      setState(() => _selectedRegionId = region.id);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => SafeArea(
                          child: SizedBox(
                            height: MediaQuery.sizeOf(context).height * .75,
                            child: _buildBindingPanel(),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: panel,
    );
  }

  Widget _buildAnimationPanel() {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _text('videoPet_animations', '动画'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: _text('videoPet_searchAnimation', '搜索动画'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _categories
                    .map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            category == 'all'
                                ? _text('videoPet_all', '全部')
                                : category,
                          ),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _visibleAnimations.length,
                itemBuilder: (context, index) {
                  final animation = _visibleAnimations[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Card(
                      child: InkWell(
                        onTap: () => _requestAnimation(animation.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedAnimationId == animation.id
                                    ? Icons.play_circle
                                    : Icons.animation,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 160,
                                ),
                                child: Text(
                                  animation.name.isEmpty
                                      ? animation.id
                                      : animation.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                animation.category,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementEditor() {
    final movement = _draft.movement;
    final movementAnimations = _draft.animations;
    final turnAnimations = _draft.animations;
    final movementItems = [
      const DropdownMenuItem<String>(value: '', child: Text('不设置')),
      for (final animation in movementAnimations)
        DropdownMenuItem(value: animation.id, child: Text(animation.name)),
    ];
    final turnItems = [
      const DropdownMenuItem<String>(value: '', child: Text('不设置')),
      for (final animation in turnAnimations)
        DropdownMenuItem(value: animation.id, child: Text(animation.name)),
    ];
    void update(VideoPetMovement next) =>
        _setDraft(_draft.copyWith(movement: next));
    Widget selector(
      String label,
      String value,
      List<DropdownMenuItem<String>> items,
      ValueChanged<String?> onChanged,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        value: items.any((item) => item.value == value) ? value : '',
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _text('videoPet_movement', '随机移动'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        selector(
          _text('videoPet_moveLeft', '向左移动'),
          movement.leftAnimationId,
          movementItems,
          (id) => update(movement.copyWith(leftAnimationId: id ?? '')),
        ),
        selector(
          _text('videoPet_moveRight', '向右移动'),
          movement.rightAnimationId,
          movementItems,
          (id) => update(movement.copyWith(rightAnimationId: id ?? '')),
        ),
        selector(
          _text('videoPet_turnLeft', '向左转向'),
          movement.turnLeftAnimationId,
          turnItems,
          (id) => update(movement.copyWith(turnLeftAnimationId: id ?? '')),
        ),
        selector(
          _text('videoPet_turnRight', '向右转向'),
          movement.turnRightAnimationId,
          turnItems,
          (id) => update(movement.copyWith(turnRightAnimationId: id ?? '')),
        ),
        selector(
          _text('videoPet_drag', '拖拽悬空'),
          movement.dragAnimationId,
          movementItems,
          (id) => update(movement.copyWith(dragAnimationId: id ?? '')),
        ),
        _numberField(
          _text('videoPet_moveSpeed', '移动速度（像素/秒）'),
          movement.speed,
          (value) => update(movement.copyWith(speed: value.clamp(.1, 10000))),
        ),
        _numberField(
          _text('videoPet_minIdle', '最短等待（秒）'),
          movement.minIdleSeconds,
          (value) => update(
            movement.copyWith(
              minIdleSeconds: value.clamp(0, movement.maxIdleSeconds),
            ),
          ),
        ),
        _numberField(
          _text('videoPet_maxIdle', '最长等待（秒）'),
          movement.maxIdleSeconds,
          (value) => update(
            movement.copyWith(
              maxIdleSeconds: value.clamp(movement.minIdleSeconds, 86400),
            ),
          ),
        ),
        Text(
          _text(
            'videoPet_movementHint',
            '在动画 JSON 中通过 facing 设置原始朝向（left/right），行走时按位移方向自动翻转。',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildBindingPanel() {
    final selected = _selectedRegion;
    if (selected == null) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [_buildMovementEditor()],
        ),
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildMovementEditor(),
          const Divider(height: 22),
          Text(
            _text('videoPet_regionProperties', '区域属性'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _draft.idleAnimationId,
            decoration: InputDecoration(
              labelText: _text('videoPet_idleAnimation', 'Idle 动画'),
              border: const OutlineInputBorder(),
            ),
            items: _draft.animations
                .map(
                  (animation) => DropdownMenuItem(
                    value: animation.id,
                    child: Text(animation.name),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id != null) _setDraft(_draft.copyWith(idleAnimationId: id));
            },
          ),
          const SizedBox(height: 12),
          _buildGlobalBindingEditor(
            _text('videoPet_globalClick', '全局 Click'),
            _draft.click,
            (binding) => _updateGlobalBinding(click: binding),
          ),
          const Divider(height: 22),
          TextFormField(
            initialValue: selected.name,
            decoration: InputDecoration(
              labelText: _text('videoPet_name', '名称'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => _updateSelectedRegion(name: value),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text('videoPet_enabled', '启用')),
            value: selected.enabled,
            onChanged: (value) => _updateSelectedRegion(enabled: value),
          ),
          _numberField(
            _text('videoPet_priority', '优先级'),
            selected.priority.toDouble(),
            (value) => _updateSelectedRegion(priority: value.round()),
          ),
          const Divider(height: 22),
          Text(
            _text('videoPet_geometry', '位置与尺寸'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _numberField(
            'X',
            selected.x,
            (value) => _updateSelectedRegion(x: value.clamp(0, 1)),
          ),
          _numberField(
            'Y',
            selected.y,
            (value) => _updateSelectedRegion(y: value.clamp(0, 1)),
          ),
          _numberField(
            _text('videoPet_width', '宽度'),
            selected.width,
            (value) => _updateSelectedRegion(width: value.clamp(.01, 1)),
          ),
          _numberField(
            _text('videoPet_height', '高度'),
            selected.height,
            (value) => _updateSelectedRegion(height: value.clamp(.01, 1)),
          ),
          const Divider(height: 22),
          _buildBindingEditor(
            _text('videoPet_click', 'Click 动画'),
            selected.click,
            _draft.click,
            (binding) => _updateSelectedRegion(click: binding),
          ),
          const Divider(height: 22),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text('videoPet_showRegions', '显示区域')),
            trailing: Switch(
              value: _showRegions,
              onChanged: (value) => setState(() => _showRegions = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value.toStringAsFixed(3),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onFieldSubmitted: (text) => onChanged(double.tryParse(text) ?? value),
      ),
    );
  }

  Widget _buildBindingEditor(
    String title,
    VideoPetBinding? binding,
    VideoPetBinding globalBinding,
    ValueChanged<Object?> onChanged,
  ) {
    final inherited = binding == null;
    final current = binding ?? globalBinding;
    final selectedIds = current.animationIds.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_text('videoPet_inheritGlobal', '继承全局')),
          value: inherited,
          onChanged: (value) => onChanged(value ? null : current),
        ),
        if (!inherited) ...[
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: current.strategy,
            decoration: InputDecoration(
              labelText: _text('videoPet_strategy', '播放策略'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'random', child: Text('random')),
              DropdownMenuItem(value: 'sequence', child: Text('sequence')),
            ],
            onChanged: (value) =>
                onChanged(_withBinding(current, strategy: value ?? 'random')),
          ),
          const SizedBox(height: 6),
          Text(
            _text('videoPet_multiSelect', '可多选动画；清空即禁用'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Wrap(
            spacing: 4,
            runSpacing: 0,
            children: _draft.animations.map((animation) {
              final selected = selectedIds.contains(animation.id);
              return FilterChip(
                label: Text(
                  animation.name.isEmpty ? animation.id : animation.name,
                ),
                selected: selected,
                onSelected: (checked) {
                  final next = {...selectedIds};
                  if (checked) {
                    next.add(animation.id);
                  } else {
                    next.remove(animation.id);
                  }
                  onChanged(_withBinding(current, animationIds: next.toList()));
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

enum _RegionGestureMode { none, add, move, resize }

class _RegionPainter extends CustomPainter {
  const _RegionPainter({
    required this.regions,
    required this.selectedId,
    required this.draftRect,
    required this.showLabels,
  });

  final List<VideoPetRegion> regions;
  final String? selectedId;
  final Rect? draftRect;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    for (final region in regions) {
      final rect = Rect.fromLTWH(
        region.x * size.width,
        region.y * size.height,
        region.width * size.width,
        region.height * size.height,
      );
      final selected = region.id == selectedId;
      final color = selected ? Colors.amber : Colors.lightBlueAccent;
      canvas.drawRect(
        rect,
        Paint()..color = color.withOpacity(selected ? .16 : .08),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.5 : 1.2,
      );
      if (showLabels && rect.width > 35 && rect.height > 18) {
        final painter = TextPainter(
          text: TextSpan(
            text: region.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              backgroundColor: Colors.black54,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: rect.width);
        painter.paint(canvas, rect.topLeft + const Offset(3, 3));
      }
    }
    if (draftRect != null) {
      final rect = Rect.fromLTRB(
        draftRect!.left * size.width,
        draftRect!.top * size.height,
        draftRect!.right * size.width,
        draftRect!.bottom * size.height,
      );
      canvas.drawRect(rect, Paint()..color = Colors.amber.withOpacity(.2));
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RegionPainter oldDelegate) =>
      oldDelegate.regions != regions ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.draftRect != draftRect ||
      oldDelegate.showLabels != showLabels;
}
