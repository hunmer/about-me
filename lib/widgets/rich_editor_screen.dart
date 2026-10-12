import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/quill_viewer/index.dart';

/// 通用富文本编辑屏文案覆盖项（默认沿用日记文案，按业务覆盖需要的字段）
class RichEditorTexts {
  final String? untitled;
  final String? wordUnit;
  final String? emptyContent;
  final String? editTooltip;
  final String? deleteTooltip;
  final String? confirmDeleteTitle;
  final String? confirmDeleteMessage;
  final String? confirmDelete;
  final String? cancel;
  final String? save;
  final String? titleHint;
  final String? contentHint;
  final String? addTag;

  const RichEditorTexts({
    this.untitled,
    this.wordUnit,
    this.emptyContent,
    this.editTooltip,
    this.deleteTooltip,
    this.confirmDeleteTitle,
    this.confirmDeleteMessage,
    this.confirmDelete,
    this.cancel,
    this.save,
    this.titleHint,
    this.contentHint,
    this.addTag,
  });
}

/// 通用富文本编辑屏：阅读态 + 编辑态（从日记编辑屏抽离）。
///
/// 内部管理标题、标签、字数与 Quill 富文本内容的阅读/编辑切换；
/// 业务特有内容（如日记的心情）通过可选插槽挂载：
/// - [eyebrow] 阅读态大标题上方的眉题（如日期）
/// - [readingPills] 阅读态标签行的前置胶囊
/// - [dockActions] 阅读态底部 dock 的额外按钮（编辑与删除之间）
/// - [titleLeading] 编辑态标题行前缀
class RichEditorScreen extends StatefulWidget {
  final String initialTitle;
  final String initialContent;
  final List<String> initialTags;
  final String? eyebrow;
  final List<Widget> Function(AppThemeData theme)? readingPills;
  final List<Widget> Function(AppThemeData theme)? dockActions;
  final Widget? titleLeading;

  /// 保存回调，完成后组件自动 pop
  final Future<void> Function(String title, String content, List<String> tags)
  onSave;

  /// 删除回调；为 null 时 dock 不显示删除按钮
  final Future<void> Function()? onDelete;

  final RichEditorTexts? texts;

  const RichEditorScreen({
    super.key,
    this.initialTitle = '',
    required this.initialContent,
    this.initialTags = const [],
    this.eyebrow,
    this.readingPills,
    this.dockActions,
    this.titleLeading,
    required this.onSave,
    this.onDelete,
    this.texts,
  });

  @override
  State<RichEditorScreen> createState() => _RichEditorScreenState();
}

class _RichEditorScreenState extends State<RichEditorScreen> {
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

  // 取消编辑时还原标签
  List<String> _backupTags = const [];

  String _text(String? override, String fallbackKey) =>
      override ?? fallbackKey.tr;

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    _contentJson = widget.initialContent;
    _tags = List.of(widget.initialTags);
    _isNewEntry = widget.initialContent.trim().isEmpty;
    _wordCount = _countChars(_contentJson);
    if (_isNewEntry) {
      _startEditing();
    }
  }

  @override
  void didUpdateWidget(covariant RichEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 非编辑态时同步外部刷新的标签（如日记从存储重新加载）
    if (!_isEditing && !listEquals(oldWidget.initialTags, widget.initialTags)) {
      _tags = List.of(widget.initialTags);
    }
  }

  @override
  void dispose() {
    _disposeEditingControllers();
    _tagInputController.dispose();
    super.dispose();
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
    if (content.trim().isEmpty) return 0;
    try {
      return quill.Document.fromJson(jsonDecode(content))
          .toPlainText()
          .trim()
          .length;
    } catch (e) {
      return content.trim().length;
    }
  }

  Future<void> _save() async {
    final title = _titleController?.text ?? _title;
    final content = _isEditing && _contentController != null
        ? jsonEncode(_contentController!.document.toDelta().toJson())
        : _contentJson;

    await widget.onSave(title, content, List.of(_tags));
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

  void _showDeleteConfirmation() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSDialog(
        title: _text(widget.texts?.confirmDeleteTitle, 'diary_confirmDeleteDiary'),
        message: _text(widget.texts?.confirmDeleteMessage, 'diary_deleteDiaryMessage'),
        confirmText: _text(widget.texts?.confirmDelete, 'diary_confirmDeleteDiary'),
        cancelText: _text(widget.texts?.cancel, 'app_cancel'),
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () async {
          // 关闭对话框
          Navigator.pop(dialogContext);
          // 执行删除
          await widget.onDelete?.call();
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
          child: _isEditing ? _buildEditingView(theme) : _buildReadingView(theme),
        ),
      ),
    );
  }

  /// 阅读态 + 底部悬浮操作 dock
  Widget _buildReadingView(AppThemeData theme) {
    final title = _title.trim().isEmpty
        ? _text(widget.texts?.untitled, 'diary_untitled')
        : _title;

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

                // 眉题（主色大写宽字距），如日期
                if (widget.eyebrow != null) ...[
                  Text(
                    widget.eyebrow!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: theme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

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

                // 标签胶囊行：业务前置胶囊 + 标签 + 字数
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ...?widget.readingPills?.call(theme),
                    for (final tag in _tags) EditorTagPill(theme: theme, label: tag),
                    EditorTagPill(
                      theme: theme,
                      label: '$_wordCount ${_text(widget.texts?.wordUnit, 'diary_wordUnit')}',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 正文
                if (_contentJson.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Text(
                      _text(widget.texts?.emptyContent, 'diary_emptyContent'),
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

        // 底部悬浮操作 dock：编辑 / 业务扩展 / 删除
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
    final actions = <Widget>[
      EditorDockButton(
        theme: theme,
        icon: Icons.edit_outlined,
        tooltip: _text(widget.texts?.editTooltip, 'diary_edit'),
        onTap: _startEditing,
      ),
      ...?widget.dockActions?.call(theme),
      if (widget.onDelete != null)
        EditorDockButton(
          theme: theme,
          icon: Icons.delete_outline,
          tooltip: _text(widget.texts?.deleteTooltip, 'diary_deleteDiary'),
          danger: true,
          onTap: _showDeleteConfirmation,
        ),
    ];
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
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            actions[i],
          ],
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
                          _text(widget.texts?.save, 'diary_save'),
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

        // 标题行（业务前缀 + 标题输入）+ 字数
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.titleLeading != null) widget.titleLeading!,
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                      decoration: InputDecoration(
                        hintText: _text(widget.texts?.titleHint, 'diary_titleHint'),
                        hintStyle: TextStyle(color: theme.textSub),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$_wordCount ${_text(widget.texts?.wordUnit, 'diary_wordUnit')}',
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
                placeholder: _text(widget.texts?.contentHint, 'diary_contentHint'),
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
              hintText: _text(widget.texts?.addTag, 'diary_addTag'),
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
class EditorTagPill extends StatelessWidget {
  final AppThemeData theme;
  final String label;
  final bool highlight;

  const EditorTagPill({
    super.key,
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

/// 底部 dock 圆形操作按钮（child 优先于 icon 显示）
class EditorDockButton extends StatelessWidget {
  final AppThemeData theme;
  final IconData? icon;
  final Widget? child;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  const EditorDockButton({
    super.key,
    required this.theme,
    required this.tooltip,
    required this.onTap,
    this.icon,
    this.child,
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
              child: child ?? Icon(icon, size: 18, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
