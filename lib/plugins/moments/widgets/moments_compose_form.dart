import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import 'package:aboutme/core/data/sdk_media_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/moments/models/moment_post.dart';
import 'package:aboutme/plugins/openai/moments/services/image_gen_service.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/utils/file_picker_helper.dart';

import 'moments_shared.dart';

/// 发布投稿面板内容（由 SmoothBottomSheet 提供标题/把手/关闭）
class MomentsComposeForm extends StatefulWidget {
  const MomentsComposeForm({super.key});

  @override
  State<MomentsComposeForm> createState() =>
      _MomentsComposeFormState();
}

class _MomentsComposeFormState extends State<MomentsComposeForm> {
  final _textController = TextEditingController();
  final _imagePromptController = TextEditingController();
  final List<File> _images = [];
  String _tag = MomentTags.defaultKey;
  bool _aiImage = false;
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    _imagePromptController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remain = MomentsService.maxImagesPerPost - _images.length;
    if (remain <= 0) {
      ToastService.instance.showToast(
        'moments_imageLimit'.trParams({
          'n': '${MomentsService.maxImagesPerPost}',
        }),
      );
      return;
    }
    final files = await FilePickerHelper.pickImages(multiple: true);
    if (files.isEmpty) return;
    setState(() => _images.addAll(files.take(remain)));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final text = _textController.text.trim();
    if (text.isEmpty && _images.isEmpty) {
      ToastService.instance.showToast('moments_composeEmptyHint'.tr);
      return;
    }
    setState(() => _submitting = true);
    try {
      // 挑选的图片上传为 SDK 资源，存储资源引用
      final relPaths = <String>[];
      for (final file in _images) {
        var name = p.basename(file.path);
        if (!name.contains('.')) name = '$name.png';
        final asset = await SdkMediaService.uploadBytes(
          await file.readAsBytes(),
          name,
        );
        relPaths.add(asset.reference);
      }
      // AI 配图（可选）：留空用文案生图，失败降级为无图发布
      if (_aiImage) {
        try {
          ToastService.instance.showToast('moments_aiImageGenerating'.tr);
          final prompt =
              _imagePromptController.text.trim().isEmpty
                  ? text
                  : _imagePromptController.text.trim();
          relPaths.addAll(
            await ImageGenService.instance.generate(prompt: prompt),
          );
        } catch (e) {
          ToastService.instance.showToast('moments_aiImageFailed'.tr);
          debugPrint('[Moments] 用户投稿 AI 配图失败: $e');
        }
      }
      await MomentsService.instance.addPost(
        agentId: MomentPost.userAuthorId,
        text: text,
        images: relPaths,
        source: 'user',
        tag: _tag,
      );
      if (mounted) {
        Navigator.pop(context);
        ToastService.instance.showToast('moments_publishDone'.tr);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ToastService.instance.showToast(
          'moments_publishFailed'.trParams({'error': '$e'}),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DSInput(
            controller: _textController,
            hint: 'moments_composeHint'.tr,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Text(
            'moments_composeTagLabel'.tr,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in MomentTags.all)
                TagPill(
                  tag: tag,
                  selected: _tag == tag.key,
                  onTap: () => setState(() => _tag = tag.key),
                ),
            ],
          ),
          const SizedBox(height: 10),
          InterestPill(
            label: 'moments_aiImage'.tr,
            leading: DsIcon(DsIconKind.palette, size: 12),
            selected: _aiImage,
            onTap: () => setState(() => _aiImage = !_aiImage),
          ),
          if (_aiImage) ...[
            const SizedBox(height: 8),
            DSInput(
              controller: _imagePromptController,
              hint: 'moments_aiImageHint'.tr,
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Container(
                    width: 72,
                    height: 72,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.surfaceAlt,
                      radius: theme.radii.md,
                      seed: i + 40,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: theme.radii.sm,
                          child: Image.file(_images[i], fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: dsSketchDecoration(
                                theme: theme,
                                fillColor: theme.ink.withValues(alpha: 0.55),
                                circle: true,
                                seed: 6,
                              ),
                              child: DsIcon(
                                DsIconKind.close,
                                size: 12,
                                color: theme.paper,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.surfaceAlt,
                      radius: theme.radii.md,
                      seed: 9,
                    ),
                    child: Center(
                      child: DsIcon(
                        DsIconKind.image,
                        size: 26,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: DSButton(
              label: 'moments_publish'.tr,
              expand: true,
              onPressed: _submitting ? null : () => unawaited(_submit()),
            ),
          ),
        ],
      ),
    );
  }
}
