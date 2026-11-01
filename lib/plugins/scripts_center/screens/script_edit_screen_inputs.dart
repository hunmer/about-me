// 脚本编辑：输入参数管理（Module 类型脚本的参数增删改列表与编辑对话框入口）。
part of 'script_edit_screen.dart';

/// 输入参数拆分：扩展 [_ScriptEditScreenState]，与类内方法等价。
extension _ScriptEditInputs on _ScriptEditScreenState {
  /// 添加输入参数
  Future<void> _addInput() async {
    final input = await showDialog<ScriptInput>(
      context: context,
      builder: (context) => const ScriptInputForm(),
    );

    if (input != null) {
      setState(() {
        _inputs.add(input);
      });
    }
  }

  /// 编辑输入参数
  Future<void> _editInput(int index) async {
    final input = await showDialog<ScriptInput>(
      context: context,
      builder: (context) => ScriptInputForm(input: _inputs[index]),
    );

    if (input != null) {
      setState(() {
        _inputs[index] = input;
      });
    }
  }

  /// 删除输入参数
  void _deleteInput(int index) {
    setState(() {
      _inputs.removeAt(index);
    });
  }

  /// 根据输入类型获取对应图标
  IconData _getInputTypeIcon(String type) {
    switch (type) {
      case 'string':
        return Icons.text_fields;
      case 'number':
        return Icons.numbers;
      case 'boolean':
        return Icons.toggle_on;
      case 'select':
        return Icons.list;
      default:
        return Icons.input;
    }
  }

  /// 构建输入参数部分
  Widget _buildInputsSection() {
    final theme = DSThemeBridge.resolve(context);
    final scriptType =
        _advancedFormKey.currentState?.value['type'] ??
        widget.script?.type ??
        'module';

    if (scriptType != 'module') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DsIcon(DsIconKind.clipboard, size: 20, color: theme.primary),
            const SizedBox(width: 8),
            Text(
              '输入参数',
              style: DsTypography.heading.copyWith(color: theme.text),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 参数列表
        if (_inputs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: theme.stroke),
              borderRadius: theme.radii.lg,
            ),
            child: Column(
              children: [
                DsIcon(DsIconKind.info, size: 40, color: theme.disabled),
                const SizedBox(height: 12),
                Text(
                  '暂无输入参数',
                  style: DsTypography.body.copyWith(color: theme.textSub),
                ),
                const SizedBox(height: 8),
                Text(
                  '为 Module 类型脚本添加输入参数，执行时会显示表单收集用户输入',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._inputs.asMap().entries.map((entry) {
            final index = entry.key;
            final input = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border.all(color: theme.stroke),
                borderRadius: theme.radii.lg,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    _getInputTypeIcon(input.type),
                    color: theme.primary,
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      input.label,
                      style: DsTypography.body.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${input.key})',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                    if (input.required) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.warning.withValues(alpha: 0.1),
                          borderRadius: theme.radii.sm,
                        ),
                        child: Text(
                          '必填',
                          style: DsTypography.caption.copyWith(
                            color: theme.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  input.description ?? '类型: ${input.type}',
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      color: theme.textSub,
                      onPressed: () => _editInput(index),
                      tooltip: '编辑',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      color: theme.danger,
                      onPressed: () => _deleteInput(index),
                      tooltip: '删除',
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 12),

        // 添加参数按钮
        DSButton(
          label: 'scripts_center_addInputParameter'.tr,
          icon: DsIconKind.plus,
          variant: DSButtonVariant.outline,
          onPressed: _addInput,
        ),
      ],
    );
  }
}
