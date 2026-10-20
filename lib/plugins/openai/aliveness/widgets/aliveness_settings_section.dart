import 'package:flutter/material.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/agent_schedule_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/chat_import_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/decision_log_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/memory_manager_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/widgets/jev_settings_dialog.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/models/tts_service_type.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';

import 'package:get/get.dart';

/// Agent 编辑页的「活人感增强」配置分组：总开关 + 核心参数。
/// 通过 onChanged 回调同步给外部 state，随 agent 一起保存。
/// 手绘风（design.md §9）：DsSketchPanel 大容器 + DSSwitch/DSSlider/DSSelect，
/// 配色经 DSThemeBridge 取自主题。
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
    final theme = DSThemeBridge.resolve(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.xl,
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _switchRow(
              theme,
              icon: DsIconKind.sparkle,
              title: 'openai_alivenessEnhance'.tr,
              subtitle: 'openai_alivenessEnhanceDesc'.tr,
              value: config.enabled,
              onChanged: (v) => widget.onChanged(config.copyWith(enabled: v)),
            ),
            if (config.enabled) ...[
              _sliderRow(
                theme,
                label: 'openai_alivenessLaziness'.tr,
                valueText: config.laziness.toStringAsFixed(1),
                value: config.laziness,
                min: 0,
                max: 1,
                onChanged: (v) =>
                    widget.onChanged(config.copyWith(laziness: v)),
              ),
              _switchRow(
                theme,
                title: 'openai_jevScoreAutoRevise'.tr,
                subtitle: 'openai_jevScoreThresholdDesc'.trParams({
                  'score': '${config.humanScoreThreshold}',
                }),
                value: config.humanScoreEnabled,
                onChanged: (v) => widget.onChanged(
                  config.copyWith(humanScoreEnabled: v),
                ),
              ),
              if (config.humanScoreEnabled)
                _sliderRow(
                  theme,
                  label: 'openai_minHumanScore'.tr,
                  valueText: '${config.humanScoreThreshold}/3',
                  value: config.humanScoreThreshold.toDouble(),
                  min: 1,
                  max: 3,
                  onChanged: (v) => widget.onChanged(
                    config.copyWith(humanScoreThreshold: v.round()),
                  ),
                ),
              _infoRow(
                theme,
                icon: DsIconKind.timer,
                title: 'openai_messageBuffer'.tr,
                subtitle: 'openai_messageBufferDesc'.tr,
              ),
              _sliderRow(
                theme,
                label: 'openai_maxBubbles'.tr,
                valueText: '${config.maxBubbles}',
                value: config.maxBubbles.toDouble(),
                min: 1,
                max: 5,
                onChanged: (v) => widget.onChanged(
                  config.copyWith(maxBubbles: v.round()),
                ),
              ),
              _sliderRow(
                theme,
                label: 'openai_bubbleDelayMin'.tr,
                valueText: '${config.bubbleDelayMinMs}',
                value: config.bubbleDelayMinMs.toDouble(),
                min: 300,
                max: 3000,
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
              _sliderRow(
                theme,
                label: 'openai_bubbleDelayMax'.tr,
                valueText: '${config.bubbleDelayMaxMs}',
                value: config.bubbleDelayMaxMs.toDouble(),
                min: 1000,
                max: 8000,
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
              SizedBox(height: theme.spacing.md),
              // 语音消息
              _switchRow(
                theme,
                title: 'openai_voiceProactiveSend'.tr,
                subtitle: 'openai_voiceProactiveSendDesc'.tr,
                value: config.voiceEnabled,
                onChanged: (v) =>
                    widget.onChanged(config.copyWith(voiceEnabled: v)),
              ),
              if (config.voiceEnabled) _buildTtsSelector(theme, config),
              SizedBox(height: theme.spacing.md),
              // 主动消息
              _switchRow(
                theme,
                title: 'openai_proactiveMessages'.tr,
                subtitle: 'openai_proactiveMessagesDesc'.tr,
                value: config.proactiveEnabled,
                onChanged: (v) =>
                    widget.onChanged(config.copyWith(proactiveEnabled: v)),
              ),
              if (config.proactiveEnabled) ...[
                _sliderRow(
                  theme,
                  label: 'openai_proactiveCooldown'.tr,
                  valueText: '${config.proactiveCooldownMin}',
                  value: config.proactiveCooldownMin.toDouble(),
                  min: 15,
                  max: 360,
                  onChanged: (v) => widget.onChanged(
                    config.copyWith(proactiveCooldownMin: v.round()),
                  ),
                ),
                _sliderRow(
                  theme,
                  label: 'openai_proactiveDailyLimit'.tr,
                  valueText: '${config.proactiveDailyLimit}',
                  value: config.proactiveDailyLimit.toDouble(),
                  min: 1,
                  max: 10,
                  onChanged: (v) => widget.onChanged(
                    config.copyWith(proactiveDailyLimit: v.round()),
                  ),
                ),
                _buildQuietHoursRow(theme, config),
              ],
              SizedBox(height: theme.spacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  DSButton(
                    label: 'openai_decisionModel'.tr,
                    size: DSButtonSize.sm,
                    variant: DSButtonVariant.outline,
                    icon: DsIconKind.tune,
                    onPressed: () => showJevSettingsDialog(context),
                  ),
                  DSButton(
                    label: 'openai_aiSchedule'.tr,
                    size: DSButtonSize.sm,
                    variant: DSButtonVariant.outline,
                    icon: DsIconKind.sun,
                    onPressed: widget.agentId == null
                        ? null
                        : () => NavigationHelper.push(
                            context,
                            AgentScheduleScreen(
                              agentId: widget.agentId!,
                              agentName: widget.agentName,
                            ),
                          ),
                  ),
                  DSButton(
                    label: 'openai_analyzeChatHistory'.tr,
                    size: DSButtonSize.sm,
                    variant: DSButtonVariant.outline,
                    icon: DsIconKind.upload,
                    onPressed: widget.agentId == null
                        ? null
                        : () => NavigationHelper.push(
                            context,
                            ChatImportScreen(
                              agentId: widget.agentId!,
                              agentName: widget.agentName,
                            ),
                          ),
                  ),
                  DSButton(
                    label: 'openai_decisionLog'.tr,
                    size: DSButtonSize.sm,
                    variant: DSButtonVariant.outline,
                    icon: DsIconKind.list,
                    onPressed: widget.agentId == null
                        ? null
                        : () => NavigationHelper.push(
                            context,
                            DecisionLogScreen(
                              agentId: widget.agentId!,
                              agentName: widget.agentName,
                            ),
                          ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
            ],
            // 记忆管理独立开关：不依赖活人感增强，单独开启即生效
            _switchRow(
              theme,
              icon: DsIconKind.storage,
              title: 'openai_memoryManagement'.tr,
              subtitle: 'openai_memoryManagementDesc'.tr,
              value: config.memoryEnabled,
              onChanged: (v) =>
                  widget.onChanged(config.copyWith(memoryEnabled: v)),
            ),
            if (config.memoryEnabled)
              Padding(
                padding: EdgeInsets.only(left: theme.spacing.sm + 28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DSButton(
                    label: 'openai_memoryManagement'.tr,
                    size: DSButtonSize.sm,
                    variant: DSButtonVariant.outline,
                    icon: DsIconKind.storage,
                    onPressed: widget.agentId == null
                        ? null
                        : () => NavigationHelper.push(
                            context,
                            MemoryManagerScreen(
                              agentId: widget.agentId!,
                              agentName: widget.agentName,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 开关行：图标（可选）+ 标题/副标题 + 手绘开关
  Widget _switchRow(
    AppThemeData theme, {
    DsIconKind? icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        children: [
          if (icon != null) ...[
            DsIcon(icon, size: 20, color: theme.textSub),
            SizedBox(width: theme.spacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: DsTypography.caption.copyWith(
                      color: theme.textSub,
                    ),
                  ),
                ],
              ],
            ),
          ),
          DSSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// 纯说明行：图标 + 标题/副标题
  Widget _infoRow(
    AppThemeData theme, {
    required DsIconKind icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        children: [
          DsIcon(icon, size: 20, color: theme.textSub),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 手绘滑杆行：标签 + DSSlider（归一化）+ 当前值
  Widget _sliderRow(
    AppThemeData theme, {
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final clamped = value.clamp(min, max);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: DsTypography.body.copyWith(color: theme.text),
            ),
          ),
          Expanded(
            child: DSSlider(
              value: max > min ? (clamped - min) / (max - min) : 0,
              onChanged: (r) => onChanged(min + r * (max - min)),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              valueText,
              textAlign: TextAlign.end,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ),
        ],
      ),
    );
  }

  /// 语音消息的 TTS 服务选择：system 类型只能当场播放、不支持合成文件，
  /// 列表中标注说明，选中时拦截并提示
  Widget _buildTtsSelector(AppThemeData theme, AlivenessConfig config) {
    final selected = config.ttsServiceId;
    final validSelection =
        selected == null || _ttsServices.any((s) => s.id == selected);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(
              'openai_ttsVoice'.tr,
              style: DsTypography.body.copyWith(color: theme.text),
            ),
          ),
          Expanded(
            child: DSSelect<String?>(
              width: double.infinity,
              value: validSelection ? selected : null,
              hint: _ttsServices.isEmpty
                  ? 'openai_ttsServiceNotFound'.tr
                  : 'openai_followGlobalSettings'.tr,
              items: [
                DSSelectItem<String?>(
                  value: null,
                  label: 'openai_followGlobalSettings'.tr,
                ),
                for (final s in _ttsServices)
                  DSSelectItem<String?>(
                    value: s.id,
                    label: s.type == TTSServiceType.system
                        ? 'openai_ttsNotSupportedSuffix'.trParams({
                            'name': s.name,
                          })
                        : s.name,
                  ),
              ],
              onChanged: (id) {
                final service = _ttsServices
                    .where((s) => s.id == id)
                    .firstOrNull;
                if (service != null && service.type == TTSServiceType.system) {
                  ToastService.instance.showToast(
                    'openai_ttsSystemUnsupported'.tr,
                  );
                  // 拒绝变更后强制刷新，恢复触发框显示原选中项
                  setState(() {});
                  return;
                }
                widget.onChanged(config.copyWith(ttsServiceId: id));
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 免打扰时段：起止小时选择（支持跨午夜，如 23 → 8）
  Widget _buildQuietHoursRow(AppThemeData theme, AlivenessConfig config) {
    final start = config.quietHours.isNotEmpty ? config.quietHours[0] : 23;
    final end = config.quietHours.length > 1 ? config.quietHours[1] : 8;
    Widget hourSelect(int value, ValueChanged<int> onChanged) => DSSelect<int>(
      width: double.infinity,
      value: value.clamp(0, 23),
      items: [
        for (var h = 0; h < 24; h++)
          DSSelectItem(
            value: h,
            label: 'openai_hourUnit'.trParams({'h': '$h'}),
          ),
      ],
      onChanged: (h) => h != value ? onChanged(h) : null,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(
              'openai_quietHours'.tr,
              style: DsTypography.body.copyWith(color: theme.text),
            ),
          ),
          Expanded(
            child: hourSelect(
              start,
              (h) => widget.onChanged(config.copyWith(quietHours: [h, end])),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'openai_quietHoursTo'.tr,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ),
          Expanded(
            child: hourSelect(
              end,
              (h) => widget.onChanged(config.copyWith(quietHours: [start, h])),
            ),
          ),
        ],
      ),
    );
  }
}
