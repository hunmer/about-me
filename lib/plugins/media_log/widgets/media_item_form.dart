import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/design_system/design_system.dart';

import '../models/media_item.dart';
import 'media_cover.dart';

/// 新建/编辑媒体条目表单（底部 sheet）
///
/// 返回构建好的 [MediaItem]（未落库，由调用方保存）。
class MediaItemForm extends StatefulWidget {
  const MediaItemForm({
    super.key,
    required this.kind,
    this.initial,
    this.showDelete = false,
  });

  /// 新建时的默认类型（编辑时以 initial 为准）
  final MediaKind kind;

  /// 编辑模式的初始条目
  final MediaItem? initial;

  /// 编辑模式是否显示删除入口
  final bool showDelete;

  @override
  State<MediaItemForm> createState() => _MediaItemFormState();
}

class _MediaItemFormState extends State<MediaItemForm> {
  late MediaKind _kind = widget.initial?.kind ?? widget.kind;
  late final TextEditingController _titleController = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _authorController = TextEditingController(
    text: widget.initial?.author ?? '',
  );
  late final TextEditingController _tagsController = TextEditingController(
    text: widget.initial?.tags.join(', '),
  );
  late final TextEditingController _overviewController = TextEditingController(
    text: widget.initial?.overview ?? '',
  );

  late CoverStyle _cover = widget.initial?.cover ?? CoverStyle.sheep;
  double _rating = 0;
  DateTime? _finishedAt;

  @override
  void initState() {
    super.initState();
    _rating = widget.initial?.rating ?? 0;
    _finishedAt = widget.initial?.finishedAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _tagsController.dispose();
    _overviewController.dispose();
    super.dispose();
  }

  Future<void> _pickFinishedDate() async {
    final picked = await showDSDatePickerDialog(
      context: context,
      initial: _finishedAt ?? DateTime.now(),
      cancelText: 'media_cancel'.tr,
      confirmText: 'media_confirm'.tr,
    );
    if (picked != null) {
      setState(() => _finishedAt = picked);
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      Toast.info('media_titleRequired'.tr);
      return;
    }
    final tags = _tagsController.text
        .split(RegExp(r'[,，]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final overview = _overviewController.text.trim();

    final result = MediaItem(
      id: widget.initial?.id ?? '',
      kind: _kind,
      title: title,
      author: _authorController.text.trim().isEmpty
          ? null
          : _authorController.text.trim(),
      cover: _cover,
      aspect: widget.initial?.aspect ?? 1.42,
      rating: _rating > 0 ? _rating : null,
      overview: overview.isEmpty ? null : overview,
      tags: tags,
      finishedAt: _finishedAt,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
      reviews: widget.initial?.reviews ?? const [],
    );
    Navigator.of(context).pop(result);
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'media_notFinished'.tr;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    const gap = SizedBox(height: 14);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 类型 + 创作者
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'media_kind'.tr,
                      style: DsTypography.label.copyWith(color: theme.textSub),
                    ),
                    const SizedBox(height: 6),
                    DSSelect<MediaKind>(
                      value: _kind,
                      items: [
                        DSSelectItem(
                          label: 'media_reading'.tr,
                          value: MediaKind.reading,
                        ),
                        DSSelectItem(
                          label: 'media_watching'.tr,
                          value: MediaKind.watching,
                        ),
                      ],
                      onChanged: (value) => setState(() => _kind = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kind == MediaKind.reading
                          ? 'media_author'.tr
                          : 'media_director'.tr,
                      style: DsTypography.label.copyWith(color: theme.textSub),
                    ),
                    const SizedBox(height: 6),
                    DSInput(
                      controller: _authorController,
                      hint: _kind == MediaKind.reading
                          ? 'media_author'.tr
                          : 'media_director'.tr,
                    ),
                  ],
                ),
              ),
            ],
          ),
          gap,
          Text(
            'media_title'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          DSInput(controller: _titleController, hint: 'media_title'.tr),
          gap,
          Text(
            'media_rating'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          DSRating(value: _rating, onChanged: (v) => setState(() => _rating = v)),
          gap,
          Text(
            'media_coverStyle'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final style in CoverStyle.values)
                _buildCoverOption(theme, style),
            ],
          ),
          gap,
          Text(
            'media_finishedAt'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DSButton(
                  label: _dateLabel(_finishedAt),
                  icon: DsIconKind.calendar,
                  variant: DSButtonVariant.outline,
                  onPressed: _pickFinishedDate,
                ),
              ),
              if (_finishedAt != null) ...[
                const SizedBox(width: 8),
                DSIconButton(
                  icon: DsIconKind.close,
                  size: 38,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  onPressed: () => setState(() => _finishedAt = null),
                ),
              ],
            ],
          ),
          gap,
          Text(
            'media_tags'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          DSInput(controller: _tagsController, hint: 'media_tagsHint'.tr),
          gap,
          Text(
            'media_overview'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          DSInput(
            controller: _overviewController,
            maxLines: 4,
            hint: 'media_overview'.tr,
          ),
          const SizedBox(height: 20),
          DSButton(
            label: 'media_save'.tr,
            icon: DsIconKind.check,
            variant: DSButtonVariant.primary,
            onPressed: _submit,
          ),
          if (widget.showDelete) ...[
            const SizedBox(height: 10),
            DSButton(
              label: 'media_delete'.tr,
              icon: DsIconKind.trash,
              variant: DSButtonVariant.destructive,
              onPressed: () => Navigator.of(context).pop('delete'),
            ),
          ],
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
    );
  }

  Widget _buildCoverOption(AppThemeData theme, CoverStyle style) {
    final selected = style == _cover;
    return Pressable(
      onPressed: () => setState(() => _cover = style),
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 56,
            decoration: dsSketchDecoration(
              theme: theme,
              radius: DsRadii.sm,
              stroke: selected ? theme.primary : null,
              strokeWidth: selected ? 2.4 : 1.2,
              seed: style.index + 1,
            ),
            child: ClipRRect(
              borderRadius: DsRadii.sm,
              child: AspectRatio(
                aspectRatio: 1 / 1.35,
                child: MediaCover(style: style),
              ),
            ),
          ),
        );
      },
    );
  }
}
