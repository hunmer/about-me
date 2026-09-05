import 'package:flutter/material.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/widgets/prompt_editor.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_model_page.dart';

class Live2DSettingsScreen extends StatefulWidget {
  const Live2DSettingsScreen({super.key});

  @override
  State<Live2DSettingsScreen> createState() => _Live2DSettingsScreenState();
}

class _Live2DSettingsScreenState extends State<Live2DSettingsScreen> {
  final plugin = Live2DPlugin.instance;
  final nameController = TextEditingController();
  List<AIAgent> agents = [];
  Live2DArchive? archive;

  @override
  void initState() {
    super.initState();
    archive = plugin.selected ?? (plugin.archives.isNotEmpty ? plugin.archives.first : null);
    if (archive != null) nameController.text = archive!.name;
    AgentController().loadAgents().then((value) {
      if (mounted) setState(() => agents = value);
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void selectArchive(String? id) {
    if (id == '__new__') {
      final created = Live2DArchive.create(modelLabel: '默认模型', modelDir: '', modelFile: '');
      plugin.upsert(created);
      setState(() { archive = created; nameController.text = created.name; });
    } else if (id != null) {
      setState(() {
        archive = plugin.archives.firstWhere((item) => item.id == id);
        nameController.text = archive!.name;
      });
    }
  }

  Future<void> saveArchive() async {
    final current = archive;
    if (current == null) return;
    current.name = nameController.text.trim().isEmpty ? 'Live2D' : nameController.text.trim();
    await plugin.upsert(current);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
      setState(() {});
    }
  }

  Future<void> chooseOnlineModel() async {
    final model = await Navigator.of(context).push<Live2DModelDefinition>(
      MaterialPageRoute(builder: (_) => const Live2DOnlineModelPage()),
    );
    if (!mounted || model == null || archive == null) return;
    setState(() {
      archive!.modelLabel = model.label;
      archive!.modelDir = model.modelDir;
      archive!.modelFile = model.modelFile;
    });
  }

  Future<void> deleteCurrentArchive() async {
    final current = archive;
    if (current == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除存档'),
        content: Text('确定删除“${current.name}”吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    await plugin.deleteArchive(current.id);
    if (!mounted) return;
    setState(() {
      archive = plugin.selected;
      nameController.text = archive?.name ?? '';
    });
  }

  Live2DModelDefinition? modelFor(Live2DArchive? value) {
    if (value == null || value.modelLabel.isEmpty) return null;
    return availableJellyLive2DModels.where((model) => model.label == value.modelLabel).firstOrNull ??
        Live2DModelDefinition(label: value.modelLabel, modelDir: value.modelDir, modelFile: value.modelFile, motions: const [], isOnline: value.modelDir.startsWith('http'));
  }

  @override
  Widget build(BuildContext context) {
    final current = archive;
    final selectedAgent = agents.where((agent) => agent.id == current?.agentId).firstOrNull;
    final prompts = current?.personality.isNotEmpty == true
        ? current!.personality
        : (selectedAgent?.messages ?? [Prompt(type: 'system', content: '')]);

    return Scaffold(
      appBar: AppBar(title: const Text('Live2D 设置'), actions: [if (current != null) IconButton(onPressed: deleteCurrentArchive, icon: const Icon(Icons.delete_outline)), IconButton(onPressed: saveArchive, icon: const Icon(Icons.save))]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButton<String>(
            isExpanded: true,
            value: current?.id,
            hint: const Text('选择或创建 Live2D 存档'),
            items: [
              ...plugin.archives.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))),
              const DropdownMenuItem(value: '__new__', child: Text('创建新存档')),
            ],
            onChanged: selectArchive,
          ),
          if (current != null) ...[
            TextField(controller: nameController, decoration: const InputDecoration(labelText: '名称')),
            const SizedBox(height: 16),
            DropdownButtonFormField<Live2DModelDefinition>(
              value: availableJellyLive2DModels.where((model) => model.label == current.modelLabel).firstOrNull,
              decoration: const InputDecoration(labelText: 'Live2D 模型'),
              items: availableJellyLive2DModels.map((model) => DropdownMenuItem(value: model, child: Text(model.label))).toList(),
              onChanged: (model) { if (model != null) setState(() { current.modelLabel = model.label; current.modelDir = model.modelDir; current.modelFile = model.modelFile; }); },
            ),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: chooseOnlineModel, icon: const Icon(Icons.cloud_download), label: const Text('从在线模型仓库选择'))),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: current.agentId,
              decoration: const InputDecoration(labelText: '人格 Agent'),
              items: agents.map((agent) => DropdownMenuItem(value: agent.id, child: Text(agent.name))).toList(),
              onChanged: (value) => setState(() => current.agentId = value),
            ),
            const SizedBox(height: 16),
            PromptEditor(prompts: prompts, onPromptsChanged: (value) => current.personality = value),
            const SizedBox(height: 16),
            Text('模型：${current.modelLabel}'),
            const SizedBox(height: 8),
            SizedBox(height: 220, child: JellyLive2D(initialModel: modelFor(current))),
          ],
        ],
      ),
    );
  }
}
