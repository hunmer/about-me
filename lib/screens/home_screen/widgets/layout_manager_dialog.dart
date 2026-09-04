import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/home_layout_manager.dart';
import 'package:aboutme/screens/home_screen/models/layout_config.dart';
import 'package:aboutme/screens/home_screen/models/home_item.dart';
import '../../../../core/services/toast_service.dart';

/// 布局管理对话框
///
/// 显示所有保存的布局配置，支持切换、重命名和删除
class LayoutManagerDialog extends StatefulWidget {
  final VoidCallback? onLayoutChanged;

  const LayoutManagerDialog({super.key, this.onLayoutChanged});

  @override
  State<LayoutManagerDialog> createState() => _LayoutManagerDialogState();
}

class _LayoutManagerDialogState extends State<LayoutManagerDialog> {
  final HomeLayoutManager _layoutManager = HomeLayoutManager();
  List<LayoutConfig> _layouts = [];
  bool _isLoading = true;
  String? _currentLayoutId;

  @override
  void initState() {
    super.initState();
    _loadLayouts();
  }

  /// 加载所有布局配置
  Future<void> _loadLayouts() async {
    try {
      final layouts = await _layoutManager.getSavedLayouts();
      final currentLayout = await _layoutManager.getCurrentLayoutConfig();

      if (mounted) {
        setState(() {
          _layouts = layouts;
          _currentLayoutId = currentLayout?.id;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        toastService.showToast('${'screens_loadLayoutFailed'.tr}：$e');
      }
    }
  }

  /// 切换到指定布局
  Future<void> _switchLayout(LayoutConfig layout) async {
    try {
      await _layoutManager.loadLayoutConfig(layout.id);
      if (mounted) {
        setState(() {
          _currentLayoutId = layout.id;
        });
        Navigator.pop(context);
        toastService.showToast(
          '${'screens_switchedToLayout'.tr}"${layout.name}"',
        );
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('${'screens_switchFailed'.tr}：$e');
      }
    }
  }

  /// 显示重命名对话框
  void _showRenameDialog(LayoutConfig layout) {
    final controller = TextEditingController(text: layout.name);
    final focus = FocusNode();

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                // 对应原 TextField 的 autofocus
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (focus.canRequestFocus) focus.requestFocus();
                });
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'screens_renameLayout'.tr,
                        textAlign: TextAlign.center,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      DSInput(
                        controller: controller,
                        focusNode: focus,
                        label: 'screens_layoutName'.tr,
                      ),
                      SizedBox(height: theme.spacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: DSButton(
                              label: 'screens_cancel'.tr,
                              variant: DSButtonVariant.outline,
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ),
                          SizedBox(width: theme.spacing.md),
                          Expanded(
                            child: DSButton(
                              label: 'screens_confirm'.tr,
                              onPressed: () async {
                                final newName = controller.text.trim();
                                if (newName.isEmpty) {
                                  toastService.showToast(
                                    'screens_pleaseEnterLayoutName'.tr,
                                  );
                                  return;
                                }

                                Navigator.pop(dialogContext);

                                try {
                                  await _layoutManager.renameLayoutConfig(
                                    layout.id,
                                    newName,
                                  );
                                  await _loadLayouts();
                                  if (mounted) {
                                    toastService.showToast(
                                      'screens_renameSuccess'.tr,
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    toastService.showToast(
                                      'screens_saveFailed'.tr,
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    ).then((_) {
      controller.dispose();
      focus.dispose();
    });
  }

  /// 确认删除布局
  void _confirmDelete(LayoutConfig layout) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSDialog(
            title: 'screens_confirmDelete'.tr,
            message: 'screens_confirmDeleteLayout'.trParams({
              'layoutName': layout.name,
            }),
            cancelText: 'screens_cancel'.tr,
            confirmText: 'screens_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () async {
              Navigator.pop(context);

              try {
                await _layoutManager.deleteLayoutConfig(layout.id);
                await _loadLayouts();
                // 通知外部重新加载布局列表
                widget.onLayoutChanged?.call();
                if (mounted) {
                  toastService.showToast('screens_deleteSuccess'.tr);
                }
              } catch (e) {
                if (mounted) {
                  toastService.showToast('screens_saveFailed'.tr);
                }
              }
            },
          ),
    );
  }

  /// 显示新建布局对话框
  void _showCreateLayoutDialog() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => _CreateLayoutDialog(
            onLayoutCreated: (newLayoutId) {
              _loadLayouts();
              // 通知外部切换到新布局
              widget.onLayoutChanged?.call();
              Navigator.pop(context); // 关闭布局管理对话框
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 480),
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'screens_layoutManagement'.tr,
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.lg),
                  Flexible(
                    child:
                        _isLoading
                            ? const Center(child: DSLoadingDots())
                            : _layouts.isEmpty
                            ? Center(
                              child: DSEmptyState(
                                emoji: '🗂️',
                                title: 'screens_noSavedLayouts'.tr,
                                message: 'screens_saveFirstLayoutHint'.tr,
                              ),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _layouts.length,
                              itemBuilder: (context, index) {
                                return _buildLayoutRow(
                                  context,
                                  theme,
                                  _layouts[index],
                                );
                              },
                            ),
                  ),
                  SizedBox(height: theme.spacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          label: 'screens_newLayout'.tr,
                          icon: DsIconKind.plus,
                          onPressed: _showCreateLayoutDialog,
                        ),
                      ),
                      SizedBox(width: theme.spacing.md),
                      Expanded(
                        child: DSButton(
                          label: 'screens_close'.tr,
                          variant: DSButtonVariant.outline,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建单个布局行
  Widget _buildLayoutRow(
    BuildContext context,
    AppThemeData theme,
    LayoutConfig layout,
  ) {
    final isActive = layout.id == _currentLayoutId;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Pressable(
        onPressed: isActive ? null : () => _switchLayout(layout),
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return JellyBox(
            radius: theme.radii.lg,
            raised: false,
            color:
                isActive
                    ? theme.primary.mixWhite(0.9)
                    : (pressed
                        ? theme.surfaceAlt.withValues(alpha: 0.6)
                        : null),
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm,
            ),
            child: Row(
              children: [
                DsIcon(
                  isActive ? DsIconKind.check : DsIconKind.layers,
                  size: 22,
                  color: isActive ? theme.primary : theme.textSub,
                ),
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        layout.name,
                        style: DsTypography.body.copyWith(
                          color: theme.text,
                          fontWeight: isActive ? FontWeight.bold : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${layout.items.length} 个组件 · ${layout.gridCrossAxisCount} 列网格',
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                      Text(
                        '更新：${dateFormat.format(layout.updatedAt)}',
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                // DSPopover 自带点击触发，child 须为纯视觉组件
                DSPopover(
                  width: 190,
                  contentBuilder: (popoverContext, close) {
                    final popoverTheme = DSThemeBridge.resolve(popoverContext);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isActive)
                          _MenuAction(
                            icon: DsIconKind.refresh,
                            label: 'screens_switchToThisLayout'.tr,
                            theme: popoverTheme,
                            onTap: () {
                              close();
                              _switchLayout(layout);
                            },
                          ),
                        _MenuAction(
                          icon: DsIconKind.edit,
                          label: 'screens_rename'.tr,
                          theme: popoverTheme,
                          onTap: () {
                            close();
                            _showRenameDialog(layout);
                          },
                        ),
                        _MenuAction(
                          icon: DsIconKind.trash,
                          label: 'screens_delete'.tr,
                          theme: popoverTheme,
                          danger: true,
                          onTap: () {
                            close();
                            _confirmDelete(layout);
                          },
                        ),
                      ],
                    );
                  },
                  child: JellyBox(
                    width: 36,
                    height: 36,
                    radius: theme.radii.md,
                    raised: false,
                    color: theme.surfaceAlt,
                    child: Center(
                      child: DsIcon(
                        DsIconKind.more,
                        size: 18,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 气泡菜单行
class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.danger = false,
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.text;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: pressed ? theme.surfaceAlt : null,
            borderRadius: theme.radii.sm,
          ),
          child: Row(
            children: [
              DsIcon(icon, size: 16, color: accent),
              SizedBox(width: theme.spacing.sm),
              Text(label, style: DsTypography.caption.copyWith(color: accent)),
            ],
          ),
        );
      },
    );
  }
}

/// 新建布局对话框
class _CreateLayoutDialog extends StatefulWidget {
  final ValueChanged<String> onLayoutCreated;

  const _CreateLayoutDialog({required this.onLayoutCreated});

  @override
  State<_CreateLayoutDialog> createState() => _CreateLayoutDialogState();
}

class _CreateLayoutDialogState extends State<_CreateLayoutDialog> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final HomeLayoutManager _layoutManager = HomeLayoutManager();

  @override
  void initState() {
    super.initState();
    // 对应原 TextField 的 autofocus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// 创建布局
  Future<void> _createLayout() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      toastService.showToast('screens_pleaseEnterLayoutName'.tr);
      return;
    }

    try {
      // 创建空白布局
      final newItems = <HomeItem>[];

      // 保存新布局
      final newLayoutId = await _layoutManager.saveLayoutAs(
        name,
        newItems,
        _layoutManager.gridCrossAxisCount,
      );

      if (mounted) {
        toastService.showToast('screens_layoutSaved'.trParams({'name': name}));
        Navigator.pop(context);
        widget.onLayoutCreated(newLayoutId);
      }
    } catch (e) {
      if (mounted) {
        toastService.showToast('screens_saveFailed'.tr);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'screens_newLayout'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),
                DSInput(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  label: 'screens_layoutName'.tr,
                  hint: 'screens_layoutNameHint'.tr,
                ),
                SizedBox(height: theme.spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: DSButton(
                        label: 'screens_cancel'.tr,
                        variant: DSButtonVariant.outline,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: DSButton(
                        label: 'screens_create'.tr,
                        onPressed: _createLayout,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
