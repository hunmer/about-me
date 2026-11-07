import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/widgets/agent_list_drawer.dart';
import 'package:aboutme/plugins/live2d/screens/live2d_imported_models_screen.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_model_page.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d.dart';
import 'package:aboutme/widgets/form_fields/image_picker_field.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import '../video/video_pet_import.dart';
import '../video/video_pet_manifest.dart';
import 'live2d_region_editor.dart';
import 'video_pet_editor_screen.dart';

/// Live2D 存档编辑表单：封面、名称、模型、Agent
class Live2DArchiveFormScreen extends StatefulWidget {
  const Live2DArchiveFormScreen({
    super.key,
    required this.archiveId,
    this.draftArchive,
    this.embedInSheet = false,
    this.onReady,
    this.onDeleteReady,
  });

  final String archiveId;

  /// 新建草稿（尚未入库），优先于 [archiveId] 的档案查找；
  /// 点击保存时才经 upsert 真正创建
  final Live2DArchive? draftArchive;

  /// 以底部弹层形式嵌入（不渲染 Scaffold/顶栏，由外壳提供标题与保存）
  final bool embedInSheet;

  /// 弹层模式下回传保存动作（外壳"保存"按钮触发）
  final void Function(VoidCallback save)? onReady;

  /// 弹层模式下回传删除动作（外壳标题栏删除按钮触发）
  final void Function(VoidCallback delete)? onDeleteReady;

  @override
  State<Live2DArchiveFormScreen> createState() =>
      _Live2DArchiveFormScreenState();
}

class _Live2DArchiveFormScreenState extends State<Live2DArchiveFormScreen> {
  final plugin = Live2DPlugin.instance;
  final nameController = TextEditingController();
  final noteController = TextEditingController();

  List<AIAgent> agents = [];
  Live2DArchive? archive;
  String? _coverPath;
  bool _loadingVideo = false;

  /// Live2D 模式的逐区域台词配置草稿（保存时回写 archive.tapRegions）
  List<Live2DTapRegion> _regions = [];

  String _videoText(String zh, String en) =>
      (Get.locale?.languageCode ?? 'zh') == 'zh' ? zh : en;

  void _setDisplayMode(String mode) {
    final current = archive;
    if (current == null || _loadingVideo) return;
    // 切到精灵图模式不再自动加载默认资源包：资源来源改为
    // 下方 select 选择本地已安装宠物，或手动导入 JSON / ZIP
    setState(() => current.displayMode = mode);
  }

  Future<void> _loadVideoPackage() async {
    if (_loadingVideo) return;
    setState(() => _loadingVideo = true);
    try {
      final service = VideoPetImportService();
      final package = await service.importPackage();
      if (!mounted || package == null) return;
      setState(() {
        archive!.displayMode = 'video';
        archive!.videoManifest = package.manifest;
        archive!.videoBaseUri = package.baseUri;
        archive!.videoResolvedSources = package.resolvedSources;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_videoText('资源包加载失败', 'Package load failed')}: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingVideo = false);
    }
  }

  /// 本地已安装宠物候选（其他带精灵图 manifest 的存档）
  List<Live2DArchive> get _localPetArchives {
    final current = archive;
    return [
      for (final a in plugin.archives)
        if (a.videoManifest != null && a.id != current?.id) a,
    ];
  }

  /// 当前草稿资源包对应的本地宠物存档 id（按 manifest.id 匹配）
  String? get _selectedLocalPetId {
    final manifestId = archive?.videoManifest?.id;
    if (manifestId == null) return null;
    for (final a in _localPetArchives) {
      if (a.videoManifest?.id == manifestId) return a.id;
    }
    return null;
  }

  /// 选中本地宠物：拷贝其资源包（manifest 与目录映射）到当前草稿
  void _applyLocalPet(String archiveId) {
    final current = archive;
    if (current == null) return;
    final source = _localPetArchives
        .where((a) => a.id == archiveId)
        .firstOrNull;
    final manifest = source?.videoManifest;
    if (source == null || manifest == null) return;
    setState(() {
      current.videoManifest = manifest;
      current.videoBaseUri = source.videoBaseUri;
      current.videoResolvedSources = source.videoResolvedSources;
    });
  }

  Future<void> _editVideo() async {
    final current = archive;
    final manifest = current?.videoManifest;
    if (current == null || manifest == null) return;
    try {
      final package = await const VideoPetImportService().prepareForPlayback(
        manifest,
        baseUri: current.videoBaseUri,
        resolvedSources: current.videoResolvedSources,
      );
      if (!mounted) return;
      final result = await Navigator.of(context).push<VideoPetManifest>(
        MaterialPageRoute(
          builder: (_) => VideoPetEditorScreen(
            manifest: package.manifest,
            baseUri: package.baseUri,
            resolvedSources: package.resolvedSources,
            // 下载即入档：下载完成的动作立即合入表单草稿（表单本身
            // 未保存，随表单保存落盘；取消编辑不再丢已下载动作）
            onActionInstalled: (manifest) {
              if (!mounted) return;
              setState(() {
                current.videoManifest = manifest;
                current.videoBaseUri = package.baseUri;
                current.videoResolvedSources = package.resolvedSources;
              });
            },
          ),
        ),
      );
      if (mounted && result != null) {
        setState(() {
          current.videoManifest = result;
          current.videoBaseUri = package.baseUri;
          current.videoResolvedSources = package.resolvedSources;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('精灵图资源包加载失败：$error')));
    }
  }

  @override
  void initState() {
    super.initState();
    final source =
        widget.draftArchive ??
        plugin.archives.where((a) => a.id == widget.archiveId).firstOrNull;
    archive = source == null ? null : Live2DArchive.fromJson(source.toJson());
    nameController.text = archive?.name ?? '';
    noteController.text = archive?.note ?? '';
    _coverPath = archive?.coverPath;
    _regions = List.of(archive?.tapRegions ?? const []);
    widget.onReady?.call(_save);
    widget.onDeleteReady?.call(_delete);
    AgentController().loadVisibleAgents().then((value) {
      if (mounted) setState(() => agents = value);
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    noteController.dispose();
    super.dispose();
  }

  String? get _selectedAgentName =>
      agents.where((a) => a.id == archive?.agentId).firstOrNull?.name;

  Future<void> _chooseModel() async {
    final current = archive;
    if (current == null) return;
    final model = await SmoothBottomSheet.show<Live2DModelDefinition>(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: availableJellyLive2DModels
            .map(
              (model) => ListTile(
                title: Text(model.label),
                selected: model.label == current.modelLabel,
                onTap: () => Navigator.pop(context, model),
              ),
            )
            .toList(),
      ),
    );
    if (model == null) return;
    setState(() {
      current.modelLabel = model.label;
      current.modelDir = model.modelDir;
      current.modelFile = model.modelFile;
    });
  }

  Future<void> _chooseOnlineModel() async {
    final current = archive;
    if (current == null) return;
    final model = await Navigator.of(context).push<Live2DModelDefinition>(
      MaterialPageRoute(builder: (_) => const Live2DOnlineModelPage()),
    );
    if (!mounted || model == null) return;
    setState(() {
      current.modelLabel = model.label;
      current.modelDir = model.modelDir;
      current.modelFile = model.modelFile;
    });
  }

  /// 打开本地模型库选择（zip 导入的模型列表，库内可继续导入新压缩包）
  Future<void> _chooseImportedModel() async {
    final current = archive;
    if (current == null) return;
    final model = await Navigator.of(context).push<Live2DModelDefinition>(
      MaterialPageRoute(builder: (_) => const Live2DImportedModelsScreen()),
    );
    if (!mounted || model == null) return;
    setState(() {
      current.modelLabel = model.label;
      current.modelDir = model.modelDir;
      current.modelFile = model.modelFile;
    });
  }

  Future<void> _chooseAgent() async {
    final current = archive;
    if (current == null) return;
    final selected = current.agentId == null
        ? <Map<String, String>>[]
        : [
            {
              'id': current.agentId!,
              'name':
                  agents
                      .where((a) => a.id == current.agentId)
                      .firstOrNull
                      ?.name ??
                  '',
            },
          ];
    final result = await SmoothBottomSheet.show<List<Map<String, String>>>(
      context: context,
      builder: (_) => AgentListDrawer(
        selectedAgents: selected,
        allowMultipleSelection: false,
        onAgentSelected: (_) {},
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() => current.agentId = result.first['id']);
  }

  Future<void> _save() async {
    final current = archive;
    if (current == null || _loadingVideo) return;
    if (current.isVideo && current.videoManifest == null) return;
    current.videoManifest?.validate();
    current.name = nameController.text.trim().isEmpty
        ? 'Live2D'
        : nameController.text.trim();
    current.coverPath = _coverPath;
    current.note = noteController.text.trim();
    // tapMessages 不再在此表单编辑：保留存档原值（视频运行时仍按部位消费）
    current.tapRegions = List.of(_regions);
    await plugin.upsert(current);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('live2d_saved'.tr)));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final current = archive;
    if (current == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('live2d_deleteArchiveTitle'.tr),
        content: Text(
          'live2d_deleteArchiveConfirm'.trParams({'name': current.name}),
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
    await plugin.deleteArchive(current.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showMenu() async {
    await SmoothBottomSheet.show(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'live2d_deleteArchiveTitle'.tr,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _delete();
            },
          ),
        ],
      ),
    );
  }

  /// 顶栏尾部菜单按钮（原 DSTopBar 内置菜单位移除后由本页自建，
  /// 样式与顶栏返回钮一致：36px 圆形按压钮 + more 图标）
  Widget _buildMenuButton() {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: _showMenu,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pressed
                ? theme.surfaceAlt
                : hovered
                ? theme.surfaceAlt.withValues(alpha: 0.6)
                : null,
          ),
          child: DsIcon(DsIconKind.more, size: 20, color: theme.text),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final current = archive;

    if (current == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text('live2d_noMatchArchives'.tr)),
      );
    }

    final scrollForm = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildFields(theme, current),
    );

    // 弹层模式：外壳提供标题/保存/删除，去掉自带顶栏与保存按钮
    if (widget.embedInSheet) {
      return scrollForm;
    }

    return Scaffold(
      body: DSThemeBridge(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DSTopBar(
                  title: 'live2d_editArchiveTitle'.tr,
                  onBack: () => Navigator.maybePop(context),
                  // DSTopBar 已移除内置菜单按钮，删除入口由本页自行传入
                  actions: [_buildMenuButton()],
                ),
              ),
              Expanded(child: scrollForm),
            ],
          ),
        ),
      ),
    );
  }

  /// 表单字段（全屏模式在末尾追加保存按钮）
  Widget _buildFields(AppThemeData theme, Live2DArchive current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImagePickerField(
          currentImage: _coverPath,
          labelText: 'live2d_coverLabel'.tr,
          hintText: 'live2d_chooseCoverHint'.tr,
          enableCrop: true,
          cropAspectRatio: 16 / 9,
          defaultImage: _buildCoverPlaceholder(theme),
          onImageChanged: (image) {
            setState(() {
              _coverPath = image is Map
                  ? image['url'] as String?
                  : image as String?;
            });
          },
        ),
        const SizedBox(height: 20),
        DSInput(controller: nameController, label: 'live2d_nameLabel'.tr),
        const SizedBox(height: 12),
        DSInput(
          controller: noteController,
          label: '模型注释（可选）',
          maxLines: 3,
          minLines: 2,
        ),
        const SizedBox(height: 20),
        DSSegmentedControl(
          options: ['Live2D', _videoText('精灵图', 'Spritesheet')],
          selected: current.displayMode == 'video' ? 1 : 0,
          onChanged: _loadingVideo
              ? null
              : (index) => _setDisplayMode(index == 1 ? 'video' : 'live2d'),
        ),
        const SizedBox(height: 12),
        if (current.isVideo) ...[
          if (_loadingVideo) const LinearProgressIndicator(),
          ListTile(
            title: Text(
              current.videoManifest?.name ??
                  _videoText('尚未加载资源包', 'No package loaded'),
            ),
            // 版权说明并入 subtitle 内部下方，与包信息左对齐
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _videoText(
                    'JSON 资源包 · ${current.videoManifest?.animations.length ?? 0} 个动画',
                    'JSON package · ${current.videoManifest?.animations.length ?? 0} animations',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _videoText(
                    '默认素材来自 dsh-pet，禁止商用；来源和许可保存在资源包中。',
                    'Default assets are from dsh-pet, for non-commercial use. Attribution and license are included in the package.',
                  ),
                ),
              ],
            ),
          ),
          // 本地已安装宠物选择：选中即拷贝其资源包到当前草稿
          if (_localPetArchives.isNotEmpty) ...[
            const SizedBox(height: 8),
            DSSelect<String>(
              items: [
                for (final a in _localPetArchives)
                  DSSelectItem(label: a.name, value: a.id),
              ],
              value: _selectedLocalPetId,
              hint: _videoText('选择已安装的宠物', 'Choose an installed pet'),
              enabled: !_loadingVideo,
              onChanged: _applyLocalPet,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _loadingVideo ? null : () => _loadVideoPackage(),
                child: Text(_videoText('导入 JSON / ZIP', 'Import JSON / ZIP')),
              ),
              FilledButton.icon(
                onPressed: _loadingVideo || current.videoManifest == null
                    ? null
                    : _editVideo,
                icon: const Icon(Icons.touch_app),
                label: Text(_videoText('编辑交互区域', 'Edit interactions')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DSListItem(
            title: _videoText('Jev 智能动作', 'Jev smart animation'),
            subtitle: _videoText(
              '根据 AI 回复自动播放合适的动作（仅编辑器中启用的动作）',
              'Auto-play a matching animation based on AI replies (enabled animations only)',
            ),
            leading: DsIcon(DsIconKind.moon, color: theme.primary),
            trailing: DSSwitch(
              value: current.jevEnabled,
              onChanged: (value) => setState(() => current.jevEnabled = value),
            ),
          ),
        ] else ...[
          DSListItem(
            title: 'Jev 智能表情与动作',
            subtitle: '根据 AI 回复自动选择合适的表情和动作',
            leading: DsIcon(DsIconKind.moon, color: theme.primary),
            trailing: DSSwitch(
              value: current.jevEnabled,
              onChanged: (value) => setState(() => current.jevEnabled = value),
            ),
          ),
          const SizedBox(height: 12),
          DSListItem(
            title: 'live2d_modelSection'.tr,
            subtitle: current.modelLabel,
            showChevron: true,
            onTap: _chooseModel,
          ),
          const SizedBox(height: 12),
          DSListItem(
            title: 'live2d_importedModelsEntry'.tr,
            leading: DsIcon(DsIconKind.archive, color: theme.primary),
            showChevron: true,
            onTap: _chooseImportedModel,
          ),
          const SizedBox(height: 12),
          DSListItem(
            title: 'live2d_chooseOnlineModel'.tr,
            leading: DsIcon(DsIconKind.download, color: theme.primary),
            showChevron: true,
            onTap: _chooseOnlineModel,
          ),
        ],
        const SizedBox(height: 12),
        DSListItem(
          title: 'live2d_agentSection'.tr,
          subtitle: _selectedAgentName ?? 'live2d_noAgentSelected'.tr,
          leading: DsIcon(DsIconKind.bot, color: theme.primary),
          showChevron: true,
          onTap: _chooseAgent,
        ),
        if (current.isVideo) ...[
          const SizedBox(height: 12),
          DSListItem(
            title: _videoText('随机走动', 'Random walk'),
            subtitle: _videoText(
              '开启后该档案的桌宠会在小屋内随机等待并水平走动',
              'When enabled, the pet of this profile waits and walks horizontally at random',
            ),
            leading: DsIcon(DsIconKind.drag, color: theme.primary),
            trailing: DSSwitch(
              value: current.randomWalkEnabled,
              onChanged: (value) =>
                  setState(() => current.randomWalkEnabled = value),
            ),
          ),
        ],
        const SizedBox(height: 12),
        DSListItem(
          title: '点击台词',
          subtitle: current.isVideo
              ? _videoText(
                  '开启后点击桌宠会随机显示已配置的台词',
                  'Show configured messages at random when the pet is tapped',
                )
              : _videoText(
                  '开启后点击模型区域显示自定义台词，按区域单独配置',
                  'Show custom messages when the model is tapped, per region',
                ),
          leading: DsIcon(DsIconKind.chat, color: theme.primary),
          trailing: DSSwitch(
            value: current.tapMessagesEnabled,
            onChanged: (value) =>
                setState(() => current.tapMessagesEnabled = value),
          ),
        ),
        // Live2D 模式：逐区域（HitArea/自定义矩形）台词编辑入口
        if (current.tapMessagesEnabled && !current.isVideo) ...[
          const SizedBox(height: 12),
          _buildTapRegionSection(theme, current),
        ],
        if (!widget.embedInSheet) ...[
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: DSButton(label: 'live2d_saveButton'.tr, onPressed: _save),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// Live2D 模式逐区域台词区：仅保留区域编辑入口与摘要（模型预览在编辑器内）
  Widget _buildTapRegionSection(AppThemeData theme, Live2DArchive current) {
    final modelCount = _regions.where((r) => r.source == 'model').length;
    final customCount = _regions.where((r) => r.source == 'custom').length;
    final messageCount = _regions.fold<int>(
      0,
      (sum, region) => sum + region.effectiveMessages.length,
    );
    return DSListItem(
      title: _videoText('点击区域与台词', 'Tap regions & messages'),
      subtitle: _videoText(
        '模型部位 $modelCount · 自定义矩形 $customCount · 台词 $messageCount 条，点击编辑',
        'Model $modelCount · custom $customCount · $messageCount messages, tap to edit',
      ),
      leading: DsIcon(DsIconKind.layers, color: theme.primary),
      showChevron: true,
      onTap: () => _editRegions(current),
    );
  }

  Future<void> _editRegions(Live2DArchive current) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Live2DRegionEditorScreen(
          archive: current,
          initialRegions: _regions,
          onChanged: (regions) => setState(() => _regions = regions),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(AppThemeData theme) => Container(
    height: 160,
    decoration: BoxDecoration(
      color: theme.primary.mixWhite(0.92),
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: DsIcon(DsIconKind.image, size: 36, color: theme.primary),
  );
}
