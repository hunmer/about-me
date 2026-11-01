// 脚本编辑：保存提交流程（验证并保存 / 基本信息与高级设置表单值合并 / 生成 scriptData 弹出返回）。
part of 'script_edit_screen.dart';

/// 保存流程拆分：扩展 [_ScriptEditScreenState]，与类内方法等价。
extension _ScriptEditSave on _ScriptEditScreenState {
  /// 验证并保存
  void _saveScript() {
    _basicInfoWrapperState?.submitForm();
  }

  /// 处理基本信息表单提交
  void _handleBasicInfoSubmit(Map<String, dynamic> values) {
    // 检查widget是否仍然mounted
    if (!mounted) {
      return;
    }

    // 保存基本信息表单的值
    _basicInfoValues = values;

    // 检查高级设置表单是否已初始化
    if (_advancedWrapperState != null) {
      // 如果已初始化，提交表单获取值
      _advancedWrapperState!.submitForm();
    } else {
      // 如果未初始化，使用默认值直接保存
      _handleAdvancedSubmit(_getDefaultAdvancedValues());
    }
  }

  /// 获取高级设置的默认值
  Map<String, dynamic> _getDefaultAdvancedValues() {
    final script = widget.script;
    return {
      'type': script?.type ?? 'module',
      'enabled': script?.enabled ?? true,
      'updateUrl': script?.updateUrl ?? '',
    };
  }

  /// 处理高级设置表单提交（最终提交）
  void _handleAdvancedSubmit(Map<String, dynamic> advancedValues) {
    // 检查widget是否仍然mounted
    if (!mounted) {
      return;
    }

    // 在保存前，获取配置表单的最新值（如果已初始化），写入当前配置文件
    if (_configWrapperState != null) {
      final configValues = _configWrapperState!.currentValues;
      if (configValues.isNotEmpty) {
        _currentProfile.values = configValues;
      }
    }
    // 未初始化时各配置文件的 values 保持加载/实时同步的值

    // 获取保存的基本信息表单的值
    final basicValues = _basicInfoValues ?? {};

    // 验证必填字段
    final name = basicValues['name']?.toString().trim() ?? '';
    if (name.isEmpty && widget.initialData == null) {
      toastService.showToast('请输入脚本名称');
      return;
    }

    // id 不再手动输入：编辑/导入沿用原值，新建从名称自动生成
    String id = isEditMode
        ? widget.script?.id ?? ''
        : widget.initialData?['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      // 名称转小写，非字母数字（空格、中文、符号）统一替换为下划线
      id = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      if (id.isEmpty) {
        id = 'script_${DateTime.now().millisecondsSinceEpoch}';
      }
      toastService.showToast('已自动生成脚本ID: $id');
    }

    // 从 icon 字段中提取图标名称（circleIconPicker 返回 Map）
    String iconValue = 'code';
    if (basicValues['icon'] != null) {
      if (basicValues['icon'] is Map) {
        final iconMap = basicValues['icon'] as Map;
        final iconData = iconMap['icon'] as IconData?;
        iconValue = iconData != null ? _getIconName(iconData) : 'code';
      } else if (basicValues['icon'] is String) {
        iconValue = basicValues['icon'] as String;
      }
    }

    // 合并两个表单的数据
    final scriptData = {
      'name': name,
      'id': id,
      'description': basicValues['description']?.toString().trim() ?? '',
      'author': basicValues['author']?.toString().trim() ?? '',
      'version': basicValues['version']?.toString().trim() ?? '1.0.0',
      'icon': iconValue,
      'type': advancedValues['type']?.toString() ?? 'module',
      'enabled': advancedValues['enabled'] as bool? ?? true,
      'autoRun': _autoRun,
      'code': _codeController.text,
      'inputs': _inputs,
      'triggers': _triggers.map((t) => t.toJson()).toList(),
      'updateUrl':
          advancedValues['updateUrl']?.toString().trim().isEmpty == true
              ? null
              : advancedValues['updateUrl']?.toString().trim(),
      'localScriptPath': _localScriptPath,
    };

    // 保存配置文件（如果有配置表单字段）
    if (_configFormFields.isNotEmpty) {
      _ensureProfiles();
      scriptData['config'] = {
        'profiles': _profiles.map((p) => p.toJson()).toList(),
        'defaultProfileId': _defaultProfileId ?? _profiles.first.id,
      };
    }

    // 保存配置表单字段定义（如果有）
    if (_configFormFields.isNotEmpty) {
      scriptData['configFormFields'] = _configFormFields;
    }

    // 再次检查mounted，因为这是在异步回调中
    if (mounted) {
      Navigator.of(context).pop(scriptData);
    }
  }
}
