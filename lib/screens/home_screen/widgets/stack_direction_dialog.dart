import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../models/home_stack_item.dart';

Future<HomeStackDirection?> showStackDirectionDialog(BuildContext context) {
  return showDSDialog<HomeStackDirection>(
    context: context,
    theme: DSThemeBridge.resolve(context),
    builder: (context) => const _StackDirectionDialog(),
  );
}

class _StackDirectionDialog extends StatefulWidget {
  const _StackDirectionDialog();

  @override
  State<_StackDirectionDialog> createState() => _StackDirectionDialogState();
}

class _StackDirectionDialogState extends State<_StackDirectionDialog> {
  final List<_DirectionOption> _options = const [
    _DirectionOption(
      direction: HomeStackDirection.horizontal,
      title: '横向折叠',
      description: '左右滑动切换组件，适合宽屏布局',
      icon: DsIconKind.columns,
    ),
    _DirectionOption(
      direction: HomeStackDirection.vertical,
      title: '纵向折叠',
      description: '上下滑动切换组件，适合竖屏布局',
      icon: DsIconKind.rows,
    ),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.xl),
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'screens_selectStackDirection'.tr,
            textAlign: TextAlign.center,
            style: DsTypography.title.copyWith(color: theme.text),
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            'screens_selectStackDirectionDesc'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
          SizedBox(height: theme.spacing.lg),
          ...List.generate(_options.length, (index) {
            final option = _options[index];
            final isSelected = _selectedIndex % _options.length == index;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _options.length - 1 ? 0 : theme.spacing.md,
              ),
              child: _DirectionCard(
                option: option,
                selected: isSelected,
                theme: theme,
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            );
          }),
          SizedBox(height: theme.spacing.lg),
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
                  label: 'screens_confirm'.tr,
                  onPressed:
                      () => Navigator.of(context).pop(
                        _options[_selectedIndex % _options.length].direction,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 方向选项卡：选中态变为主色果冻件
class _DirectionCard extends StatelessWidget {
  const _DirectionCard({
    required this.option,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final _DirectionOption option;
  final bool selected;
  final AppThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: JellyBox(
        radius: theme.radii.lg,
        raised: false,
        color: selected ? theme.primary : null,
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.md,
        ),
        child: Row(
          children: [
            DsIcon(
              option.icon,
              size: 22,
              color: selected ? theme.onPrimary : theme.primary,
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.title,
                    style: DsTypography.heading.copyWith(
                      color: selected ? theme.onPrimary : theme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: DsTypography.caption.copyWith(
                      color:
                          selected
                              ? theme.onPrimary.withValues(alpha: 0.85)
                              : theme.textSub,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            DsIcon(
              selected ? DsIconKind.check : DsIconKind.chevronRight,
              size: 18,
              color: selected ? theme.onPrimary : theme.textSub,
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionOption {
  final HomeStackDirection direction;
  final String title;
  final String description;
  final DsIconKind icon;

  const _DirectionOption({
    required this.direction,
    required this.title,
    required this.description,
    required this.icon,
  });
}
