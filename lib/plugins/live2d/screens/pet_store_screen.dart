import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/live2d/video/pet_store_catalog.dart';
import 'package:aboutme/plugins/live2d/video/pet_store_service.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_import.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'video_pet_editor_screen.dart';

/// 宠物商店页：经 [PetStoreService] 拉取远端目录并安装为 video 宠物存档，
/// 已安装的宠物可直接进入动画编辑器。
///
/// 由 Live2D 主界面右上角商店菜单进入；本地已安装宠物的展示与编辑
/// 在 Live2DStoreScreen 的宠物分区。
class PetStoreScreen extends StatefulWidget {
  const PetStoreScreen({
    super.key,
    this.service,
    this.findInstalledArchive,
    this.persistArchive,
  });

  /// 宠物商店服务；null 时内部按默认配置自建（测试可注入）
  final PetStoreService? service;

  /// 按宠物 id 查询已安装存档；null 时从 [Live2DPlugin] 存档中
  /// 按 manifest metadata 的商店标记匹配（测试可注入）
  final Live2DArchive? Function(String petId)? findInstalledArchive;

  /// 存档持久化；null 时走 [Live2DPlugin.upsert]（测试可注入）
  final Future<void> Function(Live2DArchive archive)? persistArchive;

  @override
  State<PetStoreScreen> createState() => _PetStoreScreenState();
}

class _PetStoreScreenState extends State<PetStoreScreen> {
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

  String _text(String zh, String en) =>
      (Get.locale?.languageCode ?? 'zh') == 'zh' ? zh : en;

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

  void _showToast(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DSThemeBridge(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DSTopBar(
                  title: 'live2d_petStoreTitle'.tr,
                  onBack: () => Navigator.maybePop(context),
                ),
              ),
              Expanded(child: _buildPetsSection()),
            ],
          ),
        ),
      ),
    );
  }

  /// 目录加载状态机 + 宠物列表
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
    return ListView.separated(
      key: const ValueKey('live2dStorePetsList'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
