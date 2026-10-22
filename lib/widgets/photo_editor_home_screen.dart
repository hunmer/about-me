import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:aboutme/widgets/photo_editor_history.dart';
import 'package:aboutme/widgets/photo_editor_screen.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 图片编辑器主界面：选择本地图片开始编辑 + 最近打开记录（点击继续编辑）
class PhotoEditorHomeScreen extends StatefulWidget {
  const PhotoEditorHomeScreen({super.key});

  @override
  State<PhotoEditorHomeScreen> createState() => _PhotoEditorHomeScreenState();
}

class _PhotoEditorHomeScreenState extends State<PhotoEditorHomeScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await PhotoEditorHistory.list();
    if (!mounted) return;
    setState(() {
      _history = history;
      _loading = false;
    });
  }

  Future<void> _pickImage() async {
    final result = await ImagePickerDialog.show<Map<String, dynamic>>(context);
    if (result == null) return;
    // 表情（emoji: 前缀）与 SVG 不适合进照片编辑器，静默跳过
    final url = result['url'] as String?;
    if (url == null || url.isEmpty || url.startsWith('emoji:')) return;
    if (result.containsKey('svg')) return;
    await _openEditor(url);
  }

  Future<void> _openEditor(String url) async {
    await showPhotoEditor(context, imageUrl: url);
    await _load();
  }

  Future<void> _removeEntry(Map<String, dynamic> entry) async {
    await PhotoEditorHistory.remove(entry);
    await _load();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('toolbox_clearHistory'.tr),
        content: Text('toolbox_photoEditor_clearConfirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('app_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('app_confirm'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await PhotoEditorHistory.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SuperCupertinoNavigationWrapper(
      title: Text('toolbox_photo_editor_name'.tr),
      largeTitle: 'toolbox_photo_editor_name'.tr,
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.trash,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'toolbox_clearHistory'.tr,
                onPressed: _history.isEmpty ? null : _clearAll,
              );
            },
          ),
        ),
      ],
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.lg,
                  vertical: theme.spacing.sm,
                ),
                children: [
                  _buildPickCard(theme),
                  if (_history.isNotEmpty) ...[
                    SizedBox(height: theme.spacing.sm),
                    Text(
                      'toolbox_photoEditor_history'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    for (final entry in _history)
                      Padding(
                        padding: EdgeInsets.only(bottom: theme.spacing.sm),
                        child: _buildHistoryEntry(theme, entry),
                      ),
                  ] else ...[
                    SizedBox(height: theme.spacing.xl),
                    DSEmptyState(
                      emoji: '🖼️',
                      title: 'toolbox_photoEditor_historyEmpty'.tr,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  /// 选择图片入口（大卡片）
  Widget _buildPickCard(AppThemeData theme) {
    return DSCard(
      onTap: _pickImage,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.add_photo_alternate_outlined,
                color: theme.primary),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'toolbox_photoEditor_pickImage'.tr,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                const SizedBox(height: 2),
                Text(
                  'toolbox_photoEditor_pickDesc'.tr,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.textSub),
        ],
      ),
    );
  }

  /// 历史条目：缩略图 + 名称/时间 + 删除；点击继续编辑
  Widget _buildHistoryEntry(AppThemeData theme, Map<String, dynamic> entry) {
    final url = entry['url'] as String? ?? '';
    final name = entry['name'] as String? ?? url;
    final ts = entry['ts'] is int ? entry['ts'] as int : 0;
    final time = ts > 0
        ? DateTime.fromMillisecondsSinceEpoch(ts).toString().substring(0, 16)
        : '';

    return DSCard(
      onTap: () => _openEditor(url),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: 56,
              child: Image(
                image: ImageUtils.createImageProvider(url),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.broken_image, color: theme.textSub),
              ),
            ),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _removeEntry(entry),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
