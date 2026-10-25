import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/screens/jelly_home/live2d_zip_import.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 本地模型库：管理 zip 导入的模型，点击选中返回模型定义，
/// 右上角可继续导入新压缩包
class Live2DImportedModelsScreen extends StatefulWidget {
  const Live2DImportedModelsScreen({super.key});

  @override
  State<Live2DImportedModelsScreen> createState() =>
      _Live2DImportedModelsScreenState();
}

class _Live2DImportedModelsScreenState
    extends State<Live2DImportedModelsScreen> {
  final plugin = Live2DPlugin.instance;
  bool _importing = false;

  Future<void> _importZip() async {
    if (_importing) return;
    setState(() => _importing = true);
    List<Live2DModelDefinition>? models;
    try {
      models = await Live2DZipImport.pickAndImport();
    } catch (error) {
      if (mounted) {
        _showError(
          'live2d_importZipFailed'.trParams({'error': '$error'}),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _importing = false);
    }
    if (!mounted || models == null) return;
    if (models.isEmpty) {
      _showError('live2d_importZipNoModel'.tr);
      return;
    }
    final model = models.length == 1
        ? models.first
        : await SmoothBottomSheet.show<Live2DModelDefinition>(
            context: context,
            builder: (_) => ListView(
              padding: const EdgeInsets.all(16),
              children: models!
                  .map(
                    (model) => ListTile(
                      title: Text(model.label),
                      subtitle: Text(model.modelFile),
                      onTap: () => Navigator.pop(context, model),
                    ),
                  )
                  .toList(),
            ),
          );
    if (model == null) return;
    await plugin.addImportedModel(model);
    if (!mounted) return;
    // 导入即选用：直接返回给存档表单
    Navigator.of(context).pop(model);
  }

  /// 上传/更换缩略图（1:1 裁剪，持久化到导入记录）
  Future<void> _uploadThumb(Live2DModelDefinition model) async {
    final result = await ImagePickerDialog.show<Map<String, dynamic>>(
      context,
      initialUrl: model.thumbPath,
      enableCrop: true,
      cropAspectRatio: 1,
    );
    final url = result?['url'] as String?;
    if (url == null || url.isEmpty) return;
    await plugin.setImportedModelThumb(model, url);
    if (mounted) setState(() {});
  }

  Future<void> _delete(Live2DModelDefinition model) async {    final usage = plugin.archivesUsingModel(model);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('live2d_deleteImportedTitle'.tr),
        content: Text(
          usage > 0
              ? 'live2d_deleteImportedInUseConfirm'.trParams({
                  'name': model.label,
                  'count': usage.toString(),
                })
              : 'live2d_deleteImportedConfirm'.trParams({'name': model.label}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('core_cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('core_delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await plugin.removeImportedModel(model);
    if (mounted) setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 列表缩略图：点击上传/更换（内层手势优先于整行点击），右下角相机角标
  Widget _buildThumb(AppThemeData theme, Live2DModelDefinition model) {
    return GestureDetector(
      onTap: () => _uploadThumb(model),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AdaptiveImage(
            imagePath: model.thumbPath,
            width: 48,
            height: 48,
            borderRadius: 10,
            errorImage: _thumbPlaceholder(theme),
            defaultImage: _thumbPlaceholder(theme),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primary,
                border: Border.all(color: theme.background, width: 1.5),
              ),
              child: Icon(
                Icons.photo_camera,
                size: 10,
                color: theme.background,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder(AppThemeData theme) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: theme.primary.mixWhite(0.92),
      borderRadius: BorderRadius.circular(10),
    ),
    alignment: Alignment.center,
    child: DsIcon(DsIconKind.archive, size: 22, color: theme.primary),
  );

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.fromPalette(DsThemeColorController().palette);
    final models = plugin.importedModels;
    return AppTheme(
      data: theme,
      child: ColoredBox(
        color: theme.background,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: Column(
              children: [
                JellyBox(
                  radius: theme.radii.pill,
                  padding: EdgeInsets.all(theme.spacing.sm),
                  child: Row(
                    children: [
                      DSIconButton(
                        icon: DsIconKind.chevronLeft,
                        tooltip: 'core_back'.tr,
                        size: 36,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      Expanded(
                        child: Text(
                          'live2d_importedModelsTitle'.tr,
                          textAlign: TextAlign.center,
                          style: DsTypography.heading.copyWith(
                            color: theme.text,
                          ),
                        ),
                      ),
                      DSIconButton(
                        icon: DsIconKind.plus,
                        tooltip: 'live2d_importZipModel'.tr,
                        size: 36,
                        onPressed: _importing ? null : _importZip,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: theme.spacing.md),
                if (models.isEmpty)
                  Expanded(
                    child: Center(
                      child: DSEmptyState(
                        emoji: '📦',
                        title: 'live2d_importedModelsEmpty'.tr,
                        actionLabel: 'live2d_importZipModel'.tr,
                        onAction: _importing ? null : _importZip,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: models.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: theme.spacing.sm),
                      itemBuilder: (context, index) {
                        final model = models[index];
                        return DSListItem(
                          title: model.label,
                          subtitle: model.modelFile,
                          leading: _buildThumb(theme, model),
                          trailing: _importing
                              ? null
                              : DSIconButton(
                                  icon: DsIconKind.trash,
                                  tooltip: 'core_delete'.tr,
                                  size: 32,
                                  onPressed: () => _delete(model),
                                ),
                          onTap: () => Navigator.of(context).pop(model),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
