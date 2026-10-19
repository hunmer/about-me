import 'package:get/get.dart';
import 'package:aboutme/widgets/form_fields/field_type_selector_field.dart';
import 'package:aboutme/widgets/form_fields/form_builder_wrapper.dart';
import 'package:aboutme/widgets/form_fields/types.dart';
import 'package:aboutme/widgets/form_fields/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:aboutme/plugins/database/controllers/database_controller.dart';
import 'package:aboutme/plugins/database/models/database_model.dart';
import 'package:aboutme/plugins/database/models/field_model.dart';
import 'package:aboutme/plugins/database/models/database_field.dart';

class DatabaseEditWidget extends StatefulWidget {
  final DatabaseController controller;
  final DatabaseModel database;

  /// 以底部弹层形式嵌入（不渲染 Scaffold/AppBar，由外壳提供保存）
  final bool embedInSheet;

  /// 弹层模式下回传保存动作（外壳"保存"按钮触发）
  final void Function(VoidCallback submit)? onReady;

  const DatabaseEditWidget({
    super.key,
    required this.controller,
    required this.database,
    this.embedInSheet = false,
    this.onReady,
  });

  @override
  State<DatabaseEditWidget> createState() => _DatabaseEditWidgetState();
}

class _DatabaseEditWidgetState extends State<DatabaseEditWidget>
    with SingleTickerProviderStateMixin {
  late DatabaseModel _editedDatabase;
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();
  FormBuilderWrapperState? _wrapperState; // 用于外部提交按钮
  late TabController _tabController;
  List<FieldModel> _fields = [];
  bool _isSaving = false; // 标记是否正在保存

  /// 弹层模式下 DSTabs 的当前页（替代 Material TabController）
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _editedDatabase = widget.database;
    _tabController = TabController(length: 2, vsync: this);
    _fields = _editedDatabase.fields
        .map(
          (field) => FieldModel(
            id: field.id,
            name: field.name,
            type: field.type,
            // 将 metadata 对象转为 JSON 字符串存储在 description 中
            description: field.metadata != null
                ? jsonEncode(field.metadata)
                : null,
          ),
        )
        .toList();
    widget.onReady?.call(_saveChanges);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedInSheet) {
      // 弹层外壳（SmoothBottomSheet）已注入 AppTheme，可直接用 DS 组件
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DSTabs(
            labels: [
              'database_information_tab_title'.tr,
              'database_fields_tab_title'.tr,
            ],
            selected: _selectedTab,
            onChanged: (index) => setState(() => _selectedTab = index),
          ),
          Flexible(
            child: _selectedTab == 0 ? _buildInfoTab() : _buildFieldsTab(),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('database_edit_database_title'.tr),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'database_information_tab_title'.tr),
            Tab(text: 'database_fields_tab_title'.tr),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveChanges),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Information Tab
          _buildInfoTab(),
          // Fields Tab
          _buildFieldsTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: FormBuilderWrapper(
        formKey: _formKey,
        onStateReady: (state) => _wrapperState = state,
        config: FormConfig(
          showSubmitButton: false,
          showResetButton: false,
          fieldSpacing: 16,
          fields: [
            // 封面图片
            FormFieldConfig(
              name: 'coverImage',
              type: FormFieldType.imagePicker,
              labelText: 'database_cover_image_label'.tr,
              hintText: 'database_upload_cover_image'.tr,
              initialValue: _editedDatabase.coverImage,
              extra: {
                'enableCrop': true,
                'cropAspectRatio': 1.0,
                'saveDirectory': 'database_covers',
                'previewWidth': double.infinity,
                'previewHeight': 150.0,
                'showLabel': false,
                'showShadow': true,
              },
            ),
            // 数据库名称
            FormFieldConfig(
              name: 'name',
              type: FormFieldType.text,
              labelText: 'database_database_name_label'.tr,
              initialValue: _editedDatabase.name,
              required: true,
              validationMessage: 'database_field_required'.trParams({
                'name': 'database_database_name_label'.tr,
              }),
              prefixIcon: Icons.storage,
            ),

            // 描述
            FormFieldConfig(
              name: 'description',
              type: FormFieldType.textArea,
              labelText: 'database_description_label'.tr,
              hintText: 'database_description_hint'.tr,
              initialValue: _editedDatabase.description,
              prefixIcon: Icons.description,
            ),
          ],
          onSubmit: _handleFormSubmit,
        ),
      ),
    );
  }

  Widget _buildFieldsTab() {
    final theme = DSThemeBridge.resolve(context);
    return Stack(
      children: [
        ReorderableListView(
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _fields.removeAt(oldIndex);
              _fields.insert(newIndex, item);
            });
          },
          children: _fields.map((field) {
            // 解析 metadata 获取 showInPreview
            bool showInPreview = false;
            if (field.description != null && field.description!.isNotEmpty) {
              try {
                final metadata =
                    jsonDecode(field.description!) as Map<String, dynamic>?;
                showInPreview = metadata?['showInPreview'] == true;
              } catch (e) {
                // 解析失败，使用默认值
              }
            }

            return DSListItem(
              key: ValueKey(field.id),
              title: field.name,
              subtitle: field.type,
              leading: DSCheckbox(
                value: showInPreview,
                semanticLabel: 'database_show_in_preview'.tr,
                onChanged: (value) {
                  setState(() {
                    // 更新 metadata 中的 showInPreview
                    Map<String, dynamic>? metadata;
                    if (field.description != null &&
                        field.description!.isNotEmpty) {
                      try {
                        metadata =
                            jsonDecode(field.description!)
                                as Map<String, dynamic>?;
                      } catch (e) {
                        metadata = {};
                      }
                    } else {
                      metadata = {};
                    }
                    metadata ??= {};
                    metadata['showInPreview'] = value ?? false;

                    final index = _fields.indexWhere(
                      (f) => f.id == field.id,
                    );
                    if (index >= 0) {
                      _fields[index] = field.copyWith(
                        description: jsonEncode(metadata),
                      );
                    }
                  });
                },
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DSIconButton(
                    icon: DsIconKind.edit,
                    size: 32,
                    tooltip: 'app_edit'.tr,
                    onPressed: () => _editField(field),
                  ),
                  DSIconButton(
                    icon: DsIconKind.trash,
                    size: 32,
                    iconColor: theme.danger,
                    tooltip: 'app_delete'.tr,
                    onPressed: () => _deleteField(field),
                  ),
                  DsIcon(DsIconKind.drag, color: theme.textSub),
                ],
              ),
            );
          }).toList(),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: DSThemeBridge(
            // DSFab 内部取 AppTheme，需包桥
            child: DSFab(onPressed: _showAddFieldDialog),
          ),
        ),
      ],
    );
  }

  /// 处理表单提交（来自 FormBuilderWrapper）
  void _handleFormSubmit(Map<String, dynamic> values) {
    final name = values['name'] as String? ?? '';

    // coverImage 可能是 String（初始值）或 Map（ImagePickerDialog 返回值）
    String? coverImage;
    final coverImageValue = values['coverImage'];
    if (coverImageValue is Map) {
      coverImage = coverImageValue['url'] as String?;
    } else if (coverImageValue is String) {
      coverImage = coverImageValue;
    }

    final description = values['description'] as String?;

    setState(() {
      _editedDatabase = _editedDatabase.copyWith(
        name: name,
        coverImage: coverImage,
        description: description,
      );
    });

    // 如果是保存操作，在 setState 完成后执行保存
    if (_isSaving) {
      _isSaving = false;
      // 使用 Future.microtask 确保 setState 已完成
      Future.microtask(() => _performSave());
    }
  }

  Future<void> _editField(FieldModel field) async {
    final result = await showDialog<FieldModel>(
      context: context,
      builder: (context) => FieldTypeSelectorDialog(
        initialSelectedTypes: [field.type],
        dialogTitle: 'database_edit_field_title'.tr,
        multiSelect: false,
        showConfigTab: true,
        initialField: field,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final index = _fields.indexWhere((f) => f.id == result.id);
        if (index >= 0) {
          _fields[index] = result;
        } else {
          _fields.add(result);
        }
      });
    }
  }

  /// 删除字段
  Future<void> _deleteField(FieldModel field) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      builder: (context) => DSDialog(
        title: 'database_delete_field_title'.tr,
        message: 'database_delete_field_confirm'.trParams({
          'name': field.name,
        }),
        confirmText: 'app_delete'.tr,
        cancelText: 'app_cancel'.tr,
        confirmVariant: DSButtonVariant.destructive,
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _fields.removeWhere((f) => f.id == field.id);
      });
    }
  }

  Future<void> _showAddFieldDialog() async {
    final result = await showDialog<FieldModel>(
      context: context,
      builder: (context) => FieldTypeSelectorDialog(
        initialSelectedTypes: [],
        dialogTitle: 'database_select_field_type_title'.tr,
        multiSelect: false,
        showConfigTab: true,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final newField = FieldModel(
          id: const Uuid().v4(),
          name: result.name,
          type: result.type,
          description: result.description,
        );
        _fields.add(newField);
      });
    }
  }

  Future<void> _saveChanges() async {
    _isSaving = true;
    _wrapperState?.submitForm();
  }

  /// 执行实际的保存操作
  Future<void> _performSave() async {
    try {
      if (!mounted) return;

      // 转换字段模型并更新数据库
      final updatedDatabase = _editedDatabase.copyWith(
        fields: _fields.map((field) {
          // 将 FieldModel 的 description（JSON 字符串）解析为 metadata 对象
          Map<String, dynamic>? metadata;
          if (field.description != null && field.description!.isNotEmpty) {
            try {
              metadata = jsonDecode(field.description!) as Map<String, dynamic>;
            } catch (e) {
              // 解析失败，忽略
            }
          }

          return DatabaseField(
            id: field.id,
            name: field.name,
            type: field.type,
            isRequired: false,
            metadata: metadata,
          );
        }).toList(),
      );

      if (updatedDatabase.id.isEmpty) {
        final newDatabase = updatedDatabase.copyWith(id: const Uuid().v4());
        await widget.controller.createDatabase(newDatabase);
      } else {
        await widget.controller.updateDatabase(updatedDatabase);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
      debugPrint('Save failed: $e\n$stackTrace');
      if (mounted) {
        Toast.error(
          'database_save_failed_message'.trParams({'error': e.toString()}),
        );
      }
    }
  }
}
