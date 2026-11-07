import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/activity/models/activity_record.dart';
import 'package:aboutme/plugins/activity/models/activity_record_template.dart';
import 'package:aboutme/plugins/activity/services/activity_service.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 记录模版底部面板入口
///
/// 管理固定时间点模版（起床/出门/下班等），支持：
/// - 应用：把模版一键记录到选中日期，可微调单个时间点，其余点联动平移
///   （平移可跨天，越界时间显示「次日/前日」前缀）；可选先删除重叠的已有记录
/// - 编辑：新建/修改/删除模版，每个时间点可设置生成的记录时长
Future<void> showActivityTemplateSheet(
  BuildContext context, {
  required ActivityService service,
  required DateTime selectedDate,
}) {
  return SmoothBottomSheet.showWithTitle(
    context: context,
    title: '记录模版',
    child: _ActivityTemplateSheet(
      service: service,
      selectedDate: selectedDate,
    ),
  );
}

/// 面板内部视图状态
enum _SheetView { list, apply, edit }

/// 编辑条目的临时状态（名称控制器 + 分钟偏移 + 记录时长）
class _EditItem {
  _EditItem({
    required this.controller,
    required this.minutes,
    this.durationMinutes = 30,
  });

  final TextEditingController controller;
  int minutes;
  int durationMinutes;
}

class _ActivityTemplateSheet extends StatefulWidget {
  const _ActivityTemplateSheet({
    required this.service,
    required this.selectedDate,
  });

  final ActivityService service;
  final DateTime selectedDate;

  @override
  State<_ActivityTemplateSheet> createState() => _ActivityTemplateSheetState();
}

class _ActivityTemplateSheetState extends State<_ActivityTemplateSheet> {
  List<ActivityRecordTemplate> _templates = [];
  bool _loading = true;

  _SheetView _view = _SheetView.list;

  // 应用视图状态
  ActivityRecordTemplate? _applyTarget;
  List<int> _applyMinutes = [];
  bool _linkAdjust = true;
  bool _overwriteExisting = false;

  // 编辑视图状态
  ActivityRecordTemplate? _editTarget;
  final TextEditingController _nameController = TextEditingController();
  final List<_EditItem> _editItems = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final item in _editItems) {
      item.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final templates = await widget.service.getRecordTemplates();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _loading = false;
    });
  }

  // ──────────────────────────── 视图切换 ────────────────────────────

  void _enterApply(ActivityRecordTemplate template) {
    final items = template.sortedItems;
    setState(() {
      _applyTarget = template.copyWith(items: items);
      _applyMinutes = items.map((e) => e.minutes).toList();
      _linkAdjust = true;
      _overwriteExisting = false;
      _view = _SheetView.apply;
    });
  }

  void _enterEdit([ActivityRecordTemplate? template]) {
    setState(() {
      _editTarget = template;
      _nameController.text = template?.name ?? '';
      for (final item in _editItems) {
        item.controller.dispose();
      }
      _editItems
        ..clear()
        ..addAll(
          (template?.items ?? const <ActivityTemplateItem>[])
              .map((e) => _EditItem(
                    controller: TextEditingController(text: e.title),
                    minutes: e.minutes,
                    durationMinutes: e.durationMinutes,
                  )),
        );
      if (template == null && _editItems.isEmpty) {
        // 新建时预置一个空白条目
        _editItems.add(_EditItem(controller: TextEditingController(), minutes: 8 * 60));
      }
      _view = _SheetView.edit;
    });
  }

  void _backToList() => setState(() => _view = _SheetView.list);

  // ──────────────────────────── 应用：一键记录 ────────────────────────────

  Future<void> _pickTime(int index) async {
    final oldMinutes = _applyMinutes[index];
    // TimePicker 仅覆盖 0-1439，跨天偏移先归一化再进选择器
    final normalized = ((oldMinutes % 1440) + 1440) % 1440;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60),
    );
    if (picked == null) return;
    // 就近解释：选择的时刻按同日/次日/前日三种落点取与当前差最小者，
    // 使「23:00 改 00:30」自然落在次日 00:30 而不是当天凌晨
    var delta = ((picked.hour * 60 + picked.minute - normalized) % 1440 + 1440) % 1440;
    if (delta > 720) delta -= 1440;
    final next = oldMinutes + delta;
    if (delta == 0) return;
    setState(() {
      if (_linkAdjust) {
        // 联动：其余时间点按相同偏移平移，允许跨天（负数/超过 24 点）
        for (var j = 0; j < _applyMinutes.length; j++) {
          if (j == index) continue;
          _applyMinutes[j] += delta;
        }
      }
      _applyMinutes[index] = next;
    });
  }

  Future<void> _applyToSelectedDate() async {
    final target = _applyTarget;
    if (target == null) return;
    final base = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    // 先收集待写入的时间段（分钟偏移可为负/跨天，DateTime 加减天然支持）
    final items = <ActivityTemplateItem>[];
    final starts = <DateTime>[];
    final ends = <DateTime>[];
    for (var i = 0; i < target.items.length; i++) {
      final item = target.items[i];
      if (item.title.trim().isEmpty) continue;
      final start = base.add(Duration(minutes: _applyMinutes[i]));
      items.add(item);
      starts.add(start);
      ends.add(start.add(Duration(minutes: item.durationMinutes)));
    }
    // 覆盖模式：删除选中日期内与新时间段重叠的已有记录
    if (_overwriteExisting && items.isNotEmpty) {
      final existing =
          await widget.service.getActivitiesForDate(widget.selectedDate);
      for (final record in existing) {
        final overlaps = List<bool>.generate(
          items.length,
          (i) =>
              record.startTime.isBefore(ends[i]) &&
              record.endTime.isAfter(starts[i]),
        ).contains(true);
        if (overlaps) {
          await widget.service.deleteActivity(record);
        }
      }
    }
    for (var i = 0; i < items.length; i++) {
      await widget.service.saveActivity(
        ActivityRecord(
          startTime: starts[i],
          endTime: ends[i],
          title: items[i].title.trim(),
        ),
      );
    }
    if (!mounted) return;
    Toast.show('已记录 ${items.length} 个时间点到 ${DateFormat('M月d日').format(widget.selectedDate)}');
    Navigator.of(context).pop();
  }

  // ──────────────────────────── 编辑：保存/删除 ────────────────────────────

  void _addEditItem() {
    setState(() {
      final last = _editItems.isEmpty ? 8 * 60 : _editItems.last.minutes + 60;
      _editItems.add(
        _EditItem(controller: TextEditingController(), minutes: last),
      );
    });
  }

  void _removeEditItem(int index) {
    setState(() {
      _editItems[index].controller.dispose();
      _editItems.removeAt(index);
    });
  }

  Future<void> _pickEditTime(int index) async {
    final oldMinutes = _editItems[index].minutes;
    // TimeOfDay 仅支持 0-1439，跨天偏移先归一化再进选择器
    final normalized = ((oldMinutes % 1440) + 1440) % 1440;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60),
    );
    if (picked == null) return;
    setState(() {
      _editItems[index].minutes = picked.hour * 60 + picked.minute;
    });
  }

  /// 选择该时间点生成的记录时长（常用档位）
  Future<void> _pickDuration(int index) async {
    const options = [15, 30, 45, 60, 90, 120];
    final picked = await showDSDialog<int>(
      context: context,
      builder: (dialogContext) => DSDialog(
        title: '记录时长',
        message: '「${_editItems[index].controller.text.trim()}」生成记录的时长',
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              DSChip(
                label: '$option分钟',
                selected: _editItems[index].durationMinutes == option,
                onSelected: (_) => Navigator.of(dialogContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _editItems[index].durationMinutes = picked);
  }

  Future<void> _saveTemplate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Toast.show('请填写模版名称');
      return;
    }
    final items = <ActivityTemplateItem>[];
    for (final item in _editItems) {
      final title = item.controller.text.trim();
      if (title.isEmpty) continue;
      items.add(
        ActivityTemplateItem(
          title: title,
          minutes: item.minutes,
          durationMinutes: item.durationMinutes,
        ),
      );
    }
    if (items.isEmpty) {
      Toast.show('至少需要一个时间点名称');
      return;
    }
    final template = ActivityRecordTemplate(name: name, items: items);
    final next = [..._templates];
    if (_editTarget == null) {
      next.add(template);
    } else {
      final index = next.indexWhere((e) => e.id == _editTarget!.id);
      if (index >= 0) {
        next[index] = template;
      } else {
        next.add(template);
      }
    }
    try {
      await widget.service.saveRecordTemplates(next);
    } catch (_) {
      if (mounted) Toast.show('保存失败，请重试');
      return;
    }
    await _load();
    if (!mounted) return;
    setState(() => _view = _SheetView.list);
    Toast.show('模版已保存');
  }

  Future<void> _confirmDelete(ActivityRecordTemplate template) async {
    final theme = DSThemeBridge.resolve(context);
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: theme,
      builder: (dialogContext) => DSDialog(
        title: '删除模版',
        message: '确定删除「${template.name}」吗？',
        confirmText: '删除',
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true) return;
    final next = _templates.where((e) => e.id != template.id).toList();
    try {
      await widget.service.saveRecordTemplates(next);
    } catch (_) {
      if (mounted) Toast.show('删除失败，请重试');
      return;
    }
    await _load();
    if (mounted) Toast.show('模版已删除');
  }

  Future<void> _fillSample() async {
    final sample = ActivityRecordTemplate(
      name: '工作日',
      items: [
        ActivityTemplateItem(title: '起床', minutes: 7 * 60),
        ActivityTemplateItem(title: '出门', minutes: 8 * 60),
        ActivityTemplateItem(title: '午饭', minutes: 12 * 60, durationMinutes: 60),
        ActivityTemplateItem(title: '下班', minutes: 18 * 60),
        ActivityTemplateItem(title: '睡觉', minutes: 23 * 60),
      ],
    );
    try {
      await widget.service.saveRecordTemplates([..._templates, sample]);
    } catch (_) {
      if (mounted) Toast.show('保存失败，请重试');
      return;
    }
    await _load();
  }

  // ──────────────────────────── 构建 ────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.62,
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : switch (_view) {
                    _SheetView.list => _buildList(theme),
                    _SheetView.apply => _buildApply(theme),
                    _SheetView.edit => _buildEdit(theme),
                  },
          );
        },
      ),
    );
  }

  Widget _buildList(AppThemeData theme) {
    if (_templates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Icon(DsIconKind.layers.iconData, size: 40, color: theme.textSub),
            const SizedBox(height: 8),
            Text(
              '还没有记录模版',
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
            Text(
              '创建固定时间点，一键记录一整天',
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
            const SizedBox(height: 16),
            DSButton(
              label: '填充示例模版',
              variant: DSButtonVariant.secondary,
              expand: true,
              onPressed: _fillSample,
            ),
            const SizedBox(height: 8),
            DSButton(
              label: '新建模版',
              variant: DSButtonVariant.dashed,
              expand: true,
              icon: DsIconKind.plus,
              onPressed: () => _enterEdit(),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            itemCount: _templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final template = _templates[index];
              return DSCard(
                onTap: () => _enterApply(template),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            template.name,
                            style: DsTypography.heading,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DSIconButton(
                          icon: DsIconKind.edit,
                          size: 32,
                          tooltip: '编辑',
                          onPressed: () => _enterEdit(template),
                        ),
                        DSIconButton(
                          icon: DsIconKind.trash,
                          size: 32,
                          tooltip: '删除',
                          onPressed: () => _confirmDelete(template),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final item in template.sortedItems)
                          DSChip(label: '${item.title} ${item.formattedTime}'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: DSButton(
            label: '新建模版',
            variant: DSButtonVariant.dashed,
            expand: true,
            icon: DsIconKind.plus,
            onPressed: () => _enterEdit(),
          ),
        ),
      ],
    );
  }

  Widget _buildApply(AppThemeData theme) {
    final target = _applyTarget!;
    final dateLabel = DateFormat('M月d日').format(widget.selectedDate);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              DSIconButton(
                icon: DsIconKind.chevronLeft,
                size: 36,
                tooltip: '返回',
                onPressed: _backToList,
              ),
              Expanded(
                child: Text(
                  target.name,
                  style: DsTypography.heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '点击时间可微调；$_linkTip',
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DSChip(
                    label: '联动调整',
                    selected: _linkAdjust,
                    onSelected: (value) => setState(() => _linkAdjust = value),
                  ),
                  DSChip(
                    label: '覆盖已有记录',
                    selected: _overwriteExisting,
                    onSelected: (value) =>
                        setState(() => _overwriteExisting = value),
                  ),
                ],
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: target.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = target.items[index];
              return Row(
                children: [
                  Expanded(child: Text(item.title, style: DsTypography.body)),
                  _TimeChip(
                    minutes: _applyMinutes[index],
                    onTap: () => _pickTime(index),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: DSButton(
            label: '一键记录到 $dateLabel',
            expand: true,
            icon: DsIconKind.check,
            onPressed: _applyToSelectedDate,
          ),
        ),
      ],
    );
  }

  String get _linkTip => _linkAdjust ? '其余时间点按间隔联动平移' : '仅修改当前时间点';

  Widget _buildEdit(AppThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              DSIconButton(
                icon: DsIconKind.chevronLeft,
                size: 36,
                tooltip: '返回',
                onPressed: _backToList,
              ),
              Expanded(
                child: Text(
                  _editTarget == null ? '新建模版' : '编辑模版',
                  style: DsTypography.heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DSInput(
                  controller: _nameController,
                  label: '模版名称',
                  hint: '如：工作日',
                  maxLength: 20,
                ),
                const SizedBox(height: 12),
                Text('时间点', style: DsTypography.body),
                const SizedBox(height: 8),
                for (var i = 0; i < _editItems.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: DSInput(
                            controller: _editItems[i].controller,
                            hint: '时间点名称，如：起床',
                            maxLength: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TimeChip(
                              minutes: _editItems[i].minutes,
                              onTap: () => _pickEditTime(i),
                            ),
                            const SizedBox(height: 4),
                            _DurationChip(
                              minutes: _editItems[i].durationMinutes,
                              onTap: () => _pickDuration(i),
                            ),
                          ],
                        ),
                        DSIconButton(
                          icon: DsIconKind.trash,
                          size: 32,
                          tooltip: '删除',
                          onPressed: () => _removeEditItem(i),
                        ),
                      ],
                    ),
                  ),
                DSButton(
                  label: '添加时间点',
                  variant: DSButtonVariant.dashed,
                  expand: true,
                  icon: DsIconKind.plus,
                  onPressed: _addEditItem,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: DSButton(
            label: '保存模版',
            expand: true,
            icon: DsIconKind.check,
            onPressed: _saveTemplate,
          ),
        ),
      ],
    );
  }
}

/// 可点击的时间胶囊（HH:mm，跨天带「次日/前日」前缀）
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.minutes, required this.onTap});

  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: onTap,
      child: JellyBox(
        color: theme.surfaceAlt,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(DsIconKind.clock.iconData, size: 14, color: theme.textSub),
            const SizedBox(width: 4),
            Text(
              ActivityTemplateItem.formatMinutes(minutes),
              style: DsTypography.body.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 可点击的时长胶囊（如 30分）
class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.minutes, required this.onTap});

  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: onTap,
      child: JellyBox(
        color: theme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$minutes分',
          style: DsTypography.caption.copyWith(color: theme.textSub),
        ),
      ),
    );
  }
}
