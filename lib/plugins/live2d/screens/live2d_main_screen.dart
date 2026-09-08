import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'live2d_settings_screen.dart';

/// Live2D 主界面：存档卡片列表，点击卡片进入存档设置
class Live2DMainScreen extends StatefulWidget {
  const Live2DMainScreen({super.key});

  @override
  State<Live2DMainScreen> createState() => _Live2DMainScreenState();
}

class _Live2DMainScreenState extends State<Live2DMainScreen> {
  late Live2DPlugin plugin;
  Map<String, String> agentNames = {};
  Map<String, dynamic> _multiFilters = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    plugin = PluginManager().getPlugin('live2d') as Live2DPlugin;
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    final agents = await AgentController().loadAgents();
    if (mounted) {
      setState(() {
        agentNames = {for (final a in agents) a.id: a.name};
      });
    }
  }

  List<Live2DArchive> get _filteredArchives {
    final model = _multiFilters['model'] as String?;
    return plugin.archives.where((a) {
      if (model != null && a.modelLabel != model) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final hit =
            a.name.toLowerCase().contains(q) ||
            a.modelLabel.toLowerCase().contains(q);
        if (!hit) return false;
      }
      return true;
    }).toList();
  }

  List<FilterItem> _buildFilterItems() {
    final models = plugin.archives.map((a) => a.modelLabel).toSet().toList()
      ..sort();
    if (models.isEmpty) return [];
    final options = {for (final m in models) m: m};
    return [
      FilterItem(
        id: 'model',
        title: 'live2d_modelSection'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildSingleChoiceFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
            options: options,
            allItemsKey: 'all',
            allItemsLabel: 'live2d_filterAllModels'.tr,
          );
        },
        getBadge: (value) => FilterBuilders.singleChoiceBadge(value, options),
      ),
    ];
  }

  Future<void> _pickCover(Live2DArchive archive) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ImagePickerDialog(
        initialUrl: archive.coverPath,
        saveDirectory: 'live2d_covers',
        enableCrop: true,
        cropAspectRatio: 16 / 9,
      ),
    );
    if (result == null) return;
    PaintingBinding.instance.imageCache.clear();
    setState(() => archive.coverPath = result['url'] as String);
    await plugin.save();
  }

  Future<void> _openSettings(Live2DArchive archive) async {
    plugin.selectedId = archive.id;
    await plugin.save();
    await NavigationHelper.push(
      context,
      Live2DSettingsScreen(initialArchiveId: archive.id),
    );
    if (mounted) {
      setState(() {});
      _loadAgents();
    }
  }

  Future<void> _createArchive() async {
    final created = Live2DArchive.create(
      modelLabel: 'Mao',
      modelDir: 'assets/models/mao/',
      modelFile: 'mao_pro.model3.json',
    );
    await plugin.upsert(created);
    await _openSettings(created);
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: const Text('Live2D'),
      largeTitle: 'Live2D',
      enableSearchBar: true,
      searchPlaceholder: 'live2d_searchPlaceholder'.tr,
      onSearchChanged: (query) => setState(() => _searchQuery = query),
      searchBody: _buildBody(),
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      onMultiFilterChanged:
          (filters) => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _multiFilters = filters);
          }),
      body: _buildBody(),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _createArchive,
        ),
      ],
    );
  }

  Widget _buildBody() {
    final archives = _filteredArchives;
    if (plugin.archives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.face_retouching_natural,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'live2d_noArchives'.tr,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    if (archives.isEmpty) {
      return Center(child: Text('live2d_noMatchArchives'.tr));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: archives.length,
      itemBuilder: (context, index) =>
          _Live2DArchiveCard(
            archive: archives[index],
            agentName: agentNames[archives[index].agentId],
            onTap: () => _openSettings(archives[index]),
            onCoverTap: () => _pickCover(archives[index]),
          ),
    );
  }
}

class _Live2DArchiveCard extends StatelessWidget {
  const _Live2DArchiveCard({
    required this.archive,
    required this.onTap,
    required this.onCoverTap,
    this.agentName,
  });

  final Live2DArchive archive;
  final String? agentName;
  final VoidCallback onTap;
  final VoidCallback onCoverTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Column 给子项的高度约束是无界的，StackFit.expand 无法在无界约束下
          // 展开，必须用 AspectRatio 先确定封面高度
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AdaptiveImage(
                  key: ValueKey(archive.coverPath),
                  imagePath: archive.coverPath,
                  fit: BoxFit.cover,
                  borderRadius: 0,
                  defaultImage: _buildCoverPlaceholder(theme),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Material(
                    color: theme.colorScheme.surface.withValues(alpha: 0.85),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onCoverTap,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          archive.coverPath == null
                              ? Icons.add_photo_alternate_outlined
                              : Icons.edit,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      archive.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      archive.modelLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            agentName ?? 'live2d_noAgentSelected'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(ThemeData theme) => Container(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        alignment: Alignment.center,
        child: Icon(
          Icons.face_retouching_natural,
          size: 40,
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
        ),
      );
}
