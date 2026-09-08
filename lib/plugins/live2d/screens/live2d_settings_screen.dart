import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/live2d/live2d_plugin.dart';
import 'package:aboutme/plugins/live2d/models/live2d_archive.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/plugins/tts/widgets/tts_settings_dialog.dart';
import 'package:aboutme/screens/jelly_home/live2d_online_models.dart';
import 'package:aboutme/screens/jelly_home/widgets/jelly_live2d.dart';
import 'live2d_archive_form_screen.dart';

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
  late bool _autoReadEnabled = plugin.autoReadEnabled;
  late String? _selectedTTSServiceId = plugin.ttsServiceId;
  TTSServiceConfig? _selectedTTSService;

  /// 向预览中的 JellyLive2D 发送动作播放请求（置空再赋值以便重复触发同一动作）
  final ValueNotifier<Live2DMotionDefinition?> _motionRequest =
      ValueNotifier<Live2DMotionDefinition?>(null);

  @override
  void initState() {
    super.initState();
    archive = plugin.archives
            .where((a) => a.id == widget.initialArchiveId)
            .firstOrNull ??
        plugin.selected ??
        (plugin.archives.isNotEmpty ? plugin.archives.first : null);
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
    super.dispose();
  }

  Future<void> _editCurrentArchive() async {
    final id = plugin.selectedId;
    if (id == null) return;
    await NavigationHelper.push(
      context,
      Live2DArchiveFormScreen(archiveId: id),
    );
    if (mounted) {
      setState(() {
        archive = plugin.selected;
        _showPreview = false;
      });
    }
  }

  Live2DModelDefinition? modelFor(Live2DArchive? value) =>
      modelDefinitionForArchive(value);

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
                        plugin.selectedId = item.id;
                      });
                    },
                  );
                },
              ),
            ),
          if (current != null) ...[
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
              onChangeEnd:
                  (value) => plugin.updateSettings({
                    'typingIntervalMs': value.round(),
                  }),
            ),
            const SizedBox(height: 16),
            Text('live2d_modelLabel'.trParams({'model': current.modelLabel})),
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
              if ((modelFor(current)?.motions ?? const []).isEmpty)
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
