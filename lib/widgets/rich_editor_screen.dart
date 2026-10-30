import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/common/cute_notepad_editor.dart';
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

  /// 编辑态是否显示标题/字数/标签编辑行（false 为纯内容编辑，如聊天高级编辑）
  final bool showTitle;
  final List<Widget> Function(AppThemeData theme)? readingPills;
  final List<Widget> Function(AppThemeData theme)? dockActions;
  final Widget? titleLeading;

  /// 保存回调，完成后组件自动 pop
  final Future<void> Function(String title, String content, List<String> tags)
  onSave;

  /// 删除回调；为 null 时 dock 不显示删除按钮
  final Future<void> Function()? onDelete;

  /// 样式设置入口（如背景/颜色/图标抽屉）；非 null 时
  /// 阅读态与编辑态右上角显示设置按钮，点击时由该回调弹出
  final VoidCallback? onOpenStyleSettings;

  /// 外部数据版本号：变化时组件重置为最新的 initial 数据
  /// （编辑态下会重建编辑控制器，用于外部同步刷新）
  final int reloadToken;

  final RichEditorTexts? texts;

  const RichEditorScreen({
    super.key,
    this.initialTitle = '',
    required this.initialContent,
    this.initialTags = const [],
    this.eyebrow,
    this.showTitle = true,
    this.readingPills,
    this.dockActions,
    this.titleLeading,
    required this.onSave,
    this.onDelete,
    this.onOpenStyleSettings,
    this.reloadToken = 0,
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
  // 编辑器稳定焦点节点：QuillEditor.basic 不传时工厂每次 build 都会新建
  // FocusNode，输入触发 setState 重建后旧焦点节点被 detach，焦点会跳到
  // 标题/标签输入框
  final FocusNode _editorFocusNode = FocusNode();

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
    // 无名路由打开时（RouteHistoryManager 记为 unknown），上报通用编辑页
    // 上下文供"询问当前上下文"识别；命名路由（如 /diary_edit）已带有效
    // 上下文，保持不动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = RouteHistoryManager.getCurrentContext();
      if (current == null || current.pageId == 'unknown') {
        RouteHistoryManager.updateCurrentContext(
          pageId: '/rich_editor',
          title: widget.initialTitle.trim().isEmpty
              ? '富文本编辑'
              : widget.initialTitle,
          params: {'title': widget.initialTitle},
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant RichEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadToken != oldWidget.reloadToken) {
      // 外部数据已更新：整体重置（编辑态下重建编辑控制器）
      _reloadFromInitial();
      return;
    }
    // 非编辑态时同步外部刷新的标签（如日记从存储重新加载）
    if (!_isEditing && !listEquals(oldWidget.initialTags, widget.initialTags)) {
      _tags = List.of(widget.initialTags);
    }
  }

  @override
  void dispose() {
    _disposeEditingControllers();
    _tagInputController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  // ===== 编辑态管理 =====

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _backupTags = List.of(_tags);
      _titleController = TextEditingController(text: _title);
      _contentController = _initQuillController(_contentJson);
      _listenWordCount();
    });
  }

  void _listenWordCount() {
    final controller = _contentController!;
    controller.document.changes.listen((change) {
      _tryConvertCheckboxMarkdown(change, controller);
      if (mounted) {
        setState(() {
          _wordCount = controller.document.toPlainText().trim().length;
        });
      }
    });
  }

  /// 外部数据已变化：重置为最新的 initial 数据；编辑态下重建编辑控制器
  void _reloadFromInitial() {
    _title = widget.initialTitle;
    _contentJson = widget.initialContent;
    _tags = List.of(widget.initialTags);
    _wordCount = _countChars(_contentJson);
    if (_isEditing) {
      _disposeEditingControllers();
      _backupTags = List.of(_tags);
      _titleController = TextEditingController(text: _title);
      _contentController = _initQuillController(_contentJson);
      _listenWordCount();
    }
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

  // ===== 分享 =====

  /// 当前内容快照（标题, Quill JSON）：编辑态取编辑控制器实时内容
  (String, String) _currentSnapshot() {
    final title = _isEditing ? (_titleController?.text ?? _title) : _title;
    final content = _isEditing && _contentController != null
        ? jsonEncode(_contentController!.document.toDelta().toJson())
        : _contentJson;
    return (title, content);
  }

  /// 分享文本（移动端系统分享）：标题 + 正文纯文本
  Future<void> _shareText() async {
    final (title, content) = _currentSnapshot();
    final text = tryParseQuillDeltaToText(content) ?? content;
    final body = title.trim().isEmpty ? text : '$title\n\n$text';
    if (body.trim().isEmpty) return;
    await Share.share(body);
  }

  /// 分享图片：内容带入可爱便签编辑器制作后分享/保存
  void _shareAsImage() {
    final (_, content) = _currentSnapshot();
    CuteNotepadEditorPage.show(context, initialText: content);
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

  /// 右上角「更多」气泡菜单：分享 / 分享图片
  Widget _buildMoreMenu(AppThemeData theme) {
    return DSPopover(
      width: 180,
      contentBuilder: (popoverContext, close) {
        final popoverTheme = DSThemeBridge.resolve(popoverContext);
        Widget menuRow(DsIconKind icon, String label, VoidCallback onTap) {
          return Pressable(
            onPressed: () {
              close();
              onTap();
            },
            builder: (context, states) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: states.contains(WidgetState.pressed)
                  ? popoverTheme.surfaceAlt
                  : null,
              child: Row(
                children: [
                  DsIcon(icon, size: 18, color: popoverTheme.textSub),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: DsTypography.body.copyWith(
                      color: popoverTheme.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            menuRow(DsIconKind.share, 'app_share'.tr, _shareText),
            menuRow(DsIconKind.image, 'app_shareImage'.tr, _shareAsImage),
          ],
        );
      },
      child: DSIconButton(
        icon: DsIconKind.more,
        size: 40,
        color: theme.surface,
        iconColor: theme.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return DSThemeBridge(
      child: Scaffold(
        backgroundColor: dsScaffoldBackground(theme),
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
                // 顶部导航行：圆形返回按钮（左）+ 样式设置/更多按钮（右）
                Row(
                  children: [
                    DSIconButton(
                      icon: DsIconKind.chevronLeft,
                      size: 40,
                      color: theme.surface,
                      iconColor: theme.text,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (widget.onOpenStyleSettings != null) ...[
                      DSIconButton(
                        icon: DsIconKind.tune,
                        size: 40,
                        color: theme.surface,
                        iconColor: theme.text,
                        onPressed: () => widget.onOpenStyleSettings!(),
                      ),
                      const SizedBox(width: 10),
                    ],
                    _buildMoreMenu(theme),
                  ],
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
        icon: DsIconKind.edit,
        tooltip: _text(widget.texts?.editTooltip, 'diary_edit'),
        onTap: _startEditing,
      ),
      ...?widget.dockActions?.call(theme),
      if (widget.onDelete != null)
        EditorDockButton(
          theme: theme,
          icon: DsIconKind.trash,
          tooltip: _text(widget.texts?.deleteTooltip, 'diary_deleteDiary'),
          danger: true,
          onTap: _showDeleteConfirmation,
        ),
    ];
    // 手绘墨盒 dock：实底 + 墨线描边胶囊（手绘风无柔影）
    return JellyBox(
      padding: const EdgeInsets.all(10),
      radius: BorderRadius.circular(999),
      color: theme.surface,
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
              DSIconButton(
                icon: DsIconKind.close,
                size: 40,
                color: theme.surface,
                iconColor: theme.text,
                onPressed: _cancelEditing,
              ),
              const Spacer(),
              if (widget.onOpenStyleSettings != null) ...[
                DSIconButton(
                  icon: DsIconKind.tune,
                  size: 40,
                  color: theme.surface,
                  iconColor: theme.text,
                  onPressed: () => widget.onOpenStyleSettings!(),
                ),
                const SizedBox(width: 10),
              ],
              _buildMoreMenu(theme),
              const SizedBox(width: 10),
              // 保存按钮（手绘主色胶囊）
              DSButton(
                label: _text(widget.texts?.save, 'diary_save'),
                icon: DsIconKind.check,
                size: DSButtonSize.sm,
                onPressed: _save,
              ),
            ],
          ),
        ),

        // 标题行（业务前缀 + 标题输入）+ 字数 + 标签编辑
        if (widget.showTitle)
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
              // 稳定焦点节点：见字段声明处注释
              focusNode: _editorFocusNode,
              config: quill.QuillEditorConfig(
                placeholder: _text(widget.texts?.contentHint, 'diary_contentHint'),
                padding: const EdgeInsets.all(16),
                // 渲染自定义字间距属性（与阅读态 QuillViewer 一致）
                customStyleBuilder: quillCustomStyleBuilder,
                embedBuilders: kIsWeb
                    ? FlutterQuillEmbeds.editorWebBuilders()
                    : FlutterQuillEmbeds.editorBuilders(),
              ),
            ),
          ),
        ),

        // 富文本工具栏（固定在底部，键盘上方）；容器走手绘墨线
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          padding: const EdgeInsets.all(8),
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: theme.surface,
            radius: BorderRadius.circular(16),
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
                // 行间距（quill 内置 line-height 属性，1 / 1.15 / 1.5 / 2 档）
                quill.QuillToolbarSelectLineHeightStyleDropdownButton(
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
                // 字间距（自定义 letter-spacing 属性，循环切换档位）
                _LetterSpacingToolbarButton(controller: _contentController!),
                // Lists
                quill.QuillToolbarToggleStyleButton(
                  controller: _contentController!,
                  attribute: quill.Attribute.ul,
                ),
                quill.QuillToolbarToggleStyleButton(
                  controller: _contentController!,
                  attribute: quill.Attribute.ol,
                ),
                // Check list
                quill.QuillToolbarToggleCheckListButton(
                  controller: _contentController!,
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

  /// 标签编辑行：已有标签手绘 chips（点 × 删除）+ 输入框（回车添加）
  Widget _buildTagEditor(AppThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in _tags)
          DSChip(label: tag, onDeleted: () => _removeTag(tag)),
        SizedBox(
          width: 160,
          child: DSInput(
            controller: _tagInputController,
            hint: _text(widget.texts?.addTag, 'diary_addTag'),
            onSubmitted: _addTag,
          ),
        ),
      ],
    );
  }
}

/// 行首的 markdown 复选框短语（含结尾空格）与勾选状态
const List<(String, bool)> _checkboxMarkdownPhrases = [
  ('- [x] ', true),
  ('- [X] ', true),
  ('- [ ] ', false),
];

/// 输入空格时识别行首 `- [ ] ` / `- [x] `，把该行转为复选框列表项。
/// 走文档变更流而非按键事件，软键盘同样生效；撤销重插入的不是
/// 单个空格，因此撤销后不会被立刻再次转换。
void _tryConvertCheckboxMarkdown(
    quill.DocChange change, quill.QuillController controller) {
  if (change.source != quill.ChangeSource.local) return;
  var insertPos = 0;
  String? inserted;
  for (final op in change.change.operations) {
    if (op.isDelete) return;
    if (op.isInsert) {
      inserted = op.data is String ? op.data as String : null;
      break;
    }
    insertPos += op.data is int ? op.data as int : 0;
  }
  if (inserted != ' ') return;

  final text = controller.document.toPlainText();
  if (insertPos < 0 || insertPos > text.length) return;
  var lineStart = insertPos;
  while (lineStart > 0 && text[lineStart - 1] != '\n') {
    lineStart--;
  }
  var lineEnd = insertPos;
  while (lineEnd < text.length && text[lineEnd] != '\n') {
    lineEnd++;
  }
  final line = text.substring(lineStart, lineEnd);
  for (final (phrase, checked) in _checkboxMarkdownPhrases) {
    if (!line.startsWith(phrase)) continue;
    controller.replaceText(lineStart, phrase.length, '', null);
    controller.updateSelection(
      TextSelection.collapsed(
        offset: insertPos - phrase.length > lineStart
            ? insertPos - phrase.length
            : lineStart,
      ),
      quill.ChangeSource.local,
    );
    controller.formatSelection(
      checked ? quill.Attribute.checked : quill.Attribute.unchecked,
    );
    return;
  }
}

/// 圆形图标按钮已由 DSIconButton 取代（手绘实底圆 + 墨线描边）

/// 标签胶囊（手绘墨线药丸，highlight 为主色描边）
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
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        stroke: highlight ? theme.primary : null,
        strokeWidth: highlight ? 2.2 : 1.5,
        radius: BorderRadius.circular(999),
        seed: label.hashCode & 0xffff,
      ),
      child: Text(
        label,
        style: DsTypography.caption.copyWith(
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
  final DsIconKind? icon;
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
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) => Container(
          width: 42,
          height: 42,
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: bg,
            circle: true,
            strokeWidth: 1.6,
            seed: 420,
          ),
          child: Center(
            child: child ?? DsIcon(icon!, size: 18, color: fg),
          ),
        ),
      ),
    );
  }
}

/// 字间距循环切换按钮：标准(清除) → 宽 1.0 → 更宽 2.0 → 标准。
/// quill 无内置字间距属性，走自定义 letter-spacing 属性，
/// 由 [quillCustomStyleBuilder] 映射到 TextStyle.letterSpacing 渲染。
class _LetterSpacingToolbarButton extends StatefulWidget {
  final quill.QuillController controller;

  const _LetterSpacingToolbarButton({required this.controller});

  @override
  State<_LetterSpacingToolbarButton> createState() =>
      _LetterSpacingToolbarButtonState();
}

class _LetterSpacingToolbarButtonState
    extends State<_LetterSpacingToolbarButton> {
  /// 档位序列：null 为清除属性（标准间距）
  static const List<double?> _levels = [null, 1.0, 2.0];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _LetterSpacingToolbarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// 选区当前生效的字间距（非数字视为无）
  double? get _current {
    final value = widget.controller
        .getSelectionStyle()
        .attributes[kQuillLetterSpacingKey]
        ?.value;
    return value is num ? value.toDouble() : null;
  }

  void _cycle() {
    final index = _levels.indexOf(_current);
    final next = _levels[(index + 1) % _levels.length];
    widget.controller.formatSelection(
      quill.Attribute(
        kQuillLetterSpacingKey,
        quill.AttributeScope.inline,
        next,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return quill.QuillToolbarIconButton(
      tooltip: 'app_letterSpacing'.tr,
      isSelected: _current != null,
      onPressed: _cycle,
      iconTheme: null,
      icon: const Icon(Icons.format_size),
    );
  }
}
