import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/diary/widgets/diary_mood_face.dart';
import 'package:aboutme/widgets/rich_editor_screen.dart';

/// 日记编辑屏：通用富文本编辑屏 + 日记特有心情挂载
class DiaryEditorScreen extends StatefulWidget {
  final DateTime date;
  final StorageManager storage;
  final String initialTitle;
  final String initialContent;
  final String? initialMood; // 外部预选心情（如日历页头部快捷选心情）

  const DiaryEditorScreen({
    super.key,
    required this.date,
    required this.storage,
    this.initialTitle = '',
    required this.initialContent,
    this.initialMood,
  });

  @override
  State<DiaryEditorScreen> createState() => _DiaryEditorScreenState();
}

class _DiaryEditorScreenState extends State<DiaryEditorScreen> {
  String? _selectedMood;
  DiaryEntry? _entry;
  int? _version;
  bool _loading = true;
  Object? _loadError;
  List<String> _tags = const [];

  @override
  void initState() {
    super.initState();
    _selectedMood = widget.initialMood;
    _loadCurrentEntry();
  }

  Future<void> _loadCurrentEntry() async {
    try {
      final snapshot = await DiaryUtils.loadDiarySnapshot(widget.date);
      if (!mounted) return;
      setState(() {
        _entry = snapshot.entry;
        _version = snapshot.version;
        if (_entry != null) {
          _selectedMood = _entry!.mood;
          _tags = _entry!.tags;
        }
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = error;
        });
      }
    }
  }

  // ===== 弹窗 =====

  void _showMoodSelector() {
    // 本屏幕是独立路由，不在任何主题桥之下，用 resolve 解析主题
    final theme = DSThemeBridge.resolve(context);
    showDSDialog(
      context: context,
      theme: theme,
      builder: (dialogContext) => JellyBox(
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
                for (final mood in diaryMoodEmojis)
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
                if (_selectedMood != null) SizedBox(width: theme.spacing.md),
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

  // ===== 构建 =====

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() => _loading = true);
            _loadCurrentEntry();
          },
          child: Text('日记加载失败，点击重试：$_loadError'),
        ),
      );
    }
    final dateStr = DateFormat.yMMMMd(
      Localizations.localeOf(context).toString(),
    ).format(widget.date);
    final moodName = _selectedMood != null
        ? (diaryMoodNameKeys[_selectedMood]?.tr ?? _selectedMood!)
        : null;

    return RichEditorScreen(
      initialTitle: _entry?.title ?? widget.initialTitle,
      initialContent: _entry?.content ?? widget.initialContent,
      initialTags: _tags,
      eyebrow: dateStr,
      // 编辑态标题行的心情表情（即改即生效）
      titleLeading: GestureDetector(
        onTap: _showMoodSelector,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: DiaryMoodFaceCircle(
            spec: _selectedMood != null
                ? diaryMoodSpecOf(_selectedMood!)
                : neutralMoodSpec,
            size: 32,
          ),
        ),
      ),
      // 阅读态标签行的心情胶囊
      readingPills: (theme) => [
        if (_selectedMood != null)
          EditorTagPill(
            theme: theme,
            label: '$_selectedMood $moodName',
            highlight: true,
          ),
      ],
      // 阅读态 dock 的心情按钮
      dockActions: (dockTheme) => [
        EditorDockButton(
          theme: dockTheme,
          tooltip: 'diary_mood'.tr,
          onTap: _showMoodSelector,
          // 显示当前心情表情，无心情时显示添加图标
          child: _buildMoodDockIcon(dockTheme),
        ),
      ],
      onSave: (title, content, tags) => DiaryUtils.saveDiaryEntry(
        widget.date,
        content,
        title: title,
        mood: _selectedMood,
        tags: tags,
        expectedVersion: _version,
        onCommitted: (entry, version) {
          _entry = entry;
          _version = version;
        },
      ),
      onDelete: () =>
          DiaryUtils.deleteDiaryEntry(widget.date, expectedVersion: _version),
    );
  }

  Widget _buildMoodDockIcon(AppThemeData theme) {
    if (_selectedMood == null) {
      return Icon(
        Icons.emoji_emotions_outlined,
        size: 18,
        color: theme.textSub,
      );
    }
    final spec = diaryMoodSpecOf(_selectedMood!);
    return Image.asset(
      // 未知表情无图片时回退图标
      spec.asset ?? '',
      width: 22,
      height: 22,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.emoji_emotions_outlined, size: 18, color: theme.textSub),
    );
  }
}

/// 心情选项：果冻圆底座 + 表情图片，选中态主色描边
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
    final spec = diaryMoodSpecOf(emoji);
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
        child: spec.asset != null
            ? Image.asset(
                spec.asset!,
                width: 30,
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Text(emoji, style: const TextStyle(fontSize: 26)),
              )
            : Text(emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}
