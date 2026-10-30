import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/plugins/tts/widgets/tts_settings_dialog.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_configurable_image.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'live2d_archive_form_screen.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// Live2D 全局设置：选中存档切换、语音播报、打字速度、模型预览。
/// 存档内容编辑（名称/模型/Agent/封面）在 [Live2DArchiveFormScreen]。
class Live2DSettingsScreen extends StatefulWidget {
  const Live2DSettingsScreen({super.key, this.initialArchiveId});

  /// 进入设置界面时定位到的存档 id，默认使用当前选中存档
  final String? initialArchiveId;

  @override
  State<Live2DSettingsScreen> createState() => _Live2DSettingsScreenState();
}

class _Live2DSettingsScreenState extends State<Live2DSettingsScreen> {
  final plugin = Live2DPlugin.instance;
  Live2DArchive? archive;
  bool _showPreview = false;
  late double _typingIntervalMs =
      (plugin.settings['typingIntervalMs'] as int? ??
              Live2DPlugin.defaultTypingIntervalMs)
          .toDouble();

  /// 语音设置统一存档绑定的 Agent 上
  AIAgent? _boundAgent;
  bool _autoReadEnabled = false;
  String? _selectedTTSServiceId;
  TTSServiceConfig? _selectedTTSService;

  /// 向预览中的 JellyLive2D 发送动作播放请求（置空再赋值以便重复触发同一动作）
  final ValueNotifier<String?> _videoAnimationRequest = ValueNotifier(null);
  final ValueNotifier<Live2DMotionDefinition?> _motionRequest =
      ValueNotifier<Live2DMotionDefinition?>(null);

  @override
  void initState() {
    super.initState();
    archive =
        plugin.archives
            .where((a) => a.id == widget.initialArchiveId)
            .firstOrNull ??
        plugin.selected ??
        (plugin.archives.isNotEmpty ? plugin.archives.first : null);
    _loadBoundAgent();
  }

  /// 加载当前存档绑定的 Agent 语音设置；未绑定时语音区不可用
  Future<void> _loadBoundAgent() async {
    _boundAgent = null;
    _autoReadEnabled = false;
    _selectedTTSServiceId = null;
    final agentId = archive?.agentId;
    if (agentId != null) {
      try {
        _boundAgent = await AgentController().getAgent(agentId);
      } catch (error) {
        debugPrint('加载存档绑定 Agent 失败: $error');
      }
    }
    if (_boundAgent != null) {
      _autoReadEnabled = _boundAgent!.ttsEnabled;
      _selectedTTSServiceId = _boundAgent!.ttsServiceId;
    }
    if (mounted) setState(() {});
    await _loadSelectedTTSService();
  }

  Future<void> _loadSelectedTTSService() async {
    try {
      final manager = TTSPlugin.instance.managerService;
      final service = _selectedTTSServiceId == null
          ? await manager.getDefaultService()
          : await manager.getServiceById(_selectedTTSServiceId!);
      if (mounted) setState(() => _selectedTTSService = service);
    } catch (error) {
      debugPrint('加载 Live2D 播报语音失败: $error');
    }
  }

  Future<void> _setAutoReadEnabled(bool enabled) async {
    final agent = _boundAgent;
    if (agent == null) {
      ToastService.instance.showToast('live2d_bindAgentFirst'.tr);
      return;
    }
    setState(() => _autoReadEnabled = enabled);
    await AgentController().updateAgent(agent.copyWith(ttsEnabled: enabled));
  }

  Future<void> _openTTSSettings() async {
    final agent = _boundAgent;
    if (agent == null) {
      ToastService.instance.showToast('live2d_bindAgentFirst'.tr);
      return;
    }
    final result = await showTTSSettingsDialog(
      context,
      agent: agent,
      initialEnabled: _autoReadEnabled,
      initialServiceId: _selectedTTSServiceId,
    );
    if (!mounted || result == null) return;
    setState(() {
      _autoReadEnabled = result.enabled;
      _selectedTTSServiceId = result.serviceId;
    });
    await AgentController().updateAgent(
      agent.copyWith(
        ttsEnabled: result.enabled,
        ttsServiceId: result.serviceId,
        clearTtsServiceId: result.serviceId == null,
      ),
    );
    await _loadSelectedTTSService();
  }

  String get _selectedVoiceLabel {
    final service = _selectedTTSService;
    if (service == null) {
      return _selectedTTSServiceId == null
          ? 'live2d_defaultVoice'.tr
          : 'live2d_voiceUnavailable'.tr;
    }
    final voice = service.voice ?? service.voiceId;
    return voice == null || voice.isEmpty
        ? service.name
        : '${service.name} · $voice';
  }

  @override
  void dispose() {
    _motionRequest.dispose();
    _videoAnimationRequest.dispose();
    super.dispose();
  }

  Future<void> _editCurrentArchive() async {
    final id = plugin.selectedId;
    if (id == null) return;
    VoidCallback? saveArchive;
    VoidCallback? deleteArchive;
    await SmoothBottomSheet.showForm(
      context: context,
      title: 'live2d_editArchiveTitle'.tr,
      child: Live2DArchiveFormScreen(
        archiveId: id,
        embedInSheet: true,
        onReady: (save) => saveArchive = save,
        onDeleteReady: (delete) => deleteArchive = delete,
      ),
      onSave: () => saveArchive?.call(),
      onDelete: () => deleteArchive?.call(),
    );
    if (mounted) {
      setState(() {
        archive = plugin.selected;
        _showPreview = false;
      });
    }
  }

  /// 上传/更换档案头像（复用 coverPath，1:1 裁剪保存到 live2d_covers）
  Future<void> _uploadAvatar(Live2DArchive item) async {
    final result = await ImagePickerDialog.show<Map<String, dynamic>>(
      context,
      initialUrl: item.coverPath,
      enableCrop: true,
      cropAspectRatio: 1,
    );
    final url = result?['url'] as String?;
    if (url == null || url.isEmpty) return;
    item.coverPath = url;
    await plugin.save();
    if (mounted) setState(() {});
  }

  Live2DModelDefinition? modelFor(Live2DArchive? value) =>
      modelDefinitionForArchive(value, importedModels: plugin.importedModels);

  @override
  Widget build(BuildContext context) {
    final current = archive;

    return Scaffold(
      appBar: AppBar(
        title: Text('live2d_settingsTitle'.tr),
        actions: [
          if (plugin.selectedId != null)
            IconButton(
              onPressed: _editCurrentArchive,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'live2d_editArchiveTitle'.tr,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'live2d_archivesSection'.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (plugin.archives.isNotEmpty)
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: plugin.archives.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final item = plugin.archives[index];
                  return _ArchiveAvatarTile(
                    archive: item,
                    selected: item.id == current?.id,
                    onSelect: () {
                      if (_showPreview) _showPreview = false;
                      setState(() {
                        archive = item;
                        plugin.selectedId = item.id;
                      });
                      _loadBoundAgent();
                    },
                    onUpload: () => _uploadAvatar(item),
                  );
                },
              ),
            ),
          if (current != null) ...[
            if (current.isVideo)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('随机走动'),
                subtitle: Text('当前档案（${current.name}）随机等待后水平走动，可拖拽调整位置'),
                value: current.randomWalkEnabled,
                onChanged: (value) {
                  plugin.setArchiveRandomWalkEnabled(current, value);
                  setState(() {});
                },
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('live2d_autoReadTitle'.tr),
              subtitle: Text('live2d_autoReadSubtitle'.tr),
              value: _autoReadEnabled,
              onChanged: _setAutoReadEnabled,
            ),
            if (_autoReadEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.record_voice_over),
                title: Text('live2d_voiceTitle'.tr),
                subtitle: Text(_selectedVoiceLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openTTSSettings,
              ),
            const SizedBox(height: 16),
            Text(
              'live2d_typingSpeed'.trParams({
                'ms': _typingIntervalMs.round().toString(),
              }),
            ),
            Slider(
              value: _typingIntervalMs,
              min: 20,
              max: 200,
              divisions: 18,
              label: '${_typingIntervalMs.round()} ms',
              onChanged: (value) => setState(() => _typingIntervalMs = value),
              onChangeEnd: (value) =>
                  plugin.updateSettings({'typingIntervalMs': value.round()}),
            ),
            const SizedBox(height: 16),
            Text(
              'live2d_modelLabel'.trParams({
                'model': current.displayModelLabel,
              }),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => setState(() => _showPreview = !_showPreview),
              icon: Icon(_showPreview ? Icons.stop : Icons.play_arrow),
              label: Text(
                _showPreview
                    ? 'live2d_hidePreview'.tr
                    : 'live2d_showPreview'.tr,
              ),
            ),
            if (_showPreview) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: JellyLive2D(
                  key: ValueKey('${current.modelDir}${current.modelFile}'),
                  initialModel: modelFor(current),
                  motionRequest: _motionRequest,
                  videoAnimationRequest: _videoAnimationRequest,
                  typingInterval: Duration(
                    milliseconds: _typingIntervalMs.round(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'live2d_motionList'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (current.isVideo)
                for (final animation
                    in current.videoManifest?.animations ?? const [])
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.play_arrow),
                    title: Text(animation.name),
                    onTap: () {
                      _videoAnimationRequest.value = null;
                      _videoAnimationRequest.value = animation.id;
                    },
                  )
              else if ((modelFor(current)?.motions ?? const []).isEmpty)
                Text('live2d_noMotions'.tr)
              else
                for (final motion in modelFor(current)!.motions)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_arrow),
                    title: Text(
                      motion.hasSound
                          ? 'screens_jellyLive2dMotionWithVoice'.trParams({
                              'label': motion.label.tr,
                            })
                          : motion.label.tr,
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

/// 档案头像列表项：圆形头像 + 名称，右下角相机角标上传/更换头像
class _ArchiveAvatarTile extends StatelessWidget {
  const _ArchiveAvatarTile({
    required this.archive,
    required this.selected,
    required this.onSelect,
    required this.onUpload,
  });

  final Live2DArchive archive;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = archive.coverPath;
    return GestureDetector(
      onTap: onSelect,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.dividerColor,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: cover == null || cover.isEmpty
                      ? Icon(
                          Icons.person_outline,
                          size: 26,
                          color: theme.hintColor,
                        )
                      : JellyConfigurableImage(path: cover, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: GestureDetector(
                  onTap: onUpload,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_camera,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              archive.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
