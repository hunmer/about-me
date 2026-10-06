import 'package:flutter/material.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/agent_schedule_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/chat_import_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/decision_log_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/memory_manager_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/widgets/jev_settings_dialog.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/models/tts_service_type.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';

/// Agent 编辑页的「活人感增强」配置分组：总开关 + 核心参数。
/// 通过 onChanged 回调同步给外部 state，随 agent 一起保存。
class AlivenessSettingsSection extends StatefulWidget {
  final AlivenessConfig config;
  final ValueChanged<AlivenessConfig> onChanged;
  final String? agentId;
  final String agentName;

  const AlivenessSettingsSection({
    super.key,
    required this.config,
    required this.onChanged,
    this.agentId,
    this.agentName = '',
  });

  @override
  State<AlivenessSettingsSection> createState() =>
      _AlivenessSettingsSectionState();
}

class _AlivenessSettingsSectionState extends State<AlivenessSettingsSection> {
  List<TTSServiceConfig> _ttsServices = [];

  @override
  void initState() {
    super.initState();
    _loadTtsServices();
  }

  Future<void> _loadTtsServices() async {
    try {
      final plugin = PluginManager.instance.getPlugin('tts');
      if (plugin is! TTSPlugin) return;
      final services = await plugin.managerService.getAllServices();
      if (mounted) {
        setState(() => _ttsServices = services);
      }
    } catch (_) {
      // TTS 插件未启用时选择器显示空列表
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome_outlined),
            title: const Text('活人感增强'),
            subtitle: const Text('开启后该 AI 会缓冲思考、分条回复、有节奏地聊天'),
            value: config.enabled,
            onChanged: (v) => widget.onChanged(config.copyWith(enabled: v)),
          ),
          if (config.enabled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  _buildSlider(
                    label: '惰性程度',
                    valueText: config.laziness.toStringAsFixed(1),
                    value: config.laziness,
                    min: 0,
                    max: 1,
                    divisions: 10,
                    onChanged:
                        (v) => widget.onChanged(config.copyWith(laziness: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Jev 拟人度评分与自动修订'),
                    subtitle: Text(
                      '低于 ${config.humanScoreThreshold}/3 时让模型重新生成一次',
                    ),
                    value: config.humanScoreEnabled,
                    onChanged:
                        (v) => widget.onChanged(
                          config.copyWith(humanScoreEnabled: v),
                        ),
                  ),
                  if (config.humanScoreEnabled)
                    _buildSlider(
                      label: '最低拟人度评分',
                      valueText: '${config.humanScoreThreshold}/3',
                      value: config.humanScoreThreshold.toDouble(),
                      min: 1,
                      max: 3,
                      divisions: 2,
                      onChanged:
                          (v) => widget.onChanged(
                            config.copyWith(humanScoreThreshold: v.round()),
                          ),
                    ),
                  _buildSlider(
                    label: '缓冲下限（秒）',
                    valueText: '${config.bufferMinSec}',
                    value: config.bufferMinSec.toDouble(),
                    min: 3,
                    max: 30,
                    divisions: 27,
                    onChanged: (v) {
                      final min = v.round();
                      widget.onChanged(
                        config.copyWith(
                          bufferMinSec: min,
                          bufferMaxSec: config.bufferMaxSec.clamp(min + 5, 600),
                        ),
                      );
                    },
                  ),
                  _buildSlider(
                    label: '缓冲上限（秒）',
                    valueText: '${config.bufferMaxSec}',
                    value: config.bufferMaxSec.toDouble(),
                    min: 10,
                    max: 120,
                    divisions: 22,
                    onChanged: (v) {
                      final max = v.round();
                      widget.onChanged(
                        config.copyWith(
                          bufferMaxSec: max,
                          bufferMinSec: config.bufferMinSec.clamp(1, max - 5),
                        ),
                      );
                    },
                  ),
                  _buildSlider(
                    label: '最大分条数',
                    valueText: '${config.maxBubbles}',
                    value: config.maxBubbles.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    onChanged:
                        (v) => widget.onChanged(
                          config.copyWith(maxBubbles: v.round()),
                        ),
                  ),
                  _buildSlider(
                    label: '分条最小间隔（毫秒）',
                    valueText: '${config.bubbleDelayMinMs}',
                    value: config.bubbleDelayMinMs.toDouble(),
                    min: 300,
                    max: 3000,
                    divisions: 27,
                    onChanged: (v) {
                      final min = v.round();
                      widget.onChanged(
                        config.copyWith(
                          bubbleDelayMinMs: min,
                          bubbleDelayMaxMs: config.bubbleDelayMaxMs.clamp(
                            min + 200,
                            10000,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildSlider(
                    label: '分条最大间隔（毫秒）',
                    valueText: '${config.bubbleDelayMaxMs}',
                    value: config.bubbleDelayMaxMs.toDouble(),
                    min: 1000,
                    max: 8000,
                    divisions: 35,
                    onChanged: (v) {
                      final max = v.round();
                      widget.onChanged(
                        config.copyWith(
                          bubbleDelayMaxMs: max,
                          bubbleDelayMinMs: config.bubbleDelayMinMs.clamp(
                            100,
                            max - 200,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 24),
                  // 语音消息
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('语音主动发送'),
                    subtitle: const Text('情绪浓时以语音形式追加回复（需配置支持合成的 TTS 服务）'),
                    value: config.voiceEnabled,
                    onChanged:
                        (v) =>
                            widget.onChanged(config.copyWith(voiceEnabled: v)),
                  ),
                  if (config.voiceEnabled) _buildTtsSelector(theme, config),
                  const Divider(height: 24),
                  // 主动消息
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('主动消息'),
                    subtitle: const Text('久未联系或待跟进事件到期时，AI 会主动来找你'),
                    value: config.proactiveEnabled,
                    onChanged:
                        (v) => widget.onChanged(
                          config.copyWith(proactiveEnabled: v),
                        ),
                  ),
                  if (config.proactiveEnabled) ...[
                    _buildSlider(
                      label: '主动消息冷却（分钟）',
                      valueText: '${config.proactiveCooldownMin}',
                      value: config.proactiveCooldownMin.toDouble(),
                      min: 15,
                      max: 360,
                      divisions: 23,
                      onChanged:
                          (v) => widget.onChanged(
                            config.copyWith(proactiveCooldownMin: v.round()),
                          ),
                    ),
                    _buildSlider(
                      label: '每日主动上限（条）',
                      valueText: '${config.proactiveDailyLimit}',
                      value: config.proactiveDailyLimit.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged:
                          (v) => widget.onChanged(
                            config.copyWith(proactiveDailyLimit: v.round()),
                          ),
                    ),
                    _buildQuietHoursRow(theme, config),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => showJevSettingsDialog(context),
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('决策模型'),
                      ),
                      TextButton.icon(
                        onPressed:
                            widget.agentId == null
                                ? null
                                : () => NavigationHelper.push(
                                  context,
                                  AgentScheduleScreen(
                                    agentId: widget.agentId!,
                                    agentName: widget.agentName,
                                  ),
                                ),
                        icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                        label: const Text('AI日程'),
                      ),
                      TextButton.icon(
                        onPressed:
                            widget.agentId == null
                                ? null
                                : () => NavigationHelper.push(
                                  context,
                                  ChatImportScreen(
                                    agentId: widget.agentId!,
                                    agentName: widget.agentName,
                                  ),
                                ),
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('分析聊天记录'),
                      ),
                      TextButton.icon(
                        onPressed:
                            widget.agentId == null
                                ? null
                                : () => NavigationHelper.push(
                                  context,
                                  MemoryManagerScreen(
                                    agentId: widget.agentId!,
                                    agentName: widget.agentName,
                                  ),
                                ),
                        icon: const Icon(Icons.psychology_alt, size: 16),
                        label: const Text('记忆管理'),
                      ),
                      TextButton.icon(
                        onPressed:
                            widget.agentId == null
                                ? null
                                : () => NavigationHelper.push(
                                  context,
                                  DecisionLogScreen(
                                    agentId: widget.agentId!,
                                    agentName: widget.agentName,
                                  ),
                                ),
                        icon: const Icon(Icons.receipt_long, size: 16),
                        label: const Text('决策日志'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 语音消息的 TTS 服务选择：system 类型只能当场播放、不支持合成文件，禁用并标注
  Widget _buildTtsSelector(ThemeData theme, AlivenessConfig config) {
    final selected = config.ttsServiceId;
    final validSelection =
        selected == null || _ttsServices.any((s) => s.id == selected);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text('语音声线（TTS）', style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: validSelection ? selected : null,
              hint:
                  _ttsServices.isEmpty
                      ? const Text('未找到 TTS 服务')
                      : const Text('跟随全局设置'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('跟随全局设置'),
                ),
                for (final s in _ttsServices)
                  DropdownMenuItem<String?>(
                    value: s.id,
                    enabled: s.type != TTSServiceType.system,
                    child: Text(
                      s.type == TTSServiceType.system
                          ? '${s.name}（不支持语音消息）'
                          : s.name,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            s.type == TTSServiceType.system
                                ? theme.disabledColor
                                : null,
                      ),
                    ),
                  ),
              ],
              onChanged:
                  (id) => widget.onChanged(config.copyWith(ttsServiceId: id)),
            ),
          ),
        ],
      ),
    );
  }

  /// 免打扰时段：起止小时下拉（支持跨午夜，如 23 → 8）
  Widget _buildQuietHoursRow(ThemeData theme, AlivenessConfig config) {
    final start = config.quietHours.isNotEmpty ? config.quietHours[0] : 23;
    final end = config.quietHours.length > 1 ? config.quietHours[1] : 8;
    Widget hourDropdown(int value, ValueChanged<int> onChanged) =>
        DropdownButton<int>(
          value: value.clamp(0, 23),
          items: [
            for (var h = 0; h < 24; h++)
              DropdownMenuItem(value: h, child: Text('$h 点')),
          ],
          onChanged: (h) => h != null && h != value ? onChanged(h) : null,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text('免打扰时段', style: theme.textTheme.bodyMedium),
          ),
          hourDropdown(
            start,
            (h) => widget.onChanged(config.copyWith(quietHours: [h, end])),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('至'),
          ),
          hourDropdown(
            end,
            (h) => widget.onChanged(config.copyWith(quietHours: [start, h])),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueText,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            valueText,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
