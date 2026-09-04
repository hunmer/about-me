import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../webview_plugin.dart';
import 'proxy_settings_screen.dart';

/// WebView 设置界面
class WebViewSettingsScreen extends StatefulWidget {
  const WebViewSettingsScreen({super.key});

  @override
  State<WebViewSettingsScreen> createState() => _WebViewSettingsScreenState();
}

class _WebViewSettingsScreenState extends State<WebViewSettingsScreen> {
  late bool _enableJavaScript;
  late bool _enableJSBridge;
  late bool _blockPopups;
  late bool _enableZoom;
  late bool _saveHistory;
  late bool _restoreTabsOnStartup;
  late bool _blockDeepLinks;
  late int _maxTabs;
  late String _userAgent;
  late String _defaultSearchEngine;
  late String _homePage;

  @override
  void initState() {
    super.initState();
    final settings = WebViewPlugin.instance.webviewSettings;
    _enableJavaScript = settings.enableJavaScript;
    _enableJSBridge = settings.enableJSBridge;
    _blockPopups = settings.blockPopups;
    _enableZoom = settings.enableZoom;
    _saveHistory = settings.saveHistory;
    _restoreTabsOnStartup = settings.restoreTabsOnStartup;
    _blockDeepLinks = settings.blockDeepLinks;
    _maxTabs = settings.maxTabs;
    _userAgent = settings.userAgent;
    _defaultSearchEngine = settings.defaultSearchEngine;
    _homePage = settings.homePage;
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold/AppBar 属结构性组件,刻意保留 Material
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            appBar: AppBar(
              title: Text('webview_settings_title'.tr),
              actions: [
                // DS 按钮自带 DSThemeBridge 提供 AppTheme
                DSThemeBridge(
                  child: Builder(
                    builder: (context) {
                      final theme = DSThemeBridge.resolve(context);
                      return DSIconButton(
                        icon: DsIconKind.check,
                        size: 40,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: _saveSettings,
                        tooltip:
                            MaterialLocalizations.of(context).saveButtonLabel,
                      );
                    },
                  ),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 基础设置
                _buildSectionTitle(theme, 'webview_settings_basic'.tr),
                const SizedBox(height: 8),

                // JavaScript 开关
                _buildSwitchRow(
                  theme: theme,
                  title: 'webview_settings_enable_js'.tr,
                  subtitle: 'webview_settings_enable_js_desc'.tr,
                  value: _enableJavaScript,
                  onChanged: (value) {
                    setState(() {
                      _enableJavaScript = value;
                    });
                  },
                ),

                // JS Bridge 开关
                _buildSwitchRow(
                  theme: theme,
                  title: 'webview_settings_enable_jsbridge'.tr,
                  subtitle: 'webview_settings_enable_jsbridge_desc'.tr,
                  value: _enableJSBridge,
                  onChanged: (value) {
                    setState(() {
                      _enableJSBridge = value;
                    });
                  },
                ),

                // 缩放开关
                _buildSwitchRow(
                  theme: theme,
                  title: 'webview_settings_enable_zoom'.tr,
                  subtitle: 'webview_settings_enable_zoom_desc'.tr,
                  value: _enableZoom,
                  onChanged: (value) {
                    setState(() {
                      _enableZoom = value;
                    });
                  },
                ),

                _buildDivider(theme),

                // 隐私与安全
                _buildSectionTitle(theme, 'webview_settings_privacy'.tr),
                const SizedBox(height: 8),

                // 阻止弹窗
                _buildSwitchRow(
                  theme: theme,
                  title: 'webview_settings_block_popups'.tr,
                  subtitle: 'webview_settings_block_popups_desc'.tr,
                  value: _blockPopups,
                  onChanged: (value) {
                    setState(() {
                      _blockPopups = value;
                    });
                  },
                ),

                // 阻止深度链接
                _buildSwitchRow(
                  theme: theme,
                  title: 'webview_settings_block_deeplinks'.tr,
                  subtitle: 'webview_settings_block_deeplinks_desc'.tr,
                  value: _blockDeepLinks,
                  onChanged: (value) {
                    setState(() {
                      _blockDeepLinks = value;
                    });
                  },
                ),

                // 保存历史记录
                _buildSwitchRow(
                  theme: theme,
                  title: 'webview_settings_save_history'.tr,
                  subtitle: 'webview_settings_save_history_desc'.tr,
                  value: _saveHistory,
                  onChanged: (value) {
                    setState(() {
                      _saveHistory = value;
                    });
                  },
                ),

                _buildDivider(theme),

                // 标签页管理
                _buildSectionTitle(theme, 'webview_settings_tabs'.tr),
                const SizedBox(height: 8),

                // 恢复上次打开的标签页
                _buildSwitchRow(
                  theme: theme,
                  title: 'webview_settings_restore_tabs'.tr,
                  subtitle: 'webview_settings_restore_tabs_desc'.tr,
                  value: _restoreTabsOnStartup,
                  onChanged: (value) {
                    setState(() {
                      _restoreTabsOnStartup = value;
                    });
                  },
                ),

                // 最大标签页数量
                Padding(
                  padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'webview_settings_max_tabs'.tr,
                              style: DsTypography.body.copyWith(
                                color: theme.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'webview_settings_max_tabs_desc'.tr,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: theme.spacing.md),
                      SizedBox(
                        width: 100,
                        child: DSInput(
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                              text: _maxTabs.toString(),
                            )
                            ..selection = TextSelection.fromPosition(
                              TextPosition(offset: _maxTabs.toString().length),
                            ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null && parsed > 0 && parsed <= 50) {
                              setState(() {
                                _maxTabs = parsed;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                _buildDivider(theme),

                // 高级设置
                _buildSectionTitle(theme, 'webview_settings_advanced'.tr),
                const SizedBox(height: 8),

                // 用户代理
                DSListItem(
                  title: 'webview_settings_user_agent'.tr,
                  subtitle:
                      _userAgent.isEmpty
                          ? 'webview_settings_user_agent_default'.tr
                          : _userAgent,
                  trailing: DsIcon(
                    DsIconKind.edit,
                    size: 20,
                    color: theme.textSub,
                  ),
                  onTap: () {
                    _showEditDialog(
                      title: 'webview_settings_user_agent'.tr,
                      initialValue: _userAgent,
                      onSave: (value) {
                        setState(() {
                          _userAgent = value;
                        });
                      },
                    );
                  },
                ),

                // 默认搜索引擎
                DSListItem(
                  title: 'webview_settings_search_engine'.tr,
                  subtitle: _defaultSearchEngine,
                  trailing: DsIcon(
                    DsIconKind.edit,
                    size: 20,
                    color: theme.textSub,
                  ),
                  onTap: () {
                    _showEditDialog(
                      title: 'webview_settings_search_engine'.tr,
                      initialValue: _defaultSearchEngine,
                      onSave: (value) {
                        setState(() {
                          _defaultSearchEngine = value;
                        });
                      },
                    );
                  },
                ),

                // 主页
                DSListItem(
                  title: 'webview_settings_homepage'.tr,
                  subtitle: _homePage,
                  trailing: DsIcon(
                    DsIconKind.edit,
                    size: 20,
                    color: theme.textSub,
                  ),
                  onTap: () {
                    _showEditDialog(
                      title: 'webview_settings_homepage'.tr,
                      initialValue: _homePage,
                      onSave: (value) {
                        setState(() {
                          _homePage = value;
                        });
                      },
                    );
                  },
                ),

                _buildDivider(theme),

                // 代理设置
                DSListItem(
                  title: 'webview_proxy_settings'.tr,
                  subtitle: 'webview_proxy_settings_desc'.tr,
                  showChevron: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProxySettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(AppThemeData theme, String text) => Text(
    text,
    style: DsTypography.heading.copyWith(
      color: theme.text,
      fontWeight: FontWeight.bold,
    ),
  );

  /// 开关行(SwitchListTile 的 DS 替代)
  Widget _buildSwitchRow({
    required AppThemeData theme,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
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

  void _showEditDialog({
    required String title,
    required String initialValue,
    required Function(String) onSave,
  }) {
    final controller = TextEditingController(text: initialValue);

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                return DSDialog(
                  title: title,
                  content: DSInput(controller: controller, maxLines: 1),
                  confirmText: 'app_save'.tr,
                  cancelText: 'app_cancel'.tr,
                  onConfirm: () {
                    onSave(controller.text.trim());
                    Navigator.of(dialogContext).pop();
                  },
                );
              },
            ),
          ),
    );
  }

  Future<void> _saveSettings() async {
    final plugin = WebViewPlugin.instance;
    plugin.webviewSettings = plugin.webviewSettings.copyWith(
      enableJavaScript: _enableJavaScript,
      enableJSBridge: _enableJSBridge,
      blockPopups: _blockPopups,
      enableZoom: _enableZoom,
      saveHistory: _saveHistory,
      restoreTabsOnStartup: _restoreTabsOnStartup,
      blockDeepLinks: _blockDeepLinks,
      maxTabs: _maxTabs,
      userAgent: _userAgent,
      defaultSearchEngine: _defaultSearchEngine,
      homePage: _homePage,
    );

    await plugin.saveWebviewSettings();

    if (mounted) {
      Toast.success('webview_settings_saved'.tr);
      Navigator.pop(context);
    }
  }
}
