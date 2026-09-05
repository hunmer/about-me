import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 标签选择组件
///
/// 功能特性：
/// - 显示已选标签的 DS Chips（可删除）
/// - 内嵌输入框（编辑原语），回车完成添加
/// - 支持快捷选择标签
/// - 支持字母过滤（A-Z 和中文拼音首字母）
class TagsField extends StatefulWidget {
  /// 已选标签列表
  final List<String> tags;

  /// 添加标签的回调
  final Function(String tag) onAddTag;

  /// 删除标签的回调
  final Function(String tag) onRemoveTag;

  /// 添加按钮的文本
  final String addButtonText;

  /// 主题色（保留以兼容配置；DS 件一律取主题令牌）
  final Color primaryColor;

  /// 快捷选择标签列表（点击可快速添加到已选标签）
  final List<String>? quickSelectTags;

  /// 快捷选择标签的回调
  final Function(String tag)? onQuickSelectTag;

  const TagsField({
    super.key,
    required this.tags,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.addButtonText,
    this.primaryColor = const Color(0xFF607AFB),
    this.quickSelectTags,
    this.onQuickSelectTag,
  });

  @override
  State<TagsField> createState() => _TagsFieldState();
}

class _TagsFieldState extends State<TagsField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isEditing = false;
  String? _filterLetter; // 当前过滤的字母，null 表示显示所有

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    _focusNode.requestFocus();
  }

  void _submitTag() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onAddTag(text);
      _controller.clear();
    }
    setState(() {
      _isEditing = false;
    });
    _focusNode.unfocus();
  }

  /// 获取标签的拼音首字母（大写）
  String _getPinyinFirstLetter(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return '';

    // 判断是否为英文字母
    if (trimmed[0].contains(RegExp(r'[a-zA-Z]'))) {
      return trimmed[0].toUpperCase();
    }

    // 使用 lpinyin 获取中文拼音首字母
    final pinyin = PinyinHelper.getFirstWordPinyin(trimmed);
    if (pinyin != null && pinyin.isNotEmpty) {
      return pinyin[0].toUpperCase();
    }

    return '';
  }

  /// 获取待选标签的首字母集合（已排序）
  Set<String> _getAvailableLetters() {
    if (widget.quickSelectTags == null) return {};
    return widget.quickSelectTags!
        .where((tag) => !widget.tags.contains(tag)) // 排除已选标签
        .map((tag) => _getPinyinFirstLetter(tag))
        .where((letter) => letter.isNotEmpty)
        .toSet();
  }

  /// 根据当前过滤条件获取显示的待选标签列表
  List<String> _getFilteredQuickSelectTags() {
    if (widget.quickSelectTags == null) return [];
    final unselectedTags =
        widget.quickSelectTags!
            .where((tag) => !widget.tags.contains(tag))
            .toList();
    if (_filterLetter == null) {
      return unselectedTags;
    }
    return unselectedTags
        .where((tag) => _getPinyinFirstLetter(tag) == _filterLetter)
        .toList();
  }

  /// 过滤标签
  void _filterByLetter(String? letter) {
    setState(() {
      _filterLetter = letter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final availableLetters = _getAvailableLetters();
    final filteredQuickSelectTags = _getFilteredQuickSelectTags();

    return JellyBox(
      radius: theme.radii.lg,
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 已选标签区域
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _isEditing ? _buildEditingPill(theme) : _buildAddButton(theme),
              ...widget.tags.map((tag) => _buildTagChip(tag)),
            ],
          ),
          // A-Z 过滤器按钮（仅在有待选标签时显示）
          if (availableLetters.isNotEmpty) ...[
            SizedBox(height: theme.spacing.md),
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableLetters.length + 1, // +1 为"全部"按钮
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // 全部按钮
                    return _buildFilterButton(
                      '全部',
                      _filterLetter == null,
                      () => _filterByLetter(null),
                    );
                  }
                  // A-Z 按钮按字母排序
                  final letters = availableLetters.toList()..sort();
                  final letter = letters[index - 1];
                  return _buildFilterButton(
                    letter,
                    _filterLetter == letter,
                    () => _filterByLetter(letter),
                  );
                },
              ),
            ),
          ],
          // 快捷选择标签区域
          if (filteredQuickSelectTags.isNotEmpty) ...[
            SizedBox(height: theme.spacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  filteredQuickSelectTags
                      .map((tag) => _buildQuickSelectChip(tag))
                      .toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 编辑态的输入胶囊（TextField 为嵌入自绘容器的编辑原语）
  Widget _buildEditingPill(AppThemeData theme) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: theme.primary.mixWhite(0.92),
        borderRadius: theme.radii.pill,
        border: Border.all(color: theme.primary, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(minWidth: 80),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                style: DsTypography.caption.copyWith(color: theme.text),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: '输入标签',
                  hintStyle: DsTypography.caption.copyWith(
                    color: theme.textSub.withValues(alpha: 0.75),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitTag(),
                onEditingComplete: _submitTag,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _controller.clear();
              setState(() => _isEditing = false);
              _focusNode.unfocus();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: DsIcon(DsIconKind.close, size: 14, color: theme.textSub),
            ),
          ),
        ],
      ),
    );
  }

  /// 添加标签按钮
  Widget _buildAddButton(AppThemeData theme) {
    return Pressable(
      onPressed: _startEditing,
      semanticLabel: widget.addButtonText,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DsIcon(DsIconKind.plus, size: 18, color: theme.primary),
                const SizedBox(width: 4),
                Text(
                  widget.addButtonText,
                  style: DsTypography.caption.copyWith(color: theme.primary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建已选标签的 Chip
  Widget _buildTagChip(String tag) {
    return DSChip(label: tag, onDeleted: () => widget.onRemoveTag(tag));
  }

  /// 构建快捷选择标签的 Chip
  Widget _buildQuickSelectChip(String tag) {
    return DSChip(
      label: tag,
      onSelected: (_) => widget.onQuickSelectTag?.call(tag),
    );
  }

  /// 构建字母过滤器按钮
  Widget _buildFilterButton(String label, bool isSelected, VoidCallback onTap) {
    return SizedBox(
      height: 28,
      child: Center(
        child: DSChip(
          label: label,
          selected: isSelected,
          onSelected: (_) => onTap(),
        ),
      ),
    );
  }
}
