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
          JellyLive2dPanel.status =>
            widget.statusPanel ?? const SizedBox.shrink(),
          JellyLive2dPanel.archive => _buildArchiveStrip(theme),
          JellyLive2dPanel.appearance => _buildAppearanceStrip(theme),
        },
      ),
    );
  }

  Widget _buildAppearanceStrip(AppThemeData theme) {
    final expressions = _selectedModel.expressions;
    if (expressions.isEmpty) {
      return Text('当前模型没有可用表情', style: DsTypography.caption.copyWith(color: theme.textSub));
    }
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: expressions.length,
        separatorBuilder: (_, _) => SizedBox(width: theme.spacing.sm),
        itemBuilder: (_, index) {
          final expression = expressions[index];
          return DSButton(
            label: expression.label,
            size: DSButtonSize.sm,
            onPressed: () => _applyExpression(expression),
          );
        },
      ),
    );
  }

  Future<void> _applyExpression(Live2DExpressionDefinition expression) async {
    if (!_controller.value.isLoaded) return;
    try {
      await _controller.setExpression(expression.index);
    } on Live2DException {
      // Ignore unsupported expressions on older native runtimes.
    }
  }

  /// 档案条：头像 + 名称，点击切换档案（并即时重载对应模型）；
  /// 尾部附带跳转 Live2D 模型列表的快捷入口
  Widget _buildArchiveStrip(AppThemeData theme) {
    final archives = Live2DPlugin.instance.archives;
    if (archives.isEmpty) {
      return SizedBox(
        height: 32,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'screens_jellyLive2dNoArchives'.tr,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.label.copyWith(color: theme.textSub),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              DSIconButton(
                icon: DsIconKind.grid,
                tooltip: 'screens_jellyLive2dOpenModelList'.tr,
                size: 28,
                onPressed: _openModelList,
              ),
            ],
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
          _modelListTile(theme),
        ],
      ),
    );
  }

  /// 档案条尾部：跳转 Live2D 模型列表的快捷入口
  Widget _modelListTile(AppThemeData theme) {
    return GestureDetector(
      onTap: _openModelList,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.stroke),
            ),
            child: Center(
              child: DsIcon(DsIconKind.grid, size: 20, color: theme.primary),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              'screens_jellyLive2dOpenModelList'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DsTypography.caption.copyWith(color: theme.text),
            ),
          ),
        ],
      ),
    );
  }

  /// 打开 Live2D 主界面（存档管理）；返回后刷新资源条，
  /// 选中档案的模型被改动时重载模型
  Future<void> _openModelList() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const Live2DMainScreen()),
    );
    if (!mounted) return;
    setState(() {});
    final model = modelDefinitionForArchive(
      Live2DPlugin.instance.selected,
      importedModels: Live2DPlugin.instance.importedModels,
    );
    if (model != null) await _selectModel(model);
  }

  Widget _archiveTile(AppThemeData theme, Live2DArchive archive) {
    final selected = archive.id == Live2DPlugin.instance.selectedId;
    final cover = archive.coverPath;
    return GestureDetector(
      onTap: () => _selectArchive(archive),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
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
              // 右上角快速设置角标：打开该档案的编辑弹层
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _editArchive(archive),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.surface,
                      border: Border.all(color: theme.stroke),
                    ),
                    child: Center(
                      child: DsIcon(
                        DsIconKind.edit,
                        size: 9,
                        color: theme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

  /// 打开档案编辑弹层（封面/名称/模型/Agent），与设置页的编辑入口同构；
  /// 关闭后刷新资源条，选中档案的模型被改动或档案被删除时重载模型
  Future<void> _editArchive(Live2DArchive archive) async {
    VoidCallback? saveArchive;
    VoidCallback? deleteArchive;
    await SmoothBottomSheet.showForm<void>(
      context: context,
      title: 'live2d_editArchiveTitle'.tr,
      child: Live2DArchiveFormScreen(
        archiveId: archive.id,
        embedInSheet: true,
        onReady: (save) => saveArchive = save,
        onDeleteReady: (delete) => deleteArchive = delete,
      ),
      onSave: () => saveArchive?.call(),
      onDelete: () => deleteArchive?.call(),
    );
    if (!mounted) return;
    setState(() {});
    final model = modelDefinitionForArchive(
      Live2DPlugin.instance.selected,
      importedModels: Live2DPlugin.instance.importedModels,
    );
    if (model != null) await _selectModel(model);
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
