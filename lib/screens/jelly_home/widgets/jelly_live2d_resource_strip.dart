part of 'jelly_live2d.dart';

/// 底部资源条功能：导航栏子栏图标点开后在底部导航上方展示的
/// 水平滚动资源列表容器，以及档案条、状态面板条
extension _JellyLive2DResourceStrip on _JellyLive2DState {
  /// 底部资源条：导航栏子栏图标点开后，在底部导航上方水平滚动展示资源；
  /// 点击缩略图切换，角标按钮进入对应编辑器
  Widget _buildResourceStrip(JellyLive2dPanel panel) {
    final theme = AppTheme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.92),
        borderRadius: theme.radii.lg,
        border: Border.all(color: theme.stroke),
        boxShadow: theme.shadows.soft,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: switch (panel) {
          JellyLive2dPanel.bubble => _buildBubbleStrip(theme),
          JellyLive2dPanel.background => _buildBackgroundStrip(theme),
          JellyLive2dPanel.statusPanel => _buildStatusPanelStrip(theme),
          JellyLive2dPanel.archive => _buildArchiveStrip(theme),
        },
      ),
    );
  }

  /// 档案条：头像 + 名称，点击切换档案（并即时重载对应模型）
  Widget _buildArchiveStrip(AppThemeData theme) {
    final archives = Live2DPlugin.instance.archives;
    if (archives.isEmpty) {
      return SizedBox(
        height: 32,
        child: Center(
          child: Text(
            'screens_jellyLive2dNoArchives'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
        ),
      );
    }
    return SizedBox(
      height: 66,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final archive in archives)
            Padding(
              padding: EdgeInsets.only(right: theme.spacing.sm),
              child: _archiveTile(theme, archive),
            ),
        ],
      ),
    );
  }

  Widget _archiveTile(AppThemeData theme, Live2DArchive archive) {
    final selected = archive.id == Live2DPlugin.instance.selectedId;
    final cover = archive.coverPath;
    return GestureDetector(
      onTap: () => _selectArchive(archive),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? theme.primary : theme.stroke,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: cover == null || cover.isEmpty
                  ? DsIcon(DsIconKind.user, size: 20, color: theme.textSub)
                  : JellyConfigurableImage(path: cover, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              archive.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DsTypography.caption.copyWith(
                color: selected ? theme.primary : theme.text,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanelStrip(AppThemeData theme) {
    unawaited(JellyStatusPanelSettings.instance.load());
    final settings = JellyStatusPanelSettings.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => SizedBox(
        height: 104,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final style in settings.styles)
              Padding(
                padding: EdgeInsets.only(right: theme.spacing.sm),
                child: _statusPanelTile(theme, settings, style),
              ),
            _addTile(
              theme,
              width: 132,
              height: 104,
              iconSize: 24,
              onTap: () => settings.upload(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPanelTile(
    AppThemeData theme,
    JellyStatusPanelSettings settings,
    JellyStatusPanelStyle style,
  ) {
    return GestureDetector(
      onTap: () => settings.selectStyle(style.id),
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
            color: style.id == settings.selectedStyle.id
                ? theme.primary
                : theme.stroke,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  JellyConfigurableImage(
                    path: style.asset,
                    fit: BoxFit.contain,
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        await settings.selectStyle(style.id);
                        if (mounted) await settings.edit(context);
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.surface.withValues(alpha: 0.9),
                        ),
                        child: Center(
                          child: DsIcon(
                            DsIconKind.edit,
                            size: 14,
                            color: theme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 2),
            Text(
              style.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.label.copyWith(color: theme.text),
            ),
          ],
        ),
      ),
    );
  }

  /// 资源条尾部的“添加自定义资源”占位块
  Widget _addTile(
    AppThemeData theme, {
    required double width,
    required double height,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: theme.stroke),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: DsIcon(DsIconKind.plus, size: iconSize, color: theme.primary),
        ),
      ),
    );
  }
}
