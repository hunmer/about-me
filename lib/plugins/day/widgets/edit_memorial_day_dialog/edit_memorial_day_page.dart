import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/form_fields/index.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/plugins/day/models/memorial_day.dart';
import 'package:aboutme/core/route/route_history_manager.dart';

/// 纪念日新建/编辑页
///
/// 笔记不在本页编辑（统一在详情页管理），保存时保留原笔记与时间戳。
class EditMemorialDayPage extends StatefulWidget {
  final MemorialDay? memorialDay;

  const EditMemorialDayPage({super.key, this.memorialDay});

  @override
  State<EditMemorialDayPage> createState() => _EditMemorialDayPageState();
}

class _EditMemorialDayPageState extends State<EditMemorialDayPage> {
  late TextEditingController _titleController;
  late DateTime _selectedDate;
  late Color _selectedColor;
  String? _backgroundImageUrl;
  IconData? _selectedIcon;
  Color? _selectedIconColor;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memorialDay?.title);
    _selectedDate = widget.memorialDay?.targetDate ?? DateTime.now();
    _selectedColor = widget.memorialDay?.backgroundColor ?? Colors.blue[300]!;
    _backgroundImageUrl = widget.memorialDay?.backgroundImageUrl;
    _selectedIcon = widget.memorialDay?.icon;
    _selectedIconColor = widget.memorialDay?.iconColor;
    _updateRouteContext();
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前状态
  void _updateRouteContext() {
    if (widget.memorialDay == null) {
      RouteHistoryManager.updateCurrentContext(
        pageId: "/day_new",
        title: '新建纪念日',
        params: {},
      );
    } else {
      final memorial = widget.memorialDay!;
      final dateStr = _formatDate(memorial.targetDate);
      RouteHistoryManager.updateCurrentContext(
        pageId: "/day_detail",
        title: '纪念日详情 - ${memorial.title}',
        params: {'id': memorial.id, 'title': memorial.title, 'date': dateStr},
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _save(BuildContext context) {
    if (_titleController.text.trim().isEmpty) {
      showDSToast(
        context,
        message: 'day_titleRequired'.tr,
        type: DSToastType.warning,
      );
      return;
    }
    final memorialDay = MemorialDay(
      id: widget.memorialDay?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      targetDate: _selectedDate,
      // 笔记统一在详情页管理，编辑保存时保留原值
      notes: widget.memorialDay?.notes ?? [],
      noteDates: widget.memorialDay?.noteDates ?? [],
      backgroundColor: _selectedColor,
      backgroundImageUrl: _backgroundImageUrl,
      creationDate: widget.memorialDay?.creationDate ?? DateTime.now(),
      icon: _selectedIcon,
      iconColor: _selectedIconColor,
    );

    Navigator.of(
      context,
    ).pop(DialogResult(action: DialogAction.save, memorialDay: memorialDay));
  }

  void _confirmDelete() {
    Navigator.of(context).pop(const DialogResult(action: DialogAction.delete));
  }

  /// 删除确认（手绘对话框，危险色确认钮）
  void _showDeleteConfirm() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSDialog(
        title: 'day_deleteMemorialDay'.tr,
        message: 'day_deleteConfirmation'.tr,
        confirmText: 'day_delete'.tr,
        cancelText: 'day_cancel'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () {
          Navigator.of(dialogContext).pop();
          _confirmDelete();
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.memorialDay != null;

    return SuperCupertinoNavigationWrapper(
      title: Text(
        isEditing ? 'day_editMemorialDay'.tr : 'day_addMemorialDay'.tr,
      ),
      previousPageTitle: 'day_memorialDays'.tr,
      // SuperAppBar 的 actions 经 Overlay 渲染,DS 组件需自带 DSThemeBridge
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) => DSButton(
              label: 'day_save'.tr,
              size: DSButtonSize.sm,
              onPressed: () => _save(context),
            ),
          ),
        ),
      ],
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconAvatarRowField(
                    name: 'memorial_icon',
                    initialIcon: _selectedIcon,
                    initialIconColor: _selectedIconColor,
                    initialAvatarUrl: _backgroundImageUrl,
                    onChanged: (value) {
                      setState(() {
                        _selectedIcon = value['icon'] as IconData?;
                        _selectedIconColor = value['iconColor'] as Color?;
                        _backgroundImageUrl = value['avatarUrl'] as String?;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  TextInputField(
                    controller: _titleController,
                    labelText: 'day_title'.tr,
                    hintText: 'day_enterTitle'.tr,
                    autofocus: !isEditing,
                  ),
                  const SizedBox(height: 24),

                  // 目标日期
                  DatePickerField(
                    date: _selectedDate,
                    onTap: _selectDate,
                    formattedDate: _formatDate(_selectedDate),
                    placeholder: 'day_selectDate'.tr,
                    labelText: 'day_targetDate'.tr,
                  ),
                  const SizedBox(height: 32),

                  // 删除按钮（仅编辑模式显示）
                  if (isEditing)
                    DSThemeBridge(
                      child: Builder(
                        builder: (context) => DSButton(
                          label: 'day_delete'.tr,
                          variant: DSButtonVariant.destructive,
                          icon: DsIconKind.trash,
                          expand: true,
                          onPressed: _showDeleteConfirm,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 对话框操作结果
enum DialogAction { save, delete, cancel }

/// 对话框返回结果
class DialogResult {
  final DialogAction action;
  final MemorialDay? memorialDay;

  const DialogResult({required this.action, this.memorialDay});
}
