import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

import 'gallery_section.dart';

/// 03 输入控件
class InputsSection extends StatefulWidget {
  const InputsSection({super.key});

  @override
  State<InputsSection> createState() => _InputsSectionState();
}

class _InputsSectionState extends State<InputsSection> {
  final _defaultController = TextEditingController();
  final _focusController = TextEditingController(text: '记录点什么呢...');
  final _errorController = TextEditingController();
  final _textareaController = TextEditingController();
  final _searchController = TextEditingController();
  int _stepperValue = 1;

  @override
  void dispose() {
    _defaultController.dispose();
    _focusController.dispose();
    _errorController.dispose();
    _textareaController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SectionCard(
      index: '03',
      title: '输入控件',
      children: [
        Wrap(
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.lg,
          children: [
            SizedBox(
              width: 220,
              child: DSInput(
                controller: _defaultController,
                hint: '记录点什么呢...',
                label: '默认',
              ),
            ),
            SizedBox(
              width: 220,
              child: DSInput(
                controller: _focusController,
                hint: '记录点什么呢...',
                label: '聚焦',
              ),
            ),
            SizedBox(
              width: 220,
              child: DSInput(
                controller: _errorController,
                hint: '记录点什么呢...',
                label: '错误',
                errorText: '输入内容不能为空哦',
              ),
            ),
            SizedBox(
              width: 220,
              child: DSInput(hint: '记录点什么呢...', label: '禁用', enabled: false),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        Wrap(
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.lg,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            SizedBox(
              width: 240,
              child: DSInput(
                controller: _textareaController,
                hint: '写下更多想法...',
                label: '多行文本框（Textarea）',
                maxLines: 3,
                minLines: 3,
              ),
            ),
            SizedBox(
              width: 240,
              child: DSInput.search(
                controller: _searchController,
                hint: '搜索内容...',
                label: '搜索框（Search）',
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DemoSubHeader('数字步进器（Stepper）'),
                DSStepper(
                  value: _stepperValue,
                  min: 1,
                  max: 10,
                  onChanged: (v) => setState(() => _stepperValue = v),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
