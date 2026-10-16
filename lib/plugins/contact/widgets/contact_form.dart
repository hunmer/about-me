import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/form_fields/index.dart';

import 'package:aboutme/plugins/contact/models/contact_model.dart';

/// 联系人基础信息编辑表单（Warm Paper Sketch，布局参考纪念日编辑页）
///
/// 字段：头像+姓名 / 性别 / 电话 / 备注 / 标签 / 地址。
/// 无保存按钮：字段变更防抖 [_saveDebounceMs] 后自动提交 [onSave]，
/// 关闭页面时未落盘的变更立即 flush。
/// 注意 [onSave] 会被多次调用，调用方需幂等（已存在则更新）。
/// 事件记录与自定义字段在详情页编辑，保存时保留原值。
class ContactForm extends StatefulWidget {
  final Contact? contact;
  final Function(Contact) onSave;
  final Function()? onDelete;

  /// 以底部弹层形式嵌入（不渲染 Scaffold，保留自带标题头）
  final bool embedInSheet;

  const ContactForm({
    super.key,
    this.contact,
    required this.onSave,
    this.onDelete,
    this.embedInSheet = false,
  });

  @override
  State<ContactForm> createState() => ContactFormState();
}

class ContactFormState extends State<ContactForm> {
  /// 自动保存防抖间隔
  static const Duration _saveDebounceMs = Duration(milliseconds: 500);

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();

  String? _avatarUrl;
  ContactGender? _gender;
  List<String> _tags = [];

  /// 联系人 id：编辑取原值，新建生成一次并复用（保证自动保存不产生多条）
  late final String _id;

  Timer? _saveDebounce;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();

    final contact = widget.contact;
    _id = contact?.id ?? const Uuid().v4();
    if (contact != null) {
      final names = contact.name.split(' ');
      _firstNameController.text = names.first;
      _lastNameController.text = names.length > 1
          ? names.sublist(1).join(' ')
          : '';
      _phoneController.text = contact.phone;
      _notesController.text = contact.notes ?? '';
      _addressController.text = contact.address ?? '';
      _avatarUrl = contact.avatar;
      _gender = contact.gender;
      _tags = List.from(contact.tags);
    }

    // 初始值填充完成后再挂监听，避免程序化赋值触发自动保存
    for (final c in _textControllers) {
      c.addListener(_scheduleSave);
    }
  }

  List<TextEditingController> get _textControllers => [
    _firstNameController,
    _lastNameController,
    _phoneController,
    _notesController,
    _addressController,
  ];

  @override
  void dispose() {
    _saveDebounce?.cancel();
    // 未落盘的变更立即保存（onSave 为外部回调，不依赖本 State 生命周期）
    if (_dirty) _saveNow();
    for (final c in _textControllers) {
      c.removeListener(_scheduleSave);
    }
    for (final c in _textControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// 防抖调度自动保存
  void _scheduleSave() {
    _dirty = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceMs, _saveNow);
  }

  void _saveNow() {
    // 姓名为空的中间态静默跳过，保留脏标记等下次触发
    final name = '${_firstNameController.text} ${_lastNameController.text}'
        .trim();
    if (name.isEmpty) return;

    _dirty = false;
    final existing = widget.contact;
    widget.onSave(
      Contact(
        id: _id,
        name: name,
        avatar: _avatarUrl,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        tags: _tags,
        gender: _gender,
        // 事件记录与自定义字段在详情页编辑，保存时保留原值
        customFields: existing?.customFields ?? const {},
        customActivityEvents: existing?.customActivityEvents ?? const [],
        createdTime: existing?.createdTime ?? DateTime.now(),
        lastContactTime: existing?.lastContactTime ?? DateTime.now(),
        isFavorite: existing?.isFavorite ?? false,
        // 保留表单外字段与图标设置
        organization: existing?.organization,
        email: existing?.email,
        website: existing?.website,
        icon: existing?.icon ?? Icons.person,
        iconColor: existing?.iconColor ?? Colors.blue,
      ),
    );
  }

  /// 删除确认（手绘对话框，危险色确认钮）
  void _showDeleteConfirm() {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSDialog(
        title: 'contact_confirmDelete'.tr,
        message: 'contact_deleteConfirmMessage'.tr,
        confirmText: 'app_delete'.tr,
        cancelText: 'contact_cancel'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () {
          Navigator.of(dialogContext).pop();
          widget.onDelete?.call();
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) Navigator.of(context).pop();
          });
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contact != null;

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          final header = DSLightHeader(
            title: isEditing
                ? 'contact_editContact'.tr
                : 'contact_addContact'.tr,
            trailing: isEditing
                ? DSIconButton(
                    icon: DsIconKind.trash,
                    size: 38,
                    color: theme.surface,
                    iconColor: theme.danger,
                    tooltip: 'contact_deleteContact'.tr,
                    onPressed: _showDeleteConfirm,
                  )
                : null,
          );
          final fields = SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              // sheet 模式由外壳统一追加底部安全区，避免双重留白
              bottom: widget.embedInSheet
                  ? 24
                  : MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: _buildFields(),
          );

          if (widget.embedInSheet) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                Flexible(child: fields),
              ],
            );
          }

          return Scaffold(
            backgroundColor: dsScaffoldBackground(theme),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  header,
                  Expanded(child: fields),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AvatarNameSection(
          avatarUrl: _avatarUrl,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          onAvatarChanged: (url) {
            setState(() => _avatarUrl = url);
            _scheduleSave();
          },
          // 姓名经 controller.text 赋值，由 listener 触发自动保存
          onFirstNameChanged: (v) =>
              setState(() => _firstNameController.text = v),
          onLastNameChanged: (v) =>
              setState(() => _lastNameController.text = v),
        ),
        const SizedBox(height: 24),

        GenderSelectorField(
          selectedGender: _gender,
          onGenderChanged: (gender) {
            setState(() => _gender = gender);
            _scheduleSave();
          },
        ),
        const SizedBox(height: 24),

        TextInputField(
          controller: _phoneController,
          labelText: 'contact_phoneLabel'.tr,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 24),

        TextAreaField(
          controller: _notesController,
          labelText: 'contact_notesLabel'.tr,
          hintText: 'contact_notesHint'.tr,
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: 24),

        TagsField(
          tags: _tags,
          onAddTag: (tag) {
            setState(() => _tags = [..._tags, tag]);
            _scheduleSave();
          },
          onRemoveTag: (tag) {
            setState(() => _tags = _tags.where((t) => t != tag).toList());
            _scheduleSave();
          },
          addButtonText: 'contact_addTag'.tr,
        ),
        const SizedBox(height: 24),

        TextInputField(
          controller: _addressController,
          labelText: 'contact_addressLabel'.tr,
        ),
      ],
    );
  }
}
