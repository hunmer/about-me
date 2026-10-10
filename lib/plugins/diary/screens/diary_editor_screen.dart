import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/diary/utils/diary_utils.dart';
import 'package:aboutme/plugins/diary/widgets/diary_mood_face.dart';
import 'package:aboutme/widgets/quill_viewer/index.dart';

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
  String _title = '';
  String _contentJson = '';
  List<String> _tags = [];

  // 阅读态 / 编辑态；新建（无内容）直接进入编辑态
  bool _isEditing = false;
  late final bool _isNewEntry;
  int _wordCount = 0;

  // 编辑态控制器（进入编辑时创建，取消/保存后释放）
  TextEditingController? _titleController;
  quill.QuillController? _contentController;
  final TextEditingController _tagInputController = TextEditingController();

  // 取消编辑时还原标签（mood 与阅读态共享，维持即改即生效）
  List<String> _backupTags = const [];

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    _contentJson = widget.initialContent;
    _isNewEntry = widget.initialContent.trim().isEmpty;
    _wordCount = _countChars(_contentJson);
    if (_isNewEntry) {
      _startEditing();
    }
    _loadCurrentEntry();
  }

  @override
  void dispose() {
    _disposeEditingControllers();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentEntry() async {
    // 从存储加载最新的日记条目（同步外部修改的心情与标签）
    final entry = await DiaryUtils.loadDiaryEntry(widget.date);
    if (entry != null && mounted && !_isEditing) {
      setState(() {
        _selectedMood = entry.mood;
        _tags = entry.tags;
      });
    }
  }

  // ===== 编辑态管理 =====

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _backupTags = List.of(_tags);
      _titleController = TextEditingController(text: _title);
      _contentController = _initQuillController(_contentJson);
      _contentController!.document.changes.listen((_) {
        if (mounted) {
          setState(() {
            _wordCount = _contentController!.document
                .toPlainText()
                .trim()
                .length;
          });
        }
      });
    });
  }

  void _disposeEditingControllers() {
    _titleController?.dispose();
    _titleController = null;
    _contentController?.dispose();
    _contentController = null;
  }

  /// 取消编辑：新条目直接退出页面，已有内容则回到阅读态
  void _cancelEditing() {
    if (_isNewEntry) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isEditing = false;
      _disposeEditingControllers();
      _tags = _backupTags;
      // 还原字数为已保存内容
      _wordCount = _countChars(_contentJson);
    });
  }

  quill.QuillController _initQuillController(String content) {
    if (content.trim().isEmpty) {
      return quill.QuillController.basic();
    }
    try {
      final json = jsonDecode(content);
      final document = quill.Document.fromJson(json);
      return quill.QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      final document = quill.Document()..insert(0, content);
      return quill.QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  /// 统计字符数（兼容 JSON Delta 与纯文本）
  int _countChars(String content) {
    return DiaryUtils.contentToPlainText(content).trim().length;
  }

  Future<void> _save() async {
    final title = _titleController?.text ?? _title;
    final content = _isEditing && _contentController != null
        ? jsonEncode(_contentController!.document.toDelta().toJson())
        : _contentJson;

    await DiaryUtils.saveDiaryEntry(
      widget.date,
      content,
      title: title,
      mood: _selectedMood,
      tags: _tags,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ===== 标签编辑 =====

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty || _tags.contains(tag)) {
      _tagInputController.clear();
      return;
    }
    setState(() => _tags = [..._tags, tag]);
    _tagInputController.clear();
  }

  void _removeTag(String tag) {
    setState(() => _tags = _tags.where((t) => t != tag).toList());
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

  void _showDeleteConfirmation() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSDialog(
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

  // ===== 构建 =====

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return DSThemeBridge(
      child: Scaffold(
        backgroundColor: theme.background,
        body: SafeArea(
          child: _isEditing
              ? _buildEditingView(theme)
              : _buildReadingView(theme),
        ),
      ),
    );
  }

  /// 阅读态（设计稿 Morning Reflection 布局）+ 底部悬浮操作 dock
  Widget _buildReadingView(AppThemeData theme) {
    final dateStr = DateFormat.yMMMMd(
      Localizations.localeOf(context).toString(),
    ).format(widget.date);
    final title = _title.trim().isEmpty ? 'diary_untitled'.tr : _title;
    final moodName = _selectedMood != null
        ? (diaryMoodNameKeys[_selectedMood]?.tr ?? _selectedMood!)
        : null;

    return Stack(
      children: [
        // Positioned.fill 让滚动区撑满全屏，dock 才能固定在屏幕底部
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 顶部导航行：圆形返回按钮
                Align(
                  alignment: Alignment.centerLeft,
                  child: _CircleIconButton(
                    theme: theme,
                    icon: Icons.chevron_left,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(height: 16),

                // 日期眉题（主色大写宽字距）
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: theme.primary,
                  ),
                ),
                const SizedBox(height: 6),

                // 大标题
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: theme.text,
                  ),
                ),
                const SizedBox(height: 14),

                // 标签胶囊行：心情 + 标签 + 字数
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (_selectedMood != null)
                      _TagPill(
                        theme: theme,
                        label: '$_selectedMood $moodName',
                        highlight: true,
                      ),
                    for (final tag in _tags) _TagPill(theme: theme, label: tag),
                    _TagPill(
                      theme: theme,
                      label: '$_wordCount ${'diary_wordUnit'.tr}',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 正文
                if (_contentJson.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Text(
                      'diary_emptyContent'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: theme.textSub),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: QuillViewer(data: _contentJson, selectable: true),
                  ),
              ],
            ),
          ),
        ),

        // 底部悬浮操作 dock：编辑 / 心情 / 删除
        Positioned(
          left: 0,
          right: 0,
          bottom: 28,
          child: Center(child: _buildActionDock(theme)),
        ),
      ],
    );
  }

  Widget _buildActionDock(AppThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.stroke),
        boxShadow: [
          BoxShadow(
            color: theme.isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0x14221918),
            blurRadius: 36,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DockButton(
            theme: theme,
            icon: Icons.edit_outlined,
            tooltip: 'diary_edit'.tr,
            onTap: _startEditing,
          ),
          const SizedBox(width: 14),
          _DockButton(
            theme: theme,
            // 显示当前心情表情，无心情时显示添加图标
            emoji: _selectedMood,
            fallbackIcon: Icons.emoji_emotions_outlined,
            tooltip: 'diary_mood'.tr,
            onTap: _showMoodSelector,
          ),
          const SizedBox(width: 14),
          _DockButton(
            theme: theme,
            icon: Icons.delete_outline,
            tooltip: 'diary_deleteDiary'.tr,
            danger: true,
            onTap: _showDeleteConfirmation,
          ),
        ],
      ),
    );
  }

  /// 编辑态：顶部 [取消 + 保存]，标题/标签输入，编辑区，
  /// 富文本工具栏固定在底部（键盘上方）
  Widget _buildEditingView(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部操作行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _CircleIconButton(
                theme: theme,
                icon: Icons.close,
                onTap: _cancelEditing,
              ),
              const Spacer(),
              // 保存按钮（主色胶囊）
              Material(
                color: theme.primary,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: theme.onPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'diary_save'.tr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 标题行（mood + 标题输入）+ 字数
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
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
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'diary_titleHint'.tr,
                        hintStyle: TextStyle(color: theme.textSub),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$_wordCount ${'diary_wordUnit'.tr}',
                style: TextStyle(fontSize: 12, color: theme.textSub),
              ),
              const SizedBox(height: 8),
              _buildTagEditor(theme),
            ],
          ),
        ),

        // 编辑区
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: quill.QuillEditor.basic(
              controller: _contentController!,
              config: quill.QuillEditorConfig(
                placeholder: 'diary_contentHint'.tr,
                padding: const EdgeInsets.all(16),
                embedBuilders: kIsWeb
                    ? FlutterQuillEmbeds.editorWebBuilders()
                    : FlutterQuillEmbeds.editorBuilders(),
              ),
            ),
          ),
        ),

        // 富文本工具栏（固定在底部，键盘上方）
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.stroke),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // H1, H2
                quill.QuillToolbarSelectHeaderStyleDropdownButton(
                  controller: _contentController!,
                ),
                const SizedBox(width: 4),
                // Styles
                quill.QuillToolbarToggleStyleButton(
                  controller: _contentController!,
                  attribute: quill.Attribute.bold,
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: _contentController!,
                  attribute: quill.Attribute.italic,
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: _contentController!,
                  attribute: quill.Attribute.underline,
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: _contentController!,
                  attribute: quill.Attribute.strikeThrough,
                ),
                // Lists
                quill.QuillToolbarToggleStyleButton(
                  controller: _contentController!,
                  attribute: quill.Attribute.ul,
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: _contentController!,
                  attribute: quill.Attribute.ol,
                ),
                // Media
                QuillToolbarImageButton(controller: _contentController!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 标签编辑行：已有标签 chips（点击删除）+ 输入框（回车添加）
  Widget _buildTagEditor(AppThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in _tags)
          InputChip(
            label: Text(tag, style: TextStyle(color: theme.text, fontSize: 12)),
            backgroundColor: theme.surfaceAlt,
            side: BorderSide(color: theme.stroke),
            deleteIcon: Icon(Icons.close, size: 14, color: theme.textSub),
            onDeleted: () => _removeTag(tag),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _tagInputController,
            style: TextStyle(fontSize: 12, color: theme.text),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'diary_addTag'.tr,
              hintStyle: TextStyle(fontSize: 12, color: theme.textSub),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: theme.stroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide(color: theme.primary),
              ),
            ),
            onSubmitted: _addTag,
          ),
        ),
      ],
    );
  }
}

/// 圆形图标按钮（主题表面色 + 描边）
class _CircleIconButton extends StatelessWidget {
  final AppThemeData theme;
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.theme,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.surface,
      shape: CircleBorder(side: BorderSide(color: theme.stroke)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: theme.text),
        ),
      ),
    );
  }
}

/// 标签胶囊（表面色小圆角药丸，highlight 为主色描边）
class _TagPill extends StatelessWidget {
  final AppThemeData theme;
  final String label;
  final bool highlight;

  const _TagPill({
    required this.theme,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: highlight ? theme.primary : theme.stroke),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: highlight ? theme.primary : theme.textSub,
        ),
      ),
    );
  }
}

/// 底部 dock 圆形操作按钮
class _DockButton extends StatelessWidget {
  final AppThemeData theme;
  final IconData? icon;
  final String? emoji; // 优先于 icon 显示
  final IconData? fallbackIcon; // emoji 为空时使用
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  const _DockButton({
    required this.theme,
    required this.tooltip,
    required this.onTap,
    this.icon,
    this.emoji,
    this.fallbackIcon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? theme.danger.withValues(alpha: 0.12)
        : theme.backgroundAlt;
    final fg = danger ? theme.danger : theme.textSub;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: CircleBorder(
          side: BorderSide(color: theme.stroke.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: emoji != null
                  ? Builder(
                      builder: (_) {
                        final spec = diaryMoodSpecOf(emoji!);
                        return Image.asset(
                          // 未知表情无图片时回退图标
                          spec.asset ?? '',
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(fallbackIcon, size: 18, color: fg),
                        );
                      },
                    )
                  : Icon(icon ?? fallbackIcon, size: 18, color: fg),
            ),
          ),
        ),
      ),
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
