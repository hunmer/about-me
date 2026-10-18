import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:aboutme/widgets/picker/icon_picker_dialog.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:floating_ball_plugin/floating_ball_plugin.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/constants/app_icons.dart';
import 'package:aboutme/core/action/action_manager.dart';
import 'package:aboutme/core/action/widgets/action_selector_dialog.dart';
import 'package:aboutme/core/action/models/action_instance.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 悬浮按钮编辑对话框（手绘风）
class FloatingButtonEditDialog extends StatefulWidget {
  final FloatingBallButtonData? initialButton;
  final int? index;

  const FloatingButtonEditDialog({
    super.key,
    this.initialButton,
    this.index,
  });

  /// 统一弹窗入口：走 showDSDialog 获得手绘入场与遮罩
  static Future<FloatingBallButtonData?> show(
    BuildContext context, {
    FloatingBallButtonData? initialButton,
    int? index,
  }) {
    return showDSDialog<FloatingBallButtonData>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => FloatingButtonEditDialog(
        initialButton: initialButton,
        index: index,
      ),
    );
  }

  @override
  State<FloatingButtonEditDialog> createState() =>
      _FloatingButtonEditDialogState();
}

class _FloatingButtonEditDialogState extends State<FloatingButtonEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _dataController;
  String _selectedIcon = 'ic_menu_info_details';
  String? _imageBase64;

  // 选中的动作结果
  ActionSelectorResult? _selectedActionResult;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialButton?.title ?? '',
    );
    _selectedIcon = widget.initialButton?.icon ?? 'ic_menu_info_details';
    _imageBase64 = widget.initialButton?.image;

    // 初始化执行数据
    if (widget.initialButton?.data != null) {
      _dataController = TextEditingController(
        text: jsonEncode(widget.initialButton!.data),
      );

      // 尝试从已有数据创建 ActionSelectorResult
      final data = widget.initialButton!.data!;
      final actionId = data['action'] as String?;
      if (actionId != null) {
        _selectedActionResult = ActionSelectorResult(
          singleAction: ActionInstance.create(
            actionId: actionId,
            data: data['args'] as Map<String, dynamic>? ?? {},
          ),
        );
      }
    } else {
      _dataController = TextEditingController(text: '{}');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  /// 打开动作选择器
  Future<void> _openActionSelector() async {
    // 确保 ActionManager 已初始化
    final actionManager = ActionManager();
    if (!actionManager.isInitialized) {
      await actionManager.initialize();
    }

    if (!mounted) return;

    final result = await ActionSelectorDialog.show(
      context,
      initialValue: _selectedActionResult,
      showGroupEditor: false,
    );

    if (result != null) {
      setState(() {
        _selectedActionResult = result;
        // 更新执行数据
        _updateDataFromActionResult(result);
      });
    }
  }

  /// 根据动作结果更新执行数据
  void _updateDataFromActionResult(ActionSelectorResult result) {
    Map<String, dynamic> data = {};

    if (result.singleAction != null) {
      data = {
        'action': result.singleAction!.actionId,
        if (result.singleAction!.data.isNotEmpty)
          'args': result.singleAction!.data,
      };
    } else if (result.actionGroup != null) {
      data = {
        'action': 'executeGroup',
        'args': {'groupId': result.actionGroup!.id},
      };
    }

    _dataController.text = jsonEncode(data);
  }

  /// 获取当前选中动作的显示名称
  String _getSelectedActionLabel() {
    if (_selectedActionResult == null || _selectedActionResult!.isEmpty) {
      return 'floating_ball_tapToSelectAction'.tr;
    }

    if (_selectedActionResult!.singleAction != null) {
      final actionId = _selectedActionResult!.singleAction!.actionId;
      // 尝试获取动作定义的标题
      if (_selectedActionResult!.selectedDefinition != null) {
        return _selectedActionResult!.selectedDefinition!.title;
      }
      return actionId;
    }

    if (_selectedActionResult!.actionGroup != null) {
      return 'floating_ball_actionGroupLabel'.trParams({
        'title': _selectedActionResult!.actionGroup!.title,
      });
    }

    return 'floating_ball_tapToSelectAction'.tr;
  }

  /// 选择图片
  Future<void> _pickImage() async {
    final result = await ImagePickerDialog.show<Map<String, dynamic>>(
      context,
      saveDirectory: 'floating_buttons',
      enableCrop: true,
      cropAspectRatio: 1.0,
      enableCompression: true,
      compressionQuality: 80,
    );

    if (result != null && result['bytes'] != null) {
      final bytes = result['bytes'] as Uint8List;
      setState(() {
        _imageBase64 = base64Encode(bytes);
      });
    }
  }

  /// 清除图片
  void _clearImage() {
    setState(() {
      _imageBase64 = null;
    });
  }

  /// 选择图标
  Future<void> _pickIcon() async {
    // 将字符串转换为 IconData
    IconData currentIcon = Icons.help_outline;
    for (var entry in AppIcons.predefinedIcons.entries) {
      if (entry.key == _selectedIcon) {
        currentIcon = entry.value;
        break;
      }
    }

    final result = await showIconPickerDialog(
      context,
      currentIcon,
      enableIconToImage: true,
      forceConvertToImage: true,
    );

    if (result != null) {
      setState(() {
        if (result is IconData) {
          // 仅选择图标
          _selectedIcon = _getIconString(result);
        } else if (result is Map<String, dynamic>) {
          // 图标转图片
          final bytes = result['bytes'] as Uint8List;
          final icon = result['icon'] as IconData;
          _imageBase64 = base64Encode(bytes);
          _selectedIcon = _getIconString(icon);
        }
      });
    }
  }

  /// 获取图标字符串
  String _getIconString(IconData icon) {
    for (var entry in AppIcons.predefinedIcons.entries) {
      if (entry.value == icon) {
        return entry.key;
      }
    }
    return 'ic_menu_info_details';
  }

  /// 清除图标
  void _clearIcon() {
    setState(() {
      _selectedIcon = 'ic_menu_info_details';
    });
  }

  /// 保存按钮
  void _save() {
    if (_titleController.text.trim().isEmpty) {
      toastService.showToast('floating_ball_pleaseEnterTitle'.tr);
      return;
    }

    // 解析执行数据
    Map<String, dynamic>? data;
    try {
      final dataText = _dataController.text.trim();
      if (dataText.isNotEmpty && dataText != '{}') {
        data = jsonDecode(dataText) as Map<String, dynamic>;
      }
    } catch (e) {
      toastService.showToast(
        'floating_ball_invalidJson'.trParams({'error': e.toString()}),
      );
      return;
    }

    final button = FloatingBallButtonData(
      title: _titleController.text.trim(),
      icon: _selectedIcon,
      data: data,
      image: _imageBase64,
    );

    Navigator.of(context).pop(button);
  }

  /// 清空确认
  void _confirmClear() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSDialog(
        title: 'floating_ball_clearIconImage'.tr,
        message: 'floating_ball_confirmClearIconImage'.tr,
        cancelText: 'floating_ball_cancel'.tr,
        confirmText: 'floating_ball_clear'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onCancel: () => Navigator.of(dialogContext).pop(),
        onConfirm: () {
          _clearImage();
          _clearIcon();
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  /// 构建图标预览
  Widget _buildIconPreview(AppThemeData theme) {
    // 如果有图片，优先显示图片
    if (_imageBase64 != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          base64Decode(_imageBase64!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.image_not_supported, color: theme.textSub);
          },
        ),
      );
    }

    // 否则显示图标
    IconData iconData = Icons.help_outline;
    for (var entry in AppIcons.predefinedIcons.entries) {
      if (entry.key == _selectedIcon) {
        iconData = entry.value;
        break;
      }
    }

    return Icon(iconData, color: theme.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      // 大容器走手绘面板：纸底 + 淡排线 + 墨线框
      // （showDSDialog 外层已包 WiredDraw，这里消费描画进度做墨线入场）
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.xxl,
        padding: EdgeInsets.all(theme.spacing.lg),
        progress: WiredDrawTransition.progressOf(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Text(
                widget.index == null
                    ? 'floating_ball_addButton'.tr
                    : 'floating_ball_editButton'.tr,
                textAlign: TextAlign.center,
                style: DsTypography.title.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.lg),

              // 按钮标题
              DSInput(
                controller: _titleController,
                label: 'floating_ball_buttonTitle'.tr,
              ),
              SizedBox(height: theme.spacing.lg),

              // 按钮图标设置
              _buildIconSection(theme),
              SizedBox(height: theme.spacing.sm),

              // 操作按钮组
              Row(
                children: [
                  // 选择图标按钮
                  Expanded(
                    child: DSButton(
                      label: 'floating_ball_selectIcon'.tr,
                      variant: DSButtonVariant.secondary,
                      size: DSButtonSize.sm,
                      icon: DsIconKind.tag,
                      onPressed: _pickIcon,
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  // 选择图片按钮
                  Expanded(
                    child: DSButton(
                      label: _imageBase64 == null
                          ? 'floating_ball_selectImage'.tr
                          : 'floating_ball_changeImage'.tr,
                      variant: DSButtonVariant.secondary,
                      size: DSButtonSize.sm,
                      icon: DsIconKind.image,
                      onPressed: _pickImage,
                    ),
                  ),
                ],
              ),

              SizedBox(height: theme.spacing.lg),
              Container(
                height: 1,
                color: theme.textSub.withValues(alpha: 0.25),
              ),
              SizedBox(height: theme.spacing.lg),

              // 动作选择器
              _buildActionSelector(theme),
              SizedBox(height: theme.spacing.lg),

              // 执行数据
              DSInput(
                controller: _dataController,
                label: 'floating_ball_executionData'.tr,
                hint: 'floating_ball_executionDataHint'.tr,
                maxLines: 4,
              ),
              SizedBox(height: theme.spacing.xl),

              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DSButton(
                    label: 'floating_ball_cancel'.tr,
                    variant: DSButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  DSButton(
                    label: 'floating_ball_save'.tr,
                    icon: DsIconKind.check,
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 图标/图片设置区
  Widget _buildIconSection(AppThemeData theme) {
    final hasCustom =
        _imageBase64 != null || _selectedIcon != 'ic_menu_info_details';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'floating_ball_buttonIcon'.tr,
                style:
                    DsTypography.caption.copyWith(color: theme.textSub),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  // 图标预览
                  JellyBox(
                    width: 44,
                    height: 44,
                    radius: theme.radii.sm,
                    color: theme.surfaceAlt,
                    alignment: Alignment.center,
                    child: _buildIconPreview(theme),
                  ),
                  const SizedBox(width: 8),
                  // 显示选择状态
                  Expanded(
                    child: Text(
                      _imageBase64 != null
                          ? 'floating_ball_imageSet'.tr
                          : 'floating_ball_iconSet'.trParams({
                              'icon': _selectedIcon,
                            }),
                      style: DsTypography.caption.copyWith(
                        color: _imageBase64 != null
                            ? theme.success
                            : theme.textSub,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 清除按钮
        if (hasCustom)
          DSIconButton(
            icon: DsIconKind.trash,
            size: 34,
            color: theme.surfaceAlt,
            iconColor: theme.danger,
            onPressed: _confirmClear,
            tooltip: 'floating_ball_clearIconImage'.tr,
          ),
      ],
    );
  }

  /// 动作选择触发行（墨线盒 + 当前动作 + 清除/箭头）
  Widget _buildActionSelector(AppThemeData theme) {
    final hasAction =
        _selectedActionResult != null && !_selectedActionResult!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'core_selectAction'.tr,
          style: DsTypography.caption.copyWith(color: theme.textSub),
        ),
        const SizedBox(height: 4),
        Pressable(
          onPressed: _openActionSelector,
          builder: (context, states) {
            final pressed = states.contains(WidgetState.pressed);
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md,
                vertical: theme.spacing.sm,
              ),
              decoration: dsSketchDecoration(
                theme: theme,
                radius: theme.radii.lg,
                fillColor: pressed ? theme.surfaceAlt : theme.surface,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _getSelectedActionLabel(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.body.copyWith(
                        color: hasAction ? theme.text : theme.textSub,
                      ),
                    ),
                  ),
                  if (hasAction)
                    DSIconButton(
                      icon: DsIconKind.close,
                      size: 30,
                      color: theme.surfaceAlt,
                      iconColor: theme.textSub,
                      onPressed: () {
                        setState(() {
                          _selectedActionResult = null;
                          _dataController.text = '{}';
                        });
                      },
                      tooltip: 'floating_ball_clearAction'.tr,
                    ),
                  DsIcon(DsIconKind.chevronRight, color: theme.textSub),
                ],
              ),
            );
          },
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          'floating_ball_tapToSelectAction'.tr,
          style: DsTypography.caption.copyWith(color: theme.textSub),
        ),
      ],
    );
  }
}
