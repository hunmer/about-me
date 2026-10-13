import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

import 'package:aboutme/plugins/contact/controllers/contact_controller.dart';
import 'package:aboutme/plugins/contact/models/contact_model.dart';
import 'package:aboutme/plugins/contact/models/custom_activity_event_model.dart';
import 'package:aboutme/plugins/contact/widgets/contact_form.dart';

/// 联系人详情页（Warm Paper Sketch，布局参考纪念日详情页）
///
/// 上部：iconColor 弧底 header（返回/姓名/编辑 + 圆形头像 + 标签胶囊）
/// + 基本信息卡（电话/邮箱/组织/地址/备注）；
/// 下部：自定义活动事件与自定义字段两个区块，骑缝加号新增，点击编辑、长按删除。
/// 右上角编辑进入 ContactForm（基础信息编辑页）。
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({
    super.key,
    required this.contact,
    required this.controller,
  });

  /// 初始联系人对象（仅取 id，展示时始终从 controller 取最新数据）
  final Contact contact;
  final ContactController controller;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final _textController = TextEditingController();
  final _valueController = TextEditingController();
  final _focusNode = FocusNode();

  /// 当前联系人最新数据
  Contact? _current;

  @override
  void initState() {
    super.initState();
    _current = widget.contact;
  }

  @override
  void dispose() {
    _textController.dispose();
    _valueController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 从 controller 重读最新数据（编辑/增删事件字段后调用）
  Future<void> _reload() async {
    final latest = await widget.controller.getContact(widget.contact.id);
    if (!mounted) return;

    // 联系人已被删除（编辑表单删除路径兜底）：自动返回
    if (latest == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _current = latest);
  }

  Future<void> _update(Contact contact) async {
    await widget.controller.updateContact(contact);
    await _reload();
  }

  /// 右上角编辑：进入基础信息编辑表单
  Future<void> _openEditor(Contact contact) async {
    await NavigationHelper.push(
      context,
      ContactForm(
        contact: contact,
        onSave: (saved) => widget.controller.updateContact(saved),
        onDelete: () => widget.controller.deleteContact(contact.id),
      ),
    );
    await _reload();
  }

  // ==================== 事件 / 字段编辑 ====================

  /// 区块标题行：标题文本 + 右侧小加号按钮（直接新增）
  Widget _buildSectionHeader(
    AppThemeData theme,
    String title, {
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: DsTypography.heading.copyWith(color: theme.text),
            ),
          ),
          Pressable(
            onPressed: onPressed,
            builder: (context, states) {
              final pressed = states.contains(WidgetState.pressed);
              return Transform.scale(
                scale: pressed ? 0.9 : 1.0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    fillColor: theme.surface,
                    circle: true,
                    strokeWidth: 1.4,
                    seed: 21,
                  ),
                  child: Center(
                    child: DsIcon(
                      DsIconKind.plus,
                      size: 15,
                      color: theme.text,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 新增/编辑自定义活动事件（标题输入，颜色按色板轮转）
  void _showEventDialog(Contact contact, [CustomActivityEvent? event]) {
    final isEditing = event != null;
    _textController.text = event?.title ?? '';
    showDSDialog(
      context: context,
      builder: (dialogContext) => DSDialog(
        title: isEditing
            ? 'contact_customActivityEvents'.tr
            : 'contact_addCustomEvent'.tr,
        content: DSInput(
          controller: _textController,
          focusNode: _focusNode,
          hint: 'contact_eventTitleHint'.tr,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitEvent(dialogContext, contact, event),
        ),
        confirmText: 'contact_done'.tr,
        cancelText: 'contact_cancel'.tr,
        onConfirm: () => _submitEvent(dialogContext, contact, event),
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
    if (!isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  void _submitEvent(
    BuildContext dialogContext,
    Contact contact,
    CustomActivityEvent? event,
  ) {
    final title = _textController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(dialogContext).pop();

    final theme = DSThemeBridge.resolve(context);
    final palette = [
      theme.primary,
      theme.secondary,
      theme.success,
      theme.warning,
      theme.danger,
    ];
    final events = [...contact.customActivityEvents];
    if (event == null) {
      events.add(
        CustomActivityEvent(color: palette[events.length % palette.length], title: title),
      );
    } else {
      final i = events.indexWhere((e) => e.id == event.id);
      if (i >= 0) {
        events[i] = CustomActivityEvent(id: event.id, color: event.color, title: title);
      }
    }
    _update(contact.copyWith(customActivityEvents: events));
  }

  /// 新增/编辑自定义字段（名称 + 内容两个输入）
  void _showFieldDialog(Contact contact, [MapEntry<String, String>? field]) {
    _textController.text = field?.key ?? '';
    _valueController.text = field?.value ?? '';
    showDSDialog(
      context: context,
      builder: (dialogContext) => DSDialog(
        title: field == null
            ? 'contact_addCustomField'.tr
            : 'contact_customFields'.tr,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DSInput(
              controller: _textController,
              hint: 'contact_fieldNameLabel'.tr,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            DSInput(
              controller: _valueController,
              hint: 'contact_fieldValueLabel'.tr,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitField(dialogContext, contact, field),
            ),
          ],
        ),
        confirmText: 'contact_done'.tr,
        cancelText: 'contact_cancel'.tr,
        onConfirm: () => _submitField(dialogContext, contact, field),
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _submitField(
    BuildContext dialogContext,
    Contact contact,
    MapEntry<String, String>? field,
  ) {
    final key = _textController.text.trim();
    final value = _valueController.text.trim();
    if (key.isEmpty) return;
    Navigator.of(dialogContext).pop();

    final fields = {...contact.customFields};
    // 编辑旧键时先移除，避免改名后残留旧键
    if (field != null) fields.remove(field.key);
    fields[key] = value;
    _update(contact.copyWith(customFields: fields));
  }

  /// 长按删除事件/字段确认
  void _confirmRemove(String title, VoidCallback onConfirm) {
    showDSDialog(
      context: context,
      builder: (dialogContext) => DSDialog(
        title: 'contact_confirmDelete'.tr,
        message: title,
        confirmText: 'app_delete'.tr,
        cancelText: 'contact_cancel'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () {
          Navigator.of(dialogContext).pop();
          onConfirm();
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  // ==================== 布局 ====================

  /// 内容区弧形拱起的高度
  static const double _arcDepth = 36;

  @override
  Widget build(BuildContext context) {
    final contact = _current;
    if (contact == null) return const SizedBox.shrink();

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            backgroundColor: theme.background,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(context, theme, contact),
                  Expanded(
                    child: _buildContentSection(theme, contact),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeData theme, Contact contact) {
    final accent = contact.iconColor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // accent 底色块 + 主块墨线框
        Positioned.fill(child: ColoredBox(color: accent.withValues(alpha: 0.3))),
        Positioned.fill(
          child: IgnorePointer(child: _SketchStrokeOverlay(theme: theme, seed: 3)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 72),
          child: Column(
            children: [
              // 顶行：返回 / 姓名 / 编辑
              Row(
                children: [
                  _HeaderCircleButton(
                    theme: theme,
                    icon: DsIconKind.chevronLeft,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                  ),
                  _HeaderCircleButton(
                    theme: theme,
                    icon: DsIconKind.edit,
                    onTap: () => _openEditor(contact),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAvatar(theme, contact, accent),
              const SizedBox(height: 14),
              // 标签胶囊
              if (contact.tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final tag in contact.tags)
                      _buildHeaderBadge(theme, tag),
                  ],
                ),
              const SizedBox(height: 8),
              // 收藏星标
              if (contact.isFavorite)
                DsIcon(
                  DsIconKind.star,
                  size: 20,
                  color: theme.primary,
                  fill: true,
                ),
            ],
          ),
        ),
        // 内容区弧形拱起
        Positioned(
          left: 0,
          right: 0,
          bottom: -1,
          child: SizedBox(
            height: _arcDepth + 1,
            child: CustomPaint(painter: _ArcHeaderPainter(theme.background)),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(AppThemeData theme, Contact contact, Color accent) {
    final hasImage = contact.avatar != null && contact.avatar!.isNotEmpty;

    return Container(
      width: 96,
      height: 96,
      decoration: dsSketchDecoration(
        theme: theme,
        circle: true,
        fillColor: hasImage ? theme.surface : accent.withValues(alpha: 0.25),
        stroke: theme.ink.withValues(alpha: 0.55),
        strokeWidth: 2,
        seed: 9,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? AdaptiveImage(
              imagePath: contact.avatar,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            )
          : Icon(contact.icon, size: 44, color: accent),
    );
  }

  /// header 胶囊 badge：纸底贴纸 + 墨字
  Widget _buildHeaderBadge(AppThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: theme.radii.pill,
        strokeWidth: 1.4,
        seed: 7,
      ),
      child: Text(
        label,
        style: DsTypography.label.copyWith(color: theme.text),
      ),
    );
  }

  Widget _buildContentSection(AppThemeData theme, Contact contact) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        _buildBasicInfoCard(theme, contact),
        const SizedBox(height: 16),
        _buildEventsSection(theme, contact),
        const SizedBox(height: 16),
        _buildFieldsSection(theme, contact),
      ],
    );
  }

  /// 基本信息卡：电话/邮箱/组织/地址/备注
  Widget _buildBasicInfoCard(AppThemeData theme, Contact contact) {
    final rows = <(DsIconKind, String, String)>[
      if (contact.phone.isNotEmpty)
        (DsIconKind.chat, 'contact_phone'.tr, contact.phone),
      if (contact.email != null && contact.email!.isNotEmpty)
        (DsIconKind.send, 'contact_email'.tr, contact.email!),
      if (contact.organization != null && contact.organization!.isNotEmpty)
        (DsIconKind.store, 'contact_organizationLabel'.tr, contact.organization!),
      if (contact.address != null && contact.address!.isNotEmpty)
        (DsIconKind.pin, 'contact_address'.tr, contact.address!),
      if (contact.notes != null && contact.notes!.isNotEmpty)
        (DsIconKind.book, 'contact_notes'.tr, contact.notes!),
    ];

    return DsSketchPanel(
      theme: theme,
      radius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'contact_basicInfoTab'.tr,
            style: DsTypography.heading.copyWith(color: theme.text),
          ),
          const SizedBox(height: 10),
          for (final (icon, label, value) in rows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsIcon(icon, size: 18, color: theme.textSub),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildEventsSection(AppThemeData theme, Contact contact) {
    final events = contact.customActivityEvents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          '${'contact_customActivityEvents'.tr} (${events.length})',
          onPressed: () => _showEventDialog(contact),
        ),
        if (events.isEmpty)
          Text(
            'contact_noNotes'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          )
        else
          for (final event in events)
            _buildEventRow(theme, contact, event),
      ],
    );
  }

  Widget _buildEventRow(
    AppThemeData theme,
    Contact contact,
    CustomActivityEvent event,
  ) {
    return Pressable(
      onPressed: () => _showEventDialog(contact, event),
      onLongPress: () => _confirmRemove(
        event.title,
        () {
          final events = [...contact.customActivityEvents]
            ..removeWhere((e) => e.id == event.id);
          _update(contact.copyWith(customActivityEvents: events));
        },
      ),
      builder: (context, states) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: BorderRadius.circular(14),
          seed: event.id.hashCode,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: event.color.withValues(alpha: 0.55),
                circle: true,
                strokeWidth: 1.4,
                seed: event.id.hashCode + 40,
              ),
              child: Center(
                child: DsIcon(
                  DsIconKind.calendarCheck,
                  size: 15,
                  color: theme.text,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DsTypography.body.copyWith(color: theme.text),
              ),
            ),
            DsIcon(
              DsIconKind.chevronRight,
              size: 14,
              color: theme.textSub.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsSection(AppThemeData theme, Contact contact) {
    final fields = contact.customFields.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          '${'contact_customFields'.tr} (${fields.length})',
          onPressed: () => _showFieldDialog(contact),
        ),
        if (fields.isEmpty)
          Text(
            'contact_noNotes'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          )
        else
          for (final field in fields)
            _buildFieldRow(theme, contact, field),
      ],
    );
  }

  Widget _buildFieldRow(
    AppThemeData theme,
    Contact contact,
    MapEntry<String, String> field,
  ) {
    return Pressable(
      onPressed: () => _showFieldDialog(contact, field),
      onLongPress: () => _confirmRemove(
        field.key,
        () {
          final fields = {...contact.customFields}..remove(field.key);
          _update(contact.copyWith(customFields: fields));
        },
      ),
      builder: (context, states) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: BorderRadius.circular(14),
          seed: field.key.hashCode,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.primary.withValues(alpha: 0.12),
                radius: theme.radii.pill,
                strokeWidth: 1.2,
                seed: field.key.hashCode + 80,
              ),
              child: Text(
                field.key,
                style: DsTypography.label.copyWith(color: theme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                field.value,
                style: DsTypography.body.copyWith(color: theme.text),
              ),
            ),
            DsIcon(
              DsIconKind.chevronRight,
              size: 14,
              color: theme.textSub.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// 内容区顶部弧形：应用背景色、向上拱起的贝塞尔弧，铺满全宽
class _ArcHeaderPainter extends CustomPainter {
  _ArcHeaderPainter(this.fillColor);

  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width / 2,
        -size.height,
        size.width,
        size.height,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = fillColor);
  }

  @override
  bool shouldRepaint(covariant _ArcHeaderPainter old) =>
      old.fillColor != fillColor;
}

/// 顶层手绘墨线描边（与 day 插件 SketchStrokeOverlay 等价的私有副本）
class _SketchStrokeOverlay extends StatelessWidget {
  const _SketchStrokeOverlay({required this.theme, this.seed = 1});

  final AppThemeData theme;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DecorationPainter(
        dsSketchDecoration(theme: theme, strokeWidth: 1.8, seed: seed),
      ),
    );
  }
}

class _DecorationPainter extends CustomPainter {
  _DecorationPainter(this.decoration) : _painter = decoration.createBoxPainter();

  final RoughBoxDecoration decoration;
  final BoxPainter _painter;

  @override
  void paint(Canvas canvas, Size size) {
    _painter.paint(canvas, Offset.zero, ImageConfiguration(size: size));
  }

  @override
  bool shouldRepaint(_DecorationPainter oldDelegate) =>
      !identical(oldDelegate.decoration, decoration);
}

/// header 顶行圆形按钮：纸色圆底 + 墨色图标
class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.theme,
    required this.icon,
    this.onTap,
  });

  final AppThemeData theme;
  final DsIconKind icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Transform.scale(
          scale: pressed ? 0.92 : 1.0,
          child: Container(
            width: 38,
            height: 38,
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: theme.surface,
              circle: true,
              strokeWidth: 1.4,
              seed: 5,
            ),
            child: Center(
              child: DsIcon(icon, size: 18, color: theme.text),
            ),
          ),
        );
      },
    );
  }
}
