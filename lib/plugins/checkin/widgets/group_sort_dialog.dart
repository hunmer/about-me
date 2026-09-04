import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/checkin/services/group_sort_service.dart';

class GroupSortDialog extends StatefulWidget {
  final GroupSortType currentSortType;
  final bool isReversed;
  final Function(GroupSortType, bool) onSortChanged;

  const GroupSortDialog({
    super.key,
    required this.currentSortType,
    required this.isReversed,
    required this.onSortChanged,
  });

  @override
  State<GroupSortDialog> createState() => _GroupSortDialogState();
}

class _GroupSortDialogState extends State<GroupSortDialog> {
  late GroupSortType _selectedSortType;
  late bool _isReversed;

  @override
  void initState() {
    super.initState();
    _selectedSortType = widget.currentSortType;
    _isReversed = widget.isReversed;
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'checkin_groupSortTitle'.tr,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.md),
                  ...GroupSortType.values.map(
                    (type) => Row(
                      children: [
                        DSRadio<GroupSortType>(
                          value: type,
                          groupValue: _selectedSortType,
                          onChanged:
                              (value) =>
                                  setState(() => _selectedSortType = value!),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap:
                                () => setState(() => _selectedSortType = type),
                            child: Text(
                              GroupSortService.getSortTypeName(type, context),
                              style: DsTypography.body.copyWith(
                                color: theme.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'checkin_reverseSort'.tr,
                          style: DsTypography.body.copyWith(color: theme.text),
                        ),
                      ),
                      DSSwitch(
                        value: _isReversed,
                        onChanged: (value) {
                          setState(() {
                            _isReversed = value;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          label: 'checkin_cancel'.tr,
                          variant: DSButtonVariant.outline,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DSButton(
                          label: 'checkin_confirm'.tr,
                          onPressed: () {
                            widget.onSortChanged(
                              _selectedSortType,
                              _isReversed,
                            );
                            Navigator.of(context).pop();
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
}
