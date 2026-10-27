import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/ai_image_service.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// AI 绘画预设库：内置预设 + 用户自建预设，两列瀑布流展示
///
/// 点击卡片 = 应用该预设并返回生成页回填表单；
/// 用户预设支持编辑/删除，右上角 + 新建（编辑页与生成表单共用
/// [AiImagePreset] 结构，可设置参考图）。
class AiImagePresetScreen extends StatefulWidget {
  const AiImagePresetScreen({super.key});

  @override
  State<AiImagePresetScreen> createState() => _AiImagePresetScreenState();
}

class _AiImagePresetScreenState extends State<AiImagePresetScreen> {
  List<AiImagePreset> _userPresets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final presets = await AiImageService.instance.getPresets();
    if (!mounted) return;
    setState(() {
      _userPresets = presets;
      _loading = false;
    });
  }

  Future<void> _openEdit([AiImagePreset? preset]) async {
    final result = await NavigationHelper.push<AiImagePreset>(
      context,
      AiImagePresetEditScreen(initial: preset),
    );
    if (result == null) return;
    final list = List<AiImagePreset>.from(_userPresets);
    final i = list.indexWhere((e) => e.id == result.id);
    if (i >= 0) {
      list[i] = result;
    } else {
      list.insert(0, result);
    }
    await AiImageService.instance.savePresets(list);
    await _load();
  }

  Future<void> _delete(AiImagePreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('toolbox_aiImage_presetDelete'.tr),
        content: Text(
          '${'toolbox_aiImage_presetDeleteConfirm'.tr}\n「${preset.name}」',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('app_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('app_confirm'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final list = _userPresets.where((e) => e.id != preset.id).toList();
    await AiImageService.instance.savePresets(list);
    if (!mounted) return;
    setState(() => _userPresets = list);
    Toast.success('toolbox_aiImage_presetDeleted'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 用户预设在前（新→旧），内置预设随后
    final items = [..._userPresets, ...AiImageService.builtinPresets];

    return SuperCupertinoNavigationWrapper(
      title: Text('toolbox_aiImage_presets'.tr),
      largeTitle: 'toolbox_aiImage_presets'.tr,
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.plus,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'toolbox_aiImage_presetNew'.tr,
                onPressed: () => _openEdit(),
              );
            },
          ),
        ),
      ],
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : MasonryGridView.count(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.lg,
                  vertical: theme.spacing.sm,
                ),
                crossAxisCount: 2,
                mainAxisSpacing: theme.spacing.md,
                crossAxisSpacing: theme.spacing.md,
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _buildCard(theme, items[index]),
              ),
      ),
    );
  }

  Widget _buildCard(AppThemeData theme, AiImagePreset preset) {
    return DSCard(
      onTap: () => Navigator.of(context).pop<AiImagePreset>(preset),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageArea(theme, preset),
          SizedBox(height: theme.spacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  preset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.body.copyWith(
                    color: theme.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (preset.builtin)
                DSBadge(label: 'toolbox_aiImage_builtin'.tr)
              else ...[
                _cardAction(
                  theme,
                  icon: Icons.edit_outlined,
                  onTap: () => _openEdit(preset),
                ),
                _cardAction(
                  theme,
                  icon: Icons.delete_outline,
                  danger: true,
                  onTap: () => _delete(preset),
                ),
              ],
            ],
          ),
          SizedBox(height: 2),
          if (preset.prompt.isNotEmpty)
            Text(
              preset.prompt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          SizedBox(height: theme.spacing.xs),
          Text(
            [
              if (preset.model.isNotEmpty) preset.model,
              if (preset.aspectRatio.isNotEmpty) preset.aspectRatio,
              '${preset.n}p',
              if (preset.refImages.isNotEmpty) '${preset.refImages.length}ref',
            ].join(' · '),
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
  }

  Widget _cardAction(
    AppThemeData theme, {
    required IconData icon,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(icon, size: 18, color: danger ? theme.danger : theme.textSub),
      ),
    );
  }

  /// 图片区：无参考图显示 emoji 占位，有图按数量错落排布（瀑布流高度差来源）
  Widget _buildImageArea(AppThemeData theme, AiImagePreset preset) {
    final refs = preset.refImages;
    if (refs.isEmpty) {
      return Container(
        height: 96,
        decoration: BoxDecoration(
          color: theme.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(preset.emoji, style: const TextStyle(fontSize: 34)),
        ),
      );
    }
    if (refs.length == 1) {
      return _refImage(refs.first, height: 128);
    }
    // 2-4 张两行两列（超出 4 张在末位显示 +N 角标，不足补空位）
    final shown = refs.take(4).toList();
    final extra = refs.length - shown.length;
    final row2Count = shown.length - 2;
    final Widget grid = Column(
      children: [
        Row(
          children: [
            Expanded(child: _refImage(shown[0], height: 80)),
            const SizedBox(width: 4),
            Expanded(child: _refImage(shown[1], height: 80)),
          ],
        ),
        if (row2Count > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _refImage(shown[2], height: 80)),
              const SizedBox(width: 4),
              Expanded(
                child: row2Count > 1
                    ? _stackCount(
                        _refImage(shown[3], height: 80),
                        extra > 0 ? extra : null,
                      )
                    : const SizedBox(height: 80),
              ),
            ],
          ),
        ],
      ],
    );
    return grid;
  }

  Widget _refImage(String path, {required double height}) {
    final isNetwork = path.startsWith(RegExp(r'https?://'));
    final isFile = !isNetwork && File(path).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: isNetwork
            ? Image.network(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _imgPlaceholder(),
              )
            : isFile
            ? Image.file(File(path), fit: BoxFit.cover)
            : _imgPlaceholder(),
      ),
    );
  }

  Widget _stackCount(Widget child, int? extra) {
    if (extra == null || extra <= 0) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '+$extra',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _imgPlaceholder() => const ColoredBox(
    color: Color(0x11000000),
    child: Center(child: Icon(Icons.image_not_supported_outlined, size: 20)),
  );
}
