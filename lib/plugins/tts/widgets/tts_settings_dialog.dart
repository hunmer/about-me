import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/tts/tts_plugin.dart';
import 'package:aboutme/plugins/tts/models/tts_service_config.dart';
import 'package:aboutme/plugins/tts/models/tts_service_type.dart';

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

  const TTSSettingsDialog({
    super.key,
    this.initialEnabled = false,
    this.initialServiceId,
  });

  @override
  State<TTSSettingsDialog> createState() => _TTSSettingsDialogState();
}

class _TTSSettingsDialogState extends State<TTSSettingsDialog> {
  late bool _enabled;
  String? _selectedServiceId;
  List<TTSServiceConfig> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
    _selectedServiceId = widget.initialServiceId;
    _loadServices();
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

    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 拖拽指示器
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: theme.textSub.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
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
          ],
        ),
      ),
    );
  }

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
              ),
            ),
          ),
    ),
  );
}
