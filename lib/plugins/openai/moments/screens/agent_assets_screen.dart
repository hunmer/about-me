import 'dart:io';

import 'package:flutter/material.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/moments/models/agent_asset.dart';
import 'package:aboutme/plugins/openai/moments/services/agent_assets_service.dart';
import 'package:aboutme/plugins/openai/moments/services/image_gen_service.dart';
import 'package:aboutme/plugins/openai/moments/widgets/photo_viewer_screen.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

import 'package:get/get.dart';

/// Agent 资产图管理：占位生成 / 上传命名 / 图生图
///
/// 手绘风（design.md §9/§11）：便签网格 + SmoothBottomSheet + showDSDialog；
/// [embedded] 为 true 时无页面外壳，供编辑页 Tab 内嵌。
class AgentAssetsScreen extends StatefulWidget {
  final String agentId;
  final String agentName;

  /// 嵌入模式：不包 Scaffold/AppBar，悬浮添加钮叠在网格上，供 Tab 内嵌使用
  final bool embedded;

  const AgentAssetsScreen({
    super.key,
    required this.agentId,
    required this.agentName,
    this.embedded = false,
  });

  @override
  State<AgentAssetsScreen> createState() => _AgentAssetsScreenState();
}

class _AgentAssetsScreenState extends State<AgentAssetsScreen> {
  final _assetsService = AgentAssetsService.instance;
  List<AgentAsset> _assets = [];
  final Set<String> _generating = {}; // 正在生成的资产 id

  String get _archiveDir => '${AgentAssetsService.assetsDir}/${widget.agentId}';

  @override
  void initState() {
    super.initState();
    _assetsService.addListener(_onChanged);
    _assetsService.ensureDefaults(widget.agentId).then((assets) {
      if (mounted) setState(() => _assets = assets);
    });
  }

  @override
  void dispose() {
    _assetsService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final cached = _assetsService.cached(widget.agentId);
    if (mounted && cached != null) setState(() => _assets = List.of(cached));
  }

  /// agent 人设描述（生图时附加，保证形象贴合）
  Future<String> _personaSuffix() async {
    try {
      final agent = await AgentController().getAgent(widget.agentId);
      if (agent != null && agent.description.trim().isNotEmpty) {
        return 'openai_personaSuffix'.trParams({
          'name': agent.name,
          'desc': agent.description.trim(),
        });
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // 嵌入模式：网格 + 右下角悬浮添加钮，无页面外壳
    if (widget.embedded) {
      return Stack(
        children: [
          _buildGrid(),
          Positioned(
            right: 16,
            bottom: 16,
            child: DSThemeBridge(
              // DSFab 内部取 AppTheme，需包桥
              child: DSFab(onPressed: _showAddSheet),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'openai_agentAssetsTitle'.trParams({'name': widget.agentName}),
        ),
      ),
      floatingActionButton: DSThemeBridge(
        // DSFab 内部取 AppTheme，需包桥
        child: DSFab(onPressed: _showAddSheet),
      ),
      body: _buildGrid(),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        // 贴条顶部出血 12px，纵向间距需 ≥ 16（design.md §11.2）
        mainAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, index) => _buildAssetCard(_assets[index]),
    );
  }

  /// 资产便签卡（design.md §11）：确定性倾斜 + 顶部小贴条，悬浮拿起
  Widget _buildAssetCard(AgentAsset asset) {
    final theme = DSThemeBridge.resolve(context);
    final isGenerating = _generating.contains(asset.id);
    return HandDrawnStickyItem(
      tiltKey: asset.id,
      // 窄卡片（3 列）用小号贴条
      tapeWidth: 56,
      tapeHeight: 18,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isGenerating ? null : () => _showAssetSheet(asset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (asset.hasImage)
                    FutureBuilder<String>(
                      future: ImageUtils.getAbsolutePath(asset.path),
                      builder: (context, snapshot) {
                        if (snapshot.hasData &&
                            snapshot.data!.isNotEmpty &&
                            File(snapshot.data!).existsSync()) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(snapshot.data!),
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        return _placeholderBox(theme);
                      },
                    )
                  else
                    _placeholderBox(theme),
                  if (isGenerating)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: theme.barrier,
                        child: Center(
                          child: DSLoadingDots(color: DsColors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              asset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DsTypography.body.copyWith(color: theme.text),
            ),
            Text(
              isGenerating
                  ? 'openai_assetGenerating'.tr
                  : asset.hasImage
                  ? 'openai_assetTapToManage'.tr
                  : 'openai_assetNotGenerated'.tr,
              maxLines: 1,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      ),
    );
  }

  /// 未生成占位：手绘墨线框（无渐变无投影）
  Widget _placeholderBox(AppThemeData theme) {
    return Container(
      decoration: dsSketchDecoration(theme: theme, radius: theme.radii.lg),
      child: Center(
        child: DsIcon(DsIconKind.image, size: 32, color: theme.textSub),
      ),
    );
  }

  // ---------- 添加 ----------

  void _showAddSheet() {
    SmoothBottomSheet.showWithTitle(
      context: context,
      title: 'openai_assetGallery'.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SmoothSheetAction(
            icon: DsIconKind.upload,
            label: 'openai_uploadPhoto'.tr,
            onTap: () {
              Navigator.pop(context);
              _pickAndUpload();
            },
          ),
          SmoothSheetAction(
            icon: DsIconKind.sparkle,
            label: 'openai_createPlaceholder'.tr,
            onTap: () {
              Navigator.pop(context);
              _showCreatePlaceholderDialog();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final result = await ImagePickerDialog.show<Map<String, dynamic>>(
      context,
      saveDirectory: _archiveDir,
      enableCompression: true,
      compressionQuality: 88,
    );
    if (result == null || result['url'] == null) return;
    final name = await _promptText(
      title: 'openai_namePhoto'.tr,
      hint: 'openai_assetNameHint'.tr,
    );
    if (name == null || name.trim().isEmpty) return;
    await _assetsService.addAsset(
      agentId: widget.agentId,
      name: name.trim(),
      path: result['url'] as String,
    );
  }

  Future<void> _showCreatePlaceholderDialog() async {
    final name = await _promptText(
      title: 'openai_assetNameLabel'.tr,
      hint: 'openai_assetNameHint'.tr,
    );
    if (name == null || name.trim().isEmpty) return;
    final prompt = await _promptText(
      title: 'openai_promptLabel'.tr,
      hint: 'openai_promptHint'.tr,
    );
    if (prompt == null) return;
    await _assetsService.addAsset(
      agentId: widget.agentId,
      name: name.trim(),
      prompt: prompt.trim(),
    );
  }

  // ---------- 资产操作 ----------

  void _showAssetSheet(AgentAsset asset) {
    SmoothBottomSheet.showWithTitle(
      context: context,
      title: asset.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (asset.hasImage)
            SmoothSheetAction(
              icon: DsIconKind.photoLibrary,
              label: 'openai_viewFullImage'.tr,
              onTap: () {
                Navigator.pop(context);
                NavigationHelper.push(
                  context,
                  PhotoViewerScreen(imageRelativePaths: [asset.path!]),
                );
              },
            )
          else
            SmoothSheetAction(
              icon: DsIconKind.sparkle,
              label: 'openai_generateImage'.tr,
              onTap: () {
                Navigator.pop(context);
                _showGenerateDialog(asset);
              },
            ),
          if (asset.hasImage) ...[
            SmoothSheetAction(
              icon: DsIconKind.flip,
              label: 'openai_img2img'.tr,
              onTap: () {
                Navigator.pop(context);
                _showImg2ImgDialog(asset);
              },
            ),
            SmoothSheetAction(
              icon: DsIconKind.refresh,
              label: 'openai_regenerate'.tr,
              onTap: () {
                Navigator.pop(context);
                _showGenerateDialog(asset, overwrite: true);
              },
            ),
          ],
          SmoothSheetAction(
            icon: DsIconKind.edit,
            label: asset.hasImage
                ? 'openai_rename'.tr
                : 'openai_editNameAndPrompt'.tr,
            onTap: () {
              Navigator.pop(context);
              _showEditAssetDialog(asset);
            },
          ),
          SmoothSheetAction(
            icon: DsIconKind.trash,
            label: 'app_delete'.tr,
            destructive: true,
            onTap: () {
              Navigator.pop(context);
              _assetsService.deleteAsset(
                agentId: widget.agentId,
                assetId: asset.id,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showGenerateDialog(
    AgentAsset asset, {
    bool overwrite = false,
  }) async {
    final prompt = await _promptText(
      title: overwrite
          ? 'openai_regenerateAsset'.trParams({'name': asset.name})
          : 'openai_generateAsset'.trParams({'name': asset.name}),
      hint: 'openai_promptLabel'.tr,
      initial: asset.prompt,
    );
    if (prompt == null || prompt.trim().isEmpty) return;
    await _runGenerate(
      asset: asset,
      prompt: prompt.trim(),
      refPath: null,
      overwrite: overwrite || !asset.hasImage,
    );
  }

  Future<void> _showImg2ImgDialog(AgentAsset asset) async {
    final prompt = await _promptText(
      title: 'openai_img2imgTitle'.trParams({'name': asset.name}),
      hint: 'openai_img2imgHint'.tr,
    );
    if (prompt == null || prompt.trim().isEmpty) return;
    await _runGenerate(
      asset: asset,
      prompt: prompt.trim(),
      refPath: asset.path,
      overwrite: false,
    );
  }

  Future<void> _runGenerate({
    required AgentAsset asset,
    required String prompt,
    String? refPath,
    required bool overwrite,
  }) async {
    setState(() => _generating.add(asset.id));
    try {
      final refPaths = <String>[];
      if (refPath != null) {
        final abs = await ImageUtils.getAbsolutePath(refPath);
        if (abs.isNotEmpty && File(abs).existsSync()) refPaths.add(abs);
      }
      final images = await ImageGenService.instance.generate(
        prompt: '$prompt${await _personaSuffix()}',
        refImageAbsolutePaths: refPaths,
      );
      if (images.isEmpty) throw Exception('openai_noImageReturned'.tr);
      if (!mounted) return;
      if (overwrite) {
        await _assetsService.updateAsset(
          agentId: widget.agentId,
          assetId: asset.id,
          path: images.first,
        );
        ToastService.instance.showToast(
          'openai_assetGeneratedToast'.trParams({'name': asset.name}),
        );
      } else {
        // 图生图结果：存为新资产（命名）
        final name = await _promptText(
          title: 'openai_nameNewImage'.tr,
          hint: 'openai_nameNewImageHint'.trParams({'name': asset.name}),
        );
        if (name != null && name.trim().isNotEmpty) {
          await _assetsService.addAsset(
            agentId: widget.agentId,
            name: name.trim(),
            path: images.first,
          );
          ToastService.instance.showToast(
            'openai_assetSavedToast'.trParams({'name': name.trim()}),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ToastService.instance.showToast(
          'openai_generateFailed'.trParams({'error': '$e'}),
        );
      }
    } finally {
      if (mounted) setState(() => _generating.remove(asset.id));
    }
  }

  Future<void> _showEditAssetDialog(AgentAsset asset) async {
    final name = await _promptText(
      title: 'openai_rename'.tr,
      hint: 'openai_assetNameLabel'.tr,
      initial: asset.name,
    );
    if (name == null || name.trim().isEmpty) return;
    var prompt = asset.prompt;
    if (!asset.hasImage) {
      final p = await _promptText(
        title: 'openai_promptLabel'.tr,
        hint: 'openai_keepPlaceholder'.tr,
        initial: asset.prompt,
      );
      if (p != null && p.trim().isNotEmpty) prompt = p.trim();
    }
    await _assetsService.updateAsset(
      agentId: widget.agentId,
      assetId: asset.id,
      name: name.trim(),
      prompt: prompt,
    );
  }

  /// 单行文本输入对话框；返回 null 表示取消
  Future<String?> _promptText({
    required String title,
    String? hint,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDSDialog<String>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (dialogContext) => DSDialog(
            title: title,
            content: DSInput(controller: controller, hint: hint ?? ''),
            confirmText: 'app_ok'.tr,
            cancelText: 'app_cancel'.tr,
            onConfirm: () => Navigator.of(dialogContext).pop(controller.text),
            onCancel: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }
}
