import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/utils/date_formatter.dart';

class DatePickerDialog extends StatelessWidget {
  final List<DateTime> availableDates;
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;

  const DatePickerDialog({
    super.key,
    required this.availableDates,
    required this.selectedDate,
    required this.onDateSelected,
  });

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'app_selectDate'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.md),
                Flexible(
                  child: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableDates.length,
                      itemBuilder: (context, index) {
                        final date = availableDates[index];
                        final isSelected =
                            selectedDate != null &&
                            date.year == selectedDate!.year &&
                            date.month == selectedDate!.month &&
                            date.day == selectedDate!.day;

                        return Padding(
                          padding: EdgeInsets.only(bottom: theme.spacing.sm),
                          child: Pressable(
                            onPressed: () {
                              onDateSelected(date);
                              Navigator.of(context).pop();
                            },
                            builder: (context, states) {
                              final pressed = states.contains(
                                WidgetState.pressed,
                              );
                              return JellyBox(
                                radius: theme.radii.lg,
                                raised: false,
                                padding: EdgeInsets.symmetric(
                                  horizontal: theme.spacing.md,
                                  vertical: theme.spacing.sm,
                                ),
                                color:
                                    isSelected
                                        ? theme.primary.mixWhite(0.88)
                                        : (pressed
                                            ? theme.surfaceAlt.withValues(
                                              alpha: 0.6,
                                            )
                                            : null),
                                child: Row(
                                  children: [
                                    DsIcon(
                                      DsIconKind.calendar,
                                      size: 18,
                                      color:
                                          isSelected
                                              ? theme.primary
                                              : theme.textSub,
                                    ),
                                    SizedBox(width: theme.spacing.md),
                                    Expanded(
                                      child: Text(
                                        formatDateFull(date),
                                        style: DsTypography.body.copyWith(
                                          color:
                                              isSelected
                                                  ? theme.primary
                                                  : theme.text,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.bold
                                                  : null,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      DsIcon(
                                        DsIconKind.check,
                                        size: 18,
                                        color: theme.primary,
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: theme.spacing.md),
                DSButton(
                  label: 'app_cancel'.tr,
                  variant: DSButtonVariant.ghost,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
