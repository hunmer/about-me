import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 工具配置表单弹层（由 ToolboxConfigField 列表驱动的通用配置页）
///
/// 用法：
/// ```dart
/// ToolboxConfigSheet.show(
///   context,
///   title: '图片搜索设置',
///   fields: service.configFields,
///   config: service.config,
///   onSave: (config) => service.saveConfig(config),
/// )
/// ```
class ToolboxConfigSheet extends StatefulWidget {
  final String title;
  final List<ToolboxConfigField> fields;
  final Map<String, dynamic> config;
  final Future<void> Function(Map<String, dynamic> config) onSave;

  const ToolboxConfigSheet({
    super.key,
    required this.title,
    required this.fields,
    required this.config,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<ToolboxConfigField> fields,
    required Map<String, dynamic> config,
    required Future<void> Function(Map<String, dynamic> config) onSave,
  }) {
    return SmoothBottomSheet.showScreen(
      context: context,
      screen: ToolboxConfigSheet(
        title: title,
        fields: fields,
        config: config,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ToolboxConfigSheet> createState() => _ToolboxConfigSheetState();
}

class _ToolboxConfigSheetState extends State<ToolboxConfigSheet> {
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, bool> _switches;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _switches = {};
    for (final field in widget.fields) {
      if (field.type == 'switchField') {
        _switches[field.name] = widget.config[field.name] == true;
      } else {
        _controllers[field.name] = TextEditingController(
          text: _initialText(field),
        );
      }
    }
  }

  String _initialText(ToolboxConfigField field) {
    final value = widget.config[field.name] ?? field.initialValue ?? '';
    return value.toString();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final config = <String, dynamic>{...widget.config};
      for (final field in widget.fields) {
        if (field.type == 'switchField') {
          config[field.name] = _switches[field.name] ?? false;
        } else if (field.type == 'number') {
          final text = _controllers[field.name]!.text.trim();
          config[field.name] = text.isEmpty ? field.initialValue : num.tryParse(text) ?? field.initialValue;
        } else {
          config[field.name] = _controllers[field.name]!.text.trim();
        }
      }
      // 必填校验
      for (final field in widget.fields) {
        if (field.required && config[field.name].toString().trim().isEmpty) {
          Toast.warning('${field.labelText} 未填写');
          return;
        }
      }
      await widget.onSave(config);
      if (mounted) {
        Toast.success('配置已保存');
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('app_save'.tr),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.lg,
          vertical: theme.spacing.md,
        ),
        children: [
          for (final field in widget.fields) _buildField(field, theme),
          SizedBox(height: theme.spacing.xl),
        ],
      ),
    );
  }

  Widget _buildField(ToolboxConfigField field, AppThemeData theme) {
    if (field.type == 'switchField') {
      return Padding(
        padding: EdgeInsets.only(bottom: theme.spacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(field.labelText, style: DsTypography.body.copyWith(color: theme.text)),
                  if (field.hintText.isNotEmpty)
                    Text(
                      field.hintText,
                      style: DsTypography.caption.copyWith(color: theme.textSub),
                    ),
                ],
              ),
            ),
            DSSwitch(
              value: _switches[field.name] ?? false,
              onChanged: (v) => setState(() => _switches[field.name] = v),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DSInput(
            controller: _controllers[field.name],
            label: field.labelText + (field.required ? ' *' : ''),
            hint: field.hintText,
            obscureText: field.type == 'password',
            keyboardType: field.type == 'number'
                ? TextInputType.number
                : TextInputType.text,
          ),
        ],
      ),
    );
  }
}
