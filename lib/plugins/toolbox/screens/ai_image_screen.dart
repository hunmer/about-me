import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/toolbox/controllers/ai_image_controller.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/screens/ai_image_history_screen.dart';
import 'package:aboutme/plugins/toolbox/screens/ai_image_preset_screen.dart';
import 'package:aboutme/plugins/toolbox/services/ai_image_service.dart';
import 'package:aboutme/plugins/toolbox/widgets/toolbox_config_sheet.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/gallery_viewer.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// AI 图片生成小工具独立界面
///
/// 文生图（prompt）+ 图生图（prompt + 参考图，可多选融合），
/// 异步任务轮询，产物保存到 app_data/toolbox/ai_image/。
class AiImageScreen extends StatefulWidget {
  /// 选择模式（由图片选择器的 AI 入口使用）：结果图点击即作为
  /// 选择结果返回——单选 pop 单条 {'url','thumbUrl','bytes'}，
  /// 多选勾选后确认 pop 其列表；toolbox 独立入口保持查看大图行为
  final bool pickMode;

  /// 选择模式下的多选（跟随图片选择器的 multiple）
  final bool multiple;

  const AiImageScreen({
    super.key,
    this.pickMode = false,
    this.multiple = false,
  });

  @override
  State<AiImageScreen> createState() => _AiImageScreenState();
}

class _AiImageScreenState extends State<AiImageScreen> {
  final _controller = AiImageController();
  final _promptController = TextEditingController();

  /// pickMode 多选：已勾选的结果下标
  final List<int> _picked = [];

  /// 上一批结果的引用，用于检测批次替换（新批次时旧勾选下标失效）
  List<GeneratedImage>? _lastResults;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (!identical(_lastResults, _controller.results)) {
      _lastResults = _controller.results;
      _picked.clear();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickRefImages() async {
    final picked = await ImagePickerDialog.show<List<Map<String, dynamic>>>(
      context,
      multiple: true,
    );
    if (picked == null) return;
    for (final item in picked) {
      final url = item['url']?.toString() ?? '';
      if (url.isNotEmpty) await _controller.addRefImage(url);
    }
  }

  void _openSettings() {
    final service = AiImageService.instance;
    ToolboxConfigSheet.show(
      context,
      title: 'toolbox_aiImage_settings'.tr,
      fields: service.configFields,
      config: service.config,
      onSave: service.saveConfig,
    );
  }

  /// 打开预设库；选中预设返回时整体回填表单
  Future<void> _openPresets() async {
    final preset = await NavigationHelper.push<AiImagePreset>(
      context,
      const AiImagePresetScreen(),
    );
    if (preset == null || !mounted) return;
    _promptController.text = preset.prompt;
    _controller.applyPreset(preset);
  }

  /// 打开生成图库；选中"重新生成"的记录时回填表单
  Future<void> _openHistory() async {
    final entry = await NavigationHelper.push<Map<String, dynamic>>(
      context,
      const AiImageHistoryScreen(),
    );
    if (entry == null || !mounted) return;
    final prompt = entry['prompt']?.toString() ?? '';
    if (prompt.isNotEmpty) {
      _promptController.text = prompt;
      _controller.setPrompt(prompt);
    }
    final model = entry['model']?.toString();
    if (model != null &&
        model.isNotEmpty &&
        AiImageService.models.contains(model)) {
      _controller.setModel(model);
    }
    final ratio = entry['aspectRatio']?.toString();
    if (ratio != null &&
        ratio.isNotEmpty &&
        AiImageService.aspectRatios.contains(ratio)) {
      _controller.setAspectRatio(ratio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final c = _controller;

    return SuperCupertinoNavigationWrapper(
      title: Text('toolbox_aiImage_name'.tr),
      largeTitle: 'toolbox_aiImage_name'.tr,
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DSIconButton(
                    icon: DsIconKind.sparkle,
                    size: 36,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    tooltip: 'toolbox_aiImage_presets'.tr,
                    onPressed: _openPresets,
                  ),
                  DSIconButton(
                    icon: DsIconKind.layers,
                    size: 36,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    tooltip: 'toolbox_aiImage_history'.tr,
                    onPressed: _openHistory,
                  ),
                  DSIconButton(
                    icon: DsIconKind.gear,
                    size: 36,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    tooltip: 'toolbox_settings'.tr,
                    onPressed: _openSettings,
                  ),
                ],
              );
            },
          ),
        ),
      ],
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.lg,
            vertical: theme.spacing.md,
          ),
          children: [
            // 参考图（图生图）
            _buildRefImages(theme),
            SizedBox(height: theme.spacing.md),
            // 提示词
            DSInput(
              controller: _promptController,
              label: c.isEdit
                  ? 'toolbox_aiImage_editPrompt'.tr
                  : 'toolbox_aiImage_prompt'.tr,
              hint: c.isEdit
                  ? 'toolbox_aiImage_editHint'.tr
                  : 'toolbox_aiImage_promptHint'.tr,
              minLines: 3,
              maxLines: 5,
              onChanged: c.setPrompt,
            ),
            SizedBox(height: theme.spacing.md),
            // 参数区
            _buildParams(theme),
            SizedBox(height: theme.spacing.lg),
            // 生成按钮 / 进度
            DSButton(
              label: c.isEdit
                  ? 'toolbox_aiImage_generateEdit'.tr
                  : 'toolbox_aiImage_generate'.tr,
              loading: c.generating,
              onPressed: c.generating ? null : c.generate,
            ),
            if (c.generating && c.status != null)
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.sm),
                child: Text(
                  c.status!,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                  textAlign: TextAlign.center,
                ),
              ),
            if (c.error != null)
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.sm),
                child: Text(
                  c.error!,
                  style: DsTypography.body.copyWith(color: theme.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: theme.spacing.md),
            // 结果区
            if (c.results.isNotEmpty) ...[
              Text(
                c.lastMessage,
                style: DsTypography.body.copyWith(color: theme.textSub),
              ),
              SizedBox(height: theme.spacing.sm),
              for (var i = 0; i < c.results.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => _onTapResult(i),
                    // 与查看器当前页大图同 tag，形成飞行转场
                    child: Hero(
                      tag: _heroTag(c.results[i]),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _resultImage(c.results[i]),
                          ),
                          if (widget.pickMode && widget.multiple)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: _buildPickBadge(theme, i),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              Text(
                '${'toolbox_aiImage_savedTo'.tr} SDK',
                style: DsTypography.caption.copyWith(color: theme.textSub),
                textAlign: TextAlign.center,
              ),
              if (widget.pickMode && widget.multiple) ...[
                SizedBox(height: theme.spacing.md),
                DSButton(
                  label: 'app_confirm'.tr,
                  onPressed: _picked.isEmpty ? null : _confirmPick,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 点击结果图：GalleryViewer 全屏查看本批图片
  /// Hero/查看器共用的图片标识（与 GalleryPhoto.url 保持一致）
  static String _heroTag(GeneratedImage img) =>
      img.relativePath.isNotEmpty ? img.relativePath : img.absolutePath;

  /// pickMode 结果图的回传 payload（生成图已存 SDK，url 为资源引用）
  Map<String, dynamic> _resultPayload(int index) {
    final img = _controller.results[index];
    return {
      'url': img.relativePath.isNotEmpty ? img.relativePath : img.absolutePath,
      'thumbUrl': null,
      'bytes': img.bytes,
    };
  }

  /// 结果图点击：非选择模式查看大图；单选直接返回；多选勾选待确认
  void _onTapResult(int index) {
    if (!widget.pickMode) {
      _openResultViewer(index);
    } else if (!widget.multiple) {
      Navigator.of(context).pop(_resultPayload(index));
    } else {
      setState(() {
        _picked.contains(index) ? _picked.remove(index) : _picked.add(index);
      });
    }
  }

  /// 多选确认：回传勾选的结果列表
  void _confirmPick() {
    if (_picked.isEmpty) return;
    Navigator.of(context).pop([for (final i in _picked) _resultPayload(i)]);
  }

  /// 多选勾选角标（样式与图片选择器网格一致）
  Widget _buildPickBadge(AppThemeData theme, int index) {
    final isSelected = _picked.contains(index);
    final selectedIndex = _picked.indexOf(index) + 1;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? theme.primary
            : Colors.black.withValues(alpha: 0.25),
        border: isSelected ? null : Border.all(color: Colors.white70),
      ),
      child: Center(
        // 未选中时角标为空圈，不显示序号（避免 indexOf(-1)+1 显示 0）
        child: isSelected
            ? Text(
                '$selectedIndex',
                style: DsTypography.caption.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  /// 点击结果图：GalleryViewer 全屏查看本批图片（Hero 飞行转场）
  void _openResultViewer(int index) {
    NavigationHelper.push(
      context,
      GalleryViewer(
        title: 'toolbox_aiImage_name'.tr,
        photos: [
          for (final img in _controller.results)
            GalleryPhoto(url: _heroTag(img), caption: img.relativePath),
        ],
        initialIndex: index,
      ),
    );
  }

  Widget _resultImage(img) {
    if (img.bytes != null) {
      return Image.memory(img.bytes!, fit: BoxFit.fitWidth);
    }
    // 结果为 SDK 资源引用（后台生成无字节时），统一走资源感知的 provider
    final reference = img.relativePath.isNotEmpty
        ? img.relativePath
        : img.absolutePath;
    if (reference.isNotEmpty) {
      return Image(
        image: ImageUtils.createImageProvider(reference),
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => _resultPlaceholder(),
      );
    }
    return _resultPlaceholder();
  }

  Widget _resultPlaceholder() {
    return const SizedBox(
      height: 120,
      child: Center(child: Icon(Icons.broken_image)),
    );
  }

  /// 参考图横排：已选图 + 添加按钮（图片选择器，支持网络搜图）
  Widget _buildRefImages(AppThemeData theme) {
    final c = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${'toolbox_aiImage_refImages'.tr}（${'toolbox_aiImage_refHint'.tr}）',
          style: DsTypography.body.copyWith(color: theme.text),
        ),
        SizedBox(height: theme.spacing.sm),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < c.refImages.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildRefThumb(theme, i),
                ),
              _buildAddButton(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRefThumb(AppThemeData theme, int index) {
    final path = _controller.refImages[index];
    final isNetwork = path.startsWith(RegExp(r'https?://'));
    final isFile = !isNetwork && File(path).existsSync();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 84,
            height: 84,
            child: isNetwork
                ? Image.network(
                    path,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.link),
                  )
                : isFile
                ? Image.file(File(path), fit: BoxFit.cover)
                : const Icon(Icons.image_not_supported_outlined),
          ),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: GestureDetector(
            onTap: () => _controller.removeRefImage(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: theme.danger,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(AppThemeData theme) {
    return GestureDetector(
      onTap: _pickRefImages,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.stroke),
          color: theme.surfaceAlt,
        ),
        child: Icon(Icons.add_photo_alternate_outlined, color: theme.textSub),
      ),
    );
  }

  /// 参数：模型 / 宽高比 / 数量（空值跟随配置默认）
  Widget _buildParams(AppThemeData theme) {
    final c = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paramLabel(theme, 'toolbox_aiImage_model'),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: DSChip(
                  label: 'toolbox_default'.tr,
                  selected: c.model.isEmpty,
                  onSelected: (_) => c.setModel(''),
                ),
              ),
              for (final m in AiImageService.models)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: DSChip(
                    label: m,
                    selected: c.model == m,
                    onSelected: (_) => c.setModel(m),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        _paramLabel(theme, 'toolbox_aiImage_aspectRatio'),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: DSChip(
                  label: 'toolbox_default'.tr,
                  selected: c.aspectRatio.isEmpty,
                  onSelected: (_) => c.setAspectRatio(''),
                ),
              ),
              for (final r in AiImageService.aspectRatios)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: DSChip(
                    label: r,
                    selected: c.aspectRatio == r,
                    onSelected: (_) => c.setAspectRatio(r),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        _paramLabel(theme, 'toolbox_aiImage_count'),
        Row(
          children: [
            for (var i = 1; i <= 4; i++) ...[
              DSChip(
                label: '$i',
                selected: c.n == i,
                onSelected: (_) => c.setN(i),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }

  Widget _paramLabel(AppThemeData theme, String key) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(key.tr, style: DsTypography.body.copyWith(color: theme.text)),
  );
}
