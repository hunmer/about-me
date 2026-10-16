part of 'jelly_live2d.dart';

/// 小屋内置背景图（assets/live2d_backgrounds/），null 表示无背景
const List<String> _backgroundAssets = [
  'assets/live2d_backgrounds/Live2D背景·冬日窗边.jpg',
  'assets/live2d_backgrounds/Live2D背景·放学教室.jpg',
  'assets/live2d_backgrounds/Live2D背景·海底珊瑚(深蓝冷调).jpg',
  'assets/live2d_backgrounds/Live2D背景·极简厨房(灰白冷调).jpg',
  'assets/live2d_backgrounds/Live2D背景·秋日银杏(金橙冷天).jpg',
  'assets/live2d_backgrounds/Live2D背景·森林露营(森绿冷调).jpg',
  'assets/live2d_backgrounds/Live2D背景·深夜办公室.jpg',
  'assets/live2d_backgrounds/Live2D背景·天台星空(雾紫靛蓝).jpg',
  'assets/live2d_backgrounds/Live2D背景·图书馆(冷灰绿).jpg',
  'assets/live2d_backgrounds/Live2D背景·卧室清晨.jpg',
  'assets/live2d_backgrounds/Live2D背景·夏日海边(冷蓝).jpg',
  'assets/live2d_backgrounds/Live2D背景·雪夜温泉(青灰冷调).jpg',
  'assets/live2d_backgrounds/Live2D背景·樱花长椅(樱粉雾白).jpg',
  'assets/live2d_backgrounds/Live2D背景·雨后街角.jpg',
  'assets/live2d_backgrounds/图片节点 1.jpg',
];

/// 背景模糊上限（滑杆 0~1 映射到 sigma 0~20）
const double _backgroundBlurMax = 20;

/// 背景功能：背景选择/上传、模糊与不透明度调节、背景资源条
extension _JellyLive2DBackground on _JellyLive2DState {
  /// 切换小屋背景图；null 表示关闭背景，选择后立即生效并持久化
  Future<void> _selectBackground(String? asset) async {
    if (asset == _backgroundAsset) return;
    setState(() => _backgroundAsset = asset);
    await Live2DPlugin.instance.setBackgroundAsset(asset);
  }

  /// 上传自定义背景图：保存到应用目录、加入自定义列表并立即选用
  Future<void> _uploadCustomBackground(BuildContext context) async {
    final result = await ImagePickerDialog.show<Map<String, dynamic>>(
      context,
      saveDirectory: 'live2d/backgrounds',
    );
    final asset = result?['url'] as String?;
    if (asset == null || asset.isEmpty) return;
    await Live2DPlugin.instance.addCustomBackgroundAsset(asset);
    if (!mounted) return;
    setState(() => _backgroundAsset = asset);
  }

  /// 滑杆拖动中实时预览：setState 刷新页面背景，setSheetState 刷新
  /// 设置弹出层内的滑杆
  void _previewBackground(VoidCallback apply, [StateSetter? setSheetState]) {
    setState(apply);
    setSheetState?.call(() {});
  }

  Widget _buildBackgroundStrip(AppThemeData theme) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: theme.spacing.sm),
                  child: GestureDetector(
                    onTap: () => _selectBackground(null),
                    child: Container(
                      width: 72,
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _backgroundAsset == null
                              ? theme.primary
                              : theme.stroke,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: DsIcon(
                          DsIconKind.block,
                          size: 20,
                          color: theme.textSub,
                        ),
                      ),
                    ),
                  ),
                ),
                for (final asset in [
                  ..._backgroundAssets,
                  ...Live2DPlugin.instance.customBackgroundAssets,
                ])
                  Padding(
                    padding: EdgeInsets.only(right: theme.spacing.sm),
                    child: GestureDetector(
                      onTap: () => _selectBackground(asset),
                      child: Container(
                        width: 72,
                        height: 48,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: asset == _backgroundAsset
                                ? theme.primary
                                : theme.surface.withValues(alpha: 0),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: JellyConfigurableImage(
                          path: asset,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                _addTile(
                  theme,
                  width: 72,
                  height: 48,
                  iconSize: 22,
                  onTap: () => _uploadCustomBackground(context),
                ),
              ],
            ),
          ),
          // 背景生效时尾随固定的调节按钮：点击弹出模糊/不透明度设置层
          if (_backgroundAsset != null) ...[
            SizedBox(width: theme.spacing.md),
            Container(width: 1, height: 36, color: theme.stroke),
            SizedBox(width: theme.spacing.md),
            _backgroundSettingsButton(theme),
          ],
        ],
      ),
    );
  }

  /// 背景调节按钮：点击弹出模糊 / 不透明度设置层
  Widget _backgroundSettingsButton(AppThemeData theme) {
    return GestureDetector(
      onTap: _openBackgroundSettings,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.surfaceAlt,
          border: Border.all(color: theme.stroke),
        ),
        child: Center(
          child: DsIcon(DsIconKind.tune, size: 18, color: theme.primary),
        ),
      ),
    );
  }

  /// 背景调节弹出层：滑杆拖动实时预览，松手持久化
  Future<void> _openBackgroundSettings() {
    return SmoothBottomSheet.showWithTitle<void>(
      context: context,
      title: '背景设置',
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
            child: StatefulBuilder(
              builder: (context, setSheetState) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '背景模糊',
                    style: DsTypography.label.copyWith(color: theme.text),
                  ),
                  DSSlider(
                    value:
                        (_backgroundBlur / _backgroundBlurMax).clamp(0.0, 1.0),
                    onChanged: (ratio) => _previewBackground(
                      () => _backgroundBlur = ratio * _backgroundBlurMax,
                      setSheetState,
                    ),
                    onChangeEnd: (ratio) => Live2DPlugin.instance
                        .setBackgroundBlur(ratio * _backgroundBlurMax),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Text(
                    '背景不透明度',
                    style: DsTypography.label.copyWith(color: theme.text),
                  ),
                  DSSlider(
                    value: _backgroundOpacity.clamp(0.0, 1.0),
                    onChanged: (ratio) => _previewBackground(
                      () => _backgroundOpacity = ratio,
                      setSheetState,
                    ),
                    onChangeEnd: (ratio) =>
                        Live2DPlugin.instance.setBackgroundOpacity(ratio),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
