import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/form_fields/index.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

import 'package:aboutme/plugins/contact/models/contact_model.dart';

/// 联系人基础信息编辑表单（Warm Paper Sketch，布局参考纪念日编辑页）
///
/// 字段：头像+姓名 / 性别 / 电话 / 备注 / 标签 / 地址。
/// 事件记录与自定义字段在详情页编辑，保存时保留原值。
class ContactForm extends StatefulWidget {
  final Contact? contact;
  final Function(Contact) onSave;
  final Function()? onDelete;

  const ContactForm({
    super.key,
    this.contact,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ContactForm> createState() => ContactFormState();
}

class ContactFormState extends State<ContactForm> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();

  String? _avatarUrl;
  ContactGender? _gender;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    if (contact == null) return;

    final names = contact.name.split(' ');
    _firstNameController.text = names.first;
    _lastNameController.text =
        names.length > 1 ? names.sublist(1).join(' ') : '';
    _phoneController.text = contact.phone;
    _notesController.text = contact.notes ?? '';
    _addressController.text = contact.address ?? '';
    _avatarUrl = contact.avatar;
    _gender = contact.gender;
    _tags = List.from(contact.tags);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    final name =
        '${_firstNameController.text} ${_lastNameController.text}'.trim();
    if (name.isEmpty) {
      showDSToast(
        context,
        message: 'contact_nameRequiredError'.tr,
        type: DSToastType.warning,
      );
      return;
    }

    final existing = widget.contact;
    final newContact = Contact(
      id: existing?.id ?? const Uuid().v4(),
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
    );

    widget.onSave(newContact);

    // 延迟等待 onSave 回调完成
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) Navigator.of(context).pop();
    });
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

    return SuperCupertinoNavigationWrapper(
      title: Text(
        isEditing ? 'contact_editContact'.tr : 'contact_addContact'.tr,
      ),
      previousPageTitle: 'contact_contacts'.tr,
      // SuperAppBar 的 actions 经 Overlay 渲染，DS 组件需自带 DSThemeBridge
      actions: [
        // 删除联系人（仅编辑模式）
        if (isEditing)
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.trash,
                  size: 36,
                  color: theme.surface,
                  iconColor: theme.danger,
                  tooltip: 'contact_deleteContact'.tr,
                  onPressed: _showDeleteConfirm,
                );
              },
            ),
          ),
        const SizedBox(width: 8),
        DSThemeBridge(
          child: Builder(
            builder: (context) => DSButton(
              label: 'contact_done'.tr,
              size: DSButtonSize.sm,
              onPressed: _save,
            ),
          ),
        ),
      ],
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AvatarNameSection(
                    avatarUrl: _avatarUrl,
                    firstName: _firstNameController.text,
                    lastName: _lastNameController.text,
                    onAvatarChanged: (url) => setState(() => _avatarUrl = url),
                    onFirstNameChanged: (v) =>
                        setState(() => _firstNameController.text = v),
                    onLastNameChanged: (v) =>
                        setState(() => _lastNameController.text = v),
                  ),
                  const SizedBox(height: 24),

                  GenderSelectorField(
                    selectedGender: _gender,
                    onGenderChanged: (gender) =>
                        setState(() => _gender = gender),
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
                    onAddTag: (tag) => setState(
                      () => _tags = [..._tags, tag],
                    ),
                    onRemoveTag: (tag) => setState(
                      () => _tags = _tags.where((t) => t != tag).toList(),
                    ),
                    addButtonText: 'contact_addTag'.tr,
                  ),
                  const SizedBox(height: 24),

                  TextInputField(
                    controller: _addressController,
                    labelText: 'contact_addressLabel'.tr,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
