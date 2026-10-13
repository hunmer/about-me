import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/constants/app_icons.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/calendar_album/controllers/tag_controller.dart';

/// 文件夹图标选择 Sheet 内容（配合 SmoothBottomSheet 使用）
///
/// 选中图标后写入 [TagController] 并关闭抽屉；
/// 已设置图标时顶部提供"移除图标"入口。
class FolderIconSheet extends StatefulWidget {
  const FolderIconSheet({
    super.key,
    required this.tag,
    required this.tagController,
  });

  final String tag;
  final TagController tagController;

  @override
  State<FolderIconSheet> createState() => _FolderIconSheetState();
}

class _FolderIconSheetState extends State<FolderIconSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<MapEntry<String, IconData>> _filtered = [];

  String? get _currentIconName => widget.tagController.tagIcons[widget.tag];

  @override
  void initState() {
    super.initState();
    _updateFiltered();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _updateFiltered() {
    final entries = AppIcons.predefinedIcons.entries;
    _filtered =
        _query.isEmpty
            ? entries.toList()
            : entries
                .where((e) => e.key.toLowerCase().contains(_query))
                .toList();
  }

  Future<void> _select(String iconName) async {
    await widget.tagController.setTagIcon(widget.tag, iconName);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    await widget.tagController.setTagIcon(widget.tag, null);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: DSInput(
            controller: _searchController,
            hint: 'widget_searchIcons'.tr,
            prefix: DsIcon(DsIconKind.search, size: 20, color: theme.textSub),
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                setState(() {
                  _query = value.trim().toLowerCase();
                  _updateFiltered();
                });
              });
            },
          ),
        ),

        // 移除图标入口
        if (_currentIconName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  'calendar_album_folder_icon_current'.tr,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
                const Spacer(),
                DSButton(
                  label: 'calendar_album_remove_folder_icon'.tr,
                  variant: DSButtonVariant.outline,
                  size: DSButtonSize.sm,
                  onPressed: _remove,
                ),
              ],
            ),
          ),

        // 图标网格（懒加载，无需分页）
        SizedBox(
          height: 320,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final entry = _filtered[index];
              final isSelected = entry.key == _currentIconName;
              return Pressable(
                onPressed: () => _select(entry.key),
                semanticLabel: entry.key,
                builder: (context, states) {
                  final pressed = states.contains(WidgetState.pressed);
                  return JellyBox(
                    radius: theme.radii.md,
                    color: isSelected ? theme.primary : null,
                    raised: isSelected && !pressed,
                    alignment: Alignment.center,
                    child: Icon(
                      entry.value,
                      size: 22,
                      color: isSelected ? theme.onPrimary : theme.text,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
