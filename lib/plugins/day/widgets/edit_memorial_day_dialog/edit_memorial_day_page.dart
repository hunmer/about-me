import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/form_fields/index.dart';
import 'package:aboutme/widgets/picker/circle_icon_picker.dart';
import 'package:aboutme/plugins/day/models/memorial_day.dart';
import 'package:aboutme/core/route/route_history_manager.dart';

/// 纪念日新建/编辑页
///
/// 笔记不在本页编辑（统一在详情页管理），保存时保留原笔记与时间戳。
class EditMemorialDayPage extends StatefulWidget {
  final MemorialDay? memorialDay;

  /// 以底部弹层形式嵌入（不渲染导航栏，由外壳提供标题与保存）
  final bool embedInSheet;

  /// 弹层模式下回传保存动作（外壳"保存"按钮触发）
  final void Function(VoidCallback save)? onReady;

  const EditMemorialDayPage({
    super.key,
    this.memorialDay,
    this.embedInSheet = false,
    this.onReady,
  });

  @override
  State<EditMemorialDayPage> createState() => _EditMemorialDayPageState();
}

class _EditMemorialDayPageState extends State<EditMemorialDayPage> {
  late TextEditingController _titleController;
  late TextEditingController _intervalController;
  late DateTime _selectedDate;
  late Color _selectedColor;
  String? _backgroundImageUrl;
  IconData? _selectedIcon;
  Color? _selectedIconColor;
  RecurrenceUnit? _recurrenceUnit;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memorialDay?.title);
    _intervalController = TextEditingController(
      text: '${widget.memorialDay?.recurrenceInterval ?? 1}',
    );
    _selectedDate = widget.memorialDay?.targetDate ?? DateTime.now();
    _selectedColor = widget.memorialDay?.backgroundColor ?? Colors.blue[300]!;
    _backgroundImageUrl = widget.memorialDay?.backgroundImageUrl;
    _selectedIcon = widget.memorialDay?.icon;
    _selectedIconColor = widget.memorialDay?.iconColor;
    _recurrenceUnit = widget.memorialDay?.recurrenceUnit;
    widget.onReady?.call(() => _save(context));
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
    _intervalController.dispose();
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
      recurrenceUnit: _recurrenceUnit,
      recurrenceInterval:
          int.tryParse(_intervalController.text.trim())?.clamp(1, 9999) ?? 1,
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
    if (widget.embedInSheet) {
      return _buildFormBody();
    }

    final isEditing = widget.memorialDay != null;

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            backgroundColor: dsScaffoldBackground(theme),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 轻量手绘顶栏（design.md §2.1）：保存/删除经尾部图标触发
                  DSLightHeader(
                    title: isEditing
                        ? 'day_editMemorialDay'.tr
                        : 'day_addMemorialDay'.tr,
                    trailingWidth: isEditing ? 84 : 38,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isEditing) ...[
                          DSIconButton(
                            icon: DsIconKind.trash,
                            size: 38,
                            color: theme.surface,
                            iconColor: theme.danger,
                            onPressed: _showDeleteConfirm,
                            tooltip: 'day_delete'.tr,
                          ),
                          const SizedBox(width: 8),
                        ],
                        DSIconButton(
                          icon: DsIconKind.check,
                          size: 38,
                          color: theme.surface,
                          iconColor: theme.text,
                          onPressed: () => _save(context),
                          tooltip: 'day_save'.tr,
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildFormBody()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormBody() {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              // sheet 模式由外壳统一追加底部安全区，避免双重留白
              bottom: widget.embedInSheet
                  ? 24
                  : MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconAvatarRowField(
                  name: 'memorial_icon',
                  initialIcon: _selectedIcon,
                  // 圆圈显示主题色（详情页背景用 backgroundColor，非 iconColor）
                  initialIconColor: _selectedColor,
                  initialAvatarUrl: _backgroundImageUrl,
                  onChanged: (value) {
                    setState(() {
                      _selectedIcon = value['icon'] as IconData?;
                      _selectedIconColor = value['iconColor'] as Color?;
                      // 表单唯一的选色入口即纪念日主题色，同步到背景色，
                      // 否则保存后详情页背景不生效
                      final color = value['iconColor'];
                      if (color is Color) _selectedColor = color;
                      _backgroundImageUrl = value['avatarUrl'] as String?;
                    });
                  },
                ),
                const SizedBox(height: 24),

                TextInputField(
                  controller: _titleController,
                  labelText: 'day_title'.tr,
                  hintText: 'day_enterTitle'.tr,
                  autofocus: !widget.embedInSheet && widget.memorialDay == null,
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
                const SizedBox(height: 24),

                // 循环：截止日期 = 所选日期 + 叠加量，过期自动滚到下一轮
                OptionSelectorField(
                  labelText: 'day_recurrence'.tr,
                  selectedId: _recurrenceUnit?.name ?? 'off',
                  onSelectionChanged: (id) => setState(() {
                    _recurrenceUnit =
                        id == 'off' ? null : RecurrenceUnit.values.byName(id);
                  }),
                  useHorizontalScroll: false,
                  gridColumns: 4,
                  options: [
                    OptionItem(id: 'off', label: 'day_recurrenceOff'.tr),
                    OptionItem(
                      id: RecurrenceUnit.days.name,
                      label: 'day_recurrenceDays'.tr,
                    ),
                    OptionItem(
                      id: RecurrenceUnit.months.name,
                      label: 'day_recurrenceMonths'.tr,
                    ),
                    OptionItem(
                      id: RecurrenceUnit.years.name,
                      label: 'day_recurrenceYears'.tr,
                    ),
                  ],
                ),
                if (_recurrenceUnit != null) ...[
                  const SizedBox(height: 16),
                  TextInputField(
                    controller: _intervalController,
                    labelText: switch (_recurrenceUnit) {
                      RecurrenceUnit.days => 'day_recurrenceEveryDays'.tr,
                      RecurrenceUnit.months => 'day_recurrenceEveryMonths'.tr,
                      _ => 'day_recurrenceEveryYears'.tr,
                    },
                    hintText: '1',
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 32),

                // 删除按钮仅 sheet 模式在表单底部（外壳无删除入口）；全页模式在顶栏
                if (widget.embedInSheet && widget.memorialDay != null)
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
