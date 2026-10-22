import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/widgets/agent_list_drawer.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_model_page.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d.dart';
import 'package:aboutme/widgets/form_fields/image_picker_field.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// Live2D 存档编辑表单：封面、名称、模型、Agent
class Live2DArchiveFormScreen extends StatefulWidget {
  const Live2DArchiveFormScreen({
    super.key,
    required this.archiveId,
    this.embedInSheet = false,
    this.onReady,
    this.onDeleteReady,
  });

  final String archiveId;

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

  /// 点击台词按部位的输入控制器（部位 id -> 多行文本，每行一条）
  final Map<String, TextEditingController> tapControllers = {
    for (final part in live2DTapParts)
      part.id: TextEditingController(),
  };
  List<AIAgent> agents = [];
  Live2DArchive? archive;
  String? _coverPath;

  @override
  void initState() {
    super.initState();
    archive = plugin.archives
        .where((a) => a.id == widget.archiveId)
        .firstOrNull;
    nameController.text = archive?.name ?? '';
    _coverPath = archive?.coverPath;
    for (final entry in tapControllers.entries) {
      entry.value.text = archive?.tapMessages[entry.key] ?? '';
    }
    widget.onReady?.call(_save);
    widget.onDeleteReady?.call(_delete);
    AgentController().loadVisibleAgents().then((value) {
      if (mounted) setState(() => agents = value);
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    for (final controller in tapControllers.values) {
      controller.dispose();
    }
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
    if (current == null) return;
    current.name = nameController.text.trim().isEmpty
        ? 'Live2D'
        : nameController.text.trim();
    current.coverPath = _coverPath;
    current.tapMessages = {
      for (final entry in tapControllers.entries) entry.key: entry.value.text,
    };
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
                  onMenu: _showMenu,
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
          saveDirectory: 'live2d_covers',
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
        const SizedBox(height: 20),
        DSListItem(
          title: 'live2d_modelSection'.tr,
          subtitle: current.modelLabel,
          showChevron: true,
          onTap: _chooseModel,
        ),
        const SizedBox(height: 12),
        DSListItem(
          title: 'live2d_chooseOnlineModel'.tr,
          leading: DsIcon(DsIconKind.download, color: theme.primary),
          showChevron: true,
          onTap: _chooseOnlineModel,
        ),
        const SizedBox(height: 12),
        DSListItem(
          title: 'live2d_agentSection'.tr,
          subtitle: _selectedAgentName ?? 'live2d_noAgentSelected'.tr,
          leading: DsIcon(DsIconKind.bot, color: theme.primary),
          showChevron: true,
          onTap: _chooseAgent,
        ),
        const SizedBox(height: 12),
        DSListItem(
          title: '点击台词',
          subtitle: '开启后按部位随机显示自定义台词，未填写的部位使用默认文案',
          leading: DsIcon(DsIconKind.chat, color: theme.primary),
          trailing: DSSwitch(
            value: current.tapMessagesEnabled,
            onChanged: (value) =>
                setState(() => current.tapMessagesEnabled = value),
          ),
        ),
        if (current.tapMessagesEnabled) ...[
          for (final part in live2DTapParts) ...[
            const SizedBox(height: 12),
            DSInput(
              controller: tapControllers[part.id],
              label: '${part.label}台词（每行一条，随机挑选）',
              maxLines: 3,
              minLines: 2,
            ),
          ],
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
