import 'package:flutter/material.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/agent_chat/services/suggested_questions_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 预设问题选择对话框
class SuggestedQuestionsDialog extends StatefulWidget {
  final StorageManager storage;

  const SuggestedQuestionsDialog({super.key, required this.storage});

  @override
  State<SuggestedQuestionsDialog> createState() =>
      _SuggestedQuestionsDialogState();
}

class _SuggestedQuestionsDialogState extends State<SuggestedQuestionsDialog> {
  // 存储上次选中分类的 key
  static const String _lastCategoryKey =
      'agent_chat/suggested_questions_last_category';

  final _service = SuggestedQuestionsService();
  Map<String, List<String>>? _questions;
  String? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _service.getCategorizedQuestions();
      if (mounted) {
        // 尝试读取上次选中的分类
        String? lastCategory;
        try {
          lastCategory = await AboutmeDataService.instance.readPathText(
            _lastCategoryKey,
          );
        } catch (e) {
          // 如果读取失败，忽略错误
          lastCategory = null;
        }

        setState(() {
          _questions = questions;
          // 优先使用上次选中的分类（如果存在且有效），否则选中第一个
          if (questions.isNotEmpty) {
            if (lastCategory != null && questions.containsKey(lastCategory)) {
              _selectedCategory = lastCategory;
            } else {
              _selectedCategory = questions.keys.first;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        toastService.showToast('加载问题失败: $e', type: ToastType.error);
      }
    }
  }

  /// 保存当前选中的分类
  Future<void> _saveSelectedCategory(String category) async {
    try {
      await AboutmeDataService.instance.writePath(_lastCategoryKey, category);
    } catch (e) {
      // 保存失败不影响功能，忽略错误
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DsRadii.xlValue),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          _buildHeader(),

          // 分类按钮横向滚动列表
          if (!_isLoading && _questions != null && _questions!.isNotEmpty)
            _buildCategoryTabs(),

          // 内容区域
          Flexible(
            child:
                _isLoading
                    ? const Center(child: DSThemeBridge(child: DSLoadingDots()))
                    : _questions == null || _questions!.isEmpty
                    ? _buildEmptyState()
                    : _buildQuestionsList(),
          ),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DsRadii.xlValue),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          DsIcon(DsIconKind.star, color: theme.warning),
          const SizedBox(width: 8),
          Text('你可以问', style: DsTypography.title.copyWith(color: theme.text)),
          const Spacer(),
          Pressable(
            onPressed: () => Navigator.pop(context),
            semanticLabel: '关闭',
            builder:
                (context, states) => SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: DsIcon(
                      DsIconKind.close,
                      size: 20,
                      color: theme.textSub,
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  /// 构建分类标签栏
  Widget _buildCategoryTabs() {
    final theme = DSThemeBridge.resolve(context);
    final categoryKeys = _questions!.keys.toList();
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.surfaceAlt.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.textSub.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DSChipBar(
            labels: [
              for (final key in categoryKeys) _service.getCategoryName(key),
            ],
            selected: categoryKeys
                .indexOf(_selectedCategory ?? '')
                .clamp(0, categoryKeys.length - 1),
            onChanged: (index) {
              setState(() => _selectedCategory = categoryKeys[index]);
              // 保存选中的分类
              _saveSelectedCategory(categoryKeys[index]);
            },
          ),
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final theme = DSThemeBridge.resolve(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(DsIconKind.info, size: 64, color: theme.textSub),
            const SizedBox(height: 16),
            Text(
              '暂无可用的问题示例',
              style: DsTypography.heading.copyWith(color: theme.textSub),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建问题列表（只显示选中分类的问题）
  Widget _buildQuestionsList() {
    final theme = DSThemeBridge.resolve(context);
    if (_selectedCategory == null) return const SizedBox.shrink();

    final questions = _questions![_selectedCategory] ?? [];

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: questions.length,
      separatorBuilder:
          (context, index) => Divider(
            color: theme.textSub.withValues(alpha: 0.2),
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
      itemBuilder: (context, index) => _buildQuestionItem(questions[index]),
    );
  }

  /// 构建单个问题项
  Widget _buildQuestionItem(String question) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: () => Navigator.pop(context, question),
      semanticLabel: question,
      builder:
          (context, states) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    question,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                ),
                DsIcon(
                  DsIconKind.chevronRight,
                  size: 14,
                  color: theme.textSub.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
    );
  }
}

/// 显示预设问题对话框
Future<String?> showSuggestedQuestionsDialog(
  BuildContext context,
  StorageManager storage,
) {
  return SmoothBottomSheet.show<String>(
    context: context,
    builder:
        (context) => DSThemeBridge(
          child: Builder(
            builder: (context) => SuggestedQuestionsDialog(storage: storage),
          ),
        ),
  );
}
