import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

class GoodsUsageRecordForm extends StatefulWidget {
  const GoodsUsageRecordForm({super.key});

  @override
  State<GoodsUsageRecordForm> createState() => _GoodsUsageRecordFormState();
}

class _GoodsUsageRecordFormState extends State<GoodsUsageRecordForm> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _noteController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.xl),
      constraints: const BoxConstraints(maxWidth: 360),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'goods_addUsageRecord'.tr,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
            SizedBox(height: theme.spacing.lg),
            // 日期时间选择行
            Pressable(
              onPressed: _pickDate,
              builder: (context, states) {
                final pressed = states.contains(WidgetState.pressed);
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacing.md,
                    vertical: theme.spacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: pressed ? theme.surfaceAlt : theme.background,
                    borderRadius: theme.radii.lg,
                  ),
                  child: Row(
                    children: [
                      DsIcon(
                        DsIconKind.calendar,
                        size: 20,
                        color: theme.primary,
                      ),
                      SizedBox(width: theme.spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'goods_dateTime'.tr,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(_selectedDate),
                              style: DsTypography.body.copyWith(
                                color: theme.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DsIcon(
                        DsIconKind.chevronRight,
                        size: 18,
                        color: theme.textSub,
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: theme.spacing.md),
            DSInput(
              controller: _durationController,
              label: '使用时长 (分钟)',
              hint: '例如: 30',
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: theme.spacing.md),
            DSInput(
              controller: _locationController,
              label: '使用地点',
              hint: '例如: 办公室',
            ),
            SizedBox(height: theme.spacing.md),
            DSInput(
              controller: _noteController,
              label: 'goods_optionalNote'.tr,
              maxLines: 3,
            ),
            SizedBox(height: theme.spacing.lg),
            Row(
              children: [
                Expanded(
                  child: DSButton(
                    label: 'goods_cancel'.tr,
                    variant: DSButtonVariant.outline,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: DSButton(
                    label: 'goods_confirm'.tr,
                    onPressed: () {
                      final duration = int.tryParse(_durationController.text);
                      Navigator.pop(context, {
                        'date': _selectedDate,
                        'duration': duration,
                        'location':
                            _locationController.text.isEmpty
                                ? null
                                : _locationController.text,
                        'note':
                            _noteController.text.isEmpty
                                ? null
                                : _noteController.text,
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
