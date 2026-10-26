import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/home_layout_manager.dart';
import 'package:aboutme/screens/home_screen/models/home_folder_item.dart';
import '../../../../core/services/toast_service.dart';

/// 创建文件夹对话框
class CreateFolderDialog extends StatefulWidget {
  const CreateFolderDialog({super.key});

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  IconData _selectedIcon = Icons.folder;
  Color _selectedColor = Colors.blue;

  // 常用图标列表（持久化到布局数据中的 Material IconData）
  static const List<IconData> _folderIcons = [
    Icons.folder,
    Icons.folder_special,
    Icons.work,
    Icons.home,
    Icons.favorite,
    Icons.star,
    Icons.category,
    Icons.shopping_bag,
    Icons.school,
    Icons.sports_esports,
  ];

  // 常用颜色列表
  static const List<Color> _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
    Colors.brown,
  ];

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

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // Builder 让表单在主题桥之内构建，可读取 AppTheme
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
                    'screens_createNewFolder'.tr,
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.lg),

                  // 文件夹名称
                  DSInput(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    label: 'screens_folderName'.tr,
                    hint: 'screens_enterFolderName'.tr,
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
                        _folderIcons.map((icon) {
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
                        _colors.map((color) {
                          final isSelected = color == _selectedColor;
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
                          label: 'screens_create'.tr,
                          onPressed: _createFolder,
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

  /// 创建文件夹
  void _createFolder() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      toastService.showToast('screens_pleaseEnterFolderName'.tr);
      return;
    }

    final layoutManager = HomeLayoutManager();

    // 创建文件夹
    final folder = HomeFolderItem(
      id: layoutManager.generateId(),
      name: name,
      icon: _selectedIcon,
      color: _selectedColor,
    );

    // 添加到布局
    layoutManager.addItem(folder);
    await layoutManager.saveLayout();

    // 关闭对话框
    Navigator.of(context).pop();

    // 显示提示
    toastService.showToast('screens_folderCreated'.trParams({'name': name}));
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
