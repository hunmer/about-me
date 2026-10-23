import 'package:flutter/material.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/agent_chat/services/suggested_questions_service.dart';
import 'package:aboutme/plugins/agent_chat/services/suggested_question_test_status_service.dart';
import 'package:aboutme/plugins/agent_chat/models/suggested_question.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 预设问题选择对话框
class SuggestedQuestionsDialog extends StatefulWidget {
  final StorageManager storage;
  final bool multiSelect;

  const SuggestedQuestionsDialog({
    super.key,
    required this.storage,
    this.multiSelect = false,
  });

  @override
  State<SuggestedQuestionsDialog> createState() =>
      _SuggestedQuestionsDialogState();
}

class _SuggestedQuestionsDialogState extends State<SuggestedQuestionsDialog> {
  final _service = SuggestedQuestionsService();
  Map<String, List<String>>? _questions;
  String? _selectedCategory;
  bool _isLoading = true;
  final Map<String, Set<int>> _selectedQuestions = {};
  Map<String, SuggestedQuestionTestStatus> _testStatuses = {};

  List<SuggestedQuestion> get _selection => [
    for (final entry in (_questions ?? <String, List<String>>{}).entries)
      for (var i = 0; i < entry.value.length; i++)
        if (_selectedQuestions[entry.key]?.contains(i) ?? false)
          SuggestedQuestion(
            category: entry.key,
            categoryName: _service.getCategoryName(entry.key),
            question: entry.value[i],
          ),
  ];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _service.getCategorizedQuestions();
      final testStatuses = await _loadTestStatuses(questions);
      if (mounted) {
        // 尝试读取上次选中的分类
        String? lastCategory;
        try {
          final res = await AboutmeDataService.instance.call(
            'agent_chat',
            'getPreference',
            {'key': 'suggestedQuestionsCategory'},
          );
          final value = (res['success'] == true) ? res['data'] : null;
          if (value is String) lastCategory = value;
        } catch (e) {
          // 如果读取失败，忽略错误
          lastCategory = null;
        }

        if (!mounted) return;
        setState(() {
          _questions = questions;
          _testStatuses = testStatuses;
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

  Future<Map<String, SuggestedQuestionTestStatus>> _loadTestStatuses(
    Map<String, List<String>> questions,
  ) async {
    try {
      final res = await AboutmeDataService.instance.call(
        'agent_chat',
        'listTestRuns',
      );
      final rows = (res['success'] == true && res['data'] is List)
          ? res['data'] as List
          : null;
      final reports = rows?.whereType<Map>().toList() ?? const <Map>[];

      final statuses = <String, SuggestedQuestionTestStatus>{};
      for (final entry in questions.entries) {
        for (final question in entry.value) {
          final status = latestSuggestedQuestionTestStatus(
            reports,
            category: entry.key,
            question: question,
          );
          if (status != null) {
            statuses[_questionKey(entry.key, question)] = status;
          }
        }
      }
      return statuses;
    } catch (_) {
      return {};
    }
  }

  String _questionKey(String category, String question) =>
      '$category\u0000$question';

  String _formatTestDate(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  /// 保存当前选中的分类
  Future<void> _saveSelectedCategory(String category) async {
    try {
      await AboutmeDataService.instance.call(
        'agent_chat',
        'setPreference',
        {'key': 'suggestedQuestionsCategory', 'value': category},
      );
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
            child: _isLoading
                ? const Center(child: DSThemeBridge(child: DSLoadingDots()))
                : _questions == null || _questions!.isEmpty
                ? _buildEmptyState()
                : _buildQuestionsList(),
          ),
          if (widget.multiSelect &&
              !_isLoading &&
              _questions != null &&
              _questions!.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: DSButton(
                    onPressed: _selection.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selection),
                    label: '提交 (${_selection.length})',
                  ),
                ),
              ),
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
          Text(
            widget.multiSelect ? '选择测试问题' : '你可以问',
            style: DsTypography.title.copyWith(color: theme.text),
          ),
          const Spacer(),
          Pressable(
            onPressed: () => Navigator.pop(context),
            semanticLabel: '关闭',
            builder: (context, states) => SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: DsIcon(DsIconKind.close, size: 20, color: theme.textSub),
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
              for (final key in categoryKeys)
                '${_service.getCategoryName(key)}${widget.multiSelect ? ' (${_selectedQuestions[key]?.length ?? 0}/${_questions![key]!.length})' : ''}',
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
    return const Center(
      child: DSThemeBridge(
        child: DSEmptyState(icon: DsIconKind.info, title: '暂无可用的问题示例'),
      ),
    );
  }

  /// 构建问题列表（只显示选中分类的问题）
  Widget _buildQuestionsList() {
    final theme = DSThemeBridge.resolve(context);
    if (_selectedCategory == null) return const SizedBox.shrink();

    final questions = _questions![_selectedCategory] ?? [];

    final selected = _selectedQuestions[_selectedCategory] ?? <int>{};
    final allSelected =
        questions.isNotEmpty && selected.length == questions.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.multiSelect)
          CheckboxListTile(
            dense: true,
            title: const Text('全选本分组'),
            subtitle: const Text('按分组和列表顺序执行，问题会实际调用工具。'),
            tristate: true,
            value: allSelected
                ? true
                : selected.isEmpty
                ? false
                : null,
            onChanged: (_) => setState(() {
              if (!allSelected) {
                _selectedQuestions[_selectedCategory!] = {
                  for (var i = 0; i < questions.length; i++) i,
                };
              } else {
                _selectedQuestions.remove(_selectedCategory);
              }
            }),
          ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: questions.length,
            separatorBuilder: (context, index) => Divider(
              color: theme.textSub.withValues(alpha: 0.2),
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) =>
                _buildQuestionItem(questions[index], index),
          ),
        ),
      ],
    );
  }

  /// 构建单个问题项
  Widget _buildQuestionItem(String question, int index) {
    final theme = DSThemeBridge.resolve(context);
    final selected =
        _selectedQuestions[_selectedCategory]?.contains(index) ?? false;
    final testStatus =
        _testStatuses[_questionKey(_selectedCategory!, question)];
    void toggle() => setState(() {
      final selectedIndices = _selectedQuestions.putIfAbsent(
        _selectedCategory!,
        () => <int>{},
      );
      if (!selectedIndices.remove(index)) selectedIndices.add(index);
    });
    return Pressable(
      onPressed: widget.multiSelect
          ? toggle
          : () => Navigator.pop(context, question),
      semanticLabel: question,
      builder: (context, states) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: testStatus?.hasError == true
            ? BoxDecoration(
                color: theme.danger.withValues(alpha: 0.08),
                border: Border(left: BorderSide(color: theme.danger, width: 3)),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Text(
                question,
                style: DsTypography.body.copyWith(color: theme.text),
              ),
            ),
            if (testStatus != null) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTestDate(testStatus.lastTestAt),
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  if (testStatus.hasError)
                    Text(
                      '测试错误',
                      style: DsTypography.caption.copyWith(color: theme.danger),
                    ),
                ],
              ),
              if (testStatus.hasError) ...[
                const SizedBox(width: 4),
                Icon(Icons.error_outline, size: 18, color: theme.danger),
              ],
            ],
            if (widget.multiSelect)
              Checkbox(value: selected, onChanged: (_) => toggle())
            else
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
    builder: (context) => DSThemeBridge(
      child: Builder(
        builder: (context) => SuggestedQuestionsDialog(storage: storage),
      ),
    ),
  );
}

/// 测试入口启用多选；普通入口继续点选填入输入框。
Future<List<SuggestedQuestion>?> showSuggestedQuestionBatchPicker(
  BuildContext context,
  StorageManager storage,
) => SmoothBottomSheet.show<List<SuggestedQuestion>>(
  context: context,
  builder: (context) => DSThemeBridge(
    child: SuggestedQuestionsDialog(storage: storage, multiSelect: true),
  ),
);
