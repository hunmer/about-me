import 'package:aboutme/screens/home_screen/models/home_widget_item.dart';
import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_folder_item.dart';
import 'package:aboutme/screens/home_screen/managers/home_layout_manager.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/models/home_item.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'home_grid.dart';
import 'add_widget_dialog.dart';

/// 文件夹内容对话框
class FolderDialog extends StatefulWidget {
  final HomeFolderItem folder;

  const FolderDialog({super.key, required this.folder});

  @override
  State<FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<FolderDialog> {
  final HomeLayoutManager _layoutManager = HomeLayoutManager();

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // Builder 让内容在主题桥之内构建，可读取 AppTheme
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.md),
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              children: [
                _buildHeader(context, theme),

                // 文件夹内容网格
                Expanded(
                  child: ListenableBuilder(
                    listenable: _layoutManager,
                    builder: (context, child) {
                      // 重新获取最新的文件夹数据
                      final folder = _layoutManager.findItem(widget.folder.id);
                      if (folder == null || folder is! HomeFolderItem) {
                        return Center(
                          child: Text(
                            'screens_folderHasBeenDeleted'.tr,
                            style: DsTypography.body.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        );
                      }

                      if (folder.children.isEmpty) {
                        return _buildEmptyState();
                      }

                      return HomeGrid(
                        items: folder.children,
                        crossAxisCount: 3, // 文件夹内使用 3 列布局
                        onReorder: (oldIndex, newIndex) {
                          _layoutManager.reorderInFolder(
                            folder.id,
                            oldIndex,
                            newIndex,
                          );
                        },
                        onItemLongPress: (item) {
                          _showItemOptions(item);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 标题栏（替代原 AppBar）
  Widget _buildHeader(BuildContext context, AppThemeData theme) {
    final showBack = !(UniversalPlatform.isAndroid || UniversalPlatform.isIOS);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Row(
        children: [
          if (showBack) ...[
            DSIconButton(
              icon: DsIconKind.chevronLeft,
              size: 40,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              onPressed: () => Navigator.of(context).pop(),
            ),
            SizedBox(width: theme.spacing.xs),
          ],
          // 文件夹图标为持久化的 Material IconData，保留
          Icon(widget.folder.icon, color: widget.folder.color, size: 24),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              widget.folder.name,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
          ),
          DSIconButton(
            icon: DsIconKind.plus,
            size: 40,
            onPressed: _showAddToFolderOptions,
            tooltip: 'screens_addToFolder'.tr,
          ),
          SizedBox(width: theme.spacing.xs),
          DSIconButton(
            icon: DsIconKind.edit,
            size: 40,
            onPressed: _editFolder,
            tooltip: 'screens_editFolder'.tr,
          ),
          SizedBox(width: theme.spacing.xs),
          DSIconButton(
            icon: DsIconKind.close,
            size: 40,
            color: theme.surfaceAlt,
            iconColor: theme.textSub,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// 显示添加到文件夹选项
  void _showAddToFolderOptions() {
    final theme = DSThemeBridge.resolve(context);
    SmoothBottomSheet.show(
      context: context,
      backgroundColor: theme.surface,
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SheetActionRow(
                      icon: DsIconKind.grid,
                      label: 'screens_addWidget'.tr,
                      theme: theme,
                      onTap: () {
                        Navigator.pop(context);
                        _showAddWidgetToFolder();
                      },
                    ),
                    _SheetActionRow(
                      icon: DsIconKind.download,
                      label: 'screens_moveFromHomePage'.tr,
                      theme: theme,
                      onTap: () {
                        Navigator.pop(context);
                        _showMoveFromHomeOptions();
                      },
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }

  /// 显示添加小组件到文件夹
  void _showAddWidgetToFolder() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => AddWidgetDialog(folderId: widget.folder.id),
    );
  }

  /// 显示从主页移入选项
  void _showMoveFromHomeOptions() {
    // 获取主页上的所有项目（排除当前文件夹）
    final homeItems =
        _layoutManager.items
            .where((item) => item.id != widget.folder.id)
            .toList();

    if (homeItems.isEmpty) {
      Toast.warning('screens_noItemsOnHome'.tr);
      return;
    }

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => _MoveFromHomeDialog(
            items: homeItems,
            folderId: widget.folder.id,
            layoutManager: _layoutManager,
          ),
    );
  }

  /// 编辑文件夹
  void _editFolder() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => _EditFolderDialog(
            folder: widget.folder,
            layoutManager: _layoutManager,
          ),
    );
  }

  /// 显示项目选项
  void _showItemOptions(HomeItem item) {
    final theme = DSThemeBridge.resolve(context);
    SmoothBottomSheet.show(
      context: context,
      backgroundColor: theme.surface,
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SheetActionRow(
                      icon: DsIconKind.share,
                      label: 'screens_moveOutOfFolder'.tr,
                      theme: theme,
                      onTap: () async {
                        Navigator.pop(context);
                        _layoutManager.removeFromFolder(
                          item.id,
                          widget.folder.id,
                        );
                        await _layoutManager.saveLayout();
                        Toast.success('screens_movedToHomePage'.tr);
                      },
                    ),
                    _SheetActionRow(
                      icon: DsIconKind.trash,
                      label: 'screens_delete'.tr,
                      theme: theme,
                      danger: true,
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDeleteItem(item);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }

  /// 确认删除项目
  void _confirmDeleteItem(HomeItem item) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSDialog(
            title: 'screens_confirmDelete'.tr,
            message: 'screens_confirmDeleteThisItem'.tr,
            cancelText: 'screens_cancel'.tr,
            confirmText: 'screens_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () async {
              Navigator.pop(context);
              // 从文件夹的 children 中删除
              final folder =
                  _layoutManager.findItem(widget.folder.id) as HomeFolderItem;
              final updatedFolder = folder.copyWith(
                children:
                    folder.children.where((c) => c.id != item.id).toList(),
              );
              _layoutManager.updateItem(widget.folder.id, updatedFolder);
              await _layoutManager.saveLayout();
              Toast.success('screens_deleteSuccess'.tr);
            },
          ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: DSEmptyState(
        emoji: '📂',
        title: 'screens_folderIsEmpty'.tr,
        message: 'screens_clickToAddContent'.tr,
      ),
    );
  }
}

/// 底部抽屉操作行：果冻图标底座 + 文案，danger 时红色
class _SheetActionRow extends StatelessWidget {
  const _SheetActionRow({
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
    final accent = danger ? theme.danger : theme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return JellyBox(
            radius: theme.radii.lg,
            raised: false,
            color: pressed ? accent.mixWhite(0.9) : theme.surfaceAlt,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.md,
            ),
            child: Row(
              children: [
                DsIcon(icon, size: 20, color: accent),
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: DsTypography.body.copyWith(
                      color: danger ? theme.danger : theme.text,
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

/// 从主页移入对话框
class _MoveFromHomeDialog extends StatefulWidget {
  final List<HomeItem> items;
  final String folderId;
  final HomeLayoutManager layoutManager;

  const _MoveFromHomeDialog({
    required this.items,
    required this.folderId,
    required this.layoutManager,
  });

  @override
  State<_MoveFromHomeDialog> createState() => _MoveFromHomeDialogState();
}

class _MoveFromHomeDialogState extends State<_MoveFromHomeDialog> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 460),
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'screens_moveFromHomePage'.tr,
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: theme.spacing.sm),
                    child: Text(
                      'screens_selectItemsToMoveToFolder'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ),
                  SizedBox(height: theme.spacing.lg),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) {
                        return _buildItemRow(
                          context,
                          theme,
                          widget.items[index],
                        );
                      },
                    ),
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
                          label: 'screens_moveIn'.trParams({
                            'count': _selectedIds.length.toString(),
                          }),
                          onPressed:
                              _selectedIds.isEmpty
                                  ? null
                                  : () {
                                    _moveSelectedItems();
                                    Navigator.pop(context);
                                  },
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

  /// 构建可勾选的项目行
  Widget _buildItemRow(
    BuildContext context,
    AppThemeData theme,
    HomeItem item,
  ) {
    final isSelected = _selectedIds.contains(item.id);

    Widget? leadingIcon;
    String displayName;

    if (item is HomeWidgetItem) {
      final registry = HomeWidgetRegistry();
      final widget = registry.getWidget(item.widgetId);
      if (widget != null) {
        // 注册表图标为持久化 IconData，保留 Material Icon
        leadingIcon = Icon(widget.icon, color: widget.color, size: 20);
        displayName = widget.name;
      } else {
        displayName = item.widgetId;
      }
    } else if (item is HomeFolderItem) {
      leadingIcon = Icon(item.icon, color: item.color, size: 20);
      displayName = item.name;
    } else {
      displayName = 'Unknown';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Pressable(
        onPressed: () {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(item.id);
            } else {
              _selectedIds.add(item.id);
            }
          });
        },
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return JellyBox(
            radius: theme.radii.lg,
            raised: false,
            color:
                isSelected
                    ? theme.primary.mixWhite(0.88)
                    : (pressed
                        ? theme.surfaceAlt.withValues(alpha: 0.6)
                        : null),
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm,
            ),
            child: Row(
              children: [
                DSCheckbox(
                  value: isSelected,
                  onChanged: (_) {
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(item.id);
                      } else {
                        _selectedIds.add(item.id);
                      }
                    });
                  },
                ),
                SizedBox(width: theme.spacing.md),
                if (leadingIcon != null) ...[
                  leadingIcon,
                  SizedBox(width: theme.spacing.sm),
                ],
                Expanded(
                  child: Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 移动选中的项目
  void _moveSelectedItems() {
    for (final itemId in _selectedIds) {
      widget.layoutManager.moveToFolder(itemId, widget.folderId);
    }

    Toast.success(
      'screens_itemsMovedToFolder'.trParams({
        'count': _selectedIds.length.toString(),
      }),
    );
  }
}

/// 编辑文件夹对话框
class _EditFolderDialog extends StatefulWidget {
  final HomeFolderItem folder;
  final HomeLayoutManager layoutManager;

  const _EditFolderDialog({required this.folder, required this.layoutManager});

  @override
  State<_EditFolderDialog> createState() => _EditFolderDialogState();
}

class _EditFolderDialogState extends State<_EditFolderDialog> {
  late TextEditingController _nameController;
  late FocusNode _nameFocus;
  late IconData _selectedIcon;
  late Color _selectedColor;

  // 常用图标列表（持久化到布局数据中的 Material IconData）
  static const List<IconData> _commonIcons = [
    Icons.folder,
    Icons.folder_special,
    Icons.work,
    Icons.school,
    Icons.home,
    Icons.favorite,
    Icons.star,
    Icons.bookmark,
    Icons.category,
    Icons.dashboard,
    Icons.widgets,
    Icons.apps,
  ];

  // 常用颜色列表
  static const List<Color> _commonColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
    Colors.lime,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder.name);
    _nameFocus = FocusNode();
    _selectedIcon = widget.folder.icon;
    _selectedColor = widget.folder.color;
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

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'screens_editFolder'.tr,
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.lg),

                  // 文件夹名称
                  DSInput(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    label: 'screens_folderName'.tr,
                  ),
                  SizedBox(height: theme.spacing.lg),

                  // 图标选择
                  Text(
                    'screens_selectIcon'.tr,
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.sm,
                    children:
                        _commonIcons.map((icon) {
                          final isSelected = icon == _selectedIcon;
                          return _IconOption(
                            icon: icon,
                            selected: isSelected,
                            theme: theme,
                            onTap: () {
                              setState(() {
                                _selectedIcon = icon;
                              });
                            },
                          );
                        }).toList(),
                  ),
                  SizedBox(height: theme.spacing.lg),

                  // 颜色选择
                  Text(
                    'screens_selectColor'.tr,
                    style: DsTypography.heading.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.sm,
                    children:
                        _commonColors.map((color) {
                          final isSelected =
                              color.toARGB32() == _selectedColor.toARGB32();
                          return _ColorOption(
                            color: color,
                            selected: isSelected,
                            theme: theme,
                            onTap: () {
                              setState(() {
                                _selectedColor = color;
                              });
                            },
                          );
                        }).toList(),
                  ),
                  SizedBox(height: theme.spacing.xl),

                  // 操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          label: 'screens_cancel'.tr,
                          variant: DSButtonVariant.outline,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(width: theme.spacing.md),
                      Expanded(
                        child: DSButton(
                          label: 'screens_save'.tr,
                          onPressed: _saveFolderChanges,
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

  /// 保存文件夹修改
  Future<void> _saveFolderChanges() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      Toast.error('screens_pleaseEnterFolderName'.tr);
      return;
    }

    // 创建更新后的文件夹
    final updatedFolder = widget.folder.copyWith(
      name: newName,
      icon: _selectedIcon,
      color: _selectedColor,
    );

    // 更新文件夹
    widget.layoutManager.updateItem(widget.folder.id, updatedFolder);
    await widget.layoutManager.saveLayout();

    Navigator.pop(context);
    Toast.success('screens_folderUpdated'.tr);
  }
}

/// 图标选项：果冻方底座（icon 为持久化的 Material IconData，保留）
class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.icon,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final AppThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? theme.primary.mixWhite(0.88) : theme.surfaceAlt,
          borderRadius: theme.radii.lg,
          border: Border.all(
            color: selected ? theme.primary : theme.stroke,
            width: selected ? 2 : 1.4,
          ),
        ),
        child: Icon(
          icon,
          size: 24,
          color: selected ? theme.primary : theme.textSub,
        ),
      ),
    );
  }
}

/// 颜色选项：圆形色板，选中态主色描边
class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final AppThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? theme.primary : theme.stroke,
            width: selected ? 3 : 1.4,
          ),
        ),
      ),
    );
  }
}
