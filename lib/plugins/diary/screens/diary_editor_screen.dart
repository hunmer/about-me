import 'package:flutter/material.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/aboutme_editor/aboutme_editor.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:get/get.dart';

class DiaryEditorScreen extends StatefulWidget {
  final DateTime date;
  final StorageManager storage;
  final String initialTitle;
  final String initialContent;

  const DiaryEditorScreen({
    super.key,
    required this.date,
    required this.storage,
    this.initialTitle = '',
    required this.initialContent,
  });

  @override
  State<DiaryEditorScreen> createState() => _DiaryEditorScreenState();
}

class _DiaryEditorScreenState extends State<DiaryEditorScreen> {
  String? _selectedMood;

  // 心情表情列表
  final List<String> _moods = [
    '😊',
    '😢',
    '😡',
    '😴',
    '🤔',
    '😎',
    '😍',
    '🤮',
    '😱',
    '🥳',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentEntry();
  }

  Future<void> _loadCurrentEntry() async {
    // 从存储加载最新的日记条目
    final entry = await DiaryUtils.loadDiaryEntry(widget.date);
    if (entry != null && mounted) {
      setState(() {
        _selectedMood = entry.mood;
      });
    }
  }

  void _showMoodSelector() {
    // 本屏幕是独立路由，不在任何主题桥之下，用 resolve 解析主题
    final theme = DSThemeBridge.resolve(context);
    showDSDialog(
      context: context,
      theme: theme,
      builder:
          (dialogContext) => JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'diary_selectMood'.tr,
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),
                Wrap(
                  spacing: theme.spacing.sm,
                  runSpacing: theme.spacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final mood in _moods)
                      _MoodOption(
                        emoji: mood,
                        selected: mood == _selectedMood,
                        theme: theme,
                        onTap: () {
                          setState(() => _selectedMood = mood);
                          Navigator.pop(dialogContext);
                        },
                      ),
                  ],
                ),
                SizedBox(height: theme.spacing.lg),
                Row(
                  children: [
                    if (_selectedMood != null)
                      Expanded(
                        child: DSButton(
                          label: 'diary_clearSelection'.tr,
                          variant: DSButtonVariant.outline,
                          size: DSButtonSize.sm,
                          onPressed: () {
                            setState(() => _selectedMood = null);
                            Navigator.pop(dialogContext);
                          },
                        ),
                      ),
                    if (_selectedMood != null)
                      SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: DSButton(
                        label: 'app_close'.tr,
                        size: DSButtonSize.sm,
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  void _showDeleteConfirmation() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSDialog(
            title: 'diary_confirmDeleteDiary'.tr,
            message: 'diary_deleteDiaryMessage'.tr,
            confirmText: 'diary_confirmDeleteDiary'.tr,
            cancelText: 'app_cancel'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () async {
              // 关闭对话框
              Navigator.pop(dialogContext);
              // 删除日记
              await DiaryUtils.deleteDiaryEntry(widget.date);
              // 返回上一级
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: AboutmeEditor(
        initialTitle: widget.initialTitle,
        initialContent: widget.initialContent,
        pageTitle: 'diary_name'.tr,
        date: widget.date,
        mood: _selectedMood,
        onMoodTap: _showMoodSelector,
        titleHint: 'diary_titleHint'.tr,
        contentHint: 'diary_contentHint'.tr,
        onSave: (title, content) async {
          // 保存前捕获当前上下文
          final currentContext = context;

          await DiaryUtils.saveDiaryEntry(
            widget.date,
            content,
            title: title,
            mood: _selectedMood,
          );

          if (mounted) {
            Navigator.of(currentContext).pop();
          }
        },
        actions: [
          // 删除按钮：危险色果冻圆钮（编辑器头部在本屏主题桥之内）
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = AppTheme.of(context);
                return DSIconButton(
                  icon: DsIconKind.trash,
                  size: 36,
                  color: theme.danger,
                  iconColor: theme.onDanger,
                  onPressed: _showDeleteConfirmation,
                  tooltip: 'diary_delete'.tr,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 心情选项：果冻圆底座 + 表情，选中态主色描边
class _MoodOption extends StatelessWidget {
  const _MoodOption({
    required this.emoji,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final AppThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? theme.primary.mixWhite(0.85) : theme.surfaceAlt,
          borderRadius: theme.radii.lg,
          border: Border.all(
            color: selected ? theme.primary : theme.stroke,
            width: selected ? 2 : 1.4,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}
