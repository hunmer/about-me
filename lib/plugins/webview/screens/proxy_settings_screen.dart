import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/proxy_settings.dart';
import '../webview_plugin.dart';

/// Proxy 代理设置界面（Android 专用）
class ProxySettingsScreen extends StatefulWidget {
  const ProxySettingsScreen({super.key});

  @override
  State<ProxySettingsScreen> createState() => _ProxySettingsScreenState();
}

class _ProxySettingsScreenState extends State<ProxySettingsScreen> {
  late ProxySettings _proxySettings;
  late bool _enabled;
  late List<ProxyRule> _proxyRules;
  late List<String> _bypassRules;
  late bool _reverseBypass;

  @override
  void initState() {
    super.initState();
    _proxySettings = WebViewPlugin.instance.webviewSettings.proxySettings;
    _enabled = _proxySettings.enabled;
    _proxyRules = List.from(_proxySettings.proxyRules);
    _bypassRules = List.from(_proxySettings.bypassRules);
    _reverseBypass = _proxySettings.reverseBypassEnabled;
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold/AppBar 属结构性组件,刻意保留 Material
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            backgroundColor: dsScaffoldBackground(theme),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 顶行：返回 / 标题 / 保存（design.md §2.1 轻量手绘顶栏）
                  DSLightHeader(
                    title: 'webview_proxy_settings'.tr,
                    trailing: DSIconButton(
                      icon: DsIconKind.check,
                      size: 38,
                      color: theme.surface,
                      iconColor: theme.text,
                      onPressed: _saveSettings,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 平台提示
                        JellyBox(
                          radius: theme.radii.lg,
                          raised: false,
                          padding: EdgeInsets.all(theme.spacing.lg),
                          strokeColor: theme.warning,
                          child: Row(
                            children: [
                              DsIcon(
                                DsIconKind.info,
                                size: 20,
                                color: theme.warning,
                              ),
                              SizedBox(width: theme.spacing.md),
                              Expanded(
                                child: Text(
                                  'webview_proxy_android_only'.tr,
                                  style: DsTypography.body.copyWith(
                                    color: theme.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 启用开关
                        _buildSwitchRow(
                          theme: theme,
                          title: 'webview_proxy_enable'.tr,
                          subtitle: 'webview_proxy_enable_desc'.tr,
                          value: _enabled,
                          onChanged: (value) {
                            setState(() {
                              _enabled = value;
                            });
                          },
                        ),

                        _buildDivider(theme),

                        // Proxy 规则列表
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'webview_proxy_rules'.tr,
                              style: DsTypography.heading.copyWith(
                                color: theme.text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            DSIconButton(
                              icon: DsIconKind.plus,
                              size: 40,
                              color: theme.surfaceAlt,
                              iconColor: theme.textSub,
                              onPressed: _enabled ? _addProxyRule : null,
                              tooltip: 'webview_proxy_add_rule'.tr,
                            ),
                          ],
                        ),

                        if (_proxyRules.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'webview_proxy_no_rules'.tr,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ..._proxyRules.asMap().entries.map((entry) {
                            final index = entry.key;
                            final rule = entry.value;
                            final subtitle = _buildRuleSubtitleText(rule);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: DSCard(
                                padding: EdgeInsets.symmetric(
                                  horizontal: theme.spacing.md,
                                  vertical: theme.spacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            rule.url,
                                            style: DsTypography.body.copyWith(
                                              color: theme.text,
                                            ),
                                          ),
                                          if (subtitle != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              subtitle,
                                              style: DsTypography.caption
                                                  .copyWith(
                                                    color: theme.textSub,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    DSIconButton(
                                      icon: DsIconKind.edit,
                                      size: 36,
                                      color: theme.surfaceAlt,
                                      iconColor: theme.textSub,
                                      onPressed: _enabled
                                          ? () => _editProxyRule(index, rule)
                                          : null,
                                    ),
                                    DSIconButton(
                                      icon: DsIconKind.trash,
                                      size: 36,
                                      color: theme.danger,
                                      iconColor: theme.onDanger,
                                      onPressed: _enabled
                                          ? () => setState(() {
                                              _proxyRules.removeAt(index);
                                            })
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                        const SizedBox(height: 16),
                        _buildDivider(theme),

                        // 绕过规则
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'webview_proxy_bypass_rules'.tr,
                              style: DsTypography.heading.copyWith(
                                color: theme.text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            DSIconButton(
                              icon: DsIconKind.plus,
                              size: 40,
                              color: theme.surfaceAlt,
                              iconColor: theme.textSub,
                              onPressed: _enabled ? _addBypassRule : null,
                              tooltip: 'webview_proxy_add_bypass_rule'.tr,
                            ),
                          ],
                        ),

                        if (_bypassRules.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'webview_proxy_no_bypass_rules'.tr,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ..._bypassRules.asMap().entries.map((entry) {
                            final index = entry.key;
                            final rule = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: DSCard(
                                padding: EdgeInsets.symmetric(
                                  horizontal: theme.spacing.md,
                                  vertical: theme.spacing.sm + 2,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rule,
                                        style: DsTypography.body.copyWith(
                                          color: theme.text,
                                        ),
                                      ),
                                    ),
                                    DSIconButton(
                                      icon: DsIconKind.trash,
                                      size: 36,
                                      color: theme.danger,
                                      iconColor: theme.onDanger,
                                      onPressed: _enabled
                                          ? () => setState(() {
                                              _bypassRules.removeAt(index);
                                            })
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                        const SizedBox(height: 16),

                        // 反转绕过规则
                        _buildSwitchRow(
                          theme: theme,
                          title: 'webview_proxy_reverse_bypass'.tr,
                          subtitle: 'webview_proxy_reverse_bypass_desc'.tr,
                          value: _reverseBypass,
                          onChanged: _enabled
                              ? (value) {
                                  setState(() {
                                    _reverseBypass = value;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 开关行(SwitchListTile 的 DS 替代)
  Widget _buildSwitchRow({
    required AppThemeData theme,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: DsTypography.body.copyWith(color: theme.text),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacing.md),
          DSSwitch(value: value, onChanged: onChanged, semanticLabel: title),
        ],
      ),
    );
  }

  Widget _buildDivider(AppThemeData theme) => Container(
    height: 1,
    margin: EdgeInsets.symmetric(vertical: theme.spacing.md),
    color: theme.stroke,
  );

  String? _buildRuleSubtitleText(ProxyRule rule) {
    final filters = <String>[];
    if (rule.schemeFilter != null) filters.add('scheme=${rule.schemeFilter}');
    if (rule.hostFilter != null) filters.add('host=${rule.hostFilter}');
    if (rule.portFilter != null) filters.add('port=${rule.portFilter}');
    if (rule.pathFilter != null) filters.add('path=${rule.pathFilter}');

    if (filters.isEmpty) return null;
    return filters.join(', ');
  }

  void _addProxyRule() {
    _showProxyRuleDialog();
  }

  void _editProxyRule(int index, ProxyRule rule) {
    _showProxyRuleDialog(index: index, rule: rule);
  }

  void _showProxyRuleDialog({int? index, ProxyRule? rule}) {
    final urlController = TextEditingController(text: rule?.url ?? '');
    final schemeController = TextEditingController(
      text: rule?.schemeFilter ?? '',
    );
    final hostController = TextEditingController(text: rule?.hostFilter ?? '');
    final portController = TextEditingController(
      text: rule?.portFilter?.toString() ?? '',
    );
    final pathController = TextEditingController(text: rule?.pathFilter ?? '');

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return JellyBox(
              radius: theme.radii.xxl,
              padding: EdgeInsets.all(theme.spacing.xl),
              constraints: const BoxConstraints(maxWidth: 380),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      index == null
                          ? 'webview_proxy_add_rule'.tr
                          : 'webview_proxy_edit_rule'.tr,
                      textAlign: TextAlign.center,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    SizedBox(height: theme.spacing.lg),
                    DSInput(
                      controller: urlController,
                      label: 'webview_proxy_url'.tr,
                      hint: 'http://proxy.example.com:8080',
                    ),
                    SizedBox(height: theme.spacing.md),
                    DSAccordion(
                      initialExpanded: const [],
                      entries: [
                        DSAccordionEntry(
                          title: 'webview_proxy_filters'.tr,
                          builder: (context) {
                            final innerTheme = DSThemeBridge.resolve(context);
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'webview_proxy_filters_optional'.tr,
                                  style: DsTypography.caption.copyWith(
                                    color: innerTheme.textSub,
                                  ),
                                ),
                                SizedBox(height: innerTheme.spacing.xs),
                                Text(
                                  'webview_proxy_filters_note'.tr,
                                  style: DsTypography.caption.copyWith(
                                    color: innerTheme.warning,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                SizedBox(height: innerTheme.spacing.md),
                                DSInput(
                                  controller: schemeController,
                                  label: 'webview_proxy_scheme_filter'.tr,
                                  hint: 'http / https',
                                ),
                                SizedBox(height: innerTheme.spacing.sm),
                                DSInput(
                                  controller: hostController,
                                  label: 'webview_proxy_host_filter'.tr,
                                  hint: 'example.com',
                                ),
                                SizedBox(height: innerTheme.spacing.sm),
                                DSInput(
                                  controller: portController,
                                  label: 'webview_proxy_port_filter'.tr,
                                  hint: '8080',
                                  keyboardType: TextInputType.number,
                                ),
                                SizedBox(height: innerTheme.spacing.sm),
                                DSInput(
                                  controller: pathController,
                                  label: 'webview_proxy_path_filter'.tr,
                                  hint: '/api/*',
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: theme.spacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: 'app_cancel'.tr,
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                        SizedBox(width: theme.spacing.md),
                        Expanded(
                          child: DSButton(
                            label: 'app_save'.tr,
                            onPressed: () {
                              if (urlController.text.trim().isEmpty) {
                                Toast.warning('webview_proxy_url_required'.tr);
                                return;
                              }

                              final newRule = ProxyRule(
                                url: urlController.text.trim(),
                                schemeFilter:
                                    schemeController.text.trim().isNotEmpty
                                    ? schemeController.text.trim()
                                    : null,
                                hostFilter:
                                    hostController.text.trim().isNotEmpty
                                    ? hostController.text.trim()
                                    : null,
                                portFilter:
                                    portController.text.trim().isNotEmpty
                                    ? int.tryParse(portController.text.trim())
                                    : null,
                                pathFilter:
                                    pathController.text.trim().isNotEmpty
                                    ? pathController.text.trim()
                                    : null,
                              );

                              setState(() {
                                if (index == null) {
                                  _proxyRules.add(newRule);
                                } else {
                                  _proxyRules[index] = newRule;
                                }
                              });

                              Navigator.of(dialogContext).pop();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _addBypassRule() {
    final controller = TextEditingController();

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) => DSThemeBridge(
        child: Builder(
          builder: (context) {
            return DSDialog(
              title: 'webview_proxy_add_bypass_rule'.tr,
              content: DSInput(
                controller: controller,
                label: 'webview_proxy_bypass_pattern'.tr,
                hint: 'example.com, *.excluded.com',
              ),
              confirmText: 'app_save'.tr,
              cancelText: 'app_cancel'.tr,
              onConfirm: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _bypassRules.add(controller.text.trim());
                  });
                  Navigator.of(dialogContext).pop();
                }
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    final newProxySettings = ProxySettings(
      enabled: _enabled,
      proxyRules: _proxyRules,
      bypassRules: _bypassRules,
      reverseBypassEnabled: _reverseBypass,
    );

    final plugin = WebViewPlugin.instance;
    plugin.webviewSettings = plugin.webviewSettings.copyWith(
      proxySettings: newProxySettings,
    );

    await plugin.saveWebviewSettings();

    if (mounted) {
      Toast.success('webview_proxy_settings_saved'.tr);
      Navigator.pop(context);
    }
  }
}
