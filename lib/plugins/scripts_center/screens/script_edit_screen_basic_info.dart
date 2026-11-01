// 脚本编辑：基本信息 Tab（图标/名称/描述/作者/版本表单字段定义与布局）。
part of 'script_edit_screen.dart';

/// 基本信息拆分：扩展 [_ScriptEditScreenState]，与类内方法等价。
extension _ScriptEditBasicInfo on _ScriptEditScreenState {
  /// 获取基本信息表单字段配置
  List<FormFieldConfig> _getBasicInfoFields() {
    final theme = DSThemeBridge.resolve(context);
    final script = widget.script;
    final initialData = widget.initialData;

    // 优先使用initialData中的值，其次使用script中的值
    final iconName = initialData?['icon'] as String? ?? script?.icon ?? 'code';
    final iconData = _getIconData(iconName);

    return [
      // 图标选择 - 使用 circleIconPicker
      FormFieldConfig(
        name: 'icon',
        type: FormFieldType.circleIconPicker,
        labelText: 'scripts_center_icon'.tr,
        initialValue: {'icon': iconData, 'color': theme.primary},
        extra: {
          'initialBackgroundColor': theme.primary,
          'showLabel': true,
          'labelText': 'scripts_center_selectIcon'.tr,
        },
      ),

      // 脚本名称
      FormFieldConfig(
        name: 'name',
        type: FormFieldType.text,
        labelText: 'scripts_center_scriptName'.tr,
        hintText: '例如：自动备份助手',
        prefixIcon: Icons.title,
        initialValue: initialData?['name'] as String? ?? script?.name ?? '',
        required: true,
        validationMessage: '请输入脚本名称',
      ),

      // 描述
      FormFieldConfig(
        name: 'description',
        type: FormFieldType.textArea,
        labelText: 'scripts_center_description'.tr,
        hintText: '简短描述脚本的功能',
        prefixIcon: Icons.description,
        initialValue:
            initialData?['description'] as String? ?? script?.description ?? '',
        extra: {'maxLines': 3},
      ),

      // 作者
      FormFieldConfig(
        name: 'author',
        type: FormFieldType.text,
        labelText: 'scripts_center_author'.tr,
        hintText: '例如：张三',
        prefixIcon: Icons.person,
        initialValue: initialData?['author'] as String? ?? script?.author ?? '',
      ),

      // 版本号
      FormFieldConfig(
        name: 'version',
        type: FormFieldType.text,
        labelText: 'scripts_center_version'.tr,
        hintText: '例如：1.0.0',
        prefixIcon: Icons.tag,
        initialValue:
            initialData?['version'] as String? ?? script?.version ?? '1.0.0',
        required: true,
        validationMessage: '请输入版本号',
      ),
    ];
  }

  /// 构建基本信息标签页
  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FormBuilderWrapper(
        formKey: _basicInfoFormKey,
        onStateReady: (state) => _basicInfoWrapperState = state,
        config: FormConfig(
          fields: _getBasicInfoFields(),
          showSubmitButton: false,
          showResetButton: false,
          fieldSpacing: 16,
          onSubmit: _handleBasicInfoSubmit,
        ),
      ),
    );
  }
}
