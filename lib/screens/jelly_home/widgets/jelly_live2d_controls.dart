part of 'jelly_live2d.dart';

const String _sizePrefKey = 'jelly_live2d.size';

/// 控制面板功能：长按/右键弹出的设置面板（显示尺寸、裁剪入口、
/// 视口边框、HitAreas 调试）与尺寸的持久化
extension _JellyLive2DControls on _JellyLive2DState {
  Future<void> _loadSavedSize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_sizePrefKey);
    if (saved != null && saved >= _minSize && saved <= _maxSize) {
      _size.value = saved;
    }
  }

  Future<void> _changeSize(double delta) async {
    final next = (_size.value + delta).clamp(_minSize, _maxSize);
    if (next == _size.value) return;
    _size.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sizePrefKey, next);
  }

  Future<void> _resetSize() async {
    if (_size.value == _defaultSize) return;
    _size.value = _defaultSize;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sizePrefKey, _defaultSize);
  }

  void _showControls() {
    SmoothBottomSheet.showWithTitle<void>(
      context: context,
      title: 'Live2D',
      child: Builder(
        builder: (sheetContext) {
          final theme = AppTheme.of(sheetContext);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              theme.spacing.xl,
              0,
              theme.spacing.xl,
              theme.spacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: theme.spacing.sm),
                Text(
                  'screens_jellyLive2dCharacterSize'.tr,
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.sm),
                ValueListenableBuilder<double>(
                  valueListenable: _size,
                  builder: (context, size, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DSButton(
                              label: 'screens_jellyLive2dShrink'.tr,
                              size: DSButtonSize.sm,
                              onPressed: size > _minSize
                                  ? () => _changeSize(-_sizeStep)
                                  : null,
                            ),
                          ),
                          SizedBox(width: theme.spacing.sm),
                          Expanded(
                            child: DSButton(
                              label: 'screens_jellyLive2dEnlarge'.tr,
                              size: DSButtonSize.sm,
                              onPressed: size < _maxSize
                                  ? () => _changeSize(_sizeStep)
                                  : null,
                            ),
                          ),
                          SizedBox(width: theme.spacing.sm),
                          Expanded(
                            child: DSButton(
                              label: 'screens_jellyLive2dReset'.tr,
                              size: DSButtonSize.sm,
                              onPressed: size == _defaultSize
                                  ? null
                                  : _resetSize,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacing.sm),
                      Text(
                        'screens_jellyLive2dCurrentSize'.trParams({
                          'percent': (size / _defaultSize * 100)
                              .round()
                              .toString(),
                          'size': size.round().toString(),
                        }),
                        textAlign: TextAlign.center,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isVideo) ...[
                  SizedBox(height: theme.spacing.xl),
                  Text(
                    'screens_jellyLive2dDisplayArea'.tr,
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  DSListItem(
                    title: 'screens_jellyLive2dSetCropRegion'.tr,
                    subtitle: _cropRegion.isFull
                        ? 'screens_jellyLive2dCropFullModel'.tr
                        : 'screens_jellyLive2dCropApplied'.tr,
                    leading: DsIcon(
                      DsIconKind.image,
                      size: 18,
                      color: theme.primary,
                    ),
                    trailing: DsIcon(
                      DsIconKind.chevronRight,
                      size: 18,
                      color: theme.textSub,
                    ),
                    onTap: _controller.value.isLoaded && !_isSwitchingModel
                        ? () => _openCropEditor(sheetContext)
                        : null,
                  ),
                  SizedBox(height: theme.spacing.sm),
                  ValueListenableBuilder<bool>(
                    valueListenable: _borderVisible,
                    builder: (context, visible, _) => DSListItem(
                      title: 'screens_jellyLive2dShowBorder'.tr,
                      subtitle: 'screens_jellyLive2dShowBorderDesc'.tr,
                      leading: DsIcon(
                        DsIconKind.image,
                        size: 18,
                        color: theme.primary,
                      ),
                      trailing: DSSwitch(
                        value: visible,
                        semanticLabel:
                            'screens_jellyLive2dShowBorderSemantic'.tr,
                        onChanged: (value) => _borderVisible.value = value,
                      ),
                    ),
                  ),
                  SizedBox(height: theme.spacing.xl),
                  Text(
                    'screens_jellyLive2dHitAreas'.tr,
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  ValueListenableBuilder<bool>(
                    valueListenable: _hitAreasVisible,
                    builder: (context, visible, _) => DSChip(
                      label: visible
                          ? 'screens_jellyLive2dEnabled'.tr
                          : 'screens_jellyLive2dDisabled'.tr,
                      selected: visible,
                      onSelected: (_) => _toggleHitAreas(!visible),
                    ),
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    'screens_jellyLive2dHitAreasDesc'.tr,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
