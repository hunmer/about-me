// 视频桌宠编辑器：编辑模式手势（点击/拖拽/缩放区域）与区域删除。
part of 'video_pet_editor_screen.dart';

enum _RegionGestureMode { none, add, move, resize }

/// 手势拆分：扩展 [_VideoPetEditorScreenState]，与类内方法等价。
extension _VideoPetEditorGestures on _VideoPetEditorScreenState {
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

}
