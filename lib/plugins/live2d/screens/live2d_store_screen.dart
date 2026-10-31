import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/live2d/video/pet_store_catalog.dart';
import 'package:aboutme/plugins/live2d/video/pet_store_service.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_model_page.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'video_pet_editor_screen.dart';

/// Live2D 商店页：分「Live2D 模型 / 宠物」两个分区。
///
/// - Live2D 分区：以新路由打开现有在线模型仓库页，选中返回
///   [Live2DModelDefinition] 后经 [onLive2DModelSelected] 交给宿主建档；
/// - 宠物分区：经 [PetStoreService] 拉取目录并安装为 video 宠物存档，
///   已安装的宠物可直接进入动画编辑器。
class Live2DStoreScreen extends StatefulWidget {
  const Live2DStoreScreen({
    super.key,
    this.onLive2DModelSelected,
    this.service,
    this.findInstalledArchive,
    this.persistArchive,
  });

  /// 在线模型仓库选中模型后回调（宿主负责创建存档）
  final void Function(Live2DModelDefinition model)? onLive2DModelSelected;

  /// 宠物商店服务；null 时内部按默认配置自建（测试可注入）
  final PetStoreService? service;

  /// 按宠物 id 查询已安装存档；null 时从 [Live2DPlugin] 存档中
  /// 按 manifest metadata 的商店标记匹配（测试可注入）
  final Live2DArchive? Function(String petId)? findInstalledArchive;

  /// 存档持久化；null 时走 [Live2DPlugin.upsert]（测试可注入）
  final Future<void> Function(Live2DArchive archive)? persistArchive;

  @override
  State<Live2DStoreScreen> createState() => _Live2DStoreScreenState();
}

class _Live2DStoreScreenState extends State<Live2DStoreScreen> {
  /// 当前分区：0 = Live2D 模型，1 = 宠物
  int _section = 1;

  List<PetStoreEntry> _pets = const [];
  bool _petsLoading = true;
  String? _petsError;

  /// 正在安装的宠物 id 集合
  final Set<String> _installing = {};

  /// 安装失败的错误文案（宠物 id → 错误）
  final Map<String, String> _installErrors = {};

  /// 内部自建的商店服务（dispose 时释放）
  PetStoreService? _ownService;

  PetStoreService get _service =>
      widget.service ?? (_ownService ??= PetStoreService());

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  @override
  void dispose() {
    // 仅释放本页自建的服务；注入的服务由宿主管理
    _ownService?.close();
    super.dispose();
  }

  Future<void> _loadPets() async {
    setState(() {
      _petsLoading = true;
      _petsError = null;
    });
    try {
      final pets = await _service.fetchPets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _petsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _petsError = '$error';
        _petsLoading = false;
      });
    }
  }

  /// 查找宠物已安装的存档：优先 metadata 商店标记，兜底 manifest.id。
  ///
  /// 插件未注册（如纯 UI 测试环境）时视为未安装，避免强转崩溃。
  Live2DArchive? _installedArchiveFor(PetStoreEntry entry) {
    final injected = widget.findInstalledArchive;
    if (injected != null) return injected(entry.id);
    final plugin = PluginManager().getPlugin('live2d');
    if (plugin is! Live2DPlugin) return null;
    for (final archive in plugin.archives) {
      final manifest = archive.videoManifest;
      if (manifest == null) continue;
      if (manifest.metadata[kPetStoreMetadataPetId] == entry.id ||
          manifest.id == entry.id) {
        return archive;
      }
    }
    return null;
  }

  Future<void> _persist(Live2DArchive archive) async {
    final injected = widget.persistArchive;
    if (injected != null) {
      await injected(archive);
      return;
    }
    final plugin = PluginManager().getPlugin('live2d');
    if (plugin is! Live2DPlugin) return;
    await plugin.upsert(archive);
  }

  /// 安装宠物：幂等（已安装直接忽略），安装结果写入新的 video 存档
  Future<void> _installPet(PetStoreEntry entry) async {
    if (_installing.contains(entry.id)) return;
    if (_installedArchiveFor(entry) != null) return;
    setState(() {
      _installing.add(entry.id);
      _installErrors.remove(entry.id);
    });
    try {
      final package = await _service.installPet(entry);
      final archive = Live2DArchive(
        id: 'pet_store_${entry.id}',
        name: entry.name,
        modelLabel: '',
        modelDir: '',
        modelFile: '',
        agentId: null,
        coverPath: entry.coverUrl,
        displayMode: 'video',
        videoManifest: package.manifest,
        videoBaseUri: package.baseUri,
        videoResolvedSources: package.resolvedSources,
      );
      await _persist(archive);
      if (!mounted) return;
      setState(() {});
      _showToast('live2d_storeInstalledToast'.trParams({'name': entry.name}));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _installErrors[entry.id] = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _installing.remove(entry.id);
        });
      }
    }
  }

  /// 进入动画编辑器；先经 prepareForPlayback 解析出可预览的包
  /// （老存档/内置包的相对源在此迁移），保存返回的 manifest 与
  /// 包目录映射一起写回存档。
  Future<void> _editAnimations(PetStoreEntry entry) async {
    final archive = _installedArchiveFor(entry);
    final manifest = archive?.videoManifest;
    if (archive == null || manifest == null) return;
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
            petStoreService: widget.service ?? _ownService,
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
      _showToast('精灵图资源包加载失败：$error');
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
                : _buildPetsSection(),
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

  /// 宠物分区：目录加载状态机 + 宠物列表
  Widget _buildPetsSection() {
    if (_petsLoading) {
      return Center(
        child: DSLoadingDots(label: 'live2d_storePetsLoading'.tr),
      );
    }
    if (_petsError != null) {
      return DSEmptyState(
        key: const ValueKey('live2dStorePetsError'),
        emoji: '⚠️',
        title: 'live2d_storePetsError'.trParams({'error': _petsError!}),
        actionLabel: 'app_retry'.tr,
        onAction: _loadPets,
      );
    }
    if (_pets.isEmpty) {
      return DSEmptyState(
        emoji: '🐾',
        title: 'live2d_storePetsEmpty'.tr,
      );
    }
    // 底部留白给主屏悬浮导航（高约 110）+ 安全区，避免最后一条被遮挡
    final bottomInset = MediaQuery.paddingOf(context).bottom + 126;
    return ListView.separated(
      key: const ValueKey('live2dStorePetsList'),
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
      itemCount: _pets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildPetItem(_pets[index]),
    );
  }

  Widget _buildPetItem(PetStoreEntry entry) {
    final installed = _installedArchiveFor(entry);
    final installing = _installing.contains(entry.id);
    final error = _installErrors[entry.id];
    return DSListItem(
      key: ValueKey('live2dStorePet_${entry.id}'),
      leading: AdaptiveImage(
        imagePath: entry.coverUrl,
        width: 48,
        height: 48,
        borderRadius: 8,
      ),
      title: entry.name,
      subtitle: '${entry.id} · ${entry.description}',
      subtitleMaxLines: 2,
      trailing: _buildPetTrailing(entry, installed, installing, error),
      onTap: installed != null
          ? () => _editAnimations(entry)
          : (installing ? null : () => _installPet(entry)),
    );
  }

  /// 尾部按钮：安装 → 安装中 → 编辑动画 / 失败重试
  Widget? _buildPetTrailing(
    PetStoreEntry entry,
    Live2DArchive? installed,
    bool installing,
    String? error,
  ) {
    if (installing) {
      return const DSLoadingDots();
    }
    if (installed != null) {
      return DSButton(
        key: ValueKey('live2dStoreEditButton_${entry.id}'),
        label: 'live2d_storeEditAnimations'.tr,
        icon: DsIconKind.animation,
        size: DSButtonSize.sm,
        onPressed: () => _editAnimations(entry),
      );
    }
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              'live2d_storeInstallFailed'.trParams({'error': error}),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          DSButton(
            key: ValueKey('live2dStoreRetryButton_${entry.id}'),
            label: 'app_retry'.tr,
            size: DSButtonSize.sm,
            onPressed: () => _installPet(entry),
          ),
        ],
      );
    }
    return DSButton(
      key: ValueKey('live2dStoreInstallButton_${entry.id}'),
      label: 'live2d_storeInstall'.tr,
      icon: DsIconKind.download,
      size: DSButtonSize.sm,
      onPressed: () => _installPet(entry),
    );
  }
}
