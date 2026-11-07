import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_model_page.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'pet_store_screen.dart';
import 'video_pet_editor_screen.dart';

/// Live2D 商店页：分「Live2D 模型 / 宠物」两个分区。
///
/// - Live2D 分区：以新路由打开现有在线模型仓库页，选中返回
///   [Live2DModelDefinition] 后经 [onLive2DModelSelected] 交给宿主建档；
/// - 宠物分区：本地已安装宠物列表（videoManifest 存档），可直接进入
///   动画编辑器；远端目录安装移至宠物商店页（PetStoreScreen）。
class Live2DStoreScreen extends StatefulWidget {
  const Live2DStoreScreen({
    super.key,
    this.onLive2DModelSelected,
    this.persistArchive,
  });

  /// 在线模型仓库选中模型后回调（宿主负责创建存档）
  final void Function(Live2DModelDefinition model)? onLive2DModelSelected;

  /// 存档持久化；null 时走 [Live2DPlugin.upsert]（测试可注入）
  final Future<void> Function(Live2DArchive archive)? persistArchive;

  @override
  State<Live2DStoreScreen> createState() => _Live2DStoreScreenState();
}

class _Live2DStoreScreenState extends State<Live2DStoreScreen> {
  /// 当前分区：0 = Live2D 模型，1 = 宠物
  int _section = 0;

  String _text(String zh, String en) =>
      (Get.locale?.languageCode ?? 'zh') == 'zh' ? zh : en;

  /// 本插件实例；未注册（纯 UI 测试环境）时本地列表为空
  Live2DPlugin? get _plugin {
    final plugin = PluginManager().getPlugin('live2d');
    return plugin is Live2DPlugin ? plugin : null;
  }

  /// 本地已安装宠物：带精灵图 manifest 的存档
  List<Live2DArchive> get _localPets {
    final plugin = _plugin;
    if (plugin == null) return const [];
    return plugin.archives
        .where((a) => a.videoManifest != null)
        .toList();
  }

  Future<void> _persist(Live2DArchive archive) async {
    final injected = widget.persistArchive;
    if (injected != null) {
      await injected(archive);
      return;
    }
    final plugin = _plugin;
    if (plugin == null) return;
    await plugin.upsert(archive);
  }

  /// 空态直达宠物商店；返回后刷新本地宠物列表
  Future<void> _openPetStore() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PetStoreScreen()),
    );
    if (mounted) setState(() {});
  }

  /// 进入动画编辑器；先经 prepareForPlayback 解析出可预览的包
  /// （老存档/内置包的相对源在此迁移），保存返回的 manifest 与
  /// 包目录映射一起写回存档。
  Future<void> _editAnimations(Live2DArchive archive) async {
    final manifest = archive.videoManifest;
    if (manifest == null) return;
    try {
      final package = await const VideoPetImportService().prepareForPlayback(
        manifest,
        baseUri: archive.videoBaseUri,
        resolvedSources: archive.videoResolvedSources,
      );
      if (!mounted) return;
      final result = await Navigator.of(context).push<VideoPetManifest>(
        MaterialPageRoute(
          builder: (_) => VideoPetEditorScreen(
            manifest: package.manifest,
            baseUri: package.baseUri,
            resolvedSources: package.resolvedSources,
            // 下载即入档：编辑器内每下载一个动作就写回存档并持久化，
            // 未点保存退出也不丢已下载资源
            onActionInstalled: (manifest) {
              archive.videoManifest = manifest;
              archive.videoBaseUri = package.baseUri;
              archive.videoResolvedSources = package.resolvedSources;
              _persist(archive);
            },
          ),
        ),
      );
      if (result == null || !mounted) return;
      archive.videoManifest = result;
      archive.videoBaseUri = package.baseUri;
      archive.videoResolvedSources = package.resolvedSources;
      await _persist(archive);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showToast(
        '${_text('精灵图资源包加载失败', 'Failed to load spritesheet package')}: $error',
      );
    }
  }

  /// 以新路由打开现有在线模型仓库；页面自身 pop 返回选中的模型
  Future<void> _openOnlineModels() async {
    final model = await Navigator.of(context).push<Live2DModelDefinition>(
      MaterialPageRoute(builder: (_) => Live2DOnlineModelPage()),
    );
    if (model == null || !mounted) return;
    widget.onLive2DModelSelected?.call(model);
  }

  void _showToast(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DSSegmentedControl(
              options: [
                'live2d_storeSectionLive2d'.tr,
                'live2d_storeSectionPets'.tr,
              ],
              selected: _section,
              onChanged: (index) => setState(() => _section = index),
            ),
          ),
          Expanded(
            child: _section == 0
                ? _buildLive2DSection()
                : _buildLocalPetsSection(),
          ),
        ],
      ),
    );
  }

  /// Live2D 模型分区：提示 + 在线模型仓库入口（复用现有仓库页）
  Widget _buildLive2DSection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              'live2d_storeLive2dHint'.tr,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            DSButton(
              key: const ValueKey('live2dStoreOpenOnlineButton'),
              label: 'live2d_storeOpenLive2D'.tr,
              icon: DsIconKind.store,
              onPressed: _openOnlineModels,
            ),
          ],
        ),
      ),
    );
  }

  /// 宠物分区：本地已安装宠物列表
  Widget _buildLocalPetsSection() {
    final pets = _localPets;
    if (pets.isEmpty) {
      return Center(
        child: DSEmptyState(
          key: const ValueKey('live2dLocalPetsEmpty'),
          emoji: '🐾',
          title: 'live2d_storeLocalPetsEmpty'.tr,
          message: 'live2d_storeLocalPetsEmptyHint'.tr,
          // 空态直达宠物商店，缩短「去安装」路径
          actionLabel: 'live2d_storeGoPetStore'.tr,
          onAction: _openPetStore,
        ),
      );
    }
    // 底部留白给主屏悬浮导航（高约 110）+ 安全区，避免最后一条被遮挡
    final bottomInset = MediaQuery.paddingOf(context).bottom + 126;
    return ListView.separated(
      key: const ValueKey('live2dLocalPetsList'),
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
      itemCount: pets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildLocalPetItem(pets[index]),
    );
  }

  Widget _buildLocalPetItem(Live2DArchive archive) {
    final manifest = archive.videoManifest!;
    final subtitle = _text(
      '${manifest.name} · ${manifest.animations.length} 个动画',
      '${manifest.name} · ${manifest.animations.length} animations',
    );
    return DSListItem(
      key: ValueKey('live2dLocalPet_${archive.id}'),
      leading: AdaptiveImage(
        imagePath: archive.coverPath,
        width: 48,
        height: 48,
        borderRadius: 8,
      ),
      title: archive.name,
      subtitle: subtitle,
      subtitleMaxLines: 2,
      trailing: DSButton(
        key: ValueKey('live2dLocalPetEditButton_${archive.id}'),
        label: 'live2d_storeEditAnimations'.tr,
        icon: DsIconKind.animation,
        size: DSButtonSize.sm,
        onPressed: () => _editAnimations(archive),
      ),
      onTap: () => _editAnimations(archive),
    );
  }
}
