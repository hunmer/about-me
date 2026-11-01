// 脚本编辑：高级设置 Tab（脚本类型/更新地址/启用开关表单 + 组合触发条件与输入参数区块）。
part of 'script_edit_screen.dart';

/// 高级设置拆分：扩展 [_ScriptEditScreenState]，与类内方法等价。
extension _ScriptEditAdvanced on _ScriptEditScreenState {
  /// 获取高级设置表单字段配置
  List<FormFieldConfig> _getAdvancedFields() {
    final script = widget.script;
    return [
      // 脚本类型
      FormFieldConfig(
        name: 'type',
        type: FormFieldType.select,
        labelText: 'scripts_center_scriptType'.tr,
        prefixIcon: Icons.category,
        initialValue: script?.type ?? 'module',
        required: true,
        items: [
          DropdownMenuItem(
            value: 'module',
            child: Text('scripts_center_moduleType'.tr),
          ),
          DropdownMenuItem(
            value: 'standalone',
            child: Text('scripts_center_standaloneType'.tr),
          ),
        ],
      ),

      // 更新地址
      FormFieldConfig(
        name: 'updateUrl',
        type: FormFieldType.text,
        labelText: 'scripts_center_updateUrl'.tr,
        hintText: '例如：https://example.com/script.js',
        prefixIcon: Icons.cloud_download,
        initialValue: script?.updateUrl ?? '',
      ),

      // 启用开关
      FormFieldConfig(
        name: 'enabled',
        type: FormFieldType.switchField,
        labelText: 'scripts_center_enableScript'.tr,
        hintText: script?.enabled == true ? '脚本将在触发条件满足时执行' : '脚本已禁用，不会执行',
        prefixIcon: script?.enabled == true ? Icons.check_circle : Icons.cancel,
        initialValue: script?.enabled ?? true,
      ),
    ];
  }

  /// 构建高级设置标签页（含触发条件、输入参数）
  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 使用 FormBuilderWrapper 构建高级设置表单
          FormBuilderWrapper(
            formKey: _advancedFormKey,
            onStateReady: (state) => _advancedWrapperState = state,
            config: FormConfig(
              fields: _getAdvancedFields(),
              showSubmitButton: false,
              showResetButton: false,
              fieldSpacing: 24,
              onSubmit: _handleAdvancedSubmit,
            ),
          ),

          const SizedBox(height: 24),

          // 触发条件（自动运行开关 + 触发器列表）
          _buildTriggersSection(),

          const SizedBox(height: 24),

          // 输入参数设置（保留原有逻辑）
          _buildInputsSection(),
        ],
      ),
    );
  }
}
