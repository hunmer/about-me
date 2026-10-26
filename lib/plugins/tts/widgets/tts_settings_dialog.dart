import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/models/tts_service_type.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';

/// TTS设置底部抽屉（smooth_sheets ModalSheet 底部弹出）
///
/// 用于配置TTS语音播报功能，包括：
/// - 是否启用自动朗读
/// - 选择TTS服务
class TTSSettingsDialog extends StatefulWidget {
  /// 初始是否启用自动朗读
  final bool initialEnabled;

  /// 初始选择的服务ID
  final String? initialServiceId;

  /// 关联的智能体：传入后在语音列表里标记其绑定的语音并作为默认选择
  final AIAgent? agent;

  const TTSSettingsDialog({
    super.key,
    this.initialEnabled = false,
    this.initialServiceId,
    this.agent,
  });

  @override
  State<TTSSettingsDialog> createState() => _TTSSettingsDialogState();
}

class _TTSSettingsDialogState extends State<TTSSettingsDialog> {
  late bool _enabled;
  String? _selectedServiceId;
  List<TTSServiceConfig> _services = [];
  bool _isLoading = true;

  /// 正在试听的服务ID
  String? _previewingServiceId;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
    // 未显式指定服务时，优先用 agent 绑定的语音作为默认选择
    _selectedServiceId = widget.initialServiceId ?? widget.agent?.ttsServiceId;
    _loadServices();
  }

  @override
  void dispose() {
    // 弹层关闭时停止试听
    if (_previewingServiceId != null) {
      TTSPlugin.instance.stop();
    }
    super.dispose();
  }

  /// 试听服务语音：再次点击同一服务则停止
  Future<void> _previewService(TTSServiceConfig service) async {
    try {
      await TTSPlugin.instance.stop();
      if (_previewingServiceId == service.id) {
        setState(() => _previewingServiceId = null);
        return;
      }
      setState(() => _previewingServiceId = service.id);
      await TTSPlugin.instance.speak(
        'tts_voiceTestText'.tr,
        serviceId: service.id,
        onComplete: () {
          if (mounted) setState(() => _previewingServiceId = null);
        },
        onError: (_) {
          if (mounted) setState(() => _previewingServiceId = null);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _previewingServiceId = null);
    }
  }

  /// 加载TTS服务列表
  Future<void> _loadServices() async {
    try {
      final ttsPlugin = TTSPlugin.instance;
      final services = await ttsPlugin.managerService.getAllServices();

      setState(() {
        _services = services;
        _isLoading = false;
      });

      // 如果没有选中的服务,自动选择默认服务
      if (_selectedServiceId == null && services.isNotEmpty) {
        final defaultService = services.firstWhere(
          (s) => s.isDefault,
          orElse: () => services.first,
        );
        setState(() {
          _selectedServiceId = defaultService.id;
        });
      }
    } catch (e) {
      debugPrint('加载TTS服务失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    // 大容器走手绘面板：纸底 + 淡排线 + 墨线框（与 TtsServiceForm 同款）
    return DsSketchPanel(
      theme: theme,
      width: double.infinity,
      radius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拽把手：纯色小条 + 淡墨描边（与 SmoothBottomSheet 同款）
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: theme.surfaceAlt,
                borderRadius: theme.radii.pill,
                border: Border.all(
                  color: theme.ink.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                DsIcon(DsIconKind.volumeUp, size: 20, color: theme.primary),
                const SizedBox(width: 8),
                Text(
                  'widget_voiceBroadcastSettings'.tr,
                  style: DsTypography.title.copyWith(
                    color: theme.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: DSLoadingDots(size: 12, color: theme.textSub),
              ),
            )
          else ...[
            // 内容区可滚动，服务多时不溢出
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 启用开关
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'widget_enableAutoRead'.tr,
                                  style: DsTypography.body.copyWith(
                                    color: theme.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'widget_autoReadAIMessage'.tr,
                                  style: DsTypography.caption.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DSSwitch(
                            value: _enabled,
                            onChanged: (value) {
                              setState(() {
                                _enabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // 服务选择
                    if (_enabled && _services.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Text(
                          'widget_selectTTSService'.tr,
                          style: DsTypography.body.copyWith(
                            color: theme.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      for (final service in _services)
                        _buildServiceRow(context, service),
                    ],

                    // 无可用服务提示
                    if (_enabled && _services.isEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: dsSketchDecoration(
                          theme: theme,
                          radius: BorderRadius.circular(12),
                          fillColor: theme.hatch,
                        ),
                        child: Row(
                          children: [
                            DsIcon(
                              DsIconKind.info,
                              size: 20,
                              color: theme.danger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'widget_noTTSServiceAvailable'.tr,
                                style: DsTypography.caption.copyWith(
                                  color: theme.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // 操作按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: DSButton(
                      label: 'widget_cancel'.tr,
                      variant: DSButtonVariant.outline,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DSButton(
                      label: 'widget_confirm'.tr,
                      onPressed: () {
                        final result = TTSSettingsResult(
                          enabled: _enabled,
                          serviceId: _selectedServiceId,
                        );
                        Navigator.of(context).pop(result);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          // 底部安全区
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  /// 该服务是否为当前 agent 绑定的语音
  bool _isAgentBoundService(TTSServiceConfig service) =>
      widget.agent != null && service.id == widget.agent!.ttsServiceId;

  /// 服务选择行：名称 + 默认徽章 + 类型说明 + 单选框
  Widget _buildServiceRow(BuildContext context, TTSServiceConfig service) {
    final theme = DSThemeBridge.resolve(context);
    final disabled = !service.isEnabled;

    return Pressable(
      onPressed:
          disabled
              ? null
              : () => setState(() => _selectedServiceId = service.id),
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: pressed ? theme.surfaceAlt : null,
          child: Opacity(
            opacity: disabled ? 0.5 : 1,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              service.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsTypography.body.copyWith(
                                color: theme.text,
                              ),
                            ),
                          ),
                          if (service.isDefault) ...[
                            const SizedBox(width: 8),
                            DSBadge(
                              label: 'widget_defaultLabel'.tr,
                              fontSize: 10,
                            ),
                          ],
                          if (_isAgentBoundService(service)) ...[
                            const SizedBox(width: 8),
                            DSBadge(
                              label: 'tts_currentAgentVoice'.tr,
                              fontSize: 10,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getServiceTypeText(service),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                DSIconButton(
                  icon: _previewingServiceId == service.id
                      ? DsIconKind.stop
                      : DsIconKind.play,
                  size: 34,
                  color: theme.primary,
                  iconColor: theme.onPrimary,
                  onPressed: disabled
                      ? null
                      : () => _previewService(service),
                  tooltip: 'tts_preview'.tr,
                ),
                const SizedBox(width: 8),
                DSRadio<String>(
                  value: service.id,
                  groupValue: _selectedServiceId,
                  onChanged:
                      disabled
                          ? null
                          : (value) {
                            setState(() {
                              _selectedServiceId = value;
                            });
                          },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 获取服务类型文本
  String _getServiceTypeText(TTSServiceConfig service) {
    String typeText = service.type.displayName;
    if (!service.isEnabled) {
      typeText += 'widget_disabled'.tr;
    }
    if (service.voice != null && service.voice!.isNotEmpty) {
      typeText += ' · ${service.voice}';
    }
    return typeText;
  }
}

/// TTS设置结果
class TTSSettingsResult {
  /// 是否启用自动朗读
  final bool enabled;

  /// 选择的服务ID
  final String? serviceId;

  const TTSSettingsResult({required this.enabled, this.serviceId});
}

/// 显示TTS设置底部抽屉的便捷方法（smooth_sheets ModalSheet 底部弹出）
///
/// 返回 [TTSSettingsResult] 或 null (如果用户取消)
Future<TTSSettingsResult?> showTTSSettingsDialog(
  BuildContext context, {
  bool initialEnabled = false,
  String? initialServiceId,
  AIAgent? agent,
}) {
  return Navigator.of(context).push<TTSSettingsResult>(
    ModalSheetRoute(
      swipeDismissible: true,
      builder:
          (context) => Sheet(
            // Sheet 路由在主题树之外，先过桥再取令牌
            child: DSThemeBridge(
              child: TTSSettingsDialog(
                initialEnabled: initialEnabled,
                initialServiceId: initialServiceId,
                agent: agent,
              ),
            ),
          ),
    ),
  );
}
