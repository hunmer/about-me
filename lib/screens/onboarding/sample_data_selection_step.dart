import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 引导页共享 values 中存放勾选分组 id 列表的 key
const String kSampleDataGroupIdsKey = 'sampleDataGroupIds';

/// 构建「示例数据选择」引导步骤（默认全选）
///
/// 勾选结果写入共享 [values] 的 [kSampleDataGroupIdsKey]，
/// 由 [PluginOnboardingScreen] 完成时经
/// [PluginBase.applySampleDataGroups] 应用。
PluginOnboardingStep buildSampleDataSelectionStep(
  List<PluginSampleDataGroup> groups,
) {
  return PluginOnboardingStep(
    icon: Icons.auto_awesome,
    title: 'plugin_onboarding_sample_title'.tr,
    description: 'plugin_onboarding_sample_desc'.tr,
    builder: (context, values) =>
        _SampleDataSelectionView(groups: groups, values: values),
  );
}

class _SampleDataSelectionView extends StatefulWidget {
  const _SampleDataSelectionView({
    required this.groups,
    required this.values,
  });

  final List<PluginSampleDataGroup> groups;
  final Map<String, dynamic> values;

  @override
  State<_SampleDataSelectionView> createState() =>
      _SampleDataSelectionViewState();
}

class _SampleDataSelectionViewState extends State<_SampleDataSelectionView> {
  late final Set<String> _selected = _initSelection();

  Set<String> _initSelection() {
    final stored = widget.values[kSampleDataGroupIdsKey];
    if (stored is List) {
      return stored.whereType<String>().toSet();
    }
    // 默认全选
    return widget.groups.map((g) => g.id).toSet();
  }

  void _toggle(String id, bool checked) {
    setState(() {
      checked ? _selected.add(id) : _selected.remove(id);
      widget.values[kSampleDataGroupIdsKey] = _selected.toList();
    });
  }

  void _toggleAll(bool checked) {
    setState(() {
      checked
          ? _selected.addAll(widget.groups.map((g) => g.id))
          : _selected.clear();
      widget.values[kSampleDataGroupIdsKey] = _selected.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final allChecked = _selected.length == widget.groups.length;

    return Column(
      children: [
        // 全选/全不选
        _buildTile(
          theme: theme,
          title: 'plugin_onboarding_sample_selectAll'.tr,
          checked: allChecked,
          onToggle: () => _toggleAll(!allChecked),
          isHeader: true,
        ),
        SizedBox(height: theme.spacing.sm),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: widget.groups.length,
            separatorBuilder: (_, __) => SizedBox(height: theme.spacing.xs),
            itemBuilder: (context, index) {
              final group = widget.groups[index];
              return _buildTile(
                theme: theme,
                title: group.title,
                description: group.description,
                checked: _selected.contains(group.id),
                onToggle: () => _toggle(group.id, !_selected.contains(group.id)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTile({
    required AppThemeData theme,
    required String title,
    String? description,
    required bool checked,
    required VoidCallback onToggle,
    bool isHeader = false,
  }) {
    return Pressable(
      onPressed: onToggle,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        decoration: dsSketchDecoration(
          theme: theme,
          radius: theme.radii.md,
          fillColor: theme.surface,
        ),
        child: Row(
          children: [
            DSCheckbox(value: checked, onChanged: (_) => onToggle()),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: (isHeader
                            ? DsTypography.label
                            : DsTypography.body)
                        .copyWith(
                          color: theme.text,
                          fontWeight: isHeader ? FontWeight.w600 : null,
                        ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      description,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
