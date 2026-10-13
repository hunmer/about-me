import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';

import '../models/media_item.dart';

/// 新建/编辑点评表单（底部 sheet，多条点评各带时间戳）
///
/// 返回构建好的 [MediaReview]（未落库，由调用方保存）。
class MediaReviewForm extends StatefulWidget {
  const MediaReviewForm({super.key, this.initial});

  /// 编辑模式的初始点评；null = 新建
  final MediaReview? initial;

  @override
  State<MediaReviewForm> createState() => _MediaReviewFormState();
}

class _MediaReviewFormState extends State<MediaReviewForm> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.initial?.text ?? '',
  );
  late final TextEditingController _authorController = TextEditingController(
    text: widget.initial?.author ?? '',
  );
  double _rating = 0;
  late DateTime _timestamp;

  /// 点评人头像（相对路径或 URL；null = 首字母圆）
  String? _avatar;

  @override
  void initState() {
    super.initState();
    _rating = widget.initial?.rating ?? 0;
    _timestamp = widget.initial?.timestamp ?? DateTime.now();
    _avatar = widget.initial?.avatar;
  }

  @override
  void dispose() {
    _textController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _pickTimestamp() async {
    final picked = await showDSDatePickerDialog(
      context: context,
      initial: _timestamp,
      cancelText: 'media_cancel'.tr,
      confirmText: 'media_confirm'.tr,
    );
    if (picked != null) {
      // 日期可改，保留原时刻的分秒
      setState(() => _timestamp = picked.add(
            Duration(hours: _timestamp.hour, minutes: _timestamp.minute),
          ));
    }
  }

  /// 上传点评人头像（圆形裁剪）
  Future<void> _pickAvatar() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const ImagePickerDialog(
        saveDirectory: 'media_log/avatars',
        enableCrop: true,
        cropAspectRatio: 1.0,
        enableCompression: true,
        compressionQuality: 80,
      ),
    );
    if (result != null && result['url'] != null) {
      setState(() => _avatar = result['url'] as String);
    }
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      Toast.info('media_reviewRequired'.tr);
      return;
    }
    final author = _authorController.text.trim();
    Navigator.of(context).pop(
      MediaReview(
        id: widget.initial?.id ?? '',
        text: text,
        timestamp: _timestamp,
        rating: _rating > 0 ? _rating : null,
        author: author.isEmpty ? null : author,
        avatar: _avatar,
      ),
    );
  }

  String _timestampLabel() {
    return '${_timestamp.year}-${_timestamp.month.toString().padLeft(2, '0')}-${_timestamp.day.toString().padLeft(2, '0')} '
        '${_timestamp.hour.toString().padLeft(2, '0')}:${_timestamp.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 点评人：头像 + 昵称
          Row(
            children: [
              _buildAvatarPicker(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'media_reviewAuthor'.tr,
                      style: DsTypography.label.copyWith(color: theme.textSub),
                    ),
                    const SizedBox(height: 6),
                    DSInput(
                      controller: _authorController,
                      hint: 'media_me'.tr,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'media_reviewTimestamp'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DSButton(
                  label: _timestampLabel(),
                  icon: DsIconKind.clock,
                  variant: DSButtonVariant.outline,
                  onPressed: _pickTimestamp,
                ),
              ),
              const SizedBox(width: 8),
              DSIconButton(
                icon: DsIconKind.calendar,
                size: 38,
                color: theme.surface,
                iconColor: theme.text,
                tooltip: 'media_now'.tr,
                onPressed: () => setState(() => _timestamp = DateTime.now()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'media_rating'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          DSRating(value: _rating, onChanged: (v) => setState(() => _rating = v)),
          const SizedBox(height: 14),
          Text(
            'media_reviewText'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          DSInput(
            controller: _textController,
            maxLines: 5,
            hint: 'media_reviewText'.tr,
          ),
          const SizedBox(height: 20),
          DSButton(
            label: 'media_save'.tr,
            icon: DsIconKind.check,
            variant: DSButtonVariant.primary,
            onPressed: _submit,
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
    );
  }

  /// 头像选择：圆形图片 / 用户图标占位，长按可清除
  Widget _buildAvatarPicker(AppThemeData theme) {
    Widget content;
    if (_avatar != null && _avatar!.isNotEmpty) {
      content = AdaptiveImage(
        imagePath: _avatar,
        fit: BoxFit.cover,
        borderRadius: 0,
        shape: BoxShape.circle,
      );
    } else {
      content = DsIcon(DsIconKind.user, size: 22, color: theme.textSub);
    }

    return Pressable(
      onPressed: _pickAvatar,
      onLongPress: () {
        if (_avatar != null) setState(() => _avatar = null);
      },
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 52,
            height: 52,
            decoration: dsSketchDecoration(
              theme: theme,
              radius: BorderRadius.circular(52),
              stroke: _avatar != null ? theme.primary : null,
              strokeWidth: 2,
              seed: 21,
            ),
            child: ClipOval(child: content),
          ),
        );
      },
    );
  }
}
