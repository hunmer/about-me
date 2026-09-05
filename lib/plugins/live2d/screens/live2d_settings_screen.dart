import 'package:flutter/material.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/widgets/agent_list_drawer.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/plugins/tts/widgets/tts_settings_dialog.dart';
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
  bool _showPreview = false;
  late double _typingIntervalMs =
      (plugin.settings['typingIntervalMs'] as int? ??
              Live2DPlugin.defaultTypingIntervalMs)
          .toDouble();
  late bool _autoReadEnabled = plugin.autoReadEnabled;
  late String? _selectedTTSServiceId = plugin.ttsServiceId;
  TTSServiceConfig? _selectedTTSService;

  /// 向预览中的 JellyLive2D 发送动作播放请求（置空再赋值以便重复触发同一动作）
  final ValueNotifier<Live2DMotionDefinition?> _motionRequest =
      ValueNotifier<Live2DMotionDefinition?>(null);

  @override
  void initState() {
    super.initState();
    archive =
        plugin.selected ??
        (plugin.archives.isNotEmpty ? plugin.archives.first : null);
    if (archive != null) nameController.text = archive!.name;
    AgentController().loadAgents().then((value) {
      if (mounted) setState(() => agents = value);
    });
    _loadSelectedTTSService();
  }

  Future<void> _loadSelectedTTSService() async {
    try {
      final manager = TTSPlugin.instance.managerService;
      final service =
          _selectedTTSServiceId == null
              ? await manager.getDefaultService()
              : await manager.getServiceById(_selectedTTSServiceId!);
      if (mounted) setState(() => _selectedTTSService = service);
    } catch (error) {
      debugPrint('加载 Live2D 播报语音失败: $error');
    }
  }

  Future<void> _setAutoReadEnabled(bool enabled) async {
    setState(() => _autoReadEnabled = enabled);
    await plugin.updateSettings({'autoReadEnabled': enabled});
  }

  Future<void> _openTTSSettings() async {
    final result = await showTTSSettingsDialog(
      context,
      initialEnabled: _autoReadEnabled,
      initialServiceId: _selectedTTSServiceId,
    );
    if (!mounted || result == null) return;
    setState(() {
      _autoReadEnabled = result.enabled;
      _selectedTTSServiceId = result.serviceId;
    });
    await plugin.updateSettings({
      'autoReadEnabled': result.enabled,
      'ttsServiceId': result.serviceId,
    });
    await _loadSelectedTTSService();
  }

  String get _selectedVoiceLabel {
    final service = _selectedTTSService;
    if (service == null) {
      return _selectedTTSServiceId == null ? '使用默认语音' : '所选语音不可用';
    }
    final voice = service.voice ?? service.voiceId;
    return voice == null || voice.isEmpty
        ? service.name
        : '${service.name} · $voice';
  }

  @override
  void dispose() {
    _motionRequest.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> createArchive() async {
    if (_showPreview) setState(() => _showPreview = false);
    final created = Live2DArchive.create(
      modelLabel: 'Mao',
      modelDir: 'assets/models/mao/',
      modelFile: 'mao_pro.model3.json',
    );
    await plugin.upsert(created);
    setState(() {
      archive = created;
      nameController.text = created.name;
    });
  }

  Future<void> chooseAgent() async {
    // 原生 Live2D 平台视图不能跨底部抽屉导航保持挂载，先主动卸载。
    if (_showPreview) {
      setState(() => _showPreview = false);
      await Future<void>.delayed(Duration.zero);
    }
    final selected =
        archive?.agentId == null
            ? <Map<String, String>>[]
            : [
              {
                'id': archive!.agentId!,
                'name':
                    agents
                        .where((a) => a.id == archive!.agentId)
                        .firstOrNull
                        ?.name ??
                    '',
              },
            ];
    final result = await SmoothBottomSheet.show<List<Map<String, String>>>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => AgentListDrawer(
            selectedAgents: selected,
            allowMultipleSelection: false,
            onAgentSelected: (_) {},
          ),
    );
    if (!mounted || result == null || result.isEmpty || archive == null) return;
    setState(() => archive!.agentId = result.first['id']);
  }

  Future<void> saveArchive() async {
    final current = archive;
    if (current == null) return;
    current.name =
        nameController.text.trim().isEmpty
            ? 'Live2D'
            : nameController.text.trim();
    await plugin.upsert(current);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存')));
      setState(() {});
    }
  }

  Future<void> chooseOnlineModel() async {
    if (_showPreview) {
      setState(() => _showPreview = false);
      await Future<void>.delayed(Duration.zero);
    }
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
      builder:
          (context) => AlertDialog(
            title: const Text('删除存档'),
            content: Text('确定删除“${current.name}”吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
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

  Live2DModelDefinition? modelFor(Live2DArchive? value) =>
      modelDefinitionForArchive(value);

  @override
  Widget build(BuildContext context) {
    final current = archive;
    final selectedAgent =
        agents.where((agent) => agent.id == current?.agentId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live2D 设置'),
        actions: [
          if (current != null)
            IconButton(
              onPressed: deleteCurrentArchive,
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(onPressed: saveArchive, icon: const Icon(Icons.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Live2D 存档',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: createArchive,
                icon: const Icon(Icons.add),
                label: const Text('新建'),
              ),
            ],
          ),
          if (plugin.archives.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: plugin.archives.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final item = plugin.archives[index];
                  return ChoiceChip(
                    label: Text(item.name),
                    selected: item.id == current?.id,
                    onSelected: (_) {
                      if (_showPreview) _showPreview = false;
                      setState(() {
                        archive = item;
                        nameController.text = item.name;
                        plugin.selectedId = item.id;
                      });
                    },
                  );
                },
              ),
            ),
          if (current != null) ...[
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Live2D 模型'),
              subtitle: Text(current.modelLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (_showPreview) {
                  setState(() => _showPreview = false);
                  await Future<void>.delayed(Duration.zero);
                }
                final model = await showModalBottomSheet<Live2DModelDefinition>(
                  context: context,
                  builder:
                      (_) => ListView(
                        padding: const EdgeInsets.all(16),
                        children:
                            availableJellyLive2DModels
                                .map(
                                  (model) => ListTile(
                                    title: Text(model.label),
                                    onTap: () => Navigator.pop(context, model),
                                  ),
                                )
                                .toList(),
                      ),
                );
                if (model != null)
                  setState(() {
                    current.modelLabel = model.label;
                    current.modelDir = model.modelDir;
                    current.modelFile = model.modelFile;
                  });
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: chooseOnlineModel,
                icon: const Icon(Icons.cloud_download),
                label: const Text('从在线模型仓库选择'),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('人格 Agent'),
              subtitle: Text(selectedAgent?.name ?? '未选择'),
              trailing: const Icon(Icons.chevron_right),
              onTap: chooseAgent,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI 回复语音播报'),
              subtitle: const Text('回复完成后自动朗读'),
              value: _autoReadEnabled,
              onChanged: _setAutoReadEnabled,
            ),
            if (_autoReadEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.record_voice_over),
                title: const Text('播报语音'),
                subtitle: Text(_selectedVoiceLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openTTSSettings,
              ),
            const SizedBox(height: 16),
            Text('文字展示速度：${_typingIntervalMs.round()} 毫秒/字'),
            Slider(
              value: _typingIntervalMs,
              min: 20,
              max: 200,
              divisions: 18,
              label: '${_typingIntervalMs.round()} ms',
              onChanged: (value) => setState(() => _typingIntervalMs = value),
              onChangeEnd:
                  (value) => plugin.updateSettings({
                    'typingIntervalMs': value.round(),
                  }),
            ),
            const SizedBox(height: 16),
            Text('模型：${current.modelLabel}'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => setState(() => _showPreview = !_showPreview),
              icon: Icon(_showPreview ? Icons.stop : Icons.play_arrow),
              label: Text(_showPreview ? '卸载 Live2D' : '显示 Live2D'),
            ),
            if (_showPreview) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: JellyLive2D(
                  key: ValueKey('${current.modelDir}${current.modelFile}'),
                  initialModel: modelFor(current),
                  motionRequest: _motionRequest,
                  typingInterval: Duration(
                    milliseconds: _typingIntervalMs.round(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '动作列表（点击在预览中播放）',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if ((modelFor(current)?.motions ?? const []).isEmpty)
                const Text('当前模型没有可用动作')
              else
                for (final motion in modelFor(current)!.motions)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_arrow),
                    title: Text(
                      motion.hasSound ? '${motion.label}（语音）' : motion.label,
                    ),
                    onTap: () {
                      _motionRequest.value = null;
                      _motionRequest.value = motion;
                    },
                  ),
            ],
          ],
        ],
      ),
    );
  }
}
