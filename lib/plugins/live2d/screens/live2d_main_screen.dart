import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'live2d_archive_form_screen.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

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
    final agents = await AgentController().loadVisibleAgents();
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

  Future<void> _openSettings(Live2DArchive archive) async {
    plugin.selectedId = archive.id;
    await plugin.save();
    await _showArchiveForm(archive.id);
    if (mounted) {
      setState(() {});
      _loadAgents();
    }
  }

  /// 档案编辑：smooth_sheets 底部弹层
  Future<void> _showArchiveForm(
    String archiveId, {
    Live2DArchive? draft,
  }) async {
    VoidCallback? saveArchive;
    VoidCallback? deleteArchive;
    await SmoothBottomSheet.showForm(
      context: context,
      title: 'live2d_editArchiveTitle'.tr,
      child: Live2DArchiveFormScreen(
        archiveId: archiveId,
        draftArchive: draft,
        embedInSheet: true,
        onReady: (save) => saveArchive = save,
        onDeleteReady: (delete) => deleteArchive = delete,
      ),
      onSave: () => saveArchive?.call(),
      // 草稿尚未入库，无需删除按钮（关闭即丢弃）
      onDelete: draft == null ? () => deleteArchive?.call() : null,
    );
  }

  /// 新建档案：草稿先不入库，保存时才经表单 upsert 创建
  Future<void> _createArchive() async {
    final created = Live2DArchive.create(
      modelLabel: 'Mao',
      modelDir: 'assets/models/mao/',
      modelFile: 'mao_pro.model3.json',
    );
    await _showArchiveForm(created.id, draft: created);
    if (mounted) {
      setState(() {});
      _loadAgents();
    }
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
      onMultiFilterChanged: (filters) =>
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _multiFilters = filters);
          }),
      body: _buildBody(),
      actions: [
        // actions 经 Overlay 渲染，DS 组件需自带 DSThemeBridge
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.plus,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'live2d_newArchive'.tr,
                onPressed: _createArchive,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final archives = _filteredArchives;
          if (plugin.archives.isEmpty) {
            return Center(
              child: DSEmptyState(
                emoji: '🐱',
                title: 'live2d_noArchives'.tr,
                message: 'live2d_noArchivesHint'.tr,
                actionLabel: 'live2d_newArchive'.tr,
                onAction: _createArchive,
              ),
            );
          }
          if (archives.isEmpty) {
            return Center(
              child: Text(
                'live2d_noMatchArchives'.tr,
                style: DsTypography.body.copyWith(color: theme.textSub),
              ),
            );
          }
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              // ≥ 贴条出血,避免上一行贴条压盖
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: archives.length,
            // 手绘便签:随机倾斜 + 贴条(角度由 archive.id 哈希确定)
            itemBuilder: (context, index) => HandDrawnStickyItem(
              tiltKey: archives[index].id,
              child: WiredDraw(
                child: _Live2DArchiveCard(
                  archive: archives[index],
                  agentName: agentNames[archives[index].agentId],
                  onTap: () => _openSettings(archives[index]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Live2DArchiveCard extends StatelessWidget {
  const _Live2DArchiveCard({
    required this.archive,
    required this.onTap,
    this.agentName,
  });

  final Live2DArchive archive;
  final String? agentName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return DSCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column 给子项的高度约束是无界的，StackFit.expand 无法在无界约束下
          // 展开，必须用 AspectRatio 先确定封面高度
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AdaptiveImage(
                key: ValueKey(archive.coverPath),
                imagePath: archive.coverPath,
                fit: BoxFit.cover,
                borderRadius: 0,
                defaultImage: _buildCoverPlaceholder(theme),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    archive.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    archive.modelLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.caption.copyWith(color: theme.primary),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      DsIcon(DsIconKind.bot, size: 14, color: theme.textSub),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          agentName ?? 'live2d_noAgentSelected'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
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
    );
  }

  Widget _buildCoverPlaceholder(AppThemeData theme) => Container(
    color: theme.hatch,
    alignment: Alignment.center,
    child: DsIcon(DsIconKind.mood, size: 40, color: theme.primary),
  );
}
